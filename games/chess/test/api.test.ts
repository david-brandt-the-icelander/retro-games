// The Worker's API end to end, on an in-memory database: sign-in, challenges, contacts, a whole
// online game through the room logic, history and games against the computer.
import assert from "node:assert/strict";
import test from "node:test";
import { handleApi, type ApiEnv } from "../worker/api";
import { handleAuth, safePicture, safeReturn } from "../worker/auth";
import { RoomCore } from "../worker/room";
import { BASE, type LiveMessage } from "../shared/protocol";
import { fakeD1 } from "./fake-d1";

const ORIGIN = "http://localhost:8787";

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
  return /games_session=([^;]+)/.exec(res.headers.get("Set-Cookie")!)![1];
}

function client(env: ApiEnv, cookie: string | null) {
  return async (method: string, path: string, body?: unknown, headers: Record<string, string> = {}) => {
    const url = new URL(`${ORIGIN}${BASE}/api/${path}`);
    const h: Record<string, string> = { ...headers };
    if (cookie) h.Cookie = `games_session=${cookie}`;
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

  // Chat goes into the same transcript as the moves, with times.
  assert.equal((await bo("POST", `games/${g.id}/action`, { type: "chat", text: "gg" })).status, 200);
  const full = (await ann("GET", `games/${g.id}`)).body.game;
  assert.deepEqual(full.events.map((e: any) => e.kind), ["start", "move", "move", "move", "move", "end", "chat"]);
  assert.ok(full.events.every((e: any, i: number, a: any[]) => i === 0 || e.at >= a[i - 1].at));

  const annContacts = (await ann("GET", "lobby")).body.contacts;
  assert.deepEqual(annContacts.map((c: any) => [c.email, c.name, c.wins, c.losses]), [["bo@x.io", "Bo", 0, 1]]);
  const between = await ann("GET", `contacts/${annContacts[0].id}/games`);
  assert.equal(between.body.games.length, 1);
  assert.equal(between.body.contact.email, "bo@x.io");
  assert.deepEqual((await bo("GET", "lobby")).body.contacts.map((c: any) => [c.email, c.wins]), [["ann@x.io", 1]]);
  assert.equal((await cy("GET", "lobby")).body.contacts.length, 0, "an invitation alone doesn't make a contact");
  assert.equal((await bo("GET", "games")).body.games.length, 1);
  assert.equal((await ann("GET", "lobby")).body.active.length, 0);
});

test("declining and cancelling invitations; removing a contact", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "contacts/remove", { email: "dee@x.io" })).body.contacts.length, 0);
  const c1 = (await ann("POST", "challenges", { email: "dee@x.io", color: "random" })).body.challenge;
  assert.equal((await ann("POST", `challenges/${c1.id}/cancel`, {})).status, 200);
  const dee = client(env, await signIn(env, "dee@x.io", "Dee"));
  assert.equal((await dee("GET", "lobby")).body.incoming.length, 0);
  const c2 = (await ann("POST", "challenges", { email: "dee@x.io", color: "black" })).body.challenge;
  assert.equal((await dee("POST", `challenges/${c2.id}/decline`, {})).status, 200);
  assert.equal((await ann("GET", "lobby")).body.outgoing.length, 0);
});

test("profile pictures only from Google or GitHub; a Bearer token works like the cookie", async () => {
  const { env } = setup();
  assert.equal(safePicture("https://avatars.githubusercontent.com/u/1"), "https://avatars.githubusercontent.com/u/1");
  assert.equal(safePicture("https://evil.example/x.png"), null);
  assert.equal(safePicture("http://lh3.googleusercontent.com/a"), null);
  const url = new URL(`${ORIGIN}${BASE}/auth/dev?email=pic@x.io&name=Pic&format=token`);
  const { token } = (await (await handleAuth(new Request(url), env, url))!.json()) as { token: string };
  const viaBearer = await handleApi(new Request(`${ORIGIN}${BASE}/api/me`, { headers: { Authorization: `Bearer ${token}` } }), env, new URL(`${ORIGIN}${BASE}/api/me`));
  assert.equal(((await viaBearer.json()) as any).user.email, "pic@x.io");
});

test("sign-in goes to games.icelander.net's one sign-in; signing out is the host's", async () => {
  const { env } = setup();
  for (const path of ["auth/login/google?return=%2Fretro%2Fchess%2F%3Fchallenge%3Dabc", "auth/login/github", "auth/callback/google?code=x&state=y"]) {
    const url = new URL(`${ORIGIN}${BASE}/${path}`);
    const res = (await handleAuth(new Request(url), env, url))!;
    assert.equal(res.status, 302, path);
    assert.match(res.headers.get("Location")!, /^\/auth\/sign-in\?return=%2Fretro%2Fchess%2F/, path);
  }
  const evil = new URL(`${ORIGIN}${BASE}/auth/login/google?return=${encodeURIComponent("https://evil.example/")}`);
  assert.equal((await handleAuth(new Request(evil), env, evil))!.headers.get("Location"), "/auth/sign-in?return=%2Fretro%2Fchess%2F");
  const cookie = await signIn(env, "ann@x.io", "Ann");
  const logout = new URL(`${ORIGIN}${BASE}/auth/logout`);
  const res = (await handleAuth(new Request(logout, { method: "POST", headers: { Cookie: `games_session=${cookie}`, Origin: ORIGIN } }), env, logout))!;
  assert.equal(res.status, 200);
  assert.match(res.headers.get("Set-Cookie")!, /^games_session=; Path=\/; Max-Age=0/);
  const refused = (await handleAuth(new Request(logout, { method: "POST", headers: { Cookie: `games_session=${cookie}`, Origin: "https://evil.example" } }), env, logout))!;
  assert.equal(refused.status, 403);
});

test("through the login service: checked on every request, and a person plays as the address Gambit knows", async () => {
  const { env } = setup();
  const live = new Map<string, { id: string; email: string; emails: string[]; name: string; picture: string | null; roles: string[] }>();
  const shared = {
    ...env, DEV_LOGIN: undefined, ACCOUNTS_JWKS: JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "t", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] }),
    ACCOUNTS: { session: async (v: string, app: string) => (app === "games" ? live.get(v) ?? null : null) },
  } as unknown as ApiEnv;
  // Ann played Gambit as ann@work.io; she signs in now with her primary address, ann@x.io.
  const before = client(env, await signIn(env, "ann@work.io", "Ann"));
  const annId = (await before("GET", "me")).body.user.id;
  live.set("s-ann-xxxxxxxxxxxxxxxxxxxxxxxxxxxx", { id: "a-1", email: "ann@x.io", emails: ["ann@x.io", "ann@work.io"], name: "Ann", picture: null, roles: ["games:play"] });
  const url = new URL(`https://games.icelander.net${BASE}/api/me`);
  const me = async () => (await (await handleApi(new Request(url, { headers: { Cookie: "games_session=s-ann-xxxxxxxxxxxxxxxxxxxxxxxxxxxx" } }), shared, url)).json()) as any;
  assert.deepEqual([(await me()).user.id, (await me()).user.email], [annId, "ann@work.io"]);
  assert.deepEqual((await me()).providers, ["google", "github"]);
  live.delete("s-ann-xxxxxxxxxxxxxxxxxxxxxxxxxxxx"); // disabled, or signed out everywhere
  assert.equal((await me()).user, null);
});

test("cross-site and non-JSON writes are refused", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "contacts/remove", { email: "d@x.io" }, { Origin: "https://evil.example" })).status, 403);
});

test("games against the computer: saved only when finished and legal", async () => {
  const { env } = setup();
  const ann = client(env, await signIn(env, "ann@x.io", "Ann"));
  assert.equal((await ann("POST", "games/computer", { level: 3, color: "white", moves: ["e2e4"], resigned: false })).status, 422);
  assert.equal((await ann("POST", "games/computer", { level: 3, color: "white", moves: ["e2e5"], resigned: true })).status, 422);
  const lost = await ann("POST", "games/computer", { level: 3, color: "white", moves: ["f2f3", "e7e5", "g2g4", "d8h4"], resigned: false });
  assert.equal(lost.status, 200);
  assert.equal(lost.body.game.black.name, "Stockfish · Club Novice");
  const resigned = await ann("POST", "games/computer", { level: 8, color: "black", moves: ["e2e4"], times: [4000], resigned: true });
  assert.equal(resigned.body.game.result, "1-0");
  const ev = resigned.body.game.events;
  assert.deepEqual(ev.map((e: any) => e.kind), ["start", "move", "resign", "end"]);
  assert.equal(ev[1].at - ev[0].at, 4000, "move times are kept");
  const hist = (await ann("GET", "games")).body.games;
  assert.equal(hist.length, 2);
});
