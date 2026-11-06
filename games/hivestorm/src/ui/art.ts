// All of HIVESTORM's pictures, drawn for this game: pixel maps where "." is see-through and each letter is a colour
// from the sprite's palette. Aliens face down the screen, towards the player.
import type { Kind } from "../engine/rules";

export interface Sprite { rows: string[]; palette: Record<string, string> }

// Wasp-like hive aliens: striped abdomen at the back, wings, head and feelers at the front.
const WORKER = [
  [
    "....aba....",
    "...aabaa...",
    "...bbabb...",
    "...aabaa...",
    "ww..aaa..ww",
    "www.hhh.www",
    ".ww.ehe.ww.",
    "....hhh....",
    "...h...h...",
    "..h.....h..",
  ],
  [
    "....aba....",
    "...aabaa...",
    "...bbabb...",
    "...aabaa...",
    "....aaa....",
    ".ww.hhh.ww.",
    "www.ehe.www",
    "ww..hhh..ww",
    "...h...h...",
    "..h.....h..",
  ],
];

const GUARD = [
  [
    "...abbba...",
    "..aabbbaa..",
    "..bbaaabb..",
    "w..aabaa..w",
    "ww..hhh..ww",
    "www.hhh.www",
    ".ww.ehe.ww.",
    "...h.h.h...",
    "..h..h..h..",
    ".h.......h.",
  ],
  [
    "...abbba...",
    "..aabbbaa..",
    "..bbaaabb..",
    "...aabaa...",
    ".w..hhh..w.",
    "ww..hhh..ww",
    "www.ehe.www",
    ".w.h.h.h.w.",
    "..h..h..h..",
    ".h.......h.",
  ],
];

const QUEEN = [
  [
    "...c.c.c.c...",
    "...ccccccc...",
    "....abbba....",
    "...aabbbaa...",
    "...bbaaabb...",
    "...aabbbaa...",
    "ww..aaaaa..ww",
    "www.hhhhh.www",
    ".ww.heheh.ww.",
    "....hhhhh....",
    "...h..h..h...",
    "..h.......h..",
  ],
  [
    "...c.c.c.c...",
    "...ccccccc...",
    "....abbba....",
    "...aabbbaa...",
    "...bbaaabb...",
    "...aabbbaa...",
    "....aaaaa....",
    ".ww.hhhhh.ww.",
    "www.heheh.www",
    "ww..hhhhh..ww",
    "...h..h..h...",
    "..h.......h..",
  ],
];

/** Colours of each kind: a abdomen, b stripes, h head, e eyes, w wings, c crown. */
export const KIND_PALETTE: Record<Kind, Record<string, string>> = {
  queen: { a: "#ffd040", b: "#c02828", h: "#ff7020", e: "#30ffff", w: "#ffe8b0", c: "#ffffff" },
  guard: { a: "#e050e0", b: "#701870", h: "#ff4868", e: "#ffff40", w: "#ffc8ff" },
  drone: { a: "#ff8c28", b: "#8a3000", h: "#28c8c8", e: "#ffff60", w: "#c0e8ff" },
  worker: { a: "#e8d428", b: "#7a5010", h: "#40c050", e: "#ff3030", w: "#a0dcff" },
};

const KIND_ROWS: Record<Kind, string[][]> = { queen: QUEEN, guard: GUARD, drone: WORKER, worker: WORKER };

export const alienSprite = (kind: Kind, frame: number): Sprite => ({ rows: KIND_ROWS[kind][frame % 2], palette: KIND_PALETTE[kind] });

/** The player's ship, the Stinger, nose up. */
export const SHIP: Sprite = {
  rows: [
    "......p......",
    ".....pwp.....",
    ".....www.....",
    "....wwwww....",
    "....wcwcw....",
    "...wwcccww...",
    ".r.wwwwwww.r.",
    ".r.ww.w.ww.r.",
    "rrwwwwwwwwwrr",
    "rwwbwwwwwbwwr",
    "rbbb.www.bbbr",
    "rb...bbb...br",
    ".....b.b.....",
  ],
  palette: { w: "#e8e8f0", c: "#30d0ff", r: "#ff4040", b: "#4868ff", p: "#ffd040" },
};

/** One hive cell per wave reached, shown bottom right. */
export const CELL: Sprite = {
  rows: [".oo.", "oyyo", "oyyo", ".oo."],
  palette: { o: "#ff9020", y: "#ffe060" },
};

export const COLOURS = {
  shot: "#ffffa0",
  bullet: "#ff70ff",
  text: "#ffffff",
  label: "#ff4848",
  accent: "#ffd040",
  dim: "#7088ff",
  boom: { queen: "#ffd040", guard: "#ff60ff", drone: "#ff9030", worker: "#f0e040", player: "#ff5030" } as Record<Kind | "player", string>,
};

// A 5×7 capital font for the screen text. Each glyph is seven rows of five, "#" lit.
const G: Record<string, string> = {
  A: ".###.#...##...#######...##...##...#", B: "####.#...##...#####.#...##...#####.",
  C: ".###.#...##....#....#....#...#.###.", D: "####.#...##...##...##...##...#####.",
  E: "######....#....####.#....#....#####", F: "######....#....####.#....#....#....",
  G: ".###.#...##....#.####...##...#.####", H: "#...##...##...#######...##...##...#",
  I: ".###...#....#....#....#....#...###.", J: "..###...#....#....#....#.#..#..##..",
  K: "#...##..#.#.#..##...#.#..#..#.#...#", L: "#....#....#....#....#....#....#####",
  M: "#...###.###.#.##.#.##...##...##...#", N: "#...##...###..##.#.##..###...##...#",
  O: ".###.#...##...##...##...##...#.###.", P: "####.#...##...#####.#....#....#....",
  Q: ".###.#...##...##...##.#.##..#..##.#", R: "####.#...##...#####.#.#..#..#.#...#",
  S: ".#####....#.....###.....#....#####.", T: "#####..#....#....#....#....#....#..",
  U: "#...##...##...##...##...##...#.###.", V: "#...##...##...##...##...#.#.#...#..",
  W: "#...##...##...##.#.##.#.##.#.#.#.#.", X: "#...##...#.#.#...#...#.#.#...##...#",
  Y: "#...##...#.#.#...#....#....#....#..", Z: "#####....#...#...#...#...#....#####",
  "0": ".###.#...##..###.#.###..##...#.###.", "1": "..#...##....#....#....#....#...###.",
  "2": ".###.#...#....#...#...#...#...#####", "3": "#####...#...#.....#.....##...#.###.",
  "4": "...#...##..#.#.#..#.#####...#....#.", "5": "######....####.....#....##...#.###.",
  "6": "..##..#...#....####.#...##...#.###.", "7": "#####....#...#...#...#....#....#...",
  "8": ".###.#...##...#.###.#...##...#.###.", "9": ".###.#...##...#.####....#...#..##..",
  "-": "...............#####...............", ".": "..............................##...",
  ":": "......##...##.........##...##......", "!": "..#....#....#....#....#.........#..",
  "?": ".###.#...#....#...#...#.........#..", "/": ".........#...#...#...#...#.........",
  "=": "..........#####.....#####..........", "(": "...#...#...#....#....#.....#.....#.",
  ")": ".#.....#.....#....#....#...#...#...", ",": "....................##....#...#....",
  "'": "..#....#...#..." + ".".repeat(20), "+": ".......#....#..#####..#....#.......",
  "<": "...#...#...#...#.....#.....#.....#.", ">": ".#.....#.....#.....#...#...#...#...",
  "*": ".......#..#.#.#.###.#.#.#..#.......", "_": "..............................#####", " ": ".".repeat(35),
};

export const FONT_W = 5;
export const FONT_H = 7;
export const ADVANCE = 6;

/** The lit pixels of a character as rows of "#"/".", or undefined if the font lacks it. */
export function glyph(ch: string): string[] | undefined {
  const g = G[ch];
  if (!g) return undefined;
  return Array.from({ length: FONT_H }, (_, r) => g.slice(r * FONT_W, r * FONT_W + FONT_W));
}

export const FONT_CHARS = Object.keys(G);
