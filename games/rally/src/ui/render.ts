// Draws the table, the paddles and the ball onto the canvas.
import { BALL, H, PADDLE_H, PADDLE_INSET, PADDLE_W, W, type GameEvent, type Side, type State } from "../engine/rules";

const COLOURS = {
  table: "#0d2a55",
  tableEdge: "#0a2148",
  line: "#e8f0ff",
  side: ["#ff7a5c", "#4fd8ff"],
  ball: "#fff3c4",
  hint: "rgba(232, 240, 255, 0.55)",
};

const TRAIL = 7;
const EDGE = 8;

export class Renderer {
  private ctx: CanvasRenderingContext2D;
  private trail: { x: number; y: number }[] = [];
  /** Seconds of glow left on each paddle after a return. */
  private flash: [number, number] = [0, 0];

  constructor(private canvas: HTMLCanvasElement) {
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("no 2D canvas");
    this.ctx = ctx;
  }

  /**
   * Matches the canvas's pixels to its size on screen, for sharp edges on any display. At most 2
   * pixels per CSS pixel: a 3x phone would otherwise fill more than twice the pixels every frame
   * (3.5 million at full width) for no visible gain on flat shapes.
   */
  resize(cssWidth: number): void {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = Math.round(cssWidth * dpr);
    const h = Math.round((cssWidth * H / W) * dpr);
    if (this.canvas.width !== w || this.canvas.height !== h) {
      this.canvas.width = w;
      this.canvas.height = h;
    }
  }

  events(events: GameEvent[]): void {
    for (const e of events) {
      if (e.kind === "paddle") this.flash[e.side] = 0.18;
      if (e.kind === "serve") this.trail = [];
    }
  }

  draw(s: State, dt: number, hints: [string, string] | null): void {
    const { ctx, canvas } = this;
    ctx.setTransform(canvas.width / W, 0, 0, canvas.height / H, 0, 0);
    this.flash = [Math.max(0, this.flash[0] - dt), Math.max(0, this.flash[1] - dt)];

    // The table: a blue top with white edges, a faint centre line along its length, and the net across it.
    const g = ctx.createLinearGradient(0, 0, 0, H);
    g.addColorStop(0, COLOURS.table);
    g.addColorStop(1, COLOURS.tableEdge);
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, W, H);
    ctx.strokeStyle = COLOURS.line;
    ctx.globalAlpha = 0.85;
    ctx.lineWidth = 3;
    ctx.strokeRect(EDGE, EDGE, W - 2 * EDGE, H - 2 * EDGE);
    ctx.globalAlpha = 0.18;
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(EDGE, H / 2);
    ctx.lineTo(W - EDGE, H / 2);
    ctx.stroke();
    ctx.globalAlpha = 0.08;
    ctx.fillStyle = COLOURS.line;
    ctx.fillRect(W / 2 - 7, 0, 14, H);
    ctx.globalAlpha = 0.9;
    ctx.fillRect(W / 2 - 1.5, 0, 3, H);
    ctx.globalAlpha = 1;
    for (const y of [0, H - 6]) ctx.fillRect(W / 2 - 5, y, 10, 6);

    if (hints) {
      ctx.fillStyle = COLOURS.hint;
      ctx.font = "700 18px ui-rounded, system-ui, sans-serif";
      ctx.textAlign = "center";
      ctx.fillText(hints[0], W / 4, H - 40);
      ctx.fillText(hints[1], (3 * W) / 4, H - 40);
    }

    // The paddles, glowing a moment after each return.
    for (const side of [0, 1] as Side[]) {
      const x = side === 0 ? PADDLE_INSET : W - PADDLE_INSET - PADDLE_W;
      const y = s.paddles[side].y - PADDLE_H / 2;
      ctx.save();
      ctx.shadowColor = COLOURS.side[side];
      ctx.shadowBlur = 10 + 60 * this.flash[side];
      ctx.fillStyle = COLOURS.side[side];
      roundRect(ctx, x, y, PADDLE_W, PADDLE_H, PADDLE_W / 2);
      ctx.fill();
      ctx.restore();
    }

    // The ball, with a short fading trail while in play.
    const b = s.ball;
    const onTable = b.x > -BALL && b.x < W + BALL;
    if (s.phase === "play") {
      this.trail.push({ x: b.x, y: b.y });
      if (this.trail.length > TRAIL) this.trail.shift();
    } else if (s.phase !== "point") this.trail = [];
    this.trail.forEach((p, i) => {
      ctx.globalAlpha = ((i + 1) / (TRAIL + 1)) * 0.35;
      ctx.fillStyle = COLOURS.ball;
      ctx.beginPath();
      ctx.arc(p.x, p.y, (BALL / 2) * (0.5 + (0.5 * (i + 1)) / TRAIL), 0, Math.PI * 2);
      ctx.fill();
    });
    ctx.globalAlpha = 1;
    if (onTable && s.phase !== "over") {
      ctx.save();
      ctx.shadowColor = COLOURS.ball;
      ctx.shadowBlur = 14;
      ctx.fillStyle = COLOURS.ball;
      ctx.beginPath();
      ctx.arc(b.x, b.y, BALL / 2 + 0.5, 0, Math.PI * 2);
      ctx.fill();
      ctx.restore();
    }
  }
}

function roundRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, r: number): void {
  ctx.beginPath();
  ctx.moveTo(x + r, y);
  ctx.arcTo(x + w, y, x + w, y + h, r);
  ctx.arcTo(x + w, y + h, x, y + h, r);
  ctx.arcTo(x, y + h, x, y, r);
  ctx.arcTo(x, y, x + w, y, r);
  ctx.closePath();
}
