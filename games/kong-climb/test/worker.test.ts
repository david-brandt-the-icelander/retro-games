// The Kong Climb Worker (worker/handler.ts): who may fetch what.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { checkVendored } from "../../../vendor/icelander-auth/check.mjs";
import { BASE, ROLE } from "../worker/config";
import { handle, type Env } from "../worker/handler";

const ORIGIN = "https://icelander.net";

const FILES: Record<string, { body: string; type: string }> = {
  "/": { body: "<!doctype html><title>Kong Climb</title>", type: "text/html" },
  "/kong.js": { body: "js", type: "text/javascript" },
};

const USERS: Record<string, { roles: string[] }> = {
  member: { roles: ["site:reader", "games:play", ROLE] },
  player: { roles: ["site:reader", "games:play"] },
};

const served: string[] = [];

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
        const path = new URL(req.url).pathname;
        served.push(path);
        const f = FILES[path];
        if (!f) return new Response("Not found", { status: 404 });
        return new Response(f.body, { headers: { "Content-Type": f.type } });
      },
    },
    ...extra,
  };
}

const env = makeEnv();
const req = (path: string, who?: string, init: RequestInit = {}) => new Request(ORIGIN + path, { ...init, headers: { ...(who ? { Cookie: `site_session=${who}` } : {}) } });

test("a visitor who isn't signed in is sent to sign in and back, and gets nothing", async () => {
  served.length = 0;
  for (const path of [`${BASE}/`, `${BASE}/kong.js`]) {
    const r = await handle(req(path), env);
    assert.equal(r.status, 302, path);
    assert.equal(r.headers.get("location"), `/auth/sign-in?return=${encodeURIComponent(path)}`, path);
  }
  assert.deepEqual(served, []);
});

test("a signed-in player without the role gets the not-invited page, and nothing is served", async () => {
  served.length = 0;
  const page = await handle(req(`${BASE}/`, "player"), env);
  assert.equal(page.status, 403);
  assert.match(await page.text(), /invited players only/);
  assert.equal((await handle(req(`${BASE}/kong.js`, "player"), env)).status, 403);
  assert.deepEqual(served, []);
});

test("an invited player gets the page and the script, privately", async () => {
  const page = await handle(req(`${BASE}/`, "member"), env);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("cache-control"), "private, no-cache");
  assert.match(page.headers.get("content-security-policy") ?? "", /default-src 'self'/);
  assert.match(page.headers.get("content-security-policy") ?? "", /script-src 'self'(;|$)/);
  const js = await handle(req(`${BASE}/kong.js`, "member"), env);
  assert.equal(js.status, 200);
  assert.equal(js.headers.get("cache-control"), "private, max-age=300");
});

test("nothing outside the game is answered; no writes; the bare address gets its slash", async () => {
  assert.equal((await handle(req("/games/retro/chess/", "member"), env)).status, 404);
  assert.equal((await handle(new Request(ORIGIN + `${BASE}/`, { method: "POST", headers: { Cookie: "site_session=member" } }), env)).status, 405);
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

test("the vendored sign-in library is unchanged", () => {
  assert.match(checkVendored(new URL("../../../../vendor/icelander-auth/", import.meta.url)), /^\d+\.\d+\.\d+$/);
});
