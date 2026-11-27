// The Lundey Worker at icelander.net/games/lundey: every file is for signed-in players holding games:lundey, an
// invite-only role granted at icelander.net/private/admin. Sign-in is icelander.net's (vendor/icelander-auth,
// through its login service): a visitor who isn't signed in is sent to the site's sign-in and back; a signed-in
// player without the role gets a page saying so. The game itself runs in the browser; the Worker keeps nothing.
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

    const { response, user } = await AUTH.requireRole(req, shared(env), ROLE);
    if (response) return user ? notInvited() : response;

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
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lundey · invited players</title><meta name="robots" content="noindex">
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0b1a2b;color:#f4ecd8;font:17px/1.5 system-ui,sans-serif}
main{max-width:30rem;padding:2rem 1.25rem}h1{font-size:1.6rem;margin:0 0 .75rem}a{color:#ffe27a}</style></head>
<body><main><p><a href="/games/">Games</a> / Lundey</p><h1>Lundey</h1>
<p>Lundey is open to invited players only, and this account hasn't been invited yet.</p>
<p>If you were invited at another address, sign in with that one. <a href="/games/">Back to the games</a></p></main></body></html>`;
  return new Response(html, { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
}
