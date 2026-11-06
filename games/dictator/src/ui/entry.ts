// The name-entry screen after a reign, in the style of the old arcade tables: the name in
// underlined slots with a flashing cursor, and a QWERTY keyboard drawn on the screen. A key
// blinks once each time it is pressed, typed or tapped.
import { NAME_MAX } from "../name";
import { BLUE, COLS, CYAN, WHITE, YELLOW, ZXScreen } from "../zx/screen";
import { at, Painter } from "./paint";
import { palace } from "./screens";
import * as T from "./text";

/** One key of the on-screen keyboard: what it types, its label, and where it sits (cells). */
export interface Key { key: string; label: string; col: number; row: number; width: number }

/** The keys that are not characters, as the browser names them. */
export const DEL = "Backspace", SKIP = "Escape", ENTER = "Enter";
/** Keys the browser reports that should act as one of ours. */
const ALIASES: Record<string, string> = { Delete: DEL };

const row = (chars: string, col: number, r: number): Key[] =>
  [...chars].map((c, i) => ({ key: c, label: c, col: col + 3 * i, row: r, width: 3 }));

/** The keyboard: four staggered rows, as on a real one, and a row of wide keys. */
export const KEYS: readonly Key[] = [
  ...row("1234567890", 1, 9),
  ...row("QWERTYUIOP", 1, 11),
  ...row("ASDFGHJKL", 2, 13),
  ...row("ZXCVBNM.-", 3, 15),
  { key: " ", label: "SPACE", col: 2, row: 17, width: 7 },
  { key: DEL, label: "DEL", col: 10, row: 17, width: 5 },
  { key: SKIP, label: "SKIP", col: 16, row: 17, width: 6 },
  { key: ENTER, label: "ENTER", col: 23, row: 17, width: 7 },
];

/** The browser keys besides characters that name entry reads. */
export const TYPING_KEYS: readonly string[] = [DEL, "Delete", SKIP];

/** The name's row, and the column of its first slot: 12 slots, one blank column between each. */
export const NAME_ROW = 7;
export const NAME_COL = (COLS - (2 * NAME_MAX - 1)) >> 1;
const MESSAGE_ROW = 19;

const PAGE = at(WHITE, BLUE);
// The name and the keys keep the page's own colours: BRIGHT would also brighten their paper.
const NAME = PAGE;
const KEY = PAGE;
const PRESSED = at(BLUE, YELLOW, { bright: true });
/** How long a key stays lit after a press. */
export const BLINK_MS = 140;
/** The cursor's blink: on and off every this many ms, the Spectrum's FLASH rate. */
export const CURSOR_MS = 320;
/** The underline: two pixel rows, one pixel below the name's cell, so it never touches a letter. */
const UNDERLINE_Y = (NAME_ROW + 1) * 8;

/** The key under a point on the paper (pixels, 0–255 × 0–191), or null. A key's rows reach halfway into the gaps. */
export function keyAt(x: number, y: number): string | null {
  const k = KEYS.find((k) => x >= k.col * 8 && x < (k.col + k.width) * 8 && y >= k.row * 8 - 4 && y < k.row * 8 + 12);
  return k ? k.key : null;
}

/** The on-screen key a browser key lights up (letters in either case). */
export function keyFor(key: string): Key | undefined {
  const k = ALIASES[key] ?? (key.length === 1 ? key.toUpperCase() : key);
  return KEYS.find((x) => x.key === k);
}

export class NameEntry {
  private readonly p: Painter;
  private clears = -1;
  private readonly lit = new Map<Key, ReturnType<typeof setTimeout>>();
  /** The slot the cursor blinks under. */
  private cursor = 0;
  private cursorOn = true;
  private blinker: ReturnType<typeof setInterval> | undefined;

  constructor(readonly z: ZXScreen) { this.p = new Painter(z); }

  /** Draw the whole screen. */
  draw(score: number, name: string): this {
    const p = this.p;
    palace(p, T.OFFICE.merit);
    p.centre(3, T.SCORES.entryTitle(score), at(YELLOW, BLUE));
    p.centre(5, T.SCORES.entryAsk, PAGE);
    for (const k of KEYS) this.key(k);
    this.name(name);
    this.message("");
    this.clears = this.z.clears;
    return this;
  }

  /** Blink the cursor until the screen is replaced. */
  start(): this {
    clearInterval(this.blinker);
    this.blinker = setInterval(() => {
      if (this.z.clears !== this.clears) { clearInterval(this.blinker); return; }
      this.cursorOn = !this.cursorOn;
      this.underline(this.cursor, this.cursorOn);
    }, CURSOR_MS);
    return this;
  }

  /**
   * Redraw the name, one character per slot over its own underline, with a blank column between
   * slots. The cursor is the underline of the next free slot (or the last), blinking.
   */
  name(name: string): this {
    const p = this.p;
    p.clear(0, NAME_ROW, COLS - 1, NAME_ROW, PAGE); // not row 8: the keys' frames reach into it
    this.cursor = Math.min(name.length, NAME_MAX - 1);
    this.cursorOn = true;
    for (let i = 0; i < NAME_MAX; i++) {
      p.print(NAME_COL + 2 * i, NAME_ROW, name[i] ?? " ", NAME);
      this.underline(i, true);
    }
    return this;
  }

  /** Whether the cursor is showing (for tests): its underline is drawn. */
  get cursorShown(): boolean { return this.cursorOn; }
  /** The slot the cursor is under (for tests). */
  get cursorSlot(): number { return this.cursor; }

  private underline(slot: number, on: boolean): void {
    const x = (NAME_COL + 2 * slot) * 8;
    for (let y = UNDERLINE_Y; y < UNDERLINE_Y + 2; y++) for (let dx = 0; dx < 7; dx++) this.z.plot(x + dx, y, on ? 1 : 0);
  }

  /** The line under the keyboard: a hint, or what went wrong. */
  message(text: string): this {
    this.p.clear(0, MESSAGE_ROW, COLS - 1, MESSAGE_ROW + 1, PAGE);
    this.p.centre(MESSAGE_ROW, text || T.SCORES.entryHint, at(text ? YELLOW : CYAN, BLUE, { bright: !!text }));
    if (!text) this.p.centre(MESSAGE_ROW + 1, T.SCORES.entryHint2, at(CYAN, BLUE));
    return this;
  }

  /** Light the key for a moment, as if pressed. Each press lights it again, even mid-blink. */
  blink(key: string): void {
    const k = keyFor(key);
    if (!k) return;
    clearTimeout(this.lit.get(k));
    this.p.fill(k.col, k.row, k.col + k.width - 1, k.row, PRESSED);
    this.lit.set(k, setTimeout(() => {
      this.lit.delete(k);
      if (this.z.clears === this.clears) this.p.fill(k.col, k.row, k.col + k.width - 1, k.row, KEY);
    }, BLINK_MS));
  }

  /**
   * A keycap: its label in the middle cell row, inside a 1-pixel outline that reaches 3 pixels
   * into the gap rows above and below and stops a pixel short of each side, so neighbouring keys
   * stand apart and no letter touches its frame.
   */
  private key(k: Key): void {
    const p = this.p;
    p.text(k.row, k.col, k.col + k.width - 1, k.label, KEY, "centre");
    p.fill(k.col, k.row - 1, k.col + k.width - 1, k.row + 1, KEY);
    p.rect(k.col * 8 + 1, k.row * 8 - 3, (k.col + k.width) * 8 - 2, k.row * 8 + 10);
  }
}

/** The screen as it first appears, for the contact sheet and the layout tests. */
export function drawEntry(z: ZXScreen, score: number, name = ""): NameEntry {
  return new NameEntry(z).draw(score, name);
}
