// High-score helpers shared by the Worker (worker/index.ts) and its tests.
import { LEVELS, type LevelName } from "../src/engine/ai";
import { replay, type Result } from "../src/engine/match";
import { cleanName } from "../src/name";

export const PATH = "/games/retro/rally";
export const BASE = `${PATH}/api`;
export const SCORES_PAGE = `${PATH}/scores`;
/** Rows on the game's own table, and on the web page. */
export const TABLE_SIZE = 10;
export const PAGE_SIZE = 25;
export const SEED_LIFETIME_MS = 24 * 60 * 60 * 1000;
/** A 30-minute match sends at most one move per tick; this bounds the request well above any real one. */
export const MAX_BODY = 2_000_000;

export interface Row { name: string; score: number; level: LevelName; mine: number; theirs: number; won: boolean }

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

export interface Submission { id: string; name: string; level: LevelName; recording: unknown }

/** Checks a submission's shape and cleans its name (src/name.ts); the recording is checked by replaying it. */
export function parseSubmission(body: unknown): Submission | string {
  if (!body || typeof body !== "object") return "bad request";
  const { id, level, recording } = body as Record<string, unknown>;
  const name = cleanName((body as Record<string, unknown>).name);
  if (typeof id !== "string" || id.length > 64) return "bad game id";
  if (!name) return "bad name";
  if (typeof level !== "string" || !Object.prototype.hasOwnProperty.call(LEVELS, level)) return "bad level";
  return { id, name, level: level as LevelName, recording };
}

/** The verified result of a submission's match, or null when its recording doesn't replay a whole match. */
export const verify = (seed: number, s: Submission): Result | null => replay(seed >>> 0, s.level, s.recording);
