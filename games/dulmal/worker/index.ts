// The Dulmál Worker at icelander.net/games/dulmal. Everything here is for players signed in to
// icelander.net who hold games:dulmal, an invite-only role granted at icelander.net/private/admin
// (vendor/icelander-auth, through the site's login service). A visitor who isn't signed in is sent
// to sign in and back; a signed-in player without the role gets a page saying so.
//
// It serves the page from ./dist and opens rooms: POST api/rooms creates one with a fresh code, and
// api/rooms/<CODE>/ws is the room's WebSocket, handled by that room's Durable Object (worker/room.ts).
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import WORDS_TEXT from "../data/ord.txt";
import { parseWords } from "../src/shared/words";
import { BASE, CODE_LENGTH, CODE_LETTERS, CODE_RE, ROLE } from "./config";
import { makeRoomObject } from "./room";

export const RoomObject = makeRoomObject(parseWords(WORDS_TEXT));

interface Fetcher { fetch(req: Request): Promise<Response> }
interface DurableObjectStub { fetch(input: Request | string, init?: RequestInit): Promise<Response> }
interface DurableObjectNamespace { idFromName(name: string): unknown; get(id: unknown): DurableObjectStub }
export interface Env extends AuthEnv { ASSETS: Fetcher; ROOMS: DurableObjectNamespace; DEV_LOGIN?: string }

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"] });

/** The library's env: DEV_LOGIN "1" turns on its stand-in sign-in (which works on localhost only). */
const shared = (env: Env): Env => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);

const room = (env: Env, code: string) => env.ROOMS.get(env.ROOMS.idFromName(code));
const WS_PATH = new RegExp(`^${BASE}/api/rooms/([A-Za-z]+)/ws$`);

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

    const api = path.startsWith(`${BASE}/api/`);
    const { response, user } = await AUTH.requireRole(req, shared(env), ROLE, { api });
    if (response) return user && !api ? notInvited() : response;

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

    const ws = path.match(WS_PATH);
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
    out.headers.set("Cache-Control", page ? "private, no-cache" : "private, max-age=3600");
    return out;
  },
};

/** For a signed-in player without the role. */
function notInvited(): Response {
  const html = `<!doctype html>
<html lang="is"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Dulmál · aðeins fyrir boðsgesti</title><meta name="robots" content="noindex">
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b1622;color:#f2f6f5;font:19px/1.5 system-ui,sans-serif}
main{max-width:30rem;padding:2rem 1.25rem}h1{font-size:2rem;margin:0 0 .75rem}a{color:#4fe3a3}</style></head>
<body><main><h1>Dulmál</h1>
<p>Dulmál er aðeins opið boðsgestum og þessum aðgangi hefur ekki verið boðið enn.</p>
<p>Ef þér var boðið á öðru netfangi skaltu skrá þig inn með því. <a href="/games/">Aftur í leikina</a></p>
<p lang="en"><small>Dulmál is open to invited players only, and this account hasn't been invited yet.</small></p></main></body></html>`;
  return new Response(html, { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
}
