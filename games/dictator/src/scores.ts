// The browser's side of the high-score table (worker/index.ts is the server).
// Every call is best effort: when the server can't be reached, the game still plays,
// it just can't be entered on the table.

export interface Reign { id: string; seed: number }
export interface TableRow { name: string; score: number; months: number; alive: boolean }
export interface Entry { score: number; rank: number; name: string }

const api = (path: string) => new URL(`api/${path}`, location.href).toString();

async function call<T>(path: string, init?: RequestInit, ms = 5000): Promise<T | null> {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), ms);
  try {
    const res = await fetch(api(path), { ...init, signal: ctrl.signal, headers: { "Content-Type": "application/json" } });
    return res.ok ? ((await res.json()) as T) : null;
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

/** Ask the server for this reign's seed, so that the reign can be replayed and entered later. */
export const startReign = () => call<Reign>("game", { method: "POST", body: "{}" }, 3000);

/** Send the keys of a finished reign; the server replays it and records the score it computes. */
export const submitReign = (reign: Reign, keys: string[], name: string) =>
  call<Entry>("score", { method: "POST", body: JSON.stringify({ id: reign.id, keys, name }) }, 10000);

export async function loadTable(): Promise<TableRow[] | null> {
  const r = await call<{ scores: TableRow[] }>("scores");
  return r ? r.scores : null;
}


