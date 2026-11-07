// The keyboard, gamepads and touch, turned into this browser's pilot's Controls and a queue of presses for
// menus. One pilot per browser: friends play together each on their own computer (the multiplayer page).
import { IDLE, type Controls } from "./engine/game";

/** The pilot's keys: physical key codes (KeyboardEvent.code, so any layout works). Arrows or WASD, or the numpad. */
export const KEYS = {
  left: ["ArrowLeft", "KeyA", "Numpad4"],
  right: ["ArrowRight", "KeyD", "Numpad6"],
  thrust: ["ArrowUp", "KeyW", "Numpad8"],
  fire: ["Space", "Enter", "NumpadEnter", "Numpad0", "ShiftRight", "ControlRight"],
  blink: ["ArrowDown", "KeyS", "Numpad5", "Numpad2"],
} as const;

/** How the keys are shown to players. */
export const KEYS_LABEL = "ARROWS or WASD · SPACE fire · ↓/S blink";

/** A press for menus: a key code, or "pad<i>:<button>" / "touch:<control>". */
export interface Press {
  code: string;
  key: string;
}

const PAD_BUTTONS = { fire: [0, 5], blink: [1, 2, 4], thrust: [12], left: [14], right: [15], down: [13], start: [9], back: [8] } as const;

/** Keys the page must not act on (scrolling, Firefox quick find) while the game has focus. */
const SWALLOW = new Set(["Space", "ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", "Slash", "Quote", "Tab", "Backspace"]);

export class Input {
  private down = new Set<string>();
  private queue: Press[] = [];
  private pads: Controls[] = [];
  private padPrev: Record<string, boolean> = {};
  readonly touch: Controls = { ...IDLE };
  touchSeen = false;

  constructor(target: Window) {
    target.addEventListener("keydown", (e) => {
      if (e.metaKey || e.ctrlKey && e.code !== "ControlRight" || e.altKey) return;
      if (SWALLOW.has(e.code) || e.code.startsWith("Numpad")) e.preventDefault();
      if (!e.repeat) this.queue.push({ code: e.code, key: e.key });
      this.down.add(e.code);
    });
    target.addEventListener("keyup", (e) => this.down.delete(e.code));
  }

  /** Forgets every held key and button (when the page loses focus, keyups never arrive). */
  release(): void {
    this.down.clear();
    for (const k of Object.keys(this.touch) as (keyof Controls)[]) this.touch[k] = false;
  }

  /** A touch button went down or up. */
  setTouch(ctl: keyof Controls | "pause", on: boolean): void {
    this.touchSeen = true;
    if (ctl !== "pause") this.touch[ctl] = on;
    if (on) this.queue.push({ code: `touch:${ctl}`, key: "" });
  }

  /** Reads the gamepads; call once per frame before drain(). */
  poll(): void {
    const pads = typeof navigator !== "undefined" && navigator.getGamepads ? navigator.getGamepads() : [];
    this.pads = [];
    for (const pad of pads) {
      if (!pad || !pad.connected) continue;
      const i = pad.index;
      const b = (n: number) => !!pad.buttons[n] && (pad.buttons[n].pressed || pad.buttons[n].value > 0.4);
      const any = (ns: readonly number[]) => ns.some(b);
      const ax = pad.axes[0] ?? 0;
      const ay = pad.axes[1] ?? 0;
      const c: Controls = {
        left: any(PAD_BUTTONS.left) || ax < -0.4,
        right: any(PAD_BUTTONS.right) || ax > 0.4,
        thrust: any(PAD_BUTTONS.thrust) || b(7) || ay < -0.6,
        fire: any(PAD_BUTTONS.fire),
        blink: any(PAD_BUTTONS.blink),
      };
      this.pads[i] = c;
      // Edge-detect for menus.
      const edges: Record<string, boolean> = {
        fire: c.fire, blink: c.blink, up: c.thrust, down: any(PAD_BUTTONS.down) || ay > 0.6, left: c.left, right: c.right,
        start: any(PAD_BUTTONS.start), back: any(PAD_BUTTONS.back),
      };
      for (const [name, on] of Object.entries(edges)) {
        const id = `pad${i}:${name}`;
        if (on && !this.padPrev[id]) this.queue.push({ code: id, key: "" });
        this.padPrev[id] = on;
      }
    }
  }

  /** The presses since the last call, oldest first. */
  drain(): Press[] {
    const q = this.queue;
    this.queue = [];
    return q;
  }

  isDown(code: string): boolean {
    return this.down.has(code);
  }

  /** The pilot's controls: any of the keys, any gamepad, or the touch buttons. */
  controls(): Controls {
    const keys = (codes: readonly string[]) => codes.some((c) => this.down.has(c));
    const all = [this.touch, ...this.pads.filter(Boolean)];
    const on = (k: keyof Controls) => keys(KEYS[k]) || all.some((c) => c[k]);
    return { left: on("left"), right: on("right"), thrust: on("thrust"), fire: on("fire"), blink: on("blink") };
  }
}

/** Is this press a FIRE (any fire key, gamepad button or the touch button)? */
export const isFire = (p: Press): boolean => p.code === "touch:fire" || /^pad\d+:fire$/.test(p.code) || (KEYS.fire as readonly string[]).includes(p.code);

/** The menu meaning of a press from any device. */
export type MenuAct = "up" | "down" | "left" | "right" | "ok" | "back" | "start" | "pause" | "mute" | "erase";

export function menuAct(p: Press): MenuAct | undefined {
  const c = p.code;
  if (c.includes(":")) {
    const what = c.slice(c.indexOf(":") + 1);
    if (what === "fire") return "ok";
    if (what === "thrust" || what === "up") return "up";
    if (what === "down") return "down";
    if (what === "left" || what === "right") return what;
    if (what === "start" || what === "pause") return "start";
    if (what === "back" || what === "blink") return "back";
    return undefined;
  }
  switch (c) {
    case "ArrowUp": case "KeyW": case "Numpad8": return "up";
    case "ArrowDown": case "KeyS": case "Numpad2": return "down";
    case "ArrowLeft": case "Numpad4": return "left";
    case "ArrowRight": case "Numpad6": return "right";
    case "Enter": case "NumpadEnter": return "ok";
    case "Space": return "start";
    case "Escape": return "back";
    case "KeyP": return "pause";
    case "KeyM": return "mute";
    case "Backspace": return "erase";
    default: return undefined;
  }
}
