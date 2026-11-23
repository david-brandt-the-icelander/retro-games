// Kvarðinn's requests: who may fetch what, and where each request goes. Kept apart from index.ts
// (which also exports the Durable Object, and so runs only on Cloudflare) so the tests can call it.
//
// Under BASE it serves:
//
//   POST {BASE}/api/rooms   a new room: {"code":"ABCD"}
//   GET  {BASE}/ws/ABCD     the room's WebSocket (worker/room.ts, a Durable Object per code)
//   GET  {BASE}/...         the page and its files, from dist/ (build.mjs)
//
// On icelander.net every one of them is for signed-in players holding games:kvardinn, an
// invite-only role granted at icelander.net/private/admin. Sign-in is icelander.net's
// (vendor/icelander-auth, through its login service): a visitor who isn't signed in is sent to the
// site's sign-in and back; a signed-in player without the role gets a page saying so. The
// "standalone" environment (wrangler.jsonc), for hosting on another Cloudflare account, has no
// login service and sets OPEN to "1": there anyone with the link plays.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { CODE_RE, newCode } from "./codes";
import { BASE, ROLE } from "./config";

interface Fetcher { fetch(req: Request): Promise<Response> }
interface RoomStub { fetch(input: string | Request, init?: RequestInit): Promise<Response> }
interface Rooms { idFromName(name: string): unknown; get(id: unknown): RoomStub }

export interface Env extends AuthEnv {
  ASSETS: Fetcher;
  ROOMS: Rooms;
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
  "frame-ancestors 'none'",
].join("; ");

export async function handle(req: Request, env: Env): Promise<Response> {
  const url = new URL(req.url);
  const base = (env.BASE ?? BASE).replace(/\/+$/, "");
  if (base && url.pathname === base) return Response.redirect(`${url.origin}${base}/${url.search}${url.hash}`, 301);
  if (!url.pathname.startsWith(`${base}/`)) return new Response("Not found", { status: 404 });
  const rest = url.pathname.slice(base.length);

  if (env.OPEN !== "1") {
    const api = rest === "/api/rooms" || rest.startsWith("/ws/");
    const { response, user } = await AUTH.requireRole(req, shared(env), ROLE, { api });
    if (response) return user && !api ? notInvited() : response;
  }

  if (rest === "/api/rooms") {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405, headers: { Allow: "POST" } });
    for (let i = 0; i < 8; i++) {
      const code = newCode();
      const stub = env.ROOMS.get(env.ROOMS.idFromName(code));
      const res = await stub.fetch("https://room/init", { method: "POST", body: code });
      if (res.status === 201) return Response.json({ code }, { headers: { "Cache-Control": "no-store" } });
    }
    return Response.json({ error: "Gat ekki stofnað leik. Reyndu aftur." }, { status: 503 });
  }

  const ws = rest.match(/^\/ws\/([A-Za-z]{4})$/);
  if (ws) {
    const code = ws[1].toUpperCase();
    if (!CODE_RE.test(code)) return new Response("Not found", { status: 404 });
    if (req.headers.get("Upgrade") !== "websocket") return new Response("Expected a WebSocket", { status: 426 });
    return env.ROOMS.get(env.ROOMS.idFromName(code)).fetch(req);
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
  return out;
}

/** For a signed-in player without the role. */
function notInvited(): Response {
  const html = `<!doctype html>
<html lang="is"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Kvarðinn · boðsgestir</title><meta name="robots" content="noindex">
<style>body{margin:0;min-height:100vh;display:grid;place-items:center;background:#0a1020;color:#f3f6fb;font:20px/1.5 system-ui,sans-serif}
main{max-width:30rem;padding:2rem 1.25rem}h1{font-size:1.8rem;margin:0 0 .75rem}a{color:#36c6d8}</style></head>
<body><main><p><a href="/games/">Leikir</a> / Kvarðinn</p><h1>Kvarðinn</h1>
<p>Kvarðinn er aðeins fyrir boðsgesti og þessum aðgangi hefur ekki verið boðið enn.</p>
<p>Ef þér var boðið á öðru netfangi, skráðu þig inn með því. <a href="/games/">Aftur í leikina</a></p>
<p lang="en" style="color:#b3bdd0;font-size:.85em">Kvarðinn is open to invited players only, and this account hasn't been invited yet.</p></main></body></html>`;
  return new Response(html, { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
}

