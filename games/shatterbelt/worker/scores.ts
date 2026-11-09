// High-score helpers shared by the Worker (worker/index.ts) and its tests.
import { standings } from "../src/engine/game";
import { replay, validRecording, type Recording } from "../src/engine/replay";
import { cleanName } from "../src/name";

export const PATH = "/games/retro/shatterbelt";
/** Where the game first lived: every path there is redirected to the same path under PATH. */
/** The games' own site, where the old address redirects to. */
export const ORIGIN = "https://icelander.net";
export const OLD_PATH = "/retro-games/shatterbelt";
export const BASE = `${PATH}/api`;
export const SCORES_PAGE = `${PATH}/scores`;
/** Rows the game's title screen shows, and rows the web page shows. */
export const TABLE_SIZE = 10;
export const PAGE_SIZE = 25;
export const SEED_LIFETIME_MS = 24 * 60 * 60 * 1000;
/** A recording of 90 minutes with nine busy players stays well under this. */
export const MAX_BODY = 4_000_000;

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

export interface Submission {
  id: string;
  recording: Omit<Recording, "seed">;
  /** One per player: their name (cleaned by src/name.ts), or null to stay off the table. */
  names: (string | null)[];
}

export function validSubmission(body: unknown): body is Submission {
  if (!body || typeof body !== "object") return false;
  const b = body as Record<string, unknown>;
  if (typeof b.id !== "string" || b.id.length > 64) return false;
  const r = b.recording as Record<string, unknown> | undefined;
  if (!r || typeof r !== "object" || !Array.isArray(b.names) || b.names.length !== r.players) return false;
  return b.names.every((n) => n === null || (typeof n === "string" && n.length <= 200 && cleanName(n) !== ""));
}

export interface Result { player: number; score: number; wave: number }

/**
 * Replays a submitted game from the seed the server issued. Returns every player's score as the
 * server computes it, or null unless the recording plays exactly one whole game.
 */
export function score(seed: number, sub: Submission): Result[] | null {
  const rec = { ...sub.recording, seed: seed >>> 0 } as Recording;
  if (!validRecording(rec)) return null;
  const g = replay(rec);
  if (!g) return null;
  return standings(g)
    .sort((a, b) => a.id - b.id)
    .map((s) => ({ player: s.id, score: s.score, wave: g.wave }));
}
