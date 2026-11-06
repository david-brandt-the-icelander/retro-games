// The pure game: a table, two paddles and a ball, stepped in fixed time. No DOM, no timers.
import { rng } from "./rng";

/** The table, in logical pixels. The browser scales it to fit the screen. */
export const W = 800;
export const H = 480;

export const PADDLE_W = 12;
export const PADDLE_H = 72;
/** Gap between the table's end and a paddle's back edge. */
export const PADDLE_INSET = 28;
export const BALL = 10;

/** Paddle speed from the keys, in px/s. */
export const PADDLE_SPEED = 560;
/** Paddle speed when it chases a finger or the mouse, in px/s. */
export const POINTER_SPEED = 1200;

export const SERVE_SPEED = 380;
/** Each return is this much faster than the last, up to MAX_SPEED. */
export const SPEEDUP = 1.06;
export const MAX_SPEED = 960;
/** A ball that meets the paddle's very tip leaves at this angle from the horizontal. */
export const MAX_ANGLE = (55 * Math.PI) / 180;
/** The widest angle a serve leaves at. */
export const SERVE_ANGLE = (22 * Math.PI) / 180;

/** The ball rests on the server's paddle this long before it is served, in seconds. */
export const SERVE_DELAY = 0.9;
/** The pause after a point, in seconds. */
export const POINT_PAUSE = 0.7;

export const WIN_POINTS = 11;
export const WIN_BY = 2;
/** The serve changes every this many points, and every point once both reach WIN_POINTS - 1. */
export const SERVES_EACH = 2;

/** 0 is the left paddle, 1 the right. */
export type Side = 0 | 1;

export interface Paddle { /** Centre. */ y: number }
export interface Ball { /** Centre. */ x: number; y: number; vx: number; vy: number }

export type Phase = "serve" | "play" | "point" | "over";

export interface State {
  paddles: [Paddle, Paddle];
  ball: Ball;
  score: [number, number];
  firstServer: Side;
  server: Side;
  phase: Phase;
  /** Seconds left in the serve or point pause. */
  timer: number;
  winner: Side | null;
  /** Returns in the current rally. */
  rally: number;
  random: () => number;
}

/**
 * How one paddle is driven this step. With a target, it moves toward that y at maxSpeed
 * (POINTER_SPEED by default); otherwise it moves in dir at PADDLE_SPEED.
 */
export interface Control { dir: -1 | 0 | 1; target: number | null; maxSpeed?: number }

export const IDLE: Control = { dir: 0, target: null };

export type GameEvent =
  | { kind: "serve"; side: Side }
  | { kind: "paddle"; side: Side; speed: number }
  | { kind: "wall" }
  | { kind: "point"; side: Side }
  | { kind: "win"; side: Side };

/** The x of a paddle's face, the edge the ball meets. */
export const faceX = (side: Side): number => (side === 0 ? PADDLE_INSET + PADDLE_W : W - PADDLE_INSET - PADDLE_W);

export function newMatch(seed: number): State {
  const random = rng(seed);
  const firstServer: Side = random() < 0.5 ? 0 : 1;
  const s: State = {
    paddles: [{ y: H / 2 }, { y: H / 2 }],
    ball: { x: W / 2, y: H / 2, vx: 0, vy: 0 },
    score: [0, 0],
    firstServer,
    server: firstServer,
    phase: "serve",
    timer: SERVE_DELAY,
    winner: null,
    rally: 0,
    random,
  };
  restBall(s);
  return s;
}

/** Who serves after this score: every SERVES_EACH points, then every point at deuce. */
export function serverFor(score: [number, number], firstServer: Side): Side {
  const total = score[0] + score[1];
  const deuce = 2 * (WIN_POINTS - 1);
  const turns = total < deuce ? Math.floor(total / SERVES_EACH) : deuce / SERVES_EACH + (total - deuce);
  return ((firstServer + turns) % 2) as Side;
}

/** Whether this score ends the match, and for whom. */
export function winnerOf(score: [number, number]): Side | null {
  for (const side of [0, 1] as Side[]) {
    const mine = score[side], theirs = score[1 - side];
    if (mine >= WIN_POINTS && mine - theirs >= WIN_BY) return side;
  }
  return null;
}

const clamp = (v: number, lo: number, hi: number) => Math.min(hi, Math.max(lo, v));
const PADDLE_MIN = PADDLE_H / 2;
const PADDLE_MAX = H - PADDLE_H / 2;

function movePaddle(p: Paddle, c: Control, dt: number): void {
  if (c.target !== null) {
    const step = (c.maxSpeed ?? POINTER_SPEED) * dt;
    p.y += clamp(c.target - p.y, -step, step);
  } else {
    p.y += c.dir * PADDLE_SPEED * dt;
  }
  p.y = clamp(p.y, PADDLE_MIN, PADDLE_MAX);
}

/** Puts the ball against the server's paddle, where it waits to be served. */
function restBall(s: State): void {
  const b = s.ball;
  b.x = s.server === 0 ? faceX(0) + BALL / 2 + 1 : faceX(1) - BALL / 2 - 1;
  b.y = s.paddles[s.server].y;
  b.vx = 0;
  b.vy = 0;
}

function serve(s: State, events: GameEvent[]): void {
  const angle = (s.random() * 2 - 1) * SERVE_ANGLE;
  const dir = s.server === 0 ? 1 : -1;
  s.ball.vx = dir * SERVE_SPEED * Math.cos(angle);
  s.ball.vy = SERVE_SPEED * Math.sin(angle);
  s.phase = "play";
  s.rally = 0;
  events.push({ kind: "serve", side: s.server });
}

function score(s: State, side: Side, events: GameEvent[]): void {
  s.score[side]++;
  events.push({ kind: "point", side });
  const winner = winnerOf(s.score);
  if (winner !== null) {
    s.phase = "over";
    s.winner = winner;
    events.push({ kind: "win", side: winner });
  } else {
    s.phase = "point";
    s.timer = POINT_PAUSE;
  }
}

/** Sends the ball back from a paddle: the further from its centre, the steeper; and a little faster each time. */
function returnBall(s: State, side: Side): number {
  const b = s.ball;
  const reach = PADDLE_H / 2 + BALL / 2;
  const offset = clamp((b.y - s.paddles[side].y) / reach, -1, 1);
  const angle = offset * MAX_ANGLE;
  const speed = Math.min(Math.hypot(b.vx, b.vy) * SPEEDUP, MAX_SPEED);
  const dir = side === 0 ? 1 : -1;
  b.vx = dir * speed * Math.cos(angle);
  b.vy = speed * Math.sin(angle);
  b.x = faceX(side) + (dir * BALL) / 2;
  s.rally++;
  return speed;
}

/** Moves the ball by dt, which must be short enough that it can't cross a paddle's face and back. */
function moveBall(s: State, dt: number, events: GameEvent[]): void {
  const b = s.ball;
  const prevX = b.x;
  b.x += b.vx * dt;
  b.y += b.vy * dt;

  if (b.y < BALL / 2) { b.y = BALL - b.y; b.vy = Math.abs(b.vy); events.push({ kind: "wall" }); }
  else if (b.y > H - BALL / 2) { b.y = 2 * (H - BALL / 2) - b.y; b.vy = -Math.abs(b.vy); events.push({ kind: "wall" }); }

  // A return needs the ball's leading edge to cross the paddle's face this step, with the two overlapping vertically.
  const side: Side = b.vx < 0 ? 0 : 1;
  const face = faceX(side);
  const lead = (x: number) => (side === 0 ? x - BALL / 2 : x + BALL / 2);
  const crossed = side === 0 ? lead(prevX) >= face && lead(b.x) < face : lead(prevX) <= face && lead(b.x) > face;
  if (crossed && Math.abs(b.y - s.paddles[side].y) <= PADDLE_H / 2 + BALL / 2) {
    events.push({ kind: "paddle", side, speed: returnBall(s, side) });
    return;
  }

  if (b.x + BALL / 2 < 0) score(s, 1, events);
  else if (b.x - BALL / 2 > W) score(s, 0, events);
}

/** The longest distance the ball may travel in one sub-step. */
const MAX_TRAVEL = BALL / 3;

/** Advances the match by dt seconds and returns what happened, for sound and the scoreboard. */
export function step(s: State, controls: [Control, Control], dt: number): GameEvent[] {
  const events: GameEvent[] = [];
  movePaddle(s.paddles[0], controls[0], dt);
  movePaddle(s.paddles[1], controls[1], dt);

  switch (s.phase) {
    case "serve":
      restBall(s);
      s.timer -= dt;
      if (s.timer <= 0) serve(s, events);
      break;
    case "play": {
      const speed = Math.hypot(s.ball.vx, s.ball.vy);
      const n = Math.max(1, Math.ceil((speed * dt) / MAX_TRAVEL));
      for (let i = 0; i < n && s.phase === "play"; i++) moveBall(s, dt / n, events);
      break;
    }
    case "point":
      s.timer -= dt;
      if (s.timer <= 0) {
        s.server = serverFor(s.score, s.firstServer);
        s.phase = "serve";
        s.timer = SERVE_DELAY;
        restBall(s);
      }
      break;
    case "over":
      break;
  }
  return events;
}
