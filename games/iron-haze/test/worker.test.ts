// The Iron Haze Worker: who may fetch what, and how the parted files are joined.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { BASE, ROLE } from "../worker/config";
import worker, { type Env } from "../worker/index";

const ORIGIN = "https://icelander.net";
const PART_A = new Uint8Array([1, 2, 3]);
const PART_B = new Uint8Array([4, 5]);

/** Static assets as the build writes them: the engine and one download in two parts each. */
const FILES: Record<string, { body: Uint8Array | string; type: string }> = {
  [`${BASE}/`]: { body: "<!doctype html><title>Iron Haze</title>", type: "text/html" },
  [`${BASE}/shell.css`]: { body: "body{}", type: "text/css" },
  [`${BASE}/favicon.svg`]: { body: "<svg/>", type: "image/svg+xml" },
  [`${BASE}/play/index.pck`]: { body: "pck", type: "application/octet-stream" },
  [`${BASE}/play/index.wasm.0`]: { body: PART_A, type: "application/octet-stream" },
  [`${BASE}/play/index.wasm.1`]: { body: PART_B, type: "application/octet-stream" },
  [`${BASE}/download/iron-haze-linux.zip.0`]: { body: PART_B, type: "application/octet-stream" },
  [`${BASE}/download/iron-haze-linux.zip.1`]: { body: PART_A, type: "application/octet-stream" },
};

const USERS: Record<string, { roles: string[] }> = {
  member: { roles: ["site:reader", "games:play", ROLE] },
  player: { roles: ["site:reader", "games:play", "games:kingdoms"] },
};

const env: Env = {
  // The login service's real public key set (wrangler.jsonc): the library counts sign-in as configured only with one.
  ACCOUNTS_JWKS: '{"keys":[{"kty":"OKP","crv":"Ed25519","kid":"k2026a","x":"WIEomi0LTalJvQndhD7abl8ty3YcliQ0vEz4XjLXayc"}]}',
  ACCOUNTS: {
    async session(value: string) {
      const u = USERS[value];
      return u ? ({ id: `a-${value}`, email: `${value}@example.com`, emails: [`${value}@example.com`], name: value, picture: null, roles: u.roles, supporter: false, accountIds: {}, via: "provider" } as const) : null;
    },
  } as unknown as Env["ACCOUNTS"],
  ASSETS: {
    async fetch(req: Request) {
      const f = FILES[new URL(req.url).pathname];
      if (!f) return new Response("Not found", { status: 404 });
      const len = typeof f.body === "string" ? new TextEncoder().encode(f.body).length : f.body.length;
      return new Response(f.body as BodyInit, { headers: { "Content-Type": f.type, "Content-Length": String(len), "Cache-Control": "public, max-age=14400" } });
    },
  },
};

const get = (path: string, who?: string, method = "GET") =>
  worker.fetch(new Request(ORIGIN + path, { method, headers: who ? { Cookie: `site_session=${who}` } : {} }), env);

test("a visitor who isn't signed in is sent to sign in and back", async () => {
  for (const path of [`${BASE}/`, `${BASE}/play/`, `${BASE}/download/iron-haze-linux.zip`]) {
    const r = await get(path);
    assert.equal(r.status, 302, path);
    assert.equal(r.headers.get("location"), `/auth/sign-in?return=${encodeURIComponent(path)}`, path);
  }
});

test("a signed-in player without the role gets the not-invited page, and none of the game", async () => {
  for (const path of [`${BASE}/`, `${BASE}/play/index.pck`, `${BASE}/play/index.wasm`, `${BASE}/download/iron-haze-linux.zip`]) {
    const r = await get(path, "player");
    assert.equal(r.status, 403, path);
    assert.match(await r.text(), /open to invited players only/, path);
  }
});

test("a member gets the page and the files, privately", async () => {
  const page = await get(`${BASE}/`, "member");
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("cache-control"), "private, no-cache");
  const pck = await get(`${BASE}/play/index.pck`, "member");
  assert.equal(await pck.text(), "pck");
  assert.equal(pck.headers.get("cache-control"), "private, max-age=3600");
});

test("the engine and the downloads are joined from their parts", async () => {
  const wasm = await get(`${BASE}/play/index.wasm`, "member");
  assert.equal(wasm.headers.get("content-type"), "application/wasm");
  assert.equal(wasm.headers.get("content-length"), "5");
  assert.deepEqual(new Uint8Array(await wasm.arrayBuffer()), new Uint8Array([1, 2, 3, 4, 5]));
  const zip = await get(`${BASE}/download/iron-haze-linux.zip`, "member");
  assert.equal(zip.headers.get("content-disposition"), 'attachment; filename="iron-haze-linux.zip"');
  assert.deepEqual(new Uint8Array(await zip.arrayBuffer()), new Uint8Array([4, 5, 1, 2, 3]));
  const head = await get(`${BASE}/download/iron-haze-linux.zip`, "member", "HEAD");
  assert.equal(head.headers.get("content-length"), "5");
  assert.equal((await get(`${BASE}/download/iron-haze-windows.zip`, "member")).status, 404);
  assert.equal((await get(`${BASE}/download/iron-haze-amiga.zip`, "member")).status, 404);
});

test("the stylesheet and icon are public; nothing outside the game is answered; no writes", async () => {
  assert.equal((await get(`${BASE}/shell.css`)).status, 200);
  assert.equal((await get(`${BASE}/favicon.svg`)).status, 200);
  assert.equal((await get("/games/retro/chess/", "member")).status, 404);
  assert.equal((await get(`${BASE}/`, "member", "POST")).status, 405);
  const bare = await get(BASE, "member");
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("location"), `${ORIGIN}${BASE}/`);
});
