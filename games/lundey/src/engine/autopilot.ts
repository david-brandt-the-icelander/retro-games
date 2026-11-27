// A simple player, for the demo on the title screen and for tests: it heads for the nearest eel, feather or treat
// and shies away from hunters that come close. It is no champion.
import { Game, nearTile } from "./game";
import { distances, neighbour, walkable } from "./maze";
import { Dir, opposite } from "./rules";

/** How near a hunter has to be before the autopilot minds it, in tiles. */
const WARY = 7;

export function autopilot(g: Game): Dir | -1 {
  if (g.phase !== "play" && g.phase !== "ready") return -1;
  const p = g.puffin, tiles = g.maze.tiles;
  const food: number[] = [];
  for (let i = 0; i < tiles.length; i++) if (g.eels[i] || g.feathers[i]) food.push(i);
  if (g.treat) food.push(g.treat.tile);
  const lure = distances(tiles, food, false);
  const fear = distances(tiles, g.hunters.filter((h) => h.state === "out").map(nearTile), false);
  const worth = (t: number) => -2 * lure[t] - (fear[t] < WARY ? (WARY - fear[t]) * 40 : 0);

  // Decide for the next tile middle the puffin reaches (the one it stands on, when it stands on one).
  const from = p.off > 0 ? neighbour(p.tile, p.dir) : p.tile;
  let best: Dir | -1 = -1, bestWorth = 0;
  for (let d = 0; d < 4; d++) {
    const n = neighbour(from, d as Dir);
    if (!walkable(tiles, n, false)) continue;
    const w = worth(n) - (d === opposite(p.dir) ? 3 : 0);
    if (best < 0 || w > bestWorth) { best = d as Dir; bestWorth = w; }
  }
  // Between two tiles with a hunter ahead, turning round now may be better than anything at the next middle.
  if (p.off > 0 && fear[from] < 4 && worth(p.tile) > bestWorth + 30) return opposite(p.dir);
  return best;
}
