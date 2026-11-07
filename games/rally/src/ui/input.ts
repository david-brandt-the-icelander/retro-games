// Keys, touches and the mouse, turned into this browser's player's Control. One player per browser:
// friends play each other online, each on their own device (the multiplayer page).
import { H, IDLE, W, type Control } from "../engine/rules";

const UP = ["KeyW", "ArrowUp"];
const DOWN = ["KeyS", "ArrowDown"];

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
    const paddle = UP.includes(code) || DOWN.includes(code);
    if (down) { this.held.add(code); if (paddle) this.hover = null; }
    else this.held.delete(code);
    return paddle;
  }

  reset(): void {
    this.held.clear();
    this.pointers.clear();
    this.hover = null;
  }

  /** The player's paddle: either key pair, any finger, or the mouse. */
  one(): Control {
    const u = UP.some((k) => this.held.has(k));
    const d = DOWN.some((k) => this.held.has(k));
    if (u !== d) return { dir: u ? -1 : 1, target: null };
    let y: number | null = null;
    for (const p of this.pointers.values()) y = p.y; // the latest finger
    y ??= this.hover;
    return y === null ? IDLE : { dir: 0, target: y };
  }
}
