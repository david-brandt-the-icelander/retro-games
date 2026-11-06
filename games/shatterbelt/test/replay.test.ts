// The public table depends on replays: a recording must play back to exactly the same game,
// and the engine's maths must not depend on the JavaScript engine it runs in.
import assert from "node:assert/strict";
import { test } from "node:test";
import { atan2, cos, hypot, sin } from "../src/engine/dmath";
import { IDLE, delta, newGame, step, type Controls, type Game } from "../src/engine/game";
import { H, W } from "../src/engine/config";
import { MAX_STEPS, Recorder, fromBits, replay, toBits, validRecording, type Recording } from "../src/engine/replay";
import { rand } from "../src/engine/rng";
import { cleanName, score, validSubmission } from "../worker/scores";

test("the deterministic sin, cos and atan2 agree with Math to 1e-12 over many turns", () => {
  const r = { rng: 5 };
  for (let i = 0; i < 20000; i++) {
    const x = (rand(r) - 0.5) * 400;
    assert.ok(Math.abs(sin(x) - Math.sin(x)) < 1e-12, `sin(${x})`);
    assert.ok(Math.abs(cos(x) - Math.cos(x)) < 1e-12, `cos(${x})`);
    const y = (rand(r) - 0.5) * 2000;
    const z = (rand(r) - 0.5) * 2000;
    assert.ok(Math.abs(atan2(y, z) - Math.atan2(y, z)) < 1e-12, `atan2(${y}, ${z})`);
  }
  for (const [y, x] of [[0, 1], [1, 0], [0, -1], [-1, 0], [0, 0], [1, 1], [-1, -1], [1e-9, -1]]) {
    assert.ok(Math.abs(atan2(y, x) - Math.atan2(y, x)) < 1e-12, `atan2(${y}, ${x})`);
  }
  assert.equal(hypot(3, 4), 5);
});

test("controls round-trip through their bits", () => {
  for (let b = 0; b < 32; b++) assert.equal(toBits(fromBits(b)), b);
  assert.equal(toBits(IDLE), 0);
});

/** Plays a whole game with seeded random controls, recording it as the browser does. */
function play(mode: "coop" | "versus", players: number, seed: number): { game: Game; rec: Recording } {
  const g = newGame(mode, players, seed);
  const recorder = new Recorder(players);
  const r = { rng: seed ^ 0x5eed };
  let held: Controls[] = Array.from({ length: players }, () => IDLE);
  while (!g.over && recorder.steps < MAX_STEPS) {
    held = held.map((c, p) => {
      if (rand(r) > 0.08) return c;
      // Aim roughly at the nearest rock half the time, so games last a while.
      const s = g.ships[p];
      const target = g.rocks[0];
      if (target && s.alive && rand(r) < 0.5) {
        const a = Math.atan2(delta(target.y, s.y, H), delta(target.x, s.x, W));
        const d = Math.atan2(Math.sin(a - s.angle), Math.cos(a - s.angle));
        return { left: d < -0.1, right: d > 0.1, thrust: false, fire: rand(r) < 0.7, blink: false };
      }
      return { left: rand(r) < 0.3, right: rand(r) < 0.3, thrust: rand(r) < 0.3, fire: rand(r) < 0.5, blink: rand(r) < 0.05 };
    });
    recorder.record(held);
    step(g, held);
  }
  return { game: g, rec: { mode, players, seed, steps: recorder.steps, log: recorder.log } };
}

test("a recorded game replays to exactly the same scores, for 1 to 9 players in both modes", () => {
  for (const players of [1, 2, 3, 5, 9]) {
    for (const mode of ["coop", "versus"] as const) {
      const { game, rec } = play(mode, players, 1000 + players);
      assert.ok(game.over);
      const again = replay(rec);
      assert.ok(again, `${players} ${mode}: replay accepted`);
      assert.deepEqual(again.ships.map((s) => s.score), game.ships.map((s) => s.score));
      assert.equal(again.wave, game.wave);
      assert.equal(again.rng, game.rng);
    }
  }
});

test("a replay rejects recordings that don't play exactly one whole game", () => {
  const { rec } = play("coop", 2, 77);
  assert.equal(replay({ ...rec, steps: rec.steps - 1 }), null, "stops before the end");
  assert.equal(replay({ ...rec, steps: rec.steps + 1 }), null, "runs past the end");
  assert.equal(validRecording({ ...rec, players: 10 }), false);
  assert.equal(validRecording({ ...rec, log: [0, 5, 1] }), false, "a player who isn't playing");
  assert.equal(validRecording({ ...rec, log: [0, 0, 32] }), false, "bits out of range");
  assert.equal(validRecording({ ...rec, log: [0, 0] }), false, "a broken triple");
  assert.equal(validRecording({ ...rec, mode: "attract" }), false);
});

test("a recording made with another seed doesn't replay as this one", () => {
  const { rec } = play("coop", 1, 31);
  const other = replay({ ...rec, seed: 32 });
  if (other) assert.notDeepEqual(other.ships.map((s) => s.score), replay(rec)!.ships.map((s) => s.score));
});

test("the server's helpers: initials, submissions, and scores from the issued seed", () => {
  assert.equal(cleanName("abc"), "ABC");
  assert.equal(cleanName("A "), "A");
  assert.equal(cleanName("   "), null);
  assert.equal(cleanName("ABCD"), null);
  assert.equal(cleanName("A<b"), null);
  assert.equal(cleanName(7), null);
  const { game, rec } = play("versus", 3, 4242);
  const sub = { id: "x", recording: { mode: rec.mode, players: rec.players, steps: rec.steps, log: rec.log }, names: ["ABC", null, "Z"] };
  assert.ok(validSubmission(sub));
  assert.equal(validSubmission({ ...sub, names: ["ABC"] }), false, "one name per player");
  assert.equal(validSubmission({ ...sub, names: ["ABCD", null, null] }), false);
  const results = score(rec.seed, sub)!;
  assert.deepEqual(results.map((r) => r.score), game.ships.map((s) => s.score));
  assert.ok(results.every((r) => r.wave === game.wave));
  assert.equal(score(rec.seed, { ...sub, recording: { ...sub.recording, steps: rec.steps + 5 } }), null);
});

test("replaying a long game is quick enough for the server", () => {
  const { rec } = play("coop", 4, 9);
  const t0 = performance.now();
  replay(rec);
  const ms = performance.now() - t0;
  const perMinute = ms / (rec.steps / 3600);
  assert.ok(perMinute < 200, `replay took ${perMinute.toFixed(1)} ms per minute of play`);
});
