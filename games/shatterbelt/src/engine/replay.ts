// A game as a recording: the seed, the mode, the players, and every change of anyone's controls.
// The browser records while it plays; the server replays the recording through the same engine to
// get the scores itself, so a score can't be made up in the browser.
import { MAX_PLAYERS } from "./config";
import { newGame, step, type Controls, type Game } from "./game";

export type RankedMode = "coop" | "versus";

export interface Recording {
  mode: RankedMode;
  players: number;
  seed: number;
  /** Steps played, up to and including the one that ended the game. */
  steps: number;
  /** Flat triples [steps since the previous change, player, controls as bits], in order. */
  log: number[];
}

/** Ninety minutes of play; a longer game is not accepted. */
export const MAX_STEPS = 60 * 60 * 90;
export const MAX_LOG = 3 * 250_000;

const KEYS = ["left", "right", "thrust", "fire", "blink"] as const;

export function toBits(c: Controls): number {
  let b = 0;
  KEYS.forEach((k, i) => { if (c[k]) b |= 1 << i; });
  return b;
}

export function fromBits(b: number): Controls {
  return { left: !!(b & 1), right: !!(b & 2), thrust: !!(b & 4), fire: !!(b & 8), blink: !!(b & 16) };
}

/** Call record(inputs) right before each step(game, inputs). */
export class Recorder {
  private prev: number[];
  private lastChange = 0;
  readonly log: number[] = [];
  steps = 0;

  constructor(players: number) {
    this.prev = new Array(players).fill(0);
  }

  record(inputs: readonly Controls[]): void {
    inputs.forEach((c, p) => {
      const bits = toBits(c);
      if (bits !== this.prev[p]) {
        this.log.push(this.steps - this.lastChange, p, bits);
        this.lastChange = this.steps;
        this.prev[p] = bits;
      }
    });
    this.steps++;
  }
}

const isInt = (n: unknown, lo: number, hi: number): n is number => typeof n === "number" && Number.isInteger(n) && n >= lo && n <= hi;

/** Checks a recording's shape (not yet its play). */
export function validRecording(r: unknown): r is Recording {
  if (!r || typeof r !== "object") return false;
  const x = r as Record<string, unknown>;
  if (x.mode !== "coop" && x.mode !== "versus") return false;
  if (!isInt(x.players, 1, MAX_PLAYERS) || !isInt(x.seed, 0, 0xffffffff) || !isInt(x.steps, 1, MAX_STEPS)) return false;
  const log = x.log;
  if (!Array.isArray(log) || log.length > MAX_LOG || log.length % 3 !== 0) return false;
  for (let i = 0; i < log.length; i += 3) {
    if (!isInt(log[i], 0, MAX_STEPS) || !isInt(log[i + 1], 0, (x.players as number) - 1) || !isInt(log[i + 2], 0, 31)) return false;
  }
  return true;
}

/**
 * Plays a recording through the engine. Returns the finished game, or null unless the recording
 * plays exactly one whole game: it must end on its last step, with every change used.
 */
export function replay(r: Recording): Game | null {
  if (!validRecording(r)) return null;
  const g = newGame(r.mode, r.players, r.seed);
  const held: Controls[] = Array.from({ length: r.players }, () => fromBits(0));
  let i = 0;
  let at = r.log.length ? r.log[0] : Infinity;
  for (let s = 0; s < r.steps; s++) {
    while (i < r.log.length && at === s) {
      held[r.log[i + 1]] = fromBits(r.log[i + 2]);
      i += 3;
      at = i < r.log.length ? at + r.log[i] : Infinity;
    }
    if (g.over) return null; // the game had already ended
    step(g, held);
  }
  return g.over && i === r.log.length ? g : null;
}
