// The whole game as a pure simulation: newGame() makes a state, step() advances it by DT.
// No DOM, no timers, no Math.random: the same seed and inputs always give the same game.
import { BLINK, COMBO, DRONE, DT, GUN, H, MAX_PLAYERS, POD, ROCK, SHIP, TAKEDOWN, W, WAVE, type RockSize } from "./config";
import { pick, rand, range } from "./rng";

/** Co-op: shots pass through other ships. Versus: they don't. Attract: no ships, the title backdrop. */
export type Mode = "coop" | "versus" | "attract";
export type RockKind = "stone" | "crystal" | "iron";
export type PodKind = "rapid" | "spread" | "shield";

/** One player's controls for one step. */
export interface Controls {
  left: boolean;
  right: boolean;
  thrust: boolean;
  fire: boolean;
  blink: boolean;
}
export const IDLE: Controls = Object.freeze({ left: false, right: false, thrust: false, fire: false, blink: false });

export interface Ship {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  angle: number;
  alive: boolean;
  /** No ships left: this player is out of the game. */
  out: boolean;
  /** Ships left, counting the one in play. */
  lives: number;
  score: number;
  nextExtra: number;
  /** Seconds until a lost ship comes back. */
  respawn: number;
  /** Seconds this ship can't be hurt. */
  guard: number;
  sinceShot: number;
  blinkCool: number;
  prevFire: boolean;
  prevBlink: boolean;
  thrusting: boolean;
  power: "rapid" | "spread" | null;
  powerTime: number;
  shield: boolean;
  combo: number;
  lastHit: number;
}

export interface Bullet {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  /** The ship that fired it, or -1 for a drone. */
  owner: number;
  dead: boolean;
}

export interface Rock {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  size: RockSize;
  kind: RockKind;
  hp: number;
  angle: number;
  spin: number;
  /** Radius multipliers around the outline, for drawing. */
  shape: number[];
  /** Seconds left of the white flash after a hit that didn't break it. */
  flash: number;
  dead: boolean;
}

export interface Drone {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  /** The small one hunts: it aims at the nearest ship. */
  small: boolean;
  fire: number;
  turn: number;
  angle: number;
  dead: boolean;
}

export interface Pod {
  id: number;
  x: number;
  y: number;
  vx: number;
  vy: number;
  kind: PodKind;
  life: number;
  dead: boolean;
}

export type EventType =
  | "shot" | "boom" | "clank" | "blink" | "pod" | "extra" | "die" | "spawn"
  | "wave" | "clear" | "drone" | "droneBoom" | "zap" | "shieldHit" | "streak" | "over";

export interface GameEvent {
  type: EventType;
  x: number;
  y: number;
  /** Rock size, wave number or multiplier. */
  n?: number;
  kind?: string;
  ship?: number;
  x2?: number;
  y2?: number;
}

export interface Game {
  mode: Mode;
  rng: number;
  time: number;
  wave: number;
  /** Counting down to the next wave while ≥ 0; −1 while a wave is on. */
  waveTimer: number;
  droneTimer: number;
  ships: Ship[];
  rocks: Rock[];
  bullets: Bullet[];
  drones: Drone[];
  pods: Pod[];
  /** What happened in the last step, for sound and effects. */
  events: GameEvent[];
  nextId: number;
  over: boolean;
}

export const wrap = (v: number, size: number): number => ((v % size) + size) % size;

/** The shortest difference a − b on a wrapping axis. */
export function delta(a: number, b: number, size: number): number {
  let d = a - b;
  if (d > size / 2) d -= size;
  else if (d < -size / 2) d += size;
  return d;
}

function near(ax: number, ay: number, bx: number, by: number, r: number): boolean {
  const dx = delta(ax, bx, W);
  const dy = delta(ay, by, H);
  return dx * dx + dy * dy < r * r;
}

export const rockRadius = (r: Rock): number => ROCK.radius[r.size];
export const droneRadius = (d: Drone): number => (d.small ? DRONE.smallRadius : DRONE.bigRadius);

/** Where player `id` of `count` appears: the middle for one, a ring around it for more. */
export function spawnPoint(id: number, count: number): { x: number; y: number } {
  if (count <= 1) return { x: W / 2, y: H / 2 };
  if (count === 2) return { x: W * (id === 0 ? 0.38 : 0.62), y: H / 2 };
  const a = -Math.PI / 2 + (id / count) * Math.PI * 2;
  return { x: W / 2 + Math.cos(a) * 300, y: H / 2 + Math.sin(a) * 230 };
}

function makeShip(id: number): Ship {
  return {
    id, x: 0, y: 0, vx: 0, vy: 0, angle: -Math.PI / 2,
    alive: false, out: false, lives: SHIP.lives, score: 0, nextExtra: SHIP.extraEvery,
    respawn: 0, guard: 0, sinceShot: 1, blinkCool: 0, prevFire: true, prevBlink: true, thrusting: false,
    power: null, powerTime: 0, shield: false, combo: 0, lastHit: -99,
  };
}

export function newGame(mode: Mode, players: number, seed: number): Game {
  const count = mode === "attract" ? 0 : Math.max(1, Math.min(MAX_PLAYERS, Math.floor(players)));
  const g: Game = {
    mode, rng: seed | 0, time: 0, wave: 0, waveTimer: WAVE.opening, droneTimer: 0,
    ships: [], rocks: [], bullets: [], drones: [], pods: [], events: [], nextId: 1, over: false,
  };
  for (let i = 0; i < count; i++) {
    const s = makeShip(i);
    g.ships.push(s);
    placeShip(g, s);
  }
  g.events = [];
  return g;
}

function emit(g: Game, e: GameEvent): void {
  g.events.push(e);
}

function placeShip(g: Game, s: Ship): void {
  const p = spawnPoint(s.id, g.ships.length);
  Object.assign(s, { x: p.x, y: p.y, vx: 0, vy: 0, angle: -Math.PI / 2, alive: true, guard: SHIP.spawnGuard, blinkCool: 0 });
  emit(g, { type: "spawn", x: s.x, y: s.y, ship: s.id });
}

/** The score multiplier the ship's current streak earns. */
export function multiplier(s: Ship, time: number): number {
  if (time - s.lastHit > COMBO.window || s.combo === 0) return 1;
  return Math.min(COMBO.max, 1 + Math.floor((s.combo - 1) / COMBO.step));
}

/** Adds points to a ship, with its streak multiplier, and awards extra ships. Returns the points given. */
function award(g: Game, s: Ship, base: number): number {
  const before = multiplier(s, g.time);
  s.combo = g.time - s.lastHit <= COMBO.window ? s.combo + 1 : 1;
  s.lastHit = g.time;
  const mult = multiplier(s, g.time);
  if (mult > before && mult > 1) emit(g, { type: "streak", x: s.x, y: s.y, n: mult, ship: s.id });
  const pts = base * mult;
  s.score += pts;
  while (s.score >= s.nextExtra) {
    s.nextExtra += SHIP.extraEvery;
    if (!s.out) {
      s.lives++;
      emit(g, { type: "extra", x: s.x, y: s.y, ship: s.id });
    }
  }
  return pts;
}

function makeRock(g: Game, x: number, y: number, size: RockSize, kind: RockKind, vx: number, vy: number): Rock {
  const n = 10 + Math.floor(rand(g) * 4);
  const shape: number[] = [];
  for (let i = 0; i < n; i++) shape.push(range(g, 0.74, 1.06));
  const rock: Rock = {
    id: g.nextId++, x, y, vx, vy, size, kind, hp: kind === "iron" ? ROCK.ironHp : 1,
    angle: rand(g) * Math.PI * 2, spin: range(g, -1, 1) * (4 - size) * 0.5, shape, flash: 0, dead: false,
  };
  g.rocks.push(rock);
  return rock;
}

function launch(g: Game, size: RockSize): { vx: number; vy: number } {
  const [lo, hi] = ROCK.speed[size];
  const a = rand(g) * Math.PI * 2;
  const sp = range(g, lo, hi) * Math.min(1.6, 1 + 0.05 * (g.wave - 1));
  return { vx: Math.cos(a) * sp, vy: Math.sin(a) * sp };
}

export function rocksForWave(wave: number, players: number): number {
  return Math.min(WAVE.max, WAVE.first + wave - 1 + Math.floor(Math.max(0, players - 1) / 2));
}

function startWave(g: Game, n: number): void {
  g.wave = n;
  g.waveTimer = -1;
  const ironChance = n >= ROCK.ironFrom ? Math.min(0.3, 0.1 + 0.04 * (n - ROCK.ironFrom)) : 0;
  const live = g.ships.filter((s) => s.alive);
  for (let i = rocksForWave(n, g.ships.length); i > 0; i--) {
    let x = 0;
    let y = 0;
    for (let tries = 0; tries < 40; tries++) {
      // Along an edge, away from every ship.
      if (rand(g) < 0.5) { x = rand(g) * W; y = rand(g) < 0.5 ? 0 : H - 1; }
      else { x = rand(g) < 0.5 ? 0 : W - 1; y = rand(g) * H; }
      if (live.every((s) => !near(x, y, s.x, s.y, WAVE.clearance))) break;
    }
    const roll = rand(g);
    const kind: RockKind = roll < ironChance ? "iron" : roll < ironChance + ROCK.crystalChance ? "crystal" : "stone";
    const v = launch(g, 3);
    makeRock(g, x, y, 3, kind, v.vx, v.vy);
  }
  g.droneTimer = droneDelay(g);
  emit(g, { type: "wave", x: W / 2, y: H / 2, n });
}

const droneDelay = (g: Game): number => range(g, 13, 22) * Math.max(0.45, 1 - 0.06 * (g.wave - 1));

function destroyRock(g: Game, r: Rock, by: number): void {
  if (r.dead) return;
  r.dead = true;
  const mult = r.kind === "crystal" ? ROCK.crystalPoints : r.kind === "iron" ? ROCK.ironPoints : 1;
  if (by >= 0) award(g, g.ships[by], ROCK.points[r.size] * mult);
  emit(g, { type: "boom", x: r.x, y: r.y, n: r.size, kind: r.kind });
  if (r.size > 1) {
    const size = (r.size - 1) as RockSize;
    const pieces = r.kind === "crystal" ? 3 : 2;
    const a0 = rand(g) * Math.PI * 2;
    const [lo, hi] = ROCK.speed[size];
    for (let i = 0; i < pieces; i++) {
      const a = a0 + (i / pieces) * Math.PI * 2 + range(g, -0.3, 0.3);
      const sp = range(g, lo, hi) * Math.min(1.6, 1 + 0.05 * (g.wave - 1));
      makeRock(g, r.x, r.y, size, r.kind, r.vx * 0.4 + Math.cos(a) * sp, r.vy * 0.4 + Math.sin(a) * sp);
    }
  }
  if (r.kind === "crystal" && g.mode !== "attract" && rand(g) < ROCK.podChance) dropPod(g, r.x, r.y);
}

function damageRock(g: Game, r: Rock, by: number): void {
  r.hp--;
  if (r.hp > 0) {
    r.flash = 0.12;
    emit(g, { type: "clank", x: r.x, y: r.y, kind: r.kind });
  } else destroyRock(g, r, by);
}

function dropPod(g: Game, x: number, y: number): void {
  const a = rand(g) * Math.PI * 2;
  g.pods.push({
    id: g.nextId++, x, y, vx: Math.cos(a) * POD.speed, vy: Math.sin(a) * POD.speed,
    kind: pick(g, ["rapid", "spread", "shield"] as const), life: POD.life, dead: false,
  });
}

function killShip(g: Game, s: Ship): void {
  s.alive = false;
  s.lives--;
  s.combo = 0;
  s.power = null;
  s.shield = false;
  s.thrusting = false;
  emit(g, { type: "die", x: s.x, y: s.y, ship: s.id });
  if (s.lives > 0) s.respawn = SHIP.respawn;
  else s.out = true;
}

/** Something hit ship `s`. A shield takes the hit; otherwise the ship is lost. Returns false if it was guarded. */
function hurtShip(g: Game, s: Ship, by: number): boolean {
  if (!s.alive || s.guard > 0) return false;
  if (s.shield) {
    s.shield = false;
    s.guard = 1;
    emit(g, { type: "shieldHit", x: s.x, y: s.y, ship: s.id });
    return true;
  }
  killShip(g, s);
  if (by >= 0 && by !== s.id) award(g, g.ships[by], TAKEDOWN);
  return true;
}

function killDrone(g: Game, d: Drone, by: number): void {
  if (d.dead) return;
  d.dead = true;
  if (by >= 0) award(g, g.ships[by], d.small ? DRONE.smallPoints : DRONE.bigPoints);
  emit(g, { type: "droneBoom", x: d.x, y: d.y, kind: d.small ? "small" : "big" });
  if (by >= 0 && rand(g) < DRONE.podChance) dropPod(g, d.x, d.y);
}

function fire(g: Game, s: Ship): boolean {
  const angles = s.power === "spread" ? [-GUN.spreadAngle, 0, GUN.spreadAngle] : [0];
  const cap = s.power === "spread" ? GUN.spreadCap : s.power === "rapid" ? GUN.rapidCap : GUN.cap;
  let inFlight = 0;
  for (const b of g.bullets) if (b.owner === s.id && !b.dead) inFlight++;
  if (inFlight + angles.length > cap) return false;
  for (const da of angles) {
    const a = s.angle + da;
    g.bullets.push({
      x: wrap(s.x + Math.cos(a) * 16, W), y: wrap(s.y + Math.sin(a) * 16, H),
      vx: Math.cos(a) * GUN.speed + s.vx, vy: Math.sin(a) * GUN.speed + s.vy,
      life: GUN.life, owner: s.id, dead: false,
    });
  }
  emit(g, { type: "shot", x: s.x, y: s.y, ship: s.id });
  return true;
}

function updateShip(g: Game, s: Ship, c: Controls): void {
  const tap = c.fire && !s.prevFire;
  const blink = c.blink && !s.prevBlink;
  s.prevFire = c.fire;
  s.prevBlink = c.blink;
  if (!s.alive) {
    if (!s.out) {
      s.respawn -= DT;
      if (s.respawn <= 0) placeShip(g, s);
    }
    return;
  }
  if (c.left) s.angle -= SHIP.turn * DT;
  if (c.right) s.angle += SHIP.turn * DT;
  s.thrusting = c.thrust;
  if (c.thrust) {
    s.vx += Math.cos(s.angle) * SHIP.thrust * DT;
    s.vy += Math.sin(s.angle) * SHIP.thrust * DT;
  }
  const k = Math.exp(-SHIP.drag * DT);
  s.vx *= k;
  s.vy *= k;
  const sp = Math.hypot(s.vx, s.vy);
  if (sp > SHIP.maxSpeed) {
    s.vx *= SHIP.maxSpeed / sp;
    s.vy *= SHIP.maxSpeed / sp;
  }
  s.x = wrap(s.x + s.vx * DT, W);
  s.y = wrap(s.y + s.vy * DT, H);
  s.sinceShot += DT;
  s.blinkCool = Math.max(0, s.blinkCool - DT);
  s.guard = Math.max(0, s.guard - DT);
  if (s.power) {
    s.powerTime -= DT;
    if (s.powerTime <= 0) s.power = null;
  }
  if (c.fire) {
    const wait = tap ? GUN.tapCool : s.power === "rapid" ? GUN.rapidCool : GUN.holdCool;
    if (s.sinceShot >= wait && fire(g, s)) s.sinceShot = 0;
  }
  if (blink && s.blinkCool <= 0) {
    const x0 = s.x;
    const y0 = s.y;
    s.x = wrap(s.x + Math.cos(s.angle) * BLINK.distance, W);
    s.y = wrap(s.y + Math.sin(s.angle) * BLINK.distance, H);
    s.guard = Math.max(s.guard, BLINK.guard);
    s.blinkCool = BLINK.cool;
    emit(g, { type: "blink", x: x0, y: y0, x2: s.x, y2: s.y, ship: s.id });
  }
}

function nearestShip(g: Game, x: number, y: number): Ship | undefined {
  let best: Ship | undefined;
  let bestD = Infinity;
  for (const s of g.ships) {
    if (!s.alive) continue;
    const d = Math.hypot(delta(s.x, x, W), delta(s.y, y, H));
    if (d < bestD) { bestD = d; best = s; }
  }
  return best;
}

function updateDrones(g: Game): void {
  if (g.drones.length === 0 && g.waveTimer < 0 && g.rocks.length > 0) {
    g.droneTimer -= DT;
    if (g.droneTimer <= 0) {
      const hunterChance = g.wave >= DRONE.hunterFrom ? Math.min(0.7, 0.2 + 0.08 * (g.wave - DRONE.hunterFrom)) : 0;
      const small = rand(g) < hunterChance;
      const speed = small ? DRONE.smallSpeed : DRONE.bigSpeed;
      const fromLeft = rand(g) < 0.5;
      g.drones.push({
        id: g.nextId++, x: fromLeft ? -30 : W + 30, y: range(g, H * 0.15, H * 0.85), vx: fromLeft ? speed : -speed, vy: 0,
        small, fire: 0.8, turn: range(g, 0.8, 1.8), angle: 0, dead: false,
      });
      emit(g, { type: "drone", x: fromLeft ? 0 : W, y: H / 2, kind: small ? "small" : "big" });
      g.droneTimer = droneDelay(g);
    }
  }
  for (const d of g.drones) {
    const speed = d.small ? DRONE.smallSpeed : DRONE.bigSpeed;
    d.x += d.vx * DT;
    d.y = wrap(d.y + d.vy * DT, H);
    d.angle += DT * (d.small ? 4 : 2);
    if (d.x < -40 || d.x > W + 40) d.dead = true; // flew off the side
    d.turn -= DT;
    if (d.turn <= 0) {
      d.turn = range(g, 0.8, 1.8);
      d.vy = pick(g, [-1, 0, 1]) * speed * 0.6;
    }
    d.fire -= DT;
    if (d.fire <= 0 && d.x > 0 && d.x < W) {
      d.fire = d.small ? DRONE.smallFire : DRONE.bigFire;
      let a = rand(g) * Math.PI * 2;
      const target = d.small ? nearestShip(g, d.x, d.y) : undefined;
      if (target) {
        const miss = Math.max(0.06, 0.45 - 0.04 * g.wave);
        a = Math.atan2(delta(target.y, d.y, H), delta(target.x, d.x, W)) + range(g, -miss, miss);
      }
      g.bullets.push({ x: d.x, y: d.y, vx: Math.cos(a) * DRONE.shotSpeed, vy: Math.sin(a) * DRONE.shotSpeed, life: DRONE.shotLife, owner: -1, dead: false });
      emit(g, { type: "zap", x: d.x, y: d.y });
    }
  }
}

function collide(g: Game): void {
  const versus = g.mode === "versus";
  for (const b of g.bullets) {
    if (b.dead) continue;
    for (const r of g.rocks) {
      if (!r.dead && near(b.x, b.y, r.x, r.y, rockRadius(r))) {
        b.dead = true;
        damageRock(g, r, b.owner);
        break;
      }
    }
    if (b.dead) continue;
    if (b.owner >= 0) {
      for (const d of g.drones) {
        if (!d.dead && near(b.x, b.y, d.x, d.y, droneRadius(d))) {
          b.dead = true;
          killDrone(g, d, b.owner);
          break;
        }
      }
      if (b.dead) continue;
    }
    // Drone shots hit every ship; ships' shots hit other ships only in versus.
    if (b.owner >= 0 && !versus) continue;
    for (const s of g.ships) {
      if (s.alive && s.id !== b.owner && s.guard <= 0 && near(b.x, b.y, s.x, s.y, SHIP.radius)) {
        b.dead = true;
        hurtShip(g, s, b.owner);
        break;
      }
    }
  }

  for (const s of g.ships) {
    for (const r of g.rocks) {
      if (!s.alive || s.guard > 0) break;
      if (!r.dead && near(s.x, s.y, r.x, r.y, rockRadius(r) + SHIP.radius * 0.8)) {
        hurtShip(g, s, -1);
        destroyRock(g, r, s.id);
      }
    }
    for (const d of g.drones) {
      if (!s.alive || s.guard > 0) break;
      if (!d.dead && near(s.x, s.y, d.x, d.y, droneRadius(d) + SHIP.radius * 0.8)) {
        hurtShip(g, s, -1);
        killDrone(g, d, s.id);
      }
    }
    for (const p of g.pods) {
      if (s.alive && !p.dead && near(s.x, s.y, p.x, p.y, POD.radius + SHIP.radius)) {
        p.dead = true;
        if (p.kind === "shield") s.shield = true;
        else { s.power = p.kind; s.powerTime = POD.duration; }
        emit(g, { type: "pod", x: p.x, y: p.y, kind: p.kind, ship: s.id });
      }
    }
  }

  // Ships that touch each other are both lost, in every mode, unless one is still guarded.
  for (let i = 0; i < g.ships.length; i++) {
    const a = g.ships[i];
    for (let j = i + 1; j < g.ships.length; j++) {
      const b = g.ships[j];
      if (!a.alive || !b.alive || a.guard > 0 || b.guard > 0) continue;
      if (near(a.x, a.y, b.x, b.y, SHIP.radius * 1.6)) {
        hurtShip(g, a, -1);
        hurtShip(g, b, -1);
      }
    }
  }

  for (const d of g.drones) {
    for (const r of g.rocks) {
      if (!d.dead && !r.dead && near(d.x, d.y, r.x, r.y, rockRadius(r) + droneRadius(d) * 0.8)) {
        killDrone(g, d, -1);
        destroyRock(g, r, -1);
      }
    }
  }
}

/** Advances the game by one step of DT seconds. `inputs[i]` is player i's controls. */
export function step(g: Game, inputs: readonly Controls[] = []): void {
  g.events = [];
  g.time += DT;
  g.ships.forEach((s, i) => updateShip(g, s, inputs[i] ?? IDLE));
  for (const b of g.bullets) {
    b.x = wrap(b.x + b.vx * DT, W);
    b.y = wrap(b.y + b.vy * DT, H);
    b.life -= DT;
    if (b.life <= 0) b.dead = true;
  }
  for (const r of g.rocks) {
    r.x = wrap(r.x + r.vx * DT, W);
    r.y = wrap(r.y + r.vy * DT, H);
    r.angle += r.spin * DT;
    r.flash = Math.max(0, r.flash - DT);
  }
  for (const p of g.pods) {
    p.x = wrap(p.x + p.vx * DT, W);
    p.y = wrap(p.y + p.vy * DT, H);
    p.life -= DT;
    if (p.life <= 0) p.dead = true;
  }
  updateDrones(g);
  collide(g);
  g.bullets = g.bullets.filter((b) => !b.dead);
  g.rocks = g.rocks.filter((r) => !r.dead);
  g.drones = g.drones.filter((d) => !d.dead);
  g.pods = g.pods.filter((p) => !p.dead);

  if (g.waveTimer >= 0) {
    g.waveTimer -= DT;
    if (g.waveTimer < 0) startWave(g, g.wave + 1);
  } else if (g.rocks.length === 0) {
    g.waveTimer = WAVE.pause;
    emit(g, { type: "clear", x: W / 2, y: H / 2, n: g.wave });
  }

  if (!g.over && g.ships.length > 0 && g.ships.every((s) => s.out)) {
    g.over = true;
    emit(g, { type: "over", x: W / 2, y: H / 2 });
  }
}

/** Players ranked by score, best first (ties keep player order). */
export function standings(g: Game): Ship[] {
  return [...g.ships].sort((a, b) => b.score - a.score || a.id - b.id);
}
