import assert from "node:assert/strict";
import test from "node:test";
import { applyAction, validAction } from "../worker/actions";
import type { GameView } from "../shared/protocol";
import { boardOutcome, describe, replay, scoreFor, validMoveList } from "../shared/rules";
import { commandsFor } from "../bridge/engine";

const game = (moves: string[] = []): GameView => ({
  id: "g1", kind: "online", level: null,
  white: { id: "w", email: "w@x.io", name: "W", avatar: null }, black: { id: "b", email: "b@x.io", name: "B", avatar: null },
  moves, result: "*", reason: null, drawOffer: null, created: 1, updated: 1,
  events: [{ seq: 1, at: 1, kind: "start", side: null, text: null }],
});

test("replay: legal moves give SAN, an illegal one gives null", () => {
  assert.deepEqual(replay(["e2e4", "e7e5", "g1f3"])!.san, ["e4", "e5", "Nf3"]);
  assert.equal(replay(["e2e5"]), null);
  assert.equal(replay(["e2e4", "e2e4"]), null);
});

test("outcomes: mate, stalemate, material, repetition", () => {
  assert.deepEqual(boardOutcome(replay(["f2f3", "e7e5", "g2g4", "d8h4"])!.chess), { result: "0-1", reason: "checkmate" });
  const rep = replay(["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"])!;
  assert.equal(boardOutcome(rep.chess).reason, "repetition");
  assert.equal(boardOutcome(replay([])!.chess).result, "*");
  assert.equal(scoreFor("1-0", "white"), "win");
  assert.equal(scoreFor("1-0", "black"), "loss");
  assert.equal(scoreFor("1/2-1/2", "black"), "draw");
  assert.equal(describe({ result: "0-1", reason: "resign" }, "Ann", "Bo"), "Ann resigned. Bo wins");
});

test("promotion moves are UCI with the piece", () => {
  const moves = ["a2a4", "b7b5", "a4b5", "a7a6", "b5a6", "c8b7", "a6b7", "h7h6", "b7a8q"];
  const r = replay(moves)!;
  assert.equal(r.san.at(-1), "bxa8=Q");
  assert.ok(validMoveList(moves));
  assert.ok(!validMoveList(["e2e4", "nonsense"]));
});

test("actions: turn order, stale moves, mate ends the game", () => {
  assert.equal((applyAction(game(), "black", { type: "move", uci: "e7e5", ply: 0 }, 5) as { error: string }).error, "It isn't your move.");
  assert.equal((applyAction(game(), "white", { type: "move", uci: "e2e4", ply: 1 }, 5) as { error: string }).error, "The board changed; try again.");
  assert.equal(applyAction(game(), "white", { type: "move", uci: "e2e5", ply: 0 }, 5).ok, false);
  const r = applyAction(game(["f2f3", "e7e5", "g2g4"]), "black", { type: "move", uci: "d8h4", ply: 3 }, 5);
  assert.ok(r.ok && r.game.result === "0-1" && r.game.reason === "checkmate");
  assert.ok(r.ok && r.game.updated > 1);
  assert.deepEqual(r.ok && r.added.map((e) => [e.seq, e.kind, e.side, e.text]), [[2, "move", "black", "d8h4"], [3, "end", null, "0-1 checkmate"]]);
  assert.equal(applyAction(r.ok ? r.game : game(), "white", { type: "resign" }, 6).ok, false);
});

test("actions: draw offers, accepting, declining, and a move answering one", () => {
  const offered = applyAction(game(), "white", { type: "draw-offer" }, 5);
  assert.ok(offered.ok && offered.game.drawOffer === "white");
  const g = offered.ok ? offered.game : game();
  assert.equal(applyAction(g, "white", { type: "draw-accept" }, 6).ok, false);
  const acc = applyAction(g, "black", { type: "draw-accept" }, 6);
  assert.ok(acc.ok && acc.game.result === "1/2-1/2" && acc.game.reason === "agreement");
  const dec = applyAction(g, "black", { type: "draw-decline" }, 6);
  assert.ok(dec.ok && dec.game.drawOffer === null);
  const both = applyAction(g, "black", { type: "draw-offer" }, 6);
  assert.ok(both.ok && both.game.result === "1/2-1/2", "offering back accepts");
  const mv = applyAction(g, "white", { type: "move", uci: "e2e4", ply: 0 }, 6);
  assert.ok(mv.ok && mv.game.drawOffer === null);
  const res = applyAction(game(), "black", { type: "resign" }, 5);
  assert.ok(res.ok && res.game.result === "1-0" && res.game.reason === "resign");
});

test("chat: cleaned, logged with its side, allowed after the game too, never empty", () => {
  const r = applyAction(game(), "black", { type: "chat", text: "  good luck\u0007!  " }, 50);
  assert.ok(r.ok);
  assert.deepEqual(r.ok && r.added, [{ seq: 2, at: 50, kind: "chat", side: "black", text: "good luck!" }]);
  assert.equal(applyAction(game(), "white", { type: "chat", text: "   " }, 5).ok, false);
  const over = applyAction(game(), "white", { type: "resign" }, 5);
  assert.ok(over.ok && over.added.map((e) => e.kind).join() === "resign,end");
  const gg = applyAction(over.ok ? over.game : game(), "black", { type: "chat", text: "gg" }, 6);
  assert.ok(gg.ok && gg.game.events.at(-1)!.text === "gg");
  assert.equal(applyAction(game(), "white", { type: "chat", text: "x".repeat(900) }, 5).ok && "trimmed", "trimmed");
});

test("validAction rejects malformed input", () => {
  assert.ok(validAction({ type: "move", uci: "e2e4", ply: 0 }));
  assert.ok(!validAction({ type: "move", uci: "e2e4", ply: -1 }));
  assert.ok(!validAction({ type: "move", uci: "e2e4e2e4", ply: 0 }));
  assert.ok(!validAction({ type: "nuke" }));
  assert.ok(!validAction(null));
});

test("engine strengths: eight levels, from skill 0 to full strength", () => {
  assert.deepEqual(commandsFor(1, []), ["setoption name Skill Level value 0", "position startpos", "go depth 1"]);
  assert.deepEqual(commandsFor(8, ["e2e4"]).slice(1), ["position startpos moves e2e4", "go movetime 2000"]);
  assert.equal(commandsFor(99, [])[0], "setoption name Skill Level value 20");
});
