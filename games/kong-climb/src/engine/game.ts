// The rules of Kong Climb, stepped 60 times a second with no drawing in it. A Game is built from a seed;
// the page calls step(input) once a frame and draws what it finds. The engine keeps a list of events (jump,
// smash, death, ...) for the sound to read after each step.
import { Rng } from "./rng";
import { buildLevel, stagesFor, surface, W, type Ladder, type LevelDef, type Platform } from "./levels";

export interface Input {
  left: boolean;
  right: boolean;
  up: boolean;
  down: boolean;
  jump: boolean;
}

export const NO_INPUT: Input = { left: false, right: false, up: false, down: false, jump: false };

export type Mode = "ready" | "play" | "dying" | "clear" | "over";
export type HeroState = "ground" | "air" | "climb" | "dead";

export const WALK = 1.0;
export const AIR_SPEED = 0.8;
export const CLIMB = 0.65;
export const JUMP_V = -2.4;
export const GRAVITY = 0.15;
export const FATAL_FALL = 30;
export const HAMMER_FRAMES = 600;
export const START_LIVES = 3;
export const EXTRA_LIFE = 7000;

export interface Hero {
  x: number;
  y: number;
  vy: number;
  dir: 1 | -1;
  state: HeroState;
  plat: number;
  ladder: Ladder | null;
  jumpDir: number;
  peakY: number;
  leash: [number, number];
  hammer: number;
  jumpHits: number;
  anim: number;
  moving: boolean;
}

export type HazardKind = "barrel" | "pie";

export interface Barrel {
  kind: HazardKind;
  x: number;
  y: number;
  vy: number;
  dir: 1 | -1;
  plat: number;
  mode: "roll" | "fall" | "ladder";
  wild: boolean;
  scored: boolean;
  lastLadder: Ladder | null;
  ladder: Ladder | null;
  spin: number;
}

export interface Fire {
  x: number;
  y: number;
  dir: 1 | -1;
  plat: number;
  mode: "walk" | "climb";
  ladder: Ladder | null;
  lastLadder: Ladder | null;
  climbDir: number;
  scored: boolean;
  think: number;
}

export interface Spring {
  x: number;
  y: number;
  vy: number;
  scored: boolean;
}

export interface Pickup {
  x: number;
  y: number;
  plat: number;
  taken: boolean;
}

export interface Item extends Pickup {
  kind: "hat" | "purse" | "umbrella";
}

export interface Rivet extends Pickup {
  removed: boolean;
}

export interface Popup {
  x: number;
  y: number;
  text: string;
  t: number;
}

const roundSpeed = (round: number, base: number, per: number, cap: number) => Math.min(cap, base + per * (round - 1));

export class Game {
  readonly rng: Rng;
  score = 0;
  lives = START_LIVES;
  round = 1;
  stageIdx = 0;
  mode: Mode = "ready";
  modeT = 0;
  frame = 0;
  bonus = 0;
  bonusClock = 0;
  extraGiven = false;
  def: LevelDef;
  platforms: Platform[];
  hero!: Hero;
  barrels: Barrel[] = [];
  fires: Fire[] = [];
  springs: Spring[] = [];
  hammers: Pickup[] = [];
  items: Item[] = [];
  rivets: Rivet[] = [];
  popups: Popup[] = [];
  events: string[] = [];
  /** Frames since the ape last threw something, for his animation; and whether the oil drum is burning. */
  kongThrow = 999;
  oilFire = 0;
  fireTimer = 0;
  throwTimer = 0;
  thrown = 0;
  beltTimer = 0;
  kongFallen = false;
  private prevJump = false;
  private deathReason = "";

  constructor(seed: number) {
    this.rng = new Rng(seed);
    this.def = buildLevel("girders");
    this.platforms = this.def.platforms;
    this.loadStage();
  }

  get kind() {
    return this.def.kind;
  }

  /** The platform a hero or thing stands on. */
  plat(id: number): Platform {
    return this.platforms[id];
  }

  // ---- setting a stage up -------------------------------------------------------------------------------

  /** Builds the current stage afresh (also after a death: the stage starts over). */
  loadStage(): void {
    const kind = stagesFor(this.round)[this.stageIdx];
    this.def = buildLevel(kind);
    this.platforms = this.def.platforms;
    const d = this.def;
    const s = d.start;
    this.hero = {
      x: s.x,
      y: surface(this.platforms[s.plat], s.x),
      vy: 0,
      dir: 1,
      state: "ground",
      plat: s.plat,
      ladder: null,
      jumpDir: 0,
      peakY: 0,
      leash: [0, W],
      hammer: 0,
      jumpHits: 0,
      anim: 0,
      moving: false,
    };
    const at = (sp: { x: number; plat: number }) => ({ x: sp.x, y: surface(this.platforms[sp.plat], sp.x), plat: sp.plat, taken: false });
    this.hammers = d.hammers.map(at);
    this.items = d.items.map((i) => ({ ...at(i), kind: i.kind }));
    this.rivets = d.rivets.map((r) => ({ ...at(r), removed: false }));
    this.barrels = [];
    this.springs = [];
    this.popups = [];
    this.fires = [];
    for (const f of d.fires) this.addFire(f.x, f.plat);
    this.bonus = Math.min(8000, 3000 + 1000 * (this.round + 1));
    this.bonusClock = 0;
    this.kongThrow = 999;
    this.oilFire = 0;
    this.kongFallen = false;
    this.thrown = 0;
    this.throwTimer = 90;
    this.fireTimer = 600;
    this.beltTimer = 420;
    this.mode = "ready";
    this.modeT = 0;
    this.prevJump = false;
  }

  /** How many fireballs may be alive at once. */
  get fireCap(): number {
    return Math.min(6, 2 + this.round);
  }

  private addFire(x: number, plat: number): void {
    this.fires.push({
      x,
      y: surface(this.platforms[plat], x),
      dir: this.rng.next() < 0.5 ? 1 : -1,
      plat,
      mode: "walk",
      ladder: null,
      lastLadder: null,
      climbDir: 0,
      scored: false,
      think: 0,
    });
  }

  private nextStage(): void {
    this.stageIdx++;
    if (this.stageIdx >= stagesFor(this.round).length) {
      this.stageIdx = 0;
      this.round++;
    }
    this.loadStage();
  }

  // ---- one frame ----------------------------------------------------------------------------------------

  step(input: Input): void {
    this.events = [];
    this.frame++;
    this.kongThrow++;
    for (const p of this.popups) p.t++;
    this.popups = this.popups.filter((p) => p.t < 70);
    if (this.oilFire > 0) this.oilFire--;
    const jumpPressed = input.jump && !this.prevJump;
    this.prevJump = input.jump;

    switch (this.mode) {
      case "ready":
        if (++this.modeT >= 80) {
          this.mode = "play";
          this.modeT = 0;
        }
        return;
      case "dying":
        this.modeT++;
        this.hero.anim++;
        if (this.modeT >= 110) {
          if (this.lives <= 0) {
            this.mode = "over";
            this.modeT = 0;
          } else this.loadStage();
        }
        return;
      case "clear":
        this.modeT++;
        this.hero.anim++;
        if (this.def.kind === "rivets" && this.modeT === 60) this.kongFallen = true;
        if (this.modeT >= 220) this.nextStage();
        return;
      case "over":
        this.modeT++;
        return;
      case "play":
        break;
    }

    this.moveLifts();
    this.stepHero(input, jumpPressed);
    this.spawn();
    this.stepBarrels();
    this.stepFires();
    this.stepSprings();
    this.checkHammer();
    this.checkHits();
    this.checkPickups();
    this.tickBonus();
    this.checkGoal();
  }

  // ---- the hero -----------------------------------------------------------------------------------------

  private moveLifts(): void {
    const d = this.def;
    for (const p of this.platforms) {
      if (p.lift === 0) continue;
      p.y1 += p.lift;
      p.y2 = p.y1;
      if (p.lift < 0 && p.y1 < d.liftTop) p.y1 = p.y2 = d.liftBottom;
      if (p.lift > 0 && p.y1 > d.liftBottom) p.y1 = p.y2 = d.liftTop;
    }
  }

  private liftWrapped(p: Platform): boolean {
    return p.lift < 0 ? p.y1 === this.def.liftBottom : p.y1 === this.def.liftTop;
  }

  private stepHero(input: Input, jumpPressed: boolean): void {
    const h = this.hero;
    const dx = (input.right ? 1 : 0) - (input.left ? 1 : 0);
    h.moving = false;

    if (h.state === "ground") {
      const p = this.platforms[h.plat];
      if (p.lift !== 0 && this.liftWrapped(p)) {
        this.startFall(0);
      } else {
        let nx = h.x;
        if (dx !== 0) {
          h.dir = dx > 0 ? 1 : -1;
          nx += dx * WALK * (h.hammer > 0 ? 0.8 : 1);
          h.moving = true;
          h.anim++;
        }
        nx += p.belt * 0.8;
        if (this.def.walls) nx = Math.min(p.x2, Math.max(p.x1, nx));
        else nx = Math.min(W - 4, Math.max(4, nx));
        h.x = nx;
        if (nx < p.x1 - 0.5 || nx > p.x2 + 0.5) {
          this.startFall(dx);
        } else {
          h.y = surface(p, h.x);
          this.removeRivets();
          if (jumpPressed && h.hammer === 0) {
            this.startJump(dx);
          } else if (h.hammer === 0 && (input.up || input.down)) {
            this.tryClimb(input.up);
          }
        }
      }
    } else if (h.state === "climb") {
      this.stepClimb(input);
    } else if (h.state === "air") {
      this.stepAir();
    }
    if (h.hammer > 0 && h.state !== "dead") h.hammer--;
  }

  private startJump(dx: number): void {
    const h = this.hero;
    const p = this.platforms[h.plat];
    h.state = "air";
    h.vy = JUMP_V;
    h.jumpDir = dx;
    h.peakY = h.y;
    h.leash = [p.x1, p.x2];
    h.jumpHits = 0;
    h.plat = -1;
    this.events.push("jump");
  }

  private startFall(dx: number): void {
    const h = this.hero;
    h.state = "air";
    h.vy = 0;
    h.jumpDir = dx;
    h.peakY = h.y;
    h.leash = [0, W];
    h.jumpHits = 0;
    h.plat = -1;
  }

  private tryClimb(up: boolean): void {
    const h = this.hero;
    let best: Ladder | null = null;
    for (const l of this.def.ladders) {
      if (l.broken || Math.abs(l.x - h.x) > 3) continue;
      if ((up && l.low === h.plat) || (!up && l.high === h.plat)) best = l;
    }
    if (!best) return;
    h.state = "climb";
    h.ladder = best;
    h.x = best.x;
    h.plat = -1;
    h.y = up ? best.yBottom : best.yTop;
    this.events.push("climb");
  }

  private stepClimb(input: Input): void {
    const h = this.hero;
    const l = h.ladder as Ladder;
    const v = (input.down ? 1 : 0) - (input.up ? 1 : 0);
    if (v === 0) return;
    h.y += v * CLIMB;
    h.anim++;
    h.moving = true;
    if (h.y <= l.yTop) {
      h.state = "ground";
      h.plat = l.high;
      h.y = surface(this.platforms[l.high], h.x);
      h.ladder = null;
    } else if (h.y >= l.yBottom) {
      h.state = "ground";
      h.plat = l.low;
      h.y = surface(this.platforms[l.low], h.x);
      h.ladder = null;
    }
  }

  private stepAir(): void {
    const h = this.hero;
    const prevY = h.y;
    h.x += h.jumpDir * AIR_SPEED;
    if (this.def.walls) h.x = Math.min(h.leash[1], Math.max(h.leash[0], h.x));
    else h.x = Math.min(W - 4, Math.max(4, h.x));
    h.y += h.vy;
    h.vy += GRAVITY;
    if (h.y < h.peakY) h.peakY = h.y;
    if (h.vy > 0) {
      const landed = this.landing(h.x, prevY, h.y);
      if (landed) {
        const fall = landed.y - h.peakY;
        h.y = landed.y;
        h.plat = landed.id;
        h.state = "ground";
        h.jumpDir = 0;
        this.events.push("land");
        if (fall > FATAL_FALL) this.die("fall");
        return;
      }
    }
    if (h.y > 270) this.die("fall");
  }

  /** The highest platform surface a falling thing crossed going from prevY to y at x. */
  landing(x: number, prevY: number, y: number): { id: number; y: number } | null {
    let best: { id: number; y: number } | null = null;
    for (const p of this.platforms) {
      if (x < p.x1 - 0.5 || x > p.x2 + 0.5) continue;
      const s = surface(p, x);
      if (prevY <= s + 3 && y >= s && (!best || s < best.y)) best = { id: p.id, y: s };
    }
    return best;
  }

  private removeRivets(): void {
    const h = this.hero;
    for (const r of this.rivets) {
      if (r.removed || r.plat !== h.plat || Math.abs(r.x - h.x) > 3) continue;
      r.removed = true;
      this.addScore(100, h.x, h.y - 20);
      this.events.push("rivet");
    }
  }

  // ---- what the ape sends and what runs about -----------------------------------------------------------

  private spawn(): void {
    const d = this.def;
    const r = this.round;
    if (d.kind === "girders" || d.kind === "conveyors") {
      if (--this.throwTimer <= 0) {
        const interval = Math.max(d.kind === "girders" ? 70 : 90, (d.kind === "girders" ? 190 : 170) - 14 * (r - 1)) + this.rng.int(40);
        this.throwTimer = interval;
        this.thrown++;
        this.kongThrow = 0;
        const x = d.kong.x + 30;
        const wild = d.kind === "girders" && (this.thrown === 1 || this.rng.next() < 0.22);
        this.barrels.push({
          kind: d.kind === "girders" ? "barrel" : "pie",
          x,
          y: surface(this.platforms[d.kong.plat], x),
          vy: 0,
          dir: 1,
          plat: d.kong.plat,
          mode: "roll",
          wild,
          scored: false,
          lastLadder: null,
          ladder: null,
          spin: 0,
        });
        this.events.push("throw");
      }
    }
    if (d.kind === "elevators" && --this.throwTimer <= 0) {
      this.throwTimer = Math.max(60, 130 - 10 * (r - 1)) + this.rng.int(50);
      this.kongThrow = 0;
      const x = d.kong.x - 12;
      this.springs.push({ x, y: surface(this.platforms[d.kong.plat], x) - 4, vy: -1.4, scored: false });
      this.events.push("throw");
    }
    if (d.kind === "conveyors" || d.kind === "elevators" || d.kind === "rivets") {
      if (--this.fireTimer <= 0) {
        this.fireTimer = 700 - Math.min(300, 40 * r);
        if (this.fires.length < this.fireCap) {
          const spots =
            d.kind === "rivets" ? [{ x: 20, plat: 0 }, { x: 204, plat: 0 }] : d.kind === "conveyors" ? [{ x: 8, plat: 0 }, { x: 214, plat: 0 }] : [{ x: 196, plat: 2 }];
          const s = this.rng.pick(spots);
          this.addFire(s.x, s.plat);
        }
      }
    }
    if (d.kind === "conveyors" && --this.beltTimer <= 0) {
      this.beltTimer = 500 + this.rng.int(300);
      const p = this.platforms[1 + this.rng.int(4)];
      p.belt = -p.belt;
    }
  }

  private rollSpeed(b: Barrel): number {
    const r = this.round;
    return b.kind === "pie" ? roundSpeed(r, 0.5, 0.04, 0.8) : roundSpeed(r, 1.0, 0.06, 1.5);
  }

  private stepBarrels(): void {
    const keep: Barrel[] = [];
    for (const b of this.barrels) {
      b.spin += 0.2;
      if (b.mode === "roll") {
        const p = this.platforms[b.plat];
        const speed = this.rollSpeed(b);
        if (b.kind === "pie") {
          const move = p.belt !== 0 ? p.belt * (speed / 0.5) : b.dir * speed;
          if (move !== 0) b.dir = move > 0 ? 1 : -1;
          b.x += move;
        } else {
          b.dir = p.y2 > p.y1 ? 1 : -1;
          b.x += b.dir * speed;
        }
        if (b.x < p.x1 || b.x > p.x2) {
          b.mode = "fall";
          b.vy = 0.2;
          b.y = surface(p, Math.min(p.x2, Math.max(p.x1, b.x)));
          b.plat = -1;
          b.lastLadder = null;
        } else {
          b.y = surface(p, b.x);
          if (b.kind === "barrel") this.barrelLadders(b);
          if (b.kind === "barrel" && b.plat === 0 && this.def.oilX !== null && b.x < this.def.oilX + 6) {
            this.intoOil();
            continue;
          }
        }
      } else if (b.mode === "ladder") {
        const l = b.ladder as Ladder;
        b.y += 1.0;
        if (b.y >= l.yBottom) {
          b.mode = "roll";
          b.plat = l.low;
          b.y = surface(this.platforms[l.low], b.x);
          b.ladder = null;
          b.lastLadder = l;
        }
      } else {
        const prevY = b.y;
        b.y += b.vy;
        b.vy += GRAVITY * 0.9;
        b.x += b.dir * 0.3;
        const landed = this.landing(b.x, prevY, b.y);
        if (landed && b.vy > 0) {
          b.mode = "roll";
          b.plat = landed.id;
          b.y = landed.y;
          const p = this.platforms[landed.id];
          if (b.kind === "barrel") b.dir = p.y2 > p.y1 ? 1 : -1;
        }
      }
      if (b.y > 275) continue;
      keep.push(b);
    }
    this.barrels = keep;
  }

  private barrelLadders(b: Barrel): void {
    for (const l of this.def.ladders) {
      if (l.broken || l.high !== b.plat || l === b.lastLadder) continue;
      if (Math.abs(l.x - b.x) > this.rollSpeed(b) * 0.5 + 0.1) continue;
      b.lastLadder = l;
      const chance = b.wild ? 1 : Math.min(0.6, 0.3 + 0.05 * (this.round - 1));
      if (this.rng.next() < chance) {
        b.mode = "ladder";
        b.ladder = l;
        b.x = l.x;
        this.events.push("ladderbarrel");
      }
      return;
    }
  }

  private intoOil(): void {
    this.oilFire = 40;
    this.events.push("oil");
    if (this.fires.length < this.fireCap && this.rng.next() < 0.7) {
      this.addFire(this.def.oilX as number + 6, 0);
    }
  }

  private stepFires(): void {
    const h = this.hero;
    const speed = roundSpeed(this.round, 0.38, 0.04, 0.7);
    for (const f of this.fires) {
      if (f.mode === "walk") {
        const p = this.platforms[f.plat];
        if (f.think-- <= 0) {
          f.think = 40 + this.rng.int(40);
          const wants = h.x > f.x ? 1 : -1;
          if (this.rng.next() < 0.45) f.dir = wants;
        }
        f.x += f.dir * speed + p.belt * 0.6;
        if (f.x < p.x1 + 2 || f.x > p.x2 - 2) {
          f.x = Math.min(p.x2 - 2, Math.max(p.x1 + 2, f.x));
          f.dir = f.x <= p.x1 + 2 ? 1 : -1;
        }
        f.y = surface(p, f.x);
        for (const l of this.def.ladders) {
          if (l.broken || l === f.lastLadder || Math.abs(l.x - f.x) > 1.2) continue;
          const here = l.low === f.plat ? "up" : l.high === f.plat ? "down" : "";
          if (!here) continue;
          f.lastLadder = l;
          const heroAbove = h.y < f.y - 6;
          const chance = here === "up" ? (heroAbove ? 0.45 : 0.15) : heroAbove ? 0.05 : 0.3;
          if (this.rng.next() < chance) {
            f.mode = "climb";
            f.ladder = l;
            f.climbDir = here === "up" ? -1 : 1;
            f.x = l.x;
          }
          break;
        }
        if (f.lastLadder && Math.abs(f.lastLadder.x - f.x) > 6) f.lastLadder = null;
      } else {
        const l = f.ladder as Ladder;
        f.y += f.climbDir * 0.5;
        if (f.climbDir < 0 && f.y <= l.yTop) {
          f.mode = "walk";
          f.plat = l.high;
          f.y = surface(this.platforms[l.high], f.x);
        } else if (f.climbDir > 0 && f.y >= l.yBottom) {
          f.mode = "walk";
          f.plat = l.low;
          f.y = surface(this.platforms[l.low], f.x);
        }
      }
    }
  }

  private stepSprings(): void {
    const keep: Spring[] = [];
    const speed = roundSpeed(this.round, 0.85, 0.05, 1.3);
    for (const s of this.springs) {
      const prevY = s.y;
      s.x -= speed;
      s.y += s.vy;
      s.vy += GRAVITY;
      if (s.vy > 0) {
        const landed = this.landing(s.x, prevY, s.y);
        if (landed) {
          s.y = landed.y;
          s.vy = -2.1;
        }
      }
      if (s.x < -8 || s.y > 275) continue;
      keep.push(s);
    }
    this.springs = keep;
  }

  // ---- hammer, hits, pickups ---------------------------------------------------------------------------

  private smashScore(): number {
    return this.rng.pick([300, 500, 800]);
  }

  private checkHammer(): void {
    const h = this.hero;
    if (h.hammer <= 0 || h.state !== "ground") return;
    const near = (x: number, y: number) => {
      const fx = (x - h.x) * h.dir;
      return fx > -2 && fx < 16 && Math.abs(y - h.y) < 14;
    };
    const left: Barrel[] = [];
    for (const b of this.barrels) {
      if (near(b.x, b.y)) {
        this.addScore(this.smashScore(), b.x, b.y - 10);
        this.events.push("smash");
      } else left.push(b);
    }
    this.barrels = left;
    const alive: Fire[] = [];
    for (const f of this.fires) {
      if (near(f.x, f.y)) {
        this.addScore(this.smashScore(), f.x, f.y - 10);
        this.events.push("smash");
      } else alive.push(f);
    }
    this.fires = alive;
  }

  private checkHits(): void {
    const h = this.hero;
    if (h.state === "dead") return;
    const body = (x: number, y: number, w: number, hgt: number) => Math.abs(x - h.x) < w && y > h.y - 15 && y - hgt < h.y;
    const clearOver = (x: number, y: number, reach: number) => h.state === "air" && Math.abs(x - h.x) <= reach && h.y <= y - 8 && h.y >= y - 34;
    const jumpScore = (o: { scored: boolean; x: number; y: number }) => {
      if (o.scored || !clearOver(o.x, o.y, 7)) return;
      o.scored = true;
      h.jumpHits++;
      const pts = h.jumpHits === 1 ? 100 : h.jumpHits === 2 ? 300 : 800;
      this.addScore(pts, o.x, o.y - 16);
      this.events.push("over");
    };
    for (const b of this.barrels) {
      jumpScore(b);
      if (body(b.x, b.y, 6, 8) && !(h.state === "air" && h.y <= b.y - 8)) return this.die(b.kind);
    }
    for (const f of this.fires) {
      jumpScore(f);
      if (body(f.x, f.y, 5, 12)) return this.die("fire");
    }
    for (const s of this.springs) {
      jumpScore(s);
      if (body(s.x, s.y, 6, 8) && !(h.state === "air" && h.y <= s.y - 8)) return this.die("spring");
    }
  }

  private checkPickups(): void {
    const h = this.hero;
    if (h.state === "dead") return;
    const touching = (p: Pickup) => !p.taken && Math.abs(p.x - h.x) < 7 && Math.abs(p.y - h.y) < 12;
    for (const p of this.hammers) {
      if (touching(p) && h.state !== "climb" && h.hammer === 0) {
        p.taken = true;
        h.hammer = HAMMER_FRAMES;
        this.events.push("hammer");
      }
    }
    for (const it of this.items) {
      if (touching(it)) {
        it.taken = true;
        this.addScore(it.kind === "hat" ? 300 : it.kind === "purse" ? 500 : 800, it.x, it.y - 14);
        this.events.push("pickup");
      }
    }
  }

  private tickBonus(): void {
    const per = Math.max(100, 190 - 10 * this.round);
    if (++this.bonusClock >= per) {
      this.bonusClock = 0;
      this.bonus = Math.max(0, this.bonus - 100);
      if (this.bonus === 0) this.die("time");
    }
  }

  private checkGoal(): void {
    if (this.mode !== "play") return;
    const h = this.hero;
    const g = this.def.goal;
    let done = false;
    if (g) done = h.state === "ground" && h.plat === g.plat && h.x <= g.maxX;
    else done = this.rivets.length > 0 && this.rivets.every((r) => r.removed);
    if (!done) return;
    this.mode = "clear";
    this.modeT = 0;
    this.addScore(this.bonus, h.x, h.y - 24);
    this.events.push("clear");
  }

  // ---- score and life -------------------------------------------------------------------------------------

  addScore(n: number, x: number, y: number): void {
    this.score += n;
    this.popups.push({ x, y, text: String(n), t: 0 });
    if (!this.extraGiven && this.score >= EXTRA_LIFE) {
      this.extraGiven = true;
      this.lives++;
      this.events.push("extra");
    }
  }

  die(reason: string): void {
    if (this.mode !== "play") return;
    this.mode = "dying";
    this.modeT = 0;
    this.hero.state = "dead";
    this.hero.hammer = 0;
    this.deathReason = reason;
    this.lives--;
    this.events.push("death");
  }

  get lastDeath(): string {
    return this.deathReason;
  }
}
