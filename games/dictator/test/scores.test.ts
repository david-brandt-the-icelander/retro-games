// The high-score server: a reign is scored only by replaying it from its seed and keys.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame } from "../src/engine";
import { entryName, replay } from "../worker/scores";
import { cleanName, nameChar, nameFromEmail, validName } from "../src/names";
import { DEL, ENTER, KEYS, keyAt, keyFor, NAME_COL, NAME_ROW, NameEntry, SKIP } from "../src/ui/entry";
import { WIDTH, ZXScreen } from "../src/zx/screen";
import { NAME_LENGTH } from "../src/names";
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

test("a name is up to 12 capitals, digits, dots, hyphens and spaces", () => {
  for (const ok of ["A", "ORTIGA", "ORTIGA-12.WW", "DON P", "123456789012"]) assert.ok(validName(ok), ok);
  for (const bad of ["", "ortiga", " A", "A ", "1234567890123", "<B>", "Ä", 7, null, undefined]) assert.ok(!validName(bad), String(bad));
  assert.equal(cleanName("  ortiga <the> 2nd!  "), "ORTIGA THE 2");
  assert.equal(cleanName("averyveryverylongname"), "AVERYVERYVER");
  assert.equal(cleanName("abcdefghijk lmn"), "ABCDEFGHIJK", "no space left at the end after cutting");
  assert.equal(nameChar("m"), "M");
  assert.equal(nameChar("."), ".");
  assert.equal(nameChar("_"), null);
  assert.equal(nameChar("Enter"), null);
});

test("a signed-in player's default name is the part of their email before the @", () => {
  assert.equal(nameFromEmail("david.brandt"), "DAVID.BRANDT");
  assert.equal(nameFromEmail("first_last+games"), "FIRST-LAST");
  assert.equal(nameFromEmail("averyveryverylongname"), "AVERYVERYVER");
  assert.equal(nameFromEmail("x@example.com"), "X");
  assert.equal(nameFromEmail("!!!"), "");
});

test("the server takes a typed name, or the part before the @ from an older page", () => {
  assert.equal(entryName({ name: "ORTIGA" }), "ORTIGA");
  assert.equal(entryName({ name: "ortiga" }), null, "names arrive as stored");
  assert.equal(entryName({ name: "", email: "a@b.co" }), null, "a name, when sent, must be valid");
  assert.equal(entryName({ email: "david_b@example.com" }), "DAVID-B");
  assert.equal(entryName({ email: "!!!@x.io" }), "ANONYMOUS");
  assert.equal(entryName({ email: "not an email" }), null);
  assert.equal(entryName({}), null);
});

test("the on-screen keyboard: every name character has a key, and keys don't overlap", () => {
  const chars = new Set(KEYS.map((k) => k.key));
  for (const ch of "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- ") assert.ok(chars.has(ch), ch);
  for (const k of [DEL, SKIP, ENTER]) assert.ok(chars.has(k), k);
  for (const k of KEYS) {
    assert.ok(k.col >= 0 && k.col + k.width <= 32, k.label);
    assert.equal(keyAt(k.col * 8 + 4 * k.width, k.row * 8 + 4), k.key, `the middle of ${k.label}`);
    for (const o of KEYS) if (o !== k && o.row === k.row) assert.ok(o.col + o.width <= k.col || k.col + k.width <= o.col, `${k.label}/${o.label}`);
  }
  assert.equal(keyAt(0, 0), null, "the letterhead is no key");
  assert.equal(keyFor("q")?.key, "Q", "typed letters light their key");
  assert.equal(keyFor("Delete")?.key, DEL);
  assert.equal(NAME_COL + 2 * (NAME_LENGTH - 1) < 32, true, "twelve slots fit");
});

test("name entry: letters over their underlines, the cursor under the next free slot, keys keep their frames", () => {
  const z = new ZXScreen();
  const e = new NameEntry(z).draw(42, "ORT");
  const row = (r: number) => z.chars.slice(r * 32, r * 32 + 32).join("");
  assert.equal(row(NAME_ROW).trim(), "O R T");
  assert.equal(e.cursorSlot, 3);
  const frameTop = (KEYS[0].row * 8 - 3) * WIDTH + KEYS[0].col * 8 + 4;
  assert.equal(z.pixels[frameTop], 1, "the first key's frame");
  e.name("ORTIGA-12.WW");
  assert.equal(e.cursorSlot, 11, "a full name keeps the cursor on the last slot");
  assert.equal(z.pixels[frameTop], 1, "redrawing the name leaves the keys' frames alone");
  const underline = (slot: number) => z.pixels[(NAME_ROW + 1) * 8 * WIDTH + (NAME_COL + 2 * slot) * 8 + 3];
  for (let i = 0; i < 12; i++) assert.equal(underline(i), 1, `slot ${i} underlined`);
  assert.equal(z.clipped, 0);
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
