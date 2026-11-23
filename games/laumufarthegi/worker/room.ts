// One Durable Object per room. It holds the room's state (shared/game.ts) in its storage, takes every player's
// WebSocket, applies their actions one at a time, and sends each player their own view: the secret word only to
// those who may see it, the stowaway to nobody until the round is over. Timers (a clue, the vote, the stowaway's
// guess) run on the object's alarm, so they fire even while every socket sleeps. A room nobody has touched for a
// day deletes itself.
import { act, addPlayer, byToken, newRoom, setConnected, tick, view, type Action, type State, type Topic } from "../shared/game";
import { isCode, type ClientMessage, type CreatedRoom, type ServerMessage } from "../shared/protocol";
import { TOPICS } from "../shared/topics";

export interface WebSocketLike {
  send(data: string): void;
  close(code?: number, reason?: string): void;
  serializeAttachment(value: unknown): void;
  deserializeAttachment(): unknown;
}
export interface RoomStorage {
  get<T>(key: string): Promise<T | undefined>;
  put(key: string, value: unknown): Promise<void>;
  deleteAll(): Promise<void>;
  setAlarm(time: number): Promise<void>;
}
export interface RoomContext {
  storage: RoomStorage;
  acceptWebSocket(ws: WebSocketLike, tags?: string[]): void;
  getWebSockets(tag?: string): WebSocketLike[];
}
export interface RoomDeps { now(): number; rand(): number; id(): string; topics: Topic[] }

declare const WebSocketPair: { new (): { 0: WebSocketLike; 1: WebSocketLike } };

/** A room nobody has touched for this long is deleted. */
export const IDLE_MS = 24 * 60 * 60 * 1000;
const MAX_MESSAGE = 2000;

const realDeps: RoomDeps = {
  now: () => Date.now(),
  rand: () => crypto.getRandomValues(new Uint32Array(1))[0] / 2 ** 32,
  id: () => [...crypto.getRandomValues(new Uint8Array(16))].map((b) => b.toString(16).padStart(2, "0")).join(""),
  topics: TOPICS,
};

export class Room {
  private state: State | null = null;
  private loaded = false;

  constructor(private ctx: RoomContext, _env: unknown, private deps: RoomDeps = realDeps) {}

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    await this.load();
    if (url.pathname === "/create" && req.method === "POST") {
      if (this.state) return new Response("Taken", { status: 409 });
      const body = (await req.json().catch(() => ({}))) as { code?: unknown; name?: unknown };
      if (!isCode(body.code)) return new Response("Bad code", { status: 400 });
      const host = { id: this.deps.id(), token: this.deps.id(), name: typeof body.name === "string" ? body.name : "" };
      this.state = newRoom(body.code, host, this.deps.now());
      await this.save();
      return Response.json({ code: body.code, token: host.token, playerId: host.id } satisfies CreatedRoom);
    }
    if (url.pathname === "/ws") {
      if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
      if (!this.state) return new Response("No such room", { status: 404 });
      const pair = new WebSocketPair();
      this.ctx.acceptWebSocket(pair[1]);
      return new Response(null, { status: 101, webSocket: pair[0] } as ResponseInit);
    }
    return new Response("Not found", { status: 404 });
  }

  async webSocketMessage(ws: WebSocketLike, raw: string | ArrayBuffer): Promise<void> {
    if (raw === "ping") { ws.send("pong"); return; }
    await this.load();
    const s = this.state;
    if (!s) { send(ws, { t: "error", message: "Þessi leikur er ekki lengur til." }); ws.close(4404, "gone"); return; }
    if (typeof raw !== "string" || raw.length > MAX_MESSAGE) return;
    let msg: ClientMessage;
    try { msg = JSON.parse(raw); } catch { return; }
    if (!msg || typeof msg !== "object" || typeof msg.t !== "string") return;
    const now = this.deps.now();

    if (msg.t === "join") {
      let player = byToken(s, msg.token);
      if (!player) {
        if (typeof msg.name !== "string") { send(ws, { t: "error", message: "Sætið þitt fannst ekki. Sláðu inn nafn til að ganga í leikinn." }); return; }
        const id = this.deps.id(), token = this.deps.id();
        const r = addPlayer(s, msg.name, id, token, now);
        if (!r.ok) { send(ws, { t: "error", message: r.error }); return; }
        player = s.players.find((p) => p.id === id)!;
      }
      ws.serializeAttachment({ playerId: player.id });
      setConnected(s, player.id, true, now);
      send(ws, { t: "welcome", token: player.token, playerId: player.id });
      await this.save();
      this.broadcast();
      return;
    }

    const playerId = attachedPlayer(ws);
    if (!playerId) { send(ws, { t: "error", message: "Gakktu fyrst í leikinn." }); return; }
    const r = act(s, playerId, msg as Action, now, this.deps.topics, this.deps.rand);
    if (!r.ok) { send(ws, { t: "error", message: r.error }); return; }
    await this.save();
    this.broadcast();
  }

  async webSocketClose(ws: WebSocketLike): Promise<void> {
    await this.load();
    const s = this.state;
    const playerId = attachedPlayer(ws);
    if (!s || !playerId) return;
    const stillOpen = this.ctx.getWebSockets().some((o) => o !== ws && attachedPlayer(o) === playerId);
    if (stillOpen) return;
    setConnected(s, playerId, false, this.deps.now());
    await this.save();
    this.broadcast(ws);
  }

  async webSocketError(ws: WebSocketLike): Promise<void> {
    await this.webSocketClose(ws);
  }

  async alarm(): Promise<void> {
    await this.load();
    const s = this.state;
    if (!s) return;
    const now = this.deps.now();
    if (now - s.updatedAt >= IDLE_MS) {
      for (const ws of this.ctx.getWebSockets()) { try { ws.close(4404, "gone"); } catch { /* closed */ } }
      await this.ctx.storage.deleteAll();
      this.state = null;
      return;
    }
    if (tick(s, now)) this.broadcast();
    await this.save();
  }

  /** Sends every open socket its player's view; sockets of removed players are told so and closed. */
  private broadcast(skip?: WebSocketLike): void {
    const s = this.state!;
    const now = this.deps.now();
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === skip) continue;
      const id = attachedPlayer(ws);
      if (!id) continue;
      if (!s.players.some((p) => p.id === id)) {
        send(ws, { t: "removed" });
        try { ws.close(4403, "removed"); } catch { /* closed */ }
        continue;
      }
      send(ws, { t: "state", view: view(s, id, this.deps.topics, now) });
    }
  }

  private async load(): Promise<void> {
    if (this.loaded) return;
    this.state = (await this.ctx.storage.get<State>("state")) ?? null;
    this.loaded = true;
  }

  /** Stores the state and sets the alarm for the next timeout, or for the idle clean-up. */
  private async save(): Promise<void> {
    const s = this.state!;
    await this.ctx.storage.put("state", s);
    const deadline = s.round?.deadline ?? Infinity;
    await this.ctx.storage.setAlarm(Math.min(deadline, s.updatedAt + IDLE_MS));
  }
}

function attachedPlayer(ws: WebSocketLike): string | null {
  try {
    const a = ws.deserializeAttachment() as { playerId?: unknown } | null;
    return a && typeof a.playerId === "string" ? a.playerId : null;
  } catch {
    return null;
  }
}

function send(ws: WebSocketLike, msg: ServerMessage): void {
  try { ws.send(JSON.stringify(msg)); } catch { /* the socket closed */ }
}
