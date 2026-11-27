// A burrow: the maze of one level, dug from a seed. Every seed gives a different maze, mirrored left to right,
// with no dead ends, the hunters' den in the middle and one tunnel that runs off both sides of the island.
import { Rng } from "./rng";
import { COLS, DEN, DOOR, DX, DY, Dir, PATH, ROWS, WALL } from "./rules";

export interface Maze {
  seed: number;
  /** One of WALL, PATH, DEN, DOOR for each tile, row by row. */
  tiles: Uint8Array;
  /** The tiles that start with a sand eel. */
  eels: number[];
  /** The four tiles that start with a tern's feather. */
  feathers: number[];
  /** The row whose tunnel leaves one side of the island and comes back on the other. */
  tunnelRow: number;
}

export const tileAt = (x: number, y: number): number => y * COLS + x;
export const tileX = (i: number): number => i % COLS;
export const tileY = (i: number): number => (i - (i % COLS)) / COLS;

/** The den's three tiles (its middle is where a routed hunter goes), its door, and the tile outside the door. */
export const DEN_TILES = [tileAt(9, 11), tileAt(10, 11), tileAt(11, 11)];
export const DEN_MIDDLE = tileAt(10, 11);
export const DOOR_TILE = tileAt(10, 10);
export const GATE_TILE = tileAt(10, 9);
/** Where the puffin starts. */
export const HOME_TILE = tileAt(10, 13);

/** The tile one step from `i`; off a side it comes back on the other, off the top or bottom there is none (-1). */
export function neighbour(i: number, d: Dir): number {
  const y = tileY(i) + DY[d];
  if (y < 0 || y >= ROWS) return -1;
  return tileAt((tileX(i) + DX[d] + COLS) % COLS, y);
}

/** Whether a tile can be walked: tunnels by everyone, the den and its door only by a hunter going in or out. */
export function walkable(tiles: Uint8Array, i: number, throughDen: boolean): boolean {
  if (i < 0) return false;
  const t = tiles[i];
  return t === PATH || (throughDen && (t === DEN || t === DOOR));
}

export const FAR = 9999;

/** How many tiles it is from each tile to the nearest of `from`, walking the tunnels (FAR where there is no way). */
export function distances(tiles: Uint8Array, from: number[], throughDen: boolean): Int16Array {
  const dist = new Int16Array(COLS * ROWS).fill(FAR);
  const queue: number[] = [];
  for (const f of from) if (dist[f] === FAR) { dist[f] = 0; queue.push(f); }
  for (let q = 0; q < queue.length; q++) {
    const i = queue[q];
    for (let d = 0; d < 4; d++) {
      const n = neighbour(i, d as Dir);
      if (walkable(tiles, n, throughDen) && dist[n] === FAR) { dist[n] = dist[i] + 1; queue.push(n); }
    }
  }
  return dist;
}

// The maze is dug on a grid of rooms two tiles apart (odd columns and rows), with the walls between them on the
// even ones. Only the left half is dug; the right half is its mirror image.
const HALF = 5, ROOM_ROWS = 11, AXIS = 10;
const isDen = (cx: number, cy: number) => cx === 4 && cy === 5;
const inHalf = (cx: number, cy: number) => cx >= 0 && cx < HALF && cy >= 0 && cy < ROOM_ROWS && !isDen(cx, cy);

export function buildMaze(seed: number): Maze {
  const rng = new Rng(seed);
  const tiles = new Uint8Array(COLS * ROWS).fill(WALL);
  const open = (x: number, y: number) => { tiles[tileAt(x, y)] = PATH; };

  // Every room of the left half, joined into one tree: grow from a random room, each time from the newest room
  // or from any room already dug, as a coin falls.
  const seen = new Uint8Array(HALF * ROOM_ROWS);
  const first = { cx: 0, cy: rng.int(ROOM_ROWS) };
  const active = [first];
  seen[first.cy * HALF + first.cx] = 1;
  open(1, 2 * first.cy + 1);
  while (active.length) {
    const at = rng.chance(0.5) ? active.length - 1 : rng.int(active.length);
    const { cx, cy } = active[at];
    const ways: number[] = [];
    for (let d = 0; d < 4; d++) if (inHalf(cx + DX[d], cy + DY[d]) && !seen[(cy + DY[d]) * HALF + cx + DX[d]]) ways.push(d);
    if (!ways.length) { active.splice(at, 1); continue; }
    const d = rng.pick(ways);
    const nx = cx + DX[d], ny = cy + DY[d];
    seen[ny * HALF + nx] = 1;
    open(2 * cx + 1 + DX[d], 2 * cy + 1 + DY[d]);
    open(2 * nx + 1, 2 * ny + 1);
    active.push({ cx: nx, cy: ny });
  }

  // A ring of tunnel around the den.
  open(8, 9); open(7, 10); open(7, 12); open(8, 13);

  // A few more walls knocked through, for loops.
  for (let cy = 0; cy < ROOM_ROWS; cy++) for (let cx = 0; cx < HALF; cx++) {
    if (!inHalf(cx, cy)) continue;
    if (inHalf(cx + 1, cy) && tiles[tileAt(2 * cx + 2, 2 * cy + 1)] === WALL && rng.chance(0.14)) open(2 * cx + 2, 2 * cy + 1);
    if (inHalf(cx, cy + 1) && tiles[tileAt(2 * cx + 1, 2 * cy + 2)] === WALL && rng.chance(0.14)) open(2 * cx + 1, 2 * cy + 2);
  }

  // Ways across the middle: always above and below the den, sometimes elsewhere.
  for (let cy = 0; cy < ROOM_ROWS; cy++) {
    if (cy === 5) continue;
    if (cy === 4 || cy === 6 || rng.chance(0.3)) open(AXIS, 2 * cy + 1);
  }

  // No dead ends: a room with one way out gets another.
  for (let changed = true; changed;) {
    changed = false;
    for (let cy = 0; cy < ROOM_ROWS; cy++) for (let cx = 0; cx < HALF; cx++) {
      if (!inHalf(cx, cy)) continue;
      const x = 2 * cx + 1, y = 2 * cy + 1;
      let exits = 0;
      const shut: number[] = [];
      for (let d = 0; d < 4; d++) {
        const across = cx === HALF - 1 && d === 1; // through the middle, to this room's mirror image
        if (!across && !inHalf(cx + DX[d], cy + DY[d])) continue;
        if (tiles[tileAt(x + DX[d], y + DY[d])] === PATH) exits++; else shut.push(d);
      }
      if (exits > 1 || !shut.length) continue;
      const d = rng.pick(shut);
      open(x + DX[d], y + DY[d]);
      changed = true;
    }
  }

  // The tunnel off the island's sides, away from the den's rows.
  const tunnelRow = 2 * rng.pick([1, 2, 3, 7, 8, 9]) + 1;
  open(0, tunnelRow);

  for (let y = 0; y < ROWS; y++) for (let x = 0; x < AXIS; x++) tiles[tileAt(COLS - 1 - x, y)] = tiles[tileAt(x, y)];
  for (const t of DEN_TILES) tiles[t] = DEN;
  tiles[DOOR_TILE] = DOOR;

  // A feather in each quarter of the island, in a different room each time.
  const top = { x: 2 * rng.int(3) + 1, y: 2 * rng.int(4) + 1 };
  const bottom = { x: 2 * rng.int(3) + 1, y: 2 * (7 + rng.int(4)) + 1 };
  const feathers = [tileAt(top.x, top.y), tileAt(COLS - 1 - top.x, top.y), tileAt(bottom.x, bottom.y), tileAt(COLS - 1 - bottom.x, bottom.y)];

  const eels: number[] = [];
  for (let i = 0; i < tiles.length; i++) if (tiles[i] === PATH && i !== HOME_TILE && !feathers.includes(i)) eels.push(i);
  return { seed, tiles, eels, feathers, tunnelRow };
}

/** The maze as text, for tests and for looking at: `#` turf, `.` tunnel, `D` den, `=` the den's door. */
export function drawMaze(m: Maze): string {
  let out = "";
  for (let y = 0; y < ROWS; y++) {
    for (let x = 0; x < COLS; x++) out += "#.D="[m.tiles[tileAt(x, y)]];
    out += "\n";
  }
  return out;
}
