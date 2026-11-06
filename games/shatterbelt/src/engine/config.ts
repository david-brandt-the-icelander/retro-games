// Every tuning number in Shatterbelt. Units: pixels of the 1280×800 field, seconds, radians.

/** The field. It wraps at every edge. */
export const W = 1280;
export const H = 800;
/** One simulation step: the game always advances in fixed steps of 1/60 s. */
export const DT = 1 / 60;

export const MAX_PLAYERS = 9;

export const SHIP = {
  radius: 11,
  turn: 4.4,
  thrust: 340,
  /** Velocity decays by e^(-drag·t). */
  drag: 0.6,
  maxSpeed: 430,
  lives: 3,
  /** Seconds before a lost ship comes back. */
  respawn: 2,
  /** Seconds a new ship can't be hurt (it blinks). */
  spawnGuard: 3,
  extraEvery: 10_000,
};

export const GUN = {
  speed: 640,
  life: 0.95,
  /** A fresh press fires at most this often. */
  tapCool: 0.1,
  /** Holding the button fires this often, or `rapidCool` with the rapid-fire pod. */
  holdCool: 0.24,
  rapidCool: 0.075,
  /** Shots one ship may have in flight. */
  cap: 5,
  rapidCap: 8,
  spreadCap: 9,
  spreadAngle: 0.2,
};

export const BLINK = { distance: 230, cool: 3, guard: 0.5 };

export type RockSize = 1 | 2 | 3;
export const ROCK = {
  /** Radius by size (index 1 = small, 3 = large). */
  radius: [0, 15, 30, 54],
  /** Speed range by size. */
  speed: [[0, 0], [100, 170], [60, 115], [30, 70]] as [number, number][],
  points: [0, 120, 60, 25],
  /** Crystal rocks break into three and are worth double; iron rocks take two hits and are worth triple. */
  crystalPoints: 2,
  ironPoints: 3,
  ironHp: 2,
  crystalChance: 0.18,
  /** Iron appears from this wave on. */
  ironFrom: 3,
  /** Chance that a broken crystal piece leaves a pod. */
  podChance: 0.22,
};

export const WAVE = {
  /** Large rocks in wave 1; one more each wave, plus one for every two players past the first. */
  first: 4,
  max: 14,
  /** Seconds between clearing the field and the next wave. */
  pause: 2.5,
  /** Seconds before wave 1. */
  opening: 1.5,
  /** Rocks never appear closer than this to a ship. */
  clearance: 240,
};

export const DRONE = {
  bigRadius: 20,
  smallRadius: 11,
  bigSpeed: 110,
  smallSpeed: 165,
  bigPoints: 250,
  smallPoints: 700,
  bigFire: 1.3,
  smallFire: 1.0,
  shotSpeed: 330,
  shotLife: 1.8,
  /** The hunter (small drone) first appears in this wave. */
  hunterFrom: 3,
  podChance: 0.5,
};

export const POD = { radius: 13, life: 9, duration: 10, speed: 25 };

export const COMBO = {
  /** Hits closer together than this keep a streak going. */
  window: 1.6,
  /** Every `step` hits in a streak raise the multiplier by one, up to `max`. */
  step: 5,
  max: 4,
};

/** Versus: points for destroying another player's ship. */
export const TAKEDOWN = 500;
