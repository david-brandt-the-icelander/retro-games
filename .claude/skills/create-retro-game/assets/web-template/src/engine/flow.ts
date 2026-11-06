// EXAMPLE GAME (replace): one game, as an async script over IO, so tests can drive it headless.
import * as rules from "./rules";
import type { IO } from "./screens";
import type { GameState } from "./state";

export async function playGame(io: IO, s: GameState): Promise<GameState> {
  while (s.night < rules.NIGHTS_TO_SURVIVE) {
    s.night++;
    const storm = rules.stormTonight(s);
    const trimmed = (await io.show({ kind: "night", night: s.night, oil: s.oil, storm })) === "y";
    rules.burnOil(s, storm, trimmed);
    if (rules.lampOut(s)) break;
  }
  await io.show({ kind: "ending", survived: !rules.lampOut(s), nights: s.night });
  return s;
}
