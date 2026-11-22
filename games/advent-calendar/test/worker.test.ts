// The Advent calendar Worker: who may fetch what.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { BASE, ROLE } from "../worker/config";
import worker, { type Env } from "../worker/index";

const ORIGIN = "https://icelander.net";

/** Static assets as the build writes them. */
const FILES: Record<string, { body: string; type: string }> = {
  [`${BASE}/`]: { body: "<!doctype html><title>Advent</title>", type: "text/html" },
  [`${BASE}/calendar.js`]: { body: "(function(){})();", type: "text/javascript" },
  [`${BASE}/assets/house.webp`]: { body: "webp", type: "image/webp" },
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
      return new Response(f.body, { headers: { "Content-Type": f.type, "Cache-Control": "public, max-age=14400" } });
    },
  },
};

const get = (path: string, who?: string, method = "GET") =>
  worker.fetch(new Request(ORIGIN + path, { method, headers: who ? { Cookie: `site_session=${who}` } : {} }), env);

test("a visitor who isn't signed in is sent to sign in and back", async () => {
  for (const path of [`${BASE}/`, `${BASE}/calendar.js`, `${BASE}/assets/house.webp`]) {
    const r = await get(path);
    assert.equal(r.status, 302, path);
    assert.equal(r.headers.get("location"), `/auth/sign-in?return=${encodeURIComponent(path)}`, path);
  }
});

test("a signed-in player without the role gets the not-invited page, and none of the calendar", async () => {
  for (const path of [`${BASE}/`, `${BASE}/calendar.js`, `${BASE}/assets/house.webp`]) {
    const r = await get(path, "player");
    assert.equal(r.status, 403, path);
    assert.match(await r.text(), /open to invited players only/, path);
  }
});

test("a member gets the page and the art, privately", async () => {
  const page = await get(`${BASE}/`, "member");
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("cache-control"), "private, no-cache");
  const art = await get(`${BASE}/assets/house.webp`, "member");
  assert.equal(await art.text(), "webp");
  assert.equal(art.headers.get("cache-control"), "private, max-age=3600");
  assert.equal((await get(`${BASE}/art/build.mjs`, "member")).status, 404);
});

test("nothing outside the calendar is answered; no writes; the bare address gets its slash", async () => {
  assert.equal((await get("/games/retro/chess/", "member")).status, 404);
  assert.equal((await get(`${BASE}/`, "member", "POST")).status, 405);
  const bare = await get(BASE, "member");
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("location"), `${ORIGIN}${BASE}/`);
});
