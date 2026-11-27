// The game (src/engine/game.ts), played without a page: one step is a sixtieth of a second.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { autopilot } from "../src/engine/autopilot";
import { Game, GameEvent, Hunter, Input, NO_INPUT, nearTile, position } from "../src/engine/game";
import { DEN_MIDDLE, GATE_TILE, HOME_TILE, drawMaze, neighbour, tileAt, tileX, walkable } from "../src/engine/maze";
import {
  CAUGHT_STEPS, CLEAN_POINTS, CLEARED_STEPS, COLS, DEN_REST, DIVE_BONUS, DOWN, Dir, EEL_POINTS, EXTRA_AT, FEATHER_POINTS, FIRST_READY_STEPS, LEFT, MAX_LIVES,
  OVER_STEPS, PATH, READY_STEPS, RIGHT, ROUT_POINTS, START_LIVES, TOUCH, UNIT, UP, denWait, hunterSpeed, mobSteps, opposite, prowlSteps,
} from "../src/engine/rules";

const START: Input = { dir: -1, start: true, pause: false };
const point = (dir: Dir): Input => ({ dir, start: false, pause: false });

/** A game that has been started and counted in, ready for the first step of play. */
function started(seed = 7): Game {
  const g = new Game(seed);
  g.step(START);
  for (let i = 0; i < FIRST_READY_STEPS; i++) g.step(NO_INPUT);
  assert.equal(g.phase, "play");
  g.takeEvents();
  return g;
}
/** Keeps every hunter shut in the den, so a test can look at the puffin alone. */
function denned(g: Game): void {
  for (const h of g.hunters) { h.state = "den"; h.tile = DEN_MIDDLE; h.off = 0; h.wait = 1_000_000; }
}
function run(g: Game, steps: number, input: Input = NO_INPUT): GameEvent[] {
  const events: GameEvent[] = [];
  for (let i = 0; i < steps; i++) { g.step(input); events.push(...g.takeEvents()); }
  return events;
}
/** Puts a hunter on a tile of tunnel, out and hunting, facing a way. */
function place(h: Hunter, tile: number, dir: Dir): void {
  h.state = "out"; h.tile = tile; h.dir = dir; h.off = 0; h.hunting = true; h.mood = 1_000_000; h.wait = 0;
}

test("a game waits on the title screen, counts in, and then plays", () => {
  const g = new Game(1);
  run(g, 100);
  assert.equal(g.phase, "attract");
  g.step(START);
  assert.equal(g.phase, "ready");
  assert.deepEqual(g.takeEvents(), ["start"]);
  assert.equal(g.lives, START_LIVES);
  assert.equal(g.level, 1);
  run(g, FIRST_READY_STEPS - 1);
  assert.equal(g.phase, "ready");
  g.step(NO_INPUT);
  assert.equal(g.phase, "play");
  assert.equal(g.puffin.tile, HOME_TILE);
  assert.deepEqual(g.hunters.map((h) => `${h.kind}:${h.state}`), ["fox:out", "mink:den", "skua:den", "raven:den"]);
  assert.equal(g.hunters[0].tile, GATE_TILE);
});

test("the puffin stands until it is pointed somewhere, then runs a tile every ten steps and eats what it finds", () => {
  const g = started();
  denned(g);
  run(g, 30);
  assert.equal(g.puffin.tile, HOME_TILE);
  assert.equal(g.puffin.moving, false);
  // Left of home is always tunnel (the ring round the den).
  g.step(point(LEFT));
  assert.equal(g.puffin.moving, true);
  assert.equal(g.puffin.off, 100);
  const events = run(g, 9);
  assert.equal(g.puffin.tile, HOME_TILE - 1);
  assert.equal(g.puffin.off, 0);
  assert.deepEqual(events, ["eel"]);
  assert.equal(g.score, EEL_POINTS);
  assert.equal(g.eels[HOME_TILE - 1], 0);
  assert.equal(g.eelsLeft, g.maze.eels.length - 1);
});

test("it turns where the player last pointed as soon as there is a tunnel that way, and stops at turf", () => {
  const g = started();
  denned(g);
  // Below home is turf on some burrows and tunnel on others; up is always turf (the den's wall).
  g.step(point(UP));
  run(g, 20);
  assert.equal(g.puffin.tile, HOME_TILE, "no tunnel up from home");
  g.step(point(RIGHT));
  run(g, 5);
  // Between two tiles, pointing back turns it round on the spot.
  assert.equal(g.puffin.off, 600);
  g.step(point(LEFT));
  assert.equal(g.puffin.dir, LEFT);
  assert.equal(g.puffin.tile, HOME_TILE + 1);
  assert.equal(g.puffin.off, 500);
  run(g, 5);
  assert.equal(g.puffin.tile, HOME_TILE);
  // Carry on left along the ring to its corner at column 7, pointing up all the way: it takes the first tunnel up it meets.
  g.step(point(UP));
  run(g, 200);
  assert.equal(g.puffin.moving, false, "it ran until turf stopped it");
  assert.ok(!walkable(g.maze.tiles, neighbour(g.puffin.tile, g.puffin.dir), false));
  assert.equal(g.maze.tiles[g.puffin.tile], PATH);
});

test("the tunnel off one side of the island comes back on the other", () => {
  const g = started();
  denned(g);
  const row = g.maze.tunnelRow;
  g.puffin.tile = tileAt(1, row);
  g.puffin.off = 0;
  g.step(point(LEFT));
  run(g, 9);
  assert.equal(g.puffin.tile, tileAt(0, row));
  run(g, 10);
  assert.equal(g.puffin.tile, tileAt(COLS - 1, row));
  assert.equal(position(g.puffin).x, (COLS - 1) * UNIT);
});

test("the same seed and the same controls give the same game", () => {
  const play = () => {
    const g = new Game(2024);
    g.step(START);
    const trace: string[] = [];
    for (let i = 0; i < 6000 && g.phase !== "attract"; i++) {
      g.step(point(autopilot(g) as Dir));
      if (i % 200 === 0) trace.push(`${g.score}/${g.lives}/${g.puffin.tile}/${g.hunters.map((h) => h.tile).join(",")}`);
    }
    return trace.join(" ") + drawMaze(g.maze);
  };
  assert.equal(play(), play());
  const other = new Game(2025);
  other.step(START);
  assert.notEqual(drawMaze(other.maze), drawMaze(started(2024).maze));
});

test("hunters keep to the tunnels, leave the den in turn, and never turn back on their own", () => {
  const g = started(11);
  const out: Record<string, number> = {};
  let before = g.hunters.map((h) => ({ tile: h.tile, dir: h.dir, state: h.state }));
  for (let i = 0; i < 1500 && g.phase === "play"; i++) {
    // The puffin runs away from everything, so the hunters have long to live.
    g.step(point(autopilot(g) as Dir));
    g.hunters.forEach((h, k) => {
      assert.ok(walkable(g.maze.tiles, h.tile, h.state !== "out" && h.state !== "mobbed"), `${h.kind} on tile ${h.tile} while ${h.state}`);
      if (h.state === "out" && out[h.kind] === undefined) out[h.kind] = i;
      const was = before[k];
      if (was.state === "out" && h.state === "out" && h.tile === was.tile) assert.notEqual(h.dir, opposite(was.dir), `${h.kind} turned back at step ${i}`);
    });
    before = g.hunters.map((h) => ({ tile: h.tile, dir: h.dir, state: h.state }));
  }
  if (out.raven !== undefined) assert.ok(out.fox < out.mink && out.mink < out.skua && out.skua < out.raven, JSON.stringify(out));
  assert.equal(out.fox, 0);
  assert.ok(out.mink >= denWait("mink", 1));
});

test("the mink takes the shortest way to the puffin and catches one that stands still", () => {
  const g = started(3);
  denned(g);
  place(g.hunters[1], GATE_TILE, LEFT);
  let steps = 0;
  while (!run(g, 1).includes("caught")) assert.ok(++steps < 600, "the mink never came");
  assert.equal(g.lives, START_LIVES - 1);
  // From the gate, half way round the den's ring to home, is 10 tiles; the mink is there when it comes within reach.
  const expected = (10 * UNIT - TOUCH) / hunterSpeed("mink", 1);
  assert.ok(Math.abs(steps - expected) < 3, `${steps} steps, expected about ${expected}`);
});

test("the fox follows the puffin's scent where the mink takes the shortest way", () => {
  // The puffin goes from home the long way round the den's ring: left, up its side, along the top and down the far side.
  const trail = (): Game => {
    const g = started(5);
    denned(g);
    for (const [dir, steps] of [[LEFT, 30], [UP, 40], [RIGHT, 60], [DOWN, 20]] as [Dir, number][]) { g.step(point(dir)); run(g, steps - 1); }
    assert.equal(g.puffin.tile, tileAt(13, 11));
    assert.equal(g.puffin.off, 0);
    g.puffin.moving = false;
    g.puffin.want = -1;
    return g;
  };
  /** Stands a hunter on the puffin's starting tile, free to go left (along the trail) or right (the short way). */
  const firstTiles = (g: Game, h: Hunter): number[] => {
    place(h, HOME_TILE, UP);
    const walked: number[] = [];
    for (let i = 0; i < 400 && g.phase === "play"; i++) {
      g.step(NO_INPUT);
      if (h.tile !== (walked.length ? walked[walked.length - 1] : HOME_TILE)) walked.push(h.tile);
    }
    assert.equal(g.phase, "caught");
    return walked;
  };
  const a = trail(), b = trail();
  assert.deepEqual(firstTiles(a, a.hunters[0]).slice(0, 5), [HOME_TILE - 1, HOME_TILE - 2, tileAt(7, 13), tileAt(7, 12), tileAt(7, 11)]);
  assert.deepEqual(firstTiles(b, b.hunters[1]).slice(0, 4), [HOME_TILE + 1, HOME_TILE + 2, tileAt(13, 13), tileAt(13, 12)]);
});

test("the raven wanders until it sees the puffin down a straight tunnel, then dives, faster", () => {
  const g = started(9);
  denned(g);
  const raven = g.hunters[3];
  // The ring's bottom row is straight from column 7 to column 13; the puffin stands at home in the middle of it.
  place(raven, tileAt(13, 13), UP);
  raven.dir = LEFT;
  const events = run(g, 1);
  assert.deepEqual(events, ["dive"]);
  assert.ok(raven.dive > 0);
  assert.equal(raven.dir, LEFT);
  const off = raven.off;
  run(g, 1);
  assert.equal(raven.off - off, hunterSpeed("raven", 1) + DIVE_BONUS);
  assert.ok(run(g, 120).includes("caught"));
});

test("a feather brings the terns: hunters out in the tunnels turn tail, and the puffin routs the ones it touches", () => {
  const g = started(13);
  denned(g);
  const [fox, mink] = g.hunters;
  const feather = g.maze.feathers[0];
  // The puffin stands one tile from a feather, with the fox and the mink two tiles behind it, out of reach.
  const beside = (tile: number, not: number): number => {
    for (let d = 0; d < 4; d++) { const n = neighbour(tile, d as Dir); if (n !== not && walkable(g.maze.tiles, n, false)) return d; }
    throw new Error("a dead end");
  };
  const way = beside(feather, -1) as Dir;
  const from = neighbour(feather, way);
  const behind = neighbour(from, beside(from, feather) as Dir);
  const further = neighbour(behind, beside(behind, from) as Dir);
  g.puffin.tile = from;
  place(fox, further, UP);
  place(mink, further, UP);
  const toFeather = opposite(way);
  const before = g.score;
  g.step(point(toFeather));
  const events = run(g, 9);
  assert.ok(events.includes("feather"), events.join());
  assert.equal(g.mob > 0 && g.mob <= mobSteps(1), true);
  assert.equal(fox.state, "mobbed");
  assert.equal(mink.state, "mobbed");
  assert.equal(g.hunters[2].state, "den", "a hunter in the den is left alone");
  assert.ok(g.score - before >= FEATHER_POINTS);

  // Put both mobbed hunters under the puffin's beak, one after the other.
  const score = g.score;
  fox.tile = g.puffin.tile; fox.off = g.puffin.off; fox.dir = g.puffin.dir;
  let ev = run(g, 1);
  assert.ok(ev.includes("rout"));
  assert.equal(fox.state, "routed");
  run(g, 30); // the game stands still a moment
  mink.tile = g.puffin.tile; mink.off = g.puffin.off; mink.dir = g.puffin.dir;
  ev = run(g, 2);
  assert.ok(ev.includes("rout"));
  const eelsMeanwhile = (g.score - score - ROUT_POINTS - 2 * ROUT_POINTS) / EEL_POINTS;
  assert.ok(Number.isInteger(eelsMeanwhile) && eelsMeanwhile >= 0 && eelsMeanwhile < 6, `first rout ${ROUT_POINTS}, second ${2 * ROUT_POINTS}`);
  assert.equal(g.lives, START_LIVES);

  // A routed hunter runs home, rests, and comes out again as itself.
  let home = -1, back = -1;
  g.puffin.moving = false;
  for (let i = 0; i < 3000 && back < 0; i++) {
    g.puffin.want = -1;
    if (g.phase !== "play") break;
    g.step(NO_INPUT);
    if (home < 0 && fox.state === "den") { home = i; assert.equal(fox.tile, DEN_MIDDLE); assert.equal(fox.wait, DEN_REST); }
    if (home >= 0 && fox.state === "out") back = i;
  }
  assert.ok(home >= 0, "the fox reached the den");
  if (g.phase === "play") assert.ok(back > home + DEN_REST, "and came out again after its rest");
});

test("when the terns leave, mobbed hunters hunt again", () => {
  const g = started(21);
  denned(g);
  const fox = g.hunters[0];
  place(fox, tileAt(1, 1), DOWN);
  fox.state = "mobbed";
  g.mob = 3;
  const events = run(g, 3);
  assert.ok(events.includes("mobEnd"));
  assert.equal(fox.state, "out");
  assert.equal(g.mob, 0);
});

test("a mobbed hunter runs away from the puffin", () => {
  const g = started(23);
  denned(g);
  const mink = g.hunters[1];
  place(mink, tileAt(7, 13), RIGHT);
  mink.state = "mobbed";
  g.mob = 600;
  const gap = () => Math.abs(position(mink).x - position(g.puffin).x) + Math.abs(position(mink).y - position(g.puffin).y);
  const before = gap();
  run(g, 120);
  assert.equal(g.phase, "play");
  assert.ok(gap() > before, `${before} -> ${gap()}`);
});

test("a caught puffin costs a life; the eels stay eaten; three and the game is over", () => {
  const g = started(31);
  denned(g);
  g.step(point(LEFT));
  run(g, 19);
  const left = g.eelsLeft;
  assert.equal(left, g.maze.eels.length - 2);
  for (let life = START_LIVES; life > 0; life--) {
    assert.equal(g.lives, life);
    const fox = g.hunters[0]; // each life has its own hunters
    place(fox, nearTile(g.puffin), LEFT);
    fox.tile = g.puffin.tile; fox.off = g.puffin.off; fox.dir = g.puffin.dir;
    const events = run(g, 1);
    assert.ok(events.includes("caught"), `life ${life}`);
    assert.equal(g.phase, "caught");
    assert.equal(g.clean, false);
    const after = run(g, CAUGHT_STEPS);
    if (life > 1) {
      assert.equal(g.phase, "ready");
      assert.ok(after.includes("ready"));
      assert.equal(g.puffin.tile, HOME_TILE);
      assert.equal(g.eelsLeft, left);
      run(g, READY_STEPS);
      assert.equal(g.phase, "play");
      denned(g);
    } else {
      assert.equal(g.phase, "over");
      assert.ok(after.includes("over"));
    }
  }
  assert.equal(g.best, g.score);
  run(g, OVER_STEPS);
  assert.equal(g.phase, "attract");
});

test("eating every eel clears the burrow: a bonus for a clean run, then a new burrow, harder", () => {
  const g = started(41);
  const first = drawMaze(g.maze);
  const total = g.maze.eels.length;
  const events: GameEvent[] = [];
  for (let i = 0; i < 60 * 240 && g.phase === "play"; i++) {
    denned(g);
    g.step(point(autopilot(g) as Dir));
    events.push(...g.takeEvents());
  }
  assert.equal(g.phase, "cleared");
  assert.equal(g.eelsLeft, 0);
  assert.equal(events.filter((e) => e === "eel").length, total);
  assert.equal(events.filter((e) => e === "treatShown").length, 2);
  assert.ok(events.includes("clear"));
  assert.ok(g.clean);
  const treats = events.filter((e) => e === "treat").length, feathers = events.filter((e) => e === "feather").length;
  assert.equal(g.score, total * EEL_POINTS + feathers * FEATHER_POINTS + treats * 100 + CLEAN_POINTS);
  run(g, CLEARED_STEPS + READY_STEPS);
  assert.equal(g.phase, "play");
  assert.equal(g.level, 2);
  assert.notEqual(drawMaze(g.maze), first);
  assert.equal(g.eelsLeft, g.maze.eels.length);
  assert.ok(hunterSpeed("fox", 2) > hunterSpeed("fox", 1));
  assert.ok(mobSteps(2) < mobSteps(1));
  assert.ok(prowlSteps("mink", 2) < prowlSteps("mink", 1));
  assert.ok(denWait("raven", 2) < denWait("raven", 1));
});

test("an extra puffin at 4000 points, and never more than five", () => {
  const g = started(51);
  denned(g);
  g.score = EXTRA_AT - EEL_POINTS;
  g.step(point(LEFT));
  const events = run(g, 9);
  assert.ok(events.includes("extra"));
  assert.equal(g.lives, START_LIVES + 1);
  g.lives = MAX_LIVES;
  g.score = 1_000_000;
  run(g, 10);
  assert.equal(g.lives, MAX_LIVES);
});

test("pause stops everything until it is pressed again", () => {
  const g = started(61);
  denned(g);
  g.step(point(LEFT));
  g.step({ dir: -1, start: false, pause: true });
  assert.equal(g.paused, true);
  const at = { ...g.puffin }, frame = g.frame;
  run(g, 100);
  assert.deepEqual({ ...g.puffin }, at);
  assert.equal(g.frame, frame);
  g.step({ dir: -1, start: false, pause: true });
  assert.equal(g.paused, false);
  assert.notEqual(g.puffin.off, at.off);
});

test("the demo plays by itself, scores nothing towards the best, and gives way to a real game", () => {
  const g = new Game(71);
  g.best = 123;
  g.newGame(true);
  assert.equal(g.demo, true);
  let steps = 0;
  while (g.phase !== "attract" && steps < 60 * 600) { g.step(point(autopilot(g) as Dir)); steps++; }
  assert.equal(g.phase, "attract", "the demo ends when the puffin is caught or the burrow is cleared");
  assert.equal(g.demo, false);
  assert.equal(g.best, 123);
  g.newGame(true);
  run(g, 300, NO_INPUT);
  g.step(START);
  assert.equal(g.demo, false);
  assert.equal(g.phase, "ready");
  assert.equal(g.score, 0);
  assert.equal(tileX(g.puffin.tile), 10);
});
