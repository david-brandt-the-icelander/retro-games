// The burrows (src/engine/maze.ts): whatever the seed, a maze the game can be played on.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { DEN_TILES, DOOR_TILE, FAR, GATE_TILE, HOME_TILE, buildMaze, distances, drawMaze, neighbour, tileAt, tileX, tileY } from "../src/engine/maze";
import { COLS, DEN, DOOR, Dir, PATH, ROWS, WALL } from "../src/engine/rules";

const SEEDS = Array.from({ length: 300 }, (_, i) => (i * 2654435761 + 17) >>> 0);

test("the same seed digs the same burrow, and different seeds dig different ones", () => {
  assert.equal(drawMaze(buildMaze(42)), drawMaze(buildMaze(42)));
  const drawn = new Set(SEEDS.map((s) => drawMaze(buildMaze(s))));
  assert.ok(drawn.size > SEEDS.length * 0.98, `${drawn.size} different mazes from ${SEEDS.length} seeds`);
});

test("every burrow is a mirror image of itself, left to right", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    for (let y = 0; y < ROWS; y++) for (let x = 0; x < COLS; x++) assert.equal(m.tiles[tileAt(x, y)], m.tiles[tileAt(COLS - 1 - x, y)], `seed ${s} at ${x},${y}`);
  }
});

test("every tunnel can be reached from where the puffin starts, and none is a dead end", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    const from = distances(m.tiles, [HOME_TILE], false);
    for (let i = 0; i < m.tiles.length; i++) {
      if (m.tiles[i] !== PATH) continue;
      assert.ok(from[i] < FAR, `seed ${s}: tile ${i} is cut off`);
      let ways = 0;
      for (let d = 0; d < 4; d++) { const n = neighbour(i, d as Dir); if (n >= 0 && m.tiles[n] === PATH) ways++; }
      assert.ok(ways >= 2, `seed ${s}: tile ${tileX(i)},${tileY(i)} is a dead end\n${drawMaze(m)}`);
    }
  }
});

test("the den is three tiles shut in by turf, with one door up to the tunnel above it", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    for (const t of DEN_TILES) assert.equal(m.tiles[t], DEN);
    assert.equal(m.tiles[DOOR_TILE], DOOR);
    assert.equal(m.tiles[GATE_TILE], PATH);
    assert.equal(m.tiles[HOME_TILE], PATH);
    for (const [x, y] of [[8, 10], [9, 10], [11, 10], [12, 10], [8, 11], [12, 11], [8, 12], [9, 12], [10, 12], [11, 12], [12, 12]]) {
      assert.equal(m.tiles[tileAt(x, y)], WALL, `seed ${s}: ${x},${y}`);
    }
    // The puffin can't get in: without the door, the den is nowhere.
    assert.equal(distances(m.tiles, [HOME_TILE], false)[DEN_TILES[1]], FAR);
    assert.ok(distances(m.tiles, [GATE_TILE], true)[DEN_TILES[0]] < FAR);
  }
});

test("one tunnel runs off both sides of the island, and the rest of the edge is turf", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    for (let y = 0; y < ROWS; y++) {
      assert.equal(m.tiles[tileAt(0, y)], y === m.tunnelRow ? PATH : WALL, `seed ${s} row ${y}`);
      assert.equal(m.tiles[tileAt(COLS - 1, y)], y === m.tunnelRow ? PATH : WALL);
    }
    for (let x = 0; x < COLS; x++) { assert.equal(m.tiles[tileAt(x, 0)], WALL); assert.equal(m.tiles[tileAt(x, ROWS - 1)], WALL); }
    assert.equal(neighbour(tileAt(0, m.tunnelRow), 3), tileAt(COLS - 1, m.tunnelRow));
    assert.equal(neighbour(tileAt(COLS - 1, m.tunnelRow), 1), tileAt(0, m.tunnelRow));
  }
  assert.equal(neighbour(tileAt(5, 0), 0), -1);
  assert.equal(neighbour(tileAt(5, ROWS - 1), 2), -1);
});

test("tunnels are one tile wide: no four tunnel tiles make a square", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    for (let y = 0; y < ROWS - 1; y++) for (let x = 0; x < COLS - 1; x++) {
      const square = [tileAt(x, y), tileAt(x + 1, y), tileAt(x, y + 1), tileAt(x + 1, y + 1)].every((t) => m.tiles[t] === PATH);
      assert.ok(!square, `seed ${s}: open square at ${x},${y}`);
    }
  }
});

test("four feathers, one in each quarter, and a sand eel on every other tunnel tile but the puffin's own", () => {
  for (const s of SEEDS) {
    const m = buildMaze(s);
    assert.equal(new Set(m.feathers).size, 4);
    const quarters = new Set(m.feathers.map((t) => `${tileX(t) < 10}${tileY(t) < 11}`));
    assert.equal(quarters.size, 4, `seed ${s}`);
    for (const t of m.feathers) { assert.equal(m.tiles[t], PATH); assert.ok(!m.eels.includes(t)); }
    assert.ok(!m.eels.includes(HOME_TILE));
    let tunnels = 0;
    for (const t of m.tiles) if (t === PATH) tunnels++;
    assert.equal(m.eels.length, tunnels - 5);
    assert.ok(m.eels.length >= 200 && m.eels.length <= 270, `seed ${s}: ${m.eels.length} eels`);
  }
});
