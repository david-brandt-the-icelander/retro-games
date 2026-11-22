// The MEG Worker: serves the static game behind icelander.net's sign-in, and its shared high-score table.
//
//   POST {BASE}/run     → { id }                          a ticket for a new run, issued when it starts
//   POST {BASE}/score   ← { id, name, score, file }       the run's score, once per ticket
//                       → { score, rank, name }
//   GET  {BASE}/scores  → { scores: [...] }                the table, best first
//   GET  /games/retro/meg/scores/                          the table as a web page (worker/scores-page.ts)
//
// The table lives in one Durable Object (ScoreTable, worker/scores.ts), created by the first deploy.
// Scores are trusted within limits the server can check (worker/scores.ts says which).
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { scoresPage } from "./scores-page";
import { BASE, MAX_BODY, PAGE_SIZE, PATH, SCORES_PAGE, TABLE_SIZE, json, parseSubmission, type Row } from "./scores";

export { ScoreTable } from "./scores";

interface Fetcher { fetch(req: Request): Promise<Response> }
interface DurableObjectNamespace { idFromName(name: string): unknown; get(id: unknown): Fetcher }
export interface Env extends AuthEnv { ASSETS: Fetcher; SCORES: DurableObjectNamespace }

/**
 * Every game under icelander.net/games needs a sign-in (the games hub's docs/SIGN-IN.md): the site's one cookie, site_session,
 * checked with icelander.net's login service through the ACCOUNTS binding. The site's Worker answers /auth/….
 */
const AUTH = createAuth({ app: "site", cookie: "site_session", home: "/games/", implicitRole: "reader", rolePrefixes: ["games"] });

/** The game's page itself; its script and stylesheet come straight from the assets. */
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

/** The one table. */
const table = (env: Env) => env.SCORES.get(env.SCORES.idFromName("table"));
const ask = (env: Env, method: string, path: string, body?: unknown) =>
  table(env).fetch(new Request(`https://scores${path}`, { method, body: body === undefined ? undefined : JSON.stringify(body) }));

export async function loadTop(env: Env, n: number): Promise<Row[]> {
  const res = await ask(env, "GET", `/top?n=${n}`);
  return ((await res.json()) as { scores: Row[] }).scores;
}

async function submitScore(req: Request, env: Env): Promise<Response> {
  if (Number(req.headers.get("Content-Length") ?? 0) > MAX_BODY) return json({ error: "too large" }, 413);
  const text = await req.text();
  if (text.length > MAX_BODY) return json({ error: "too large" }, 413);
  let body: unknown;
  try { body = JSON.parse(text); } catch { return json({ error: "bad request" }, 400); }
  const sub = parseSubmission(body);
  if (typeof sub === "string") return json({ error: sub }, 400);
  return ask(env, "POST", "/score", sub);
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === PATH) return Response.redirect(`${url.origin}${PATH}/${url.search}`, 301);
    // The public high-score page.
    if (url.pathname === SCORES_PAGE) return Response.redirect(`${url.origin}${SCORES_PAGE}/`, 301);
    if (url.pathname === SCORES_PAGE + "/") return scoresPage(await loadTop(env, PAGE_SIZE));
    if (isPage(url.pathname)) return gamePage(req, env);
    if (!url.pathname.startsWith(BASE + "/")) return env.ASSETS.fetch(req);
    const route = `${req.method} ${url.pathname.slice(BASE.length)}`;
    // Playing, and so a run's ticket and a score, needs a sign-in; the table itself is public.
    if (req.method === "POST") {
      const { response } = await AUTH.requireRole(req, env, "games:play", { api: true });
      if (response) return response;
    }
    try {
      if (route === "POST /run") return await ask(env, "POST", "/run");
      if (route === "POST /score") return await submitScore(req, env);
      if (route === "GET /scores") return json({ scores: await loadTop(env, TABLE_SIZE) });
      return json({ error: "not found" }, 404);
    } catch {
      return json({ error: "server error" }, 500);
    }
  },
};
