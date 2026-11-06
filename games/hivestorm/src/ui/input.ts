// Keyboard and touch input, turned into the game's Input once per frame.
import type { Input } from "../engine/game";

const LEFT = new Set(["ArrowLeft", "KeyA", "KeyZ"]);
const RIGHT = new Set(["ArrowRight", "KeyD", "KeyX"]);
const FIRE = new Set(["Space", "ArrowUp", "KeyW", "ControlLeft", "ControlRight", "Enter"]);

export class Controls {
  private held = new Set<string>();
  private presses = { start1: false, start2: false, pause: false };
  /** Called on any key or touch, so sound can start. */
  onActivity: () => void = () => {};
  onMute: () => void = () => {};

  constructor(root: Document) {
    root.addEventListener("keydown", (e) => {
      this.onActivity();
      if (e.repeat) { if (this.isGameKey(e.code)) e.preventDefault(); return; }
      if (e.code === "Digit1" || e.code === "Numpad1") this.presses.start1 = true;
      else if (e.code === "Digit2" || e.code === "Numpad2") this.presses.start2 = true;
      else if (e.code === "KeyP" || e.code === "Escape") this.presses.pause = true;
      else if (e.code === "KeyM") this.onMute();
      this.held.add(this.map(e.code));
      if (this.isGameKey(e.code)) e.preventDefault();
    });
    root.addEventListener("keyup", (e) => this.held.delete(this.map(e.code)));
    window.addEventListener("blur", () => this.held.clear());
  }

  private map(code: string): string {
    if (LEFT.has(code)) return "left";
    if (RIGHT.has(code)) return "right";
    if (FIRE.has(code)) return "fire";
    return code;
  }

  private isGameKey(code: string): boolean { return LEFT.has(code) || RIGHT.has(code) || FIRE.has(code); }

  /** Wires an on-screen button: held buttons ("left", "right", "fire") or one-shot presses ("start1", "start2", "pause"). */
  bindButton(el: HTMLElement, action: string): void {
    const down = (e: Event) => {
      e.preventDefault();
      this.onActivity();
      if (action === "start1" || action === "start2" || action === "pause") this.presses[action] = true;
      else if (action === "mute") this.onMute();
      else this.held.add(action);
      el.classList.add("down");
    };
    const up = (e: Event) => { e.preventDefault(); this.held.delete(action); el.classList.remove("down"); };
    el.addEventListener("pointerdown", (e) => { el.setPointerCapture?.(e.pointerId); down(e); });
    el.addEventListener("pointerup", up);
    el.addEventListener("pointercancel", up);
    el.addEventListener("contextmenu", (e) => e.preventDefault());
  }

  /** This frame's input; presses are used up. */
  read(): Input {
    const input: Input = { left: this.held.has("left"), right: this.held.has("right"), fire: this.held.has("fire"), ...this.presses };
    this.presses = { start1: false, start2: false, pause: false };
    return input;
  }
}
