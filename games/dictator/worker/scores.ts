// High-score helpers shared by the Worker (worker/index.ts) and its tests.
import { newGame, playGame } from "../src/engine";

export const BASE = "/retro/samosa/api";
/** Where the game used to live: every path there is redirected to the same path under /retro/samosa. */
/** The games' own site, where the old address redirects to. */
export const ORIGIN = "https://games.icelander.net";
export const OLD_PATH = "/retro-games/samosa";
export const PATH = "/retro/samosa";
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

export { cleanName } from "../src/name";

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

