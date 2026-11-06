// The Samosa Worker: serves the static game and a small high-score API.
//
//   POST {BASE}/api/game    → { id, seed }        a new reign's seed, issued by the server
//   POST {BASE}/api/score   ← { id, keys, name }   the keys pressed at every screen, in order, and a name
//                           → { score, rank, name }
//   GET  {BASE}/api/scores  → { scores: [...] }    the table, best first
//   GET  /games/retro/samosa/scores/                the table as a web page (worker/scores-page.ts)
//
// Scores are never trusted from the browser: the server replays the reign with the same
// engine, from the seed it issued and the keys the player pressed, and records the rating
// that replay produces. Each seed can be submitted once. The player gives only a name for the
// table (cleaned by src/name.ts); no email or other personal data is asked for or kept.
import { scoresPage } from "./scores-page";
import { BASE, OLD_PATH, PATH, json, MAX_KEYS, cleanName, replay, SEED_LIFETIME_MS, TABLE_SIZE } from "./scores";

/** The subset of Cloudflare's D1 and Fetcher types this Worker uses. */
interface D1Result<T> { results: T[]; meta: { changes: number } }
interface D1Statement { bind(...v: unknown[]): D1Statement; first<T>(): Promise<T | null>; all<T>(): Promise<D1Result<T>>; run(): Promise<D1Result<unknown>> }
interface D1Database { prepare(sql: string): D1Statement }
interface Fetcher { fetch(req: Request): Promise<Response> }
interface Env { DB: D1Database; ASSETS: Fetcher }

async function issueGame(env: Env): Promise<Response> {
  const id = crypto.randomUUID();
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  const now = Date.now();
  await env.DB.prepare("DELETE FROM games WHERE used = 0 AND created < ?").bind(now - SEED_LIFETIME_MS).run();
  await env.DB.prepare("INSERT INTO games (id, seed, created, used) VALUES (?, ?, ?, 0)").bind(id, seed, now).run();
  return json({ id, seed });
}

async function submitScore(req: Request, env: Env): Promise<Response> {
  let body: { id?: unknown; keys?: unknown; name?: unknown };
  try { body = await req.json(); } catch { return json({ error: "bad request" }, 400); }
  const { id, keys } = body;
  const name = cleanName(body.name);
  if (typeof id !== "string" || id.length > 64) return json({ error: "bad game id" }, 400);
  if (!Array.isArray(keys) || keys.length > MAX_KEYS || !keys.every((k) => typeof k === "string" && k.length <= 12)) return json({ error: "bad keys" }, 400);
  if (!name) return json({ error: "bad name" }, 400);

  const game = await env.DB.prepare("SELECT seed, created, used FROM games WHERE id = ?").bind(id).first<{ seed: number; created: number; used: number }>();
  if (!game || game.used || game.created < Date.now() - SEED_LIFETIME_MS) return json({ error: "unknown or used game" }, 409);

  const result = await replay(game.seed >>> 0, keys as string[]);
  if (!result) return json({ error: "the keys do not replay a whole reign" }, 422);

  const claim = await env.DB.prepare("UPDATE games SET used = 1 WHERE id = ? AND used = 0").bind(id).run();
  if (claim.meta.changes !== 1) return json({ error: "unknown or used game" }, 409);

  await env.DB.prepare("INSERT INTO scores (id, name, score, months, alive, created) VALUES (?, ?, ?, ?, ?, ?)")
    .bind(id, name, result.score, result.months, result.alive ? 1 : 0, Date.now()).run();
  const better = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE score > ?").bind(result.score).first<{ n: number }>();
  return json({ score: result.score, rank: (better?.n ?? 0) + 1, name });
}

async function loadTop(env: Env, size: number) {
  const { results } = await env.DB.prepare(
    "SELECT name, score, months, alive FROM scores ORDER BY score DESC, created ASC LIMIT ?",
  ).bind(size).all<{ name: string; score: number; months: number; alive: number }>();
  return results.map((r) => ({ name: r.name, score: r.score, months: r.months, alive: r.alive === 1 }));
}

async function topScores(env: Env): Promise<Response> {
  return json({ scores: await loadTop(env, TABLE_SIZE) });
}

const SCORES_PAGE = `${PATH}/scores`;
/** The web page lists more reigns than the game's own ten-row screen. */
const PAGE_SIZE = 25;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    // The game moved from /retro-games/samosa to /games/retro/samosa; 308 keeps the method.
    if (url.pathname === OLD_PATH || url.pathname.startsWith(OLD_PATH + "/")) {
      return new Response(null, { status: 308, headers: { Location: PATH + url.pathname.slice(OLD_PATH.length) + url.search, "Cache-Control": "no-store" } });
    }
    // The public high-score page.
    if (url.pathname === SCORES_PAGE || url.pathname === SCORES_PAGE + "/") {
      if (url.pathname === SCORES_PAGE) return Response.redirect(`${url.origin}${SCORES_PAGE}/`, 301);
      return scoresPage(await loadTop(env, PAGE_SIZE));
    }
    if (!url.pathname.startsWith(BASE + "/")) return env.ASSETS.fetch(req);
    const route = `${req.method} ${url.pathname.slice(BASE.length)}`;
    try {
      if (route === "POST /game") return await issueGame(env);
      if (route === "POST /score") return await submitScore(req, env);
      if (route === "GET /scores") return await topScores(env);
      return json({ error: "not found" }, 404);
    } catch {
      return json({ error: "server error" }, 500);
    }
  },
};
