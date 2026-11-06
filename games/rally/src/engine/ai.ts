// The computer opponent. It sees the ball only every `reaction` seconds, guesses where the ball
// will reach its paddle (bounces included) with some error, and moves there no faster than its level allows.
import { BALL, H, PADDLE_H, PADDLE_SPEED, SERVE_SPEED, faceX, type Control, type Side, type State } from "./rules";
import { rng } from "./rng";

export type LevelName = "easy" | "normal" | "hard";

export interface Level {
  /** Top speed, as a share of a player's key speed. */
  speed: number;
  /** Seconds between looks at the ball. */
  reaction: number;
  /** Largest error in its guess of where a serve-speed ball will arrive, in px. It grows with the ball's speed. */
  error: number;
  /** How far from the paddle's centre it tries to meet the ball, as a share of half the paddle: wider means sharper returns. */
  aim: number;
}

export const LEVELS: Record<LevelName, Level> = {
  easy: { speed: 0.5, reaction: 0.3, error: 46, aim: 0.15 },
  normal: { speed: 0.72, reaction: 0.17, error: 24, aim: 0.45 },
  hard: { speed: 0.95, reaction: 0.08, error: 8, aim: 0.75 },
};

/** Where the ball's centre will be when it reaches x, folding in the bounces off the table's sides. */
export function predictY(s: State, x: number): number {
  const b = s.ball;
  if (b.vx === 0) return b.y;
  const t = (x - b.x) / b.vx;
  if (t < 0) return b.y;
  const span = H - BALL;
  const raw = b.y - BALL / 2 + b.vy * t;
  const m = ((raw % (2 * span)) + 2 * span) % (2 * span);
  return BALL / 2 + (m <= span ? m : 2 * span - m);
}

/** How fast the error grows with the ball's speed: a ball twice as fast is guessed this power of 2 times worse. */
export const FAST_MISS = 1.5;

export class Cpu {
  private random: () => number;
  private wait = 0;
  private target = H / 2;
  /** Which rally the current plan was made for, so a new guess is drawn once per incoming ball. */
  private planned = -1;
  private guess = 0;

  constructor(readonly side: Side, readonly level: Level, seed: number) {
    this.random = rng(seed);
  }

  control(s: State, dt: number): Control {
    this.wait -= dt;
    if (this.wait <= 0) {
      this.wait = this.level.reaction;
      this.look(s);
    }
    return { dir: 0, target: this.target, maxSpeed: PADDLE_SPEED * this.level.speed };
  }

  private look(s: State): void {
    const b = s.ball;
    const coming = s.phase === "play" && (this.side === 0 ? b.vx < 0 : b.vx > 0);
    if (s.phase === "serve" && s.server === this.side) {
      // Holding the ball: wander a little so serves don't all start from the same place.
      if (this.planned !== -2) { this.planned = -2; this.target = H / 2 + (this.random() * 2 - 1) * H * 0.3; }
      return;
    }
    if (!coming) {
      this.planned = -1;
      this.target += (H / 2 - this.target) * 0.5;
      return;
    }
    const key = s.rally * 2 + this.side;
    if (this.planned !== key) {
      this.planned = key;
      const pace = Math.hypot(s.ball.vx, s.ball.vy) / SERVE_SPEED;
      const miss = (this.random() * 2 - 1) * this.level.error * pace ** FAST_MISS;
      const aim = (this.random() * 2 - 1) * this.level.aim * (PADDLE_H / 2);
      this.guess = miss - aim;
    }
    this.target = predictY(s, faceX(this.side)) + this.guess;
  }
}
