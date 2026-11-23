// The Dulmál Worker: who may fetch what, and its routes, with fake assets, rooms and login service.
import assert from "node:assert/strict";
import { test } from "node:test";
import { BASE, CODE_RE, ROLE } from "../worker/config";
import worker, { newCode, type Env } from "../worker/index";

const ORIGIN = "https://icelander.net";
const USERS: Record<string, { roles: string[] }> = {
  member: { roles: ["site:reader", "games:play", ROLE] },
  player: { roles: ["site:reader", "games:play"] },
};

function env() {
  const calls: { name: string; url: string }[] = [];
  let taken = true; // the first code tried is taken
  const e: Env = {
    // The login service's real public key set (wrangler.jsonc): the library counts sign-in as configured only with one.
    ACCOUNTS_JWKS: '{"keys":[{"kty":"OKP","crv":"Ed25519","kid":"k2026a","x":"WIEomi0LTalJvQndhD7abl8ty3YcliQ0vEz4XjLXayc"}]}',
    ACCOUNTS: {
      async session(value: string) {
        const u = USERS[value];
        return u ? ({ id: `a-${value}`, email: `${value}@example.com`, emails: [`${value}@example.com`], name: value, picture: null, roles: u.roles, supporter: false, accountIds: {}, via: "provider" } as const) : null;
      },
    } as unknown as Env["ACCOUNTS"],
    ASSETS: { fetch: async () => new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } }) },
    ROOMS: {
      idFromName: (name: string) => name,
      get: (id: unknown) => ({
        fetch: async (input: Request | string) => {
          const url = typeof input === "string" ? input : input.url;
          calls.push({ name: String(id), url });
          if (url.endsWith("/create")) {
            if (taken) { taken = false; return new Response("taken", { status: 409 }); }
            return Response.json({ id: "p1", token: "t1" });
          }
          return new Response("socket", { status: 200 });
        },
      }),
    },
  };
  return { e, calls };
}

function at(path: string, who?: string, init: RequestInit = {}) {
  const headers = new Headers(init.headers);
  if (who) headers.set("Cookie", `site_session=${who}`);
  return new Request(ORIGIN + path, { ...init, headers });
}

test("room codes are four easy letters", () => {
  for (let i = 0; i < 200; i++) assert.match(newCode(), CODE_RE);
});

test("a visitor who isn't signed in is sent to sign in, and gets no room", async () => {
  const { e, calls } = env();
  const page = await worker.fetch(at(`${BASE}/?herbergi=HKLS`), e);
  assert.equal(page.status, 302);
  assert.equal(page.headers.get("location"), `/auth/sign-in?return=${encodeURIComponent(`${BASE}/?herbergi=HKLS`)}`);
  const create = await worker.fetch(at(`${BASE}/api/rooms`, undefined, { method: "POST", body: '{"name":"Anna"}' }), e);
  assert.ok(create.status === 401 || create.status === 403, String(create.status));
  const ws = await worker.fetch(at(`${BASE}/api/rooms/HKLS/ws`, undefined, { headers: { Upgrade: "websocket" } }), e);
  assert.ok(ws.status === 401 || ws.status === 403, String(ws.status));
  assert.equal(calls.length, 0, "no room was touched");
});

test("a signed-in player without the role gets the not-invited page, and no room", async () => {
  const { e, calls } = env();
  const page = await worker.fetch(at(`${BASE}/`, "player"), e);
  assert.equal(page.status, 403);
  assert.match(await page.text(), /aðeins opið boðsgestum/);
  const ws = await worker.fetch(at(`${BASE}/api/rooms/HKLS/ws`, "player", { headers: { Upgrade: "websocket" } }), e);
  assert.equal(ws.status, 403);
  assert.equal(calls.length, 0);
});

test("a member gets the page, privately", async () => {
  const { e } = env();
  const page = await worker.fetch(at(`${BASE}/`, "member"), e);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("Cache-Control"), "private, no-cache");
  const bare = await worker.fetch(at(`${BASE}?herbergi=HKLS`, "member"), e);
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("Location"), `${ORIGIN}${BASE}/?herbergi=HKLS`);
  assert.equal((await worker.fetch(at("/games/other/", "member"), e)).status, 404);
  assert.equal((await worker.fetch(at(`${BASE}/`, "member", { method: "POST" }), e)).status, 405);
});

test("creating a room tries another code when one is taken", async () => {
  const { e, calls } = env();
  const res = await worker.fetch(at(`${BASE}/api/rooms`, "member", { method: "POST", body: JSON.stringify({ name: "Anna" }) }), e);
  assert.equal(res.status, 200);
  const body = (await res.json()) as { code: string; id: string; token: string };
  assert.match(body.code, CODE_RE);
  assert.equal(body.token, "t1");
  assert.equal(calls.length, 2);
  const noName = await worker.fetch(at(`${BASE}/api/rooms`, "member", { method: "POST", body: "{}" }), e);
  assert.equal(noName.status, 400);
});

test("the WebSocket route goes to the room named by its code", async () => {
  const { e, calls } = env();
  assert.equal((await worker.fetch(at(`${BASE}/api/rooms/HKLS/ws`, "member"), e)).status, 426);
  await worker.fetch(at(`${BASE}/api/rooms/hkls/ws`, "member", { headers: { Upgrade: "websocket" } }), e);
  assert.deepEqual(calls.at(-1), { name: "HKLS", url: "https://room/ws" });
  const bad = await worker.fetch(at(`${BASE}/api/rooms/QQQQ/ws`, "member", { headers: { Upgrade: "websocket" } }), e);
  assert.equal(bad.status, 404);
});
