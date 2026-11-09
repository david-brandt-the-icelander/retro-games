import { test } from "node:test";
import assert from "node:assert/strict";
import { cleanName, nameFromEmail } from "../src/name";
import { actionFor, edit, keyId, ROWS, DEL, ENTER, SKIP } from "../src/ui/entry";
import { parseSubmission } from "../worker/scores";
import { scoresPage } from "../worker/scores-page";

test("names: cleaned to plain letters, digits, spaces and . - ' _; a signed-in player's default from their email", () => {
  assert.equal(cleanName("Davíð Brandt"), "David Brandt");
  assert.equal(cleanName("  pat <the> 2nd!  "), "pat the 2nd");
  assert.equal(cleanName("!!!"), "");
  assert.equal(nameFromEmail("first_last+games"), "FIRST-LAST");
  assert.equal(nameFromEmail("þórður"), "THORDUR");
  assert.equal(nameFromEmail("averyveryverylongname"), "AVERYVERYVER");
});

test("name entry: typed keys, delete, enter and skip; never more than 12", () => {
  assert.deepEqual(actionFor("m"), { kind: "type", ch: "M" }, "M is a letter here, not the sound key");
  assert.deepEqual(actionFor(" "), { kind: "type", ch: " " });
  assert.deepEqual(actionFor("Backspace"), { kind: "delete" });
  assert.deepEqual(actionFor("Delete"), { kind: "delete" });
  assert.deepEqual(actionFor("Enter"), { kind: "enter" });
  assert.deepEqual(actionFor("Escape"), { kind: "skip" });
  assert.deepEqual(actionFor("_"), { kind: "none" });
  assert.deepEqual(actionFor("ArrowUp"), { kind: "none" });
  let name = "";
  for (const k of "abcdefghijklmnop") name = edit(name, actionFor(k));
  assert.equal(name, "ABCDEFGHIJKL");
  assert.equal(edit(name, actionFor("Backspace")), "ABCDEFGHIJK");
  assert.equal(edit("", actionFor("Backspace")), "");
});

test("the on-screen keyboard has a key for every name character, and typed keys light theirs", () => {
  const keys = new Set(ROWS.flat().map(([k]) => k));
  for (const ch of "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- ") assert.ok(keys.has(ch), JSON.stringify(ch));
  for (const k of [DEL, SKIP, ENTER]) assert.ok(keys.has(k), k);
  assert.equal(keyId("q"), "Q");
  assert.equal(keyId("Delete"), DEL);
  assert.ok(keys.has(keyId("Backspace")));
});

test("the server checks a submission's shape before replaying it", () => {
  const good = { id: "abc", name: "PAT", level: "hard", recording: { ticks: 1, moves: [] } };
  assert.deepEqual(parseSubmission(good), good);
  assert.deepEqual(parseSubmission({ ...good, name: " Davíð " }), { ...good, name: "David" }, "names are cleaned, as Samosa's are");
  assert.equal(parseSubmission({ ...good, name: "!!!" }), "bad name");
  assert.equal(parseSubmission({ ...good, name: 42 }), "bad name");
  assert.equal(parseSubmission({ ...good, level: "impossible" }), "bad level");
  assert.equal(parseSubmission({ ...good, level: "toString" }), "bad level");
  assert.equal(parseSubmission({ ...good, id: "x".repeat(65) }), "bad game id");
  assert.equal(parseSubmission(null), "bad request");
});

test("the high-score web page lists matches, escapes names, and carries the site's footer", async () => {
  const html = await scoresPage([{ name: "PAT", score: 3800, level: "normal", mine: 11, theirs: 7, won: true }, { name: "<b>x</b>", score: 100, level: "easy", mine: 1, theirs: 11, won: false }]).text();
  assert.match(html, /<td>1<\/td><td>PAT<\/td><td class="num">3800<\/td><td>Normal<\/td><td>Won 11–7<\/td>/);
  assert.match(html, /&lt;b&gt;x&lt;\/b&gt;/);
  assert.doesNotMatch(html, /<b>x<\/b>/);
  assert.match(html, /<a href="https:\/\/icelander\.net\/trains">Trains of thought<\/a> · <a href="\/games\/">Games<\/a>[^\n]*<a href="\/privacy">Privacy<\/a> · <a href="\/terms">Terms<\/a>/);
  assert.match(await scoresPage([]).text(), /No match recorded yet/);
});
