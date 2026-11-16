// The Rampart Worker at icelander.net/games/retro/rampart: the static Godot web export (dist/), for anyone
// signed in to icelander.net. No API and no database: the high score lives in the player's browser.
//
//   GET {BASE}/            the game's page, for anyone holding games:play (others go to sign in and come back)
//   GET {BASE}/index.wasm  the Godot engine, stored in parts under Cloudflare's 25 MiB limit and joined here
//   anything else          a static asset
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

export const BASE = "/games/retro/rampart";
/** At most this many engine parts are joined (8 × 20 MiB is far more than the engine needs). */
const MAX_PARTS = 8;

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

/** icelander.net's one sign-in: the site's cookie, checked with its login service through the ACCOUNTS binding. */
const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

const isPage = (path: string) => path === `${BASE}/` || path === `${BASE}/index.html`;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (url.pathname === `${BASE}/index.wasm`) return joinedWasm(req, env, url);
    if (isPage(url.pathname)) {
      const { response } = await AUTH.requireRole(req, env, "games:play");
      if (response) return response;
      const page = await env.ASSETS.fetch(req);
      const out = new Response(page.body, page);
      out.headers.set("Cache-Control", "private, no-cache");
      return out;
    }
    return env.ASSETS.fetch(req);
  },
};

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
