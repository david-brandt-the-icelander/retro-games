// High-score helpers shared by the Worker (worker/index.ts) and its tests.
import { newGame, playGame } from "../src/engine";

export const BASE = "/games/retro/samosa/api";
/** Where the game used to live: every path there is redirected to the same path under /games/retro/samosa. */
export const OLD_PATH = "/retro-games/samosa";
export const PATH = "/games/retro/samosa";
export const TABLE_SIZE = 10;
export const MAX_KEYS = 20000;
export const SEED_LIFETIME_MS = 24 * 60 * 60 * 1000;

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: {
      "Content-Type": "application/json; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
    },
  });

/** The public name: the part before the @, limited to characters the game's font can draw. */
export function publicName(email: string): string {
  const local = email.slice(0, email.lastIndexOf("@"));
  const clean = local.replace(/[^A-Za-z0-9._+-]/g, "").slice(0, 12);
  return clean || "anonymous";
}

export function validEmail(email: unknown): email is string {
  return typeof email === "string" && email.length <= 254 && /^[^\s@]{1,64}@[^\s@.]+(\.[^\s@.]+)+$/.test(email);
}

/** Replay a reign from its seed and keys. Returns null unless the keys play exactly one whole game. */
export async function replay(seed: number, keys: string[]): Promise<{ score: number; months: number; alive: boolean } | null> {
  const state = newGame(seed);
  let i = 0;
  const io = { show: async () => { if (i >= keys.length) throw new RangeError("out of keys"); return keys[i++]; } };
  try {
    const outcome = await playGame(io as never, state, null);
    if (i !== keys.length) return null;
    return { score: outcome.score, months: state.month, alive: state.alive };
  } catch {
    return null;
  }
}

