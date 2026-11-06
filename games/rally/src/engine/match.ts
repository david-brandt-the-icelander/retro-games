// A one-player match as the high-score table sees it: the seed the server issued, the computer's
// level, and the player's paddle controls tick by tick. The server replays the match from these
// with the same engine, so a score is only ever what the match really scored.
import { Cpu, LEVELS, type LevelName } from "./ai";
import { H, newMatch, step, type Control, type Side } from "./rules";

/** The fixed step every match runs at, in the browser and in a replay. */
export const DT = 1 / 120;
/** The longest match the server will replay: 30 minutes. */
export const MAX_TICKS = 120 * 60 * 30;

/** What each point the player wins is worth, by the computer's level. Winning the match adds ten points' worth. */
export const POINT_VALUE: Record<LevelName, number> = { easy: 100, normal: 200, hard: 300 };
export const WIN_BONUS_POINTS = 10;

/** The player's score for a finished one-player match: they are side 0. */
export function scoreOf(level: LevelName, score: readonly [number, number], winner: Side | null): number {
  return POINT_VALUE[level] * (score[0] + (winner === 0 ? WIN_BONUS_POINTS : 0));
}

/** The computer's own seed, derived from the match's, so one seed from the server covers both. */
export const cpuSeed = (seed: number): number => (seed ^ 0x9e3779b9) >>> 0;

/** A change in the player's control: from this tick on, until the next change. target -1 means none. */
export type Move = [tick: number, dir: -1 | 0 | 1, target: number];
export interface Recording { ticks: number; moves: Move[] }

/**
 * The player's control as it is played and recorded: a finger or mouse target in whole pixels
 * on the table, so a recording replays it exactly.
 */
export function quantise(c: Control): Control {
  return c.target === null ? { dir: c.dir, target: null } : { dir: 0, target: Math.max(0, Math.min(H, Math.round(c.target))) };
}

const controlOf = (m: Move): Control => (m[2] < 0 ? { dir: m[1], target: null } : { dir: 0, target: m[2] });

/** Records the player's controls, one Move per change. */
export class Recorder {
  readonly moves: Move[] = [];
  ticks = 0;
  private last = "";

  /** Call once per tick, with the control that tick is played with. */
  record(c: Control): void {
    const move: Move = [this.ticks, c.target === null ? c.dir : 0, c.target === null ? -1 : c.target];
    const key = `${move[1]},${move[2]}`;
    if (key !== this.last) { this.moves.push(move); this.last = key; }
    this.ticks++;
  }

  get recording(): Recording { return { ticks: this.ticks, moves: this.moves }; }
}

export interface Result { score: number; mine: number; theirs: number; won: boolean }

function wellFormed(rec: unknown): rec is Recording {
  if (!rec || typeof rec !== "object") return false;
  const { ticks, moves } = rec as Recording;
  if (!Number.isInteger(ticks) || ticks < 1 || ticks > MAX_TICKS) return false;
  if (!Array.isArray(moves) || moves.length > ticks) return false;
  let prev = -1;
  for (const m of moves) {
    if (!Array.isArray(m) || m.length !== 3) return false;
    const [t, dir, target] = m;
    if (!Number.isInteger(t) || t <= prev || t >= ticks) return false;
    if (dir !== -1 && dir !== 0 && dir !== 1) return false;
    if (!Number.isInteger(target) || target < -1 || target > H || (target >= 0 && dir !== 0)) return false;
    prev = t;
  }
  return true;
}

/**
 * Plays a one-player match again from its seed, level and recording. Returns its result, or null
 * unless the recording is well formed and the match ends exactly on its last tick.
 */
export function replay(seed: number, level: LevelName, rec: unknown): Result | null {
  if (!Object.prototype.hasOwnProperty.call(LEVELS, level) || !wellFormed(rec)) return null;
  const s = newMatch(seed);
  const cpu = new Cpu(1, LEVELS[level], cpuSeed(seed));
  let next = 0;
  let control: Control = { dir: 0, target: null };
  for (let t = 0; t < rec.ticks; t++) {
    if (next < rec.moves.length && rec.moves[next][0] === t) control = controlOf(rec.moves[next++]);
    step(s, [control, cpu.control(s, DT)], DT);
    if (s.phase === "over" && t !== rec.ticks - 1) return null;
  }
  if (s.phase !== "over") return null;
  return { score: scoreOf(level, s.score, s.winner), mine: s.score[0], theirs: s.score[1], won: s.winner === 0 };
}
