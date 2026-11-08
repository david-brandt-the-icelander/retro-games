// The chess Worker at games.icelander.net/retro/chess: the static game (dist/), sign-in
// (worker/auth.ts), the JSON API (worker/api.ts) and one Durable Object per online game
// (worker/room.ts), with users, challenges, contacts and games in the D1 database "chess"
// (worker/schema.sql).
import { BASE } from "../src/shared/protocol";
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
    return env.ASSETS.fetch(req);
  },
};
