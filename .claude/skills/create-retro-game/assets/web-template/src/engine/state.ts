// EXAMPLE GAME (replace): the state of one game, with its own seeded random numbers.
// Draw random numbers only through `rnd`, in the order docs/RULES.md gives, so a seed
// always replays the same game (that is what makes parity testing possible).

export interface GameState {
  night: number;
  oil: number;
  /** RNG state (mulberry32). */
  seed: number;
}

export const newGame = (seed: number = (Math.random() * 2 ** 32) >>> 0): GameState => ({ night: 0, oil: 6, seed: seed >>> 0 });

/** Uniform float in [0, 1), advancing the state's seed. */
export function random(s: GameState): number {
  s.seed = (s.seed + 0x6d2b79f5) >>> 0;
  let t = s.seed;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

/** Uniform integer in 0..n-1. */
export const rnd = (s: GameState, n: number): number => Math.floor(random(s) * n);
