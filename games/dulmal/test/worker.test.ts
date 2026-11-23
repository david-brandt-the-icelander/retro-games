// The Worker's routes, with fake assets and rooms.
import assert from "node:assert/strict";
import { test } from "node:test";
import worker, { newCode, type Env } from "../worker/index";
import { CODE_RE } from "../worker/config";

function env() {
  const calls: { name: string; url: string }[] = [];
  const taken = new Set(["first"]);
  const e: Env = {
    ASSETS: { fetch: async () => new Response("<!doctype html>", { headers: { "Content-Type": "text/html" } }) },
    ROOMS: {
      idFromName: (name: string) => name,
      get: (id: unknown) => ({
        fetch: async (input: Request | string) => {
          const url = typeof input === "string" ? input : input.url;
          calls.push({ name: String(id), url });
          if (url.endsWith("/create")) {
            if (taken.size && taken.delete("first")) return new Response("taken", { status: 409 });
            return Response.json({ id: "p1", token: "t1" });
          }
          return new Response("socket", { status: 200 });
        },
      }),
    },
  };
  return { e, calls };
}

const at = (path: string, init?: RequestInit) => new Request(`https://icelander.net${path}`, init);

test("room codes are four easy letters", () => {
  for (let i = 0; i < 200; i++) assert.match(newCode(), CODE_RE);
});

test("creating a room tries another code when one is taken", async () => {
  const { e, calls } = env();
  const res = await worker.fetch(at("/games/fresh/dulmal/api/rooms", { method: "POST", body: JSON.stringify({ name: "Anna" }) }), e);
  assert.equal(res.status, 200);
  const body = (await res.json()) as { code: string; id: string; token: string };
  assert.match(body.code, CODE_RE);
  assert.equal(body.token, "t1");
  assert.equal(calls.length, 2);
  const noName = await worker.fetch(at("/games/fresh/dulmal/api/rooms", { method: "POST", body: "{}" }), e);
  assert.equal(noName.status, 400);
});

test("the WebSocket route goes to the room named by its code", async () => {
  const { e, calls } = env();
  const plainGet = await worker.fetch(at("/games/fresh/dulmal/api/rooms/HKLS/ws"), e);
  assert.equal(plainGet.status, 426);
  await worker.fetch(at("/games/fresh/dulmal/api/rooms/hkls/ws", { headers: { Upgrade: "websocket" } }), e);
  assert.deepEqual(calls.at(-1), { name: "HKLS", url: "https://room/ws" });
  const bad = await worker.fetch(at("/games/fresh/dulmal/api/rooms/QQQQ/ws", { headers: { Upgrade: "websocket" } }), e);
  assert.equal(bad.status, 404);
});

test("the page is served with no sign-in, and other paths are not ours", async () => {
  const { e } = env();
  const page = await worker.fetch(at("/games/fresh/dulmal/"), e);
  assert.equal(page.status, 200);
  assert.equal(page.headers.get("Cache-Control"), "no-cache");
  const bare = await worker.fetch(at("/games/fresh/dulmal?herbergi=HKLS"), e);
  assert.equal(bare.status, 301);
  assert.equal(bare.headers.get("Location"), "https://icelander.net/games/fresh/dulmal/?herbergi=HKLS");
  assert.equal((await worker.fetch(at("/games/other/"), e)).status, 404);
});
