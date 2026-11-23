// The Laumufarþegi Worker at icelander.net/games/laumufarthegi: the page and its files (dist/), a small API,
// and one Durable Object per room (worker/room.ts).
//
//   GET  {BASE}/                      the game (anyone with the link may play)
//   GET  {BASE}/api/me                whether the visitor may start a room, and where to sign in
//   POST {BASE}/api/rooms             starts a room; needs icelander.net's sign-in and HOST_ROLE, unless HOST_SIGN_IN is "none"
//   GET  {BASE}/api/rooms/CODE/ws     the room's WebSocket (no sign-in: the room code in the link is the key)
//
// As deployed, starting a room is for invited hosts only: signed in to icelander.net with the role games:laumufarthegi
// (HOST_ROLE), granted at icelander.net/private/admin. Everyone else joins from the shared link with just a name.
import { createAuth, sameOrigin, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { BASE, CODE_LENGTH, CODE_LETTERS, isCode, type CreatedRoom } from "../shared/protocol";

export { Room } from "./room";

interface Fetcher { fetch(req: Request): Promise<Response> }
interface RoomStub { fetch(req: Request | string, init?: RequestInit): Promise<Response> }
interface RoomNamespace { idFromName(name: string): unknown; get(id: unknown): RoomStub }

export interface Env extends AuthEnv {
  ASSETS: Fetcher;
  ROOMS: RoomNamespace;
  /** "1" turns on the sign-in library's stand-in sign-in (localhost only). */
  DEV_LOGIN?: string;
  /** "none" lets anyone start a room; anything else needs icelander.net's sign-in with HOST_ROLE. */
  HOST_SIGN_IN?: string;
  /** The role a host needs (default "games:play", which every signed-in player holds). */
  HOST_ROLE?: string;
}

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"] });
const shared = (env: Env): Env => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);
/** The role every signed-in player of icelander.net's games holds: the default for HOST_ROLE. */
const PLAY_ROLE = "games:play";

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (!url.pathname.startsWith(`${BASE}/`)) return new Response("Not found", { status: 404 });
    try {
      if (url.pathname === `${BASE}/api/me`) return await me(req, env);
      if (url.pathname === `${BASE}/api/rooms`) return await createRoom(req, env, url);
      const m = url.pathname.match(new RegExp(`^${BASE}/api/rooms/([A-Z]+)/ws$`));
      if (m) return await openSocket(req, env, url, m[1]);
      if (url.pathname.startsWith(`${BASE}/api/`)) return json({ error: "Not found" }, 404);
    } catch (e) {
      console.error(e);
      return json({ error: "Eitthvað fór úrskeiðis á þjóninum." }, 500);
    }
    if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
    const asset = await env.ASSETS.fetch(req);
    const out = new Response(asset.body, asset);
    if ((out.headers.get("Content-Type") ?? "").startsWith("text/html")) out.headers.set("Cache-Control", "no-cache");
    return out;
  },
};

/** Whether this visitor may start a room: open to all, or signed in to icelander.net with the host role. */
async function mayHost(req: Request, env: Env): Promise<{ ok: boolean; signedIn: boolean; name: string }> {
  if (env.HOST_SIGN_IN === "none") return { ok: true, signedIn: false, name: "" };
  const user = await AUTH.currentUser(req, shared(env));
  return { ok: !!user && AUTH.hasRole(user, env.HOST_ROLE || PLAY_ROLE), signedIn: !!user, name: user?.name ?? "" };
}

async function me(req: Request, env: Env): Promise<Response> {
  if (req.method !== "GET") return json({ error: "Method not allowed" }, 405);
  const h = await mayHost(req, env);
  return json({ canHost: h.ok, signedIn: h.signedIn, name: h.name, signIn: AUTH.signInPath(`${BASE}/`) }, 200, { "Cache-Control": "private, no-store" });
}

async function createRoom(req: Request, env: Env, url: URL): Promise<Response> {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);
  if (!sameOrigin(req, url)) return json({ error: "Forbidden" }, 403);
  const h = await mayHost(req, env);
  if (!h.ok && h.signedIn) return json({ error: "Aðeins boðnir gestgjafar geta stofnað leik. Þú getur samt gengið í leik með hlekk frá öðrum." }, 403);
  if (!h.ok) return json({ error: "Skráðu þig inn á icelander.net til að stofna leik.", signIn: AUTH.signInPath(`${BASE}/`) }, 401);
  const body = (await req.json().catch(() => ({}))) as { name?: unknown };
  const name = typeof body.name === "string" && body.name.trim() ? body.name : h.name;
  for (let tries = 0; tries < 6; tries++) {
    const code = randomCode();
    const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
    const r = await stub.fetch("https://room/create", { method: "POST", body: JSON.stringify({ code, name }), headers: { "Content-Type": "application/json" } });
    if (r.status === 409) continue;
    if (!r.ok) return json({ error: "Ekki tókst að stofna leik." }, 500);
    return json((await r.json()) as CreatedRoom, 201);
  }
  return json({ error: "Ekki tókst að finna laust leiknúmer. Reyndu aftur." }, 503);
}

async function openSocket(req: Request, env: Env, url: URL, code: string): Promise<Response> {
  if (!isCode(code)) return json({ error: "Not found" }, 404);
  if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
  const origin = req.headers.get("Origin");
  if (origin && origin !== url.origin) return new Response("Forbidden", { status: 403 });
  const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
  return stub.fetch(new Request("https://room/ws", req));
}

function randomCode(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(CODE_LENGTH));
  return [...bytes].map((b) => CODE_LETTERS[b % CODE_LETTERS.length]).join("");
}

function json(body: unknown, status = 200, headers: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json; charset=utf-8", ...headers } });
}
