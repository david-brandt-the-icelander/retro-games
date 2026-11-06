// A model of the ZX Spectrum display: a 256×192 one-bit bitmap plus a 32×24 grid of
// colour attributes (INK, PAPER, BRIGHT, FLASH), and a border colour.
// Rendering is a pure function to RGBA, so it can be tested without a browser.
import { glyph } from "./font";

export const WIDTH = 256, HEIGHT = 192, COLS = 32, ROWS = 24;
/** Border thickness in Spectrum pixels around the 256×192 paper. */
export const BORDER = 32;
export const FULL_WIDTH = WIDTH + 2 * BORDER, FULL_HEIGHT = HEIGHT + 2 * BORDER;

export const BLACK = 0, BLUE = 1, RED = 2, MAGENTA = 3, GREEN = 4, CYAN = 5, YELLOW = 6, WHITE = 7;

/** Spectrum palette as [r, g, b]: normal (0xD7) and BRIGHT (0xFF) intensities. */
export function rgb(colour: number, bright: boolean): [number, number, number] {
  const v = colour === BLACK ? 0 : bright ? 0xff : 0xd7;
  return [colour & 2 ? v : 0, colour & 4 ? v : 0, colour & 1 ? v : 0];
}

export interface Attr { ink: number; paper: number; bright?: boolean; flash?: boolean }

const packAttr = (a: Attr) => (a.ink & 7) | ((a.paper & 7) << 3) | (a.bright ? 64 : 0) | (a.flash ? 128 : 0);

export class ZXScreen {
  /** One byte per pixel, 0 = paper, 1 = ink. */
  readonly pixels = new Uint8Array(WIDTH * HEIGHT);
  /** Spectrum attribute bytes: bits 0–2 ink, 3–5 paper, 6 BRIGHT, 7 FLASH. */
  readonly attrs = new Uint8Array(COLS * ROWS);
  border = WHITE;
  /** The character last printed in each cell (for screen readers and tests). */
  readonly chars: string[] = Array(COLS * ROWS).fill(" ");
  /** Characters that fell off the right or bottom edge since the last cls(). */
  clipped = 0;
  /** True when the current screen has a footer prompt (set by the painter), e.g. to animate it while waiting. */
  hasFooter = false;
  /** Incremented on every change, so a display knows when to redraw. */
  version = 0;

  /** Clear the screen to the given colours (like CLS after INK/PAPER). */
  cls(attr: Attr, border = this.border): void {
    this.pixels.fill(0);
    this.attrs.fill(packAttr(attr));
    this.chars.fill(" ");
    this.clipped = 0;
    this.hasFooter = false;
    this.border = border;
    this.version++;
  }

  setBorder(colour: number): void { this.border = colour & 7; this.version++; }

  attrAt(col: number, row: number): Attr {
    const a = this.attrs[row * COLS + col];
    return { ink: a & 7, paper: (a >> 3) & 7, bright: !!(a & 64), flash: !!(a & 128) };
  }

  /** Set the attributes of a rectangle of cells (clipped to the screen). */
  fillAttr(col: number, row: number, w: number, h: number, attr: Attr): void {
    const v = packAttr(attr);
    for (let r = Math.max(0, row); r < Math.min(ROWS, row + h); r++)
      for (let c = Math.max(0, col); c < Math.min(COLS, col + w); c++) this.attrs[r * COLS + c] = v;
    this.version++;
  }

  /** Clear the pixels of a rectangle of cells, optionally recolouring it. */
  clearCells(col: number, row: number, w: number, h: number, attr?: Attr): void {
    for (let r = Math.max(0, row); r < Math.min(ROWS, row + h); r++)
      for (let c = Math.max(0, col); c < Math.min(COLS, col + w); c++) {
        this.cellBytes(c, r, [0, 0, 0, 0, 0, 0, 0, 0]);
        this.chars[r * COLS + c] = " ";
      }
    if (attr) this.fillAttr(col, row, w, h, attr);
    this.version++;
  }

  /** Draw 8 bytes into one character cell (bit 7 = leftmost pixel). */
  cellBytes(col: number, row: number, bytes: readonly number[], attr?: Attr): void {
    if (col < 0 || col >= COLS || row < 0 || row >= ROWS) return;
    for (let y = 0; y < 8; y++) {
      const b = bytes[y] ?? 0;
      const base = (row * 8 + y) * WIDTH + col * 8;
      for (let x = 0; x < 8; x++) this.pixels[base + x] = (b >> (7 - x)) & 1;
    }
    if (attr) this.attrs[row * COLS + col] = packAttr(attr);
    this.version++;
  }

  /** PRINT AT row, col; text is clipped at the right edge. Returns the column after the text. */
  print(col: number, row: number, text: string, attr?: Attr): number {
    for (const ch of text) {
      if (col >= COLS || row < 0 || row >= ROWS) { this.clipped++; continue; }
      this.cellBytes(col, row, glyph(ch), attr);
      if (col >= 0) this.chars[row * COLS + col] = ch;
      col++;
    }
    return Math.min(col, COLS);
  }

  /** The printed text of each row, right-trimmed. */
  textRows(): string[] {
    return Array.from({ length: ROWS }, (_, r) => this.chars.slice(r * COLS, (r + 1) * COLS).join("").trimEnd());
  }

  /** Print text centred on a row. */
  printCentered(row: number, text: string, attr?: Attr): void {
    this.print(Math.max(0, Math.floor((COLS - text.length) / 2)), row, text, attr);
  }

  /**
   * Draw a picture given as rows of '#' (ink) and '.' (paper), with its top-left at a
   * cell. Pictures are usually 8 or 16 pixels square (user-defined graphics).
   */
  picture(col: number, row: number, rows: readonly string[], attr?: Attr): void {
    rows.forEach((line, y) => {
      for (let x = 0; x < line.length; x++) this.plot(col * 8 + x, row * 8 + y, line[x] === "#" ? 1 : 0);
    });
    if (attr) this.fillAttr(col, row, Math.ceil(Math.max(...rows.map((r) => r.length)) / 8), Math.ceil(rows.length / 8), attr);
    this.version++;
  }

  /** Set (1) or reset (0) a single pixel; (0,0) is the top-left of the paper. */
  plot(x: number, y: number, on = 1): void {
    if (x < 0 || x >= WIDTH || y < 0 || y >= HEIGHT) return;
    this.pixels[y * WIDTH + x] = on;
    this.version++;
  }

  hasFlash(): boolean { return this.attrs.some((a) => (a & 128) !== 0); }

  /**
   * Render the border and paper into a FULL_WIDTH × FULL_HEIGHT RGBA buffer
   * (one Uint32 per pixel, little-endian ABGR as used by ImageData).
   * While `flashOn`, cells with FLASH show ink and paper swapped.
   */
  render(out: Uint32Array, flashOn: boolean): void {
    const border = packRGBA(rgb(this.border, false));
    out.fill(border);
    for (let row = 0; row < ROWS; row++) {
      for (let col = 0; col < COLS; col++) {
        const a = this.attrs[row * COLS + col];
        const bright = (a & 64) !== 0;
        let ink = packRGBA(rgb(a & 7, bright));
        let paper = packRGBA(rgb((a >> 3) & 7, bright));
        if (flashOn && a & 128) [ink, paper] = [paper, ink];
        for (let y = 0; y < 8; y++) {
          const src = (row * 8 + y) * WIDTH + col * 8;
          const dst = (BORDER + row * 8 + y) * FULL_WIDTH + BORDER + col * 8;
          for (let x = 0; x < 8; x++) out[dst + x] = this.pixels[src + x] ? ink : paper;
        }
      }
    }
  }
}

/** Pack [r, g, b] as an opaque little-endian RGBA Uint32. */
export const packRGBA = ([r, g, b]: [number, number, number]): number => ((255 << 24) | (b << 16) | (g << 8) | r) >>> 0;
