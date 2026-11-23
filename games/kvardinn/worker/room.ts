// One game room: a Durable Object named after the room's four-letter code. It holds the Game
// (src/engine/game.ts) in its storage, so the room survives the object sleeping or restarting,
// and talks to every device over a hibernatable WebSocket.
//
// Each socket's attachment says which seat it holds (pid, or null before joining) and whether it
// is a big screen. Every change sends each socket its own viewFor(): the target goes only to the
// clue-giver's sockets until the reveal. Pointer drags send only the new position.
import { DurableObject } from "cloudflare:workers";
import cardsText from "../data/kvardar.txt";
import { parseCards } from "../src/engine/cards";
import { act, addPlayer, newGame, viewFor, type Action, type Ctx, type Game } from "../src/engine/game";

const CARDS = parseCards(cardsText).cards;
/** A room nobody has touched for this long is deleted. */
const IDLE_MS = 2 * 24 * 60 * 60 * 1000;
const MAX_MESSAGE = 4000;

interface Tag { pid: string | null; screen: boolean }

type ClientMessage =
  | { t: "hello"; pid?: string; token?: string; screen?: boolean }
  | { t: "join"; name: string; team: unknown }
  | { t: "claim"; pid: string }
  | { t: "act"; action: Action }
  | { t: "ping" };

function rng(): number {
  const a = new Uint32Array(1);
  crypto.getRandomValues(a);
  return a[0] / 4294967296;
}

export class Room extends DurableObject<Record<string, unknown>> {
  private game: Game | null = null;

  constructor(ctx: DurableObjectState, env: Record<string, unknown>) {
    super(ctx, env);
    ctx.blockConcurrencyWhile(async () => {
      this.game = (await ctx.storage.get<Game>("game")) ?? null;
    });
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === "/init" && req.method === "POST") {
      if (this.game) return new Response("taken", { status: 409 });
      const code = (await req.text()).slice(0, 8);
      this.game = newGame(code);
      await this.save(true);
      return new Response("created", { status: 201 });
    }
    if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
    const pair = new WebSocketPair();
    const [client, server] = [pair[0], pair[1]];
    this.ctx.acceptWebSocket(server);
    server.serializeAttachment({ pid: null, screen: false } satisfies Tag);
    if (!this.game) {
      server.send(JSON.stringify({ t: "gone" }));
      server.close(4404, "No such room");
    }
    return new Response(null, { status: 101, webSocket: client });
  }

  async webSocketMessage(ws: WebSocket, data: string | ArrayBuffer): Promise<void> {
    if (typeof data !== "string" || data.length > MAX_MESSAGE) return;
    let msg: ClientMessage;
    try {
      msg = JSON.parse(data);
    } catch {
      return;
    }
    const game = this.game;
    if (!game) {
      send(ws, { t: "gone" });
      return;
    }
    const tag = (ws.deserializeAttachment() as Tag | null) ?? { pid: null, screen: false };

    switch (msg.t) {
      case "ping":
        send(ws, { t: "pong" });
        return;
      case "hello": {
        const seat = game.players.find((p) => p.id === msg.pid && p.token === msg.token);
        tag.pid = seat ? seat.id : null;
        tag.screen = msg.screen === true;
        ws.serializeAttachment(tag);
        send(ws, { t: "welcome", you: tag.pid });
        this.broadcast();
        return;
      }
      case "join": {
        if (tag.pid || tag.screen) return;
        const res = addPlayer(game, msg.name, msg.team, this.ctx_());
        if (!res.ok) {
          send(ws, { t: "error", message: res.error });
          return;
        }
        tag.pid = res.player.id;
        ws.serializeAttachment(tag);
        send(ws, { t: "seat", pid: res.player.id, token: res.player.token });
        await this.save(true);
        this.broadcast();
        return;
      }
      case "claim": {
        // A player on a new device takes back a seat that nobody is using.
        if (tag.pid || tag.screen) return;
        const seat = game.players.find((p) => p.id === msg.pid);
        if (!seat || this.online().has(seat.id)) {
          send(ws, { t: "error", message: "Þetta sæti er í notkun." });
          return;
        }
        tag.pid = seat.id;
        ws.serializeAttachment(tag);
        send(ws, { t: "seat", pid: seat.id, token: seat.token });
        this.broadcast();
        return;
      }
      case "act": {
        if (!tag.pid) {
          send(ws, { t: "error", message: "Þú ert ekki í leiknum." });
          return;
        }
        if (!msg.action || typeof msg.action !== "object") return;
        const out = act(game, tag.pid, msg.action, this.ctx_());
        if (!out.ok) {
          send(ws, { t: "error", message: out.error });
          return;
        }
        if (out.change === "pointer" && game.round) {
          const m = JSON.stringify({ t: "pointer", value: game.round.pointer, by: tag.pid });
          for (const s of this.ctx.getWebSockets()) trySend(s, m);
          await this.save(false);
        } else {
          await this.save(true);
          this.broadcast();
        }
        // Removed players lose their sockets' seats.
        if (msg.action.a === "kick") this.dropRemoved();
        return;
      }
    }
  }

  async webSocketClose(ws: WebSocket, code: number): Promise<void> {
    try {
      ws.close(code === 1005 || code === 1006 ? 1000 : code, "bye");
    } catch {
      /* already closed */
    }
    this.broadcast(ws);
  }

  async webSocketError(ws: WebSocket): Promise<void> {
    this.broadcast(ws);
  }

  async alarm(): Promise<void> {
    const touched = (await this.ctx.storage.get<number>("touched")) ?? 0;
    if (Date.now() - touched >= IDLE_MS && this.ctx.getWebSockets().length === 0) {
      await this.ctx.storage.deleteAll();
      this.game = null;
    } else {
      await this.ctx.storage.setAlarm(touched + IDLE_MS);
    }
  }

  private ctx_(except?: WebSocket): Ctx {
    return { online: this.online(except), rng, cards: CARDS };
  }

  private online(except?: WebSocket): Set<string> {
    const s = new Set<string>();
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except || ws.readyState !== WebSocket.OPEN) continue;
      const tag = ws.deserializeAttachment() as Tag | null;
      if (tag?.pid) s.add(tag.pid);
    }
    return s;
  }

  private async save(touch: boolean): Promise<void> {
    if (!this.game) return;
    await this.ctx.storage.put("game", this.game);
    if (touch) {
      const now = Date.now();
      await this.ctx.storage.put("touched", now);
      await this.ctx.storage.setAlarm(now + IDLE_MS);
    }
  }

  private broadcast(except?: WebSocket): void {
    const game = this.game;
    if (!game) return;
    const online = this.online(except);
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      const tag = ws.deserializeAttachment() as Tag | null;
      trySend(ws, JSON.stringify({ t: "state", view: viewFor(game, tag?.pid ?? null, online) }));
    }
  }

  private dropRemoved(): void {
    const game = this.game;
    if (!game) return;
    for (const ws of this.ctx.getWebSockets()) {
      const tag = ws.deserializeAttachment() as Tag | null;
      if (tag?.pid && !game.players.some((p) => p.id === tag.pid)) {
        ws.serializeAttachment({ pid: null, screen: false } satisfies Tag);
        trySend(ws, JSON.stringify({ t: "removed" }));
        trySend(ws, JSON.stringify({ t: "state", view: viewFor(game, null, this.online()) }));
      }
    }
  }
}

function send(ws: WebSocket, msg: unknown): void {
  trySend(ws, JSON.stringify(msg));
}

function trySend(ws: WebSocket, text: string): void {
  try {
    ws.send(text);
  } catch {
    /* closing */
  }
}
