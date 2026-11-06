import { test } from "node:test";
import assert from "node:assert/strict";
import {
  BALL, H, IDLE, MAX_SLOPE, MAX_SPEED, PADDLE_H, POINT_PAUSE, SERVE_DELAY, SERVE_SPEED, SPEEDUP, W,
  faceX, newMatch, serverFor, step, winnerOf, type Control, type GameEvent, type State,
} from "../src/engine/rules";

const DT = 1 / 120;
const idle: [Control, Control] = [IDLE, IDLE];

/** A match already in play, with the ball where the test wants it. */
function inPlay(ball: Partial<State["ball"]>): State {
  const s = newMatch(1);
  s.phase = "play";
  Object.assign(s.ball, ball);
  return s;
}

function run(s: State, seconds: number, controls: [Control, Control] = idle): GameEvent[] {
  const out: GameEvent[] = [];
  for (let t = 0; t < seconds; t += DT) out.push(...step(s, controls, DT));
  return out;
}

test("the ball waits on the server's paddle, then is served toward the other side", () => {
  const s = newMatch(7);
  const side = s.server;
  const events = run(s, SERVE_DELAY + DT * 2);
  assert.deepEqual(events.filter((e) => e.kind === "serve"), [{ kind: "serve", side }]);
  assert.equal(s.phase, "play");
  assert.equal(Math.sign(s.ball.vx), side === 0 ? 1 : -1);
  assert.ok(Math.abs(Math.hypot(s.ball.vx, s.ball.vy) - SERVE_SPEED) < 1e-6);
});

test("the waiting ball follows the server's paddle", () => {
  const s = newMatch(7);
  const dir: Control = { dir: 1, target: null };
  run(s, 0.3, s.server === 0 ? [dir, IDLE] : [IDLE, dir]);
  assert.equal(s.ball.y, s.paddles[s.server].y);
  assert.ok(s.ball.y > H / 2);
});

test("the ball bounces off the top and bottom of the table", () => {
  const s = inPlay({ x: W / 2, y: BALL, vx: 100, vy: -400 });
  const events = run(s, 0.05);
  assert.ok(events.some((e) => e.kind === "wall"));
  assert.ok(s.ball.vy > 0);
  assert.ok(s.ball.y >= BALL / 2);

  const t = inPlay({ x: W / 2, y: H - BALL, vx: 100, vy: 400 });
  run(t, 0.05);
  assert.ok(t.ball.vy < 0);
  assert.ok(t.ball.y <= H - BALL / 2);
});

test("a centred hit goes straight back, faster", () => {
  const s = inPlay({ x: faceX(0) + 20, y: H / 2, vx: -400, vy: 0 });
  const events = run(s, 0.1);
  const hit = events.find((e) => e.kind === "paddle");
  assert.deepEqual(hit, { kind: "paddle", side: 0, speed: 400 * SPEEDUP });
  assert.ok(s.ball.vx > 0);
  assert.ok(Math.abs(s.ball.vy) < 1e-9);
  assert.equal(s.rally, 1);
});

test("a hit near the tip leaves at a steep angle, toward that tip's side", () => {
  const s = inPlay({ x: faceX(1) - 20, y: H / 2 + PADDLE_H / 2 + BALL / 2 - 1, vx: 400, vy: 0 });
  run(s, 0.1);
  assert.ok(s.ball.vx < 0);
  const slope = s.ball.vy / -s.ball.vx;
  assert.ok(slope > MAX_SLOPE * 0.9 && slope <= MAX_SLOPE + 1e-9, `slope ${slope}`);
  assert.ok(Math.abs(Math.atan(MAX_SLOPE) * 180 / Math.PI - 55) < 1e-9, "55°");
});

test("the ball never goes faster than MAX_SPEED", () => {
  const s = inPlay({ x: faceX(0) + 20, y: H / 2, vx: -MAX_SPEED, vy: 0 });
  run(s, 0.05);
  assert.ok(Math.abs(Math.hypot(s.ball.vx, s.ball.vy) - MAX_SPEED) < 1e-6);
});

test("even at top speed the ball can't slip through a paddle", () => {
  for (const y of [PADDLE_H / 2, H / 2, H - PADDLE_H / 2]) {
    const s = inPlay({ x: W / 2, y, vx: -MAX_SPEED, vy: 0 });
    s.paddles[0].y = y;
    // Big frames: 1/20 s at top speed is 48 px, nearly five ball widths.
    const events: GameEvent[] = [];
    for (let i = 0; i < 20 && !events.length; i++) events.push(...step(s, idle, 1 / 20));
    assert.equal(events[0]?.kind, "paddle", `y ${y}`);
  }
});

test("a missed ball is a point to the other side, then a pause, then the next serve", () => {
  const s = inPlay({ x: faceX(0) + 20, y: 20, vx: -500, vy: 0 });
  s.paddles[0].y = H - PADDLE_H / 2;
  const events = run(s, 0.3);
  assert.deepEqual(events.filter((e) => e.kind === "point"), [{ kind: "point", side: 1 }]);
  assert.deepEqual(s.score, [0, 1]);
  assert.equal(s.phase, "point");
  run(s, POINT_PAUSE);
  assert.equal(s.phase, "serve");
});

test("the paddles stay on the table", () => {
  const s = newMatch(3);
  run(s, 3, [{ dir: -1, target: null }, { dir: 1, target: null }]);
  assert.equal(s.paddles[0].y, PADDLE_H / 2);
  assert.equal(s.paddles[1].y, H - PADDLE_H / 2);
  run(s, 3, [{ dir: 0, target: -500 }, { dir: 0, target: 5000 }]);
  assert.equal(s.paddles[0].y, PADDLE_H / 2);
  assert.equal(s.paddles[1].y, H - PADDLE_H / 2);
});

test("a pointer target is chased at a limited speed", () => {
  const s = newMatch(3);
  step(s, [{ dir: 0, target: 0, maxSpeed: 120 }, IDLE], 0.5);
  assert.equal(s.paddles[0].y, H / 2 - 60);
});

test("first to 11 wins, but only by two clear points", () => {
  assert.equal(winnerOf([11, 9]), 0);
  assert.equal(winnerOf([10, 11]), null);
  assert.equal(winnerOf([11, 10]), null);
  assert.equal(winnerOf([12, 14]), 1);
  assert.equal(winnerOf([5, 11]), 1);
  assert.equal(winnerOf([10, 10]), null);
});

test("the serve changes every two points, and every point from 10–10", () => {
  const seq = (pairs: [number, number][]) => pairs.map((p) => serverFor(p, 0));
  assert.deepEqual(seq([[0, 0], [1, 0], [1, 1], [2, 1], [2, 2], [3, 2]]), [0, 0, 1, 1, 0, 0]);
  assert.deepEqual(seq([[10, 10], [11, 10], [11, 11], [12, 11]]), [0, 1, 0, 1]);
  assert.equal(serverFor([0, 0], 1), 1);
});

test("the match ends with a winner and stops scoring", () => {
  const s = inPlay({ x: faceX(1) - 20, y: 20, vx: 500, vy: 0 });
  s.score = [10, 3];
  s.paddles[1].y = H - PADDLE_H / 2;
  const events = run(s, 0.3);
  assert.deepEqual(events.filter((e) => e.kind === "win"), [{ kind: "win", side: 0 }]);
  assert.equal(s.phase, "over");
  assert.equal(s.winner, 0);
  run(s, 2);
  assert.deepEqual(s.score, [11, 3]);
});
