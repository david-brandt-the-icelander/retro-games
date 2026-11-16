// The Neon Snake Worker at icelander.net/games/retro/snake: the static game (dist/), for anyone signed in to
// icelander.net (every game under icelander.net/games needs a sign-in), and Godot's engine file joined from
// its parts. The game keeps its best score in the browser; there is no API and no database.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

export const BASE = "/games/retro/snake";
/** Cloudflare serves static files of at most 25 MiB; build.mjs stores the engine in parts under that. */
const MAX_PARTS = 8;

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

/** The site's one sign-in: its cookie, checked with icelander.net's login service through the ACCOUNTS binding. */
const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (url.pathname === `${BASE}/` || url.pathname === `${BASE}/index.html`) return gamePage(req, env);
    if (url.pathname === `${BASE}/index.wasm`) return joinedWasm(req, env, url);
    return env.ASSETS.fetch(req);
  },
};

/** The page, for anyone signed in; anyone else goes to sign in and comes back. */
async function gamePage(req: Request, env: Env): Promise<Response> {
  const { response } = await AUTH.requireRole(req, env, "games:play");
  if (response) return response;
  const page = await env.ASSETS.fetch(req);
  const out = new Response(page.body, page);
  out.headers.set("Cache-Control", "private, no-cache");
  return out;
}

/** The Godot engine, stored as index.wasm.0, .1, … and streamed back as one file. */
async function joinedWasm(req: Request, env: Env, url: URL): Promise<Response> {
  const parts: Response[] = [];
  for (let i = 0; i < MAX_PARTS; i++) {
    const r = await env.ASSETS.fetch(new Request(new URL(`${BASE}/index.wasm.${i}`, url), { headers: req.headers }));
    if (!r.ok || !r.body) break;
    parts.push(r);
  }
  if (!parts.length) return new Response("Not found", { status: 404 });
  const total = parts.reduce((n, r) => n + Number(r.headers.get("Content-Length") ?? NaN), 0);
  const { readable, writable } = new TransformStream();
  void (async () => {
    for (const p of parts) await p.body!.pipeTo(writable, { preventClose: true });
    await writable.close();
  })();
  const headers = new Headers({ "Content-Type": "application/wasm", "Cache-Control": "public, max-age=3600", "X-Content-Type-Options": "nosniff" });
  if (Number.isFinite(total)) headers.set("Content-Length", String(total));
  return new Response(readable, { headers });
}
