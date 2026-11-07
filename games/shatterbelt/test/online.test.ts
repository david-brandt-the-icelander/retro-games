// Online play: the browsers' lockstep (src/online.ts), between fake browsers with random delays.
// The relay itself is the games hub's (the recreations repository, worker/match.ts), tested there.
// The same file is in Rally, Shatterbelt and Hivestorm.
import assert from "node:assert/strict";
import { test } from "node:test";
import { Lockstep, delaySteps, fingerprint, type Room as ClientRoom, type RoomListener, type RoomMessage } from "../src/online";

// ——— Lockstep between fake browsers ———

/** A fake room for browsers: a hub that delivers each message after a random delay, in order per sender. */
class Hub {
  members = new Map<number, FakeRoom>();
  queue: { at: number; to: number; msg: RoomMessage }[] = [];
  now = 0;
  private lastAt = new Map<string, number>();
  constructor(private random: () => number) {}
  post(from: number, msg: RoomMessage, toAll = true): void {
    for (const to of this.members.keys()) {
      if (to === from && toAll) continue;
      const key = `${from}>${to}`;
      // Random latency, but never overtaking an earlier message on the same path.
      const at = Math.max(this.now + 1 + Math.floor(this.random() * 6), this.lastAt.get(key) ?? 0);
      this.lastAt.set(key, at);
      this.queue.push({ at, to, msg: { ...JSON.parse(JSON.stringify(msg)), from } });
    }
  }
  /** Delivers everything due by now. */
  deliver(): void {
    const due = this.queue.filter((q) => q.at <= this.now).sort((a, b) => a.at - b.at);
    this.queue = this.queue.filter((q) => q.at > this.now);
    for (const q of due) this.members.get(q.to)?.receive(q.msg);
  }
  leave(slot: number): void {
    this.members.delete(slot);
    for (const [to, m] of this.members) {
      const at = Math.max(this.now + 1, this.lastAt.get(`${slot}>${to}`) ?? 0);
      this.queue.push({ at, to, msg: { t: "leave", slot } });
      m.peers.delete(slot);
    }
  }
}

class FakeRoom {
  peers: Set<number>;
  private listeners = new Set<RoomListener>();
  constructor(private hub: Hub, readonly you: number, slots: number[]) {
    this.peers = new Set(slots);
    hub.members.set(you, this);
  }
  listen(fn: RoomListener): () => void { this.listeners.add(fn); return () => this.listeners.delete(fn); }
  send(msg: object): void { this.hub.post(this.you, msg as RoomMessage); }
  receive(msg: RoomMessage): void { for (const fn of [...this.listeners]) fn(msg); }
}

/** A tiny deterministic "game": a running total each player's controls feed into. */
const play = (state: number, inputs: (number | null)[]): number =>
  inputs.reduce<number>((s, v, i) => (Math.imul(s, 31) + (v === null ? 7 : v * (i + 3))) | 0, state);

function rng(seed: number): () => number {
  let s = seed >>> 0;
  return () => ((s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 2 ** 32);
}

test("browsers in lockstep play the same steps, whatever the delays", () => {
  for (const seed of [1, 2, 3]) {
    const random = rng(seed);
    const hub = new Hub(random);
    const slots = [0, 1, 2];
    const start = { slots, seed, delay: 4 };
    const browsers = slots.map((s) => {
      const room = new FakeRoom(hub, s, slots);
      return { lock: new Lockstep(room as unknown as ClientRoom, start, 0), state: 0, log: [] as number[], room };
    });
    for (const b of browsers) b.lock.onDesync = () => assert.fail("the games drifted apart");
    // Each browser takes its turn at a slightly different pace, as real ones do.
    for (let tick = 0; tick < 3000; tick++) {
      hub.now = tick;
      hub.deliver();
      for (const b of browsers) {
        if (random() < 0.25) continue; // this browser's frame came late
        b.lock.local(Math.floor(random() * 4));
        if (b.lock.ready()) {
          b.state = play(b.state, b.lock.next());
          b.log.push(b.state);
          b.lock.check(b.state);
        }
        b.lock.flush(tick * 30); // every flush is due
      }
    }
    const n = Math.min(...browsers.map((b) => b.log.length));
    assert.ok(n > 1000, `steps played: ${n}`);
    for (const b of browsers) assert.deepEqual(b.log.slice(0, n), browsers[0].log.slice(0, n));
  }
});

test("a player who leaves plays on as null from the same step for everyone", () => {
  const random = rng(9);
  const hub = new Hub(random);
  const slots = [0, 1, 2];
  const browsers = slots.map((s) => {
    const room = new FakeRoom(hub, s, slots);
    return { lock: new Lockstep(room as unknown as ClientRoom, { slots, seed: 1, delay: 7 }, 0), log: [] as string[], left: [] as number[], gone: false };
  });
  for (const b of browsers) b.lock.onLeave = (i) => b.left.push(i);
  for (let tick = 0; tick < 2000; tick++) {
    hub.now = tick;
    if (tick === 700) { browsers[2].gone = true; browsers[2].lock.stop(); hub.leave(2); }
    hub.deliver();
    for (const b of browsers) {
      if (b.gone || random() < 0.2) continue;
      b.lock.local(1 + Math.floor(random() * 3));
      if (b.lock.ready()) b.log.push(JSON.stringify(b.lock.next()));
      b.lock.flush(tick * 30);
    }
  }
  const [a, b] = browsers;
  const n = Math.min(a.log.length, b.log.length);
  assert.ok(n > 1000, `steps played: ${n}, ${a.log.length}, ${b.log.length}, ${browsers[2].log.length}`);
  assert.deepEqual(a.log.slice(0, n), b.log.slice(0, n));
  assert.ok(a.log.slice(0, n).some((l) => JSON.parse(l)[2] === null), "the leaver became null");
  assert.deepEqual(a.left, [2]);
  assert.deepEqual(b.left, [2]);
});

test("browsers notice when their games drift apart", () => {
  const hub = new Hub(() => 0);
  const slots = [0, 1];
  const locks = slots.map((s) => new Lockstep(new FakeRoom(hub, s, slots) as unknown as ClientRoom, { slots, seed: 1, delay: 2 }, 0));
  let drifted = 0;
  for (const l of locks) l.onDesync = () => drifted++;
  for (let tick = 0; tick < 400; tick++) {
    hub.now = tick;
    hub.deliver();
    locks.forEach((l, i) => {
      l.local(0);
      if (l.ready()) { l.next(); l.check(l.frame < 200 ? 42 : 42 + i); }
      l.flush(tick * 30);
    });
  }
  assert.ok(drifted > 0);
});

test("the delay covers the slowest two players' connections", () => {
  assert.equal(delaySteps([], 1 / 60), Math.ceil(150 / (1000 / 60)));
  assert.equal(delaySteps([10, 10], 1 / 60), 4); // 10 ms, plus 50 ms to spare: 60 ms
  assert.ok(delaySteps([200, 180, 20], 1 / 60) > delaySteps([20, 20, 20], 1 / 60));
  assert.equal(delaySteps([5000, 5000], 1 / 120), 48); // at most 400 ms
  assert.notEqual(fingerprint([0.1, 0.2]), fingerprint([0.2, 0.1]));
  assert.equal(fingerprint([1, 2, 3]), fingerprint([1, 2, 3]));
});
