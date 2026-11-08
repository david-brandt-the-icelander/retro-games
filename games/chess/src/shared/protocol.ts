// What the browser and the Worker say to each other. Every path is under BASE.
import type { Reason, Result, Side } from "./rules";

export const BASE = "/retro/chess";

export interface User { id: string; email: string; name: string }

export interface Me { user: User | null; providers: string[] }

export interface PlayerRef { id: string | null; email: string | null; name: string }

export interface GameView {
  id: string;
  kind: "online" | "computer";
  /** The computer's strength, 1–8, for games against it. */
  level: number | null;
  white: PlayerRef;
  black: PlayerRef;
  moves: string[];
  result: Result;
  reason: Reason | null;
  /** The side that has offered a draw, until the other answers or a move is made. */
  drawOffer: Side | null;
  created: number;
  updated: number;
}

export interface Challenge {
  id: string;
  from: PlayerRef;
  toEmail: string;
  /** The colour the challenger plays. */
  color: Side | "random";
  status: "open" | "accepted" | "declined" | "cancelled";
  gameId: string | null;
  created: number;
}

export interface Contact {
  email: string;
  name: string | null;
  /** Finished games against them, from the owner's side. */
  wins: number;
  losses: number;
  draws: number;
  lastPlayed: number | null;
  /** True when they have signed in to the game at least once. */
  joined: boolean;
}

export interface Lobby {
  incoming: Challenge[];
  outgoing: Challenge[];
  active: GameView[];
  contacts: Contact[];
}

/** Actions a player takes in an online game. `ply` is the number of moves already made when the player chose it. */
export type Action =
  | { type: "move"; uci: string; ply: number }
  | { type: "resign" }
  | { type: "draw-offer" }
  | { type: "draw-accept" }
  | { type: "draw-decline" };

/** What the live connection sends: the whole game after every change. */
export type LiveMessage = { t: "state"; game: GameView } | { t: "error"; error: string } | { t: "pong" };

/** Normalises an email address for comparison; null if it doesn't look like one. */
export function cleanEmail(x: unknown): string | null {
  if (typeof x !== "string") return null;
  const e = x.trim().toLowerCase();
  if (e.length > 254 || !/^[^\s@<>()",;:]+@[^\s@<>()",;:]+\.[a-z0-9-]{2,}$/.test(e)) return null;
  return e;
}

/** A display name: printable, at most 40 characters. */
export function cleanDisplayName(x: unknown): string {
  if (typeof x !== "string") return "";
  return x.replace(/[\u0000-\u001f\u007f<>]/g, "").trim().slice(0, 40);
}

/** The computer's eight strengths. */
export const LEVELS: readonly { name: string; blurb: string; elo: string }[] = [
  { name: "Pawn Pusher", blurb: "Just learned how the knight moves", elo: "~400" },
  { name: "Weekend Wood", blurb: "Plays fast, hangs pieces", elo: "~800" },
  { name: "Club Novice", blurb: "Knows a few tricks", elo: "~1100" },
  { name: "Café Regular", blurb: "Punishes loose pieces", elo: "~1400" },
  { name: "Club Captain", blurb: "Solid and patient", elo: "~1700" },
  { name: "County Champ", blurb: "Sees tactics you miss", elo: "~2000" },
  { name: "Master", blurb: "Bring your best game", elo: "~2300" },
  { name: "The Machine", blurb: "Full strength. Good luck", elo: "2800+" },
];
