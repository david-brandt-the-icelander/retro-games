// The Dawn Chorus Worker at icelander.net/games/retro/dawn-chorus: the static page, photos and recordings, for anyone
// signed in to icelander.net (vendor/icelander-auth, through its login service). A visitor who isn't signed in is sent
// to the site's sign-in and back. No database and no secrets.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { BASE, ROLE } from "./config";

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher; DEV_LOGIN?: string }

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"] });

/** The library's env: DEV_LOGIN "1" turns on its stand-in sign-in (which works on localhost only). */
const shared = (env: Env): Env => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE) return Response.redirect(`${url.origin}${BASE}/${url.search}`, 301);
    if (!url.pathname.startsWith(`${BASE}/`)) return new Response("Not found", { status: 404 });
    if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });

    const { response } = await AUTH.requireRole(req, shared(env), ROLE);
    if (response) return response;

    const asset = await env.ASSETS.fetch(req);
    const out = new Response(asset.body, asset);
    const page = (out.headers.get("Content-Type") ?? "").startsWith("text/html");
    out.headers.set("Cache-Control", page ? "private, no-cache" : "private, max-age=3600");
    return out;
  },
};
