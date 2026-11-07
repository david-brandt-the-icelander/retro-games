// The Hivestorm Worker: serves the static game and a small high-score API.
//
//   POST {BASE}/game    → { id, seed }                     a new game's seed, issued by the server
//   POST {BASE}/score   ← { id, runs, names }              the game's recorded controls, and a name (or null) per player
//                       → { entries: [{ player, name, score, wave, rank }] }
//   GET  {BASE}/scores  → { scores: [...] }                the table, best first
//   GET  /games/retro/hivestorm/scores/                    the table as a web page (worker/scores-page.ts)
//   GET  {BASE}/room/{CODE}                                a WebSocket to an online room (worker/room.ts)
//
// Scores are never trusted from the browser: the server plays the game again with the same engine,
// from the seed it issued and the controls the players used on every frame (src/engine/replay.ts),
// and records the scores that replay produces. Each seed can be submitted once. Players give only a
// name for the table (cleaned by src/name.ts); no email or other personal data is asked for or kept.
import { Room, roomRequest, type RoomEnv } from "./room";
import { scoresPage } from "./scores-page";
import { BASE, MAX_BODY_BYTES, PAGE_SIZE, PATH, SEED_LIFETIME_MS, TABLE_SIZE, cleanName, json, replay } from "./scores";

/** The subset of Cloudflare's D1 and Fetcher types this Worker uses. */
interface D1Result<T> { results: T[]; meta: { changes: number } }
interface D1Statement { bind(...v: unknown[]): D1Statement; first<T>(): Promise<T | null>; all<T>(): Promise<D1Result<T>>; run(): Promise<D1Result<unknown>> }
interface D1Database { prepare(sql: string): D1Statement }
interface Fetcher { fetch(req: Request): Promise<Response> }
interface Rooms { idFromName(name: string): unknown; get(id: unknown): { fetch(req: Request): Promise<Response> } }
export interface Env extends RoomEnv { DB: D1Database; ASSETS: Fetcher; ROOMS: Rooms }

/** Online rooms are Durable Objects; Cloudflare finds the class by this export. */
export { Room };

async function issueGame(env: Env): Promise<Response> {
  const id = crypto.randomUUID();
  const seed = crypto.getRandomValues(new Uint32Array(1))[0];
  const now = Date.now();
  await env.DB.prepare("DELETE FROM games WHERE used = 0 AND created < ?").bind(now - SEED_LIFETIME_MS).run();
  await env.DB.prepare("INSERT INTO games (id, seed, created, used) VALUES (?, ?, ?, 0)").bind(id, seed, now).run();
  return json({ id, seed });
}

async function submitScore(req: Request, env: Env): Promise<Response> {
  const text = await req.text();
  if (text.length > MAX_BODY_BYTES) return json({ error: "too large" }, 413);
  let body: { id?: unknown; runs?: unknown; names?: unknown };
  try { body = JSON.parse(text); } catch { return json({ error: "bad request" }, 400); }
  const { id, runs } = body;
  if (typeof id !== "string" || id.length > 64) return json({ error: "bad game id" }, 400);
  if (!Array.isArray(body.names) || body.names.length < 1 || body.names.length > 2) return json({ error: "bad names" }, 400);
  const names = body.names.map((n) => (n === null ? null : cleanName(n) || undefined));
  if (names.includes(undefined) || names.every((n) => n === null)) return json({ error: "bad name" }, 400);

  const game = await env.DB.prepare("SELECT seed, created, used FROM games WHERE id = ?").bind(id).first<{ seed: number; created: number; used: number }>();
  if (!game || game.used || game.created < Date.now() - SEED_LIFETIME_MS) return json({ error: "unknown or used game" }, 409);

  const result = replay(game.seed >>> 0, runs);
  if (!result || names.length !== result.players) return json({ error: "the controls do not replay a whole game" }, 422);

  const claim = await env.DB.prepare("UPDATE games SET used = 1 WHERE id = ? AND used = 0").bind(id).run();
  if (claim.meta.changes !== 1) return json({ error: "unknown or used game" }, 409);

  const entries = [];
  for (let player = 0; player < result.players; player++) {
    const name = names[player];
    const { score, wave } = result.scores[player];
    if (!name || score <= 0) continue;
    await env.DB.prepare("INSERT INTO scores (game, player, name, score, wave, players, created) VALUES (?, ?, ?, ?, ?, ?, ?)")
      .bind(id, player, name, score, wave, result.players, Date.now()).run();
    const better = await env.DB.prepare("SELECT COUNT(*) AS n FROM scores WHERE score > ?").bind(score).first<{ n: number }>();
    entries.push({ player: player + 1, name, score, wave, rank: (better?.n ?? 0) + 1 });
  }
  return json({ entries });
}

async function loadTop(env: Env, size: number) {
  const { results } = await env.DB.prepare(
    "SELECT name, score, wave, players FROM scores ORDER BY score DESC, created ASC LIMIT ?",
  ).bind(size).all<{ name: string; score: number; wave: number; players: number }>();
  return results.map((r) => ({ name: r.name, score: r.score, wave: r.wave, players: r.players }));
}

const SCORES_PAGE = `${PATH}/scores`;

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const url = new URL(req.url);
    if (url.pathname === SCORES_PAGE || url.pathname === SCORES_PAGE + "/") {
      if (url.pathname === SCORES_PAGE) return Response.redirect(`${url.origin}${SCORES_PAGE}/`, 301);
      return scoresPage(await loadTop(env, PAGE_SIZE));
    }
    if (!url.pathname.startsWith(BASE + "/")) return env.ASSETS.fetch(req);
    const rooms = roomRequest(req, url.pathname.slice(BASE.length), env.ROOMS);
    if (rooms) return rooms;
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
