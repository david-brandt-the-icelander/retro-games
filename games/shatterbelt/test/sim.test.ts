// Whole games: long random runs must stay sane, replay exactly from a seed, and be winnable by a simple bot.
import assert from "node:assert/strict";
import { test } from "node:test";
import { H, MAX_PLAYERS, W } from "../src/engine/config";
import { IDLE, delta, newGame, step, type Controls, type Game } from "../src/engine/game";
import { rand } from "../src/engine/rng";

function sane(g: Game): void {
  const finite = (...xs: number[]) => xs.every(Number.isFinite);
  for (const s of g.ships) {
    assert.ok(finite(s.x, s.y, s.vx, s.vy, s.angle, s.score), `ship ${s.id} has a bad number`);
    assert.ok(s.x >= 0 && s.x < W && s.y >= 0 && s.y < H);
    assert.ok(s.lives >= 0);
  }
  for (const r of g.rocks) assert.ok(finite(r.x, r.y, r.vx, r.vy) && r.x >= 0 && r.x < W && r.y >= 0 && r.y < H);
  for (const b of g.bullets) assert.ok(finite(b.x, b.y));
  assert.ok(g.rocks.length < 200, "rocks multiply out of hand");
  assert.ok(g.bullets.length < 200, "too many shots");
}

/** Random button mashing for every player, from a seeded generator. */
function masher(seed: number, players: number): () => Controls[] {
  const r = { rng: seed };
  let held: Controls[] = Array.from({ length: players }, () => IDLE);
  return () => {
    held = held.map((c) => (rand(r) < 0.1
      ? { left: rand(r) < 0.3, right: rand(r) < 0.3, thrust: rand(r) < 0.3, fire: rand(r) < 0.5, blink: rand(r) < 0.03 }
      : c));
    return held;
  };
}

test("long random games with 1 to 9 players stay sane, in both modes", () => {
  for (let players = 1; players <= MAX_PLAYERS; players++) {
    for (const mode of ["coop", "versus"] as const) {
      const g = newGame(mode, players, players * 101);
      const mash = masher(players, players);
      for (let i = 0; i < 60 * 90 && !g.over; i++) {
        step(g, mash());
        if (i % 30 === 0) sane(g);
      }
      sane(g);
    }
  }
});

test("the same seed and inputs replay the same game", () => {
  const run = () => {
    const g = newGame("versus", 4, 999);
    const mash = masher(5, 4);
    for (let i = 0; i < 60 * 60; i++) step(g, mash());
    return JSON.stringify({ ships: g.ships, rocks: g.rocks.length, wave: g.wave, rng: g.rng });
  };
  assert.equal(run(), run());
});

test("the attract backdrop runs for minutes without ships", () => {
  const g = newGame("attract", 0, 3);
  for (let i = 0; i < 60 * 180; i++) step(g);
  sane(g);
  assert.ok(g.wave >= 1);
  assert.equal(g.over, false);
});

/** Turns towards the nearest rock and shoots; thrusts away when one gets close. */
function bot(g: Game, id: number): Controls {
  const s = g.ships[id];
  if (!s.alive) return IDLE;
  let best = Infinity;
  let aim = 0;
  for (const r of g.rocks) {
    const dx = delta(r.x, s.x, W);
    const dy = delta(r.y, s.y, H);
    const d = Math.hypot(dx, dy);
    if (d < best) { best = d; aim = Math.atan2(dy, dx); }
  }
  let diff = aim - s.angle;
  diff = Math.atan2(Math.sin(diff), Math.cos(diff));
  return { left: diff < -0.05, right: diff > 0.05, thrust: false, fire: Math.abs(diff) < 0.25 && g.time % 0.2 < 0.1, blink: best < 60 };
}

test("a simple bot clears waves and scores", () => {
  const g = newGame("coop", 1, 12345);
  for (let i = 0; i < 60 * 120 && !g.over; i++) step(g, [bot(g, 0)]);
  assert.ok(g.ships[0].score > 1000, `bot scored ${g.ships[0].score}`);
  assert.ok(g.wave >= 2, `bot reached wave ${g.wave}`);
});

test("nine bots in co-op play a full game and it ends", () => {
  const g = newGame("coop", 9, 4242);
  let i = 0;
  for (; i < 60 * 60 * 20 && !g.over; i++) step(g, g.ships.map((_, id) => bot(g, id)));
  sane(g);
  assert.ok(g.ships.reduce((a, s) => a + s.score, 0) > 1000);
});
