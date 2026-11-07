// High-score helpers shared by the Worker (worker/index.ts) and its tests.
export { replay } from "../src/engine/replay";
export { cleanName } from "../src/name";

export const PATH = "/retro/hivestorm";
export const BASE = `${PATH}/api`;
/** Rows in the game's own table screen. */
export const TABLE_SIZE = 10;
/** Rows on the web page. */
export const PAGE_SIZE = 25;
export const SEED_LIFETIME_MS = 24 * 60 * 60 * 1000;
/** A recorded game is a few kilobytes a minute; this allows well over an hour. */
export const MAX_BODY_BYTES = 2_000_000;

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
