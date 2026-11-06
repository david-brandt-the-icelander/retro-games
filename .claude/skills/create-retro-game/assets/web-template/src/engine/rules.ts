// EXAMPLE GAME (replace): rules as small pure functions named for what they do.
import { GameState, rnd } from "./state";

export const NIGHTS_TO_SURVIVE = 7;

/** One night in three brings a storm (one draw per night). */
export const stormTonight = (s: GameState): boolean => rnd(s, 3) === 0;

/** Burn the night's oil: 1, or 2 in a storm; trimming the wick saves 1 in a storm. */
export function burnOil(s: GameState, storm: boolean, trimmed: boolean): void {
  s.oil -= storm && !trimmed ? 2 : 1;
}

export const lampOut = (s: GameState): boolean => s.oil <= 0;
