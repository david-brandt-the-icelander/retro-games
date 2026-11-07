// The Shatterbelt Worker: serves the static game, a small high-score API and the high-score page.
//
//   POST {BASE}/game    → { id, seed }               a new game's seed, issued by the server
//   POST {BASE}/score   ← { id, recording, names }   every change of every player's controls
//                       → { results: [{ player, score, wave, name, rank }] }
//   GET  {BASE}/scores  → { scores: [...] }          the table, best first
//   GET  /games/retro/shatterbelt/scores/            the table as a web page (worker/scores-page.ts)
//
// Scores are never trusted from the browser: the server replays the game with the same engine,
// from the seed it issued and the recorded controls, and lists the scores that replay produces.
// Each seed can be submitted once.
import { scoresPage, type Row } from "./scores-page";
import { BASE, MAX_BODY, OLD_PATH, PAGE_SIZE, PATH, SCORES_PAGE, SEED_LIFETIME_MS, TABLE_SIZE, cleanName, json, score, validSubmission } from "./scores";

/** The subset of Cloudflare's D1 and Fetcher types this Worker uses. */
interface D1Result<T> { results: T[]; meta: { changes: number } }
interface D1Statement { bind(...v: unknown[]): D1Statement; first<T>(): Promise<T | null>; all<T>(): Promise<D1Result<T>>; run(): Promise<D1Result<unknown>> }
interface D1Database { prepare(sql: string): D1Statement; batch(statements: D1Statement[]): Promise<unknown> }
interface Fetcher { fetch(req: Request): Promise<Response> }
export interface Env { DB: D1Database; ASSETS: Fetcher }

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
  if (!validSubmission(body)) return json({ error: "bad submission" }, 400);

  const game = await env.DB.prepare("SELECT seed, created, used FROM games WHERE id = ?").bind(body.id).first<{ seed: number; created: number; used: number }>();
  if (!game || game.used || game.created < Date.now() - SEED_LIFETIME_MS) return json({ error: "unknown or used game" }, 409);

  const results = score(game.seed, body);
  if (!results) return json({ error: "the recording does not replay a whole game" }, 422);

  const claim = await env.DB.prepare("UPDATE games SET used = 1 WHERE id = ? AND used = 0").bind(body.id).run();
  if (claim.meta.changes !== 1) return json({ error: "unknown or used game" }, 409);

  const now = Date.now();
  const { mode, players } = body.recording;
  const entered = results
    .map((r) => ({ ...r, name: cleanName(body.names[r.player]) }))
    .filter((r) => r.name !== "" && r.score > 0);
  if (entered.length) {
    await env.DB.batch(entered.map((r) =>
      env.DB.prepare("INSERT INTO scores (id, game, player, name, score, wave, mode, players, created) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)")
        .bind(`${body.id}:${r.player}`, body.id, r.player, r.name, r.score, r.wave, mode, players, now)));
  }
  const out = [];
  for (const r of results) {
    const name = entered.find((e) => e.player === r.player)?.name ?? null;
    let rank: number | null = null;
    if (name) {
      const better = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE score > ?").bind(r.score).first<{ n: number }>();
      rank = (better?.n ?? 0) + 1;
    }
    out.push({ ...r, name, rank });
  }
  return json({ results: out });
}

async function loadTop(env: Env, size: number): Promise<Row[]> {
  const { results } = await env.DB.prepare(
    "SELECT name, score, wave, mode, players FROM scores ORDER BY score DESC, created ASC LIMIT ?",
  ).bind(size).all<Row>();
  return results.map((r) => ({ name: r.name, score: r.score, wave: r.wave, mode: r.mode, players: r.players }));
}

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    // The game moved from /retro-games/shatterbelt to /games/retro/shatterbelt; 308 keeps the method.
    if (url.pathname === OLD_PATH || url.pathname.startsWith(OLD_PATH + "/")) {
      const rest = url.pathname.slice(OLD_PATH.length) || "/";
      return new Response(null, { status: 308, headers: { Location: PATH + rest + url.search, "Cache-Control": "no-store" } });
    }
    if (url.pathname === SCORES_PAGE) return Response.redirect(`${url.origin}${SCORES_PAGE}/`, 301);
    if (url.pathname === SCORES_PAGE + "/") {
      try {
        return scoresPage(await loadTop(env, PAGE_SIZE));
      } catch {
        return json({ error: "server error" }, 500);
      }
    }
    if (!url.pathname.startsWith(BASE + "/")) return env.ASSETS.fetch(req);
    const route = `${req.method} ${url.pathname.slice(BASE.length)}`;
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
