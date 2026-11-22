// The Worker (worker/index.ts): the page needs a sign-in, the engine comes back joined from its parts,
// and every other file is a plain static asset. The login service is stood in for here; it is tested in
// icelander.net's accounts/test.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { BASE } from "../worker/index";

const ORIGIN = "https://icelander.net";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

const served: string[] = [];
const files: Record<string, Uint8Array<ArrayBuffer>> = {
  [`${BASE}/index.wasm.0`]: new Uint8Array([0, 97, 115]),
  [`${BASE}/index.wasm.1`]: new Uint8Array([109, 1]),
};
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  ASSETS: {
    fetch: async (r: Request) => {
      const path = new URL(r.url).pathname;
      served.push(path);
      if (path.includes(".wasm.")) {
        const f = files[path];
        return f ? new Response(f, { headers: { "Content-Length": String(f.length) } }) : new Response("missing", { status: 404 });
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
  served.length = 0;
  const res = await call(`${BASE}/`, { headers: { Cookie: `site_session=${ALICE}` } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "private, no-cache");
  assert.deepEqual(served, [`${BASE}/`]);
});

test("the bare path redirects to the page", async () => {
  const res = await call(BASE);
  assert.equal(res.status, 301);
  assert.equal(res.headers.get("Location"), `${ORIGIN}${BASE}/`);
});

test("the engine is streamed back as one file from its parts", async () => {
  const res = await call(`${BASE}/index.wasm`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "5");
  assert.deepEqual([...new Uint8Array(await res.arrayBuffer())], [0, 97, 115, 109, 1]);
});

test("other files are plain static assets", async () => {
  served.length = 0;
  const res = await call(`${BASE}/index.pck`);
  assert.equal(res.status, 200);
  assert.deepEqual(served, [`${BASE}/index.pck`]);
});
