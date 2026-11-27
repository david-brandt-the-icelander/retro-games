// Keyboard, touch and gamepad, turned into the game's Input once a step. A direction is sent once, when it is
// chosen: the puffin remembers which way it was last pointed.
import type { Input } from "../engine/game";
import { DOWN, Dir, LEFT, RIGHT, UP } from "../engine/rules";

const KEYS: Record<string, Dir> = {
  ArrowUp: UP, KeyW: UP, ArrowRight: RIGHT, KeyD: RIGHT, ArrowDown: DOWN, KeyS: DOWN, ArrowLeft: LEFT, KeyA: LEFT,
};
const BUTTONS: Record<string, Dir> = { up: UP, right: RIGHT, down: DOWN, left: LEFT };
/** How far a finger must travel before it counts as a swipe, in CSS pixels. */
const SWIPE = 14;

export class Controls {
  private dir: Dir | -1 = -1;
  private start = false;
  private pause = false;
  private pad = { dir: -1 as Dir | -1, start: false, pause: false };
  /** Called on any key, touch or gamepad button, so sound can start. */
  onActivity: () => void = () => {};
  onMute: () => void = () => {};

  constructor(root: Document, screen: HTMLElement) {
    root.addEventListener("keydown", (e) => {
      if (e.metaKey || e.ctrlKey || e.altKey) return;
      this.onActivity();
      const d = KEYS[e.code];
      if (d !== undefined) { this.dir = d; e.preventDefault(); return; }
      if (e.repeat) return;
      if (e.code === "Enter" || e.code === "Space" || e.code === "NumpadEnter") { this.start = true; e.preventDefault(); }
      else if (e.code === "KeyP" || e.code === "Escape") this.pause = true;
      else if (e.code === "KeyM") this.onMute();
    });

    // Swipes anywhere on the screen: each time the finger has moved far enough one way, that is a direction, and the
    // swipe starts again from there, so a turn can follow without lifting the finger. A touch that goes nowhere is a tap.
    let from: { x: number; y: number; id: number; swiped: boolean } | null = null;
    screen.addEventListener("pointerdown", (e) => {
      this.onActivity();
      from = { x: e.clientX, y: e.clientY, id: e.pointerId, swiped: false };
      screen.setPointerCapture?.(e.pointerId);
      e.preventDefault();
    });
    screen.addEventListener("pointermove", (e) => {
      if (!from || e.pointerId !== from.id) return;
      const dx = e.clientX - from.x, dy = e.clientY - from.y;
      if (Math.max(Math.abs(dx), Math.abs(dy)) < SWIPE) return;
      this.dir = Math.abs(dx) > Math.abs(dy) ? (dx > 0 ? RIGHT : LEFT) : dy > 0 ? DOWN : UP;
      from = { x: e.clientX, y: e.clientY, id: e.pointerId, swiped: true };
    });
    const lift = (e: PointerEvent) => {
      if (!from || e.pointerId !== from.id) return;
      if (!from.swiped && e.type === "pointerup") this.start = true;
      from = null;
    };
    screen.addEventListener("pointerup", lift);
    screen.addEventListener("pointercancel", lift);
    screen.addEventListener("contextmenu", (e) => e.preventDefault());
  }

  /** Wires an on-screen button: "up", "right", "down", "left", "start" or "pause". */
  bindButton(el: HTMLElement, action: string): void {
    el.addEventListener("pointerdown", (e) => {
      e.preventDefault();
      this.onActivity();
      if (action === "start") this.start = true;
      else if (action === "pause") this.pause = true;
      else if (action in BUTTONS) this.dir = BUTTONS[action];
    });
    el.addEventListener("contextmenu", (e) => e.preventDefault());
  }

  /** A pause from the page itself (the tab was hidden), taken on the next step like a key. */
  queuePause(): void { this.pause = true; }

  /** The first gamepad: the d-pad or left stick points, A starts, Start pauses (or starts, when there is no game on). */
  private readGamepad(playing: boolean): void {
    const gp = typeof navigator.getGamepads === "function" ? Array.from(navigator.getGamepads()).find((g) => g && g.connected) : null;
    if (!gp) return;
    const b = (i: number) => !!gp.buttons[i]?.pressed;
    const x = gp.axes[0] ?? 0, y = gp.axes[1] ?? 0;
    let dir: Dir | -1 = -1;
    if (b(12) || y < -0.6) dir = UP;
    else if (b(15) || x > 0.6) dir = RIGHT;
    else if (b(13) || y > 0.6) dir = DOWN;
    else if (b(14) || x < -0.6) dir = LEFT;
    if (dir >= 0 && dir !== this.pad.dir) { this.dir = dir; this.onActivity(); }
    const start = b(0) || (!playing && b(9)), pause = playing && b(9);
    if (start && !this.pad.start) { this.start = true; this.onActivity(); }
    if (pause && !this.pad.pause) this.pause = true;
    this.pad = { dir, start, pause };
  }

  /** This step's input; everything in it is used up. */
  read(playing: boolean): Input {
    this.readGamepad(playing);
    const input: Input = { dir: this.dir, start: this.start, pause: this.pause };
    this.dir = -1;
    this.start = false;
    this.pause = false;
    return input;
  }
}
