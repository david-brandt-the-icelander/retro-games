// Seeded bots play many full reigns with different key policies, valid and invalid, and check
// that every reign ends cleanly, the invariants hold at every screen, and every engine kind occurs.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame, SCREEN_KINDS, snapshot } from "../src/engine";
import type { Screen, Snapshot } from "../src/engine";
import { keyStream } from "./helpers";

const POLICIES: Record<string, readonly string[]> = {
  yes: ["y", "Y"],
  no: ["n", "Enter", " "],
  digits: ["1", "2", "3", "4", "5", "6"],
  valid: ["y", "n", "1", "2", "3", "4", "5", "6", "Enter"],
  invalid: ["y", "n", "1", "3", "7", "0", "x", "Escape", "Y", " ", "!", "ArrowUp", "q", "M"],
  cabinet: ["2", "2", "1", "3", "y", "y", "n"],
};

function check(s: Snapshot, prev: Snapshot | null, where: string): void {
  for (const v of [...s.pop, ...s.str]) assert.ok(Number.isInteger(v) && v >= 0 && v <= 9, where);
  assert.equal(s.pop.length, 8); assert.equal(s.str.length, 6);
  assert.ok(s.costs >= 0 && s.presidentStrength >= 0 && s.swiss >= 0, where);
  assert.ok(Number.isInteger(s.treasury) && Number.isInteger(s.swiss), where);
  assert.ok(s.threshold === 0 || (s.threshold >= 2 && s.threshold <= 4), where);
  assert.ok(s.revolutionStrength >= 10 && s.revolutionStrength <= 12, where);
  s.status.forEach((st, f) => {
    assert.equal(st === "revolution", s.ally[f] >= 0, where);
    if (st === "revolution") assert.ok(s.ally[f] !== f && s.ally[f] < 6, where);
  });
  assert.ok(s.rng >= 0 && s.rng < 2 ** 32, where);
  if (prev) {
    assert.ok(s.swiss >= prev.swiss, where);
    assert.ok(s.month >= prev.month, where);
    for (let i = 0; i < 6; i++) assert.ok(!prev.newsUsed[i] || s.newsUsed[i], where);
    if (prev.loanEast) assert.ok(s.loanEast);
    if (prev.helicopter) assert.ok(s.helicopter);
    if (!prev.alive) assert.ok(!s.alive);
  }
}

test("bots play 6,000 full reigns without errors, and every reign ends with the final report", async () => {
  const seen = new Set<string>();
  const endings = new Map<string, number>();
  let screens = 0;
  for (const [name, keys] of Object.entries(POLICIES)) {
    for (let seed = 1; seed <= 1000; seed++) {
      const s = newGame(seed * 7919);
      const next = keyStream(seed, keys);
      const helpKey = keyStream(seed + 99, ["1", "2", "3", "4", "5", "6"]);
      let prev: Snapshot | null = null, last: Screen | null = null, helpRepeats = 0, n = 0;
      const out = await playGame({
        show: async (screen) => {
          assert.ok(SCREEN_KINDS.includes(screen.kind), screen.kind);
          assert.ok(++n < 50000, `${name} ${seed}: no end`);
          const snap = snapshot(s);
          check(snap, prev, `${name} seed ${seed} ${screen.kind}`);
          prev = snap; last = screen; seen.add(screen.kind);
          helpRepeats = screen.kind === "helpList" ? helpRepeats + 1 : 0;
          return helpRepeats > 8 ? helpKey() : next();
        },
      }, s, seed % 3 ? null : 100);
      screens += n;
      const final: Screen = last!;
      assert.ok(final.kind === "report" && final.variant === "final", `${name} ${seed}`);
      assert.equal(s.alive, s.escaped, "a reign ends dead, or alive by escaping");
      assert.ok(out.best >= out.score);
      const ending = s.alive ? "escaped" : "dead";
      endings.set(ending, (endings.get(ending) ?? 0) + 1);
    }
  }
  const missing = SCREEN_KINDS.filter((k) => !seen.has(k));
  assert.deepEqual(missing, [], `never shown: ${missing}`);
  assert.ok((endings.get("escaped") ?? 0) > 0 && (endings.get("dead") ?? 0) > 0);
  assert.ok(screens > 100000);
});
