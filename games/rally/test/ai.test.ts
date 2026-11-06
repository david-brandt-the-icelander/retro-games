import { test } from "node:test";
import assert from "node:assert/strict";
import { BALL, H, W, faceX, newMatch, step, type Side, type State } from "../src/engine/rules";
import { Cpu, LEVELS, predictY, type LevelName } from "../src/engine/ai";

const DT = 1 / 120;

/** Plays a whole match between two computer players and returns the final state. */
function match(left: LevelName, right: LevelName, seed: number): { s: State; returns: number } {
  const s = newMatch(seed);
  const a = new Cpu(0, LEVELS[left], seed * 3 + 1);
  const b = new Cpu(1, LEVELS[right], seed * 3 + 2);
  let returns = 0;
  for (let t = 0; t < 60 * 60 && s.phase !== "over"; t += DT) {
    for (const e of step(s, [a.control(s, DT), b.control(s, DT)], DT)) if (e.kind === "paddle") returns++;
  }
  return { s, returns };
}

test("predictY follows the ball through its bounces", () => {
  const s = newMatch(1);
  s.phase = "play";
  Object.assign(s.ball, { x: W / 2, y: H / 2, vx: 300, vy: 0 });
  assert.equal(predictY(s, faceX(1)), H / 2);

  // Climbs 45° from the middle: up to the top, then down.
  Object.assign(s.ball, { x: 100, y: H / 2, vx: 300, vy: -300 });
  const x = 100 + (H / 2 - BALL / 2) + 50;
  assert.ok(Math.abs(predictY(s, x) - (BALL / 2 + 50)) < 1e-6);

  // Checked against the engine itself.
  Object.assign(s.ball, { x: 300, y: 100, vx: 420, vy: 610 });
  s.paddles[1].y = 0;
  const want = predictY(s, 700);
  for (let i = 0; i < 2000 && s.ball.x < 700; i++) step(s, [{ dir: 0, target: null }, { dir: 0, target: null }], 1 / 2000);
  assert.ok(Math.abs(s.ball.y - want) < 2, `${s.ball.y} vs ${want}`);
});

test("computer matches finish with a proper table-tennis score", () => {
  for (let seed = 1; seed <= 5; seed++) {
    const { s, returns } = match("normal", "normal", seed);
    assert.equal(s.phase, "over", `seed ${seed} never finished`);
    const w = s.winner as Side;
    assert.ok(s.score[w] >= 11 && s.score[w] - s.score[1 - w] >= 2);
    assert.ok(returns > 20, `seed ${seed}: only ${returns} returns, so the rallies are too short`);
  }
});

test("the same seed plays the same match", () => {
  assert.deepEqual(match("hard", "easy", 9).s.score, match("hard", "easy", 9).s.score);
});

test("a harder computer beats an easier one", () => {
  let hard = 0;
  for (let seed = 1; seed <= 6; seed++) {
    if (match("hard", "easy", seed).s.winner === 0) hard++;
    if (match("easy", "hard", seed + 100).s.winner === 1) hard++;
  }
  assert.ok(hard >= 10, `hard won only ${hard} of 12`);
});

test("the computer usually returns a gentle ball", () => {
  for (const level of ["easy", "normal", "hard"] as LevelName[]) {
    let hits = 0;
    for (let seed = 1; seed <= 20; seed++) {
      const s = newMatch(seed);
      s.phase = "play";
      Object.assign(s.ball, { x: W / 2, y: 60 + ((seed * 37) % (H - 120)), vx: 360, vy: ((seed % 5) - 2) * 90 });
      s.rally = 1;
      const cpu = new Cpu(1, LEVELS[level], seed);
      for (let t = 0; t < 2 && s.phase === "play" && s.ball.vx > 0; t += DT) step(s, [{ dir: 0, target: null }, cpu.control(s, DT)], DT);
      if (s.ball.vx < 0) hits++;
    }
    assert.ok(hits >= 14, `${level} returned only ${hits} of 20`);
  }
});
