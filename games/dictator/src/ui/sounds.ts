// The game's sound motifs, from docs/ART-BIBLE.md §9: every melody composed for this game.
// Each recipe is written in the art bible's token notation and turned into template notes here.
import type { Note } from "../zx/sound";
import { TICK } from "../zx/sound";

export interface MotifSpec {
  volume: number;
  /** The motif's length in seconds; screens timed by their sound last exactly this long. */
  seconds: number;
  /** How many template notes the recipe makes. */
  count: number;
  recipe: string;
}

export const MOTIF_SPECS = {
  "anthem": { volume: 0.05, seconds: 7.140, count: 25, recipe: "G4:0.315 G4:0.105 B4:0.315 A4:0.105 G4:0.42 D5:0.42 C5:0.315 B4:0.105 A4:0.315 B4:0.105 C#5:0.42 D5:0.42 E5:0.315 D5:0.105 C5:0.315 B4:0.105 A4:0.21 G4:0.21 F#4:0.42 G4:0.315 A4:0.105 B4:0.315 A4:0.105 R:0.42 G4:0.84" },
  "welcome-fanfare": { volume: 0.05, seconds: 1.500, count: 4, recipe: "C4:0.25 F4:0.25 A4:0.25 D5:0.75" },
  "month-chime": { volume: 0.05, seconds: 0.500, count: 3, recipe: "E5:0.2 R:0.05 C5:0.25" },
  "ledger": { volume: 0.05, seconds: 0.600, count: 16, recipe: "(T R:0.076)x6 X:0.02 R:0.03 C3:0.03 R:0.04" },
  "report-open": { volume: 0.04, seconds: 0.400, count: 33, recipe: "sweep(1200,400,300,10) R:0.05 T R:0.046" },
  "report-none": { volume: 0.04, seconds: 2.500, count: 152, recipe: "buzz(-15,-14,10,600) R:0.3 buzz(-20,-19,10,900) R:0.7" },
  "bankrupt-slide": { volume: 0.05, seconds: 2.000, count: 120, recipe: "sweep(880,110,1600,20) buzz(-36,-35,10,400)" },
  "audience-bell": { volume: 0.05, seconds: 0.800, count: 3, recipe: "E5:0.2 C5:0.2 G5:0.4" },
  "answer-blip": { volume: 0.03, seconds: 0.004, count: 1, recipe: "T" },
  "answer-yes": { volume: 0.03, seconds: 0.030, count: 1, recipe: "C6:0.03" },
  "cash-short-raspberry": { volume: 0.05, seconds: 1.000, count: 50, recipe: "buzz(-24,-22,20,1000)" },
  "refuse-thud": { volume: 0.05, seconds: 0.400, count: 3, recipe: "X:0.05 C2:0.15 R:0.2" },
  "swiss-whistle": { volume: 0.04, seconds: 1.000, count: 7, recipe: "A5:0.15 R:0.05 E5:0.15 R:0.05 G5:0.15 R:0.05 B5:0.4" },
  "loan-typewriter": { volume: 0.05, seconds: 1.000, count: 16, recipe: "T R:0.07 T R:0.12 T R:0.05 T R:0.09 T R:0.11 T R:0.06 T R:0.1 G6:0.25 R:0.122" },
  "loan-yes": { volume: 0.05, seconds: 1.000, count: 7, recipe: "C5:0.1 E5:0.1 G5:0.1 C6:0.2 R:0.05 G6:0.35 R:0.1" },
  "loan-no": { volume: 0.05, seconds: 0.600, count: 3, recipe: "E4:0.25 R:0.05 A3:0.3" },
  "news-teleprinter": { volume: 0.04, seconds: 6.000, count: 207, recipe: "A5:0.15 D6:0.35 R:0.1 (T R:0.03 T R:0.05 T R:0.02 T R:0.06 T R:0.04)x20 R:0.2 A5:0.15 D6:0.35 R:0.3" },
  "assassin-shot": { volume: 0.06, seconds: 1.600, count: 13, recipe: "R:0.3 T R:0.4 T R:0.292 X:0.06 R:0.01 X:0.03 R:0.02 X:0.02 R:0.03 X:0.01 R:0.42" },
  "assassin-dead": { volume: 0.05, seconds: 2.500, count: 41, recipe: "(G2:0.05 F#2:0.05)x10 (F2:0.05 E2:0.05)x10 R:0.5" },
  "assassin-miss": { volume: 0.04, seconds: 2.000, count: 29, recipe: "sweep(600,2400,250,10) R:0.25 C5:0.2 G5:0.4 R:0.9" },
  "war-drums": { volume: 0.05, seconds: 3.500, count: 69, recipe: "(X:0.02 R:0.03)x20 E5:0.15 E5:0.15 C5:0.15 G4:0.3 C5:0.15 E5:0.15 G5:0.6 R:0.1 (X:0.02 R:0.03)x10 R:0.25" },
  "war-short": { volume: 0.05, seconds: 4.000, count: 96, recipe: "X:0.15 sweep(1000,200,300,20) R:0.1 X:0.1 sweep(800,150,300,20) R:0.1 X:0.2 sweep(1200,100,400,20) R:0.2 (X:0.05 R:0.05)x6 sweep(600,80,500,20) R:0.3 X:0.3 R:0.45" },
  "war-won": { volume: 0.05, seconds: 2.500, count: 8, recipe: "G4:0.2 G4:0.1 C5:0.2 E5:0.2 G5:0.5 E5:0.2 G5:0.6 R:0.5" },
  "war-lost": { volume: 0.05, seconds: 2.500, count: 5, recipe: "A4:0.4 G4:0.4 F4:0.4 E4:0.8 R:0.5" },
  "rotor": { volume: 0.04, seconds: 3.000, count: 105, recipe: "T R:0.12 T R:0.1 T R:0.09 T R:0.08 T R:0.07 T R:0.06 T R:0.05 T R:0.045 T R:0.04 T R:0.035 (T R:0.03)x6 sweep(200,1600,800,20) pulse(1600,20,30,8) pulse(1600,10,40,8) R:0.466" },
  "sputter": { volume: 0.05, seconds: 1.500, count: 20, recipe: "T R:0.04 T R:0.05 T R:0.07 T R:0.06 T R:0.1 T R:0.09 T R:0.14 T R:0.2 X:0.08 R:0.05 X:0.05 R:0.538" },
  "volley": { volume: 0.06, seconds: 3.000, count: 27, recipe: "(X:0.02 R:0.03)x10 R:0.6 X:0.12 R:0.18 X:0.12 R:0.18 X:0.12 R:1.18" },
  "revolt-siren": { volume: 0.04, seconds: 5.000, count: 25, recipe: "(D5:0.35 R:0.05 G#4:0.35 R:0.05)x6 R:0.2" },
  "heartbeat": { volume: 0.06, seconds: 5.000, count: 28, recipe: "-30:0.04 R:0.12 -30:0.04 R:0.8 -30:0.04 R:0.12 -30:0.04 R:0.7 -30:0.04 R:0.12 -30:0.04 R:0.6 -30:0.04 R:0.12 -30:0.04 R:0.5 -30:0.04 R:0.12 -30:0.04 R:0.4 -30:0.04 R:0.12 -30:0.04 R:0.3 -30:0.04 R:0.12 -30:0.04 R:0.3" },
  "skirmish": { volume: 0.05, seconds: 2.500, count: 28, recipe: "X:0.03 R:0.07 X:0.02 R:0.12 X:0.05 R:0.04 X:0.02 R:0.2 X:0.03 R:0.05 X:0.06 R:0.1 X:0.02 R:0.03 X:0.02 R:0.15 X:0.04 R:0.06 X:0.03 R:0.25 X:0.02 R:0.08 X:0.05 R:0.1 X:0.02 R:0.3 X:0.03 R:0.51" },
  "overthrown-drop": { volume: 0.05, seconds: 2.500, count: 61, recipe: "sweep(600,60,1500,25) R:1.0" },
  "crushed-fanfare": { volume: 0.05, seconds: 1.500, count: 6, recipe: "C5:0.15 C5:0.15 G5:0.3 E5:0.15 G5:0.15 C6:0.6" },
  "footsteps": { volume: 0.03, seconds: 4.000, count: 20, recipe: "X:0.03 R:0.27 X:0.03 R:0.29 X:0.03 R:0.31 X:0.03 R:0.33 X:0.03 R:0.35 X:0.03 R:0.37 X:0.03 R:0.39 X:0.03 R:0.41 X:0.03 R:0.43 X:0.03 R:0.55" },
  "caught-jig": { volume: 0.05, seconds: 3.000, count: 16, recipe: "D5:0.15 F#5:0.15 A5:0.15 G5:0.15 E5:0.15 C#5:0.15 D5:0.15 A4:0.15 D5:0.15 F#5:0.3 E5:0.15 B5:0.15 A5:0.15 F#5:0.15 D5:0.45 R:0.3" },
  "escaped-whistle": { volume: 0.04, seconds: 2.500, count: 25, recipe: "sweep(800,1800,400,20) R:0.1 B5:0.15 R:0.05 D6:0.5 R:1.3" },
  "funeral": { volume: 0.05, seconds: 12.000, count: 24, recipe: "G2:0.25 R:0.25 G2:0.25 R:0.25 G4:0.75 G4:0.25 A#4:0.75 A4:0.25 G4:1.0 D5:1.0 D2:0.5 D#5:0.75 D5:0.25 C5:0.75 A#4:0.25 A4:0.5 G4:0.5 F#4:1.0 G4:0.25 A4:0.125 G4:0.125 F#4:0.25 G4:1.25 G2:0.5" },
  "rating-tally": { volume: 0.03, seconds: 0.030, count: 1, recipe: "C5:0.03" },
  "new-best": { volume: 0.05, seconds: 1.500, count: 9, recipe: "C6:0.08 D6:0.08 E6:0.08 G6:0.08 C7:0.3 R:0.1 G6:0.1 C7:0.5 R:0.18" },
} as const satisfies Record<string, MotifSpec>;

export type MotifId = keyof typeof MOTIF_SPECS;

const NAMES: Record<string, number> = { C: 0, "C#": 1, D: 2, "D#": 3, E: 4, F: 5, "F#": 6, G: 7, "G#": 8, A: 9, "A#": 10, B: 11 };
const MIDDLE_C = 261.63;
const pitchOf = (hz: number): number => 12 * Math.log2(hz / MIDDLE_C);

/** Split a recipe into tokens, keeping bracketed groups and function calls whole. */
function tokens(recipe: string): string[] {
  const out: string[] = [];
  let i = 0;
  while (i < recipe.length) {
    if (recipe[i] === " ") { i++; continue; }
    let j = i, depth = 0;
    while (j < recipe.length && (depth > 0 || recipe[j] !== " ")) {
      if (recipe[j] === "(") depth++;
      if (recipe[j] === ")") depth--;
      j++;
    }
    out.push(recipe.slice(i, j));
    i = j;
  }
  return out;
}

/** Turn a recipe (art bible §9 notation) into template notes. */
export function parseRecipe(recipe: string): Note[] {
  const notes: Note[] = [];
  for (const t of tokens(recipe)) {
    let m: RegExpMatchArray | null;
    if (t === "T") notes.push(...TICK);
    else if ((m = t.match(/^\((.*)\)x(\d+)$/))) for (let k = 0; k < Number(m[2]); k++) notes.push(...parseRecipe(m[1]));
    else if ((m = t.match(/^sweep\(([\d.]+),([\d.]+),([\d.]+),([\d.]+)\)$/))) {
      const [f0, f1, ms, step] = m.slice(1).map(Number);
      const n = Math.round(ms / step);
      for (let k = 0; k < n; k++) notes.push([step / 1000, pitchOf(f0 * (f1 / f0) ** (k / (n - 1)))]);
    } else if ((m = t.match(/^buzz\((-?[\d.]+),(-?[\d.]+),([\d.]+),([\d.]+)\)$/))) {
      const [a, b, step, ms] = m.slice(1).map(Number);
      const n = Math.round(ms / step);
      for (let k = 0; k < n; k++) notes.push([step / 1000, k % 2 ? b : a]);
    } else if ((m = t.match(/^pulse\(([\d.]+),([\d.]+),([\d.]+),(\d+)\)$/))) {
      const [hz, on, off, count] = m.slice(1).map(Number);
      for (let k = 0; k < count; k++) notes.push([on / 1000, pitchOf(hz)], [off / 1000, null]);
    } else if ((m = t.match(/^R:([\d.]+)$/))) notes.push([Number(m[1]), null]);
    else if ((m = t.match(/^X:([\d.]+)$/))) notes.push([Number(m[1]), "noise"]);
    else if ((m = t.match(/^(-?\d+):([\d.]+)$/))) notes.push([Number(m[2]), Number(m[1])]);
    else if ((m = t.match(/^([A-G]#?)(\d):([\d.]+)$/))) notes.push([Number(m[3]), 12 * (Number(m[2]) - 4) + NAMES[m[1]]]);
    else throw new Error(`bad sound token: ${t}`);
  }
  return notes;
}

export interface Motif { notes: readonly Note[]; volume: number; seconds: number }

/** Every motif, ready to play. */
export const MOTIFS = Object.fromEntries(
  Object.entries(MOTIF_SPECS).map(([id, spec]) => [id, { notes: parseRecipe(spec.recipe), volume: spec.volume, seconds: spec.seconds }]),
) as Record<MotifId, Motif>;

/** The length of some notes in seconds. */
export const duration = (notes: readonly Note[]): number => notes.reduce((t, [s]) => t + s, 0);

/** The rating tally blip for the i-th line (0-based): a whole tone higher each time. */
export const tally = (i: number): readonly Note[] => [[0.03, 12 + 2 * i]];
