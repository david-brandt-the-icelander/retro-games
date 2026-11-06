// The high-score server: a reign is scored only by replaying it from its seed and keys.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame } from "../src/engine";
import { cleanName, replay } from "../worker/scores";
import { hasGlyph } from "../src/zx/font";
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

test("a name is cleaned to what the game's font can draw, up to 12 characters", () => {
  assert.equal(cleanName("Davíð Brandt"), "David Brandt");
  assert.equal(cleanName("Þórður"), "Thordur");
  assert.equal(cleanName("  Ortiga   the  Great  "), "Ortiga the G");
  assert.equal(cleanName("Mæja <b>"), "Maeja b");
  assert.equal(cleanName("O'Neil-Smith_2"), "O'Neil-Smith");
  for (const empty of ["", "   ", "!!!", "@@@", "...", 42, undefined]) assert.equal(cleanName(empty), "", String(empty));
  for (const raw of ["Davíð", "Ærnöld Þrándur", "x".repeat(300), "a\u0000b\n<c>&d"]) {
    const name = cleanName(raw);
    assert.ok(name.length <= 12, raw);
    for (const ch of name) assert.ok(ch === " " || hasGlyph(ch), `${raw}: no glyph for ${ch}`);
  }
});

test("the high-score web page lists the reigns, escapes names, and carries the site's footer", async () => {
  const { scoresPage } = await import("../worker/scores-page");
  const html = await scoresPage([{ name: "ortiga", score: 120, months: 30, alive: true }, { name: "<b>x</b>", score: 7, months: 2, alive: false }]).text();
  assert.match(html, /<td>1<\/td><td>ortiga<\/td><td class="num">120<\/td><td class="num">30<\/td><td>Fled<\/td>/);
  assert.match(html, /&lt;b&gt;x&lt;\/b&gt;/);
  assert.doesNotMatch(html, /<b>x<\/b>/);
  assert.match(html, /<a href="\/trains">Trains of thought<\/a> · <a href="\/games\/">Games<\/a> · <a href="\/">About and contact<\/a> · <a href="\/feed.xml">Feed of everything<\/a>/);
  assert.match(await scoresPage([]).text(), /No reign recorded yet/);
});
