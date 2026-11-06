// The Samosa Worker: serves the static game and a small high-score API.
//
//   POST {BASE}/api/game    → { id, seed }        a new reign's seed, issued by the server
//   POST {BASE}/api/score   ← { id, keys, email }  the keys pressed at every screen, in order
//                           → { score, rank, name }
//   GET  {BASE}/api/scores  → { scores: [...] }    the table, best first
//
// Scores are never trusted from the browser: the server replays the reign with the same
// engine, from the seed it issued and the keys the player pressed, and records the rating
// that replay produces. Each seed can be submitted once. Only the part of the email before
// the @ is ever returned; the full address is stored privately.
import { BASE, json, MAX_KEYS, publicName, replay, SEED_LIFETIME_MS, TABLE_SIZE, validEmail } from "./scores";

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
  let body: { id?: unknown; keys?: unknown; email?: unknown };
  try { body = await req.json(); } catch { return json({ error: "bad request" }, 400); }
  const { id, keys, email } = body;
  if (typeof id !== "string" || id.length > 64) return json({ error: "bad game id" }, 400);
  if (!Array.isArray(keys) || keys.length > MAX_KEYS || !keys.every((k) => typeof k === "string" && k.length <= 12)) return json({ error: "bad keys" }, 400);
  if (!validEmail(email)) return json({ error: "bad email" }, 400);

  const game = await env.DB.prepare("SELECT seed, created, used FROM games WHERE id = ?").bind(id).first<{ seed: number; created: number; used: number }>();
  if (!game || game.used || game.created < Date.now() - SEED_LIFETIME_MS) return json({ error: "unknown or used game" }, 409);

  const result = await replay(game.seed >>> 0, keys as string[]);
  if (!result) return json({ error: "the keys do not replay a whole reign" }, 422);

  const claim = await env.DB.prepare("UPDATE games SET used = 1 WHERE id = ? AND used = 0").bind(id).run();
  if (claim.meta.changes !== 1) return json({ error: "unknown or used game" }, 409);

  const name = publicName(email);
  await env.DB.prepare("INSERT INTO scores (id, email, name, score, months, alive, created) VALUES (?, ?, ?, ?, ?, ?, ?)")
    .bind(id, email, name, result.score, result.months, result.alive ? 1 : 0, Date.now()).run();
  const better = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE score > ?").bind(result.score).first<{ n: number }>();
  return json({ score: result.score, rank: (better?.n ?? 0) + 1, name });
}

async function topScores(env: Env): Promise<Response> {
  const { results } = await env.DB.prepare(
    "SELECT name, score, months, alive FROM scores ORDER BY score DESC, created ASC LIMIT ?",
  ).bind(TABLE_SIZE).all<{ name: string; score: number; months: number; alive: number }>();
  return json({ scores: results.map((r) => ({ name: r.name, score: r.score, months: r.months, alive: r.alive === 1 })) });
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
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
