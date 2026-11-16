// The Worker (worker/index.ts): the page needs a sign-in, and the engine comes back as one file. The login
// service is stood in for here; it is tested in icelander.net's accounts/test.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { BASE } from "../worker/index";

const ORIGIN = "https://icelander.net";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

const served: string[] = [];
const files: Record<string, string> = { [`${BASE}/index.wasm.0`]: "abc", [`${BASE}/index.wasm.1`]: "de" };
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  ASSETS: {
    fetch: async (r: Request) => {
      const path = new URL(r.url).pathname;
      served.push(path);
      if (path.includes(".wasm.")) return files[path] ? new Response(files[path], { headers: { "Content-Length": String(files[path].length) } }) : new Response("no", { status: 404 });
      return new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } });
    },
  },
  ACCOUNTS: accounts,
  ACCOUNTS_JWKS: JWKS,
}) as never;
const call = (path: string, init: RequestInit = {}, e = env()) => worker.fetch(new Request(ORIGIN + path, init), e);

test("the page sends someone signed out to sign in, and back to the match they were sent to", async () => {
  served.length = 0;
  const res = await call(`${BASE}/?match=abcdefgh12`);
  assert.equal(res.status, 302);
  assert.equal(res.headers.get("Location"), `/auth/sign-in?return=${encodeURIComponent(`${BASE}/?match=abcdefgh12`)}`);
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
  assert.equal((await call(`${BASE}/`, { headers: { Cookie: `site_session=${ALICE}` } }, env(null))).status, 302);
});

test("the address without its slash moves to it, keeping the match", async () => {
  const res = await call(`${BASE}?match=abcdefgh12`);
  assert.equal(res.status, 301);
  assert.equal(res.headers.get("Location"), `${ORIGIN}${BASE}/?match=abcdefgh12`);
});

test("the engine is joined from its parts", async () => {
  const res = await call(`${BASE}/index.wasm`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "5");
  assert.equal(await res.text(), "abcde");
});

test("other files are plain static assets, with no sign-in", async () => {
  served.length = 0;
  const res = await call(`${BASE}/shell.css`);
  assert.equal(res.status, 200);
  assert.deepEqual(served, [`${BASE}/shell.css`]);
});
