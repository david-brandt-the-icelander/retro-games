// The Iron Haze Worker at icelander.net/games/fresh/iron-haze: every file (the landing page, the web build under
// play/ and the desktop builds under download/) is for signed-in players holding games:iron-haze, an invite-only
// role granted at icelander.net/private/admin. Sign-in is icelander.net's (vendor/icelander-auth, through its
// login service): a visitor who isn't signed in is sent to the site's sign-in and back; a signed-in player without
// the role gets a page saying so. The engine and the downloads are stored in parts under Cloudflare's 25 MiB limit
// and joined here (build.mjs).
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { BASE, ROLE } from "./config";
const PARTS_MAX = 16;

interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { ASSETS: Fetcher; DEV_LOGIN?: string }

const AUTH = createAuth({ app: "site", cookie: "site_session", home: `${BASE}/`, implicitRole: "reader", rolePrefixes: ["games"] });

/** The library's env: DEV_LOGIN "1" turns on its stand-in sign-in (which works on localhost only). */
const shared = (env: Env): Env => (env.DEV_LOGIN === "1" ? { ...env, DEV_SIGN_IN: "true" } : env);

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === BASE || url.pathname === `${BASE}/play`) return Response.redirect(`${url.origin}${url.pathname}/${url.search}`, 301);
    if (!url.pathname.startsWith(`${BASE}/`)) return new Response("Not found", { status: 404 });
    if (req.method !== "GET" && req.method !== "HEAD") return new Response("Method not allowed", { status: 405, headers: { Allow: "GET, HEAD" } });

    // The stylesheet and the icon are the only public files: the page for a player who isn't invited uses them.
    const rest = url.pathname.slice(BASE.length);
    if (rest === "/shell.css" || rest === "/favicon.svg") return env.ASSETS.fetch(req);

    const { response, user } = await AUTH.requireRole(req, shared(env), ROLE);
    if (response) return user ? notInvited() : response;

    if (rest === "/play/index.wasm") return joined(req, env, url, "application/wasm", null);
    const download = /^\/download\/(iron-haze-(?:windows|macos|linux)\.zip)$/.exec(rest);
    if (download) return joined(req, env, url, "application/zip", download[1]);
    if (rest.startsWith("/download/")) return new Response("Not found", { status: 404 });

    const asset = await env.ASSETS.fetch(req);
    const out = new Response(asset.body, asset);
    const page = (out.headers.get("Content-Type") ?? "").startsWith("text/html");
    out.headers.set("Cache-Control", page ? "private, no-cache" : "private, max-age=3600");
    return out;
  },
};

/** A file stored as name.0, name.1, …, streamed back as one. `attachment` names the download, if it is one. */
async function joined(req: Request, env: Env, url: URL, type: string, attachment: string | null): Promise<Response> {
  const parts: Response[] = [];
  for (let i = 0; i < PARTS_MAX; i++) {
    const r = await env.ASSETS.fetch(new Request(new URL(`${url.pathname}.${i}`, url), { headers: req.headers }));
    if (!r.ok || !r.body) break;
    parts.push(r);
  }
  if (!parts.length) return new Response("Not found", { status: 404, headers: { "Cache-Control": "no-store" } });
  const total = parts.reduce((n, r) => n + Number(r.headers.get("Content-Length") ?? NaN), 0);
  const headers = new Headers({ "Content-Type": type, "Cache-Control": "private, max-age=3600", "X-Content-Type-Options": "nosniff" });
  if (attachment) headers.set("Content-Disposition", `attachment; filename="${attachment}"`);
  if (Number.isFinite(total)) headers.set("Content-Length", String(total));
  if (req.method === "HEAD") {
    for (const p of parts) await p.body?.cancel();
    return new Response(null, { headers });
  }
  const { readable, writable } = new TransformStream();
  void (async () => {
    for (const p of parts) await p.body!.pipeTo(writable, { preventClose: true });
    await writable.close();
  })();
  return new Response(readable, { headers });
}

/** For a signed-in player without the role. */
function notInvited(): Response {
  const html = `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Iron Haze · invited players</title><meta name="robots" content="noindex">
<link rel="icon" href="${BASE}/favicon.svg" type="image/svg+xml"><link rel="stylesheet" href="${BASE}/shell.css"></head>
<body class="page"><div class="wrap"><nav class="crumbs" aria-label="Breadcrumb"><a href="/games/">Games</a> / Iron Haze</nav>
<section class="panel"><p class="eyebrow">Invited players</p><h1 class="title">IRON HAZE</h1>
<p class="lede">Iron Haze is open to invited players only, and this account hasn't been invited yet.</p>
<p class="note">If you were invited at another address, sign in with that one. <a class="btn line" href="/games/">Back to the games</a></p>
</section></div></body></html>`;
  return new Response(html, { status: 403, headers: { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "private, no-store" } });
}
