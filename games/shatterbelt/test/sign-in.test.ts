// Signing in (worker/index.ts): every game on games.icelander.net needs it. The page and the score API are for
// anyone signed in; the high-score table is public. The login service is stood in for here; it is tested in
// icelander.net's accounts/test, and the games hub tests the sign-in routes on this host.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../worker/index";

const ORIGIN = "https://games.icelander.net";
const PATH = "/retro/shatterbelt";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

const served: string[] = [];
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "games" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  DB: { prepare: () => { throw new Error("no database call expected"); } },
  ASSETS: { fetch: async (r: Request) => { served.push(new URL(r.url).pathname); return new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } }); } },
  ACCOUNTS: accounts,
  ACCOUNTS_JWKS: JWKS,
}) as never;
const call = (path: string, init: RequestInit = {}, e = env()) => worker.fetch(new Request(ORIGIN + path, init), e);

test("sign-in: the game's page sends someone signed out to sign in, and back", async () => {
  served.length = 0;
  const res = await call(`${PATH}/?match=abc`);
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), `/auth/sign-in?return=${encodeURIComponent(`${PATH}/?match=abc`)}`);
  assert.deepEqual(served, []);
});

test("sign-in: the page is served to anyone signed in, privately", async () => {
  served.length = 0;
  const res = await call(`${PATH}/`, { headers: { Cookie: `games_session=${ALICE}` } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "private, no-cache");
  assert.deepEqual(served, [`${PATH}/`]);
});

test("sign-in: a new game or a score needs a sign-in; the login service out of reach is signed out", async () => {
  for (const path of ["/api/game", "/api/score"]) {
    const res = await call(PATH + path, { method: "POST", body: "{}" });
    assert.equal(res.status, 401, path);
  }
  const down = env({ session: async () => { throw new Error("down"); } });
  assert.equal((await call(`${PATH}/api/game`, { method: "POST", body: "{}", headers: { Cookie: `games_session=${ALICE}` } }, down)).status, 401);
  assert.equal((await call(`${PATH}/`, { headers: { Cookie: `games_session=${ALICE}` } }, env(null))).status, 302);
});
