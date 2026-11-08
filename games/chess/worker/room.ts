// One Durable Object per online game. Every action on a game passes through its object, one at a
// time, so two moves can never race. The game itself lives in D1 (so lists and history can query
// it); the object checks each action (worker/actions.ts), saves the result and sends the new game
// to everyone watching it over a WebSocket. Watchers are the two players; their sockets hibernate
// between moves, so an idle game costs nothing.
import type { Action, LiveMessage } from "../src/shared/protocol";
import { applyAction, sideOf } from "./actions";
import { gameById, saveGame, type D1Database } from "./db";

/** The game logic of a room, without the Durable Object around it (the tests use it directly). */
export class RoomCore {
  private queue: Promise<unknown> = Promise.resolve();
  constructor(private db: D1Database, private broadcast: (msg: LiveMessage) => void) {}

  /** Runs one action, after any before it have finished. */
  act(gameId: string, userId: string, action: Action): Promise<{ status: number; body: unknown }> {
    const run = this.queue.then(() => this.actNow(gameId, userId, action));
    this.queue = run.catch(() => undefined);
    return run;
  }

  private async actNow(gameId: string, userId: string, action: Action): Promise<{ status: number; body: unknown }> {
    const game = await gameById(this.db, gameId);
    if (!game) return { status: 404, body: { error: "No such game." } };
    const side = sideOf(game, userId);
    if (!side || game.kind !== "online") return { status: 403, body: { error: "You don't play in this game." } };
    const r = applyAction(game, side, action, Date.now());
    if (!r.ok) return { status: 409, body: { error: r.error, game } };
    if (!(await saveGame(this.db, r.game, game.updated))) return { status: 409, body: { error: "The board changed; try again.", game: await gameById(this.db, gameId) } };
    this.broadcast({ t: "state", game: r.game });
    return { status: 200, body: { game: r.game } };
  }
}

// ── The Durable Object ──

interface WebSocketLike { send(data: string): void; close(code?: number, reason?: string): void; accept?(): void }
interface DurableObjectState {
  acceptWebSocket(ws: WebSocketLike, tags?: string[]): void;
  getWebSockets(tag?: string): WebSocketLike[];
}
declare const WebSocketPair: { new (): { 0: WebSocketLike; 1: WebSocketLike } };

export class GameRoom {
  private core: RoomCore;
  private db: D1Database;
  constructor(private ctx: DurableObjectState, env: { DB: D1Database }) {
    this.db = env.DB;
    this.core = new RoomCore(env.DB, (msg) => {
      const text = JSON.stringify(msg);
      for (const ws of this.ctx.getWebSockets()) {
        try { ws.send(text); } catch { /* closed */ }
      }
    });
  }

  async fetch(req: Request): Promise<Response> {
    const url = new URL(req.url);
    const userId = req.headers.get("X-User") ?? "";
    const gameId = req.headers.get("X-Game") ?? "";

    if (url.pathname === "/action") {
      const r = await this.core.act(gameId, userId, (await req.json()) as Action);
      return new Response(JSON.stringify(r.body), { status: r.status, headers: { "Content-Type": "application/json" } });
    }

    if (url.pathname === "/live") {
      if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
      const game = await gameById(this.db, gameId);
      if (!game || !sideOf(game, userId)) return new Response("Not your game", { status: 403 });
      const pair = new WebSocketPair();
      this.ctx.acceptWebSocket(pair[1], [userId]);
      pair[1].send(JSON.stringify({ t: "state", game } satisfies LiveMessage));
      return new Response(null, { status: 101, webSocket: pair[0] } as ResponseInit);
    }
    return new Response("Not found", { status: 404 });
  }

  webSocketMessage(ws: WebSocketLike, message: string | ArrayBuffer): void {
    if (message === "ping") ws.send(JSON.stringify({ t: "pong" } satisfies LiveMessage));
  }

  webSocketClose(ws: WebSocketLike, code: number): void {
    try { ws.close(code === 1005 ? 1000 : code, "bye"); } catch { /* already closed */ }
  }
}
