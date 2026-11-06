// Keyboard and touch input in the period style: every prompt waits for a single key press.
// Keys are passed on as typed ("y", "Y", "1", "Enter", " "): which keys mean what is up to the
// game (its RULES.md quirks section). On touch screens a keypad offers the keys that matter, and
// tapping the screen counts as any key, unless the prompt says otherwise.

/** What a prompt offers on the touch keypad: [key, label]. */
export type Offer = ReadonlyArray<readonly [key: string, label: string]>;

/** The key reported when the screen itself is tapped. */
export const ANY = "Enter";

/** The key as the game sees it: single characters as typed, Enter and Space kept; others ignored. */
export function normaliseKey(key: string): string | null {
  if (key === "Enter" || key === " ") return key;
  if ([...key].length === 1) return key;
  return null; // Shift, arrows, function keys… are ignored
}

export interface WaitOptions {
  /** Buttons for the touch keypad. */
  offer?: Offer;
  /** Whether a tap on the screen counts as any key (default true). */
  tapCounts?: boolean;
}

export class Input {
  private pending: ((key: string) => void) | null = null;
  private tapCounts = true;
  private listeners: Array<(key: string) => void> = [];
  private readonly reserved = new Map<string, () => void>();

  constructor(target: HTMLElement, private readonly keypad: HTMLElement) {
    addEventListener("keydown", (e) => {
      if (e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
      // A focused button handles its own Enter/Space; other keys still answer the prompt.
      if (e.target instanceof HTMLButtonElement && (e.key === "Enter" || e.key === " ")) return;
      const k = normaliseKey(e.key);
      if (k === null) return;
      const action = this.reserved.get(k.toLowerCase());
      if (action) { e.preventDefault(); action(); return; }
      if (!this.pending) return;
      e.preventDefault();
      this.resolve(k);
    });
    target.addEventListener("pointerdown", (e) => {
      if (!this.pending || !this.tapCounts) return;
      e.preventDefault();
      this.resolve(ANY);
    });
  }

  /** Reserve a key (either case) for an action (e.g. M = sound on/off); it never answers a prompt. */
  reserve(key: string, action: () => void): void { this.reserved.set(key.toLowerCase(), action); }

  /** Called with every key that answers a prompt (e.g. to unlock audio). */
  onKey(listener: (key: string) => void): void { this.listeners.push(listener); }

  /** Wait for the next key. Keys pressed while nobody waits are discarded. */
  waitKey(options: WaitOptions = {}): Promise<string> {
    this.tapCounts = options.tapCounts ?? true;
    this.showKeypad(options.offer ?? []);
    return new Promise((resolve) => { this.pending = resolve; });
  }

  /** Show no keypad and read no key (while a screen holds before its footer). */
  idle(): void {
    this.pending = null;
    this.keypad.replaceChildren();
  }

  private resolve(key: string): void {
    const p = this.pending;
    this.pending = null;
    this.keypad.replaceChildren();
    for (const l of this.listeners) l(key);
    p?.(key);
  }

  private showKeypad(offer: Offer): void {
    this.keypad.replaceChildren();
    for (const [key, label] of offer) {
      const b = document.createElement("button");
      b.type = "button";
      b.textContent = label;
      b.dataset.key = key;
      b.addEventListener("pointerdown", (e) => { e.stopPropagation(); e.preventDefault(); if (this.pending) this.resolve(key); });
      this.keypad.appendChild(b);
    }
  }
}
