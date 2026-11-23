// The room's Durable Object (worker/room.ts), on a fake runtime: joining, seats kept across reloads, each socket
// seeing only its own view, the alarm's timeouts, removal and clean-up.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import type { View } from "../shared/game";
import type { ServerMessage } from "../shared/protocol";
import { IDLE_MS, Room, type RoomContext, type WebSocketLike } from "../worker/room";
import { TOPICS } from "../shared/topics";

class FakeSocket implements WebSocketLike {
  sent: ServerMessage[] = [];
  closed: number | null = null;
  private att: unknown = null;
  send(data: string) { this.sent.push(data === "pong" ? ({ t: "pong" } as unknown as ServerMessage) : JSON.parse(data)); }
  close(code?: number) { this.closed = code ?? 1000; }
  serializeAttachment(v: unknown) { this.att = structuredClone(v); }
  deserializeAttachment() { return this.att; }
  last<T extends ServerMessage["t"]>(t: T): Extract<ServerMessage, { t: T }> | undefined {
    return [...this.sent].reverse().find((m) => m.t === t) as Extract<ServerMessage, { t: T }> | undefined;
  }
  view(): View { return this.last("state")!.view; }
}

function fakeCtx() {
  const data = new Map<string, unknown>();
  let alarm: number | null = null;
  const sockets: FakeSocket[] = [];
  const ctx: RoomContext = {
    storage: {
      async get<T>(k: string) { return structuredClone(data.get(k)) as T | undefined; },
      async put(k: string, v: unknown) { data.set(k, structuredClone(v)); },
      async deleteAll() { data.clear(); },
      async setAlarm(t: number) { alarm = t; },
    },
    acceptWebSocket(ws: WebSocketLike) { sockets.push(ws as FakeSocket); },
    getWebSockets() { return sockets.filter((s) => s.closed === null); },
  };
  return { ctx, data, sockets, alarmAt: () => alarm };
}

function setup() {
  let t = 1_000_000;
  let n = 0;
  const f = fakeCtx();
  const deps = { now: () => t, rand: (() => { let x = 0.1; return () => (x = (x * 9301 + 0.49297) % 1); })(), id: () => `id${++n}`, topics: TOPICS };
  const room = new Room(f.ctx, {}, deps);
  const open = () => { const ws = new FakeSocket(); f.ctx.acceptWebSocket(ws); return ws; };
  const say = (ws: FakeSocket, msg: unknown) => room.webSocketMessage(ws, JSON.stringify(msg));
  return { ...f, room, open, say, advance: (ms: number) => { t += ms; }, now: () => t };
}

async function create(r: ReturnType<typeof setup>, name = "Anna") {
  const res = await r.room.fetch(new Request("https://room/create", { method: "POST", body: JSON.stringify({ code: "ABCDE", name }) }));
  assert.equal(res.status, 200);
  return (await res.json()) as { code: string; token: string; playerId: string };
}

test("a room is made once; a second create for the same code is refused", async () => {
  const r = setup();
  const made = await create(r);
  assert.equal(made.code, "ABCDE");
  const again = await r.room.fetch(new Request("https://room/create", { method: "POST", body: JSON.stringify({ code: "ABCDE" }) }));
  assert.equal(again.status, 409);
});

test("the host joins with the token; guests join by name and keep their seat after a reload", async () => {
  const r = setup();
  const host = await create(r);
  const hs = r.open();
  await r.say(hs, { t: "join", token: host.token });
  assert.equal(hs.last("welcome")!.playerId, host.playerId);
  assert.equal(hs.view().me.host, true);

  const gs = r.open();
  await r.say(gs, { t: "join", name: "Bjarni" });
  const welcome = gs.last("welcome")!;
  assert.equal(gs.view().players.length, 2);

  // The guest reloads: a new socket with the stored token gets the same seat, not a new one.
  gs.close(1001);
  await r.room.webSocketClose(gs);
  assert.equal(hs.view().players.find((p) => p.id === welcome.playerId)!.connected, false);
  const gs2 = r.open();
  await r.say(gs2, { t: "join", token: welcome.token });
  assert.equal(gs2.last("welcome")!.playerId, welcome.playerId);
  assert.equal(gs2.view().players.length, 2);
  assert.equal(hs.view().players.find((p) => p.id === welcome.playerId)!.connected, true);
});

test("a taken name or an unknown token without a name is refused, and nothing is done before joining", async () => {
  const r = setup();
  await create(r);
  const a = r.open();
  await r.say(a, { t: "join", name: "anna" });
  assert.match(a.last("error")!.message, /nafn/);
  const b = r.open();
  await r.say(b, { t: "join", token: "nope" });
  assert.ok(b.last("error"));
  const c = r.open();
  await r.say(c, { t: "start" });
  assert.match(c.last("error")!.message, /Gakktu fyrst/);
});

test("each socket gets its own view: the secret only for those allowed, and a second tab keeps a player connected", async () => {
  const r = setup();
  const host = await create(r);
  const socks = [r.open()];
  await r.say(socks[0], { t: "join", token: host.token });
  for (const name of ["Bjarni", "Dísa", "Einar"]) { const s = r.open(); await r.say(s, { t: "join", name }); socks.push(s); }
  await r.say(socks[0], { t: "start" });
  const views = socks.map((s) => s.view());
  const stowaways = views.filter((v) => v.me.stowaway);
  assert.equal(stowaways.length, 1);
  assert.equal(stowaways[0].round!.secret, null);
  const secrets = new Set(views.filter((v) => !v.me.stowaway).map((v) => v.round!.secret));
  assert.equal(secrets.size, 1);
  assert.ok(![...secrets].includes(null));

  // A second tab of the same player, then closing one of them: still connected.
  const welcome = socks[1].last("welcome")!;
  const tab = r.open();
  await r.say(tab, { t: "join", token: welcome.token });
  socks[1].close(1001);
  await r.room.webSocketClose(socks[1]);
  assert.equal(socks[0].view().players.find((p) => p.id === welcome.playerId)!.connected, true);
});

test("the alarm runs out a turn, and a room unused for a day deletes itself", async () => {
  const r = setup();
  const host = await create(r);
  const socks = [r.open()];
  await r.say(socks[0], { t: "join", token: host.token });
  for (const name of ["Bjarni", "Dísa"]) { const s = r.open(); await r.say(s, { t: "join", name }); socks.push(s); }
  await r.say(socks[0], { t: "start" });
  const deadline = socks[0].view().round!.deadline!;
  assert.equal(r.alarmAt(), deadline);
  r.advance(deadline - r.now());
  await r.room.alarm();
  assert.equal(socks[0].view().round!.clues[0].text, "—");
  assert.equal(socks[0].view().round!.turn, 1);

  r.advance(IDLE_MS);
  await r.room.alarm(); // runs out the next turn first (state changed: updatedAt moves on)
  r.advance(IDLE_MS + 1);
  await r.room.alarm();
  assert.equal(r.data.size, 0, "storage cleared");
  assert.ok(socks.every((s) => s.closed === 4404));
});

test("a removed player's socket is told so and closed", async () => {
  const r = setup();
  const host = await create(r);
  const hs = r.open();
  await r.say(hs, { t: "join", token: host.token });
  const gs = r.open();
  await r.say(gs, { t: "join", name: "Bjarni" });
  await r.say(hs, { t: "kick", player: gs.last("welcome")!.playerId });
  assert.equal(gs.last("removed")!.t, "removed");
  assert.equal(gs.closed, 4403);
  assert.equal(hs.view().players.length, 1);
});

test("a message to a room that no longer exists closes the socket", async () => {
  const r = setup();
  const ws = r.open();
  await r.say(ws, { t: "join", name: "X" });
  assert.equal(ws.closed, 4404);
});
