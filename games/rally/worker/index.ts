// The Rally Worker: serves the static game and a small high-score API.
//
//   POST {BASE}/game    → { id, seed }                     a new one-player match's seed, issued by the server
//   POST {BASE}/score   ← { id, name, level, recording }   the player's paddle moves, tick by tick
//                       → { score, rank, name }
//   GET  {BASE}/scores  → { scores: [...] }                the table, best first
//   GET  /retro/rally/scores/                         the table as a web page (worker/scores-page.ts)
//
// Scores are never trusted from the browser: the server replays the match with the same engine,
// from the seed it issued, the computer's level and the player's recorded moves, and records the
// score that replay produces. Each seed can be submitted once. Only a name is stored.
import { createAuth, type AuthEnv } from "../../../vendor/icelander-auth/index.js";
import { scoresPage } from "./scores-page";
import { BASE, MAX_BODY, PAGE_SIZE, PATH, SCORES_PAGE, SEED_LIFETIME_MS, TABLE_SIZE, json, parseSubmission, verify, type Row } from "./scores";

/** The subset of Cloudflare's D1 and Fetcher types this Worker uses. */
interface D1Result<T> { results: T[]; meta: { changes: number } }
interface D1Statement { bind(...v: unknown[]): D1Statement; first<T>(): Promise<T | null>; all<T>(): Promise<D1Result<T>>; run(): Promise<D1Result<unknown>> }
interface D1Database { prepare(sql: string): D1Statement }
interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env extends AuthEnv { DB: D1Database; ASSETS: Fetcher }

/**
 * Every game on games.icelander.net needs a sign-in (the games hub's docs/SIGN-IN.md): the host's one cookie,
 * checked with icelander.net's login service through the ACCOUNTS binding. The hub answers /auth/… on this host.
 */
const AUTH = createAuth({ app: "games", cookie: "games_session" });

/** The game's page itself; its script, images and sounds come straight from the assets. */
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

async function issueGame(env: Env): Promise<Response> {
  const id = crypto.randomUUID();
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  const now = Date.now();
  await env.DB.prepare("DELETE FROM games WHERE used = 0 AND created < ?").bind(now - SEED_LIFETIME_MS).run();
  await env.DB.prepare("INSERT INTO games (id, seed, created, used) VALUES (?, ?, ?, 0)").bind(id, seed, now).run();
  return json({ id, seed });
}

async function submitScore(req: Request, env: Env): Promise<Response> {
  if (Number(req.headers.get("Content-Length") ?? 0) > MAX_BODY) return json({ error: "too large" }, 413);
  const text = await req.text();
  if (text.length > MAX_BODY) return json({ error: "too large" }, 413);
  let body: unknown;
  try { body = JSON.parse(text); } catch { return json({ error: "bad request" }, 400); }
  const sub = parseSubmission(body);
  if (typeof sub === "string") return json({ error: sub }, 400);

  const game = await env.DB.prepare("SELECT seed, created, used FROM games WHERE id = ?").bind(sub.id).first<{ seed: number; created: number; used: number }>();
  if (!game || game.used || game.created < Date.now() - SEED_LIFETIME_MS) return json({ error: "unknown or used game" }, 409);

  const result = verify(game.seed, sub);
  if (!result) return json({ error: "the moves do not replay a whole match" }, 422);

  const claim = await env.DB.prepare("UPDATE games SET used = 1 WHERE id = ? AND used = 0").bind(sub.id).run();
  if (claim.meta.changes !== 1) return json({ error: "unknown or used game" }, 409);

  await env.DB.prepare("INSERT INTO scores (id, name, score, level, mine, theirs, won, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?)")
    .bind(sub.id, sub.name, result.score, sub.level, result.mine, result.theirs, result.won ? 1 : 0, Date.now()).run();
  // Ties list oldest first, and this entry is the newest, so it ranks after every entry scoring as much.
  const ahead = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE score >= ?").bind(result.score).first<{ n: number }>();
  return json({ score: result.score, rank: Math.max(1, ahead?.n ?? 1), name: sub.name });
}

export async function loadTop(env: Env, size: number): Promise<Row[]> {
  const { results } = await env.DB.prepare(
    "SELECT name, score, level, mine, theirs, won FROM scores ORDER BY score DESC, created ASC LIMIT ?",
  ).bind(size).all<Omit<Row, "won"> & { won: number }>();
  return results.map((r) => ({ name: r.name, score: r.score, level: r.level, mine: r.mine, theirs: r.theirs, won: r.won === 1 }));
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    // The public high-score page.
    if (url.pathname === SCORES_PAGE) return Response.redirect(`${url.origin}${SCORES_PAGE}/`, 301);
    if (url.pathname === SCORES_PAGE + "/") return scoresPage(await loadTop(env, PAGE_SIZE));
    if (isPage(url.pathname)) return gamePage(req, env);
    if (!url.pathname.startsWith(BASE + "/")) return env.ASSETS.fetch(req);
    const route = `${req.method} ${url.pathname.slice(BASE.length)}`;
    // Playing, and so a new game's seed and a score, needs a sign-in; the table itself is public.
    if (req.method === "POST") {
      const { response } = await AUTH.requireRole(req, env, "games:play", { api: true });
      if (response) return response;
    }
    try {
      if (route === "POST /game") return await issueGame(env);
      if (route === "POST /score") return await submitScore(req, env);
      if (route === "GET /scores") return json({ scores: await loadTop(env, TABLE_SIZE) });
      return json({ error: "not found" }, 404);
    } catch {
      return json({ error: "server error" }, 500);
    }
  },
};
