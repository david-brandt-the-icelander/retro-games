// The browser's side of the high-score table (worker/index.ts is the server). Every call is best
// effort: when the server can't be reached, the game still plays; it just can't be entered.
import type { LevelName } from "./engine/ai";
import type { Recording } from "./engine/match";
import { cleanName, nameFromEmail } from "./name";

export interface Match { id: string; seed: number }
export interface TableRow { name: string; score: number; level: LevelName; mine: number; theirs: number; won: boolean }
export interface Entry { score: number; rank: number; name: string }

const api = (path: string) => new URL(`api/${path}`, location.href).toString();

async function call<T>(url: string, init?: RequestInit, ms = 5000): Promise<T | null> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    const res = await fetch(url, { ...init, signal: ctrl.signal, headers: { "Content-Type": "application/json" } });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/** A seed for a one-player match, from the server, so the match can be replayed and entered later. */
export const startMatch = () => call<Match>(api("game"), { method: "POST", body: "{}" }, 2500);

/** Send the finished match; the server replays it and records the score it computes. */
export const submitMatch = (match: Match, level: LevelName, recording: Recording, name: string) =>
  call<Entry>(api("score"), { method: "POST", body: JSON.stringify({ id: match.id, name, level, recording }) }, 10000);

export async function loadTable(): Promise<TableRow[] | null> {
  const r = await call<{ scores: TableRow[] }>(api("scores"));
  return r ? r.scores : null;
}

// ── The player's name, shared by every game on icelander.net for this browser session ──

const NAME_KEY = "games.name";
/** Who is signed in at games.icelander.net (the games hub, in the recreations repository): the part of their email before the @. */
const ME = "/me";

export function saveName(name: string): void {
  try { sessionStorage.setItem(NAME_KEY, name); } catch { /* storage blocked: the name lasts this screen only */ }
}

/** The name entered earlier this session; otherwise a signed-in player's email before the @; otherwise none. */
export async function defaultName(): Promise<string> {
  try {
    const saved = sessionStorage.getItem(NAME_KEY);
    if (saved !== null) return cleanName(saved);
  } catch { /* storage blocked */ }
  const me = await call<{ name: string | null }>(new URL(ME, location.href).toString(), { credentials: "same-origin" }, 3000);
  return me?.name ? nameFromEmail(me.name) : "";
}
