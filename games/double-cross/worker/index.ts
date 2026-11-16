// The Double Cross Worker at icelander.net/games/retro/double-cross: the Godot web build (dist/), whose
// page is for anyone signed in to icelander.net with games:play (every game under icelander.net/games
// needs a sign-in), and the engine, joined back from the parts the build split it into.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";

export const BASE = "/games/retro/double-cross";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher }

const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (url.pathname === `${BASE}/index.wasm`) return joinedWasm(req, env, url);
    if (url.pathname === `${BASE}/` || url.pathname === `${BASE}/index.html`) {
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

/** The Godot engine, stored as index.wasm.0, .1, … (each under Cloudflare's 25 MiB limit), streamed back as one file. */
async function joinedWasm(req: Request, env: Env, url: URL): Promise<Response> {
  const parts: Response[] = [];
  for (let i = 0; i < 8; i++) {
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
