// The generator (RULES §15.4) and the parity hook.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame, snapshot } from "../src/engine";
import { draw, pick } from "../src/engine/state";
import { drawsBetween } from "./helpers";

/** RULES §15.4's generator, written out again from the text. */
function reference(seed: number) {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return { u: ((t ^ (t >>> 14)) >>> 0) / 2 ** 32, state };
  };
}

test("the generator follows RULES §15.4 exactly, and its state is the seed plus a constant per draw", () => {
  for (const seed of [0, 1, 42, 0xffffffff, 123456789]) {
    const s = newGame(seed), ref = reference(seed);
    for (let i = 0; i < 1000; i++) {
      const r = ref();
      assert.equal(draw(s), r.u);
      assert.equal(s.rng, r.state);
    }
    assert.equal(drawsBetween(seed, s.rng), 1000);
  }
});

test("pick(n) is floor(u × n), uniform over 0…n−1", () => {
  const s = newGame(77), ref = reference(77);
  const counts = Array(24).fill(0);
  for (let i = 0; i < 48000; i++) {
    const v = pick(s, 24);
    assert.equal(v, Math.floor(ref().u * 24));
    counts[v]++;
  }
  for (const c of counts) assert.ok(Math.abs(c / 48000 - 1 / 24) < 0.006);
});

test("nothing draws but the rules: advice, dialogs, reports, the Swiss account and plots do not", async () => {
  // Between two screens with nothing random between them, the generator stands still.
  const s = newGame(5);
  s.popularity = [9, 9, 9, 0, 9, 9, 9, 9];
  const log: Array<{ kind: string; rng: number }> = [];
  let menus = 0;
  await playGame({
    show: async (sc) => {
      log.push({ kind: sc.kind, rng: s.rng });
      if (sc.kind === "menu" && ++menus === 1) return "3";
      if (sc.kind === "section") return "4";
      if (sc.kind === "helpList") return "2";
      return ["adviceOffer", "reportOffer"].includes(sc.kind) ? "y" : "n";
    },
  }, s, null);
  const still = [["adviceOffer", "advice"], ["advice", "dialog"], ["dialog", "treasury"], ["reportOffer", "report"], ["section", "swiss"], ["swiss", "reportOffer"], ["welcome", "treasury"], ["treasury", "report"]];
  for (const [a, b] of still) {
    const i = log.findIndex((x, j) => x.kind === a && log[j + 1]?.kind === b);
    assert.ok(i >= 0, `${a} → ${b} not seen`);
    assert.equal(log[i + 1].rng, log[i].rng, `${a} → ${b}`);
  }
});

test("snapshot has exactly the parity shape, in RULES' terms", () => {
  const s = newGame(9);
  const snap = snapshot(s);
  assert.deepEqual(Object.keys(snap).sort(), [
    "alive", "ally", "costs", "decisionUsed", "escaped", "helicopter", "loanEast", "loanWest", "month", "newsUsed", "plotPause",
    "pop", "presidentStrength", "requestUsed", "revolutionStrength", "rng", "status", "str", "swiss", "threshold", "treasury",
  ]);
  assert.deepEqual(snap.pop, [7, 7, 7, 0, 7, 7, 7, 7]);
  assert.deepEqual(snap.str, [6, 6, 6, 6, 6, 6]);
  assert.deepEqual(snap.status, ["none", "none", "none"]);
  assert.deepEqual(snap.ally, [-1, -1, -1]);
  assert.equal(snap.presidentStrength, 4);
  assert.equal(snap.rng, 9);
  assert.equal(snap.requestUsed.length, 24);
  assert.equal(snap.decisionUsed.length, 19);
  assert.equal(snap.newsUsed.length, 6);
  assert.ok(snap.alive && !snap.escaped);
  // a copy: changing the state later does not change it
  s.popularity[0] = 1;
  assert.equal(snap.pop[0], 7);
});
