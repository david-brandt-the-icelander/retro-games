// The room's Durable Object logic with fake sockets: what each device is sent, reconnecting to
// the same seat, the timer alarm, and that the key never reaches a guesser's socket.
import assert from "node:assert/strict";
import { test } from "node:test";
import WORDS_TEXT from "../data/ord.txt";
import type { Room } from "../src/shared/game";
import type { ServerMsg, View } from "../src/shared/protocol";
import { parseWords } from "../src/shared/words";
import { IDLE_MS, RoomCore, type Attachment, type RoomHost, type Socket } from "../worker/room";
import { seeded } from "./helpers";

class FakeSocket implements Socket {
  sent: ServerMsg[] = [];
  raw: string[] = [];
  att: Attachment = { id: null, screen: false };
  closedWith: number | null = null;
  send(data: string) { this.raw.push(data); this.sent.push(JSON.parse(data)); }
  close(code?: number) { this.closedWith = code ?? 1000; }
  last<T extends ServerMsg["t"]>(t: T): Extract<ServerMsg, { t: T }> | undefined {
    return [...this.sent].reverse().find((m) => m.t === t) as Extract<ServerMsg, { t: T }> | undefined;
  }
  get view(): View { return this.last("state")!.view; }
}

function makeRoom() {
  let now = 1_000_000;
  const sockets: FakeSocket[] = [];
  let tokenCount = 0;
  const saved: { room: Room | null; alarm: number | null } = { room: null, alarm: null };
  const host: RoomHost = {
    sockets: () => sockets,
    attachment: (ws) => (ws as FakeSocket).att,
    attach: (ws, att) => { (ws as FakeSocket).att = att; },
    save: async (room) => { saved.room = room && structuredClone(room); },
    alarm: async (at) => { saved.alarm = at; },
    now: () => now,
    random: seeded(3),
    token: (n) => `tok${++tokenCount}`.padEnd(n, "x"),
  };
  const core = new RoomCore(null, host, parseWords(WORDS_TEXT));
  const connect = () => { const ws = new FakeSocket(); sockets.push(ws); core.open(ws); return ws; };
  const drop = (ws: FakeSocket) => { sockets.splice(sockets.indexOf(ws), 1); core.closed(ws); };
  const say = (ws: FakeSocket, msg: unknown) => core.message(ws, JSON.stringify(msg));
  return { core, host, saved, sockets, connect, drop, say, advance: (ms: number) => { now += ms; }, get now() { return now; } };
}

async function fourPlayers() {
  const r = makeRoom();
  const seat0 = (await r.core.create("HKLS", "Anna"))!;
  const devices: FakeSocket[] = [];
  const a = r.connect();
  await r.say(a, { t: "hello", seat: seat0 });
  devices.push(a);
  for (const name of ["Bjarni", "Guðrún", "Þórður"]) {
    const ws = r.connect();
    await r.say(ws, { t: "hello" });
    await r.say(ws, { t: "join", name });
    devices.push(ws);
  }
  return { ...r, devices, seat0 };
}

test("a room can only be created once, and an unknown room says so", async () => {
  const r = makeRoom();
  const ws = r.connect();
  assert.equal(ws.last("gone")?.t, "gone");
  assert.equal(ws.closedWith, 4404);
  assert.ok(await r.core.create("HKLS", "Anna"));
  assert.equal(await r.core.create("HKLS", "Bjarni"), null);
  assert.equal(r.saved.room?.players.length, 1);
});

test("players join, are put in teams and everyone sees everyone", async () => {
  const { devices } = await fourPlayers();
  const v = devices[0]!.view;
  assert.equal(v.players.length, 4);
  assert.equal(v.hostId, v.you!.id);
  assert.equal(v.players.filter((p) => p.team === "hraun").length, 2);
  assert.ok(v.players.every((p) => p.online));
  assert.equal(devices[3]!.view.you!.name, "Þórður");
  assert.ok(devices[3]!.last("seat")!.token);
});

test("the hidden key reaches only the clue-givers' sockets", async () => {
  const { devices, say } = await fourPlayers();
  await say(devices[0]!, { t: "start" });
  for (const ws of devices) {
    const v = ws.view;
    const known = v.game!.cards.filter((c) => c.kind !== null).length;
    assert.equal(known, v.you!.role === "clue" ? 25 : 0, `${v.you!.name} (${v.you!.role})`);
    if (v.you!.role === "guess") assert.ok(!ws.raw.some((m) => /"kind":"(hraun|jokull|neutral|ghost)"/.test(m)), "no key in anything sent to a guesser");
  }
});

test("a big screen sees the board but never the key", async () => {
  const r = await fourPlayers();
  const tv = r.connect();
  await r.say(tv, { t: "hello", screen: true });
  await r.say(r.devices[0]!, { t: "start" });
  assert.equal(tv.view.screen, true);
  assert.equal(tv.view.you, null);
  assert.equal(tv.view.game!.cards.filter((c) => c.kind !== null).length, 0);
  assert.equal(tv.view.players.length, 4, "a screen is not a player");
});

test("a player who drops and comes back gets the same seat and the game as it is", async () => {
  const r = await fourPlayers();
  await r.say(r.devices[0]!, { t: "start" });
  const bjarni = r.devices[1]!;
  const seat = bjarni.last("seat")!;
  const id = bjarni.view.you!.id;
  r.drop(bjarni);
  const other = r.devices[2]!.view.players.find((p) => p.id === id)!;
  assert.equal(other.online, false, "the others see Bjarni as away");
  const again = r.connect();
  await r.say(again, { t: "hello", seat: { id: seat.id, token: seat.token } });
  assert.equal(again.view.you!.id, id);
  assert.equal(again.view.game!.number, 1);
  assert.equal(r.devices[2]!.view.players.find((p) => p.id === id)!.online, true);
});

test("a wrong token is turned away; an away seat can be taken over from another device", async () => {
  const r = await fourPlayers();
  const bjarni = r.devices[1]!;
  const id = bjarni.view.you!.id;
  const stranger = r.connect();
  await r.say(stranger, { t: "hello", seat: { id, token: "wrong" } });
  assert.equal(stranger.last("unseated")?.t, "unseated");
  assert.equal(stranger.view.you, null);
  await r.say(stranger, { t: "claim", id });
  assert.equal(stranger.last("error")?.code, "seatTaken", "Bjarni is still connected");
  r.drop(bjarni);
  await r.say(stranger, { t: "claim", id });
  assert.equal(stranger.view.you!.id, id);
  const oldToken = bjarni.last("seat")!.token;
  const old = r.connect();
  await r.say(old, { t: "hello", seat: { id, token: oldToken } });
  assert.equal(old.view.you, null, "the old device's token no longer works");
});

test("a game played through the sockets, with the timer alarm", async () => {
  const r = await fourPlayers();
  const host = r.devices[0]!;
  await r.say(host, { t: "timer", seconds: 90 });
  await r.say(host, { t: "start" });
  const g = host.view.game!;
  assert.equal(r.saved.alarm, g.deadline);
  const byRole = (team: string, role: string) => r.devices.find((d) => d.view.you!.team === team && d.view.you!.role === role)!;
  const cg = byRole(g.turn, "clue");
  await r.say(cg, { t: "clue", word: "Eldur", number: 1 });
  assert.equal(host.view.game!.clue!.word, "Eldur");
  const gs = byRole(g.turn, "guess");
  await r.say(gs, { t: "guess", index: 99 });
  assert.equal(gs.last("error")?.code, "bad");
  r.advance(90_000);
  await r.core.alarm();
  assert.notEqual(host.view.game!.turn, g.turn, "the timer passed the turn");
  assert.equal(host.view.game!.event?.type, "timeout");
});

test("errors go only to the device that caused them", async () => {
  const r = await fourPlayers();
  await r.say(r.devices[1]!, { t: "start" });
  assert.equal(r.devices[1]!.last("error")?.code, "notHost");
  assert.equal(r.devices[2]!.last("error"), undefined);
  await r.say(r.devices[1]!, "not json" as unknown as object);
  await r.core.message(r.devices[1]!, "{oops");
  assert.equal(r.devices[1]!.last("error")?.code, "bad");
});

test("leaving and being removed send the device back to the join screen", async () => {
  const r = await fourPlayers();
  const d = r.devices[3]!;
  await r.say(d, { t: "leave" });
  assert.equal(d.last("unseated")?.t, "unseated");
  assert.equal(r.devices[0]!.view.players.length, 3);
  await r.say(d, { t: "guess", index: 0 });
  assert.equal(d.last("unseated")?.t, "unseated");
});

test("an idle room is deleted after a few days, but not while anyone is connected", async () => {
  const r = await fourPlayers();
  r.advance(IDLE_MS + 1);
  await r.core.alarm();
  assert.ok(r.core.room, "devices are still connected");
  for (const d of [...r.devices]) r.drop(d);
  await r.core.alarm();
  assert.equal(r.core.room, null);
  assert.equal(r.saved.room, null);
});
