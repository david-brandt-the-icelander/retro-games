// The Kvarðinn Worker (worker/handler.ts): who may fetch what, and where each request goes.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { BASE, ROLE } from "../worker/config";
import { handle, type Env } from "../worker/handler";

const ORIGIN = "https://icelander.net";

const FILES: Record<string, { body: string; type: string }> = {
  "/": { body: "<!doctype html><title>Kvarðinn</title>", type: "text/html" },
  "/app.js": { body: "js", type: "text/javascript" },
  "/icon.svg": { body: "svg", type: "image/svg+xml" },
};

const USERS: Record<string, { roles: string[] }> = {
  member: { roles: ["site:reader", "games:play", ROLE] },
  player: { roles: ["site:reader", "games:play"] },
};

/** Room codes the fake Durable Object namespace has been asked to create, and sockets it was asked for. */
const created: string[] = [];
const sockets: string[] = [];

function makeEnv(extra: Partial<Env> = {}): Env {
  return {
    BASE,
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
        return new Response(f.body, { headers: { "Content-Type": f.type } });
      },
    },
    ROOMS: {
      idFromName: (name: string) => name,
      get: (id: unknown) => ({
        async fetch(input: string | Request, init?: RequestInit) {
          if (typeof input === "string") {
            created.push(String(init?.body));
            return new Response("created", { status: 201 });
          }
          sockets.push(String(id));
          return new Response("socket", { status: 200 });
        },
      }),
    },
    ...extra,
  };
}

const env = makeEnv();
const req = (path: string, who?: string, init: RequestInit = {}) =>
  new Request(ORIGIN + path, { ...init, headers: { ...(who ? { Cookie: `site_session=${who}` } : {}), ...(init.headers as Record<string, string> | undefined) } });
const ws = { Upgrade: "websocket" };

test("a visitor who isn't signed in is sent to sign in and back, and gets no room or socket", async () => {
  for (const path of [`${BASE}/`, `${BASE}/app.js`]) {
    const r = await handle(req(path), env);
    assert.equal(r.status, 302, path);
    assert.equal(r.headers.get("location"), `/auth/sign-in?return=${encodeURIComponent(path)}`, path);
  }
  assert.equal((await handle(req(`${BASE}/api/rooms`, undefined, { method: "POST" }), env)).status, 401);
  assert.equal((await handle(req(`${BASE}/ws/ABDE`, undefined, { headers: ws }), env)).status, 401);
  assert.deepEqual([created.length, sockets.length], [0, 0]);
});

test("a signed-in player without the role gets the not-invited page, and no room or socket", async () => {
  const page = await handle(req(`${BASE}/`, "player"), env);
  assert.equal(page.status, 403);
  assert.match(await page.text(), /aðeins fyrir boðsgesti/);
  assert.equal((await handle(req(`${BASE}/app.js`, "player"), env)).status, 403);
  assert.equal((await handle(req(`${BASE}/api/rooms`, "player", { method: "POST" }), env)).status, 403);
  assert.equal((await handle(req(`${BASE}/ws/ABDE`, "player", { headers: ws }), env)).status, 403);
  assert.deepEqual([created.length, sockets.length], [0, 0]);
});

test("an invited player gets the page privately, can start a room and reach its socket", async () => {
  const page = await handle(req(`${BASE}/`, "member"), env);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("cache-control"), "private, no-cache");
  assert.match(page.headers.get("content-security-policy") ?? "", /default-src 'self'/);
  const room = await handle(req(`${BASE}/api/rooms`, "member", { method: "POST", headers: { Origin: ORIGIN } }), env);
  assert.equal(room.status, 200);
  const { code } = (await room.json()) as { code: string };
  assert.match(code, /^[ABDEFGHJKLMNPRSTUVXY]{4}$/);
  assert.deepEqual(created, [code]);
  assert.equal((await handle(req(`${BASE}/ws/${code.toLowerCase()}`, "member", { headers: ws }), env)).status, 200);
  assert.deepEqual(sockets, [code]);
  assert.equal((await handle(req(`${BASE}/ws/ABCD`, "member", { headers: ws }), env)).status, 404, "C is never in a code");
  assert.equal((await handle(req(`${BASE}/ws/ABDE`, "member"), env)).status, 426, "not a WebSocket");
});

test("nothing outside the game is answered; no other writes; the bare address gets its slash", async () => {
  assert.equal((await handle(req("/games/retro/chess/", "member"), env)).status, 404);
  assert.equal((await handle(req(`${BASE}/`, "member", { method: "POST" }), env)).status, 405);
  assert.equal((await handle(req(`${BASE}/api/rooms`, "member"), env)).status, 405);
  const bare = await handle(req(BASE, "member"), env);
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("location"), `${ORIGIN}${BASE}/`);
});

test("the standalone environment is open to anyone at the root", async () => {
  const open = makeEnv({ BASE: "", OPEN: "1", ACCOUNTS: undefined, ACCOUNTS_JWKS: undefined });
  const page = await handle(req("/"), open);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("cache-control"), "public, no-cache");
});
