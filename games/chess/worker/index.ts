// The chess Worker at games.icelander.net/retro/chess: the static game (dist/), sign-in
// (worker/auth.ts), the JSON API (worker/api.ts) and one Durable Object per online game
// (worker/room.ts), with users, challenges, contacts and games in the D1 database "chess"
// (worker/schema.sql).
import { BASE } from "../shared/protocol";
import { handleApi, json, type ApiEnv } from "./api";
import { handleAuth } from "./auth";

export { GameRoom } from "./room";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends ApiEnv { ASSETS: Fetcher }

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    try {
      if (url.pathname.startsWith(`${BASE}/api/`)) return await handleApi(req, env, url);
      if (url.pathname.startsWith(`${BASE}/auth/`)) {
        const r = await handleAuth(req, env, url);
        if (r) return r;
        return new Response("Not found", { status: 404 });
      }
    } catch (e) {
      console.error(e);
      return json({ error: "Something went wrong on the server." }, 500);
    }
    if (url.pathname === `${BASE}/index.wasm`) return joinedWasm(req, env, url);
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
