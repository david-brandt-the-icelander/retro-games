// The Worker (worker/index.ts): the page needs a sign-in, and the engine's parts are joined into one file.
// The login service is stood in for here; it is tested in icelander.net's accounts/test.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { BASE } from "../worker/index";

const ORIGIN = "https://icelander.net";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

const files: Record<string, string> = {
  [`${BASE}/`]: "<!doctype html>",
  [`${BASE}/index.wasm.0`]: "abc",
  [`${BASE}/index.wasm.1`]: "def",
  [`${BASE}/index.js`]: "// engine loader",
};
const served: string[] = [];
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  ASSETS: {
    fetch: async (r: Request) => {
      const path = new URL(r.url).pathname;
      served.push(path);
      const body = files[path];
      return body === undefined ? new Response("Not found", { status: 404 }) : new Response(body, { headers: { "Content-Length": String(body.length) } });
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
  served.length = 0;
  const res = await call(`${BASE}/`, { headers: { Cookie: `site_session=${ALICE}` } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "private, no-cache");
  assert.deepEqual(served, [`${BASE}/`]);
});

test("the login service out of reach counts as signed out", async () => {
  const down = env({ session: async () => { throw new Error("down"); } });
  assert.equal((await call(`${BASE}/`, { headers: { Cookie: `site_session=${ALICE}` } }, down)).status, 302);
});

test("the bare path redirects to the page", async () => {
  const res = await call(BASE);
  assert.equal(res.status, 301);
  assert.equal(res.headers.get("Location"), `${ORIGIN}${BASE}/`);
});

test("the engine's parts are joined into one wasm file", async () => {
  const res = await call(`${BASE}/index.wasm`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "6");
  assert.equal(await res.text(), "abcdef");
});

test("other files are plain static assets", async () => {
  const res = await call(`${BASE}/index.js`);
  assert.equal(await res.text(), "// engine loader");
});
