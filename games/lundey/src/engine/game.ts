// The game itself, with no page and no clock: `step` moves everything on by one sixtieth of a second, given the
// player's controls. The same seed and the same controls always give the same game, so tests can play it.
import {
  FAR, Maze, DEN_MIDDLE, DEN_TILES, GATE_TILE, HOME_TILE, buildMaze, distances, neighbour, tileX, tileY, walkable,
} from "./maze";
import { Rng } from "./rng";
import {
  CAUGHT_STEPS, CLEAN_POINTS, CLEARED_STEPS, COLS, DEN_REST, DIVE_BONUS, DIVE_REST, DIVE_STEPS, DX, DY, Dir, EEL_POINTS,
  EXTRA_AT, EXTRA_EVERY, FEATHER_POINTS, FIRST_READY_STEPS, HIT_STOP, HUNT_STEPS, HunterKind, KINDS, LEAVING_SPEED, LEFT,
  MAX_LIVES, MOBBED_SPEED, OVER_STEPS, PATH, POPUP_STEPS, PUFFIN_SPEED, READY_STEPS, ROUTED_SPEED, ROUT_POINTS, SCENT_STEPS,
  SKUA_CLOSE, SKUA_MEAL_MIN, START_LIVES, TOUCH, TREAT_AT_TENTHS, TREAT_POINTS, TREAT_STEPS, UNIT, UP, denWait, hunterSpeed,
  mobSteps, opposite, prowlSteps, treatFor,
} from "./rules";

/** Where the game is: on the title screen, counting in, being played, a puffin just caught, a burrow just cleared, or over. */
export type Phase = "attract" | "ready" | "play" | "caught" | "cleared" | "over";

/** One step's controls: the way the player last pointed (-1 for none), and whether start or pause was pressed. */
export interface Input { dir: Dir | -1; start: boolean; pause: boolean }
export const NO_INPUT: Input = { dir: -1, start: false, pause: false };

/** Things that happened in a step, for the page to make a sound of. */
export type GameEvent =
  | "start" | "ready" | "eel" | "feather" | "rout" | "mobEnd" | "dive" | "treatShown" | "treat" | "extra" | "caught" | "clear" | "over" | "pause";

/** Anything that walks the tunnels: at the middle of `tile` when `off` is 0, else `off` thousandths of the way to the next tile along `dir`. */
export interface Mover { tile: number; dir: Dir; off: number }
export interface Puffin extends Mover { want: Dir | -1; moving: boolean }
/** In the den, on the way out of it, out in the tunnels, mobbed by terns, or routed and running home. */
export type HunterState = "den" | "leaving" | "out" | "mobbed" | "routed";
export interface Hunter extends Mover {
  kind: HunterKind;
  state: HunterState;
  /** Steps left to wait in the den. */
  wait: number;
  /** Out in the tunnels a hunter hunts or prowls in turn; `mood` is how long until it changes. */
  hunting: boolean;
  mood: number;
  /** The raven: steps left of a dive, and steps until it can dive again. */
  dive: number;
  diveRest: number;
}
export interface Popup { x: number; y: number; points: number; steps: number }

/** Where a mover is, in thousandths of a tile from the middle of the top-left tile. */
export function position(m: Mover): { x: number; y: number } {
  return { x: tileX(m.tile) * UNIT + DX[m.dir] * m.off, y: tileY(m.tile) * UNIT + DY[m.dir] * m.off };
}
/** The tile a mover is nearest to. */
export const nearTile = (m: Mover): number => (m.off * 2 >= UNIT ? neighbour(m.tile, m.dir) : m.tile);

export class Game {
  phase: Phase = "attract";
  paused = false;
  /** A game the computer plays for the title screen: it scores nothing and ends when the puffin is caught. */
  demo = false;
  /** Steps taken, for animation. Stands still while paused. */
  frame = 0;
  score = 0;
  best = 0;
  lives = 0;
  level = 1;
  maze: Maze;
  /** 1 for each tile that still has its sand eel, and each that still has its feather. */
  eels = new Uint8Array(0);
  feathers = new Uint8Array(0);
  eelsLeft = 0;
  eaten = 0;
  puffin: Puffin = { tile: HOME_TILE, dir: LEFT, off: 0, want: -1, moving: false };
  hunters: Hunter[] = [];
  /** Steps the terns will go on mobbing the hunters, and how many hunters this feather has routed. */
  mob = 0;
  chain = 0;
  treat: { tile: number; steps: number } | null = null;
  popups: Popup[] = [];
  /** Steps left of the current phase (not of play, which lasts until the eels are gone or the puffin is caught). */
  timer = 0;
  /** True until a puffin is lost on this burrow. */
  clean = true;

  private rng: Rng;
  private base = 0;
  private clock = 0;
  /** For each tile, the `clock` when the puffin was last there (0 for never). */
  private scent = new Int32Array(0);
  private treatsShown = 0;
  private nextExtra = EXTRA_AT;
  private hitStop = 0;
  private events: GameEvent[] = [];
  private toGate: Int16Array = new Int16Array(0);
  private toDen: Int16Array = new Int16Array(0);
  private toPuffin: Int16Array | null = null;

  constructor(seed: number) {
    this.rng = new Rng(seed);
    this.maze = buildMaze(seed);
    this.loadLevel();
  }

  /** The events since the last call. */
  takeEvents(): GameEvent[] { const e = this.events; this.events = []; return e; }

  newGame(demo = false): void {
    this.demo = demo;
    this.paused = false;
    this.score = 0;
    this.lives = START_LIVES;
    this.level = 1;
    this.nextExtra = EXTRA_AT;
    this.base = this.rng.int(4294967296);
    this.loadLevel();
    this.phase = "ready";
    this.timer = FIRST_READY_STEPS;
    this.emit("start");
  }

  step(input: Input): void {
    if (this.phase === "attract") { this.frame++; if (input.start) this.newGame(); return; }
    if (this.demo && input.start) { this.newGame(); return; }
    if (input.pause && !this.demo && (this.phase === "ready" || this.phase === "play")) { this.paused = !this.paused; this.emit("pause"); }
    if (this.paused) return;
    this.frame++;
    switch (this.phase) {
      case "ready":
        if (input.dir >= 0) this.puffin.want = input.dir;
        if (--this.timer <= 0) this.phase = "play";
        return;
      case "play":
        return this.play(input);
      case "caught":
        if (--this.timer > 0) return;
        if (this.demo) { this.demo = false; this.phase = "attract"; return; }
        if (this.lives <= 0) { this.phase = "over"; this.timer = OVER_STEPS; this.emit("over"); return; }
        this.resetActors();
        this.phase = "ready";
        this.timer = READY_STEPS;
        this.emit("ready");
        return;
      case "cleared":
        if (--this.timer > 0) return;
        if (this.demo) { this.demo = false; this.phase = "attract"; return; }
        this.level++;
        this.loadLevel();
        this.phase = "ready";
        this.timer = READY_STEPS;
        this.emit("ready");
        return;
      case "over":
        this.timer--;
        if (input.start && this.timer < OVER_STEPS - 45) this.newGame();
        else if (this.timer <= 0) this.phase = "attract";
        return;
    }
  }

  /** The burrow of the current level, dug from the game's seed, with everyone at their starting places. */
  private loadLevel(): void {
    this.maze = buildMaze((this.base + Math.imul(this.level, 2654435761)) >>> 0);
    this.eels = new Uint8Array(this.maze.tiles.length);
    this.feathers = new Uint8Array(this.maze.tiles.length);
    for (const t of this.maze.eels) this.eels[t] = 1;
    for (const t of this.maze.feathers) this.feathers[t] = 1;
    this.eelsLeft = this.maze.eels.length;
    this.eaten = 0;
    this.treatsShown = 0;
    this.clean = true;
    this.scent = new Int32Array(this.maze.tiles.length);
    this.toGate = distances(this.maze.tiles, [GATE_TILE], true);
    this.toDen = distances(this.maze.tiles, [DEN_MIDDLE], true);
    this.resetActors();
  }

  /** Puffin and hunters back where a burrow starts; the eels stay as they are. */
  private resetActors(): void {
    this.puffin = { tile: HOME_TILE, dir: LEFT, off: 0, want: -1, moving: false };
    const starts: Record<HunterKind, number> = { fox: GATE_TILE, mink: DEN_MIDDLE, skua: DEN_TILES[0], raven: DEN_TILES[2] };
    this.hunters = KINDS.map((kind) => ({
      kind, tile: starts[kind], dir: kind === "fox" ? LEFT : UP, off: 0,
      state: kind === "fox" ? "out" : "den", wait: denWait(kind, this.level),
      hunting: true, mood: HUNT_STEPS[kind], dive: 0, diveRest: 0,
    }));
    this.mob = 0;
    this.chain = 0;
    this.treat = null;
    this.popups = [];
    this.hitStop = 0;
    this.scent.fill(0);
    this.toPuffin = null;
  }

  private emit(e: GameEvent): void { this.events.push(e); }

  private add(points: number): void {
    this.score += points;
    if (!this.demo && this.score > this.best) this.best = this.score;
    while (this.score >= this.nextExtra) {
      this.nextExtra += EXTRA_EVERY;
      if (this.lives < MAX_LIVES && !this.demo) { this.lives++; this.emit("extra"); }
    }
  }

  private play(input: Input): void {
    if (input.dir >= 0) this.puffin.want = input.dir;
    for (const p of this.popups) p.steps--;
    this.popups = this.popups.filter((p) => p.steps > 0);
    if (this.hitStop > 0) { this.hitStop--; return; }
    this.clock++;
    this.toPuffin = null;
    this.movePuffin();
    if (this.phase !== "play") return;
    if (this.mob > 0 && --this.mob === 0) {
      for (const h of this.hunters) if (h.state === "mobbed") h.state = "out";
      this.emit("mobEnd");
    }
    this.toPuffin = null;
    for (const h of this.hunters) this.moveHunter(h);
    this.touch();
    if (this.treat && --this.treat.steps <= 0) this.treat = null;
  }

  private open(tile: number, d: Dir): boolean { return walkable(this.maze.tiles, neighbour(tile, d), false); }

  /** A mover between two tiles turns round where it stands. */
  private turnBack(m: Mover): void {
    if (m.off === 0) return;
    m.tile = neighbour(m.tile, m.dir);
    m.dir = opposite(m.dir);
    m.off = UNIT - m.off;
  }

  private movePuffin(): void {
    const p = this.puffin;
    if (p.off > 0 && p.want === opposite(p.dir)) this.turnBack(p);
    let left = PUFFIN_SPEED;
    while (left > 0) {
      if (p.off === 0) {
        // At the middle of a tile: turn the way the player wants if there is a tunnel there, else carry straight on, else stop.
        if (p.want >= 0 && this.open(p.tile, p.want as Dir)) { p.dir = p.want as Dir; p.moving = true; }
        else if (!p.moving || !this.open(p.tile, p.dir)) { p.moving = false; return; }
      }
      const go = Math.min(left, UNIT - p.off);
      p.off += go;
      left -= go;
      if (p.off === UNIT) {
        p.off = 0;
        p.tile = neighbour(p.tile, p.dir);
        this.puffinArrives(p.tile);
        if (this.phase !== "play") return;
      }
    }
  }

  private puffinArrives(tile: number): void {
    this.scent[tile] = this.clock;
    if (this.treat && this.treat.tile === tile) {
      const points = TREAT_POINTS[treatFor(this.level)];
      this.popup(tile, points);
      this.treat = null;
      this.add(points);
      this.emit("treat");
    }
    if (this.feathers[tile]) {
      this.feathers[tile] = 0;
      this.add(FEATHER_POINTS);
      this.mob = mobSteps(this.level);
      this.chain = 0;
      for (const h of this.hunters) if (h.state === "out") { h.state = "mobbed"; h.dive = 0; this.turnBack(h); }
      this.emit("feather");
    }
    if (this.eels[tile]) {
      this.eels[tile] = 0;
      this.eelsLeft--;
      this.eaten++;
      this.add(EEL_POINTS);
      this.emit("eel");
      const total = this.maze.eels.length;
      if (this.treatsShown < TREAT_AT_TENTHS.length && this.eaten === Math.floor((total * TREAT_AT_TENTHS[this.treatsShown]) / 10)) this.showTreat();
      if (this.eelsLeft === 0) {
        if (this.clean) { this.add(CLEAN_POINTS); this.popup(tile, CLEAN_POINTS); }
        this.phase = "cleared";
        this.timer = CLEARED_STEPS;
        this.emit("clear");
      }
    }
  }

  /** A treat washes up in a tunnel the puffin has emptied, not too near it. */
  private showTreat(): void {
    const from = this.puffinField();
    const spots: number[] = [];
    for (let i = 0; i < this.maze.tiles.length; i++) {
      if (this.maze.tiles[i] === PATH && !this.eels[i] && !this.feathers[i] && from[i] >= 6 && from[i] < FAR) spots.push(i);
    }
    this.treat = { tile: spots.length ? this.rng.pick(spots) : HOME_TILE, steps: TREAT_STEPS };
    this.treatsShown++;
    this.emit("treatShown");
  }

  private popup(tile: number, points: number): void {
    this.popups.push({ x: tileX(tile) * UNIT, y: tileY(tile) * UNIT, points, steps: POPUP_STEPS });
  }

  /** How far every tile is from the puffin, worked out at most once a step. */
  private puffinField(): Int16Array {
    return (this.toPuffin ??= distances(this.maze.tiles, [nearTile(this.puffin)], false));
  }

  private speedOf(h: Hunter): number {
    switch (h.state) {
      case "den": return 0;
      case "leaving": return LEAVING_SPEED;
      case "routed": return ROUTED_SPEED;
      case "mobbed": return MOBBED_SPEED;
      case "out": return hunterSpeed(h.kind, this.level) + (h.dive > 0 ? DIVE_BONUS : 0);
    }
  }

  private moveHunter(h: Hunter): void {
    if (h.state === "den") {
      if (--h.wait > 0) return;
      h.state = "leaving";
    }
    if (h.state === "out") {
      if (h.kind === "raven") {
        if (h.dive > 0) { if (--h.dive === 0) h.diveRest = DIVE_REST; }
        else if (h.diveRest > 0) h.diveRest--;
      } else if (--h.mood <= 0) {
        h.hunting = !h.hunting;
        h.mood = h.hunting ? HUNT_STEPS[h.kind] : prowlSteps(h.kind, this.level);
      }
    }
    let left = this.speedOf(h);
    while (left > 0) {
      if (h.off === 0) h.dir = this.choose(h);
      const go = Math.min(left, UNIT - h.off);
      h.off += go;
      left -= go;
      if (h.off < UNIT) return;
      h.off = 0;
      h.tile = neighbour(h.tile, h.dir);
      if (h.state === "leaving" && h.tile === GATE_TILE) h.state = "out";
      else if (h.state === "routed" && h.tile === DEN_MIDDLE) { h.state = "den"; h.wait = DEN_REST; h.dir = UP; return; }
    }
  }

  /** Which way a hunter at the middle of a tile goes next. It never turns back unless there is no other way. */
  private choose(h: Hunter): Dir {
    const tiles = this.maze.tiles;
    const through = h.state === "leaving" || h.state === "routed";
    const ways: Dir[] = [];
    for (let d = 0; d < 4; d++) {
      if (d !== opposite(h.dir) && walkable(tiles, neighbour(h.tile, d as Dir), through)) ways.push(d as Dir);
    }
    if (!ways.length) return opposite(h.dir);
    if (h.state === "leaving") return this.toward(h, ways, this.toGate);
    if (h.state === "routed") return this.toward(h, ways, this.toDen);
    if (h.state === "mobbed") return this.toward(h, ways, this.puffinField(), -1);
    const puffin = this.puffinField();
    if (h.kind === "raven") {
      // The raven wanders until it sees the puffin down a straight tunnel, then dives at it.
      if (h.dive === 0 && h.diveRest === 0 && this.sees(h.tile, nearTile(this.puffin))) { h.dive = DIVE_STEPS; this.emit("dive"); }
      return h.dive > 0 ? this.toward(h, ways, puffin) : this.rng.pick(ways);
    }
    if (ways.length === 1) return ways[0];
    if (!h.hunting) return this.rng.pick(ways);
    if (h.kind === "fox") {
      // The fox follows the puffin's scent, tile by tile, while the trail is fresh; without one it takes the shortest way.
      const here = this.fresh(h.tile);
      let best: Dir | -1 = -1, newest = here;
      for (const d of ways) {
        const s = this.fresh(neighbour(h.tile, d));
        if (s > newest) { newest = s; best = d; }
      }
      if (best >= 0) return best as Dir;
    }
    if (h.kind === "skua" && puffin[h.tile] > SKUA_CLOSE) {
      // The skua flies to the puffin's next meal: the eel nearest the puffin that isn't right under its beak.
      let meal = -1;
      for (const t of this.maze.eels) {
        if (this.eels[t] && puffin[t] >= SKUA_MEAL_MIN && (meal < 0 || puffin[t] < puffin[meal])) meal = t;
      }
      if (meal >= 0) return this.toward(h, ways, distances(tiles, [meal], false));
    }
    return this.toward(h, ways, puffin);
  }

  /** The way that brings a hunter nearest to where `field` counts from (or, with `sign` -1, farthest from it). */
  private toward(h: Hunter, ways: Dir[], field: Int16Array, sign = 1): Dir {
    let best = ways[0];
    for (const d of ways) if (field[neighbour(h.tile, d)] * sign < field[neighbour(h.tile, best)] * sign) best = d;
    return best;
  }

  /** When the puffin was last on a tile, or 0 if never or too long ago for the fox to smell. */
  private fresh(tile: number): number {
    const s = this.scent[tile];
    return s > 0 && this.clock - s < SCENT_STEPS ? s : 0;
  }

  /** Whether two tiles are in one row or column with nothing but tunnel between them. */
  private sees(a: number, b: number): boolean {
    const ax = tileX(a), ay = tileY(a), bx = tileX(b), by = tileY(b);
    if (a === b || (ax !== bx && ay !== by)) return false;
    const d: Dir = ax === bx ? (by > ay ? 2 : 0) : bx > ax ? 1 : 3;
    for (let t = a; t !== b;) {
      t = t + DX[d] + DY[d] * COLS;
      if (this.maze.tiles[t] !== PATH) return false;
    }
    return true;
  }

  /** A hunter that touches the puffin catches it, unless the terns are mobbing that hunter: then it is routed. */
  private touch(): void {
    const p = position(this.puffin);
    for (const h of this.hunters) {
      if (h.state !== "out" && h.state !== "mobbed") continue;
      const q = position(h);
      let dx = Math.abs(p.x - q.x);
      if (dx > (COLS * UNIT) / 2) dx = COLS * UNIT - dx;
      if (dx + Math.abs(p.y - q.y) >= TOUCH) continue;
      if (h.state === "mobbed") {
        this.chain++;
        h.state = "routed";
        const points = ROUT_POINTS * this.chain;
        this.popups.push({ x: q.x, y: q.y, points, steps: POPUP_STEPS });
        this.add(points);
        this.hitStop = HIT_STOP;
        this.emit("rout");
      } else {
        this.phase = "caught";
        this.timer = CAUGHT_STEPS;
        this.lives--;
        this.clean = false;
        this.emit("caught");
        return;
      }
    }
  }
}
