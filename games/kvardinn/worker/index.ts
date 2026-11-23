// The Kvarðinn Worker. Under BASE (icelander.net/games/fresh/kvardinn, or the root of a
// workers.dev address for the "standalone" environment) it serves:
//
//   POST {BASE}/api/rooms   a new room: {"code":"ABCD"}
//   GET  {BASE}/ws/ABCD     the room's WebSocket (worker/room.ts, a Durable Object per code)
//   GET  {BASE}/...         the page and its files, from dist/ (build.mjs)
//
// No sign-in, on purpose: players join from one shared link with only a name (README.md).
import { CODE_RE, newCode } from "./codes";
import { Room } from "./room";

export { Room };

interface Env {
  ASSETS: Fetcher;
  ROOMS: DurableObjectNamespace;
  /** The path the game lives under, without a trailing slash; "" at a domain's root. */
  BASE?: string;
}

const CSP = [
  "default-src 'self'",
  "connect-src 'self'",
  "img-src 'self' data:",
  "style-src 'self' 'unsafe-inline'",
  "script-src 'self'",
  "base-uri 'none'",
  "frame-ancestors 'none'",
].join("; ");

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    const base = (env.BASE ?? "").replace(/\/+$/, "");
    if (base && url.pathname === base) return Response.redirect(`${url.origin}${base}/${url.search}${url.hash}`, 301);
    if (!url.pathname.startsWith(`${base}/`)) return new Response("Not found", { status: 404 });
    const rest = url.pathname.slice(base.length);

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
    out.headers.set("Cache-Control", page ? "no-cache" : "public, max-age=300");
    out.headers.set("Content-Security-Policy", CSP);
    out.headers.set("X-Content-Type-Options", "nosniff");
    out.headers.set("Referrer-Policy", "same-origin");
    return out;
  },
};
