// The pieces, drawn as 16×16 pixel art, and a 3×5 pixel font for the board's coordinates.
//
// Each piece is a silhouette: x is the body, d a dark detail (an eye, a slit), c a gold accent
// (crowns and crosses). Rows of 8 characters are mirrored into 16; rows of 16 are used as they
// are. The outline is drawn around the silhouette, and the body is lit from the top left:
// pixels on its top or left edge are highlight, on its bottom or right edge shadow.

export type PieceType = "p" | "n" | "b" | "r" | "q" | "k";
export type PieceColor = "w" | "b";

const ART: Record<PieceType, string[]> = {
  p: [
    "........", "........", "........", "......xx", ".....xxx", ".....xxx", ".....xxx", "......xx",
    ".....xxx", "......xx", "......xx", ".....xxx", "....xxxx", "...xxxxx", "........", "........",
  ],
  r: [
    "........", "........", "..xx..xx", "..xx..xx", "..xxxxxx", "...xxxxx", "....xxxx", "....xxxd",
    "....xxxd", "....xxxx", "....xxxx", "...xxxxx", "..xxxxxx", "..xxxxxx", "........", "........",
  ],
  b: [
    "........", ".......c", "......xx", ".....xxx", "....xxxxxdxx....", "....xxxxdxxx....", "....xxxdxxxx....", ".....xxx",
    "......xx", ".....ccc", "......xx", ".....xxx", "...xxxxx", "..xxxxxx", "........", "........",
  ],
  n: [
    "................",
    "................",
    "......x.x.......",
    ".....xxxxxx.....",
    "....xxxxxxxx....",
    "...xxdxxxxxxx...",
    "..xxxxxxxxxxxx..",
    ".xxxxxxxxxxxxx..",
    ".xxxx.xxxxxxxx..",
    "..xx..xxxxxxxx..",
    ".....xxxxxxxxx..",
    "....xxxxxxxxx...",
    "....xxxxxxxxx...",
    "..xxxxxxxxxxxx..",
    "................",
    "................",
  ],
  q: [
    "........", "..c..c.c", "..x..x.x", "..xx.xxx", "..xxxxxx", "...xxxxx", "...xxxxx", "....xxxx",
    ".....xxx", "....cccc", ".....xxx", "....xxxx", "...xxxxx", "..xxxxxx", "........", "........",
  ],
  k: [
    "........", ".......c", "......cc", ".......c", "...xx.xx", "..xxxxxx", "..xxxxxx", "...xxxxx",
    ".....xxx", "....cccc", ".....xxx", "....xxxx", "...xxxxx", "..xxxxxx", "........", "........",
  ],
};

export interface PieceColors { outline: string; base: string; light: string; dark: string; detail: string; gold: string; goldDark: string }

export const PALETTE: Record<PieceColor, PieceColors> = {
  w: { outline: "#1d1430", base: "#efe2c2", light: "#fffaf0", dark: "#bfa985", detail: "#1d1430", gold: "#ffcf5a", goldDark: "#d8962f" },
  b: { outline: "#0b0714", base: "#4a3868", light: "#7e68a8", dark: "#2a1d40", detail: "#ffcf5a", gold: "#ffcf5a", goldDark: "#d8962f" },
};

/** The silhouette of a piece as 16 rows of 16 characters. */
export function grid(type: PieceType): string[] {
  return ART[type].map((row) => (row.length === 16 ? row : row + [...row].reverse().join("")));
}

/** Every pixel of a piece: x, y and colour. Transparent pixels are left out. */
export function pixels(type: PieceType, color: PieceColor): { x: number; y: number; c: string }[] {
  const g = grid(type);
  const pal = PALETTE[color];
  const fill = (x: number, y: number) => y >= 0 && y < 16 && x >= 0 && x < 16 && g[y][x] !== ".";
  const out: { x: number; y: number; c: string }[] = [];
  for (let y = 0; y < 16; y++) {
    for (let x = 0; x < 16; x++) {
      const ch = g[y][x];
      if (ch === ".") {
        if (fill(x - 1, y) || fill(x + 1, y) || fill(x, y - 1) || fill(x, y + 1)) out.push({ x, y, c: pal.outline });
        continue;
      }
      const lit = !fill(x - 1, y) || !fill(x, y - 1);
      const shade = !fill(x + 1, y) || !fill(x, y + 1);
      let c: string;
      if (ch === "d") c = pal.detail;
      else if (ch === "c") c = shade && !lit ? pal.goldDark : pal.gold;
      else c = lit && !shade ? pal.light : shade && !lit ? pal.dark : pal.base;
      out.push({ x, y, c });
    }
  }
  return out;
}

const cache = new Map<string, HTMLCanvasElement>();

/** A piece drawn on its own 16×16 canvas (made once, then reused). */
export function sprite(type: PieceType, color: PieceColor): HTMLCanvasElement {
  const key = color + type;
  let c = cache.get(key);
  if (!c) {
    c = document.createElement("canvas");
    c.width = c.height = 16;
    const ctx = c.getContext("2d")!;
    for (const p of pixels(type, color)) {
      ctx.fillStyle = p.c;
      ctx.fillRect(p.x, p.y, 1, 1);
    }
    cache.set(key, c);
  }
  return c;
}

// ── A 3×5 font for a–h and 1–8 ──

const ROWS: Record<string, string[]> = {
  a: [".#.", "#.#", "###", "#.#", "#.#"], b: ["##.", "#.#", "##.", "#.#", "##."],
  c: [".##", "#..", "#..", "#..", ".##"], d: ["##.", "#.#", "#.#", "#.#", "##."],
  e: ["###", "#..", "##.", "#..", "###"], f: ["###", "#..", "##.", "#..", "#.."],
  g: [".##", "#..", "#.#", "#.#", ".##"], h: ["#.#", "#.#", "###", "#.#", "#.#"],
  "1": [".#.", "##.", ".#.", ".#.", "###"], "2": ["##.", "..#", ".#.", "#..", "###"],
  "3": ["##.", "..#", ".#.", "..#", "##."], "4": ["#.#", "#.#", "###", "..#", "..#"],
  "5": ["###", "#..", "##.", "..#", "##."], "6": [".##", "#..", "##.", "#.#", ".#."],
  "7": ["###", "..#", ".#.", ".#.", ".#."], "8": [".#.", "#.#", ".#.", "#.#", ".#."],
};
const GLYPHS: Record<string, string> = Object.fromEntries(Object.entries(ROWS).map(([k, rows]) => [k, rows.join("")]));
/** Draws one character of the 3×5 font with its top left at (x, y). */
export function glyph(ctx: CanvasRenderingContext2D, ch: string, x: number, y: number, color: string): void {
  const g = GLYPHS[ch];
  if (!g) return;
  ctx.fillStyle = color;
  for (let i = 0; i < 15; i++) if (g[i] === "#") ctx.fillRect(x + (i % 3), y + Math.floor(i / 3), 1, 1);
}
