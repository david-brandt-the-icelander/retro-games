// The board: a 152×152 pixel canvas (8×8 squares of 16 pixels, inside a 12-pixel frame),
// scaled up in whole pixels. It draws the position, the last move, check, the selected piece and
// its moves, slides pieces as they move and breaks captured ones into pixels. Players move by
// tapping a piece and then a square, by dragging, or with the arrow keys and Enter.
import type { Chess, Move, Square } from "chess.js";
import { sounds } from "./sound";
import { glyph, pixels, sprite, type PieceColor, type PieceType } from "./sprites";

const SQ = 16;
const BORDER = 12;
const SIZE = SQ * 8 + BORDER * 2;
const FILES = "abcdefgh";

const COLORS = {
  light: "#e9c995",
  lightDither: "#e2bf88",
  dark: "#a7674a",
  darkDither: "#9c5f43",
  frame: "#33213a",
  frameLight: "#4f3658",
  frameDark: "#1c1222",
  coord: "#c9a6d6",
  last: "rgba(255, 214, 64, 0.42)",
  select: "#ffcf5a",
  hint: "rgba(29, 20, 48, 0.38)",
  check: "#ff4058",
  cursor: "#7ef0ff",
};

interface Anim { type: PieceType; color: PieceColor; from: Square; to: Square; start: number; dur: number }
interface Particle { x: number; y: number; vx: number; vy: number; c: string; life: number }
interface Picker { from: Square; to: Square; color: PieceColor }

const ease = (t: number) => 1 - (1 - t) ** 3;

export class Board {
  readonly canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private chess: Chess | null = null;
  private last: { from: Square; to: Square } | null = null;
  private anims: Anim[] = [];
  private particles: Particle[] = [];
  private selected: Square | null = null;
  private targets: Move[] = [];
  private drag: { from: Square; x: number; y: number; moved: boolean } | null = null;
  private picker: Picker | null = null;
  private cursor: Square | null = null;
  private scale = 4;
  private raf = 0;
  /** Which colour the player may move now, or null when it isn't their turn. */
  movable: PieceColor | null = null;
  /** Called with a UCI move ("e2e4", "e7e8q") when the player makes one. */
  onMove: (uci: string) => void = () => undefined;
  flipped = false;

  constructor(host: HTMLElement) {
    this.canvas = document.createElement("canvas");
    this.canvas.className = "board";
    this.canvas.tabIndex = 0;
    this.canvas.setAttribute("role", "application");
    this.canvas.setAttribute("aria-label", "Chess board. Arrow keys move the cursor, Enter picks up and puts down a piece.");
    host.appendChild(this.canvas);
    this.ctx = this.canvas.getContext("2d")!;
    new ResizeObserver(() => this.resize()).observe(host);
    this.canvas.addEventListener("pointerdown", (e) => this.down(e));
    this.canvas.addEventListener("pointermove", (e) => this.moveTo(e));
    this.canvas.addEventListener("pointerup", (e) => this.up(e));
    this.canvas.addEventListener("pointercancel", () => { this.drag = null; });
    this.canvas.addEventListener("keydown", (e) => this.key(e));
    this.loop();
  }

  destroy(): void {
    cancelAnimationFrame(this.raf);
    this.canvas.remove();
  }

  private resize(): void {
    const host = this.canvas.parentElement;
    if (!host) return;
    const css = host.clientWidth;
    const dpr = window.devicePixelRatio || 1;
    this.scale = Math.max(1, Math.floor((css * dpr) / SIZE));
    this.canvas.width = this.canvas.height = SIZE * this.scale;
  }

  /**
   * Shows a position. `move` is the move that led to it (verbose, from chess.js), to mark it and,
   * when `animate`, to slide the piece and break up what it captured.
   */
  show(chess: Chess, move: Move | null, animate: boolean): void {
    this.chess = chess;
    this.last = move ? { from: move.from, to: move.to } : null;
    this.selected = null;
    this.targets = [];
    this.picker = null;
    if (move && animate) {
      const now = performance.now();
      this.anims = [{ type: move.promotion ? "p" : (move.piece as PieceType), color: move.color, from: move.from, to: move.to, start: now, dur: 170 }];
      if (move.flags.includes("k") || move.flags.includes("q")) {
        const rank = move.from[1];
        const [rf, rt] = move.flags.includes("k") ? ["h", "f"] : ["a", "d"];
        this.anims.push({ type: "r", color: move.color, from: `${rf}${rank}` as Square, to: `${rt}${rank}` as Square, start: now, dur: 170 });
      }
      if (move.captured) {
        const at = move.flags.includes("e") ? (`${move.to[0]}${move.from[1]}` as Square) : move.to;
        this.shatter(move.captured as PieceType, move.color === "w" ? "b" : "w", at, 120);
      }
      if (chess.inCheck()) sounds.check();
      else if (move.captured) sounds.capture();
      else sounds.move();
    } else {
      this.anims = [];
    }
  }

  // ── Geometry ──

  private squareAt(px: number, py: number): Square | null {
    const x = Math.floor((px - BORDER) / SQ), y = Math.floor((py - BORDER) / SQ);
    if (x < 0 || x > 7 || y < 0 || y > 7) return null;
    const file = this.flipped ? 7 - x : x, rank = this.flipped ? y : 7 - y;
    return `${FILES[file]}${rank + 1}` as Square;
  }

  private origin(sq: Square): { x: number; y: number } {
    const file = FILES.indexOf(sq[0]), rank = Number(sq[1]) - 1;
    const x = this.flipped ? 7 - file : file, y = this.flipped ? rank : 7 - rank;
    return { x: BORDER + x * SQ, y: BORDER + y * SQ };
  }

  private logical(e: PointerEvent): { x: number; y: number } {
    const r = this.canvas.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * SIZE, y: ((e.clientY - r.top) / r.height) * SIZE };
  }

  // ── Input ──

  private canPick(sq: Square): boolean {
    const p = this.chess?.get(sq);
    return Boolean(p && this.movable && p.color === this.movable && this.chess!.turn() === this.movable);
  }

  private pick(sq: Square): void {
    this.selected = sq;
    this.targets = this.chess!.moves({ square: sq, verbose: true });
    sounds.select();
  }

  /** Tries to move the selected piece to `to`. True if that was one of its moves. */
  private tryMove(to: Square): boolean {
    const from = this.selected;
    if (!from) return false;
    const options = this.targets.filter((m) => m.to === to);
    if (!options.length) return false;
    if (options.some((m) => m.promotion)) {
      this.picker = { from, to, color: options[0].color };
      return true;
    }
    this.selected = null;
    this.targets = [];
    this.onMove(from + to);
    return true;
  }

  private down(e: PointerEvent): void {
    if (!this.chess) return;
    this.canvas.focus({ preventScroll: true });
    const p = this.logical(e);
    if (this.picker) { this.choosePromotion(p); return; }
    const sq = this.squareAt(p.x, p.y);
    if (!sq) return;
    this.cursor = null;
    if (this.selected && sq !== this.selected && this.tryMove(sq)) return;
    if (this.canPick(sq)) {
      if (this.selected !== sq) this.pick(sq);
      this.drag = { from: sq, x: p.x, y: p.y, moved: false };
      this.canvas.setPointerCapture(e.pointerId);
    } else {
      if (this.selected) sounds.illegal();
      this.selected = null;
      this.targets = [];
    }
  }

  private moveTo(e: PointerEvent): void {
    if (!this.drag) return;
    const p = this.logical(e);
    if (Math.abs(p.x - this.drag.x) + Math.abs(p.y - this.drag.y) > 3) this.drag.moved = true;
    this.drag.x = p.x;
    this.drag.y = p.y;
  }

  private up(e: PointerEvent): void {
    if (!this.drag) return;
    const d = this.drag;
    this.drag = null;
    if (!d.moved) return;
    const p = this.logical(e);
    const sq = this.squareAt(p.x, p.y);
    if (sq && sq !== d.from && this.tryMove(sq)) return;
    if (sq && sq !== d.from) sounds.illegal();
  }

  private key(e: KeyboardEvent): void {
    if (!this.chess) return;
    const dirs: Record<string, [number, number]> = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, 1], ArrowDown: [0, -1] };
    if (this.picker) {
      const order = ["q", "r", "b", "n"];
      const n = Number(e.key);
      if (n >= 1 && n <= 4) { this.finishPromotion(order[n - 1]); e.preventDefault(); }
      if (e.key === "Escape") { this.picker = null; e.preventDefault(); }
      return;
    }
    if (dirs[e.key]) {
      e.preventDefault();
      const cur = this.cursor ?? this.selected ?? (this.flipped ? "e8" : "e2");
      let f = FILES.indexOf(cur[0]), r = Number(cur[1]) - 1;
      const [dx, dy] = dirs[e.key];
      f = Math.min(7, Math.max(0, f + (this.flipped ? -dx : dx)));
      r = Math.min(7, Math.max(0, r + (this.flipped ? -dy : dy)));
      this.cursor = `${FILES[f]}${r + 1}` as Square;
    } else if ((e.key === "Enter" || e.key === " ") && this.cursor) {
      e.preventDefault();
      if (this.selected && this.cursor !== this.selected && this.tryMove(this.cursor)) return;
      if (this.canPick(this.cursor)) this.pick(this.cursor);
      else { this.selected = null; this.targets = []; }
    } else if (e.key === "Escape") {
      this.selected = null;
      this.targets = [];
    }
  }

  private pickerSquares(pk: Picker): Square[] {
    const file = pk.to[0];
    const ranks = pk.color === "w" ? ["8", "7", "6", "5"] : ["1", "2", "3", "4"];
    return ranks.map((r) => `${file}${r}` as Square);
  }

  private choosePromotion(p: { x: number; y: number }): void {
    const pk = this.picker!;
    const sq = this.squareAt(p.x, p.y);
    const i = sq ? this.pickerSquares(pk).indexOf(sq) : -1;
    if (i < 0) { this.picker = null; return; }
    this.finishPromotion(["q", "r", "b", "n"][i]);
  }

  private finishPromotion(piece: string): void {
    const pk = this.picker!;
    this.picker = null;
    this.selected = null;
    this.targets = [];
    this.onMove(pk.from + pk.to + piece);
  }

  // ── Effects ──

  private shatter(type: PieceType, color: PieceColor, sq: Square, delay: number): void {
    const o = this.origin(sq);
    const born = performance.now() + delay;
    for (const px of pixels(type, color)) {
      if ((px.x + px.y) % 2) continue;
      const dx = px.x - 8, dy = px.y - 10;
      this.particles.push({
        x: o.x + px.x, y: o.y + px.y,
        vx: dx * 0.012 + (Math.random() - 0.5) * 0.06, vy: dy * 0.01 - 0.06 - Math.random() * 0.05,
        c: px.c, life: born,
      });
    }
  }

  // ── Drawing ──

  private loop = (): void => {
    this.raf = requestAnimationFrame(this.loop);
    if (!this.canvas.isConnected || !this.canvas.width) return;
    this.draw(performance.now());
  };

  private draw(now: number): void {
    const ctx = this.ctx;
    ctx.setTransform(this.scale, 0, 0, this.scale, 0, 0);
    ctx.imageSmoothingEnabled = false;
    this.drawFrame(ctx);
    for (let y = 0; y < 8; y++) {
      for (let x = 0; x < 8; x++) {
        const light = (x + y) % 2 === 0;
        const px = BORDER + x * SQ, py = BORDER + y * SQ;
        ctx.fillStyle = light ? COLORS.light : COLORS.dark;
        ctx.fillRect(px, py, SQ, SQ);
        // A sparse dither gives the squares some grain.
        ctx.fillStyle = light ? COLORS.lightDither : COLORS.darkDither;
        for (let i = 0; i < SQ; i += 4) for (let j = (i / 4) % 2 ? 2 : 0; j < SQ; j += 4) ctx.fillRect(px + j, py + i, 1, 1);
      }
    }
    if (!this.chess) return;

    if (this.last) for (const sq of [this.last.from, this.last.to]) { const o = this.origin(sq); ctx.fillStyle = COLORS.last; ctx.fillRect(o.x, o.y, SQ, SQ); }

    // The king in check glows red.
    if (this.chess.inCheck()) {
      const king = this.chess.findPiece({ type: "k", color: this.chess.turn() })[0];
      if (king) {
        const o = this.origin(king);
        const pulse = 0.45 + 0.25 * Math.sin(now / 160);
        ctx.fillStyle = `rgba(255, 64, 88, ${pulse})`;
        ctx.fillRect(o.x, o.y, SQ, SQ);
      }
    }

    if (this.selected) this.corners(ctx, this.origin(this.selected), COLORS.select, now);

    // Pieces, leaving out any that are sliding or being dragged.
    const moving = new Set(this.anims.filter((a) => now < a.start + a.dur).map((a) => a.to));
    const dragging = this.drag?.moved ? this.drag.from : null;
    const board = this.chess.board();
    for (const row of board) for (const p of row) {
      if (!p || moving.has(p.square) || p.square === dragging) continue;
      const o = this.origin(p.square);
      this.piece(ctx, p.type, p.color, o.x, o.y);
    }

    // Where the selected piece can go: a dot on empty squares, corner marks on captures.
    for (const m of this.targets) {
      const o = this.origin(m.to);
      ctx.fillStyle = COLORS.hint;
      if (m.captured) {
        for (const [cx, cy] of [[0, 0], [SQ - 3, 0], [0, SQ - 3], [SQ - 3, SQ - 3]]) {
          ctx.fillRect(o.x + cx, o.y + cy, 3, 1);
          ctx.fillRect(o.x + cx + (cx ? 2 : 0), o.y + cy, 1, 3);
        }
      } else {
        ctx.fillRect(o.x + 6, o.y + 7, 4, 2);
        ctx.fillRect(o.x + 7, o.y + 6, 2, 4);
      }
    }

    for (const a of this.anims) {
      const t = Math.min(1, Math.max(0, (now - a.start) / a.dur));
      if (t >= 1) continue;
      const f = this.origin(a.from), to = this.origin(a.to), k = ease(t);
      const x = Math.round(f.x + (to.x - f.x) * k), y = Math.round(f.y + (to.y - f.y) * k - Math.sin(Math.PI * t) * 3);
      this.piece(ctx, a.type, a.color, x, y);
    }
    this.anims = this.anims.filter((a) => now < a.start + a.dur);

    this.drawParticles(ctx, now);

    if (this.drag?.moved) {
      const p = this.chess.get(this.drag.from);
      if (p) {
        const hover = this.squareAt(this.drag.x, this.drag.y);
        if (hover && this.targets.some((m) => m.to === hover)) this.corners(ctx, this.origin(hover), COLORS.cursor, now);
        this.piece(ctx, p.type, p.color, Math.round(this.drag.x - 8), Math.round(this.drag.y - 12), true);
      }
    }

    if (this.cursor) this.corners(ctx, this.origin(this.cursor), COLORS.cursor, now);
    if (this.picker) this.drawPicker(ctx, this.picker);
  }

  private drawFrame(ctx: CanvasRenderingContext2D): void {
    ctx.fillStyle = COLORS.frameDark;
    ctx.fillRect(0, 0, SIZE, SIZE);
    ctx.fillStyle = COLORS.frame;
    ctx.fillRect(1, 1, SIZE - 2, SIZE - 2);
    ctx.fillStyle = COLORS.frameLight;
    ctx.fillRect(1, 1, SIZE - 2, 1);
    ctx.fillRect(1, 1, 1, SIZE - 2);
    ctx.fillStyle = COLORS.frameDark;
    ctx.fillRect(BORDER - 1, BORDER - 1, SQ * 8 + 2, SQ * 8 + 2);
    for (let i = 0; i < 8; i++) {
      const file = FILES[this.flipped ? 7 - i : i];
      const rank = String(this.flipped ? i + 1 : 8 - i);
      glyph(ctx, file, BORDER + i * SQ + 6, SIZE - BORDER + 4, COLORS.coord);
      glyph(ctx, rank, 4, BORDER + i * SQ + 5, COLORS.coord);
    }
  }

  private piece(ctx: CanvasRenderingContext2D, type: PieceType, color: PieceColor, x: number, y: number, lifted = false): void {
    // A soft shadow under the piece; a bigger one when it is lifted.
    ctx.fillStyle = "rgba(20, 8, 24, 0.28)";
    const sy = lifted ? y + 15 : y + 14;
    ctx.fillRect(x + 4, sy, 8, 1);
    ctx.fillRect(x + 3, sy - 1, 10, 1);
    ctx.drawImage(sprite(type, color), x, lifted ? y - 1 : y);
  }

  private corners(ctx: CanvasRenderingContext2D, o: { x: number; y: number }, color: string, now: number): void {
    const inset = Math.sin(now / 140) > 0 ? 0 : 1;
    ctx.fillStyle = color;
    const a = o.x + inset, b = o.y + inset, c = o.x + SQ - 1 - inset, d = o.y + SQ - 1 - inset;
    for (const [x, y, sx, sy] of [[a, b, 1, 1], [c, b, -1, 1], [a, d, 1, -1], [c, d, -1, -1]]) {
      ctx.fillRect(Math.min(x, x + sx * 3), y, 4, 1);
      ctx.fillRect(x, Math.min(y, y + sy * 3), 1, 4);
    }
  }

  private drawParticles(ctx: CanvasRenderingContext2D, now: number): void {
    const alive: Particle[] = [];
    for (const p of this.particles) {
      const age = now - p.life;
      if (age < 0) { alive.push(p); ctx.fillStyle = p.c; ctx.fillRect(Math.round(p.x), Math.round(p.y), 1, 1); continue; }
      if (age > 650) continue;
      const x = p.x + p.vx * age, y = p.y + p.vy * age + 0.00035 * age * age;
      ctx.globalAlpha = 1 - age / 650;
      ctx.fillStyle = p.c;
      ctx.fillRect(Math.round(x), Math.round(y), 1, 1);
      alive.push(p);
    }
    ctx.globalAlpha = 1;
    this.particles = alive;
  }

  private drawPicker(ctx: CanvasRenderingContext2D, pk: Picker): void {
    ctx.fillStyle = "rgba(12, 6, 20, 0.55)";
    ctx.fillRect(BORDER, BORDER, SQ * 8, SQ * 8);
    const types: PieceType[] = ["q", "r", "b", "n"];
    this.pickerSquares(pk).forEach((sq, i) => {
      const o = this.origin(sq);
      ctx.fillStyle = "#2b1f42";
      ctx.fillRect(o.x - 1, o.y - 1, SQ + 2, SQ + 2);
      ctx.fillStyle = "#ffcf5a";
      ctx.fillRect(o.x, o.y, SQ, SQ);
      ctx.fillStyle = "#fff1c4";
      ctx.fillRect(o.x + 1, o.y + 1, SQ - 2, SQ - 2);
      ctx.drawImage(sprite(types[i], pk.color), o.x, o.y);
    });
  }
}
