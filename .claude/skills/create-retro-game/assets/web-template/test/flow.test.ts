// EXAMPLE GAME (replace): rule, probability and flow tests, the patterns to follow.
import assert from "node:assert/strict";
import { test } from "node:test";
import { playGame } from "../src/engine/flow";
import type { Screen } from "../src/engine/screens";
import * as rules from "../src/engine/rules";
import { newGame } from "../src/engine/state";

test("a storm burns two cans unless the wick is trimmed", () => {
  const s = newGame(1);
  rules.burnOil(s, true, false);
  assert.equal(s.oil, 4);
  rules.burnOil(s, true, true);
  assert.equal(s.oil, 3);
});

test("storms come one night in three", () => {
  const s = newGame(7);
  let storms = 0;
  for (let i = 0; i < 9000; i++) if (rules.stormTonight(s)) storms++;
  assert.ok(Math.abs(storms / 9000 - 1 / 3) < 0.02);
});

test("the same seed replays the same game", async () => {
  const run = async () => {
    const log: Screen[] = [];
    await playGame({ show: async (s) => { log.push(s); return "n"; } }, newGame(42));
    return JSON.stringify(log);
  };
  assert.equal(await run(), await run());
});

test("every game ends with the ending screen, whatever the keys", async () => {
  for (let seed = 1; seed <= 200; seed++) {
    for (const key of ["y", "n", "enter", "?"]) {
      const log: Screen[] = [];
      await playGame({ show: async (s) => { log.push(s); return key; } }, newGame(seed));
      assert.equal(log[log.length - 1].kind, "ending");
    }
  }
});
