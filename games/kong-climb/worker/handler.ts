// Kong Climb's requests: who may fetch what. The game runs entirely in the browser, so the Worker has no
// API, no database and no secrets; it only checks the sign-in and serves the page and its files from dist/.
//
// On icelander.net every request is for a signed-in player holding games:recreations, an invite-only
// role granted at icelander.net/private/admin. Sign-in is icelander.net's (vendor/icelander-auth,
// through its login service): a visitor who isn't signed in is sent to the site's sign-in and back; a
// signed-in player without the role gets a page saying so. The "standalone" environment (wrangler.jsonc)
// has no login service and sets OPEN to "1": there anyone with the link plays.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { BASE, ROLE } from "./config";

interface Fetcher {
  fetch(req: Request): Promise<Response>;
}

export interface Env extends AuthEnv {
  ASSETS: Fetcher;
  /** The path the game lives under, without a trailing slash; "" at a domain's root. Default BASE. */
  BASE?: string;
  /** "1": no sign-in at all (the standalone environment only). */
  OPEN?: string;
  /** "1" turns on the library's stand-in sign-in, which works on localhost only. */
  DEV_LOGIN?: string;
}

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"] });

/** The library's env: DEV_LOGIN "1" turns on its stand-in sign-in (which works on localhost only). */
const shared = (env: Env): Env => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);

const CSP = [
  "default-src 'self'",
  "connect-src 'self'",
  "img-src 'self' data:",
  "style-src 'self' 'unsafe-inline'",
  "script-src 'self'",
  "base-uri 'none'",
  "form-action 'none'",
  "frame-ancestors 'none'",
  "object-src 'none'",
].join("; ");

export async function handle(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const base = (env.BASE ?? BASE).replace(/\/+$/, "");
  if (base && url.pathname === base) return Response.redirect(`${url.origin}${base}/${url.search}${url.hash}`, 301);
  if (!url.pathname.startsWith(`${base}/`)) return new Response("Not found", { status: 404 });
  const rest = url.pathname.slice(base.length);

  if (env.OPEN !== "1") {
    const { response, user } = await AUTH.requireRole(req, shared(env), ROLE, { api: false });
    if (response) return user ? notInvited() : response;
  }

  if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });
  const asset = await env.ASSETS.fetch(new Request(new URL(rest + url.search, url.origin), req));
  const out = new Response(asset.body, asset);
  // The assets binding redirects /index.html to /; keep such redirects under BASE.
  const loc = out.headers.get("Location");
  if (loc && loc.startsWith("/")) out.headers.set("Location", base + loc);
  const page = (out.headers.get("Content-Type") ?? "").startsWith("text/html");
  const scope = env.OPEN === "1" ? "public" : "private";
  out.headers.set("Cache-Control", page ? `${scope}, no-cache` : `${scope}, max-age=300`);
  out.headers.set("Content-Security-Policy", CSP);
  out.headers.set("X-Content-Type-Options", "nosniff");
  out.headers.set("Referrer-Policy", "same-origin");
  out.headers.set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=()");
  return out;
}

/** For a signed-in player without the role. */
function notInvited(): Response {
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kong Climb · invited players only</title><meta name="robots" content="noindex">
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#05060a;color:#f3f6fb;font:18px/1.5 system-ui,sans-serif}
main{max-width:30rem;padding:0 1.25rem 2rem}h1{font-size:1.8rem;margin:0 0 .75rem}a{color:#46d8e6}
.art{height:8rem;margin:0 -1.25rem 1.25rem;background:linear-gradient(#1a0a0d,#05060a);display:grid;place-items:center;font:800 1.3rem "Courier New",monospace;letter-spacing:.1em;color:#ffd84a}
.pitch{color:#b3bdd0}</style></head>
<body><main><div class="art" aria-hidden="true">KONG CLIMB</div><p><a href="/games/">Games</a> / Kong Climb</p><h1>Kong Climb</h1>
<p class="pitch">A recreation of the 1981 arcade climber: dodge the ape's barrels across four stages and rescue the captive.</p>
<p>It is for invited players only, and this account has not been invited yet.</p>
<p>If you were invited under another email address, sign in with that one. <a href="/games/">Back to the games</a></p></main></body></html>`;
  return new Response(html, { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
}
