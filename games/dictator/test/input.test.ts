// Input quirks (RULES §15.1): one raw key per prompt; only Y or y is yes; any other key is no or
// next; 1-5 at the menu; a section's numbers; 1-6 at the help list; timed screens ignore keys.
import assert from "node:assert/strict";
import { test } from "node:test";
import { digit, isYes, newGame, playGame } from "../src/engine";
import type { GameState, Screen } from "../src/engine";
import { kinds, patient, recorder } from "./helpers";

test("only Y and y mean yes", () => {
  assert.ok(isYes("y") && isYes("Y"));
  for (const k of ["n", "N", "Enter", " ", "1", "yes", "", "m", "Escape"]) assert.ok(!isYes(k), k);
});

test("digits: only single keys 1…max count", () => {
  assert.equal(digit("1", 5), 1);
  assert.equal(digit("5", 5), 5);
  assert.equal(digit("6", 5), 0);
  assert.equal(digit("0", 5), 0);
  assert.equal(digit("12", 9), 0);
  assert.equal(digit("Enter", 5), 0);
  assert.equal(digit("a", 5), 0);
  assert.equal(digit("6", 6), 6);
});

function calm(seed: number): GameState {
  const s = newGame(seed);
  s.popularity = [9, 9, 9, 0, 9, 9, 9, 9];
  return s;
}

async function firstMonth(answer: (sc: Screen) => string, s = calm(3)) {
  const { io, log } = recorder(s, patient(answer));
  await playGame(io, s, null);
  const end = log.findIndex((x, i) => i > 3 && x.screen.kind === "month");
  return log.slice(0, end);
}

test("Y in either case buys a report; any other key skips it", async () => {
  for (const [key, buys] of [["y", true], ["Y", true], ["n", false], ["Enter", false], [" ", false], ["x", false]] as const) {
    const log = await firstMonth((sc) => (sc.kind === "reportOffer" ? key : "n"));
    const i = log.findIndex((x) => x.screen.kind === "reportOffer");
    assert.equal(log[i + 1].screen.kind === "report", buys, key);
  }
});

test("any key but Y refuses the request; Y grants it", async () => {
  for (const key of ["n", "Enter", " ", "q", "1"]) {
    const log = await firstMonth((sc) => (sc.kind === "dialog" ? key : "n"));
    const aud = log.find((x) => x.screen.kind === "audience")!.screen;
    const t = log.findIndex((x, i) => i > 3 && x.screen.kind === "treasury");
    assert.ok(aud.kind === "audience" && log[t].snap.pop[aud.faction] < 9, key);
  }
  const log = await firstMonth((sc) => (sc.kind === "dialog" ? "Y" : "n"));
  const aud = log.find((x) => x.screen.kind === "audience")!.screen;
  const t = log.findIndex((x, i) => i > 3 && x.screen.kind === "treasury");
  assert.ok(aud.kind === "audience" && log[t].snap.pop[aud.faction] === 9);
});

test("at the menu, any key but 1-5 means no decision this month", async () => {
  for (const key of ["0", "6", "9", "a", "Enter", " ", "y"]) {
    const log = await firstMonth((sc) => (sc.kind === "menu" ? key : "n"));
    const i = log.findIndex((x) => x.screen.kind === "menu");
    assert.equal(log[i + 1].screen.kind, "reportOffer", key);
    assert.equal(log.filter((x) => x.screen.kind === "menu").length, 1);
  }
});

test("in a section, an unlisted or used number goes back to the menu without an error", async () => {
  for (const key of ["4", "0", "Enter", "x"]) {
    let menus = 0;
    const log = await firstMonth((sc) => (sc.kind === "menu" ? (++menus === 1 ? "2" : "n") : sc.kind === "section" ? key : "n"));
    assert.deepEqual(kinds(log).slice(log.findIndex((x) => x.screen.kind === "menu")).slice(0, 4), ["menu", "section", "menu", "reportOffer"], key);
  }
  const used = calm(3);
  used.decisionUsed[0] = true;
  let menus = 0;
  const log = await firstMonth((sc) => (sc.kind === "menu" ? (++menus === 1 ? "1" : "n") : sc.kind === "section" ? "1" : "n"), used);
  const i = log.findIndex((x) => x.screen.kind === "section");
  const sec = log[i].screen;
  assert.ok(sec.kind === "section" && !sec.options[0].available && sec.options[1].available);
  assert.equal(log[i + 1].screen.kind, "menu");
});

test("timed screens ignore the key they return", async () => {
  // An unaffordable request answered "y" everywhere is still refused (the dialog is timed).
  for (let seed = 1; seed < 400; seed++) {
    const s = calm(seed);
    s.treasury = -500;
    const log = await firstMonth(() => "y", s);
    const d = log.find((x) => x.screen.kind === "dialog")?.screen;
    if (!d || d.kind !== "dialog" || d.affordable) continue;
    const aud = log.find((x) => x.screen.kind === "audience")!.screen;
    const t = log.findIndex((x, i) => i > 3 && x.screen.kind === "treasury");
    assert.ok(aud.kind === "audience" && log[t].snap.pop[aud.faction] < 9);
    assert.ok(kinds(log).includes("mustRefuse"));
    return;
  }
  assert.fail("no unaffordable request found");
});

test("an unavailable report offer is timed: Y does not buy", async () => {
  const s = calm(3);
  s.popularity[5] = 0;
  const log = await firstMonth(() => "Y", s);
  const i = log.findIndex((x) => x.screen.kind === "reportOffer");
  const offer = log[i].screen;
  assert.ok(offer.kind === "reportOffer" && !offer.available && offer.policeDisloyal);
  assert.notEqual(log[i + 1].screen.kind, "report");
  assert.equal(log[i + 1].snap.treasury, log[i].snap.treasury);
});

test("the engine treats an M like any other key: the platform keeps it from reaching the game", async () => {
  const log = await firstMonth((sc) => (sc.kind === "reportOffer" ? "m" : "n"));
  const i = log.findIndex((x) => x.screen.kind === "reportOffer");
  assert.notEqual(log[i + 1].screen.kind, "report");
});
