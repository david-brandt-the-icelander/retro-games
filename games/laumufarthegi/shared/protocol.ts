// What the browser and the room's Durable Object say to each other over the WebSocket, as JSON.
import type { Action, View } from "./game";

/** The game's address on icelander.net. */
export const BASE = "/games/laumufarthegi";

/** Room codes: five letters, none that look alike (no I, O, Q, W). */
export const CODE_LETTERS = "ABCDEFGHJKLMNPRSTUVXYZ";
export const CODE_LENGTH = 5;
export const isCode = (x: unknown): x is string => typeof x === "string" && new RegExp(`^[${CODE_LETTERS}]{${CODE_LENGTH}}$`).test(x);

/** Browser → room. The first message on a socket must be "join": with a token to take back a seat, or a name for a new one. */
export type ClientMessage = { t: "join"; token?: string; name?: string } | Action;

/** Room → browser. */
export type ServerMessage =
  | { t: "welcome"; token: string; playerId: string }
  | { t: "state"; view: View }
  | { t: "error"; message: string }
  | { t: "removed" };

/** The answer to POST {BASE}/api/rooms. */
export interface CreatedRoom { code: string; token: string; playerId: string }
