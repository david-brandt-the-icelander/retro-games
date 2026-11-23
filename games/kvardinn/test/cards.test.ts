// data/kvardar.txt: every line reads as a card, there are enough of them, none repeats, and the
// Icelandic letters survive the trip through the bundler.
import assert from "node:assert/strict";
import { test } from "node:test";
import cardsText from "../data/kvardar.txt";
import { parseCards } from "../src/engine/cards";
import { MAX_END } from "../src/engine/game";

test("every line of data/kvardar.txt is a card", () => {
  const { cards, problems } = parseCards(cardsText);
  assert.deepEqual(problems, [], `lines that aren't "Vinstri ↔ Hægri": ${JSON.stringify(problems)}`);
  assert.ok(cards.length >= 140, `only ${cards.length} cards`);
});

test("no card repeats, and no end is too long for a phone", () => {
  const { cards } = parseCards(cardsText);
  const seen = new Set<string>();
  for (const [l, r] of cards) {
    const key = `${l.toLowerCase()}|${r.toLowerCase()}`;
    assert.ok(!seen.has(key), `repeated: ${l} ↔ ${r}`);
    seen.add(key);
    assert.notEqual(l.toLowerCase(), r.toLowerCase());
    assert.ok(l.length <= MAX_END && r.length <= MAX_END, `too long: ${l} ↔ ${r}`);
  }
});

test("Icelandic letters arrive intact", () => {
  const all = parseCards(cardsText).cards.flat().join(" ");
  for (const ch of ["þ", "ð", "æ", "ö", "á", "é", "í", "ó", "ú", "ý", "Í", "Ó", "Ö", "Ú", "Æ"]) assert.ok(all.includes(ch), `no ${ch}`);
});

test("the parser takes ↔, <-> and |, and skips comments", () => {
  const { cards, problems } = parseCards("# athugasemd\n\nKalt ↔ Heitt\nLítið <-> Stórt\n Sveit | Borg \nBara eitt\n");
  assert.deepEqual(cards, [["Kalt", "Heitt"], ["Lítið", "Stórt"], ["Sveit", "Borg"]]);
  assert.equal(problems.length, 1);
});
