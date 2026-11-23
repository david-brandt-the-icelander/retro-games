// What the page and the room's Durable Object say to each other over the WebSocket, as JSON.
// The room sends each connection its own View: the key (which word belongs to whom) goes only
// to clue-givers, and to everyone once the game is over.

export type Team = "hraun" | "jokull";
export type Role = "clue" | "guess";
export type CardKind = Team | "neutral" | "ghost";
export const TEAMS: readonly Team[] = ["hraun", "jokull"];
export const other = (t: Team): Team => (t === "hraun" ? "jokull" : "hraun");

/** Turn timer choices, in seconds; 0 is off. */
export const TIMERS = [0, 60, 90, 120, 180] as const;

export const MAX_PLAYERS = 12;
export const MAX_NAME = 20;
export const MAX_CUSTOM_WORDS = 1000;

export type ClientMsg =
  | { t: "hello"; seat?: { id: string; token: string } | null; screen?: boolean }
  | { t: "join"; name: string }
  | { t: "claim"; id: string }
  | { t: "screen" }
  | { t: "name"; name: string }
  | { t: "team"; id: string; team: Team }
  | { t: "clueGiver"; id: string }
  | { t: "shuffle" }
  | { t: "remove"; id: string }
  | { t: "timer"; seconds: number }
  | { t: "words"; text: string | null }
  | { t: "start" }
  | { t: "clue"; word: string; number: number }
  | { t: "guess"; index: number }
  | { t: "stop" }
  | { t: "newGame" }
  | { t: "lobby" }
  | { t: "leave" };

export type ErrorCode =
  | "bad" // a message the room does not understand
  | "noRoom"
  | "full"
  | "name"
  | "notHost"
  | "notNow"
  | "notYou"
  | "needTeams"
  | "clueWord"
  | "clueOnBoard"
  | "clueNumber"
  | "revealed"
  | "guessFirst"
  | "fewWords"
  | "seatTaken";

export type ServerMsg =
  | { t: "state"; view: View }
  | { t: "seat"; id: string; token: string }
  | { t: "unseated" }
  | { t: "error"; code: ErrorCode }
  | { t: "gone" };

export interface PlayerView { id: string; name: string; team: Team; role: Role; online: boolean }

export interface Clue { team: Team; word: string; number: number }

/** What happened last, for the line that tells everyone. */
export type GameEvent =
  | { type: "guess"; team: Team; index: number; by: string }
  | { type: "stop"; team: Team }
  | { type: "timeout"; team: Team }
  | { type: "clue"; team: Team };

export interface CardView {
  word: string;
  /** Null when this viewer may not know yet. */
  kind: CardKind | null;
  revealed: boolean;
}

export interface GameView {
  number: number;
  cards: CardView[];
  first: Team;
  turn: Team;
  phase: "clue" | "guess" | "over";
  clue: Clue | null;
  /** Guesses left this turn (the clue's number plus one, less guesses made). */
  left: number;
  made: number;
  winner: Team | null;
  /** The game ended on the game-over word. */
  ghost: boolean;
  clues: Clue[];
  remaining: Record<Team, number>;
  /** When the turn timer runs out, in the room's clock (View.now), or null. */
  deadline: number | null;
  event: GameEvent | null;
}

export interface View {
  code: string;
  /** The room's clock when it sent this, for the countdown. */
  now: number;
  you: PlayerView | null;
  screen: boolean;
  /** Whoever runs the room now: its creator, or while they are away, whoever joined first. */
  hostId: string | null;
  players: PlayerView[];
  timer: number;
  /** How many words the host's own list has; 0 for the built-in list. */
  customWords: number;
  game: GameView | null;
}
