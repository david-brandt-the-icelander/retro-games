// The Worker: the engine's parts come back as one .wasm, the page needs a sign-in, and every other
// file is served as it is.
import assert from "node:assert/strict";
import { test } from "node:test";
import worker, { BASE, joinedWasm, type Env } from "../worker/index";

function assets(files: Record<string, Uint8Array | string>): Env["ASSETS"] {
  return {
    async fetch(req: Request) {
      const path = new URL(req.url).pathname;
      const body = files[path];
      if (body === undefined) return new Response("Not found", { status: 404 });
      const bytes = typeof body === "string" ? new TextEncoder().encode(body) : body;
      return new Response(bytes as unknown as BodyInit, { headers: { "Content-Length": String(bytes.length) } });
    },
  };
}

const env = (files: Record<string, Uint8Array | string>) => ({ ASSETS: assets(files) }) as unknown as Env;

test("the engine's parts are joined in order", async () => {
  const files = { [`${BASE}/index.wasm.0`]: new Uint8Array([1, 2, 3]), [`${BASE}/index.wasm.1`]: new Uint8Array([4, 5]) };
  const url = new URL(`https://icelander.net${BASE}/index.wasm`);
  const res = await joinedWasm(new Request(url), env(files), url);
  assert.equal(res.status, 200);
  assert.equal(res.headers.get("Content-Type"), "application/wasm");
  assert.equal(res.headers.get("Content-Length"), "5");
  assert.deepEqual([...new Uint8Array(await res.arrayBuffer())], [1, 2, 3, 4, 5]);
});

test("no parts is a 404", async () => {
  const url = new URL(`https://icelander.net${BASE}/index.wasm`);
  const res = await joinedWasm(new Request(url), env({}), url);
  assert.equal(res.status, 404);
});

test("the bare game address gains its slash", async () => {
  const res = await worker.fetch(new Request(`https://icelander.net${BASE}?x=1`), env({}));
  assert.equal(res.status, 301);
  assert.equal(res.headers.get("Location"), `https://icelander.net${BASE}/?x=1`);
});

test("the page sends someone without a sign-in to sign in", async () => {
  const res = await worker.fetch(new Request(`https://icelander.net${BASE}/`), env({ [`${BASE}/`]: "<html>" }));
  assert.ok(res.status === 302 || res.status === 303 || res.status === 401 || res.status === 403, `status ${res.status}`);
  assert.notEqual(await res.text(), "<html>");
});

test("other files are plain assets", async () => {
  const res = await worker.fetch(new Request(`https://icelander.net${BASE}/boot.js`), env({ [`${BASE}/boot.js`]: "ok" }));
  assert.equal(await res.text(), "ok");
});
