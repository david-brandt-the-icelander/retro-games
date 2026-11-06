import { test } from "node:test";
import assert from "node:assert/strict";
import { Cpu, LEVELS, type LevelName } from "../src/engine/ai";
import { DT, MAX_TICKS, Recorder, cpuSeed, quantise, replay, scoreOf, type Recording } from "../src/engine/match";
import { H, newMatch, step, type Control } from "../src/engine/rules";

/**
 * Plays a one-player match the way the browser does, with a stand-in player: a computer player
 * steering by key or by pointer (switching now and then), recorded tick by tick.
 */
function play(seed: number, level: LevelName, player: LevelName = "normal") {
  const s = newMatch(seed);
  const cpu = new Cpu(1, LEVELS[level], cpuSeed(seed));
  const me = new Cpu(0, LEVELS[player], seed + 7);
  const rec = new Recorder();
  while (s.phase !== "over" && rec.ticks < MAX_TICKS) {
    const want = me.control(s, DT);
    const byKeys = Math.floor(rec.ticks / 600) % 2 === 0;
    const raw: Control = byKeys
      ? { dir: Math.abs(want.target! - s.paddles[0].y) < 6 ? 0 : want.target! < s.paddles[0].y ? -1 : 1, target: null }
      : { dir: 0, target: want.target! + 0.37 };
    const human = quantise(raw);
    rec.record(human);
    step(s, [human, cpu.control(s, DT)], DT);
  }
  return { s, rec: rec.recording };
}

test("a recorded match replays to the same score", () => {
  for (const [seed, level] of [[1, "easy"], [2, "normal"], [3, "hard"], [4, "normal"]] as const) {
    const { s, rec } = play(seed, level, seed === 1 ? "hard" : "normal");
    assert.equal(s.phase, "over");
    const r = replay(seed, level, rec);
    assert.deepEqual(r, { score: scoreOf(level, s.score, s.winner), mine: s.score[0], theirs: s.score[1], won: s.winner === 0 });
  }
});

test("a replay refuses recordings that don't play exactly one whole match", () => {
  const { rec } = play(5, "normal");
  assert.notEqual(replay(5, "normal", rec), null);
  assert.equal(replay(5, "normal", { ...rec, ticks: rec.ticks - 1 }), null, "stops short of the end");
  assert.equal(replay(5, "normal", { ...rec, ticks: rec.ticks + 1 }), null, "runs on past the end");
  assert.equal(replay(5, "silly" as LevelName, rec), null, "unknown level");
  assert.equal(replay(5, "toString" as LevelName, rec), null, "not a level, though every object has it");
  const bad = (moves: unknown): Recording => ({ ticks: rec.ticks, moves } as Recording);
  for (const moves of [[[0, 2, -1]], [[0, 0, H + 1]], [[0, 1, 50]], [[5, 0, -1], [5, 1, -1]], [[0, 0, 1.5]], "x", [[rec.ticks, 0, -1]]]) {
    assert.equal(replay(5, "normal", bad(moves)), null, JSON.stringify(moves));
  }
  assert.equal(replay(5, "normal", null), null);
  assert.equal(replay(5, "normal", { ticks: MAX_TICKS + 1, moves: [] }), null);
});

test("a recording made against one seed or level scores differently, or not at all, on another", () => {
  const { s, rec } = play(6, "hard");
  const other = replay(7, "hard", rec);
  const easier = replay(6, "easy", rec);
  const mine = scoreOf("hard", s.score, s.winner);
  assert.ok(other === null || other.score !== mine || other.mine !== s.score[0]);
  assert.ok(easier === null || easier.score !== mine);
});

test("scores: 100, 200 or 300 a point by level, and ten points' worth for a win", () => {
  assert.equal(scoreOf("easy", [11, 4], 0), 2100);
  assert.equal(scoreOf("normal", [7, 11], 1), 1400);
  assert.equal(scoreOf("hard", [13, 11], 0), 6900);
  assert.equal(scoreOf("hard", [0, 11], 1), 0);
});

test("recordings stay small: one move per change", () => {
  const { rec } = play(8, "normal");
  assert.ok(rec.moves.length < rec.ticks / 2, `${rec.moves.length} moves in ${rec.ticks} ticks`);
});

test("a long match replays quickly enough for the server", () => {
  const { rec } = play(9, "hard", "hard");
  const t0 = performance.now();
  replay(9, "hard", rec);
  const ms = performance.now() - t0;
  console.log(`# replayed ${rec.ticks} ticks (${(rec.ticks / 120 / 60).toFixed(1)} min) in ${ms.toFixed(1)} ms`);
  assert.ok(ms < 500, `${ms} ms`);
});
