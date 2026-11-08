// What a player's action does to an online game. Pure: the Durable Object (worker/room.ts) loads
// the game, calls applyAction, and saves and broadcasts what it returns. Every action adds to the
// game's transcript: the action itself and, when it ends the game, an "end" entry.
import { MAX_CHAT, type Action, type GameEvent, type GameView } from "../shared/protocol";
import { boardOutcome, other, replay, resignation, sideToMove, type Outcome, type Side } from "../shared/rules";

export type Applied = { ok: true; game: GameView; added: GameEvent[] } | { ok: false; error: string };

/** The side `userId` plays in a game, or null if they don't play in it. */
export function sideOf(game: GameView, userId: string): Side | null {
  if (game.white.id === userId) return "white";
  if (game.black.id === userId) return "black";
  return null;
}

/** Cleans a chat message: no control characters, at most MAX_CHAT characters; empty if nothing is left. */
export function cleanChat(x: unknown): string {
  if (typeof x !== "string") return "";
  return x.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, "").replace(/\n{3,}/g, "\n\n").trim().slice(0, MAX_CHAT);
}

export function applyAction(game: GameView, side: Side, action: Action, now: number): Applied {
  const at = Math.max(now, game.updated + 1);
  const next: GameView = { ...game, moves: [...game.moves], updated: at, events: [...game.events] };
  const added: GameEvent[] = [];
  const log = (kind: GameEvent["kind"], who: Side | null, text: string | null) => {
    const e: GameEvent = { seq: (next.events.at(-1)?.seq ?? 0) + 1, at, kind, side: who, text };
    next.events.push(e);
    added.push(e);
  };
  const finish = (o: Outcome) => {
    next.result = o.result;
    next.reason = o.reason;
    next.drawOffer = null;
    if (o.result !== "*") log("end", null, `${o.result} ${o.reason}`);
  };
  const done = (): Applied => ({ ok: true, game: next, added });

  if (action.type === "chat") {
    const text = cleanChat(action.text);
    if (!text) return { ok: false, error: "Say something first." };
    log("chat", side, text);
    return done();
  }
  if (game.result !== "*") return { ok: false, error: "The game is over." };

  switch (action.type) {
    case "move": {
      if (action.ply !== game.moves.length) return { ok: false, error: "The board changed; try again." };
      if (sideToMove(game.moves.length) !== side) return { ok: false, error: "It isn't your move." };
      const played = replay([...game.moves, action.uci]);
      if (!played) return { ok: false, error: "That move isn't legal." };
      next.moves.push(action.uci);
      // A move answers the other side's draw offer with a no, and withdraws one's own.
      next.drawOffer = null;
      log("move", side, action.uci);
      finish(boardOutcome(played.chess));
      return done();
    }
    case "resign":
      log("resign", side, null);
      finish(resignation(side));
      return done();
    case "draw-offer":
      if (game.drawOffer === other(side)) return applyAction(game, side, { type: "draw-accept" }, now);
      if (game.drawOffer === side) return { ok: false, error: "You have already offered a draw." };
      next.drawOffer = side;
      log("draw-offer", side, null);
      return done();
    case "draw-accept":
      if (game.drawOffer !== other(side)) return { ok: false, error: "There is no draw offer to accept." };
      finish({ result: "1/2-1/2", reason: "agreement" });
      return done();
    case "draw-decline":
      if (game.drawOffer !== other(side)) return { ok: false, error: "There is no draw offer to decline." };
      next.drawOffer = null;
      log("draw-decline", side, null);
      return done();
    default:
      return { ok: false, error: "Unknown action." };
  }
}

/** True for a well-formed action from the browser. */
export function validAction(x: unknown): x is Action {
  if (!x || typeof x !== "object") return false;
  const a = x as Record<string, unknown>;
  if (a.type === "move") return typeof a.uci === "string" && a.uci.length <= 5 && Number.isInteger(a.ply) && (a.ply as number) >= 0;
  if (a.type === "chat") return typeof a.text === "string" && a.text.length <= MAX_CHAT * 2;
  return a.type === "resign" || a.type === "draw-offer" || a.type === "draw-accept" || a.type === "draw-decline";
}
