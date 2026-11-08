// The JSON API under {BASE}/api/. Everything except /api/me needs a signed-in user.
//
//   GET  me                               → Me
//   POST me/name          { name }        renames yourself
//   GET  lobby                            → Lobby: open challenges both ways, games in play, contacts
//   POST challenges       { email, color } → { challenge, emailed, link }
//   GET  challenges/{id}                  → { challenge }  (yours, or addressed to you)
//   POST challenges/{id}/accept           → { game }
//   POST challenges/{id}/decline | cancel
//   POST contacts         { email, name? }
//   POST contacts/remove  { email }
//   GET  games?before=T                   → { games }  finished games, newest first, 30 at a time
//   GET  games/{id}                       → { game }
//   POST games/{id}/action  Action        → { game }  (through the game's Durable Object)
//   GET  games/{id}/live                  WebSocket: LiveMessage after every change
//   POST games/computer   { level, color, moves, resigned } → { game }  a finished game against the computer
import { BASE, cleanDisplayName, cleanEmail, type Me, type User } from "../src/shared/protocol";
import { boardOutcome, replay, resignation, validMoveList, type Side } from "../src/shared/rules";
import { validAction } from "./actions";
import { currentUser, providers, type AuthEnv } from "./auth";
import * as db from "./db";
import { canMail, challengeMail, sendMail, type MailEnv } from "./mail";

export interface DurableObjectStub { fetch(req: Request): Promise<Response> }
export interface DurableObjectNamespace { idFromName(name: string): unknown; get(id: unknown): DurableObjectStub }
export interface ApiEnv extends AuthEnv, MailEnv { ROOMS: DurableObjectNamespace }

const MAX_BODY = 20_000;
const CHALLENGES_PER_HOUR = 30;

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });
}
const fail = (error: string, status = 400) => json({ error }, status);

async function readJson(req: Request): Promise<Record<string, unknown> | null> {
  const text = await req.text();
  if (text.length > MAX_BODY) return null;
  try {
    const x = JSON.parse(text || "{}");
    return x && typeof x === "object" && !Array.isArray(x) ? x : null;
  } catch {
    return null;
  }
}

/** Refuses cross-site writes: a POST must be JSON, and from this origin when the browser says where it is from. */
function sameOrigin(req: Request, url: URL): boolean {
  const origin = req.headers.get("Origin");
  if (origin && origin !== url.origin) return false;
  return (req.headers.get("Content-Type") ?? "").startsWith("application/json");
}

export const challengeLink = (origin: string, id: string) => `${origin}${BASE}/?challenge=${id}`;

export async function handleApi(req: Request, env: ApiEnv, url: URL): Promise<Response> {
  const path = url.pathname.slice(`${BASE}/api/`.length).split("/").filter(Boolean);
  const method = req.method;
  if (method === "POST" && !sameOrigin(req, url)) return fail("forbidden", 403);
  const user = await currentUser(req, env);

  if (path[0] === "me" && path.length === 1 && method === "GET") {
    const me: Me = { user, providers: providers(env) };
    return json(me);
  }
  if (!user) return fail("Sign in first.", 401);
  const now = Date.now();

  // ── Yourself ──
  if (path[0] === "me" && path[1] === "name" && method === "POST") {
    const body = await readJson(req);
    const name = cleanDisplayName(body?.name);
    if (!name) return fail("Give a name.");
    await db.renameUser(env.DB, user.id, name);
    return json({ user: { ...user, name } });
  }

  // ── The lobby ──
  if (path[0] === "lobby" && method === "GET") {
    const [ch, active, contacts] = await Promise.all([db.openChallenges(env.DB, user), db.activeGames(env.DB, user.id), db.contacts(env.DB, user)]);
    return json({ ...ch, active, contacts });
  }

  // ── Challenges ──
  if (path[0] === "challenges") {
    if (path.length === 1 && method === "POST") return createChallenge(req, env, url, user, now);
    const c = path[1] ? await db.challengeById(env.DB, path[1]) : null;
    if (!c) return fail("No such challenge.", 404);
    const mine = c.from.id === user.id, forMe = c.toEmail === user.email;
    if (!mine && !forMe) return fail("This challenge was sent to someone else.", 403);
    if (path.length === 2 && method === "GET") return json({ challenge: c });
    if (method !== "POST") return fail("not found", 404);
    if (path[2] === "cancel" && mine) {
      return (await db.closeChallenge(env.DB, c.id, "cancelled", null)) ? json({ ok: true }) : fail("The challenge was already answered.", 409);
    }
    if (path[2] === "decline" && forMe) {
      return (await db.closeChallenge(env.DB, c.id, "declined", null)) ? json({ ok: true }) : fail("The challenge was already answered.", 409);
    }
    if (path[2] === "accept" && forMe) {
      const gameId = db.newId();
      if (!(await db.closeChallenge(env.DB, c.id, "accepted", gameId))) return fail("The challenge was already answered.", 409);
      const challengerSide: Side = c.color === "random" ? (crypto.getRandomValues(new Uint8Array(1))[0] & 1 ? "white" : "black") : c.color;
      const white = challengerSide === "white" ? c.from.id : user.id;
      const black = challengerSide === "white" ? user.id : c.from.id;
      await db.insertGame(env.DB, { id: gameId, kind: "online", level: null, white, black, moves: [], result: "*", reason: null, now });
      await db.addContact(env.DB, user.id, c.from.email!, c.from.name, now);
      return json({ game: await db.gameById(env.DB, gameId) });
    }
    return fail("not found", 404);
  }

  // ── Contacts ──
  if (path[0] === "contacts" && method === "POST") {
    const body = await readJson(req);
    const email = cleanEmail(body?.email);
    if (!email) return fail("That doesn't look like an email address.");
    if (path[1] === "remove") await db.removeContact(env.DB, user.id, email);
    else if (path.length === 1) {
      if (email === user.email) return fail("That's you.");
      await db.addContact(env.DB, user.id, email, cleanDisplayName(body?.name) || null, now);
    } else return fail("not found", 404);
    return json({ contacts: await db.contacts(env.DB, user) });
  }

  // ── Games ──
  if (path[0] === "games") {
    if (path.length === 1 && method === "GET") {
      const before = Number(url.searchParams.get("before")) || now + 1;
      return json({ games: await db.finishedGames(env.DB, user.id, before, 30) });
    }
    if (path[1] === "computer" && path.length === 2 && method === "POST") return saveComputerGame(req, env, user, now);
    const id = path[1];
    if (!id || !/^[a-z0-9]{8,40}$/.test(id)) return fail("No such game.", 404);
    if (path.length === 2 && method === "GET") {
      const g = await db.gameById(env.DB, id);
      if (!g || (g.white.id !== user.id && g.black.id !== user.id)) return fail("No such game.", 404);
      return json({ game: g });
    }
    if ((path[2] === "action" && method === "POST") || (path[2] === "live" && method === "GET")) {
      if (path[2] === "action") {
        const body = await readJson(req);
        if (!validAction(body)) return fail("bad action");
        return toRoom(env, id, user, "action", req, JSON.stringify(body));
      }
      return toRoom(env, id, user, "live", req, null);
    }
  }
  return fail("not found", 404);
}

/** Passes a request to the game's Durable Object, saying who it is from. */
function toRoom(env: ApiEnv, id: string, user: User, what: "action" | "live", req: Request, body: string | null): Promise<Response> {
  const stub = env.ROOMS.get(env.ROOMS.idFromName(id));
  const headers = new Headers({ "X-User": user.id, "X-Game": id });
  if (what === "live") {
    headers.set("Upgrade", req.headers.get("Upgrade") ?? "");
    return stub.fetch(new Request(`https://room/${what}`, { headers }));
  }
  headers.set("Content-Type", "application/json");
  return stub.fetch(new Request(`https://room/${what}`, { method: "POST", headers, body }));
}

async function createChallenge(req: Request, env: ApiEnv, url: URL, user: User, now: number): Promise<Response> {
  const body = await readJson(req);
  const email = cleanEmail(body?.email);
  const color = body?.color;
  if (!email) return fail("That doesn't look like an email address.");
  if (email === user.email) return fail("You can't challenge yourself. Try the computer!");
  if (color !== "white" && color !== "black" && color !== "random") return fail("Choose a colour.");
  if ((await db.countOpenFrom(env.DB, user.id, now - 3600_000)) >= CHALLENGES_PER_HOUR) return fail("That's a lot of challenges. Try again in an hour.", 429);
  const id = db.newId();
  await db.insertChallenge(env.DB, { id, from: user.id, toEmail: email, color, now });
  const known = await db.userByEmail(env.DB, email);
  await db.addContact(env.DB, user.id, email, known?.name ?? null, now);
  const link = challengeLink(url.origin, id);
  const emailed = canMail(env) ? await sendMail(env, email, challengeMail(user.name, user.email, link)) : false;
  return json({ challenge: await db.challengeById(env.DB, id), emailed, link });
}

async function saveComputerGame(req: Request, env: ApiEnv, user: User, now: number): Promise<Response> {
  const body = await readJson(req);
  const level = Number(body?.level);
  const color = body?.color;
  if (!Number.isInteger(level) || level < 1 || level > 8) return fail("bad level");
  if (color !== "white" && color !== "black") return fail("bad colour");
  if (!validMoveList(body?.moves)) return fail("bad moves");
  const played = replay(body.moves);
  if (!played) return fail("The moves aren't legal.", 422);
  let outcome = boardOutcome(played.chess);
  if (outcome.result === "*") {
    if (body.resigned !== true) return fail("The game isn't over.", 422);
    outcome = resignation(color);
  }
  const id = db.newId();
  await db.insertGame(env.DB, {
    id, kind: "computer", level, white: color === "white" ? user.id : null, black: color === "black" ? user.id : null,
    moves: body.moves, result: outcome.result, reason: outcome.reason, now,
  });
  return json({ game: await db.gameById(env.DB, id) });
}
