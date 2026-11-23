import assert from "node:assert/strict";
import { test } from "node:test";
import WORDS_TEXT from "../data/ord.txt";
import { key, parseWords, pickWords, plain, similar } from "../src/shared/words";
import { seeded } from "./helpers";

const words = parseWords(WORDS_TEXT);

test("the built-in list has about 400 words, each one word, none repeated", () => {
  assert.ok(words.length >= 380 && words.length <= 450, `${words.length} words`);
  const lines = WORDS_TEXT.split("\n").map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
  assert.equal(lines.length, words.length, "every line in data/ord.txt is a word the game uses (no repeats, no spaces)");
  for (const w of words) assert.match(plain(w), /^[\p{Lu}][\p{Ll}]+$/u, w);
});

test("long words say where they may be split, so they stay readable on a small phone", () => {
  for (const w of words) {
    if (plain(w).length >= 9) assert.ok(w.includes("|"), `${w}: add a | where it can be split`);
    for (const part of w.split("|")) assert.ok(part.length <= 9, `${w}: each part at most 9 letters`);
  }
});

test("no built-in word names a team or the game-over word", () => {
  for (const w of words) for (const r of ["hraun", "jökul", "draug"]) assert.ok(!key(w).includes(r), w);
});

test("Icelandic letters survive parsing", () => {
  const list = parseWords("þorri\nÐ\nÆðarfugl, Ölfus; Ísafjörður\n# athugasemd\n\nTvö orð\nþorri");
  assert.deepEqual(list, ["Þorri", "Ð", "Æðarfugl", "Ölfus", "Ísafjörður"]);
});

test("look-alike words are kept apart", () => {
  assert.ok(similar("Sund", "Sund|laug"));
  assert.ok(similar("Jólatré", "Jóla|sveinn"));
  assert.ok(similar("Harð|fiskur", "Plokk|fiskur"));
  assert.ok(similar("Ís", "Hafís"));
  assert.ok(!similar("Hekla", "Katla"));
  assert.ok(!similar("Lundi", "Kría"));
});

test("every deal from the built-in list has 25 different, unalike words", () => {
  for (let seed = 1; seed <= 300; seed++) {
    const board = pickWords(words, 25, seeded(seed));
    assert.ok(board, `seed ${seed}`);
    for (let i = 0; i < board.length; i++) for (let j = i + 1; j < board.length; j++) assert.ok(!similar(board[i]!, board[j]!), `${board[i]} / ${board[j]}`);
  }
});

test("a list too short or too alike cannot be dealt", () => {
  assert.equal(pickWords(["A", "B"], 25, seeded(1)), null);
  const alike = Array.from({ length: 30 }, (_, i) => `Sund${"abcdefghijklmnopqrstuvwxyzþæö"[i]}`);
  assert.equal(pickWords(alike, 25, seeded(1)), null);
});
