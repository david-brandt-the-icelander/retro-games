// The rules of the simulation, one at a time, on hand-made situations.
import assert from "node:assert/strict";
import { test } from "node:test";
import { BLINK, COMBO, DT, GUN, H, MAX_PLAYERS, ROCK, SHIP, TAKEDOWN, W, WAVE } from "../src/engine/config";
import { IDLE, delta, multiplier, newGame, rocksForWave, spawnPoint, step, type Controls, type Game, type Rock } from "../src/engine/game";
import { rand } from "../src/engine/rng";

const press = (c: Partial<Controls>): Controls => ({ ...IDLE, ...c });

/** Steps until wave 1 is on the field. */
function started(mode: "coop" | "versus", players: number, seed = 1): Game {
  const g = newGame(mode, players, seed);
  while (g.wave === 0) step(g);
  return g;
}

/** A game with the field emptied, ships unguarded and the drone held back, for setting up a situation by hand. */
function quiet(mode: "coop" | "versus", players: number): Game {
  const g = started(mode, players);
  g.rocks = [];
  g.waveTimer = 999;
  g.droneTimer = 999;
  for (const s of g.ships) s.guard = 0;
  return g;
}

function rock(g: Game, x: number, y: number, size: 1 | 2 | 3, kind: Rock["kind"] = "stone"): Rock {
  const r: Rock = { id: g.nextId++, x, y, vx: 0, vy: 0, size, kind, hp: kind === "iron" ? ROCK.ironHp : 1, angle: 0, spin: 0, shape: [1, 1, 1, 1, 1, 1, 1, 1], flash: 0, dead: false };
  g.rocks.push(r);
  return r;
}

test("the generator is deterministic and uniform enough", () => {
  const a = { rng: 42 };
  const b = { rng: 42 };
  const xs = Array.from({ length: 1000 }, () => rand(a));
  assert.deepEqual(xs, Array.from({ length: 1000 }, () => rand(b)));
  assert.ok(xs.every((x) => x >= 0 && x < 1));
  const mean = xs.reduce((s, x) => s + x, 0) / xs.length;
  assert.ok(Math.abs(mean - 0.5) < 0.05);
});

test("a game holds 1 to 9 players; attract mode holds none", () => {
  assert.equal(newGame("coop", 1, 1).ships.length, 1);
  assert.equal(newGame("coop", 9, 1).ships.length, 9);
  assert.equal(newGame("coop", 40, 1).ships.length, MAX_PLAYERS);
  assert.equal(newGame("coop", 0, 1).ships.length, 1);
  assert.equal(newGame("attract", 4, 1).ships.length, 0);
});

test("every player starts apart from the others, on the field", () => {
  for (let n = 1; n <= MAX_PLAYERS; n++) {
    const pts = Array.from({ length: n }, (_, i) => spawnPoint(i, n));
    for (const p of pts) assert.ok(p.x > 0 && p.x < W && p.y > 0 && p.y < H);
    for (let i = 0; i < n; i++) for (let j = i + 1; j < n; j++) {
      assert.ok(Math.hypot(pts[i].x - pts[j].x, pts[i].y - pts[j].y) > SHIP.radius * 8, `${n} players: ${i} and ${j} too close`);
    }
  }
});

test("wave 1 arrives after the opening pause, with rocks away from every ship", () => {
  const g = newGame("coop", 4, 7);
  let steps = 0;
  while (g.wave === 0) { step(g); steps++; }
  assert.ok(Math.abs(steps * DT - WAVE.opening) < 2 * DT);
  assert.equal(g.rocks.length, rocksForWave(1, 4));
  assert.ok(g.rocks.every((r) => r.size === 3));
});

test("more players and later waves bring more rocks, up to the cap", () => {
  assert.equal(rocksForWave(1, 1), WAVE.first);
  assert.ok(rocksForWave(1, 9) > rocksForWave(1, 1));
  assert.ok(rocksForWave(5, 1) > rocksForWave(1, 1));
  assert.equal(rocksForWave(50, 9), WAVE.max);
});

test("a ship turns, thrusts, coasts to a stop and wraps around the edges", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  const a0 = s.angle;
  step(g, [press({ right: true })]);
  assert.ok(s.angle > a0);
  s.angle = 0;
  for (let i = 0; i < 60; i++) step(g, [press({ thrust: true })]);
  assert.ok(s.vx > 100 && Math.abs(s.vy) < 1e-9);
  for (let i = 0; i < 600; i++) step(g, [press({ thrust: true })]);
  assert.ok(Math.hypot(s.vx, s.vy) <= SHIP.maxSpeed + 1e-9);
  for (let i = 0; i < 900; i++) step(g);
  assert.ok(Math.hypot(s.vx, s.vy) < 2);
  assert.ok(s.x >= 0 && s.x < W && s.y >= 0 && s.y < H);
  s.x = W - 1;
  s.vx = 300;
  step(g);
  assert.ok(s.x < 10);
});

test("shots are limited in flight, and holding fire is slower than tapping", () => {
  const g = quiet("coop", 1);
  for (let i = 0; i < 30; i++) step(g, [press({ fire: true })]);
  const held = g.bullets.length;
  assert.ok(held >= 2 && held <= 3, `held fire gave ${held} shots in half a second`);
  for (let i = 0; i < 120; i++) step(g, [press({ fire: i % 2 === 0 })]);
  assert.ok(g.bullets.length <= GUN.cap);
  assert.equal(g.bullets.length, GUN.cap);
});

test("shots expire after their range", () => {
  const g = quiet("coop", 1);
  step(g, [press({ fire: true })]);
  assert.equal(g.bullets.length, 1);
  for (let i = 0; i < GUN.life / DT + 2; i++) step(g);
  assert.equal(g.bullets.length, 0);
});

test("rocks split by kind and score by size and kind", () => {
  for (const [kind, pieces, mult] of [["stone", 2, 1], ["crystal", 3, ROCK.crystalPoints], ["iron", 2, ROCK.ironPoints]] as const) {
    const g = quiet("coop", 1);
    const s = g.ships[0];
    s.angle = 0;
    const r = rock(g, s.x + 120, s.y, 3, kind);
    for (let i = 0; i < 400 && !r.dead && g.rocks.includes(r); i++) step(g, [press({ fire: i % 8 === 0 })]);
    assert.ok(!g.rocks.includes(r), `${kind} rock broke`);
    const kids = g.rocks.filter((k) => k.size === 2 && k.kind === kind);
    assert.equal(kids.length, pieces, `${kind} pieces`);
    assert.equal(s.score % (ROCK.points[3] * mult), 0);
    assert.ok(s.score >= ROCK.points[3] * mult);
  }
});

test("iron takes two hits", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  s.angle = 0;
  const r = rock(g, s.x + 100, s.y, 2, "iron");
  step(g, [press({ fire: true })]);
  for (let i = 0; i < 30 && g.bullets.length; i++) step(g);
  assert.ok(g.rocks.includes(r));
  assert.equal(r.hp, 1);
  for (let i = 0; i < 10; i++) step(g); // past the tap cooldown
  for (let i = 0; i < 40 && g.rocks.includes(r); i++) step(g, [press({ fire: i === 0 })]);
  assert.ok(!g.rocks.includes(r));
});

test("touching a rock costs a ship, and the ship comes back guarded", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  rock(g, s.x, s.y, 2);
  step(g);
  assert.equal(s.alive, false);
  assert.equal(s.lives, SHIP.lives - 1);
  for (let i = 0; i < SHIP.respawn / DT + 2; i++) step(g);
  assert.equal(s.alive, true);
  assert.ok(s.guard > 0);
  rock(g, s.x, s.y, 2);
  step(g);
  assert.equal(s.alive, true, "a guarded ship can't be hurt");
});

test("a shield takes one hit", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  s.shield = true;
  rock(g, s.x, s.y, 1);
  step(g);
  assert.equal(s.alive, true);
  assert.equal(s.shield, false);
});

test("two ships that touch are both lost, in co-op and in versus", () => {
  for (const mode of ["coop", "versus"] as const) {
    const g = quiet(mode, 3);
    const [a, b, c] = g.ships;
    b.x = a.x + SHIP.radius;
    b.y = a.y;
    step(g);
    assert.equal(a.alive, false, `${mode}: a`);
    assert.equal(b.alive, false, `${mode}: b`);
    assert.equal(c.alive, true, `${mode}: c is elsewhere`);
    assert.equal(a.lives, SHIP.lives - 1);
    assert.equal(a.score + b.score, 0, "nobody scores a collision");
  }
});

test("a ship still guarded after appearing doesn't collide with another", () => {
  const g = quiet("coop", 2);
  const [a, b] = g.ships;
  a.guard = 1;
  b.x = a.x;
  b.y = a.y;
  step(g);
  assert.ok(a.alive && b.alive);
});

test("co-op shots pass through other ships; versus shots take them down for points", () => {
  for (const mode of ["coop", "versus"] as const) {
    const g = quiet(mode, 2);
    const [a, b] = g.ships;
    a.x = 200; a.y = 400; a.angle = 0;
    b.x = 320; b.y = 400;
    step(g, [press({ fire: true })]);
    for (let i = 0; i < 20; i++) step(g);
    if (mode === "coop") {
      assert.equal(b.alive, true);
      assert.equal(a.score, 0);
    } else {
      assert.equal(b.alive, false);
      assert.equal(a.score, TAKEDOWN);
    }
  }
});

test("a ship's own shots never hit it", () => {
  const g = quiet("versus", 1);
  const s = g.ships[0];
  s.angle = 0;
  step(g, [press({ fire: true })]);
  for (let i = 0; i < 300; i++) step(g, [press({ fire: i % 10 === 0 })]); // shots wrap round the field
  assert.equal(s.alive, true);
});

test("blink jumps ahead, guards briefly, and has a cooldown", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  s.angle = 0;
  const x0 = s.x;
  step(g, [press({ blink: true })]);
  assert.ok(Math.abs(delta(s.x, x0, W) - BLINK.distance) < 1);
  assert.ok(s.guard > 0);
  const x1 = s.x;
  step(g, [press({})]);
  step(g, [press({ blink: true })]);
  assert.ok(Math.abs(delta(s.x, x1, W)) < 1, "no second blink during the cooldown");
});

test("hits in quick succession raise the multiplier; a pause resets it", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  assert.equal(multiplier(s, g.time), 1);
  s.combo = COMBO.step;
  s.lastHit = g.time;
  const r = rock(g, s.x + 60, s.y, 1);
  r.hp = 1;
  s.angle = 0;
  s.guard = 0;
  step(g, [press({ fire: true })]);
  for (let i = 0; i < 10 && g.rocks.length; i++) step(g);
  assert.equal(s.score, ROCK.points[1] * 2);
  assert.equal(multiplier(s, g.time), 2);
  assert.equal(multiplier(s, g.time + COMBO.window + 0.1), 1);
});

test("an extra ship every 10,000 points", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  s.score = SHIP.extraEvery - 10;
  const r = rock(g, s.x + 60, s.y, 1);
  s.angle = 0;
  step(g, [press({ fire: true })]);
  for (let i = 0; i < 10 && g.rocks.includes(r); i++) step(g);
  assert.equal(s.lives, SHIP.lives + 1);
  assert.ok(g.events.some((e) => e.type === "extra") || s.nextExtra === SHIP.extraEvery * 2);
});

test("clearing the field brings the next wave after a pause", () => {
  const g = started("coop", 1);
  g.rocks = [];
  step(g);
  assert.ok(g.events.some((e) => e.type === "clear"));
  let steps = 0;
  while (g.wave === 1) { step(g); steps++; }
  assert.ok(Math.abs(steps * DT - WAVE.pause) < 2 * DT);
  assert.equal(g.wave, 2);
});

test("the game ends only when every player is out of ships", () => {
  const g = quiet("coop", 2);
  const [a, b] = g.ships;
  a.lives = 1;
  b.lives = 1;
  rock(g, a.x, a.y, 1);
  step(g);
  assert.equal(a.out, true);
  assert.equal(g.over, false);
  rock(g, b.x, b.y, 1);
  step(g);
  assert.equal(b.out, true);
  assert.equal(g.over, true);
  assert.ok(g.events.some((e) => e.type === "over"));
});

test("pods give their power", () => {
  const g = quiet("coop", 1);
  const s = g.ships[0];
  for (const kind of ["rapid", "spread", "shield"] as const) {
    g.pods.push({ id: g.nextId++, x: s.x, y: s.y, vx: 0, vy: 0, kind, life: 5, dead: false });
    step(g);
  }
  assert.equal(s.shield, true);
  assert.equal(s.power, "spread");
  s.angle = 0;
  step(g, [press({ fire: true })]);
  assert.equal(g.bullets.length, 3, "spread fires three");
});
