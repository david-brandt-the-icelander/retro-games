// Small drawing vocabulary for the game's screens, on top of ZXScreen.
import { glyph } from "../zx/font";
import { Attr, BLACK, BLUE, COLS, RED, WHITE, ZXScreen } from "../zx/screen";

export const at = (ink: number, paper: number, extra: Partial<Attr> = {}): Attr => ({ ink, paper, ...extra });

/** Break text into lines of at most `width` characters, on spaces where possible. */
export function wrap(text: string, width = COLS): string[] {
  const lines: string[] = [];
  let line = "";
  for (const word of text.split(/\s+/).filter(Boolean)) {
    if (!line) line = word;
    else if (line.length + 1 + word.length <= width) line += " " + word;
    else { lines.push(line); line = word; }
    while (line.length > width) { lines.push(line.slice(0, width)); line = line.slice(width); }
  }
  if (line) lines.push(line);
  return lines;
}

export class Painter {
  /** Cells covered by pictures in this drawing, so text and art can't silently overlap. */
  private readonly art = new Set<number>();

  constructor(readonly z: ZXScreen) {}

  /** Draw a picture at a cell; overlapping text (before or after) counts as clipped. */
  icon(col: number, row: number, picture: readonly string[], attr: Attr): this {
    const w = Math.ceil(picture[0].length / 8), h = Math.ceil(picture.length / 8);
    for (let r = row; r < row + h; r++)
      for (let c = col; c < col + w; c++) {
        if (c < 0 || c >= COLS || r < 0 || r >= 24) { this.z.clipped++; continue; }
        if (this.z.chars[r * COLS + c] !== " ") this.z.clipped++;
        this.art.add(r * COLS + c);
      }
    this.z.picture(col, row, picture, attr);
    return this;
  }

  /** Clear to a paper colour and border, like INK/PAPER/BORDER/CLS. */
  page(paper: number, ink = BLACK, border = BLUE, extra: Partial<Attr> = {}): this {
    this.z.cls(at(ink, paper, extra), border);
    return this;
  }

  /** Recolour whole rows. */
  band(row: number, height: number, attr: Attr): this {
    this.z.fillAttr(0, row, COLS, height, attr);
    return this;
  }

  /** Print at a column, or centred when `col` is omitted. */
  text(row: number, s: string, attr?: Attr, col?: number): this {
    const start = col ?? Math.max(0, Math.floor((COLS - s.length) / 2));
    for (let c = start; c < start + s.length; c++) if (this.art.has(row * COLS + c)) this.z.clipped++;
    this.z.print(start, row, s, attr);
    return this;
  }

  /** Print wrapped text, one line every `step` rows; returns the row after the last line. */
  para(row: number, s: string, attr?: Attr, step = 1, centre = false): number {
    for (const line of wrap(s)) {
      this.text(row, line, attr, centre ? undefined : 0);
      row += step;
    }
    return row;
  }

  /** Fill every cell with a repeating pattern of characters (decoration: not read out). */
  tile(pattern: string, attrFor: (col: number, row: number) => Attr): this {
    for (let r = 0; r < 24; r++)
      for (let c = 0; c < COLS; c++) this.z.cellBytes(c, r, glyph(pattern[(r * COLS + c) % pattern.length]), attrFor(c, r));
    return this;
  }

  /**
   * A footer prompt across rows 21–23 for screens that wait for a key. Its look and label
   * are the game's own (art bible); text already in those rows counts as clipped.
   */
  footer(label: string, attr: Attr = at(WHITE, BLUE)): this {
    for (let i = 21 * COLS; i < 24 * COLS; i++) if (this.z.chars[i] !== " " || this.art.has(i)) this.z.clipped++;
    this.z.hasFooter = true;
    this.band(21, 3, attr);
    this.z.clearCells(0, 21, COLS, 3);
    return this.text(22, label);
  }

  /** Print a line made of differently coloured parts (e.g. one flashing word), centred unless `col` is given. */
  parts(row: number, segments: ReadonlyArray<readonly [string, Attr | undefined]>, col?: number): this {
    const length = segments.reduce((n, [s]) => n + s.length, 0);
    let c = col ?? Math.max(0, Math.floor((COLS - length) / 2));
    for (const [s, attr] of segments) { this.text(row, s, attr, c); c += s.length; }
    return this;
  }
}


export { BLACK, BLUE, RED, WHITE };
