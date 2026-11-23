// The Dulmál Worker at icelander.net/games/fresh/dulmal. It serves the page from ./dist and
// opens rooms: POST api/rooms creates one with a fresh code, and api/rooms/<CODE>/ws is the
// room's WebSocket, handled by that room's Durable Object (worker/room.ts). There is no sign-in:
// anyone with a room's link can join it, as the owner asked (.dev/decisions.json).
import WORDS_TEXT from "../data/ord.txt";
import { parseWords } from "../src/shared/words";
import { BASE, CODE_LENGTH, CODE_LETTERS, CODE_RE } from "./config";
import { makeRoomObject } from "./room";

export const RoomObject = makeRoomObject(parseWords(WORDS_TEXT));

interface Fetcher { fetch(req: Request): Promise<Response> }
interface DurableObjectStub { fetch(input: Request | string, init?: RequestInit): Promise<Response> }
interface DurableObjectNamespace { idFromName(name: string): unknown; get(id: unknown): DurableObjectStub }
export interface Env { ASSETS: Fetcher; ROOMS: DurableObjectNamespace }

const room = (env: Env, code: string) => env.ROOMS.get(env.ROOMS.idFromName(code));

/** A random room code (19 letters, so the small bias of a byte modulo 19 does not matter). */
export function newCode(): string {
  return Array.from(crypto.getRandomValues(new Uint8Array(CODE_LENGTH)), (b) => CODE_LETTERS[b % CODE_LETTERS.length]).join("");
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const path = url.pathname;
    if (path === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (!path.startsWith(`${BASE}/`)) return new Response("Not found", { status: 404 });

    if (path === `${BASE}/api/rooms`) {
      if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } });
      const body = (await req.json().catch(() => ({}))) as { name?: unknown };
      const name = String(body.name ?? "").trim();
      if (!name) return Response.json({ error: "name" }, { status: 400 });
      for (let attempt = 0; attempt < 10; attempt++) {
        const code = newCode();
        const res = await room(env, code).fetch("https://room/create", { method: "POST", body: JSON.stringify({ code, name }) });
        if (res.ok) {
          const seat = (await res.json()) as { id: string; token: string };
          return Response.json({ code, ...seat }, { headers: { "Cache-Control": "no-store" } });
        }
      }
      return Response.json({ error: "busy" }, { status: 503 });
    }

    const ws = path.match(/^\/games\/fresh\/dulmal\/api\/rooms\/([A-Za-z]+)\/ws$/);
    if (ws) {
      const code = ws[1]!.toUpperCase();
      if (!CODE_RE.test(code)) return new Response("No such room", { status: 404 });
      if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
      return room(env, code).fetch(new Request("https://room/ws", req));
    }

    if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
    const asset = await env.ASSETS.fetch(req);
    const out = new Response(asset.body, asset);
    const page = (out.headers.get("Content-Type") ?? "").startsWith("text/html");
    out.headers.set("Cache-Control", page ? "no-cache" : "public, max-age=3600");
    return out;
  },
};
