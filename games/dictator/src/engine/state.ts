// The state of one reign, held in one plain object, with its own seeded random numbers.
// Draw random numbers only through `draw` / `pick`, and only in the order docs/RULES.md §15.4
// gives: the same seed must always replay the same reign.

/** The eight groups, in their fixed order (RULES §1). */
export const ARMY = 0, PEASANTS = 1, LANDOWNERS = 2, GUERRILLAS = 3, NEIGHBOUR = 4, POLICE = 5, EAST = 6, WEST = 7;
export const GROUP_COUNT = 8;
/** Groups 1–6 have a strength; the two superpowers do not. */
export const STRENGTH_COUNT = 6;
/** The three domestic factions that may plot: Army, Peasants, Landowners. */
export const FACTIONS = [ARMY, PEASANTS, LANDOWNERS] as const;

export type Plot = "none" | "assassination" | "revolution";

export interface GameState {
  /** Popularity 0–9 of each of the eight groups. */
  popularity: number[];
  /** Strength 0–9 of groups 1–6. */
  strength: number[];
  /** What each domestic faction plans, as of the most recent plot check. */
  plots: Plot[];
  /** The group index (0–7) each revolution plot relies on, or -1. */
  allies: number[];
  /** Thousands of dollars; may be negative. */
  treasury: number;
  /** Monthly running costs, in thousands; never below 0. */
  costs: number;
  /** The Swiss account, in thousands; only ever grows. */
  swiss: number;
  /** The President's own strength (the bodyguard): no upper limit, never below 0. */
  bodyguard: number;
  month: number;
  /** This month's disaffection line, 2–4 (hidden from the player). */
  threshold: number;
  /** This month's revolution strength, 10–12. */
  revolutionStrength: number;
  /** Plots are suppressed while the month is below this. */
  plotPause: number;
  helicopter: boolean;
  loanEast: boolean;
  loanWest: boolean;
  requestUsed: boolean[];
  decisionUsed: boolean[];
  newsUsed: boolean[];
  alive: boolean;
  escaped: boolean;
  /** The generator's 32-bit state. */
  rng: number;
}

export function newGame(seed: number = (Math.random() * 2 ** 32) >>> 0): GameState {
  return {
    popularity: [7, 7, 7, 0, 7, 7, 7, 7],
    strength: [6, 6, 6, 6, 6, 6],
    plots: ["none", "none", "none"],
    allies: [-1, -1, -1],
    treasury: 1000,
    costs: 60,
    swiss: 0,
    bodyguard: 4,
    month: 0,
    threshold: 0,
    revolutionStrength: 10,
    plotPause: 0,
    helicopter: false,
    loanEast: false,
    loanWest: false,
    requestUsed: Array(24).fill(false),
    decisionUsed: Array(19).fill(false),
    newsUsed: Array(6).fill(false),
    alive: true,
    escaped: false,
    rng: seed >>> 0,
  };
}

/** One raw draw: a uniform number in [0, 1), advancing the generator (RULES §15.4). */
export function draw(s: GameState): number {
  s.rng = (s.rng + 0x6d2b79f5) >>> 0;
  let t = s.rng;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

/** pick(n): a uniform whole number 0 … n−1. */
export const pick = (s: GameState, n: number): number => Math.floor(draw(s) * n);

/** Keep a group's popularity or strength within 0–9. */
export const clampGroup = (v: number): number => Math.max(0, Math.min(9, v));
