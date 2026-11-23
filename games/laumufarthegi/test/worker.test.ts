// The Worker (worker/index.ts): the page is open to all, starting a room needs icelander.net's sign-in, and the
// room's WebSocket checks its code and origin.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { checkVendored } from "../../../vendor/icelander-auth/check.mjs";
import { BASE } from "../shared/protocol";
import worker, { type Env } from "../worker/index";

const ORIGIN = "https://icelander.net";

function env(over: Partial<Env> = {}): Env & { created: string[]; forwarded: string[] } {
  const created: string[] = [];
  const forwarded: string[] = [];
  return {
    created, forwarded,
    ACCOUNTS_JWKS: '{"keys":[{"kty":"OKP","crv":"Ed25519","kid":"k2026a","x":"WIEomi0LTalJvQndhD7abl8ty3YcliQ0vEz4XjLXayc"}]}',
    ACCOUNTS: {
      async session(value: string) {
        return value === "member"
          ? ({ id: "a-member", email: "m@example.com", emails: ["m@example.com"], name: "Magga", picture: null, roles: ["site:reader", "games:play"], supporter: false, accountIds: {}, via: "provider" } as const)
          : null;
      },
    } as unknown as Env["ACCOUNTS"],
    ASSETS: {
      async fetch(req: Request) {
        const path = new URL(req.url).pathname;
        if (path === `${BASE}/`) return new Response("<!doctype html><title>Laumufarþegi</title>", { headers: { "Content-Type": "text/html" } });
        if (path === `${BASE}/app.js`) return new Response("js", { headers: { "Content-Type": "text/javascript" } });
        return new Response("Not found", { status: 404 });
      },
    },
    ROOMS: {
      idFromName: (name: string) => name,
      get: (id: unknown) => ({
        async fetch(req: Request | string, init?: RequestInit) {
          const r = typeof req === "string" ? new Request(req, init) : req;
          const path = new URL(r.url).pathname;
          if (path === "/create") {
            const body = (await r.json()) as { code: string; name: string };
            created.push(`${body.code}:${body.name}`);
            return Response.json({ code: id, token: "tok", playerId: "pid" });
          }
          forwarded.push(`${id}${path}`);
          return new Response("upgraded", { status: 200 });
        },
      }),
    },
    ...over,
  };
}

const call = (e: Env, path: string, init: RequestInit & { who?: string } = {}) => {
  const headers = new Headers(init.headers);
  if (init.who) headers.set("Cookie", `site_session=${init.who}`);
  return worker.fetch(new Request(ORIGIN + path, { ...init, headers }), e);
};

test("the vendored sign-in library is unchanged", () => {
  // The test runs from dist-test/, directly inside the game folder.
  assert.match(checkVendored(new URL("../../../vendor/icelander-auth/", import.meta.url)), /^\d+\.\d+\.\d+$/);
});

test("the page is open to anyone, with no sign-in", async () => {
  const r = await call(env(), `${BASE}/`);
  assert.equal(r.status, 200);
  assert.equal(r.headers.get("Cache-Control"), "no-cache");
  assert.equal((await call(env(), `${BASE}/app.js`)).status, 200);
  const bare = await call(env(), BASE);
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("location"), `${ORIGIN}${BASE}/`);
});

test("starting a room needs a sign-in; a signed-in player gets a room code and token", async () => {
  const e = env();
  const anon = await call(e, `${BASE}/api/rooms`, { method: "POST", body: "{}", headers: { Origin: ORIGIN } });
  assert.equal(anon.status, 401);
  assert.match(((await anon.json()) as { signIn: string }).signIn, /\/auth\/sign-in/);
  assert.equal(((await (await call(e, `${BASE}/api/me`)).json()) as { canHost: boolean }).canHost, false);

  const ok = await call(e, `${BASE}/api/rooms`, { method: "POST", who: "member", body: JSON.stringify({ name: "Anna" }), headers: { Origin: ORIGIN } });
  assert.equal(ok.status, 201);
  const room = (await ok.json()) as { code: string; token: string };
  assert.match(room.code, /^[A-Z]{5}$/);
  assert.equal(e.created[0], `${room.code}:Anna`);
  const me = (await (await call(e, `${BASE}/api/me`, { who: "member" })).json()) as { canHost: boolean; name: string };
  assert.deepEqual([me.canHost, me.name], [true, "Magga"]);
});

test("HOST_SIGN_IN none lets anyone start a room; another site may not start one", async () => {
  const e = env({ HOST_SIGN_IN: "none" });
  assert.equal((await call(e, `${BASE}/api/rooms`, { method: "POST", body: JSON.stringify({ name: "Óli" }), headers: { Origin: ORIGIN } })).status, 201);
  assert.equal((await call(e, `${BASE}/api/rooms`, { method: "POST", body: "{}", headers: { Origin: "https://evil.example" } })).status, 403);
  assert.equal((await call(e, `${BASE}/api/rooms`)).status, 405);
});

test("the room socket: a valid code and a WebSocket upgrade from this site only", async () => {
  const e = env();
  const up = { Upgrade: "websocket", Origin: ORIGIN };
  assert.equal((await call(e, `${BASE}/api/rooms/ABCDE/ws`, { headers: up })).status, 200);
  assert.deepEqual(e.forwarded, ["ABCDE/ws"]);
  assert.equal((await call(e, `${BASE}/api/rooms/ABCDI/ws`, { headers: up })).status, 404, "I is not a code letter");
  assert.equal((await call(e, `${BASE}/api/rooms/ABCDE/ws`)).status, 426);
  assert.equal((await call(e, `${BASE}/api/rooms/ABCDE/ws`, { headers: { Upgrade: "websocket", Origin: "https://evil.example" } })).status, 403);
  assert.equal((await call(e, `${BASE}/api/nothing`)).status, 404);
});

test("paths outside the game are not answered", async () => {
  assert.equal((await call(env(), "/games/fresh/other/")).status, 404);
});
