// One Durable Object per room, named by its code. Every message from every device in the room
// passes through it one at a time, so it is the single source of truth: it keeps the Room in its
// storage, applies the rules (src/shared/game.ts) and sends each connection the view it may see.
// The key never leaves this object except to clue-givers. Sockets hibernate between messages.
import * as G from "../src/shared/game";
import type { ClientMsg, ServerMsg } from "../src/shared/protocol";

/** A room nobody has touched for this long is deleted. */
export const IDLE_MS = 3 * 24 * 60 * 60 * 1000;

export interface Socket { send(data: string): void; close(code?: number, reason?: string): void }
/** What a connection is: a player's seat, a shared screen, or someone who has not joined yet. */
export interface Attachment { id: string | null; screen: boolean }

/** What the room's logic needs from around it; the Durable Object below, or the tests. */
export interface RoomHost {
  sockets(): Socket[];
  attachment(ws: Socket): Attachment;
  attach(ws: Socket, att: Attachment): void;
  save(room: G.Room | null): Promise<void>;
  alarm(at: number | null): Promise<void>;
  now(): number;
  random(): number;
  token(length: number): string;
}

/** The room's logic without the Durable Object around it. */
export class RoomCore {
  constructor(public room: G.Room | null, private host: RoomHost, private builtin: readonly string[]) {}

  /** Opens the room for its first player, the host. Null if the room already exists. */
  async create(code: string, name: string): Promise<{ id: string; token: string } | null> {
    if (this.room) return null;
    const room = G.newRoom(code, this.host.now());
    const seat = { id: this.host.token(10), token: this.host.token(24) };
    const r = G.join(room, name, seat.id, seat.token, this.ctx());
    if (!r.ok) return null;
    this.room = room;
    await this.commit();
    return seat;
  }

  /** A new connection: it says who it is with its first message. */
  open(ws: Socket): void {
    this.host.attach(ws, { id: null, screen: false });
    if (!this.room) { this.send(ws, { t: "gone" }); ws.close(4404, "no room"); }
  }

  async message(ws: Socket, data: string): Promise<void> {
    const room = this.room;
    if (!room) { this.send(ws, { t: "gone" }); return; }
    let msg: ClientMsg;
    try { msg = JSON.parse(data) as ClientMsg; } catch { this.send(ws, { t: "error", code: "bad" }); return; }
    if (!msg || typeof msg !== "object" || typeof msg.t !== "string") { this.send(ws, { t: "error", code: "bad" }); return; }

    const att = this.host.attachment(ws);
    const ctx = this.ctx();
    let r: G.Result = { ok: true };

    if (msg.t === "hello") {
      const seat = msg.seat;
      const p = seat && room.players.find((x) => x.id === seat.id && x.token === seat.token);
      if (p) this.host.attach(ws, { id: p.id, screen: false });
      else {
        if (seat) this.send(ws, { t: "unseated" });
        this.host.attach(ws, { id: null, screen: !!msg.screen });
      }
      this.broadcast();
      return;
    }

    if (msg.t === "screen") {
      this.host.attach(ws, { id: null, screen: true });
      this.broadcast();
      return;
    }

    if (msg.t === "join" || msg.t === "claim") {
      if (att.id) { this.send(ws, { t: "error", code: "bad" }); return; }
      const token = this.host.token(24);
      let id: string;
      if (msg.t === "join") {
        id = this.host.token(10);
        r = G.join(room, String(msg.name ?? ""), id, token, ctx);
      } else {
        id = String(msg.id ?? "");
        r = G.claim(room, id, token, ctx);
      }
      if (!r.ok) { this.send(ws, { t: "error", code: r.error }); return; }
      this.host.attach(ws, { id, screen: false });
      this.send(ws, { t: "seat", id, token });
      await this.commit();
      return;
    }

    const me = att.id;
    if (!me || !room.players.some((p) => p.id === me)) {
      this.host.attach(ws, { id: null, screen: att.screen });
      this.send(ws, { t: "unseated" });
      this.broadcast();
      return;
    }

    switch (msg.t) {
      case "name": r = G.rename(room, me, String(msg.name ?? "")); break;
      case "team": r = G.setTeam(room, me, String(msg.id), msg.team, ctx); break;
      case "clueGiver": r = G.setClueGiver(room, me, String(msg.id), ctx); break;
      case "shuffle": r = G.shuffleTeams(room, me, ctx); break;
      case "remove":
      case "leave": {
        const id = msg.t === "leave" ? me : String(msg.id);
        r = G.remove(room, me, id, ctx);
        if (r.ok) this.unseat(id);
        break;
      }
      case "timer": r = G.setTimer(room, me, Number(msg.seconds), ctx); break;
      case "words": r = G.setWords(room, me, msg.text === null ? null : String(msg.text ?? ""), ctx); break;
      case "start":
      case "newGame": r = G.deal(room, me, ctx); break;
      case "lobby": r = G.toLobby(room, me, ctx); break;
      case "clue": r = G.giveClue(room, me, String(msg.word ?? ""), Number(msg.number), ctx); break;
      case "guess": r = G.guess(room, me, Number(msg.index), ctx); break;
      case "stop": r = G.stop(room, me, ctx); break;
      default: r = { ok: false, error: "bad" };
    }
    if (!r.ok) { this.send(ws, { t: "error", code: r.error }); this.broadcastTo(ws); return; }
    await this.commit();
  }

  /** A connection went away: everyone sees that player as away. */
  closed(ws: Socket): void {
    if (this.room) this.broadcast(ws);
  }

  /** The turn timer, or the room's idle time, ran out. */
  async alarm(): Promise<void> {
    const room = this.room;
    if (!room) return;
    const now = this.host.now();
    if (G.expire(room, now)) { await this.commit(false); return; }
    if (now >= room.active + IDLE_MS && this.host.sockets().length === 0) {
      this.room = null;
      await this.host.save(null);
      await this.host.alarm(null);
      return;
    }
    await this.schedule();
  }

  // ── Inside ──

  private ctx(except?: Socket): G.Ctx {
    return { now: this.host.now(), random: () => this.host.random(), builtin: this.builtin, online: this.online(except) };
  }

  private online(except?: Socket): Set<string> {
    const ids = new Set<string>();
    for (const ws of this.host.sockets()) {
      if (ws === except) continue;
      const id = this.host.attachment(ws).id;
      if (id) ids.add(id);
    }
    return ids;
  }

  /** Saves the room after a change, sets its alarm and tells everyone. */
  private async commit(touched = true): Promise<void> {
    if (!this.room) return;
    if (touched) this.room.active = this.host.now();
    await this.host.save(this.room);
    await this.schedule();
    this.broadcast();
  }

  private async schedule(): Promise<void> {
    const room = this.room;
    if (!room) return;
    const deadline = room.game?.deadline ?? null;
    const idle = room.active + IDLE_MS;
    await this.host.alarm(deadline !== null ? Math.min(deadline, idle) : idle);
  }

  /** Connections whose seat was removed go back to the join screen. */
  private unseat(id: string): void {
    for (const ws of this.host.sockets()) {
      const att = this.host.attachment(ws);
      if (att.id === id) {
        this.host.attach(ws, { id: null, screen: false });
        this.send(ws, { t: "unseated" });
      }
    }
  }

  private broadcast(except?: Socket): void {
    for (const ws of this.host.sockets()) if (ws !== except) this.broadcastTo(ws, except);
  }

  private broadcastTo(ws: Socket, except?: Socket): void {
    if (!this.room) return;
    const att = this.host.attachment(ws);
    this.send(ws, { t: "state", view: G.view(this.room, att, this.ctx(except)) });
  }

  private send(ws: Socket, msg: ServerMsg): void {
    try { ws.send(JSON.stringify(msg)); } catch { /* the socket closed */ }
  }
}

// ── The Durable Object ──

interface HibernatingSocket extends Socket {
  serializeAttachment(value: unknown): void;
  deserializeAttachment(): unknown;
}
interface Storage {
  get<T>(key: string): Promise<T | undefined>;
  put(key: string, value: unknown): Promise<void>;
  deleteAll(): Promise<void>;
  setAlarm(at: number): Promise<void>;
  deleteAlarm(): Promise<void>;
}
interface DurableObjectState {
  storage: Storage;
  acceptWebSocket(ws: HibernatingSocket, tags?: string[]): void;
  getWebSockets(tag?: string): HibernatingSocket[];
  blockConcurrencyWhile<T>(fn: () => Promise<T>): Promise<T>;
  setWebSocketAutoResponse?(pair: unknown): void;
}
declare const WebSocketPair: { new (): { 0: HibernatingSocket; 1: HibernatingSocket } };
declare const WebSocketRequestResponsePair: { new (request: string, response: string): unknown } | undefined;

/** Random letters and digits from the platform's secure generator. */
export function randomToken(length: number): string {
  const abc = "abcdefghijkmnpqrstuvwxyz23456789";
  const bytes = crypto.getRandomValues(new Uint8Array(length));
  return Array.from(bytes, (b) => abc[b % abc.length]).join("");
}

/** A number in [0, 1) from the secure generator, for dealing and shuffling. */
export function secureRandom(): number {
  return crypto.getRandomValues(new Uint32Array(1))[0]! / 2 ** 32;
}

export function makeRoomObject(builtin: readonly string[]) {
  return class RoomObject {
    private core!: RoomCore;

    constructor(private ctx: DurableObjectState, _env: unknown) {
      if (typeof WebSocketRequestResponsePair !== "undefined") {
        try { ctx.setWebSocketAutoResponse?.(new WebSocketRequestResponsePair("ping", "pong")); } catch { /* not supported */ }
      }
      const host: RoomHost = {
        sockets: () => ctx.getWebSockets(),
        attachment: (ws) => ((ws as HibernatingSocket).deserializeAttachment() as Attachment | null) ?? { id: null, screen: false },
        attach: (ws, att) => (ws as HibernatingSocket).serializeAttachment(att),
        save: (room) => (room ? ctx.storage.put("room", room) : ctx.storage.deleteAll()),
        alarm: (at) => (at === null ? ctx.storage.deleteAlarm() : ctx.storage.setAlarm(at)),
        now: () => Date.now(),
        random: secureRandom,
        token: randomToken,
      };
      void ctx.blockConcurrencyWhile(async () => {
        this.core = new RoomCore((await ctx.storage.get<G.Room>("room")) ?? null, host, builtin);
      });
    }

    async fetch(req: Request): Promise<Response> {
      const url = new URL(req.url);
      if (url.pathname === "/create" && req.method === "POST") {
        const body = (await req.json().catch(() => ({}))) as { code?: string; name?: string };
        const seat = await this.core.create(String(body.code ?? ""), String(body.name ?? ""));
        if (!seat) return Response.json({ error: "taken" }, { status: 409 });
        return Response.json(seat);
      }
      if (url.pathname === "/ws") {
        if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
        const pair = new WebSocketPair();
        this.ctx.acceptWebSocket(pair[1]);
        this.core.open(pair[1]);
        return new Response(null, { status: 101, webSocket: pair[0] } as ResponseInit);
      }
      return new Response("Not found", { status: 404 });
    }

    async webSocketMessage(ws: HibernatingSocket, message: string | ArrayBuffer): Promise<void> {
      if (typeof message !== "string") return;
      if (message === "ping") { ws.send("pong"); return; }
      await this.core.message(ws, message);
    }

    webSocketClose(ws: HibernatingSocket, code: number): void {
      this.core.closed(ws);
      try { ws.close(code === 1005 || code === 1006 ? 1000 : code, "bye"); } catch { /* already closed */ }
    }

    webSocketError(ws: HibernatingSocket): void {
      this.core.closed(ws);
    }

    async alarm(): Promise<void> {
      await this.core.alarm();
    }
  };
}
