// The rules of chess, shared by the browser and the server. Move legality comes from chess.js;
// this file turns a game (a list of moves in UCI notation, "e2e4", "e7e8q") into its position
// and its result, so that both sides judge a game in exactly the same way.
import { Chess, type Square } from "chess.js";

export type Side = "white" | "black";
export type Result = "1-0" | "0-1" | "1/2-1/2" | "*";
/** Why a game ended. The first five follow from the board; the rest from the players. */
export type Reason = "checkmate" | "stalemate" | "material" | "repetition" | "fifty" | "resign" | "agreement" | "abandoned";

export interface Outcome { result: Result; reason: Reason | null }

export const START_FEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";
const UCI = /^[a-h][1-8][a-h][1-8][qrbn]?$/;

export const other = (s: Side): Side => (s === "white" ? "black" : "white");
export const sideOf = (c: "w" | "b"): Side => (c === "w" ? "white" : "black");
export const sideToMove = (plies: number): Side => (plies % 2 === 0 ? "white" : "black");

/** Plays one UCI move on a board. Returns its SAN, or null if it is not legal. */
export function play(chess: Chess, uci: string): string | null {
  if (!UCI.test(uci)) return null;
  try {
    const m = chess.move({ from: uci.slice(0, 2) as Square, to: uci.slice(2, 4) as Square, promotion: uci[4] });
    return m ? m.san : null;
  } catch {
    return null;
  }
}

/** Replays a list of UCI moves from the start. Returns the board and the SAN of each move, or null at the first illegal move. */
export function replay(moves: readonly string[]): { chess: Chess; san: string[] } | null {
  const chess = new Chess();
  const san: string[] = [];
  for (const uci of moves) {
    const s = play(chess, uci);
    if (s === null) return null;
    san.push(s);
  }
  return { chess, san };
}

/** The result the board itself decides (mate or a forced draw), or "*" while the game can go on. */
export function boardOutcome(chess: Chess): Outcome {
  if (chess.isCheckmate()) return { result: chess.turn() === "w" ? "0-1" : "1-0", reason: "checkmate" };
  if (chess.isStalemate()) return { result: "1/2-1/2", reason: "stalemate" };
  if (chess.isInsufficientMaterial()) return { result: "1/2-1/2", reason: "material" };
  if (chess.isThreefoldRepetition()) return { result: "1/2-1/2", reason: "repetition" };
  if (chess.isDrawByFiftyMoves()) return { result: "1/2-1/2", reason: "fifty" };
  return { result: "*", reason: null };
}

/** The result when `side` resigns. */
export const resignation = (side: Side): Outcome => ({ result: side === "white" ? "0-1" : "1-0", reason: "resign" });

/** The result from one side's point of view. */
export function scoreFor(result: Result, side: Side): "win" | "loss" | "draw" | "playing" {
  if (result === "*") return "playing";
  if (result === "1/2-1/2") return "draw";
  return (result === "1-0") === (side === "white") ? "win" : "loss";
}

/** How a finished game ended, in words. */
export function describe(o: Outcome, white = "White", black = "Black"): string {
  if (o.result === "*") return "In play";
  const winner = o.result === "1-0" ? white : black;
  const loser = o.result === "1-0" ? black : white;
  switch (o.reason) {
    case "checkmate": return `Checkmate. ${winner} wins`;
    case "resign": return `${loser} resigned. ${winner} wins`;
    case "abandoned": return `${loser} left the game. ${winner} wins`;
    case "stalemate": return "Stalemate. A draw";
    case "material": return "Neither side can mate. A draw";
    case "repetition": return "Threefold repetition. A draw";
    case "fifty": return "Fifty moves without a capture or pawn move. A draw";
    case "agreement": return "Draw agreed";
    default: return o.result === "1/2-1/2" ? "A draw" : `${winner} wins`;
  }
}

/** True for a well-formed move list: at most 600 UCI moves. */
export function validMoveList(x: unknown): x is string[] {
  return Array.isArray(x) && x.length <= 600 && x.every((m) => typeof m === "string" && UCI.test(m));
}
