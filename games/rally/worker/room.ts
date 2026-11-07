// An online room: the relay between the browsers playing one game together from different
// computers, run as a Cloudflare Durable Object (one per room code). The same file is in Rally,
// Shatterbelt and Hivestorm.
//
// The room doesn't know the game. Every browser runs the whole game itself; the room only hands
// each browser's messages (mostly its controls, frame by frame) to the others, in order. See
// src/online.ts for the browsers' side.
//
//   GET {BASE}/room/{CODE}?new   a WebSocket that makes the room (refused if the code is in use)
//   GET {BASE}/room/{CODE}       a WebSocket that joins it (refused if nobody is in it, or it is full)
//
// The room tells a new member { t: "welcome", you, peers, size }: its slot (0, 1, …), every slot
// in the room, and how many it holds. It tells the others { t: "join", slot } and later
// { t: "leave", slot }. Anything a member sends is passed to every other member with `from` (its
// slot) added. Only the host (the lowest slot still in the room) may send { t: "start" }. A
// message that is just "ping" is answered "pong" without waking the room, for measuring delay.
//
// It uses the WebSocket Hibernation API, so an idle room costs nothing; each member's slot is kept
// on its socket, so the room has no other state and nothing is stored once everyone has gone.

/** The parts of Cloudflare's Durable Object and WebSocket types the room uses. */
interface Socket {
  send(data: string): void;
  close(code?: number, reason?: string): void;
  serializeAttachment(value: unknown): void;
  deserializeAttachment(): unknown;
}
interface RoomState {
  acceptWebSocket(ws: Socket): void;
  getWebSockets(): Socket[];
  setWebSocketAutoResponse?(pair: unknown): void;
}
declare const WebSocketPair: { new (): { 0: Socket; 1: Socket } };
declare const WebSocketRequestResponsePair: { new (request: string, response: string): unknown } | undefined;

export interface RoomEnv { ROOM_SIZE?: string }

/** Room codes: four capitals, without I and O, which look like 1 and 0. */
export const CODE = /^[A-HJ-NP-Z]{4}$/;
/** The longest message a member may send; anything longer is dropped. */
export const MAX_MESSAGE = 8192;

interface Member { ws: Socket; slot: number }

export class Room {
  constructor(private ctx: RoomState, private env: RoomEnv) {
    // Answered by Cloudflare itself, without waking the room.
    if (typeof WebSocketRequestResponsePair !== "undefined") ctx.setWebSocketAutoResponse?.(new WebSocketRequestResponsePair("ping", "pong"));
  }

  /** How many players a room holds: the game's ROOM_SIZE, 2 if unset. */
  private get size(): number {
    const n = Number(this.env.ROOM_SIZE);
    return Number.isInteger(n) && n >= 2 && n <= 16 ? n : 2;
  }

  private members(except?: Socket): Member[] {
    const out: Member[] = [];
    for (const ws of this.ctx.getWebSockets()) {
      if (ws === except) continue;
      const a = ws.deserializeAttachment() as { slot?: unknown } | null;
      if (a && typeof a.slot === "number") out.push({ ws, slot: a.slot });
    }
    return out;
  }

  private broadcast(text: string, except?: Socket): void {
    for (const m of this.members(except)) {
      try { m.ws.send(text); } catch { /* closing; its close event will follow */ }
    }
  }

  async fetch(req: Request): Promise<Response> {
    if (req.headers.get("Upgrade")?.toLowerCase() !== "websocket") return new Response("This address takes a WebSocket.", { status: 426 });
    const create = new URL(req.url).searchParams.has("new");
    const pair = new WebSocketPair();
    const client = pair[0], server = pair[1];
    const members = this.members();
    this.ctx.acceptWebSocket(server);
    const taken = new Set(members.map((m) => m.slot));
    let slot = 0;
    while (taken.has(slot)) slot++;
    const refusal = create && members.length ? "taken" : !create && !members.length ? "missing" : slot >= this.size ? "full" : null;
    if (refusal) {
      server.send(JSON.stringify({ t: "error", reason: refusal }));
      server.close(4000, refusal);
    } else {
      server.serializeAttachment({ slot });
      server.send(JSON.stringify({ t: "welcome", you: slot, peers: [...taken, slot].sort((a, b) => a - b), size: this.size }));
      this.broadcast(JSON.stringify({ t: "join", slot }), server);
    }
    return new Response(null, { status: 101, webSocket: client } as ResponseInit);
  }

  webSocketMessage(ws: Socket, data: string | ArrayBuffer): void {
    if (typeof data !== "string" || data.length > MAX_MESSAGE || !data.startsWith('{"') || !data.endsWith("}")) return;
    const a = ws.deserializeAttachment() as { slot?: number } | null;
    if (!a || typeof a.slot !== "number") return;
    const from = a.slot;
    // Controls are most of the traffic: pass them on without reading them.
    if (!data.startsWith('{"t":"in"')) {
      let msg: unknown;
      try { msg = JSON.parse(data); } catch { return; }
      if (!msg || typeof msg !== "object" || typeof (msg as { t?: unknown }).t !== "string") return;
      if ((msg as { t: string }).t === "start" && from !== Math.min(...this.members().map((m) => m.slot))) return;
    }
    // `from` goes last: if a member sent its own, JSON.parse keeps the last one, the room's.
    this.broadcast(`${data.slice(0, -1)},"from":${from}}`, ws);
  }

  webSocketClose(ws: Socket): void {
    this.leave(ws);
    try { ws.close(1000, "bye"); } catch { /* already closed */ }
  }

  webSocketError(ws: Socket): void {
    this.leave(ws);
  }

  private leave(ws: Socket): void {
    const a = ws.deserializeAttachment() as { slot?: number } | null;
    if (!a || typeof a.slot !== "number") return;
    ws.serializeAttachment(null);
    this.broadcast(JSON.stringify({ t: "leave", slot: a.slot }), ws);
  }
}

/** Routes GET {base}/room/{CODE} to that room's Durable Object; null for any other address. */
export function roomRequest(req: Request, path: string, rooms: { idFromName(name: string): unknown; get(id: unknown): { fetch(req: Request): Promise<Response> } }): Promise<Response> | null {
  if (!path.startsWith("/room/")) return null;
  const code = path.slice("/room/".length);
  if (req.method !== "GET" || !CODE.test(code)) return Promise.resolve(new Response("No such room.", { status: 404 }));
  return rooms.get(rooms.idFromName(code)).fetch(req);
}
