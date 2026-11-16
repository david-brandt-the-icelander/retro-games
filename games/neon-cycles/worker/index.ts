// The Neon Cycles Worker: serves the static Godot game, and only to someone signed in to icelander.net.
// The game keeps nothing between visits, so there is no API and no database.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

export const PATH = "/games/retro/neon-cycles";

/**
 * Every game under icelander.net/games needs a sign-in (the games hub's docs/SIGN-IN.md): the site's one cookie, site_session,
 * checked with icelander.net's login service through the ACCOUNTS binding. The site's Worker answers /auth/….
 */
const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

/** The game's page itself; the engine, its data and the page's script and stylesheet come from the assets. */
const isPage = (path: string) => path === `${PATH}/` || path === `${PATH}/index.html`;

/** The page, for anyone signed in; anyone else goes to sign in and comes back. */
async function gamePage(req: Request, env: Env): Promise<Response> {
  const { response } = await AUTH.requireRole(req, env, "games:play");
  if (response) return response;
  const page = await env.ASSETS.fetch(req);
  const out = new Response(page.body, page);
  out.headers.set("Cache-Control", "private, no-cache");
  return out;
}

/** The Godot engine, stored as index.wasm.0, .1, … (each under Cloudflare's 25 MiB limit), streamed back as one file. */
async function joinedWasm(req: Request, env: Env, url: URL): Promise<Response> {
  const parts: Response[] = [];
  for (let i = 0; i < 8; i++) {
    const r = await env.ASSETS.fetch(new Request(new URL(`${PATH}/index.wasm.${i}`, url), { headers: req.headers }));
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

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === PATH) return Response.redirect(`${url.origin}${PATH}/${url.search}`, 301);
    if (isPage(url.pathname)) return gamePage(req, env);
    if (url.pathname === `${PATH}/index.wasm`) return joinedWasm(req, env, url);
    return env.ASSETS.fetch(req);
  },
};
