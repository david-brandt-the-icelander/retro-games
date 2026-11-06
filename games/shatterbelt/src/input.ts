// Keyboards, gamepads and touch, turned into one Controls per player and a queue of presses for menus.
import { IDLE, type Controls } from "./engine/game";

/** A keyboard key set: physical key codes for each control (KeyboardEvent.code, so any layout works). */
export interface KeySet {
  name: string;
  /** How the keys are shown to players. */
  label: string;
  left: string[];
  right: string[];
  thrust: string[];
  fire: string[];
  blink: string[];
}

/** Five players can share one keyboard (as far as the keyboard can register that many keys at once). */
export const KEY_SETS: KeySet[] = [
  { name: "kb1", label: "W A D · Q fire · S blink", left: ["KeyA"], right: ["KeyD"], thrust: ["KeyW"], fire: ["KeyQ"], blink: ["KeyS"] },
  { name: "kb2", label: "T F H · R fire · G blink", left: ["KeyF"], right: ["KeyH"], thrust: ["KeyT"], fire: ["KeyR"], blink: ["KeyG"] },
  { name: "kb3", label: "I J L · U fire · K blink", left: ["KeyJ"], right: ["KeyL"], thrust: ["KeyI"], fire: ["KeyU"], blink: ["KeyK"] },
  { name: "kb4", label: "← ↑ → · ENTER fire · ↓ blink", left: ["ArrowLeft"], right: ["ArrowRight"], thrust: ["ArrowUp"], fire: ["Enter", "NumpadEnter", "Slash", "ShiftRight", "ControlRight"], blink: ["ArrowDown"] },
  { name: "kb5", label: "NUMPAD 4 8 6 · 0 fire · 5 blink", left: ["Numpad4"], right: ["Numpad6"], thrust: ["Numpad8"], fire: ["Numpad0", "Numpad7"], blink: ["Numpad5", "Numpad2"] },
];

/** A lone keyboard player gets every key set at once, plus Space to fire. */
export const ALL_KEYS: KeySet = {
  name: "kb", label: "ARROWS or WASD · SPACE fire · ↓/S blink",
  left: KEY_SETS.flatMap((k) => k.left), right: KEY_SETS.flatMap((k) => k.right), thrust: KEY_SETS.flatMap((k) => k.thrust),
  fire: ["Space", ...KEY_SETS.flatMap((k) => k.fire)], blink: KEY_SETS.flatMap((k) => k.blink),
};

/** What a player plays with: a key set ("kb1"…"kb5", or "kb" for all keys), a gamepad ("pad0"…), or "touch". */
export type Device = string;

export function deviceLabel(d: Device): string {
  if (d === "touch") return "TOUCH BUTTONS";
  if (d.startsWith("pad")) return `GAMEPAD ${Number(d.slice(3)) + 1}`;
  return (d === "kb" ? ALL_KEYS : KEY_SETS.find((k) => k.name === d))?.label ?? d;
}

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

  controls(device: Device): Controls {
    if (device === "touch") return { ...this.touch };
    if (device.startsWith("pad")) return this.pads[Number(device.slice(3))] ?? IDLE;
    const set = device === "kb" ? ALL_KEYS : KEY_SETS.find((k) => k.name === device);
    if (!set) return IDLE;
    const on = (codes: string[]) => codes.some((c) => this.down.has(c));
    return { left: on(set.left), right: on(set.right), thrust: on(set.thrust), fire: on(set.fire), blink: on(set.blink) };
  }
}

/** The device whose FIRE this press is, if any. */
export function fireDevice(p: Press): Device | undefined {
  if (p.code === "touch:fire") return "touch";
  const pad = /^pad(\d+):fire$/.exec(p.code);
  if (pad) return `pad${pad[1]}`;
  return KEY_SETS.find((k) => k.fire.includes(p.code))?.name;
}

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
