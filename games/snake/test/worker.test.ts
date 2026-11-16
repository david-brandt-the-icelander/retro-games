// The Worker (worker/index.ts): the page needs a sign-in, like every game under icelander.net/games, and
// the engine comes back whole from its parts. The login service is stood in for here; it is tested in
// icelander.net's accounts/test.
import { test } from "node:test";
import assert from "node:assert/strict";
import { checkVendored } from "../../../vendor/icelander-auth/check.mjs";
import worker, { BASE } from "../worker/index";

const ORIGIN = "https://icelander.net";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";
const PARTS: Record<string, string> = { [`${BASE}/index.wasm.0`]: "abc", [`${BASE}/index.wasm.1`]: "de" };

const served: string[] = [];
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  ASSETS: {
    fetch: async (r: Request) => {
      const path = new URL(r.url).pathname;
      served.push(path);
      if (path.includes(".wasm.")) {
        const body = PARTS[path];
        return body === undefined ? new Response("no", { status: 404 }) : new Response(body, { headers: { "Content-Length": String(body.length) } });
      }
      return new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } });
    },
  },
  ACCOUNTS: accounts,
  ACCOUNTS_JWKS: JWKS,
}) as never;
const call = (path: string, init: RequestInit = {}, e = env()) => worker.fetch(new Request(ORIGIN + path, init), e);

test("the page sends someone signed out to sign in, and back", async () => {
  served.length = 0;
  const res = await call(`${BASE}/`);
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), `/auth/sign-in?return=${encodeURIComponent(`${BASE}/`)}`);
  assert.deepEqual(served, []);
});

test("the page is served to anyone signed in, privately", async () => {
  for (const path of [`${BASE}/`, `${BASE}/index.html`]) {
    served.length = 0;
    const res = await call(path, { headers: { Cookie: `site_session=${ALICE}` } });
    assert.equal(res.status, 200, path);
    assert.equal(res.headers.get("Cache-Control"), "private, no-cache");
    assert.deepEqual(served, [path]);
  }
});

test("the login service out of reach counts as signed out", async () => {
  assert.equal((await call(`${BASE}/`, { headers: { Cookie: `site_session=${ALICE}` } }, env(null))).status, 302);
});

test("the bare path gets its trailing slash, keeping the query", async () => {
  const res = await call(`${BASE}?x=1`);
  assert.equal(res.status, 301);
  assert.equal(res.headers.get("Location"), `${ORIGIN}${BASE}/?x=1`);
});

test("the engine is its parts, in order, as one WebAssembly file", async () => {
  const res = await call(`${BASE}/index.wasm`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "5");
  assert.equal(await res.text(), "abcde");
});

test("other files come straight from the assets", async () => {
  served.length = 0;
  const res = await call(`${BASE}/index.js`);
  assert.equal(res.status, 200);
  assert.deepEqual(served, [`${BASE}/index.js`]);
});

test("the vendored sign-in library is icelander.net's, unedited", () => {
  assert.match(checkVendored(new URL("../../../../vendor/icelander-auth/", import.meta.url)), /^\d+\.\d+\.\d+$/);
});
