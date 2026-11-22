// The Advent calendar's address on icelander.net, and the invite-only role every file is served under.
// A module of its own: the Worker's main module may export nothing but its handler (workerd reads every
// named export there as an entrypoint).
export const BASE = "/games/fresh/advent-calendar";
export const ROLE = "games:advent-calendar";
/** Developers may preview every window before its date and forget the opened ones. */
export const DEV_ROLE = "games:advent-calendar-dev";

/**
 * The last window anyone may open at this moment: the day of December where the calendar date is furthest ahead
 * (UTC+14), so a player is never refused a window their own clock has reached. 0 outside December.
 */
export function lastOpenDay(now: Date): number {
  const ahead = new Date(now.getTime() + 14 * 60 * 60 * 1000);
  return ahead.getUTCMonth() === 11 ? Math.min(24, ahead.getUTCDate()) : 0;
}
