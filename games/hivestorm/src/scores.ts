// The browser's side of the high-score table (worker/index.ts is the server).
// Every call is best effort: when the server can't be reached, the game still plays,
// it just can't be entered on the table.

export interface Ticket { id: string; seed: number }
export interface TableRow { name: string; score: number; wave: number; players: number }
export interface Entry { player: number; name: string; score: number; wave: number; rank: number }

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

/** A seed for the next game, issued by the server so the game can be replayed and entered later. */
export const newTicket = () => call<Ticket>("game", { method: "POST", body: "{}" }, 4000);

/** Sends a finished game's controls and the players' names; the server replays it and records the scores it computes. */
export const submitGame = (ticket: Ticket, runs: number[], names: (string | null)[]) =>
  call<{ entries: Entry[] }>("score", { method: "POST", body: JSON.stringify({ id: ticket.id, runs, names }) }, 15000);

export async function loadTable(): Promise<TableRow[] | null> {
  const r = await call<{ scores: TableRow[] }>("scores");
  return r ? r.scores : null;
}

/** Whether a score would make the ten-row table. */
export const qualifies = (score: number, table: { score: number }[] | null, size = 10) =>
  score > 0 && (!table || table.length < size || score > table[table.length - 1].score);
