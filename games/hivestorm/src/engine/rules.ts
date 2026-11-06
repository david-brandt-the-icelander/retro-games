// Every number the game plays by, in one place. Units: pixels on the 224×288 screen, and frames at 60 a second.

export const W = 224;
export const H = 288;

export type Kind = "queen" | "guard" | "drone" | "worker";

/** The hive's rows, top to bottom, and which of its nine columns each row fills. */
export const LAYOUT: { kind: Kind; cols: number[] }[] = [
  { kind: "queen", cols: [2, 4, 6] },
  { kind: "guard", cols: [1, 2, 3, 4, 5, 6, 7] },
  { kind: "drone", cols: [0, 1, 2, 3, 4, 5, 6, 7, 8] },
  { kind: "worker", cols: [0, 1, 2, 3, 4, 5, 6, 7, 8] },
  { kind: "worker", cols: [0, 1, 2, 3, 4, 5, 6, 7, 8] },
];

export interface Slot { kind: Kind; row: number; col: number }

/** One slot per alien, in LAYOUT order; an alien's id is its index here. */
export const SLOTS: Slot[] = LAYOUT.flatMap((r, row) => r.cols.map((col) => ({ kind: r.kind, row, col })));

/** Points for shooting an alien while it sits in the hive, and while it is out diving. */
export const POINTS: Record<Kind, { home: number; diving: number }> = {
  queen: { home: 60, diving: 200 },
  guard: { home: 50, diving: 100 },
  drone: { home: 40, diving: 80 },
  worker: { home: 30, diving: 60 },
};

/** A diving queen is worth more for each of its guards shot first on the same dive. */
export const QUEEN_BONUS = [200, 400, 800];

export const RULES = {
  startLives: 3,
  extraLifeAt: 7000,
  player: { y: H - 40, speed: 1.6, minX: 9, maxX: W - 9, halfW: 5, halfH: 6 },
  shot: { speed: 5.5, top: 18 },
  formation: { top: 58, colGap: 18, rowGap: 15, centre: 4, sway: 26, swaySpeed: 0.2 },
  alien: { halfW: 6, halfH: 5, crash: 9 },
  peel: { radius: 13, turn: 0.075, sweep: Math.PI * 1.25 },
  dive: { baseSpeed: 1.35, speedPerWave: 0.08, maxSpeed: 2.3, steer: 0.05, maxVx: 1.7, returnSpeed: 1.3 },
  bullet: { speed: 2.4, maxVx: 0.7 },
  /** When this few aliens are left, they stop going home and dive without pause. */
  swarmAt: 5,
  timing: { ready: 150, dying: 130, waveClear: 150, playerOver: 150, gameOver: 270, firstDive: 150 },
};

export const diveSpeed = (wave: number) => Math.min(RULES.dive.maxSpeed, RULES.dive.baseSpeed + (wave - 1) * RULES.dive.speedPerWave);

/** How many aliens may be out diving at once. */
export const maxDivers = (wave: number) => Math.min(2 + Math.floor((wave - 1) / 2), 7);

/** Frames between dives, before a ±30% random spread. */
export const diveInterval = (wave: number) => Math.max(35, 130 - wave * 10);
