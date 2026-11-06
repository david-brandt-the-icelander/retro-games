// Shared test helpers: scripted IO, key policies and a draw counter.
import type { IO, Screen, Snapshot } from "../src/engine";
import { snapshot } from "../src/engine";
import type { GameState } from "../src/engine";

export interface Step { screen: Screen; snap: Snapshot; key: string }

/** A small key generator independent of the game's own random numbers (xorshift). */
export function keyStream(seed: number, keys: readonly string[]): () => string {
  let x = (seed * 2654435761) >>> 0 || 1;
  return () => { x ^= x << 13; x >>>= 0; x ^= x >>> 17; x ^= x << 5; x >>>= 0; return keys[x % keys.length]; };
}

/** An IO that answers every screen with `answer`, recording each screen and a snapshot taken before the key. */
export function recorder(state: GameState, answer: (screen: Screen, n: number) => string, limit = 200000): { io: IO; log: Step[] } {
  const log: Step[] = [];
  const io: IO = {
    show: async (screen) => {
      if (log.length >= limit) throw new Error(`no end after ${limit} screens`);
      const key = answer(screen, log.length);
      log.push({ screen: structuredClone(screen), snap: snapshot(state), key });
      return key;
    },
  };
  return { io, log };
}

/** Rotate through keys, but always answer the help list with a digit so it cannot spin forever. */
export function rotating(keys: readonly string[]): (screen: Screen, n: number) => string {
  let i = 0;
  return (screen) => {
    const k = keys[i++ % keys.length];
    if (screen.kind === "helpList" && !/^[1-6]$/.test(k)) return String(1 + (i % 6));
    return k;
  };
}

const STEP = 0x6d2b79f5n, MOD = 2n ** 32n;
function inverse(a: bigint, m: bigint): bigint {
  let [r0, r1, s0, s1] = [a, m, 1n, 0n];
  while (r1) { const q = r0 / r1; [r0, r1] = [r1, r0 - q * r1]; [s0, s1] = [s1, s0 - q * s1]; }
  return ((s0 % m) + m) % m;
}
const INV = inverse(STEP, MOD);

/** How many draws took the generator from one state to another (each draw adds a constant). */
export function drawsBetween(before: number, after: number): number {
  return Number(((((BigInt(after >>> 0) - BigInt(before >>> 0)) % MOD) + MOD) % MOD * INV) % MOD);
}

export const kinds = (log: Step[]): string[] => log.map((s) => s.screen.kind);
