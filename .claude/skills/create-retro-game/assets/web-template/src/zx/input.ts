// Keyboard and touch input in the period style: every prompt waits for a single key press.
// Which keys mean what is up to the game (its RULES.md quirks section).
// On touch screens a keypad offers the keys that matter, and tapping the screen is "any key".

/** What a prompt offers on the touch keypad: [key, label]. An empty list means "any key". */
export type Offer = ReadonlyArray<readonly [key: string, label: string]>;

/** The key reported when the screen itself is tapped, or Enter / Space is pressed. */
export const ANY = "enter";
/** What waitKey reports when a timed screen moves on by itself. */
export const TIMEOUT = "timeout";

/** Normalise a KeyboardEvent key: single characters lower-cased, Enter and Space as ANY. */
export function normaliseKey(key: string): string | null {
  if (key === "Enter" || key === " ") return ANY;
  if (key.length === 1) return key.toLowerCase();
  return null; // Shift, arrows, function keys… are ignored
}

export class Input {
  private pending: ((key: string) => void) | null = null;
  private listeners: Array<(key: string) => void> = [];
  private readonly reserved = new Map<string, () => void>();

  constructor(target: HTMLElement, private readonly keypad: HTMLElement) {
    addEventListener("keydown", (e) => {
      if (e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
      // A focused button handles its own Enter/Space; other keys still answer the prompt.
      if (e.target instanceof HTMLButtonElement && (e.key === "Enter" || e.key === " ")) return;
      const k = normaliseKey(e.key);
      if (k === null) return;
      const action = this.reserved.get(k);
      if (action) { e.preventDefault(); action(); return; }
      if (!this.pending) return;
      e.preventDefault();
      this.resolve(k);
    });
    target.addEventListener("pointerdown", (e) => {
      if (!this.pending) return;
      e.preventDefault();
      this.resolve(ANY);
    });
  }

  /** Reserve a key for an action (e.g. M = sound on/off); it never answers a prompt. */
  reserve(key: string, action: () => void): void { this.reserved.set(key, action); }

  /** Called with every key that answers a prompt (e.g. to unlock audio). */
  onKey(listener: (key: string) => void): void { this.listeners.push(listener); }

  /**
   * Wait for the next key. `offer` only decides which buttons the touch keypad shows.
   * With `timeoutMs`, give up after that long and report TIMEOUT (like Spectrum BASIC's PAUSE n,
   * which ends early on a key press).
   */
  waitKey(offer: Offer = [], timeoutMs?: number): Promise<string> {
    this.showKeypad(offer);
    return new Promise((resolve) => {
      let timer: ReturnType<typeof setTimeout> | undefined;
      this.pending = (key) => { clearTimeout(timer); resolve(key); };
      if (timeoutMs !== undefined) {
        timer = setTimeout(() => {
          if (!this.pending) return;
          this.pending = null;
          this.keypad.replaceChildren();
          resolve(TIMEOUT);
        }, timeoutMs);
      }
    });
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
