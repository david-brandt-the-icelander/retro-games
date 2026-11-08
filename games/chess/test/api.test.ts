// The Worker's API end to end, on an in-memory database: sign-in, challenges, contacts, a whole
// online game through the room logic, history and games against the computer.
import assert from "node:assert/strict";
import test from "node:test";
import { handleApi, type ApiEnv } from "../worker/api";
import { handleAuth, safeReturn } from "../worker/auth";
import { RoomCore } from "../worker/room";
import { BASE, type LiveMessage } from "../src/shared/protocol";
import { fakeD1 } from "./fake-d1";

const ORIGIN = "https://games.example";

function setup() {
  const DB = fakeD1();
  const broadcasts: LiveMessage[] = [];
  const core = new RoomCore(DB, (m) => broadcasts.push(m));
  const env: ApiEnv = {
    DB, DEV_LOGIN: "1",
    ROOMS: {
      idFromName: (n) => n,
      get: () => ({
        async fetch(req: Request) {
          const r = await core.act(req.headers.get("X-Game")!, req.headers.get("X-User")!, await req.json());
          return new Response(JSON.stringify(r.body), { status: r.status });
        },
      }),
    },
  };
  return { env, broadcasts };
}

async function signIn(env: ApiEnv, email: string, name: string): Promise<string> {
  const url = new URL(`${ORIGIN}${BASE}/auth/dev?email=${email}&name=${name}`);
  const res = (await handleAuth(new Request(url), env, url))!;
  assert.equal(res.status, 302);
  return /chess_session=([^;]+)/.exec(res.headers.get("Set-Cookie")!)![1];
}

function client(env: ApiEnv, cookie: string | null) {
  return async (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
    const url = new URL(`${ORIGIN}${BASE}/api/${path}`);
    const h: Record<string, string> = { ...headers };
    if (cookie) h.Cookie = `chess_session=${cookie}`;
    if (body !== undefined) h["Content-Type"] = "application/json";
    const res = await handleApi(new Request(url, { method, headers: h, body: body === undefined ? undefined : JSON.stringify(body) }), env, url);
    return { status: res.status, body: (await res.json()) as Record<string, any> };
  };
}

test("signed out: /me says so; everything else needs sign-in; dev sign-in only when enabled", async () => {
  const { env } = setup();
  const anon = client(env, null);
  assert.deepEqual((await anon("GET", "me")).body, { user: null, providers: ["dev"] });
  assert.equal((await anon("GET", "lobby")).status, 401);
  const url = new URL(`${ORIGIN}${BASE}/auth/dev?email=a@b.io`);
  assert.equal((await handleAuth(new Request(url), { ...env, DEV_LOGIN: undefined }, url))!.status, 404);
  assert.equal(safeReturn("https://evil.com/"), `${BASE}/`);
  assert.equal(safeReturn("//evil.com/retro/chess/"), `${BASE}/`);
  assert.equal(safeReturn(`${BASE}/?challenge=abc#/online`), `${BASE}/?challenge=abc#/online`);
});

test("a challenge by email, accepted, played to mate, in both players' history and contacts", async () => {
  const { env, broadcasts } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("GET", "me")).body.user.name, "Ann");

  // Ann challenges an address nobody has signed in with yet.
  const ch = await ann("POST", "challenges", { email: "  Bo@X.io ", color: "white" });
  assert.equal(ch.status, 200);
  assert.equal(ch.body.challenge.toEmail, "bo@x.io");
  assert.equal(ch.body.emailed, false);
  assert.match(ch.body.link, /\?challenge=[a-z0-9]+$/);
  assert.equal((await ann("POST", "challenges", { email: "ann@x.io", color: "white" })).status, 400);
  assert.equal((await ann("POST", "challenges", { email: "nope", color: "white" })).status, 400);

  // Bo signs in later and finds it.
  const bo = client(env, await signIn(env, "bo@x.io", "Bo"));
  const lobby = (await bo("GET", "lobby")).body;
  assert.equal(lobby.incoming.length, 1);
  assert.equal((await ann("GET", "lobby")).body.outgoing.length, 1);
  // Someone else can't see or answer it.
  const cy = client(env, await signIn(env, "cy@x.io", "Cy"));
  assert.equal((await cy("POST", `challenges/${ch.body.challenge.id}/accept`, {})).status, 403);

  const acc = await bo("POST", `challenges/${ch.body.challenge.id}/accept`, {});
  assert.equal(acc.status, 200);
  const g = acc.body.game;
  assert.equal(g.white.name, "Ann");
  assert.equal(g.black.name, "Bo");
  assert.equal((await bo("POST", `challenges/${ch.body.challenge.id}/accept`, {})).status, 409, "only once");
  assert.equal((await cy("GET", `games/${g.id}`)).status, 404, "only players see a game");

  const play = [[ann, "f2f3"], [bo, "e7e5"], [ann, "g2g4"], [bo, "d8h4"]] as const;
  for (let i = 0; i < play.length; i++) {
    const r = await play[i][0]("POST", `games/${g.id}/action`, { type: "move", uci: play[i][1], ply: i });
    assert.equal(r.status, 200, JSON.stringify(r.body));
  }
  assert.equal(broadcasts.length, 4);
  const end = (await ann("GET", `games/${g.id}`)).body.game;
  assert.equal(end.result, "0-1");
  assert.equal(end.reason, "checkmate");
  assert.equal((await ann("POST", `games/${g.id}/action`, { type: "resign" })).status, 409);

  const annContacts = (await ann("GET", "lobby")).body.contacts;
  assert.deepEqual(annContacts.map((c: any) => [c.email, c.wins, c.losses, c.joined]), [["bo@x.io", 0, 1, true]]);
  assert.deepEqual((await bo("GET", "lobby")).body.contacts.map((c: any) => [c.email, c.wins]), [["ann@x.io", 1]]);
  assert.equal((await bo("GET", "games")).body.games.length, 1);
  assert.equal((await ann("GET", "lobby")).body.active.length, 0);
});

test("contacts: add, can't add yourself, remove; declining and cancelling challenges", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "contacts", { email: "dee@x.io", name: "Dee" })).body.contacts[0].name, "Dee");
  assert.equal((await ann("POST", "contacts", { email: "ann@x.io" })).status, 400);
  assert.equal((await ann("POST", "contacts/remove", { email: "dee@x.io" })).body.contacts.length, 0);
  const c1 = (await ann("POST", "challenges", { email: "dee@x.io", color: "random" })).body.challenge;
  assert.equal((await ann("POST", `challenges/${c1.id}/cancel`, {})).status, 200);
  const dee = client(env, await signIn(env, "dee@x.io", "Dee"));
  assert.equal((await dee("GET", "lobby")).body.incoming.length, 0);
  const c2 = (await ann("POST", "challenges", { email: "dee@x.io", color: "black" })).body.challenge;
  assert.equal((await dee("POST", `challenges/${c2.id}/decline`, {})).status, 200);
  assert.equal((await ann("GET", "lobby")).body.outgoing.length, 0);
});

test("cross-site and non-JSON writes are refused", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "contacts", { email: "d@x.io" }, { Origin: "https://evil.example" })).status, 403);
});

test("games against the computer: saved only when finished and legal", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "games/computer", { level: 3, color: "white", moves: ["e2e4"], resigned: false })).status, 422);
  assert.equal((await ann("POST", "games/computer", { level: 3, color: "white", moves: ["e2e5"], resigned: true })).status, 422);
  const lost = await ann("POST", "games/computer", { level: 3, color: "white", moves: ["f2f3", "e7e5", "g2g4", "d8h4"], resigned: false });
  assert.equal(lost.status, 200);
  assert.equal(lost.body.game.black.name, "Stockfish · Club Novice");
  const resigned = await ann("POST", "games/computer", { level: 8, color: "black", moves: ["e2e4"], resigned: true });
  assert.equal(resigned.body.game.result, "1-0");
  const hist = (await ann("GET", "games")).body.games;
  assert.equal(hist.length, 2);
});
