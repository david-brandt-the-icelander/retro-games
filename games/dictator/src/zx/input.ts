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
  /**
   * Typing mode, for entering a name: reserved keys (M for sound) are typed like any other,
   * and these keys, ignored otherwise, are passed on too (e.g. "Backspace", "Escape").
   */
  typing?: readonly string[];
  /** Maps a tap or click on the screen (client coordinates) to a key, or null to ignore it. */
  tapKey?: (clientX: number, clientY: number) => string | null;
  /** Move on by itself after this many ms, answering ANY, if no key comes first. */
  timeoutMs?: number;
}

export class Input {
  private pending: ((key: string) => void) | null = null;
  private tapCounts = true;
  private typing: readonly string[] | null = null;
  private tapKey: WaitOptions["tapKey"] = undefined;
  private listeners: Array<(key: string) => void> = [];
  private readonly reserved = new Map<string, () => void>();

  constructor(target: HTMLElement, private readonly keypad: HTMLElement) {
    addEventListener("keydown", (e) => {
      if (e.repeat || e.ctrlKey || e.metaKey || e.altKey) return;
      // A focused button handles its own Enter/Space; other keys still answer the prompt.
      if (e.target instanceof HTMLButtonElement && (e.key === "Enter" || e.key === " ")) return;
      const typing = this.pending ? this.typing : null;
      const k = typing?.includes(e.key) ? e.key : normaliseKey(e.key);
      if (k === null) return;
      const action = typing ? undefined : this.reserved.get(k.toLowerCase());
      if (action) { e.preventDefault(); action(); return; }
      if (!this.pending) return;
      e.preventDefault();
      this.resolve(k);
    });
    target.addEventListener("pointerdown", (e) => {
      if (!this.pending) return;
      if (this.tapKey) {
        e.preventDefault();
        const key = this.tapKey(e.clientX, e.clientY);
        if (key !== null) this.resolve(key);
        return;
      }
      if (!this.tapCounts) return;
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
    this.typing = options.typing ?? null;
    this.tapKey = options.tapKey;
    this.showKeypad(options.offer ?? []);
    return new Promise((resolve) => {
      this.pending = resolve;
      if (options.timeoutMs === undefined) return;
      setTimeout(() => {
        if (this.pending !== resolve) return; // answered already, or another prompt is waiting now
        this.pending = null;
        this.keypad.replaceChildren();
        resolve(ANY); // not a key the player pressed, so the key listeners aren't told
      }, Math.max(0, options.timeoutMs));
    });
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
