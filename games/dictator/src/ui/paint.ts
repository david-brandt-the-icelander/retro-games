// The drawing vocabulary for the game's screens (docs/UI-DESIGN.md § Global patterns), on top of
// ZXScreen. It keeps track of which cells hold text and which hold pictures, so the layout tests
// can count text that runs out of its region, off the screen, under the footer or into art.
import { glyph } from "../zx/font";
import { Attr, BLACK, COLS, ROWS, WHITE, ZXScreen } from "../zx/screen";

export const at = (ink: number, paper: number, extra: Partial<Attr> = {}): Attr => ({ ink, paper, ...extra });

export type Align = "left" | "centre" | "right";

/** The first row of the footer counterfoil. */
export const FOOTER_ROW = 21;

export class Painter {
  /** Cells covered by pictures. */
  private readonly art = new Set<number>();
  /** Cells covered by text. */
  private readonly words = new Set<number>();
  /** True while the footer itself is being drawn. */
  private inFooter = false;

  constructor(readonly z: ZXScreen) {}

  // ── Cells ────────────────────────────────────────────────────────────

  private markText(col: number, row: number): void {
    if (col < 0 || col >= COLS || row < 0 || row >= ROWS) { this.z.clipped++; return; }
    const i = row * COLS + col;
    if (this.art.has(i)) this.z.clipped++;
    if (!this.inFooter && this.z.hasFooter && row >= FOOTER_ROW) this.z.clipped++;
    this.words.add(i);
  }

  /** Clear the screen to its page colours and set the border (CLS). */
  page(ink: number, paper: number, border: number, extra: Partial<Attr> = {}): this {
    this.z.cls(at(ink, paper, extra), border);
    this.art.clear();
    this.words.clear();
    return this;
  }

  /** Recolour a rectangle of cells (columns c0–c1, rows r0–r1, inclusive). */
  fill(c0: number, r0: number, c1: number, r1: number, attr: Attr): this {
    this.z.fillAttr(c0, r0, c1 - c0 + 1, r1 - r0 + 1, attr);
    return this;
  }

  /** Clear the pixels and text of a rectangle of cells and colour it. */
  clear(c0: number, r0: number, c1: number, r1: number, attr: Attr): this {
    this.z.clearCells(c0, r0, c1 - c0 + 1, r1 - r0 + 1, attr);
    for (let r = r0; r <= r1; r++) for (let c = c0; c <= c1; c++) { this.words.delete(r * COLS + c); this.art.delete(r * COLS + c); }
    return this;
  }

  // ── Text ─────────────────────────────────────────────────────────────

  /** Print at a cell. */
  print(col: number, row: number, s: string, attr?: Attr): this {
    for (let i = 0; i < s.length; i++) this.markText(col + i, row);
    this.z.print(col, row, s, attr);
    return this;
  }

  /** Print inside a region of columns c0–c1, aligned; text wider than the region counts as clipped. */
  text(row: number, c0: number, c1: number, s: string, attr?: Attr, align: Align = "left"): this {
    const width = c1 - c0 + 1;
    if (s.length > width) this.z.clipped += s.length - width;
    const start = align === "left" ? c0 : align === "right" ? c1 - s.length + 1 : c0 + Math.floor((width - s.length) / 2);
    return this.print(start, row, s, attr);
  }

  /** Centre text on the whole row. */
  centre(row: number, s: string, attr?: Attr): this {
    return this.text(row, 0, COLS - 1, s, attr, "centre");
  }

  /** Double-size text (each glyph pixel a 2×2 block) on rows row and row+1, centred in columns c0–c1. */
  big(row: number, c0: number, c1: number, s: string, attr: Attr): this {
    const width = c1 - c0 + 1;
    if (2 * s.length > width) this.z.clipped += 2 * s.length - width;
    const start = c0 + Math.floor((width - 2 * s.length) / 2);
    [...s].forEach((ch, i) => {
      const col = start + 2 * i;
      for (let dc = 0; dc < 2; dc++) for (let dr = 0; dr < 2; dr++) this.markText(col + dc, row + dr);
      const g = glyph(ch);
      for (let y = 0; y < 8; y++) for (let x = 0; x < 8; x++) {
        const on = (g[y] >> (7 - x)) & 1;
        for (let k = 0; k < 4; k++) this.z.plot(col * 8 + 2 * x + (k & 1), row * 8 + 2 * y + (k >> 1), on);
      }
      if (col >= 0 && col < COLS && row >= 0 && row < ROWS) this.z.chars[row * COLS + col] = ch;
      this.z.fillAttr(col, row, 2, 2, attr);
    });
    return this;
  }

  // ── Pictures ─────────────────────────────────────────────────────────

  private markArt(col: number, row: number, w: number, h: number): void {
    for (let r = row; r < row + h; r++)
      for (let c = col; c < col + w; c++) {
        if (c < 0 || c >= COLS || r < 0 || r >= ROWS) { this.z.clipped++; continue; }
        if (this.words.has(r * COLS + c)) this.z.clipped++;
        if (this.z.hasFooter && r >= FOOTER_ROW) this.z.clipped++;
        this.art.add(r * COLS + c);
      }
  }

  /** Draw a picture with its top-left at a cell; overlapping text counts as clipped. */
  icon(col: number, row: number, picture: readonly string[], attr: Attr): this {
    this.markArt(col, row, Math.ceil(picture[0].length / 8), Math.ceil(picture.length / 8));
    this.z.picture(col, row, picture, attr);
    return this;
  }

  /** Draw a picture at double size (each pixel a 2×2 block). */
  bigIcon(col: number, row: number, picture: readonly string[], attr: Attr): this {
    const w = Math.ceil((picture[0].length * 2) / 8), h = Math.ceil((picture.length * 2) / 8);
    this.markArt(col, row, w, h);
    picture.forEach((line, y) => {
      for (let x = 0; x < line.length; x++)
        for (let k = 0; k < 4; k++) this.z.plot(col * 8 + 2 * x + (k & 1), row * 8 + 2 * y + (k >> 1), line[x] === "#" ? 1 : 0);
    });
    this.z.fillAttr(col, row, w, h, attr);
    return this;
  }

  // ── Lines (decoration, in each cell's own ink) ──────────────────────

  /** A horizontal line of pixels on y from x0 to x1, every `step` pixels. */
  hline(y: number, x0: number, x1: number, step = 1): this {
    for (let x = x0; x <= x1; x += step) this.z.plot(x, y);
    return this;
  }

  /** A vertical line of pixels on x from y0 to y1. */
  vline(x: number, y0: number, y1: number): this {
    for (let y = y0; y <= y1; y++) this.z.plot(x, y);
    return this;
  }

  /** A 1-pixel rectangle outline. */
  rect(x0: number, y0: number, x1: number, y1: number): this {
    this.hline(y0, x0, x1).hline(y1, x0, x1).vline(x0, y0, y1).vline(x1, y0, y1);
    return this;
  }

  // ── Recurring elements ───────────────────────────────────────────────

  /** Row 0: the letterhead band with the seal and the office's name; row 1: the double rule. */
  letterhead(office: string, band: Attr, seal: readonly string[]): this {
    this.fill(0, 0, COLS - 1, 0, band);
    this.icon(1, 0, seal, band);
    this.text(0, 3, 18, office, band);
    this.hline(10, 0, 255).hline(13, 0, 255);
    return this;
  }

  /** A red bar: one row of black on BRIGHT red (or another paper), text from its first text column. */
  bar(row: number, c0: number, c1: number, s: string, textCol: number, paper: number): this {
    const attr = at(BLACK, paper, { bright: true });
    this.fill(c0, row, c1, row, attr);
    return this.text(row, textCol, c1, s, attr);
  }

  /** A framed stamp box: black on BRIGHT paper with a 1-pixel frame on its outermost pixel ring. */
  stamp(c0: number, r0: number, c1: number, r1: number, paper: number): Attr {
    const attr = at(BLACK, paper, { bright: true });
    this.clear(c0, r0, c1, r1, attr); // the box hides any line drawn under it (e.g. the ledger margin)
    this.rect(c0 * 8, r0 * 8, c1 * 8 + 7, r1 * 8 + 7);
    return attr;
  }

  /**
   * The footer counterfoil (rows 21–23): perforation, centred prompt and a flashing cursor. The
   * cursor is the only flash on a screen with a footer, so an alarm lamp or a rifle sight that
   * flashed while the screen held stops flashing when the footer appears.
   */
  footer(prompt: string, second?: string): this {
    for (let i = FOOTER_ROW * COLS; i < ROWS * COLS; i++) if (this.words.has(i) || this.art.has(i)) this.z.clipped++;
    for (let i = 0; i < this.z.attrs.length; i++) this.z.attrs[i] &= 127;
    this.z.hasFooter = true;
    this.inFooter = true;
    this.clear(0, FOOTER_ROW, COLS - 1, ROWS - 1, at(BLACK, WHITE));
    this.hline(FOOTER_ROW * 8 + 3, 0, 254, 2);
    if (prompt.length > 28) this.z.clipped += prompt.length - 28;
    const start = Math.floor((COLS - prompt.length) / 2);
    this.print(start, 22, prompt, at(BLACK, WHITE));
    this.print(start + prompt.length + 1, 22, "█", at(BLACK, WHITE, { flash: true }));
    if (second) this.centre(23, second, at(BLACK, WHITE));
    this.inFooter = false;
    return this;
  }
}
