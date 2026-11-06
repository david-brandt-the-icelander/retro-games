import assert from "node:assert/strict";
import { test } from "node:test";
import { Alien, Game, Input, NO_INPUT } from "../src/engine/game";
import { H, POINTS, QUEEN_BONUS, RULES, SLOTS, W } from "../src/engine/rules";

const press = (p: Partial<Input>): Input => ({ ...NO_INPUT, ...p });

/** A game started and run until the player can move. */
function playing(players: 1 | 2 = 1, seed = 1): Game {
  const g = new Game(seed);
  g.step(press(players === 1 ? { start1: true } : { start2: true }));
  while (g.phase === "ready") g.step(NO_INPUT);
  assert.equal(g.phase, "play");
  return g;
}

/** Puts the player's shot just under an alien so the next step hits it. */
function shoot(g: Game, a: Alien): void {
  g.shot = { x: Math.round(a.x), y: a.y + RULES.shot.speed + 2 };
  g.diveCooldown = 1e9;
  g.step(NO_INPUT);
}

function killPlayer(g: Game): void {
  g.bullets.push({ x: g.playerX, y: RULES.player.y - RULES.bullet.speed, vx: 0, vy: RULES.bullet.speed });
  g.diveCooldown = 1e9;
  g.step(NO_INPUT);
  assert.equal(g.phase, "dying");
}

const runUntil = (g: Game, phase: string, limit = 2000) => {
  for (let i = 0; i < limit && g.phase !== phase; i++) g.step(NO_INPUT);
  assert.equal(g.phase, phase);
};

test("the hive has 37 aliens in five rows, all on screen at either end of its sway", () => {
  assert.equal(SLOTS.length, 37);
  const g = new Game(1);
  for (const sway of [-RULES.formation.sway, RULES.formation.sway]) {
    g.sway = sway;
    for (const s of SLOTS) {
      const { x, y } = g.home(s);
      assert.ok(x - 7 >= 0 && x + 7 <= W, `x ${x} on screen`);
      assert.ok(y > 20 && y < RULES.player.y - 60);
    }
  }
});

test("the title screen waits; 1 starts a one-player game, 2 a two-player game", () => {
  const g = new Game(1);
  for (let i = 0; i < 500; i++) g.step(press({ fire: true, left: true }));
  assert.equal(g.phase, "attract");
  g.step(press({ start2: true }));
  assert.equal(g.phase, "ready");
  assert.equal(g.numPlayers, 2);
  assert.equal(g.players.length, 2);
  assert.equal(g.current, 0);
  assert.deepEqual(g.players.map((p) => p.lives), [3, 3]);
});

test("only one shot is in the air at a time", () => {
  const g = playing();
  g.diveCooldown = 1e9;
  let shots = 0;
  for (let i = 0; i < 20; i++) shots += g.step(press({ fire: true })).filter((e) => e === "shoot").length;
  assert.equal(shots, 1);
  while (g.shot) g.step(NO_INPUT);
  assert.ok(g.step(press({ fire: true })).includes("shoot"));
});

test("the ship moves and stops at the screen edges", () => {
  const g = playing();
  g.diveCooldown = 1e9;
  for (let i = 0; i < 300; i++) g.step(press({ left: true }));
  assert.equal(g.playerX, RULES.player.minX);
  for (let i = 0; i < 300; i++) g.step(press({ right: true }));
  assert.equal(g.playerX, RULES.player.maxX);
});

test("aliens score their hive value at home and more when diving", () => {
  const g = playing();
  const worker = g.aliens.find((a) => a.kind === "worker")!;
  shoot(g, worker);
  assert.equal(worker.alive, false);
  assert.equal(g.player!.score, POINTS.worker.home);

  const guard = g.aliens.find((a) => a.kind === "guard" && a.alive)!;
  guard.mode = "dive";
  shoot(g, guard);
  assert.equal(g.player!.score, POINTS.worker.home + POINTS.guard.diving);
});

test("a diving queen is worth 200, 400 or 800 by how many of her escorts fell first", () => {
  for (const lost of [0, 1, 2]) {
    const g = playing(1, 3);
    const q = g.aliens.find((a) => a.kind === "queen" && a.col === 4)!;
    // Send her out with two guards, then step until they are clear of the hive.
    (g as unknown as { startDive(a: Alien): void }).startDive(q);
    const escorts = g.aliens.filter((a) => a.kind === "guard" && Math.abs(a.col - q.col) <= 1).slice(0, 2);
    for (const e of escorts) { e.mode = "dive"; e.leader = q.id; e.offX = e.x - q.x; e.offY = e.y - q.y; }
    g.diveCooldown = 1e9;
    for (let i = 0; i < 70; i++) g.step(NO_INPUT);
    const before = g.player!.score;
    for (const e of escorts.slice(0, lost)) shoot(g, e);
    const afterEscorts = g.player!.score;
    assert.equal(afterEscorts - before, lost * POINTS.guard.diving);
    shoot(g, q);
    assert.equal(g.player!.score - afterEscorts, QUEEN_BONUS[lost]);
    assert.equal(g.popups.at(-1)?.text, String(QUEEN_BONUS[lost]));
  }
});

test("clearing the hive brings the next wave", () => {
  const g = playing();
  for (const a of g.aliens) if (a.kind !== "worker" || a.col !== 0 || a.row !== 4) a.alive = false;
  const last = g.aliens.find((a) => a.alive)!;
  shoot(g, last);
  assert.equal(g.phase, "waveClear");
  assert.equal(g.player!.wave, 2);
  runUntil(g, "play");
  assert.equal(g.aliveCount, 37);
});

test("an extra ship comes once, at 7000", () => {
  const g = playing();
  g.player!.score = RULES.extraLifeAt - 10;
  shoot(g, g.aliens.find((a) => a.kind === "worker")!);
  assert.equal(g.player!.lives, 4);
  g.player!.score = RULES.extraLifeAt * 2 - 10;
  shoot(g, g.aliens.find((a) => a.kind === "worker" && a.alive)!);
  assert.equal(g.player!.lives, 4);
});

test("a diving alien that rams the ship destroys both", () => {
  const g = playing();
  const a = g.aliens.find((x) => x.kind === "drone")!;
  a.mode = "dive";
  a.x = g.playerX;
  a.y = RULES.player.y - 3;
  a.vx = 0; a.vy = 0;
  g.diveCooldown = 1e9;
  g.step(NO_INPUT);
  assert.equal(a.alive, false);
  assert.equal(g.phase, "dying");
  assert.equal(g.player!.lives, 2);
});

test("one player: losing every ship ends the game, keeps the high score and returns to the title", () => {
  const g = playing();
  shoot(g, g.aliens.find((a) => a.kind === "worker")!);
  for (let life = 3; life > 0; life--) {
    killPlayer(g);
    if (life > 1) runUntil(g, "play");
  }
  runUntil(g, "gameOver");
  assert.equal(g.hiScore, POINTS.worker.home);
  runUntil(g, "attract");
});

test("two players take turns, each with their own hive, score and ships", () => {
  const g = playing(2);
  const target = g.aliens.find((a) => a.kind === "worker")!;
  shoot(g, target);
  assert.equal(g.players[0].score, 30);
  killPlayer(g);
  runUntil(g, "ready");
  assert.equal(g.current, 1);
  assert.equal(g.aliveCount, 37, "player 2 has a full hive");
  runUntil(g, "play");
  killPlayer(g);
  runUntil(g, "ready");
  assert.equal(g.current, 0);
  assert.equal(g.aliveCount, 36, "player 1's hive is as they left it");
  assert.equal(g.aliens[target.id].alive, false);
  assert.deepEqual(g.players.map((p) => p.lives), [2, 2]);
  assert.deepEqual(g.players.map((p) => p.score), [30, 0]);
});

test("two players: when one is out, the other plays on alone until they are out too", () => {
  const g = playing(2);
  g.players[0].lives = 1;
  killPlayer(g);
  runUntil(g, "playerOver");
  assert.equal(g.players[0].over, true);
  runUntil(g, "play");
  assert.equal(g.current, 1);
  killPlayer(g);
  runUntil(g, "play");
  assert.equal(g.current, 1, "the turn stays with the player still in");
  g.players[1].lives = 1;
  killPlayer(g);
  runUntil(g, "playerOver");
  runUntil(g, "gameOver");
});

test("pause stops the game and P resumes it", () => {
  const g = playing();
  g.step(press({ pause: true }));
  const frame = g.frame;
  for (let i = 0; i < 50; i++) g.step(press({ left: true }));
  assert.equal(g.frame, frame);
  g.step(press({ pause: true }));
  assert.equal(g.frame, frame + 1, "the step that unpauses runs");
});

test("aliens peel off, dive, fire and come home", () => {
  const g = playing(1, 9);
  const seen = new Set<string>();
  let fired = false;
  for (let i = 0; i < 4000 && g.phase === "play"; i++) {
    const before = g.bullets.length;
    g.step(NO_INPUT);
    if (g.bullets.length > before) fired = true;
    for (const a of g.aliens) seen.add(a.mode);
    g.playerX = 9; // stay mostly out of the way
    g.bullets = g.bullets.filter((b) => b.y < RULES.player.y - 20);
  }
  for (const m of ["home", "peel", "dive", "return"]) assert.ok(seen.has(m), `saw ${m}`);
  assert.ok(fired, "divers fire");
});

test("a long game of random play never breaks", () => {
  for (const seed of [1, 2, 3, 4]) {
    const g = new Game(seed);
    let r = seed;
    const rand = () => ((r = (r * 1103515245 + 12345) >>> 0) / 2 ** 32);
    let games = 0;
    for (let i = 0; i < 60_000; i++) {
      const input = press({ left: rand() < 0.4, right: rand() < 0.4, fire: rand() < 0.5, start1: rand() < 0.01, start2: rand() < 0.01 });
      if (g.phase === "attract" && input.start1) games++;
      g.step(input);
      for (const a of g.aliens) {
        assert.ok(Number.isFinite(a.x) && Number.isFinite(a.y));
        if (a.alive && a.mode === "home") assert.ok(a.y < H / 2);
      }
      for (const p of g.players) assert.ok(p.lives >= 0 && p.score >= 0);
    }
    assert.ok(games >= 1);
  }
});
