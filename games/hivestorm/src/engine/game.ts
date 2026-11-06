// The game itself: no drawing, no sound, no DOM. `step` advances one frame (1/60 s) and lists what happened in
// `events`, so the page can play sounds and the tests can drive whole games.
import { Rng } from "./rng";
import { H, Kind, POINTS, QUEEN_BONUS, RULES, SLOTS, W, diveInterval, diveSpeed, maxDivers } from "./rules";

export type Phase = "attract" | "ready" | "play" | "dying" | "waveClear" | "playerOver" | "gameOver";
export type Mode = "home" | "peel" | "dive" | "return";
export type GameEvent = "start" | "ready" | "shoot" | "hit" | "queen" | "dive" | "die" | "extra" | "wave" | "over" | "pause";

export interface Input {
  left: boolean;
  right: boolean;
  fire: boolean;
  /** The next three are presses, true for one frame only. */
  start1: boolean;
  start2: boolean;
  pause: boolean;
}

export const NO_INPUT: Input = { left: false, right: false, fire: false, start1: false, start2: false, pause: false };

export interface Alien {
  id: number;
  kind: Kind;
  row: number;
  col: number;
  alive: boolean;
  mode: Mode;
  x: number;
  y: number;
  vx: number;
  vy: number;
  /** Peel: the angle turned so far. Dive: frames since the dive began. */
  t: number;
  /** Which way it peels away from the hive: -1 left, 1 right. */
  dir: number;
  cx: number;
  cy: number;
  /** For a guard escorting a queen: the queen's id and where it flies relative to her. -1 when on its own. */
  leader: number;
  offX: number;
  offY: number;
  /** For a diving queen: how many of her escorts were shot on this dive. */
  escortsLost: number;
  shots: number;
  fireIn: number;
}

export interface PlayerState {
  score: number;
  /** Ships left, counting the one in play. */
  lives: number;
  wave: number;
  /** Which aliens of this player's hive are still alive, by id: kept while the other player has their turn. */
  alive: boolean[];
  extraGiven: boolean;
  over: boolean;
}

export interface Shot { x: number; y: number }
export interface Bullet { x: number; y: number; vx: number; vy: number }
export interface Boom { x: number; y: number; age: number; kind: Kind | "player"; seed: number }
export interface Popup { x: number; y: number; age: number; text: string }

export const newPlayer = (): PlayerState => ({
  score: 0,
  lives: RULES.startLives,
  wave: 1,
  alive: SLOTS.map(() => true),
  extraGiven: false,
  over: false,
});

export class Game {
  phase: Phase = "attract";
  timer = 0;
  frame = 0;
  paused = false;
  numPlayers = 1;
  current = 0;
  players: PlayerState[] = [];
  hiScore = 0;
  aliens: Alien[] = [];
  shot: Shot | null = null;
  bullets: Bullet[] = [];
  booms: Boom[] = [];
  popups: Popup[] = [];
  events: GameEvent[] = [];
  playerX = W / 2;
  sway = 0;
  swayDir = 1;
  diveCooldown = 0;
  rng: Rng;

  constructor(seed = Date.now()) {
    this.rng = new Rng(seed);
    this.loadHive(SLOTS.map(() => true));
  }

  get player(): PlayerState | undefined { return this.players[this.current]; }
  get wave(): number { return this.player?.wave ?? 1; }
  get aliveCount(): number { return this.aliens.reduce((n, a) => n + (a.alive ? 1 : 0), 0); }
  get swarm(): boolean { return this.aliveCount <= RULES.swarmAt; }

  /** Where an alien's home in the hive is right now, as the hive sways. */
  home(a: { row: number; col: number }): { x: number; y: number } {
    const f = RULES.formation;
    return { x: W / 2 + this.sway + (a.col - f.centre) * f.colGap, y: f.top + a.row * f.rowGap };
  }

  start(players: 1 | 2): void {
    this.numPlayers = players;
    this.players = Array.from({ length: players }, newPlayer);
    this.current = 0;
    this.booms = [];
    this.popups = [];
    this.events.push("start");
    this.enterReady();
  }

  step(input: Input): GameEvent[] {
    this.events = [];
    if (input.pause && this.phase !== "attract") {
      this.paused = !this.paused;
      this.events.push("pause");
    }
    if (this.paused) return this.events;
    this.frame++;

    if (this.phase === "attract") {
      this.swayHive();
      if (input.start1) this.start(1);
      else if (input.start2) this.start(2);
      return this.events;
    }

    this.swayHive();
    this.ageEffects();
    switch (this.phase) {
      case "ready":
        this.moveAliens(false);
        if (--this.timer <= 0) this.phase = "play";
        break;
      case "play":
        this.movePlayer(input);
        this.moveShot();
        this.moveAliens(true);
        this.launchDives();
        this.moveBullets();
        this.collide();
        if (this.phase === "play" && this.aliveCount === 0) {
          this.player!.wave++;
          this.phase = "waveClear";
          this.timer = RULES.timing.waveClear;
          this.bullets = [];
          this.events.push("wave");
        }
        break;
      case "dying":
        this.moveShot();
        this.moveAliens(false);
        this.moveBullets();
        if (--this.timer <= 0) this.afterDeath();
        break;
      case "waveClear":
        this.moveShot();
        this.moveAliens(false);
        if (--this.timer <= 0) {
          this.player!.alive = SLOTS.map(() => true);
          this.loadHive(this.player!.alive);
          this.diveCooldown = RULES.timing.firstDive;
          this.phase = "play";
        }
        break;
      case "playerOver":
        if (--this.timer <= 0) this.nextTurn();
        break;
      case "gameOver":
        if (--this.timer <= 0) this.phase = "attract";
        break;
    }
    return this.events;
  }

  // --- turns -------------------------------------------------------------------------------------------------

  private loadHive(alive: boolean[]): void {
    this.aliens = SLOTS.map((s, id) => {
      const h = this.home(s);
      return {
        id, kind: s.kind, row: s.row, col: s.col, alive: alive[id], mode: "home",
        x: h.x, y: h.y, vx: 0, vy: 0, t: 0, dir: 1, cx: 0, cy: 0,
        leader: -1, offX: 0, offY: 0, escortsLost: 0, shots: 0, fireIn: 0,
      };
    });
  }

  private enterReady(): void {
    this.loadHive(this.player!.alive);
    this.shot = null;
    this.bullets = [];
    this.playerX = W / 2;
    this.diveCooldown = RULES.timing.firstDive;
    this.phase = "ready";
    this.timer = RULES.timing.ready;
    this.events.push("ready");
  }

  private afterDeath(): void {
    const p = this.player!;
    p.alive = this.aliens.map((a) => a.alive);
    if (p.lives <= 0) {
      p.over = true;
      if (this.numPlayers === 1) return this.endGame();
      this.phase = "playerOver";
      this.timer = RULES.timing.playerOver;
      this.events.push("over");
      return;
    }
    this.nextTurn();
  }

  /** Two players take turns: the turn passes on each lost ship, skipping a player whose game is over. */
  private nextTurn(): void {
    if (this.numPlayers === 2 && !this.players[1 - this.current].over) this.current = 1 - this.current;
    if (this.player!.over) return this.endGame();
    this.enterReady();
  }

  private endGame(): void {
    this.phase = "gameOver";
    this.timer = RULES.timing.gameOver;
    this.shot = null;
    this.bullets = [];
    this.events.push("over");
  }

  private addScore(points: number): void {
    const p = this.player!;
    p.score += points;
    if (!p.extraGiven && p.score >= RULES.extraLifeAt) {
      p.extraGiven = true;
      p.lives++;
      this.events.push("extra");
    }
    this.hiScore = Math.max(this.hiScore, p.score);
  }

  // --- movement ----------------------------------------------------------------------------------------------

  private swayHive(): void {
    const f = RULES.formation;
    this.sway += this.swayDir * f.swaySpeed;
    if (Math.abs(this.sway) >= f.sway) {
      this.sway = Math.sign(this.sway) * f.sway;
      this.swayDir = -this.swayDir;
    }
  }

  private ageEffects(): void {
    for (const b of this.booms) b.age++;
    for (const p of this.popups) p.age++;
    this.booms = this.booms.filter((b) => b.age < (b.kind === "player" ? 90 : 30));
    this.popups = this.popups.filter((p) => p.age < 70);
  }

  private movePlayer(input: Input): void {
    const p = RULES.player;
    if (input.left && !input.right) this.playerX -= p.speed;
    if (input.right && !input.left) this.playerX += p.speed;
    this.playerX = Math.max(p.minX, Math.min(p.maxX, this.playerX));
    // Only one shot in the air at a time.
    if (input.fire && !this.shot) {
      this.shot = { x: Math.round(this.playerX), y: p.y - 8 };
      this.events.push("shoot");
    }
  }

  private moveShot(): void {
    if (!this.shot) return;
    this.shot.y -= RULES.shot.speed;
    if (this.shot.y < RULES.shot.top) this.shot = null;
  }

  private moveAliens(mayFire: boolean): void {
    const speed = diveSpeed(this.wave);
    for (const a of this.aliens) {
      if (!a.alive) continue;
      const home = this.home(a);
      if (a.mode === "home") {
        a.x = home.x;
        a.y = home.y;
        continue;
      }
      const px = a.x, py = a.y;
      if (a.leader >= 0) {
        const q = this.aliens[a.leader];
        if (q.alive && (q.mode === "peel" || q.mode === "dive")) {
          a.x = q.x + a.offX;
          a.y = q.y + a.offY;
          a.vx = q.vx;
          a.vy = q.vy;
        } else {
          a.leader = -1; // on its own now, carrying on the way it was going
          a.mode = "dive";
        }
      } else if (a.mode === "peel") {
        a.t += RULES.peel.turn;
        const r = RULES.peel.radius;
        a.x = a.cx - a.dir * r * Math.cos(a.t);
        a.y = a.cy - r * Math.sin(a.t);
        a.vx = a.x - px;
        a.vy = a.y - py;
        if (a.t >= RULES.peel.sweep) { a.mode = "dive"; a.t = 0; }
      } else if (a.mode === "dive") {
        a.t++;
        const d = RULES.dive;
        if (a.y < RULES.player.y - 24) {
          const target = this.playerX + Math.sin(a.t * 0.05 + a.id) * 18;
          a.vx += Math.sign(target - a.x) * d.steer;
          a.vx = Math.max(-d.maxVx, Math.min(d.maxVx, a.vx));
        }
        a.vy += (speed - a.vy) * 0.05;
        a.x += a.vx;
        a.y += a.vy;
        if (a.x < 6 || a.x > W - 6) { a.vx = -a.vx; a.x = Math.max(6, Math.min(W - 6, a.x)); }
      } else {
        // Coming home from the top of the screen.
        a.x += Math.max(-2, Math.min(2, home.x - a.x));
        a.y += RULES.dive.returnSpeed;
        if (a.y >= home.y) { a.mode = "home"; a.x = home.x; a.y = home.y; }
      }
      if (a.mode === "dive" && mayFire) this.maybeFire(a);
      if ((a.mode === "dive" || a.mode === "peel") && a.y > H + 10) this.wrap(a);
    }
  }

  /** An alien that flew off the bottom comes back in at the top: home, or, in a swarm, straight into another dive. */
  private wrap(a: Alien): void {
    a.leader = -1;
    a.y = -10;
    if (this.swarm && this.phase === "play") {
      a.mode = "dive";
      a.t = 0;
      a.vy = 0.5;
      a.shots = 1 + this.rng.int(2);
      a.fireIn = 20 + this.rng.int(40);
    } else {
      a.mode = "return";
      a.x = this.home(a).x;
    }
  }

  private maybeFire(a: Alien): void {
    if (a.shots <= 0 || --a.fireIn > 0) return;
    if (a.y < 40 || a.y > RULES.player.y - 50) return;
    const b = RULES.bullet;
    const vx = Math.max(-b.maxVx, Math.min(b.maxVx, ((this.playerX - a.x) / (RULES.player.y - a.y)) * b.speed));
    this.bullets.push({ x: a.x, y: a.y + 6, vx, vy: b.speed });
    a.shots--;
    a.fireIn = 18 + this.rng.int(30);
  }

  private moveBullets(): void {
    for (const b of this.bullets) { b.x += b.vx; b.y += b.vy; }
    this.bullets = this.bullets.filter((b) => b.y < H + 4 && b.x > -4 && b.x < W + 4);
  }

  // --- dives -------------------------------------------------------------------------------------------------

  private launchDives(): void {
    if (--this.diveCooldown > 0) return;
    const homes = this.aliens.filter((a) => a.alive && a.mode === "home");
    if (homes.length === 0) { this.diveCooldown = 10; return; }
    const out = this.aliens.filter((a) => a.alive && a.mode !== "home").length;
    if (!this.swarm && out >= maxDivers(this.wave)) { this.diveCooldown = 10; return; }

    const queens = homes.filter((a) => a.kind === "queen");
    if (queens.length > 0 && this.rng.chance(0.3)) {
      const q = this.rng.pick(queens);
      this.startDive(q);
      const escorts = homes.filter((a) => a.kind === "guard" && Math.abs(a.col - q.col) <= 1).slice(0, 2);
      for (const e of escorts) {
        e.mode = "dive";
        e.leader = q.id;
        e.offX = e.x - q.x;
        e.offY = e.y - q.y;
        e.t = 0;
        e.shots = 1 + this.rng.int(2);
        e.fireIn = 40 + this.rng.int(40);
      }
    } else {
      // Aliens peel off from the ends of the hive.
      const pool = homes.filter((a) => a.kind !== "queen");
      const from = pool.length ? pool : homes;
      const left = this.rng.chance(0.5);
      const edge = left ? Math.min(...from.map((a) => a.col)) : Math.max(...from.map((a) => a.col));
      this.startDive(this.rng.pick(from.filter((a) => a.col === edge)));
    }
    const base = this.swarm ? 25 : diveInterval(this.wave);
    this.diveCooldown = Math.round(base * (0.7 + this.rng.next() * 0.6));
  }

  private startDive(a: Alien): void {
    const f = RULES.formation;
    a.mode = "peel";
    a.t = 0;
    a.dir = a.col < f.centre ? -1 : a.col > f.centre ? 1 : this.rng.chance(0.5) ? -1 : 1;
    a.cx = a.x + a.dir * RULES.peel.radius;
    a.cy = a.y;
    a.leader = -1;
    a.escortsLost = 0;
    a.shots = 1 + this.rng.int(2 + Math.min(2, Math.floor(this.wave / 3)));
    a.fireIn = 25 + this.rng.int(40);
    this.events.push("dive");
  }

  // --- hits --------------------------------------------------------------------------------------------------

  private collide(): void {
    const s = this.shot;
    if (s) {
      const r = RULES.alien;
      const hit = this.aliens.find((a) => a.alive && Math.abs(s.x - a.x) <= r.halfW + 1 && Math.abs(s.y - a.y) <= r.halfH + 3);
      if (hit) { this.shot = null; this.kill(hit); }
    }
    const p = RULES.player;
    if (this.bullets.some((b) => Math.abs(b.x - this.playerX) <= p.halfW && Math.abs(b.y - p.y) <= p.halfH)) {
      return this.killPlayer();
    }
    const c = RULES.alien.crash;
    const crash = this.aliens.find((a) => a.alive && a.mode !== "home" && Math.abs(a.x - this.playerX) <= c && Math.abs(a.y - p.y) <= c);
    if (crash) {
      this.kill(crash);
      this.killPlayer();
    }
  }

  /** Points for an alien shot (or rammed) now. */
  pointsFor(a: Alien): number {
    if (a.mode === "home") return POINTS[a.kind].home;
    if (a.kind === "queen") return QUEEN_BONUS[Math.min(a.escortsLost, QUEEN_BONUS.length - 1)];
    return POINTS[a.kind].diving;
  }

  private kill(a: Alien): void {
    const points = this.pointsFor(a);
    if (a.leader >= 0) this.aliens[a.leader].escortsLost++;
    a.alive = false;
    this.addScore(points);
    this.booms.push({ x: a.x, y: a.y, age: 0, kind: a.kind, seed: this.rng.int(1000) });
    if (a.kind === "queen" && a.mode !== "home") {
      this.popups.push({ x: a.x, y: a.y, age: 0, text: String(points) });
      this.events.push("queen");
    } else {
      this.events.push("hit");
    }
  }

  private killPlayer(): void {
    this.booms.push({ x: this.playerX, y: RULES.player.y, age: 0, kind: "player", seed: this.rng.int(1000) });
    this.player!.lives--;
    this.bullets = [];
    this.phase = "dying";
    this.timer = RULES.timing.dying;
    this.events.push("die");
  }
}
