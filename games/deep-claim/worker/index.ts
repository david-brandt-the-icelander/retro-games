// The Deep Claim Worker at icelander.net/games/retro/deep-claim: the static Godot web export (dist/),
// for anyone signed in to icelander.net. Every game under icelander.net/games needs a sign-in, checked
// with icelander.net's login service through the ACCOUNTS binding (vendor/icelander-auth). The game keeps
// no data on the server: the best haul is saved in the player's own browser.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

export const BASE = "/games/retro/deep-claim";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

/** The engine is stored in parts of at most 20 MiB (Cloudflare serves static files up to 25 MiB). */
export const MAX_PARTS = 8;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (url.pathname === `${BASE}/index.wasm`) return joinedWasm(req, env, url);
    if (url.pathname === `${BASE}/` || url.pathname === `${BASE}/index.html`) return gamePage(req, env);
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

/** The Godot engine, stored as index.wasm.0, .1, … by build.mjs, streamed back as one file. */
export async function joinedWasm(req: Request, env: Env, url: URL): Promise<Response> {
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
