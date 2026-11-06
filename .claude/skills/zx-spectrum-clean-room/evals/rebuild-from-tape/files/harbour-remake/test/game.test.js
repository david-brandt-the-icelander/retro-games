import { test } from "node:test";
import assert from "node:assert/strict";
import { newGame, line200, line300, titleScreen, harbourMap } from "../src/game.js";

test("title screen credits the original", () => {
  assert.equal(titleScreen()[3][2], "Copyright FICTISOFT 1983");
});

test("smugglers pay 40 gold and cost 2 reputation", () => {
  const st = newGame();
  const ev = line200(st, 0.3);
  assert.equal(ev.lines[2], "Smugglers whisper of a moonless landing.");
  line300(st, ev, "y");
  assert.equal(st.gold, 140);
  assert.equal(st.rep, 3);
});

test("refusing flips reputation and costs nothing", () => {
  const st = newGame();
  const ev = line200(st, 0.6);
  line300(st, ev, "n");
  assert.equal(st.gold, 100);
  assert.equal(st.rep, 3);
});

test("going broke ends the game", () => {
  const st = newGame();
  st.gold = 10;
  line300(st, line200(st, 0.6), "y");
  assert.match(st.over, /ruined/);
});

test("surviving thirty days wins", () => {
  const st = newGame();
  st.day = 30;
  line300(st, line200(st, 0.9), "y");
  assert.match(st.over, /Well done/);
});

test("map is 6 rows of 10", () => {
  assert.equal(harbourMap().length, 6);
  assert.ok(harbourMap().every((r) => r.length === 10));
});
