// The browser's side of the public high-score table (worker/index.ts is the server).
// Every call is best effort: when the server can't be reached the game still plays; it just
// can't be entered on the public table, and scores are kept on this device only.
import type { Recording } from "./engine/replay";

export interface Ticket { id: string; seed: number }
export interface PublicRow { name: string; score: number; wave: number; mode: string; players: number }
export interface Result { player: number; score: number; wave: number; name: string | null; rank: number | null }

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

/** Asks the server for this game's seed, so that the game can be replayed and entered later. */
export const startGame = () => call<Ticket>("game", { method: "POST", body: "{}" }, 2500);

/** Sends a finished game; the server replays it and records the scores it computes. */
export async function submitGame(ticket: Ticket, recording: Recording, names: (string | null)[]): Promise<Result[] | null> {
  // The server replays from the seed it issued, so the recording goes without one.
  const { mode, players, steps, log } = recording;
  const body = JSON.stringify({ id: ticket.id, recording: { mode, players, steps, log }, names });
  const r = await call<{ results: Result[] }>("score", { method: "POST", body }, 20000);
  return r ? r.results : null;
}

export async function loadPublic(): Promise<PublicRow[] | null> {
  const r = await call<{ scores: PublicRow[] }>("scores");
  return r ? r.scores : null;
}
