// The Worker: the page needs a sign-in, the engine's parts are joined into one index.wasm, the rest is static.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker, { BASE, type Env } from "../worker/index";

const files: Record<string, Uint8Array> = {
  [`${BASE}/index.html`]: new TextEncoder().encode("<!doctype html>"),
  [`${BASE}/index.wasm.0`]: new Uint8Array([0, 97, 115]),
  [`${BASE}/index.wasm.1`]: new Uint8Array([109, 1]),
  [`${BASE}/index.js`]: new TextEncoder().encode("var Engine;"),
};
const env: Env = {
  ASSETS: {
    async fetch(req: Request) {
      const body = files[new URL(req.url).pathname];
      return body ? new Response(new Blob([body as BlobPart]), { headers: { "Content-Length": String(body.length) } }) : new Response("Not found", { status: 404 });
    },
  },
};
const get = (path: string, init?: RequestInit) => worker.fetch(new Request(`https://icelander.net${path}`, init), env);

test("the bare address moves to the trailing slash", async () => {
  const r = await get(BASE);
  assert.equal(r.status, 301);
  assert.equal(r.headers.get("Location"), `https://icelander.net${BASE}/`);
});

test("the page needs a sign-in", async () => {
  const r = await get(`${BASE}/`, { headers: { Accept: "text/html" } });
  assert.ok(r.status === 302 || r.status === 303 || r.status === 401 || r.status === 403, `status ${r.status}`);
  assert.notEqual(await r.text(), "<!doctype html>");
});

test("the engine is served as one file", async () => {
  const r = await get(`${BASE}/index.wasm`);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get("Content-Type"), "application/wasm");
  assert.equal(r.headers.get("Content-Length"), "5");
  assert.deepEqual([...new Uint8Array(await r.arrayBuffer())], [0, 97, 115, 109, 1]);
});

test("other files are static assets", async () => {
  const r = await get(`${BASE}/index.js`);
  assert.equal(await r.text(), "var Engine;");
});
