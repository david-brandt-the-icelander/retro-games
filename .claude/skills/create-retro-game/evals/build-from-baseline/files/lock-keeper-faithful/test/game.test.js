import { test } from "node:test";
import assert from "node:assert/strict";
import { newGame, playGame, snapshot, decide, rainfall, verdict } from "../src/game.js";

const scripted = (keys) => {
  const log = [];
  return { log, show: async (screen) => { log.push(screen); return keys(screen, log.length); } };
};

test("title shows the original credit", async () => {
  const io = scripted(() => "o");
  await playGame(io, newGame(1));
  assert.equal(io.log[0].lines[3], "(C) 1984 INVENTASOFT LIMITED");
});

test("letting the coal barge through", () => {
  const s = newGame(1);
  decide(s, 1, "o");
  assert.deepEqual([s.water, s.coins, s.goodwill], [3, 56, 3]);
});

test("keeping shut costs one goodwill", () => {
  const s = newGame(1);
  decide(s, 3, "k");
  assert.deepEqual([s.water, s.coins, s.goodwill], [5, 50, 2]);
});

test("water is capped at 9 after rain", () => {
  const s = newGame(1);
  s.water = 9;
  rainfall(s);
  assert.equal(s.water, 9);
});

test("running dry is checked before going broke", () => {
  const s = newGame(1);
  s.water = 0;
  s.coins = -1;
  assert.equal(verdict(s), 0);
});

test("retiring after day 20 records 21 as best", async () => {
  const s = newGame(5);
  s.day = 20;
  s.water = 99;
  s.goodwill = 99;
  const best = await playGame(scripted(() => "k"), s, 0);
  assert.equal(best, 21);
});

test("invalid keys re-ask and draw nothing", async () => {
  const s = newGame(3);
  const io = scripted((screen, n) => (screen.kind === "day" && n < 6 ? "O" : "o"));
  await playGame(io, s);
  const first = io.log.filter((x) => x.kind === "day").slice(0, 5);
  assert.ok(first.every((x) => x.boat === first[0].boat));
});

test("same seed, same game; every game ends", async () => {
  for (let seed = 1; seed <= 200; seed++) {
    for (const k of ["o", "k", "i", "?"]) {
      const run = async () => {
        const io = scripted((screen, n) => (k === "?" ? (n % 3 ? "x" : "o") : k === "i" ? (n === 1 ? "i" : "o") : k));
        const s = newGame(seed);
        await playGame(io, s, 0);
        return JSON.stringify([io.log, snapshot(s)]);
      };
      const a = await run();
      assert.equal(a, await run());
      assert.equal(JSON.parse(a)[0].at(-1).kind, "ending");
    }
  }
});
