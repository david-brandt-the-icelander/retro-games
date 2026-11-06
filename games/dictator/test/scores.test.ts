// The high-score server: a reign is scored only by replaying it from its seed and keys.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame } from "../src/engine";
import { publicName, replay, validEmail } from "../worker/scores";
import { looksLikeEmail } from "../src/scores";
import { rotating } from "./helpers";

async function playRecorded(seed: number) {
  const keys: string[] = [];
  const next = rotating(["y", "1", "n", "3", "Y", "2", "Enter", "4", "5", "6", "q"], seed);
  const state = newGame(seed);
  const outcome = await playGame({ show: async (s) => { const k = next(s, 0); keys.push(k); return k; } }, state, null);
  return { keys, score: outcome.score, months: state.month, alive: state.alive };
}

test("a replay from the seed and the keys gives the same score", async () => {
  for (let seed = 1; seed <= 200; seed++) {
    const game = await playRecorded(seed);
    assert.deepEqual(await replay(seed, game.keys), { score: game.score, months: game.months, alive: game.alive }, `seed ${seed}`);
  }
});

test("a replay is refused when the keys don't play exactly one whole reign", async () => {
  const game = await playRecorded(7);
  assert.equal(await replay(7, game.keys.slice(0, -1)), null, "too few keys");
  assert.equal(await replay(7, [...game.keys, " "]), null, "keys left over");
  const other = await replay(8, game.keys);
  assert.ok(other === null || other.score !== undefined, "another seed either fails or scores its own game");
});

test("only the part before the @ is made public, in characters the font can draw", () => {
  assert.equal(publicName("david.brandt@example.com"), "david.brandt");
  assert.equal(publicName("a<b>\"c@x.io"), "abc");
  assert.equal(publicName("averyveryverylongname@x.io"), "averyveryver");
  assert.equal(publicName("!!!@x.io"), "anonymous");
});

test("emails are checked the same way in the browser and on the server", () => {
  for (const [s, ok] of [["a@b.co", true], ["first.last+tag@sub.example.org", true], ["no-at-sign", false], ["a@b", false], ["a b@c.de", false], ["@c.de", false], [`${"x".repeat(65)}@c.de`, false]] as const) {
    assert.equal(validEmail(s), ok, s);
    assert.equal(looksLikeEmail(s), ok, s);
  }
});
