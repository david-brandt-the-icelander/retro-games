// What a player's action does to an online game. Pure: the Durable Object (worker/room.ts) loads
// the game, calls applyAction, and saves and broadcasts what it returns.
import type { Action, GameView } from "../src/shared/protocol";
import { boardOutcome, other, replay, resignation, sideToMove, type Side } from "../src/shared/rules";

export type Applied = { ok: true; game: GameView } | { ok: false; error: string };

/** The side `userId` plays in a game, or null if they don't play in it. */
export function sideOf(game: GameView, userId: string): Side | null {
  if (game.white.id === userId) return "white";
  if (game.black.id === userId) return "black";
  return null;
}

export function applyAction(game: GameView, side: Side, action: Action, now: number): Applied {
  if (game.result !== "*") return { ok: false, error: "The game is over." };
  const next: GameView = { ...game, moves: [...game.moves], updated: Math.max(now, game.updated + 1) };
  switch (action.type) {
    case "move": {
      if (action.ply !== game.moves.length) return { ok: false, error: "The board changed; try again." };
      if (sideToMove(game.moves.length) !== side) return { ok: false, error: "It isn't your move." };
      const played = replay([...game.moves, action.uci]);
      if (!played) return { ok: false, error: "That move isn't legal." };
      next.moves.push(action.uci);
      // A move answers the other side's draw offer with a no, and withdraws one's own.
      next.drawOffer = null;
      const o = boardOutcome(played.chess);
      next.result = o.result;
      next.reason = o.reason;
      return { ok: true, game: next };
    }
    case "resign": {
      const o = resignation(side);
      next.result = o.result;
      next.reason = o.reason;
      next.drawOffer = null;
      return { ok: true, game: next };
    }
    case "draw-offer":
      if (game.drawOffer === other(side)) return applyAction(game, side, { type: "draw-accept" }, now);
      if (game.drawOffer === side) return { ok: false, error: "You have already offered a draw." };
      next.drawOffer = side;
      return { ok: true, game: next };
    case "draw-accept":
      if (game.drawOffer !== other(side)) return { ok: false, error: "There is no draw offer to accept." };
      next.result = "1/2-1/2";
      next.reason = "agreement";
      next.drawOffer = null;
      return { ok: true, game: next };
    case "draw-decline":
      if (game.drawOffer !== other(side)) return { ok: false, error: "There is no draw offer to decline." };
      next.drawOffer = null;
      return { ok: true, game: next };
    default:
      return { ok: false, error: "Unknown action." };
  }
}

/** True for a well-formed action from the browser. */
export function validAction(x: unknown): x is Action {
  if (!x || typeof x !== "object") return false;
  const a = x as Record<string, unknown>;
  if (a.type === "move") return typeof a.uci === "string" && a.uci.length <= 5 && Number.isInteger(a.ply) && (a.ply as number) >= 0;
  return a.type === "resign" || a.type === "draw-offer" || a.type === "draw-accept" || a.type === "draw-decline";
}
