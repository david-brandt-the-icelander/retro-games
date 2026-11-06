// The best pilots: the top ten scores, kept in this browser.
import type { Mode } from "./engine/game";

export interface Entry {
  name: string;
  score: number;
  wave: number;
  mode: Exclude<Mode, "attract">;
  players: number;
}

const KEY = "shatterbelt.scores.v1";
export const TABLE_SIZE = 10;

export function loadScores(): Entry[] {
  try {
    const raw = JSON.parse(localStorage.getItem(KEY) ?? "[]") as unknown;
    if (!Array.isArray(raw)) return [];
    return raw
      .filter((e): e is Entry => !!e && typeof e.name === "string" && Number.isFinite(e.score))
      .map((e) => ({ ...e, name: e.name.slice(0, 3).toUpperCase() }))
      .sort((a, b) => b.score - a.score)
      .slice(0, TABLE_SIZE);
  } catch {
    return [];
  }
}

export function qualifies(table: Entry[], score: number): boolean {
  return score > 0 && (table.length < TABLE_SIZE || score > table[table.length - 1].score);
}

/** Adds an entry, keeps the table sorted and trimmed, saves it, and returns it. */
export function addScore(table: Entry[], entry: Entry): Entry[] {
  const next = [...table, entry].sort((a, b) => b.score - a.score).slice(0, TABLE_SIZE);
  try { localStorage.setItem(KEY, JSON.stringify(next)); } catch { /* kept for this visit only */ }
  return next;
}
