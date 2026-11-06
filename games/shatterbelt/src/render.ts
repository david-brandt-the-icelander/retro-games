// Drawing: the field, the effects, the HUD and every screen, on one canvas in 1280×800 field units.
import { BLINK, H, MAX_PLAYERS, POD, SHIP, W } from "./engine/config";
import { droneRadius, multiplier, rockRadius, standings, type Game, type GameEvent, type Rock, type Ship } from "./engine/game";
import type { Entry } from "./scores";

/** One colour per player. Drones are red; no player is. */
export const PLAYER_COLORS = ["#45f0c2", "#ffa63d", "#5aa8ff", "#ff7ad9", "#b6f04a", "#b48cff", "#fff06a", "#f2f2f2", "#ff9f9f"];
const COLOR = {
  bg: "#04060d",
  stone: "#d9b58c",
  stoneFill: "rgba(38,28,20,0.9)",
  crystal: "#8fe9ff",
  crystalFill: "rgba(14,34,60,0.8)",
  iron: "#e0704a",
  ironFill: "rgba(48,22,16,0.92)",
  drone: "#ff3b3b",
  text: "#e9eef7",
  dim: "#7f8aa3",
  pod: { rapid: "#fff06a", spread: "#b48cff", shield: "#6cc8ff" } as Record<string, string>,
};

/** Three hull designs, pointing along +x; player i flies hull i % 3 in colour i. */
const HULLS: number[][] = [
  [18, 0, -8, -12, -4, -5, -12, -6, -9, 0, -12, 6, -4, 5, -8, 12],
  [16, 0, 4, -6, -6, -13, -11, -8, -7, 0, -11, 8, -6, 13, 4, 6],
  [17, 0, 2, -9, -10, -10, -6, -3, -12, 0, -6, 3, -10, 10, 2, 9],
];

const FONT = 'ui-monospace, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace';
const fmt = (n: number): string => n.toLocaleString("en-US");

interface Particle {
  x: number;
  y: number;
  vx: number;
  vy: number;
  life: number;
  max: number;
  color: string;
  size: number;
  /** Debris: a spinning line of this length. */
  len?: number;
  angle?: number;
  spin?: number;
  /** A floating word. */
  text?: string;
  /** An expanding ring. */
  ring?: number;
}

export interface Rect { x: number; y: number; w: number; h: number }
export const inRect = (r: Rect, x: number, y: number): boolean => x >= r.x && x <= r.x + r.w && y >= r.y && y <= r.y + r.h;

/** Title menu items, in field units, for taps. */
export const MENU_ITEMS = ["CO-OP", "VERSUS"] as const;
export const menuRect = (i: number): Rect => ({ x: 440, y: 338 + i * 62, w: 400, h: 50 });

export class Renderer {
  private ctx: CanvasRenderingContext2D;
  private parts: Particle[] = [];
  private backdrop: HTMLCanvasElement | null = null;
  private shake = 0;
  private banner: { text: string; sub: string; t: number } | null = null;
  scale = 1;

  constructor(private canvas: HTMLCanvasElement) {
    this.ctx = canvas.getContext("2d")!;
    this.fit();
  }

  /** Matches the canvas to its size on screen. */
  fit(): void {
    const r = this.canvas.getBoundingClientRect();
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.max(320, Math.round(r.width * dpr));
    const h = Math.round((w * H) / W);
    if (this.canvas.width !== w || this.canvas.height !== h) {
      this.canvas.width = w;
      this.canvas.height = h;
      this.backdrop = null;
    }
    this.scale = w / W;
  }

  /** A point on the page, in field units. */
  toField(clientX: number, clientY: number): { x: number; y: number } {
    const r = this.canvas.getBoundingClientRect();
    return { x: ((clientX - r.left) / r.width) * W, y: ((clientY - r.top) / r.height) * H };
  }

  private paintBackdrop(): HTMLCanvasElement {
    const c = document.createElement("canvas");
    c.width = this.canvas.width;
    c.height = this.canvas.height;
    const x = c.getContext("2d")!;
    x.scale(this.scale, this.scale);
    x.fillStyle = COLOR.bg;
    x.fillRect(0, 0, W, H);
    const glow = (cx: number, cy: number, r: number, color: string) => {
      const gr = x.createRadialGradient(cx, cy, 0, cx, cy, r);
      gr.addColorStop(0, color);
      gr.addColorStop(1, "rgba(0,0,0,0)");
      x.fillStyle = gr;
      x.fillRect(0, 0, W, H);
    };
    glow(W * 0.22, H * 0.3, 520, "rgba(40,60,140,0.22)");
    glow(W * 0.8, H * 0.75, 600, "rgba(110,40,120,0.16)");
    glow(W * 0.6, H * 0.15, 300, "rgba(20,110,120,0.12)");
    let seed = 7;
    const r = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
    for (let i = 0; i < 220; i++) {
      const b = r();
      x.fillStyle = `rgba(${200 + r() * 55},${210 + r() * 45},255,${0.15 + b * 0.6})`;
      const s = b > 0.93 ? 2 : 1.2;
      x.fillRect(r() * W, r() * H, s, s);
    }
    return c;
  }

  /** Turns a step's events into particles, shake and banners. */
  absorb(events: GameEvent[], g: Game): void {
    for (const e of events) {
      const pc = e.ship !== undefined ? PLAYER_COLORS[e.ship] : COLOR.text;
      switch (e.type) {
        case "boom": {
          const n = e.n ?? 1;
          const col = e.kind === "crystal" ? COLOR.crystal : e.kind === "iron" ? COLOR.iron : COLOR.stone;
          this.spray(e.x, e.y, 6 + n * 7, col, 60 + n * 40, 0.5 + n * 0.15);
          this.debris(e.x, e.y, 2 + n, col, 4 + n * 3);
          this.shake = Math.max(this.shake, n * 1.6);
          break;
        }
        case "clank": this.spray(e.x, e.y, 6, "#ffffff", 120, 0.25); break;
        case "die":
          this.spray(e.x, e.y, 30, pc, 160, 1.1);
          this.debris(e.x, e.y, 7, pc, 12);
          this.ring(e.x, e.y, pc, 70, 0.6);
          this.shake = Math.max(this.shake, 9);
          break;
        case "droneBoom":
          this.spray(e.x, e.y, 26, COLOR.drone, 150, 0.8);
          this.debris(e.x, e.y, 5, COLOR.drone, 10);
          this.ring(e.x, e.y, COLOR.drone, 60, 0.5);
          this.shake = Math.max(this.shake, 5);
          break;
        case "blink": {
          for (let i = 0; i <= 10; i++) {
            const t = i / 10;
            const dx = wrapDelta((e.x2 ?? e.x) - e.x, W);
            const dy = wrapDelta((e.y2 ?? e.y) - e.y, H);
            this.parts.push({ x: e.x + dx * t, y: e.y + dy * t, vx: 0, vy: 0, life: 0.35 + t * 0.2, max: 0.55, color: pc, size: 2.5 });
          }
          this.ring(e.x2 ?? e.x, e.y2 ?? e.y, pc, 34, 0.35);
          break;
        }
        case "pod":
          this.ring(e.x, e.y, COLOR.pod[e.kind ?? "rapid"], 50, 0.45);
          this.word(e.x, e.y - 24, e.kind === "rapid" ? "RAPID FIRE" : e.kind === "spread" ? "SPREAD SHOT" : "SHIELD", COLOR.pod[e.kind ?? "rapid"]);
          break;
        case "shieldHit": this.ring(e.x, e.y, COLOR.pod.shield, 60, 0.5); break;
        case "extra": this.word(e.x, e.y - 26, "+1 SHIP", pc); break;
        case "streak": this.word(e.x, e.y - 26, `×${e.n}`, pc); break;
        case "spawn": this.ring(e.x, e.y, pc, 40, 0.5); break;
        case "wave": this.banner = { text: `WAVE ${e.n}`, sub: g.mode === "attract" ? "" : `${g.rocks.length} rocks inbound`, t: 2 }; break;
        case "clear": if (g.mode !== "attract") this.banner = { text: "BELT CLEARED", sub: `wave ${e.n} done`, t: 2 }; break;
        default: break;
      }
    }
  }

  /** Exhaust from every thrusting ship; call once per step. */
  trails(g: Game): void {
    for (const s of g.ships) {
      if (!s.alive || !s.thrusting) continue;
      const a = s.angle + Math.PI + (Math.random() - 0.5) * 0.5;
      this.parts.push({
        x: s.x - Math.cos(s.angle) * 11, y: s.y - Math.sin(s.angle) * 11,
        vx: s.vx * 0.3 + Math.cos(a) * 140, vy: s.vy * 0.3 + Math.sin(a) * 140,
        life: 0.3, max: 0.3, color: Math.random() < 0.5 ? "#fff3c0" : PLAYER_COLORS[s.id], size: 2,
      });
    }
  }

  update(dt: number): void {
    for (const p of this.parts) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= 0.985;
      p.vy *= 0.985;
      if (p.angle !== undefined) p.angle += (p.spin ?? 0) * dt;
      p.life -= dt;
    }
    this.parts = this.parts.filter((p) => p.life > 0);
    if (this.parts.length > 1500) this.parts.splice(0, this.parts.length - 1500);
    this.shake = Math.max(0, this.shake - dt * 25);
    if (this.banner) {
      this.banner.t -= dt;
      if (this.banner.t <= 0) this.banner = null;
    }
  }

  clearEffects(): void {
    this.parts = [];
    this.banner = null;
    this.shake = 0;
  }

  private spray(x: number, y: number, n: number, color: string, speed: number, life: number): void {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const v = speed * (0.3 + Math.random() * 0.9);
      this.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: life * (0.5 + Math.random() * 0.5), max: life, color, size: 1.5 + Math.random() * 1.5 });
    }
  }

  private debris(x: number, y: number, n: number, color: string, len: number): void {
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const v = 40 + Math.random() * 90;
      this.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, life: 0.9 + Math.random() * 0.6, max: 1.5, color, size: 1.6, len: len * (0.5 + Math.random()), angle: Math.random() * 6, spin: (Math.random() - 0.5) * 8 });
    }
  }

  private ring(x: number, y: number, color: string, radius: number, life: number): void {
    this.parts.push({ x, y, vx: 0, vy: 0, life, max: life, color, size: 2, ring: radius });
  }

  private word(x: number, y: number, text: string, color: string): void {
    this.parts.push({ x, y, vx: 0, vy: -30, life: 1.1, max: 1.1, color, size: 18, text });
  }

  // ---------------------------------------------------------------- drawing

  /** Starts a frame: backdrop, with shake. */
  begin(): void {
    const c = this.ctx;
    c.setTransform(1, 0, 0, 1, 0, 0);
    if (!this.backdrop) this.backdrop = this.paintBackdrop();
    c.drawImage(this.backdrop, 0, 0);
    const sx = this.shake ? (Math.random() - 0.5) * this.shake : 0;
    const sy = this.shake ? (Math.random() - 0.5) * this.shake : 0;
    c.setTransform(this.scale, 0, 0, this.scale, sx * this.scale, sy * this.scale);
    c.lineJoin = "round";
    c.lineCap = "round";
  }

  /** Strokes the current path twice: a wide faint pass for the glow, then the line. */
  private glow(color: string, width = 2, fill?: string): void {
    const c = this.ctx;
    if (fill) {
      c.fillStyle = fill;
      c.fill();
    }
    c.strokeStyle = color;
    const a = c.globalAlpha;
    c.globalAlpha = a * 0.22;
    c.lineWidth = width * 4;
    c.stroke();
    c.globalAlpha = a;
    c.lineWidth = width;
    c.stroke();
  }

  /** Calls draw at (x, y) and at each wrapped copy that would show near an edge. */
  private wrapped(x: number, y: number, r: number, draw: (x: number, y: number) => void): void {
    const xs = [x];
    const ys = [y];
    if (x < r) xs.push(x + W);
    if (x > W - r) xs.push(x - W);
    if (y < r) ys.push(y + H);
    if (y > H - r) ys.push(y - H);
    for (const xx of xs) for (const yy of ys) draw(xx, yy);
  }

  world(g: Game, t: number): void {
    const c = this.ctx;
    for (const r of g.rocks) this.wrapped(r.x, r.y, rockRadius(r) + 4, (x, y) => this.rock(r, x, y));
    for (const p of g.pods) {
      if (p.life < 2 && Math.floor(t * 8) % 2) continue;
      this.wrapped(p.x, p.y, POD.radius + 4, (x, y) => this.pod(p.kind, x, y, t));
    }
    for (const d of g.drones) this.drone(d.x, d.y, d.small, d.angle, droneRadius(d));
    for (const b of g.bullets) {
      if (b.owner < 0) {
        c.beginPath();
        c.arc(b.x, b.y, 3.5, 0, Math.PI * 2);
        this.glow(COLOR.drone, 1.5, "#ffd0d0");
      } else {
        const sp = Math.hypot(b.vx, b.vy) || 1;
        c.beginPath();
        c.moveTo(b.x, b.y);
        c.lineTo(b.x - (b.vx / sp) * 9, b.y - (b.vy / sp) * 9);
        this.glow(PLAYER_COLORS[b.owner], 2.5);
      }
    }
    for (const s of g.ships) {
      if (!s.alive) {
        // Mark where a lost ship will come back.
        if (!s.out && s.respawn < 1.2) {
          c.globalAlpha = 0.3 + 0.3 * Math.sin(t * 12);
          c.beginPath();
          c.arc(s.x, s.y, 16 + s.respawn * 20, 0, Math.PI * 2);
          this.glow(PLAYER_COLORS[s.id], 1.5);
          c.globalAlpha = 1;
        }
        continue;
      }
      if (s.guard > 0 && Math.floor(t * 14) % 2) c.globalAlpha = 0.35;
      this.wrapped(s.x, s.y, 24, (x, y) => this.ship(s, x, y, t));
      c.globalAlpha = 1;
    }
    this.particles();
  }

  private rock(r: Rock, x: number, y: number): void {
    const c = this.ctx;
    const R = rockRadius(r);
    const n = r.shape.length;
    const pt = (i: number, k = 1): [number, number] => {
      const a = r.angle + (i / n) * Math.PI * 2;
      return [x + Math.cos(a) * R * r.shape[i % n] * k, y + Math.sin(a) * R * r.shape[i % n] * k];
    };
    c.beginPath();
    for (let i = 0; i < n; i++) {
      const [px, py] = pt(i);
      if (i === 0) c.moveTo(px, py);
      else c.lineTo(px, py);
    }
    c.closePath();
    const col = r.flash > 0 ? "#ffffff" : r.kind === "crystal" ? COLOR.crystal : r.kind === "iron" ? COLOR.iron : COLOR.stone;
    const fill = r.kind === "crystal" ? COLOR.crystalFill : r.kind === "iron" ? COLOR.ironFill : COLOR.stoneFill;
    this.glow(col, r.size === 1 ? 1.5 : 2, fill);
    // Surface detail, by kind.
    c.beginPath();
    if (r.kind === "crystal") {
      // Facets from a point off-centre to every third corner.
      const cx = x + Math.cos(r.angle) * R * 0.15;
      const cy = y + Math.sin(r.angle) * R * 0.15;
      for (let i = 0; i < n; i += 3) {
        const [px, py] = pt(i, 0.97);
        c.moveTo(cx, cy);
        c.lineTo(px, py);
      }
    } else if (r.kind === "iron") {
      for (let i = 0; i < n; i++) {
        const [px, py] = pt(i, 0.55);
        if (i === 0) c.moveTo(px, py);
        else c.lineTo(px, py);
      }
      c.closePath();
      if (r.hp < 2) {
        const [ax, ay] = pt(1, 0.95);
        const [bx, by] = pt(n >> 1, 0.2);
        c.moveTo(ax, ay);
        c.lineTo(bx, by);
      }
    } else if (r.size > 1) {
      // Two craters.
      const k = R * 0.18;
      c.moveTo(x + Math.cos(r.angle + 1) * R * 0.4 + k, y + Math.sin(r.angle + 1) * R * 0.4);
      c.arc(x + Math.cos(r.angle + 1) * R * 0.4, y + Math.sin(r.angle + 1) * R * 0.4, k, 0, Math.PI * 2);
      const k2 = R * 0.12;
      c.moveTo(x + Math.cos(r.angle + 3.6) * R * 0.45 + k2, y + Math.sin(r.angle + 3.6) * R * 0.45);
      c.arc(x + Math.cos(r.angle + 3.6) * R * 0.45, y + Math.sin(r.angle + 3.6) * R * 0.45, k2, 0, Math.PI * 2);
    }
    c.globalAlpha *= 0.55;
    c.strokeStyle = col;
    c.lineWidth = 1.2;
    c.stroke();
    c.globalAlpha /= 0.55;
  }

  /** A hull outline at (x, y), pointing at `angle`, scaled by `k`. */
  hull(id: number, x: number, y: number, angle: number, k = 1, width = 2): void {
    const c = this.ctx;
    const pts = HULLS[id % HULLS.length];
    c.save();
    c.translate(x, y);
    c.rotate(angle);
    c.scale(k, k);
    c.beginPath();
    for (let i = 0; i < pts.length; i += 2) {
      if (i === 0) c.moveTo(pts[i], pts[i + 1]);
      else c.lineTo(pts[i], pts[i + 1]);
    }
    c.closePath();
    this.glow(PLAYER_COLORS[id], width / k, "rgba(4,6,13,0.85)");
    c.restore();
  }

  private ship(s: Ship, x: number, y: number, t: number): void {
    const c = this.ctx;
    if (s.thrusting) {
      const len = 16 + Math.random() * 10;
      c.save();
      c.translate(x, y);
      c.rotate(s.angle);
      c.beginPath();
      c.moveTo(-9, -4);
      c.lineTo(-9 - len, 0);
      c.lineTo(-9, 4);
      this.glow("#ffd27a", 1.5);
      c.restore();
    }
    this.hull(s.id, x, y, s.angle);
    if (s.shield) {
      c.globalAlpha *= 0.5 + 0.3 * Math.sin(t * 6);
      c.beginPath();
      c.arc(x, y, 22, 0, Math.PI * 2);
      this.glow(COLOR.pod.shield, 1.5);
      c.globalAlpha = 1;
    }
    if (s.power) {
      c.beginPath();
      c.arc(x, y, 3, 0, Math.PI * 2);
      c.fillStyle = COLOR.pod[s.power];
      c.fill();
    }
  }

  private drone(x: number, y: number, small: boolean, spin: number, r: number): void {
    const c = this.ctx;
    c.beginPath();
    const sides = small ? 4 : 6;
    for (let i = 0; i < sides; i++) {
      const a = (i / sides) * Math.PI * 2 + (small ? 0 : Math.PI / 6);
      const rx = small ? r * 1.3 : r;
      const px = x + Math.cos(a) * rx;
      const py = y + Math.sin(a) * r * (small ? 0.8 : 0.7);
      if (i === 0) c.moveTo(px, py);
      else c.lineTo(px, py);
    }
    c.closePath();
    this.glow(COLOR.drone, 2, "rgba(40,6,10,0.9)");
    // The turning eye.
    c.beginPath();
    for (let i = 0; i < 3; i++) {
      const a = spin + (i / 3) * Math.PI * 2;
      const px = x + Math.cos(a) * r * 0.4;
      const py = y + Math.sin(a) * r * 0.4;
      if (i === 0) c.moveTo(px, py);
      else c.lineTo(px, py);
    }
    c.closePath();
    this.glow("#ffb0b0", 1.2);
  }

  private pod(kind: string, x: number, y: number, t: number): void {
    const c = this.ctx;
    const col = COLOR.pod[kind];
    const r = POD.radius + Math.sin(t * 5) * 1.5;
    c.beginPath();
    c.arc(x, y, r, 0, Math.PI * 2);
    this.glow(col, 1.8, "rgba(6,10,20,0.85)");
    c.beginPath();
    if (kind === "rapid") {
      for (const dx of [-4, 3]) {
        c.moveTo(x + dx - 3, y - 5);
        c.lineTo(x + dx + 2, y);
        c.lineTo(x + dx - 3, y + 5);
      }
    } else if (kind === "spread") {
      for (const a of [-0.6, 0, 0.6]) {
        c.moveTo(x - 5, y);
        c.lineTo(x - 5 + Math.cos(a) * 10, y + Math.sin(a) * 10);
      }
    } else {
      c.arc(x, y, 6, Math.PI * 1.1, Math.PI * 1.9);
      c.moveTo(x - 6, y + 2);
      c.arc(x, y + 2, 6, Math.PI, 0, true);
    }
    c.strokeStyle = col;
    c.lineWidth = 1.8;
    c.stroke();
  }

  private particles(): void {
    const c = this.ctx;
    for (const p of this.parts) {
      const a = Math.max(0, p.life / p.max);
      c.globalAlpha = Math.min(1, a * 1.4);
      if (p.text) {
        this.text(p.text, p.x, p.y, p.size, p.color, "center");
      } else if (p.ring) {
        c.beginPath();
        c.arc(p.x, p.y, p.ring * (1 - a) + 4, 0, Math.PI * 2);
        c.strokeStyle = p.color;
        c.lineWidth = p.size;
        c.stroke();
      } else if (p.len) {
        const dx = Math.cos(p.angle ?? 0) * p.len / 2;
        const dy = Math.sin(p.angle ?? 0) * p.len / 2;
        c.beginPath();
        c.moveTo(p.x - dx, p.y - dy);
        c.lineTo(p.x + dx, p.y + dy);
        c.strokeStyle = p.color;
        c.lineWidth = p.size;
        c.stroke();
      } else {
        c.fillStyle = p.color;
        c.fillRect(p.x - p.size / 2, p.y - p.size / 2, p.size, p.size);
      }
    }
    c.globalAlpha = 1;
  }

  text(s: string, x: number, y: number, size: number, color: string, align: CanvasTextAlign = "left", weight = 700): void {
    const c = this.ctx;
    c.font = `${weight} ${size}px ${FONT}`;
    c.textAlign = align;
    c.textBaseline = "middle";
    c.fillStyle = color;
    c.fillText(s, x, y);
  }

  private glowText(s: string, x: number, y: number, size: number, color: string): void {
    const c = this.ctx;
    c.font = `800 ${size}px ${FONT}`;
    c.textAlign = "center";
    c.textBaseline = "middle";
    c.strokeStyle = color;
    c.globalAlpha = 0.25;
    c.lineWidth = size / 8;
    c.strokeText(s, x, y);
    c.globalAlpha = 1;
    c.lineWidth = Math.max(1.5, size / 30);
    c.strokeText(s, x, y);
    c.fillStyle = "rgba(4,6,13,0.6)";
    c.fillText(s, x, y);
  }

  private dimmer(alpha = 0.6): void {
    this.ctx.fillStyle = `rgba(4,6,13,${alpha})`;
    this.ctx.fillRect(-20, -20, W + 40, H + 40);
  }

  /** Scores, ships, pods and streaks along the top; wave and best along the bottom. */
  hud(g: Game, best: number): void {
    const n = g.ships.length;
    const pw = n <= 2 ? 300 : W / n;
    const big = n <= 3 ? 28 : n <= 5 ? 22 : 17;
    g.ships.forEach((s, i) => {
      const right = n === 2 && i === 1;
      const x0 = n === 2 ? (right ? W - 20 : 20) : i * pw + (n === 1 ? 20 : 10);
      const align: CanvasTextAlign = right ? "right" : "left";
      const col = PLAYER_COLORS[s.id];
      const dir = right ? -1 : 1;
      this.ctx.globalAlpha = s.out ? 0.45 : 1;
      this.text(`P${s.id + 1}`, x0, 18, 13, col, align);
      this.text(fmt(s.score), x0 + dir * 30, 19, big, COLOR.text, align);
      if (s.out) this.text("OUT", x0, 42, 13, COLOR.dim, align);
      else {
        const shown = Math.min(s.lives, n > 5 ? 3 : 5);
        for (let k = 0; k < shown; k++) this.hull(s.id, x0 + dir * (8 + k * 17), 44, -Math.PI / 2, 0.55, 1.2);
        if (s.lives > shown) this.text(`+${s.lives - shown}`, x0 + dir * (8 + shown * 17), 44, 12, col, align);
      }
      // Blink readiness, power-up time and streak, on the third line.
      let bx = x0;
      const bar = (frac: number, color: string, w: number) => {
        const c = this.ctx;
        c.fillStyle = "rgba(255,255,255,0.12)";
        c.fillRect(right ? bx - w : bx, 62, w, 4);
        c.fillStyle = color;
        c.fillRect(right ? bx - w * frac : bx, 62, w * frac, 4);
        bx += dir * (w + 6);
      };
      if (!s.out) {
        bar(1 - s.blinkCool / BLINK.cool, s.blinkCool > 0 ? COLOR.dim : col, 26);
        if (s.power) bar(s.powerTime / 10, COLOR.pod[s.power], 40);
        if (s.shield) bar(1, COLOR.pod.shield, 10);
        const m = multiplier(s, g.time);
        if (m > 1) this.text(`×${m}`, bx + dir * 4, 64, 14, col, align);
      }
      this.ctx.globalAlpha = 1;
    });
    this.text(`WAVE ${Math.max(1, g.wave)}   BEST ${fmt(Math.max(best, ...g.ships.map((s) => s.score)))}`, W / 2, H - 16, 14, COLOR.dim, "center", 600);
    if (this.banner) {
      this.ctx.globalAlpha = Math.min(1, this.banner.t * 2);
      this.glowText(this.banner.text, W / 2, H / 2 - 20, 56, COLOR.text);
      if (this.banner.sub) this.text(this.banner.sub, W / 2, H / 2 + 28, 18, COLOR.dim, "center", 600);
      this.ctx.globalAlpha = 1;
    }
  }

  paused(): void {
    this.dimmer(0.55);
    this.glowText("PAUSED", W / 2, H / 2 - 30, 64, COLOR.text);
    this.text("P / START resume   ·   ESC quit to title", W / 2, H / 2 + 30, 18, COLOR.dim, "center", 600);
  }

  title(sel: number, t: number, scores: Entry[], touch: boolean): void {
    this.dimmer(0.35);
    const pulse = 0.85 + 0.15 * Math.sin(t * 2);
    this.ctx.globalAlpha = pulse;
    this.glowText("SHATTERBELT", W / 2, 170, 104, "#8fe9ff");
    this.ctx.globalAlpha = 1;
    this.text("Break the belt. Mind your wingmates.", W / 2, 245, 20, COLOR.dim, "center", 600);
    this.text("1 TO 9 PLAYERS", W / 2, 285, 16, PLAYER_COLORS[1], "center");
    MENU_ITEMS.forEach((item, i) => {
      const r = menuRect(i);
      const on = i === sel;
      const c = this.ctx;
      c.beginPath();
      c.rect(r.x, r.y, r.w, r.h);
      this.glow(on ? "#8fe9ff" : "rgba(143,233,255,0.25)", on ? 2 : 1, on ? "rgba(20,50,80,0.6)" : "rgba(4,6,13,0.5)");
      this.text(item, W / 2, r.y + r.h / 2 + 1, 26, on ? COLOR.text : COLOR.dim, "center");
    });
    this.text(sel === 0 ? "Everyone against the rocks. Your shots pass through friends; your hulls don't." : "Every ship for itself. Shots hit other pilots: +500 for a takedown.", W / 2, 478, 16, COLOR.text, "center", 500);

    // Lower panel: how to play and the best pilots, side by side.
    const top = 530;
    this.text("HOW TO PLAY", 120, top, 16, PLAYER_COLORS[0]);
    const how = [
      "Break every rock to clear the wave.",
      "Big rocks split; crystal splits in three",
      "  and may drop a pod: rapid, spread, shield.",
      "Iron rocks take two hits.",
      "Blink jumps you ahead, briefly untouchable.",
      "Ships that touch are both lost.",
      "Hits in quick succession build a ×2–×4 streak.",
      `A new ship every ${fmt(SHIP.extraEvery)} points.`,
    ];
    how.forEach((l, i) => this.text(l, 120, top + 30 + i * 24, 15, COLOR.text, "left", 500));
    this.text("BEST PILOTS", 760, top, 16, PLAYER_COLORS[1]);
    if (scores.length === 0) this.text("No scores yet. Be the first.", 760, top + 30, 15, COLOR.dim, "left", 500);
    scores.slice(0, 8).forEach((e, i) => {
      const y = top + 30 + i * 24;
      this.text(`${String(i + 1).padStart(2)}. ${e.name.padEnd(3)}`, 760, y, 15, COLOR.text, "left", 600);
      this.text(fmt(e.score), 1000, y, 15, COLOR.text, "right", 600);
      this.text(`W${e.wave} ${e.mode === "versus" ? "VS" : e.players > 1 ? `${e.players}P` : "1P"}`, 1020, y, 13, COLOR.dim, "left", 500);
    });
    const go = touch ? "TAP A MODE" : "↑ ↓ choose · ENTER or SPACE select · M sound";
    this.ctx.globalAlpha = 0.6 + 0.4 * Math.sin(t * 4);
    this.text(go, W / 2, H - 22, 15, COLOR.dim, "center", 600);
    this.ctx.globalAlpha = 1;
  }

  lobby(mode: string, slots: string[], deviceLabels: string[], t: number, touch: boolean): void {
    this.dimmer(0.6);
    this.glowText(mode === "versus" ? "VERSUS" : "CO-OP", W / 2, 62, 52, "#8fe9ff");
    this.text("Each pilot: press your FIRE to join.", W / 2, 112, 18, COLOR.text, "center", 600);
    const cw = 360;
    const ch = 92;
    for (let i = 0; i < MAX_PLAYERS; i++) {
      const col = i % 3;
      const row = Math.floor(i / 3);
      const x = W / 2 - cw * 1.5 + col * cw + 8;
      const y = 140 + row * (ch + 10);
      const joined = i < slots.length;
      const c = this.ctx;
      c.beginPath();
      c.rect(x, y, cw - 16, ch);
      this.glow(joined ? PLAYER_COLORS[i] : "rgba(127,138,163,0.3)", joined ? 1.5 : 1, joined ? "rgba(10,16,30,0.75)" : "rgba(4,6,13,0.4)");
      if (joined) {
        this.hull(i, x + 40, y + ch / 2, -Math.PI / 2 + Math.sin(t * 2 + i) * 0.3, 1.4);
        this.text(`P${i + 1}`, x + 80, y + 28, 22, PLAYER_COLORS[i]);
        this.text(deviceLabels[i], x + 80, y + 60, 12, COLOR.text, "left", 500);
      } else {
        this.ctx.globalAlpha = i === slots.length ? 0.6 + 0.4 * Math.sin(t * 5) : 0.35;
        this.text(i === slots.length ? "PRESS FIRE TO JOIN" : `P${i + 1}`, x + (cw - 16) / 2, y + ch / 2, 15, COLOR.dim, "center", 600);
        this.ctx.globalAlpha = 1;
      }
    }
    const ky = 470;
    this.text("FIRE TO JOIN WITH", W / 2, ky, 14, PLAYER_COLORS[1], "center");
    const rows = [
      "Keyboard:  Q (keys W A S D)   ·   R (keys T F G H)   ·   U (keys I J K L)",
      "           ENTER (arrow keys)   ·   NUMPAD 0 (numpad 8 4 5 6)",
      "Gamepad:   A button (stick or d-pad turns, up or right trigger thrusts, B blinks)",
      `Touch:     the FIRE button${touch ? "" : " (on phones and tablets)"}`,
      "Thrust is the top key, turn with the side keys, blink with the bottom key.",
    ];
    rows.forEach((r, i) => this.text(r, 150, ky + 34 + i * 26, 15, COLOR.text, "left", 500));
    const ready = slots.length > 0;
    this.ctx.globalAlpha = ready ? 0.7 + 0.3 * Math.sin(t * 5) : 0.6;
    this.text(
      ready ? (touch ? "TAP HERE TO LAUNCH  ·  SPACE / START" : "SPACE or START to launch   ·   ESC back") : "Playing alone on the keyboard? Just press SPACE.   ·   ESC back",
      W / 2, H - 50, 20, ready ? COLOR.text : COLOR.dim, "center",
    );
    this.ctx.globalAlpha = 1;
  }

  gameOver(g: Game, t: number): void {
    this.dimmer(Math.min(0.65, t * 0.6));
    this.glowText("GAME OVER", W / 2, 150, 80, "#ff9f9f");
    const ranked = standings(g);
    let y = 240;
    if (g.ships.length > 1) {
      const top = ranked.filter((s) => s.score === ranked[0].score);
      const head = g.mode === "versus"
        ? (top.length > 1 ? "DRAW" : `P${top[0].id + 1} WINS`)
        : `TOGETHER: ${fmt(g.ships.reduce((a, s) => a + s.score, 0))}`;
      this.text(head, W / 2, y, 30, top.length > 1 && g.mode === "versus" ? COLOR.text : PLAYER_COLORS[top[0].id], "center");
      y += 50;
    }
    const rowH = g.ships.length > 6 ? 32 : 40;
    ranked.forEach((s, i) => {
      const yy = y + i * rowH;
      this.hull(s.id, W / 2 - 200, yy, -Math.PI / 2, 0.8, 1.5);
      this.text(`P${s.id + 1}`, W / 2 - 170, yy, 20, PLAYER_COLORS[s.id]);
      this.text(fmt(s.score), W / 2 + 200, yy, 22, COLOR.text, "right");
    });
    this.text(`Reached wave ${g.wave}`, W / 2, Math.min(H - 70, y + ranked.length * rowH + 20), 16, COLOR.dim, "center", 600);
    if (t > 1.2) {
      this.ctx.globalAlpha = 0.6 + 0.4 * Math.sin(t * 4);
      this.text("FIRE, ENTER or TAP to continue", W / 2, H - 30, 16, COLOR.dim, "center", 600);
      this.ctx.globalAlpha = 1;
    }
  }

  entry(id: number, score: number, letters: string[], pos: number, t: number): void {
    this.dimmer(0.7);
    this.glowText("NEW BEST PILOT", W / 2, 170, 64, PLAYER_COLORS[id]);
    this.text(`P${id + 1}   ${fmt(score)}`, W / 2, 250, 28, COLOR.text, "center");
    this.text("Your initials:", W / 2, 320, 18, COLOR.dim, "center", 600);
    letters.forEach((l, i) => {
      const x = W / 2 + (i - 1) * 90;
      const on = i === pos;
      this.text(l, x, 400, 72, on ? PLAYER_COLORS[id] : COLOR.text, "center", 800);
      if (on && Math.floor(t * 3) % 2 === 0) {
        this.ctx.fillStyle = PLAYER_COLORS[id];
        this.ctx.fillRect(x - 28, 445, 56, 5);
      }
    });
    this.text("Type letters, ENTER to save, BACKSPACE to go back.", W / 2, 520, 16, COLOR.text, "center", 500);
    this.text("Gamepad or touch: ← → change the letter, FIRE next, blink back.", W / 2, 550, 16, COLOR.text, "center", 500);
  }
}

function wrapDelta(d: number, size: number): number {
  if (d > size / 2) return d - size;
  if (d < -size / 2) return d + size;
  return d;
}
