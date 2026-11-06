// Keys, touches and the mouse, turned into a Control for each paddle.
import { H, IDLE, W, type Control } from "../engine/rules";

const UP_LEFT = new Set(["KeyW"]);
const DOWN_LEFT = new Set(["KeyS"]);
const UP_RIGHT = new Set(["ArrowUp"]);
const DOWN_RIGHT = new Set(["ArrowDown"]);

export class Input {
  private held = new Set<string>();
  /** Fingers, pens and pressed mouse buttons on the table, in table coordinates. */
  private pointers = new Map<number, { x: number; y: number }>();
  /** Where an unpressed mouse is hovering, for one-player games; cleared when a key is pressed. */
  private hover: number | null = null;

  constructor(private canvas: HTMLCanvasElement) {
    canvas.addEventListener("pointerdown", (e) => {
      try { canvas.setPointerCapture(e.pointerId); } catch { /* not capturable */ }
      this.pointers.set(e.pointerId, this.at(e));
      e.preventDefault();
    });
    canvas.addEventListener("pointermove", (e) => {
      if (this.pointers.has(e.pointerId)) this.pointers.set(e.pointerId, this.at(e));
      else if (e.pointerType === "mouse") this.hover = this.at(e).y;
    });
    const up = (e: PointerEvent) => this.pointers.delete(e.pointerId);
    canvas.addEventListener("pointerup", up);
    canvas.addEventListener("pointercancel", up);
    canvas.addEventListener("pointerleave", (e) => { if (e.pointerType === "mouse") this.hover = null; });
    window.addEventListener("blur", () => this.reset());
  }

  private at(e: PointerEvent): { x: number; y: number } {
    const r = this.canvas.getBoundingClientRect();
    return { x: ((e.clientX - r.left) / r.width) * W, y: ((e.clientY - r.top) / r.height) * H };
  }

  /** Returns true when the key moves a paddle, so the page shouldn't scroll. */
  key(code: string, down: boolean): boolean {
    const paddle = UP_LEFT.has(code) || DOWN_LEFT.has(code) || UP_RIGHT.has(code) || DOWN_RIGHT.has(code);
    if (down) { this.held.add(code); if (paddle) this.hover = null; }
    else this.held.delete(code);
    return paddle;
  }

  reset(): void {
    this.held.clear();
    this.pointers.clear();
    this.hover = null;
  }

  private dir(up: Set<string>, down: Set<string>): -1 | 0 | 1 {
    const u = [...up].some((k) => this.held.has(k));
    const d = [...down].some((k) => this.held.has(k));
    return u === d ? 0 : u ? -1 : 1;
  }

  private pointer(side: "left" | "right" | "any"): number | null {
    let y: number | null = null;
    for (const p of this.pointers.values()) {
      if (side === "any" || (side === "left") === (p.x < W / 2)) y = p.y;
    }
    return y;
  }

  /** The human's paddle in a one-player game: any keys, any finger, or the mouse. */
  one(): Control {
    const dir = this.dir(new Set([...UP_LEFT, ...UP_RIGHT]), new Set([...DOWN_LEFT, ...DOWN_RIGHT]));
    if (dir) return { dir, target: null };
    const y = this.pointer("any") ?? this.hover;
    return y === null ? IDLE : { dir: 0, target: y };
  }

  /** Both paddles in a two-player game: W/S and the left half; the arrows and the right half. */
  two(): [Control, Control] {
    const side = (up: Set<string>, down: Set<string>, half: "left" | "right"): Control => {
      const dir = this.dir(up, down);
      if (dir) return { dir, target: null };
      const y = this.pointer(half);
      return y === null ? IDLE : { dir: 0, target: y };
    };
    return [side(UP_LEFT, DOWN_LEFT, "left"), side(UP_RIGHT, DOWN_RIGHT, "right")];
  }
}
