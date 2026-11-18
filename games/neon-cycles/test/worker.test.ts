// The Worker (worker/index.ts): every game under icelander.net/games needs a sign-in, and the Godot engine
// is stored in parts under Cloudflare's 25 MiB limit and served as one file. The login service is stood in
// for here; it is tested in icelander.net's accounts/test, and the games hub tests the sign-in routes on this host.
import { test } from "node:test";
import assert from "node:assert/strict";
import { checkVendored } from "../../../vendor/icelander-auth/check.mjs";
import worker from "../worker/index";

const ORIGIN = "https://icelander.net";
const PATH = "/games/retro/neon-cycles";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

/** Engine parts the stand-in assets hold: two of them. */
const PARTS: Record<string, Uint8Array<ArrayBuffer>> = {
  [`${PATH}/index.wasm.0`]: new Uint8Array([0, 97, 115, 109]),
  [`${PATH}/index.wasm.1`]: new Uint8Array([1, 0, 0, 0, 42]),
};

const served: string[] = [];
const env = (accounts: unknown = { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) }) => ({
  ASSETS: {
    fetch: async (r: Request) => {
      const path = new URL(r.url).pathname;
      served.push(path);
      if (path in PARTS) return new Response(PARTS[path], { headers: { "Content-Length": String(PARTS[path].length) } });
      if (path.startsWith(`${PATH}/index.wasm.`)) return new Response("Not found", { status: 404 });
      return new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } });
    },
  },
  ACCOUNTS: accounts,
  ACCOUNTS_JWKS: JWKS,
}) as never;
const call = (path: string, init: RequestInit = {}, e = env()) => worker.fetch(new Request(ORIGIN + path, init), e);

test("sign-in: the game's page sends someone signed out to sign in, and back", async () => {
  served.length = 0;
  for (const page of [`${PATH}/`, `${PATH}/index.html`]) {
    const res = await call(page);
    assert.equal(res.status, 302, page);
    assert.equal(res.headers.get("Location"), `/auth/sign-in?return=${encodeURIComponent(page)}`);
  }
  assert.deepEqual(served, []);
});

test("sign-in: the page is served to anyone signed in, privately", async () => {
  served.length = 0;
  const res = await call(`${PATH}/`, { headers: { Cookie: `site_session=${ALICE}` } });
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Cache-Control"), "private, no-cache");
  assert.deepEqual(served, [`${PATH}/`]);
});

test("sign-in: the login service out of reach counts as signed out", async () => {
  assert.equal((await call(`${PATH}/`, { headers: { Cookie: `site_session=${ALICE}` } }, env(null))).status, 302);
  const down = env({ session: async () => { throw new Error("down"); } });
  assert.equal((await call(`${PATH}/`, { headers: { Cookie: `site_session=${ALICE}` } }, down)).status, 302);
});

test("the bare path redirects to the page; the page's script and stylesheet are plain assets", async () => {
  const bare = await call(`${PATH}?x=1`);
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("Location"), `${ORIGIN}${PATH}/?x=1`);
  served.length = 0;
  for (const f of ["boot.js", "shell.css", "index.js", "index.pck"]) assert.equal((await call(`${PATH}/${f}`)).status, 200, f);
  assert.deepEqual(served, ["boot.js", "shell.css", "index.js", "index.pck"].map((f) => `${PATH}/${f}`));
});

test("the engine: its parts are joined into one WebAssembly file, in order", async () => {
  const res = await call(`${PATH}/index.wasm`);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "9");
  assert.deepEqual([...new Uint8Array(await res.arrayBuffer())], [0, 97, 115, 109, 1, 0, 0, 0, 42]);
});

test("sign-in: the vendored library (shared by every game here) is icelander.net's, unedited", () => {
  assert.match(checkVendored(new URL("../../../vendor/icelander-auth/", import.meta.url)), /^\d+\.\d+\.\d+$/);
});
