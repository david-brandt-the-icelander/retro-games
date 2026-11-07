// The browser's side of the high-score table (worker/index.ts is the server).
// Every call is best effort: when the server can't be reached, the game still plays,
// it just can't be entered on the table.
import { cleanName, nameFromEmail } from "./name";

export interface Reign { id: string; seed: number }
export interface TableRow { name: string; score: number; months: number; alive: boolean }
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

/** Ask the server for this reign's seed, so that the reign can be replayed and entered later. */
export const startReign = () => call<Reign>(api("game"), { method: "POST", body: "{}" }, 3000);

/** Send the keys of a finished reign; the server replays it and records the score it computes. */
export const submitReign = (reign: Reign, keys: string[], name: string) =>
  call<Entry>(api("score"), { method: "POST", body: JSON.stringify({ id: reign.id, keys, name }) }, 10000);

export async function loadTable(): Promise<TableRow[] | null> {
  const r = await call<{ scores: TableRow[] }>(api("scores"));
  return r ? r.scores : null;
}

// ── The player's name ────────────────────────────────────────────────────

/** Shared by every game on icelander.net, for this browser session. */
const NAME_KEY = "games.name";

/** Who is signed in at games.icelander.net (the games hub, in the recreations repository): the part of their email before the @. */
const ME = "/me";

export function saveName(name: string): void {
  try { sessionStorage.setItem(NAME_KEY, name); } catch { /* storage blocked: the name lasts this screen only */ }
}

/**
 * The name to offer: the one entered earlier this session; otherwise, for a player signed in to
 * the games, the part of their email before the @; otherwise none.
 */
export async function defaultName(): Promise<string> {
  try {
    const saved = sessionStorage.getItem(NAME_KEY);
    if (saved !== null) return cleanName(saved);
  } catch { /* storage blocked */ }
  const me = await call<{ name: string | null }>(new URL(ME, location.href).toString(), { credentials: "same-origin" }, 3000);
  return me?.name ? nameFromEmail(me.name) : "";
}
