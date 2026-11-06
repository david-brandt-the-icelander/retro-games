// Parity kit (verify role). Copy this file to scratch storage, never into the game:
// the baseline adapter you write next to it imports the private baseline.
//
// Each run of a game becomes a list of steps: the canonical screen kind and a snapshot
// of the game state taken when that screen is shown (before its key is applied).
// See README.md beside this file for the adapters and the run loop.

/** The game state in RULES' own terms. Each game defines its own fields; keep them JSON-comparable. */
export type Snapshot = Record<string, unknown>;
export interface Step { kind: string; state: Snapshot }
export interface Policy { key(kind: string, screen: unknown): string }

/** The same mixing function as the template's engine RNG, used here only for input policies. */
export function mulberry(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 2 ** 32;
  };
}
const pick = <T,>(r: () => number, xs: readonly T[]): T => xs[Math.floor(r() * xs.length)];

/**
 * An input policy. `choices` maps each *decision* kind (a screen whose key changes the game)
 * to the keys to choose from. The policy draws from its own RNG **only on those kinds**.
 * Other screens get `neutral(kind)`, a fixed key chosen without drawing: the two runs can
 * show different numbers of non-decision screens (one game splits a screen the other shows
 * as one), and a draw there would push the two input streams out of step.
 */
export function policy(seed: number, choices: Record<string, readonly string[]>, neutral: (kind: string) => string = () => " "): Policy {
  const r = mulberry(seed);
  return { key: (kind) => (kind in choices ? pick(r, choices[kind]) : neutral(kind)) };
}

/** A neutral key per kind that varies by kind but draws nothing: handy for "junk key" policies. */
export const junkFor = (junk: readonly string[]) => (kind: string) =>
  junk[[...kind].reduce((h, c) => h + c.charCodeAt(0), 0) % junk.length];

export interface DiffOptions {
  /** Kinds where the state must match exactly: every decision screen, every screen that displays numbers, and "end". */
  checked: ReadonlySet<string>;
  /** Kinds only the remake shows (e.g. an added funeral screen); dropped before comparing. */
  remakeOnly?: ReadonlySet<string>;
}

export interface DiffReport { first: string | null; reordered: Record<string, number> }

const same = (x: Snapshot, y: Snapshot) => JSON.stringify(x) === JSON.stringify(y);
function firstField(x: Snapshot, y: Snapshot): string {
  for (const k of Object.keys(x)) if (JSON.stringify(x[k]) !== JSON.stringify(y[k])) return k;
  return "";
}

/**
 * Compare a baseline run (a) with a remake run (b). Screen kinds must match at every step.
 * State must match exactly at the `checked` kinds. Elsewhere a state difference means a
 * change was applied on the other side of a screen that takes no decision and shows no
 * numbers: that is presentation order, not behaviour. It is counted in `reordered` by
 * "kind:field" so the report can list and explain every one.
 */
export function diff(a: Step[], b: Step[], opts: DiffOptions): DiffReport {
  const bb = opts.remakeOnly ? b.filter((s) => !opts.remakeOnly!.has(s.kind)) : b;
  const reordered: Record<string, number> = {};
  const n = Math.max(a.length, bb.length);
  for (let i = 0; i < n; i++) {
    const x = a[i], y = bb[i];
    if (!x || !y) return { first: `step ${i}: length ${a.length} vs ${bb.length} (${x?.kind ?? "-"} vs ${y?.kind ?? "-"})`, reordered };
    if (x.kind !== y.kind) return { first: `step ${i}: kind ${x.kind} vs ${y.kind} (after ${a[i - 1]?.kind ?? "start"})`, reordered };
    if (same(x.state, y.state)) continue;
    const field = firstField(x.state, y.state);
    if (!opts.checked.has(x.kind)) { reordered[`${x.kind}:${field}`] = (reordered[`${x.kind}:${field}`] ?? 0) + 1; continue; }
    return { first: `step ${i} (${x.kind}, after ${a[i - 1]?.kind ?? "start"}): ${field} ${JSON.stringify(x.state[field])} vs ${JSON.stringify(y.state[field])}`, reordered };
  }
  return { first: null, reordered };
}
