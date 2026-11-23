import assert from "node:assert/strict";
import { test } from "node:test";
import WORDS_TEXT from "../data/ord.txt";
import * as G from "../src/shared/game";
import { other, type Team } from "../src/shared/protocol";
import { parseWords } from "../src/shared/words";
import { seeded } from "./helpers";

const builtin = parseWords(WORDS_TEXT);

function setup(n = 4, seed = 7) {
  const room = G.newRoom("ABCD", 1000);
  const online = new Set<string>();
  const ctx: G.Ctx = { now: 1000, random: seeded(seed), builtin, online };
  for (let i = 0; i < n; i++) {
    const id = `p${i}`;
    assert.deepEqual(G.join(room, `Leikmaður ${i}`, id, `t${i}`, ctx), { ok: true });
    online.add(id);
  }
  return { room, ctx, online };
}

const giver = (room: G.Room, t: Team) => room.players.find((p) => p.team === t && p.role === "clue")!;
const guesser = (room: G.Room, t: Team) => room.players.find((p) => p.team === t && p.role === "guess")!;
const indexOf = (g: G.Game, kind: string) => g.cards.findIndex((c) => !c.revealed && c.kind === kind);

test("newcomers are dealt into even teams, the first in each giving clues", () => {
  const { room } = setup(5);
  const h = room.players.filter((p) => p.team === "hraun"), j = room.players.filter((p) => p.team === "jokull");
  assert.ok(Math.abs(h.length - j.length) <= 1);
  for (const team of [h, j]) assert.equal(team.filter((p) => p.role === "clue").length, 1);
  assert.equal(G.hostId(room, new Set(room.players.map((p) => p.id))), "p0");
  assert.ok(G.ready(room));
});

test("names are tidied and made unique", () => {
  const { room, ctx } = setup(1);
  G.join(room, "  Leikmaður   0 ", "x", "tx", ctx);
  assert.equal(room.players[1]!.name, "Leikmaður 0 2");
  assert.deepEqual(G.join(room, "   ", "y", "ty", ctx), { ok: false, error: "name" });
});

test("players can trade teams before the game, and the clue-giver follows", () => {
  const { room, ctx } = setup(4);
  const g = giver(room, "hraun");
  assert.deepEqual(G.setTeam(room, g.id, g.id, "jokull", ctx), { ok: true });
  assert.equal(g.team, "jokull");
  assert.equal(g.role, "guess", "the other team already had a clue-giver");
  assert.equal(room.players.filter((p) => p.team === "hraun" && p.role === "clue").length, 1, "Hraun got a new clue-giver");
  const someone = guesser(room, "jokull");
  const notHost = room.players.find((p) => p.id !== "p0" && p.id !== someone.id)!;
  assert.deepEqual(G.setTeam(room, notHost.id, someone.id, "hraun", ctx), { ok: false, error: "notHost" });
  assert.deepEqual(G.setTeam(room, "p0", someone.id, "hraun", ctx), { ok: true }, "the host can move anyone");
});

test("a guesser can take over as clue-giver; shuffle keeps one each", () => {
  const { room, ctx } = setup(6);
  const p = guesser(room, "jokull");
  G.setClueGiver(room, p.id, p.id, ctx);
  assert.equal(giver(room, "jokull").id, p.id);
  assert.equal(room.players.filter((x) => x.team === "jokull" && x.role === "clue").length, 1);
  assert.deepEqual(G.shuffleTeams(room, "p1", ctx), { ok: false, error: "notHost" });
  G.shuffleTeams(room, "p0", ctx);
  assert.equal(room.players.filter((x) => x.team === "hraun").length, 3);
  assert.ok(G.ready(room));
});

test("a deal has 9, 8, 7 and 1 words, and the team with 9 starts", () => {
  for (let seed = 1; seed < 40; seed++) {
    const { room, ctx } = setup(4, seed);
    assert.deepEqual(G.deal(room, "p0", ctx), { ok: true });
    const g = room.game!;
    const count = (k: string) => g.cards.filter((c) => c.kind === k).length;
    assert.equal(g.cards.length, 25);
    assert.equal(count(g.first), 9);
    assert.equal(count(other(g.first)), 8);
    assert.equal(count("neutral"), 7);
    assert.equal(count("ghost"), 1);
    assert.equal(g.turn, g.first);
    assert.equal(g.phase, "clue");
  }
});

test("only the host starts, and only with two full teams", () => {
  const { room, ctx } = setup(3);
  assert.deepEqual(G.deal(room, "p0", ctx), { ok: false, error: "needTeams" });
  G.join(room, "Fjórði", "p3", "t3", ctx);
  assert.deepEqual(G.deal(room, "p1", ctx), { ok: false, error: "notHost" });
  assert.deepEqual(G.deal(room, "p0", ctx), { ok: true });
});

test("clues are one word, not on the board, numbered 1 to 9, from the right person", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const cg = giver(room, g.turn);
  const onBoard = g.cards[0]!.word.replace(/\|/g, "");
  assert.deepEqual(G.giveClue(room, guesser(room, g.turn).id, "Sjór", 2, ctx), { ok: false, error: "notYou" });
  assert.deepEqual(G.giveClue(room, giver(room, other(g.turn)).id, "Sjór", 2, ctx), { ok: false, error: "notYou" });
  assert.deepEqual(G.giveClue(room, cg.id, "tvö orð", 2, ctx), { ok: false, error: "clueWord" });
  assert.deepEqual(G.giveClue(room, cg.id, onBoard.toLowerCase(), 2, ctx), { ok: false, error: "clueOnBoard" });
  assert.deepEqual(G.giveClue(room, cg.id, "Sjór", 0, ctx), { ok: false, error: "clueNumber" });
  assert.deepEqual(G.giveClue(room, cg.id, "Sjór", 10, ctx), { ok: false, error: "clueNumber" });
  assert.deepEqual(G.giveClue(room, cg.id, "þjóðsaga", 2, ctx), { ok: true });
  assert.equal(g.clue!.word, "Þjóðsaga");
  assert.equal(g.phase, "guess");
  assert.equal(g.left, 3);
});

test("right guesses go on, up to the number plus one", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const team = g.turn;
  G.giveClue(room, giver(room, team).id, "Orð", 2, ctx);
  const gs = guesser(room, team).id;
  assert.deepEqual(G.guess(room, giver(room, team).id, indexOf(g, team), ctx), { ok: false, error: "notYou" });
  assert.deepEqual(G.stop(room, gs, ctx), { ok: false, error: "guessFirst" });
  for (let i = 0; i < 3; i++) {
    assert.equal(g.turn, team);
    assert.deepEqual(G.guess(room, gs, indexOf(g, team), ctx), { ok: true });
  }
  assert.equal(g.turn, other(team), "three right guesses on a 2 end the turn");
  assert.equal(g.phase, "clue");
});

test("a neutral word or the other team's word ends the turn; guessers may stop", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const team = g.turn;
  G.giveClue(room, giver(room, team).id, "Orð", 3, ctx);
  G.guess(room, guesser(room, team).id, indexOf(g, "neutral"), ctx);
  assert.equal(g.turn, other(team));
  G.giveClue(room, giver(room, other(team)).id, "Annað", 1, ctx);
  G.guess(room, guesser(room, other(team)).id, indexOf(g, team), ctx);
  assert.equal(g.turn, team, "revealing the other team's word hands them the turn");
  G.giveClue(room, giver(room, team).id, "Þriðja", 1, ctx);
  G.guess(room, guesser(room, team).id, indexOf(g, team), ctx);
  assert.deepEqual(G.stop(room, guesser(room, team).id, ctx), { ok: true });
  assert.equal(g.turn, other(team));
  assert.deepEqual(G.guess(room, guesser(room, team).id, 0, ctx), { ok: false, error: "notNow" });
});

test("the game-over word loses the game at once", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const team = g.turn;
  G.giveClue(room, giver(room, team).id, "Orð", 1, ctx);
  G.guess(room, guesser(room, team).id, indexOf(g, "ghost"), ctx);
  assert.equal(g.phase, "over");
  assert.equal(g.winner, other(team));
  assert.equal(g.ghost, true);
});

test("finding all your words wins, even on the other team's turn", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const team = g.turn;
  for (const c of g.cards) if (c.kind === team) c.revealed = true;
  g.cards.find((c) => c.kind === team)!.revealed = false; // one left
  G.giveClue(room, giver(room, team).id, "Orð", 1, ctx);
  G.guess(room, guesser(room, team).id, indexOf(g, team), ctx);
  assert.equal(g.winner, team);
  assert.equal(g.ghost, false);

  const second = setup(4, 99);
  G.deal(second.room, "p0", second.ctx);
  const h = second.room.game!;
  const them = other(h.turn);
  for (const c of h.cards) if (c.kind === them) c.revealed = true;
  h.cards.find((c) => c.kind === them)!.revealed = false;
  G.giveClue(second.room, giver(second.room, h.turn).id, "Orð", 1, second.ctx);
  G.guess(second.room, guesser(second.room, h.turn).id, indexOf(h, them), second.ctx);
  assert.equal(h.winner, them, "revealing the other team's last word makes them win");
});

test("the turn timer ends the turn when it runs out", () => {
  const { room, ctx } = setup();
  G.setTimer(room, "p0", 60, ctx);
  G.deal(room, "p0", ctx);
  const g = room.game!;
  assert.equal(g.deadline, 1000 + 60000);
  const team = g.turn;
  assert.equal(G.expire(room, 1000 + 59999), false);
  assert.equal(G.expire(room, 1000 + 60000), true);
  assert.equal(g.turn, other(team));
  assert.equal(g.deadline, 61000 + 60000);
  assert.deepEqual(G.setTimer(room, "p0", 45, ctx), { ok: false, error: "bad" });
  G.setTimer(room, "p0", 0, ctx);
  assert.equal(g.deadline, null);
});

test("new game keeps the teams and deals a new board", () => {
  const { room, ctx } = setup(6);
  G.deal(room, "p0", ctx);
  const before = room.players.map((p) => `${p.id}:${p.team}:${p.role}`).join();
  const words = room.game!.cards.map((c) => c.word).join();
  G.deal(room, "p0", ctx);
  assert.equal(room.players.map((p) => `${p.id}:${p.team}:${p.role}`).join(), before);
  assert.notEqual(room.game!.cards.map((c) => c.word).join(), words);
  assert.equal(room.game!.number, 2);
});

test("guessers never see the key; clue-givers do; everyone does at the end", () => {
  const { room, ctx } = setup();
  G.deal(room, "p0", ctx);
  const g = room.game!;
  const known = (v: ReturnType<typeof G.view>) => v.game!.cards.filter((c) => c.kind !== null).length;
  assert.equal(known(G.view(room, { id: guesser(room, "hraun").id, screen: false }, ctx)), 0);
  assert.equal(known(G.view(room, { id: null, screen: true }, ctx)), 0);
  assert.equal(known(G.view(room, { id: null, screen: false }, ctx)), 0);
  assert.equal(known(G.view(room, { id: giver(room, "jokull").id, screen: false }, ctx)), 25);
  const guesserJson = JSON.stringify(G.view(room, { id: guesser(room, "jokull").id, screen: false }, ctx));
  assert.ok(!/"kind":"(hraun|jokull|neutral|ghost)"/.test(guesserJson), "no kind in a guesser's view");
  assert.ok(!guesserJson.includes("token"), "no seat tokens in a view");
  G.giveClue(room, giver(room, g.turn).id, "Orð", 1, ctx);
  G.guess(room, guesser(room, g.turn).id, indexOf(g, "neutral"), ctx);
  assert.equal(known(G.view(room, { id: guesser(room, "hraun").id, screen: false }, ctx)), 1, "a revealed word shows its colour");
  g.phase = "over";
  assert.equal(known(G.view(room, { id: guesser(room, "hraun").id, screen: false }, ctx)), 25);
});

test("the host role passes on while the creator is away, and comes back", () => {
  const { room, online } = setup(4);
  online.delete("p0");
  assert.equal(G.hostId(room, online), "p1");
  online.add("p0");
  assert.equal(G.hostId(room, online), "p0");
});

test("a clue-giver who leaves mid-game is replaced from their team", () => {
  const { room, ctx } = setup(6);
  G.deal(room, "p0", ctx);
  const cg = giver(room, "jokull");
  G.remove(room, "p0", cg.id, ctx);
  assert.equal(room.players.filter((p) => p.team === "jokull" && p.role === "clue").length, 1);
});

test("a host's custom list is used for the next deal", () => {
  const { room, ctx } = setup();
  assert.deepEqual(G.setWords(room, "p0", "of fá, orð", ctx), { ok: false, error: "fewWords" });
  const mine = ["Fjallganga", "Hestur", "Kría", "Lundi", "Selur", "Bátur", "Sól", "Tungl", "Vindur", "Snjór", "Kaffi", "Skyr", "Brauð", "Ostur", "Epli", "Bók", "Penni", "Stóll", "Borð", "Lampi", "Spegill", "Klukka", "Sími", "Tölva", "Húfa", "Trefill", "Gítar", "Píanó"];
  assert.deepEqual(G.setWords(room, "p0", mine.join(", "), ctx), { ok: true });
  assert.equal(room.words!.length, 28);
  G.deal(room, "p0", ctx);
  for (const c of room.game!.cards) assert.ok(mine.includes(c.word), c.word);
  G.setWords(room, "p0", null, ctx);
  assert.equal(room.words, null);
});
