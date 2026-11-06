import { test } from "node:test";
import assert from "node:assert/strict";
import { newGame, line210 } from "../src/game.js";
import { MINER } from "../src/graphics.js";

const seq = (...v) => { let i = 0; return () => v[i++ % v.length]; };

test("starts with a lamp of 40 and the welcome message", () => {
  const s = newGame(seq(0.5, 0.5));
  assert.equal(s.f, 40);
  assert.equal(s.msg, "Welcome to the Gloomdeep Mine, digger.");
});

test("keys move the digger and burn lamp oil", () => {
  const s = newGame(seq(0.9, 0.9));
  line210(s, "p", seq(0.5));
  assert.deepEqual([s.x, s.y, s.f], [2, 1, 39]);
});

test("any other key still burns lamp oil (as in the original)", () => {
  const s = newGame(seq(0.9, 0.9));
  line210(s, "P", seq(0.5));
  assert.deepEqual([s.x, s.y, s.f], [1, 1, 39]);
});

test("finding a gem scores 10 and refills 5", () => {
  const s = newGame(seq(0.1, 0.0)); // gem at (1,1)... digger moves onto (2,1)
  s.gx = 2; s.gy = 1;
  line210(s, "p", seq(0.5, 0.5, 0.5));
  assert.equal(s.sc, 10);
  assert.equal(s.f, 44);
});

test("cave-in ends the game", () => {
  const s = newGame(seq(0.9, 0.9));
  line210(s, "a", seq(0.01));
  assert.match(s.over, /roof caves in/);
});

test("miner sprite is the original UDG", () => {
  assert.deepEqual(MINER, [24, 60, 24, 126, 24, 36, 36, 102]);
});
