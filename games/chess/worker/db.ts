// The D1 queries. The interfaces are the subset of Cloudflare's D1 types this Worker uses, so the
// tests can run the same queries on node:sqlite (test/fake-d1.ts).
import type { Challenge, Contact, GameEvent, GameView, PlayerRef, User } from "../shared/protocol";
import type { Reason, Result, Side } from "../shared/rules";
import { LEVELS } from "../shared/protocol";

export interface D1Result<T> { results: T[]; meta: { changes: number } }
export interface D1Statement { bind(...v: unknown[]): D1Statement; first<T>(): Promise<T | null>; all<T>(): Promise<D1Result<T>>; run(): Promise<D1Result<unknown>> }
export interface D1Database { prepare(sql: string): D1Statement; batch(statements: D1Statement[]): Promise<unknown> }

export const newId = () => crypto.randomUUID().replace(/-/g, "").slice(0, 20);
export const avatarPath = (id: string, picture: string | null | undefined) => (picture ? `api/avatar/${id}` : null);

// ── Users ──

/** Signs a user in: creates them, or refreshes their name and picture from the provider. */
export async function upsertUser(db: D1Database, email: string, name: string, picture: string | null, now: number): Promise<User> {
  const existing = await db.prepare("SELECT id, email, name, picture FROM users WHERE email = ?").bind(email).first<User>();
  const display = name || existing?.name || email.split("@")[0];
  if (existing) {
    await db.prepare("UPDATE users SET name = ?, picture = COALESCE(?, picture), last_seen = ? WHERE id = ?").bind(display, picture, now, existing.id).run();
    return { ...existing, name: display, picture: picture ?? existing.picture };
  }
  const user: User = { id: newId(), email, name: display, picture };
  await db.prepare("INSERT INTO users (id, email, name, picture, created, last_seen) VALUES (?, ?, ?, ?, ?, ?)").bind(user.id, email, display, picture, now, now).run();
  return user;
}

export const userById = (db: D1Database, id: string) =>
  db.prepare("SELECT id, email, name, picture FROM users WHERE id = ?").bind(id).first<User>();

export const userByEmail = (db: D1Database, email: string) =>
  db.prepare("SELECT id, email, name, picture FROM users WHERE email = ?").bind(email).first<User>();

// ── Sessions ──

export async function createSession(db: D1Database, tokenHash: string, userId: string, now: number, lifetime: number): Promise<void> {
  await db.prepare("DELETE FROM sessions WHERE expires < ?").bind(now).run();
  await db.prepare("INSERT INTO sessions (token_hash, user_id, created, expires) VALUES (?, ?, ?, ?)").bind(tokenHash, userId, now, now + lifetime).run();
}

export const sessionUser = (db: D1Database, tokenHash: string, now: number) =>
  db.prepare("SELECT u.id, u.email, u.name, u.picture FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ? AND s.expires > ?")
    .bind(tokenHash, now).first<User>();

export async function deleteSession(db: D1Database, tokenHash: string): Promise<void> {
  await db.prepare("DELETE FROM sessions WHERE token_hash = ?").bind(tokenHash).run();
}

// ── Games ──

interface GameRow {
  id: string; kind: string; level: number | null; white_user: string | null; black_user: string | null;
  moves: string; result: string; reason: string | null; draw_offer: string | null; created: number; updated: number;
  w_email: string | null; w_name: string | null; w_pic: string | null; b_email: string | null; b_name: string | null; b_pic: string | null;
}

const GAME_SELECT = `SELECT g.*, w.email AS w_email, w.name AS w_name, w.picture AS w_pic, b.email AS b_email, b.name AS b_name, b.picture AS b_pic
  FROM games g LEFT JOIN users w ON w.id = g.white_user LEFT JOIN users b ON b.id = g.black_user`;

function player(id: string | null, email: string | null, name: string | null, pic: string | null, level: number | null): PlayerRef {
  if (id) return { id, email, name: name ?? email ?? "?", avatar: avatarPath(id, pic) };
  return { id: null, email: null, name: level ? `Stockfish · ${LEVELS[level - 1]?.name ?? level}` : "Stockfish", avatar: null };
}

export function toView(r: GameRow, events: GameEvent[] = []): GameView {
  return {
    id: r.id,
    kind: r.kind === "computer" ? "computer" : "online",
    level: r.level,
    white: player(r.white_user, r.w_email, r.w_name, r.w_pic, r.level),
    black: player(r.black_user, r.b_email, r.b_name, r.b_pic, r.level),
    moves: r.moves ? r.moves.split(" ") : [],
    result: r.result as Result,
    reason: (r.reason as Reason | null) ?? null,
    drawOffer: (r.draw_offer as Side | null) ?? null,
    created: r.created,
    updated: r.updated,
    events,
  };
}

export async function gameEvents(db: D1Database, id: string): Promise<GameEvent[]> {
  const r = await db.prepare("SELECT seq, at, kind, side, text FROM game_events WHERE game_id = ? ORDER BY seq").bind(id).all<GameEvent>();
  return r.results.map((e) => ({ seq: e.seq, at: e.at, kind: e.kind, side: e.side ?? null, text: e.text ?? null }));
}

/** A game with its whole transcript. */
export async function gameById(db: D1Database, id: string): Promise<GameView | null> {
  const r = await db.prepare(`${GAME_SELECT} WHERE g.id = ?`).bind(id).first<GameRow>();
  return r ? toView(r, await gameEvents(db, id)) : null;
}

const insertEvent = (db: D1Database, gameId: string, e: GameEvent) =>
  db.prepare("INSERT INTO game_events (game_id, seq, at, kind, side, text) VALUES (?, ?, ?, ?, ?, ?)").bind(gameId, e.seq, e.at, e.kind, e.side, e.text);

export async function insertGame(db: D1Database, g: { id: string; kind: "online" | "computer"; level: number | null; white: string | null; black: string | null; moves: string[]; result: Result; reason: Reason | null; now: number; events: GameEvent[] }): Promise<void> {
  await db.batch([
    db.prepare("INSERT INTO games (id, kind, level, white_user, black_user, moves, result, reason, draw_offer, created, updated) VALUES (?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?)")
      .bind(g.id, g.kind, g.level, g.white, g.black, g.moves.join(" "), g.result, g.reason, g.now, g.now),
    ...g.events.map((e) => insertEvent(db, g.id, e)),
  ]);
}

/** Saves a game's new state and its new transcript entries, only if nobody changed it since `prevUpdated` (true when saved). */
export async function saveGame(db: D1Database, g: GameView, prevUpdated: number, added: GameEvent[]): Promise<boolean> {
  const r = await db.prepare("UPDATE games SET moves = ?, result = ?, reason = ?, draw_offer = ?, updated = ? WHERE id = ? AND updated = ?")
    .bind(g.moves.join(" "), g.result, g.reason, g.drawOffer, g.updated, g.id, prevUpdated).run();
  if (r.meta.changes !== 1) return false;
  if (added.length) await db.batch(added.map((e) => insertEvent(db, g.id, e)));
  return true;
}

export async function activeGames(db: D1Database, userId: string): Promise<GameView[]> {
  const r = await db.prepare(`${GAME_SELECT} WHERE g.kind = 'online' AND g.result = '*' AND (g.white_user = ? OR g.black_user = ?) ORDER BY g.updated DESC LIMIT 50`)
    .bind(userId, userId).all<GameRow>();
  return r.results.map((row) => toView(row));
}

/** Finished games, newest first, without transcripts. With `opponent`, only those against that user. */
export async function finishedGames(db: D1Database, userId: string, before: number, limit: number, opponent?: string): Promise<GameView[]> {
  const vs = opponent ? " AND (g.white_user = ?4 OR g.black_user = ?4)" : "";
  const r = await db.prepare(`${GAME_SELECT} WHERE g.result != '*' AND (g.white_user = ?1 OR g.black_user = ?1) AND g.updated < ?2${vs} ORDER BY g.updated DESC LIMIT ?3`)
    .bind(...[userId, before, limit, ...(opponent ? [opponent] : [])]).all<GameRow>();
  return r.results.map((row) => toView(row));
}

/** Every online game between two users, in play or finished, newest first. */
export async function gamesBetween(db: D1Database, a: string, b: string): Promise<GameView[]> {
  const r = await db.prepare(`${GAME_SELECT} WHERE g.kind = 'online' AND ((g.white_user = ?1 AND g.black_user = ?2) OR (g.white_user = ?2 AND g.black_user = ?1)) ORDER BY g.updated DESC LIMIT 200`)
    .bind(a, b).all<GameRow>();
  return r.results.map((row) => toView(row));
}

// ── Challenges ──

interface ChallengeRow { id: string; from_user: string; to_email: string; color: string; status: string; game_id: string | null; created: number; f_email: string; f_name: string; f_pic: string | null }
const CHALLENGE_SELECT = "SELECT c.*, u.email AS f_email, u.name AS f_name, u.picture AS f_pic FROM challenges c JOIN users u ON u.id = c.from_user";

const toChallenge = (r: ChallengeRow): Challenge => ({
  id: r.id,
  from: { id: r.from_user, email: r.f_email, name: r.f_name, avatar: avatarPath(r.from_user, r.f_pic) },
  toEmail: r.to_email,
  color: r.color as Challenge["color"],
  status: r.status as Challenge["status"],
  gameId: r.game_id,
  created: r.created,
});

export async function challengeById(db: D1Database, id: string): Promise<Challenge | null> {
  const r = await db.prepare(`${CHALLENGE_SELECT} WHERE c.id = ?`).bind(id).first<ChallengeRow>();
  return r ? toChallenge(r) : null;
}

export async function insertChallenge(db: D1Database, c: { id: string; from: string; toEmail: string; color: string; now: number }): Promise<void> {
  await db.prepare("INSERT INTO challenges (id, from_user, to_email, color, status, game_id, created) VALUES (?, ?, ?, ?, 'open', NULL, ?)")
    .bind(c.id, c.from, c.toEmail, c.color, c.now).run();
}

/** Moves an open challenge to a new status. True when it was still open. */
export async function closeChallenge(db: D1Database, id: string, status: Challenge["status"], gameId: string | null): Promise<boolean> {
  const r = await db.prepare("UPDATE challenges SET status = ?, game_id = ? WHERE id = ? AND status = 'open'").bind(status, gameId, id).run();
  return r.meta.changes === 1;
}

export async function openChallenges(db: D1Database, user: User): Promise<{ incoming: Challenge[]; outgoing: Challenge[] }> {
  const [inc, out] = await Promise.all([
    db.prepare(`${CHALLENGE_SELECT} WHERE c.to_email = ? AND c.status = 'open' ORDER BY c.created DESC LIMIT 50`).bind(user.email).all<ChallengeRow>(),
    db.prepare(`${CHALLENGE_SELECT} WHERE c.from_user = ? AND c.status = 'open' ORDER BY c.created DESC LIMIT 50`).bind(user.id).all<ChallengeRow>(),
  ]);
  return { incoming: inc.results.map(toChallenge), outgoing: out.results.map(toChallenge) };
}

export async function countOpenFrom(db: D1Database, userId: string, since: number): Promise<number> {
  const r = await db.prepare("SELECT COUNT(*) AS n FROM challenges WHERE from_user = ? AND created > ?").bind(userId, since).first<{ n: number }>();
  return r?.n ?? 0;
}

// ── Contacts: people you have played against ──

export async function addContact(db: D1Database, ownerId: string, email: string, now: number): Promise<void> {
  await db.prepare("INSERT INTO contacts (owner_id, email, name, created) VALUES (?, ?, NULL, ?) ON CONFLICT (owner_id, email) DO NOTHING")
    .bind(ownerId, email, now).run();
}

export async function removeContact(db: D1Database, ownerId: string, email: string): Promise<void> {
  await db.prepare("DELETE FROM contacts WHERE owner_id = ? AND email = ?").bind(ownerId, email).run();
}

interface ContactRow { email: string; id: string; name: string; picture: string | null }
interface RecordRow { opp: string; result: string; me_white: number; last: number }

export async function contacts(db: D1Database, owner: User): Promise<Contact[]> {
  const [list, games] = await Promise.all([
    db.prepare("SELECT c.email, u.id, u.name, u.picture FROM contacts c JOIN users u ON u.email = c.email WHERE c.owner_id = ? LIMIT 500")
      .bind(owner.id).all<ContactRow>(),
    db.prepare(`SELECT CASE WHEN g.white_user = ?1 THEN g.black_user ELSE g.white_user END AS opp, g.result, (g.white_user = ?1) AS me_white, g.updated AS last
      FROM games g WHERE g.kind = 'online' AND (g.white_user = ?1 OR g.black_user = ?1)`).bind(owner.id).all<RecordRow>(),
  ]);
  const out = new Map<string, Contact>();
  for (const c of list.results) {
    out.set(c.id, { id: c.id, email: c.email, name: c.name, avatar: avatarPath(c.id, c.picture), wins: 0, losses: 0, draws: 0, lastPlayed: null });
  }
  for (const g of games.results) {
    const c = out.get(g.opp);
    if (!c) continue;
    c.lastPlayed = Math.max(c.lastPlayed ?? 0, g.last);
    if (g.result === "1/2-1/2") c.draws++;
    else if (g.result === "1-0" || g.result === "0-1") {
      if ((g.result === "1-0") === Boolean(g.me_white)) c.wins++; else c.losses++;
    }
  }
  return [...out.values()].sort((a, b) => (b.lastPlayed ?? 0) - (a.lastPlayed ?? 0));
}
