// Name entry for the high-score table, in the style of the old arcade tables: the name in 12
// underlined slots with space between them, the cursor blinking under the next free slot, and a
// QWERTY keyboard on screen. Each key blinks once whenever it is pressed, typed or clicked.
import { NAME_MAX, nameChar } from "../name";

export const DEL = "Backspace", SKIP = "Escape", ENTER = "Enter";

/** The keyboard's rows: four staggered rows of characters, and a row of wide keys. */
export const ROWS: readonly (readonly (readonly [key: string, label: string])[])[] = [
  [..."1234567890"].map((c) => [c, c] as const),
  [..."QWERTYUIOP"].map((c) => [c, c] as const),
  [..."ASDFGHJKL"].map((c) => [c, c] as const),
  [..."ZXCVBNM.-"].map((c) => [c, c] as const),
  [[" ", "SPACE"], [DEL, "DEL"], [SKIP, "SKIP"], [ENTER, "ENTER"]],
];

/** How long a key stays lit after a press, in ms (the CSS animation's length). */
export const BLINK_MS = 160;

/** What a key does to the name being typed. */
export type Action = { kind: "type"; ch: string } | { kind: "delete" } | { kind: "skip" } | { kind: "enter" } | { kind: "none" };

/** The keys a browser reports, as name-entry actions. */
export function actionFor(key: string): Action {
  if (key === DEL || key === "Delete") return { kind: "delete" };
  if (key === SKIP) return { kind: "skip" };
  if (key === ENTER) return { kind: "enter" };
  const ch = nameChar(key);
  return ch === null ? { kind: "none" } : { kind: "type", ch };
}

/** The name after a typed character or a delete: never more than NAME_MAX. */
export function edit(name: string, a: Action): string {
  if (a.kind === "delete") return name.slice(0, -1);
  if (a.kind === "type" && name.length < NAME_MAX) return name + a.ch;
  return name;
}

/** The on-screen key a browser key lights up. */
export const keyId = (key: string): string => (key === "Delete" ? DEL : key.length === 1 ? key.toUpperCase() : key);

/** Builds the slots and the keyboard into their containers, and keeps them up to date. */
export class NameEntry {
  private readonly slots: HTMLElement[] = [];
  private readonly keys = new Map<string, HTMLButtonElement>();

  constructor(slotBox: HTMLElement, keyboard: HTMLElement, onKey: (key: string) => void) {
    slotBox.replaceChildren();
    for (let i = 0; i < NAME_MAX; i++) {
      const s = document.createElement("span");
      s.className = "slot";
      slotBox.append(s);
      this.slots.push(s);
    }
    keyboard.replaceChildren();
    for (const row of ROWS) {
      const r = document.createElement("div");
      r.className = "krow";
      for (const [key, label] of row) {
        const b = document.createElement("button");
        b.type = "button";
        b.className = label.length > 1 ? "key wide" : "key";
        b.textContent = label;
        b.setAttribute("aria-label", label === " " ? "space" : label);
        // pointerdown, not click: the key answers at once, as a real key would, and keeps the focus where it was.
        b.addEventListener("pointerdown", (e) => { e.preventDefault(); onKey(key); });
        b.addEventListener("click", (e) => { if (e.detail === 0) onKey(key); }); // keyboard activation of a focused key
        r.append(b);
        this.keys.set(key, b);
      }
      keyboard.append(r);
    }
  }

  /** Show the name: a character over each underline; the cursor under the next free slot, or the last. */
  show(name: string): void {
    const cursor = Math.min(name.length, NAME_MAX - 1);
    this.slots.forEach((s, i) => {
      s.textContent = name[i] ?? "";
      s.classList.toggle("cursor", i === cursor);
      // restart the blink, so the cursor is visible the moment it moves
      if (i === cursor) { s.style.animation = "none"; void s.offsetWidth; s.style.animation = ""; }
    });
  }

  /** Light a key once; pressing it again mid-blink starts the blink again. */
  blink(key: string): void {
    const b = this.keys.get(keyId(key));
    if (!b) return;
    b.classList.remove("hit");
    void b.offsetWidth; // restart the animation
    b.classList.add("hit");
  }
}
