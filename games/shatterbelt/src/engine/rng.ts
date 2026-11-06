// The one random generator: a 32-bit state kept in the game, so a seed replays a game exactly.

export interface Seeded {
  rng: number;
}

/** A uniform number in [0, 1). Advances the state. */
export function rand(g: Seeded): number {
  g.rng = (g.rng + 0x6d2b79f5) | 0;
  let t = g.rng;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

export function range(g: Seeded, lo: number, hi: number): number {
  return lo + (hi - lo) * rand(g);
}

export function pick<T>(g: Seeded, items: readonly T[]): T {
  return items[Math.floor(rand(g) * items.length)];
}
