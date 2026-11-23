// The rules in src/engine/game.ts, played through act() as the room's Durable Object does.
import assert from "node:assert/strict";
import { test } from "node:test";
import cardsText from "../data/kvardar.txt";
import { parseCards } from "../src/engine/cards";
import { act, addPlayer, newGame, scoreFor, sideIsRight, viewFor, type Action, type Ctx, type Game, type TeamId } from "../src/engine/game";

const CARDS = parseCards(cardsText).cards;

function seeded(seed: number): () => number {
  let s = seed >>> 0;
  return () => {
    s = (s * 1664525 + 1013904223) >>> 0;
    return s / 4294967296;
  };
}

function table(names: string[], teams: TeamId[], seed = 1): { game: Game; ctx: Ctx; ids: string[]; online: Set<string> } {
  const game = newGame("ABDE");
  const online = new Set<string>();
  const ctx: Ctx = { online, rng: seeded(seed), cards: CARDS };
  const ids = names.map((n, i) => {
    const r = addPlayer(game, n, teams[i], ctx);
    assert.ok(r.ok);
    online.add(r.player.id);
    return r.player.id;
  });
  return { game, ctx, ids, online };
}

function ok(game: Game, pid: string, a: Action, ctx: Ctx): void {
  const out = act(game, pid, a, ctx);
  assert.ok(out.ok, out.ok ? "" : out.error);
}

const guessers = (game: Game): string[] => game.players.filter((p) => p.id !== game.round!.giver && (game.round!.team === null || p.team === game.round!.team)).map((p) => p.id);
const others = (game: Game): string[] => game.players.filter((p) => game.round!.team !== null && p.team !== game.round!.team).map((p) => p.id);

test("scoring bands: 4 in the centre, then 3 and 2, else 0", () => {
  assert.equal(scoreFor(50, 50), 4);
  assert.equal(scoreFor(50, 53), 4);
  assert.equal(scoreFor(50, 46.9), 3);
  assert.equal(scoreFor(50, 59), 3);
  assert.equal(scoreFor(50, 35), 2);
  assert.equal(scoreFor(50, 65.1), 0);
  assert.equal(sideIsRight("L", 30, 50), true);
  assert.equal(sideIsRight("R", 30, 50), false);
  assert.equal(sideIsRight("L", 50, 50), false);
  assert.equal(sideIsRight("R", 50, 50), false);
});

test("the first player is the host; names must differ; the room fills up", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni"], [0, 1]);
  assert.equal(game.host, ids[0]);
  const dup = addPlayer(game, "  anna ", 0, ctx);
  assert.equal(dup.ok, false);
  const blank = addPlayer(game, "   ", 0, ctx);
  assert.equal(blank.ok, false);
  for (let i = 0; i < 10; i++) assert.ok(addPlayer(game, `P${i}`, 0, ctx).ok);
  assert.equal(addPlayer(game, "Of margir", 0, ctx).ok, false);
});

test("the target reaches only the clue-giver until the reveal", () => {
  const { game, ctx, ids, online } = table(["Anna", "Bjarni", "Dóra", "Einar"], [0, 0, 1, 1]);
  ok(game, ids[0], { a: "start" }, ctx);
  const r = game.round!;
  for (const id of ids) {
    const v = viewFor(game, id, online);
    if (id === r.giver) assert.equal(v.round!.target, r.target);
    else assert.equal(v.round!.target, null, "a guesser must not see the target");
    assert.ok(!JSON.stringify(v).includes('"token"'), "no seat tokens in a view");
    assert.ok(!JSON.stringify(v).includes('"deck"'), "no deck in a view");
  }
  assert.equal(viewFor(game, null, online).round!.target, null, "the big screen must not see the target");

  ok(game, r.giver, { a: "ready", clue: "Kaffi" }, ctx);
  const g = guessers(game)[0];
  ok(game, g, { a: "move", value: 20 }, ctx);
  for (const id of ids) if (id !== r.giver) assert.equal(viewFor(game, id, online).round!.target, null);
  ok(game, game.round!.locker, { a: "lock" }, ctx);
  assert.equal(game.phase, "bonus");
  assert.equal(viewFor(game, others(game)[0], online).round!.target, null, "not during the left/right guess either");
  ok(game, others(game)[0], { a: "pick", side: "L" }, ctx);
  ok(game, game.round!.bonusLocker!, { a: "bonus-lock" }, ctx);
  assert.equal(game.phase, "reveal");
  for (const id of ids) assert.equal(viewFor(game, id, online).round!.target, r.target);
  assert.equal(viewFor(game, null, online).round!.target, r.target);
});

test("only the guessing team (not the giver) moves the pointer, and only the locker locks", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar", "Fríða"], [0, 0, 1, 1, 0]);
  ok(game, ids[0], { a: "start" }, ctx);
  const r = game.round!;
  assert.equal(act(game, r.giver, { a: "move", value: 10 }, ctx).ok, false, "not before the clue");
  ok(game, r.giver, { a: "ready", clue: "" }, ctx);
  assert.equal(act(game, r.giver, { a: "move", value: 10 }, ctx).ok, false, "the giver can't move it");
  for (const o of others(game)) assert.equal(act(game, o, { a: "move", value: 10 }, ctx).ok, false, "the other team can't");
  const team = guessers(game);
  const first = act(game, team[0], { a: "move", value: 140 }, ctx);
  assert.deepEqual(first, { ok: true, change: "full" });
  assert.equal(game.round!.pointer, 100, "clamped");
  assert.deepEqual(act(game, team[0], { a: "move", value: 33.333 }, ctx), { ok: true, change: "pointer" });
  assert.equal(game.round!.pointer, 33.3);
  const notLocker = team.find((id) => id !== game.round!.locker);
  if (notLocker) assert.equal(act(game, notLocker, { a: "lock" }, ctx).ok, false);
  ok(game, game.round!.locker, { a: "lock" }, ctx);
});

test("if the locker drops out, anyone on the guessing team may lock", () => {
  const { game, ctx, ids, online } = table(["Anna", "Bjarni", "Dóra", "Einar", "Fríða", "Gunni"], [0, 0, 0, 1, 1, 1]);
  ok(game, ids[0], { a: "start" }, ctx);
  ok(game, game.round!.giver, { a: "ready", clue: "x" }, ctx);
  const team = guessers(game);
  const other = team.find((id) => id !== game.round!.locker)!;
  assert.equal(act(game, other, { a: "lock" }, ctx).ok, false);
  online.delete(game.round!.locker);
  ok(game, other, { a: "lock" }, ctx);
});

test("teams alternate, clue-givers rotate within each team, scores add up and the bonus point works", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar", "Fríða", "Gunni"], [0, 0, 0, 1, 1, 1], 7);
  ok(game, ids[0], { a: "settings", settings: { goal: 20 } }, ctx);
  ok(game, ids[0], { a: "start" }, ctx);
  const givers: string[] = [];
  const teams: (TeamId | null)[] = [];
  let expected: [number, number] = [0, 0];
  for (let n = 0; n < 6; n++) {
    const r = game.round!;
    givers.push(r.giver);
    teams.push(r.team);
    ok(game, r.giver, { a: "ready", clue: `v${n}` }, ctx);
    const aim = n % 2 === 0 ? r.target + 1 : r.target + 40 > 100 ? r.target - 40 : r.target + 40;
    ok(game, guessers(game)[0], { a: "move", value: aim }, ctx);
    ok(game, game.round!.locker, { a: "lock" }, ctx);
    const pts = scoreFor(r.target, game.round!.pointer);
    const side = r.target < game.round!.pointer ? "L" : "R";
    ok(game, others(game)[0], { a: "pick", side }, ctx);
    ok(game, game.round!.bonusLocker!, { a: "bonus-lock" }, ctx);
    expected = [...expected] as [number, number];
    expected[r.team!] += pts;
    expected[1 - r.team!] += 1;
    assert.deepEqual(game.scores, expected);
    ok(game, ids[1], { a: "next" }, ctx);
  }
  assert.deepEqual(teams.slice(0, 4), [teams[0], 1 - teams[0]!, teams[0], 1 - teams[0]!]);
  assert.equal(new Set(givers).size, 6, "six rounds, six different clue-givers");
});

test("first team to the goal wins; a tie at the goal plays on", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar"], [0, 0, 1, 1], 3);
  ok(game, ids[0], { a: "settings", settings: { goal: 5, bonus: false } }, ctx);
  ok(game, ids[0], { a: "start" }, ctx);
  let guard = 0;
  while (game.phase !== "over" && guard++ < 20) {
    const r = game.round!;
    ok(game, r.giver, { a: "ready", clue: "" }, ctx);
    ok(game, guessers(game)[0], { a: "move", value: r.target }, ctx);
    ok(game, game.round!.locker, { a: "lock" }, ctx);
    assert.equal(game.phase, "reveal", "no bonus when it is off");
    ok(game, ids[2], { a: "next" }, ctx);
  }
  assert.equal(game.phase, "over");
  // Both teams score 4 a round: 8–4 after three rounds, so the starting team wins.
  assert.equal(game.round!.result!.winner, game.startTeam);
  assert.equal(game.scores[game.startTeam], 8);
});

test("everyone together: ten rounds, a group score and a best that survives a new game", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra"], [0, 0, 0], 11);
  ok(game, ids[0], { a: "settings", settings: { mode: "coop", rounds: 5 } }, ctx);
  ok(game, ids[0], { a: "start" }, ctx);
  let total = 0;
  const givers: string[] = [];
  for (let n = 1; n <= 5; n++) {
    const r = game.round!;
    assert.equal(r.team, null);
    assert.equal(r.n, n);
    givers.push(r.giver);
    ok(game, r.giver, { a: "ready", clue: "" }, ctx);
    const g = guessers(game);
    assert.equal(g.length, 2, "everyone but the giver guesses");
    ok(game, g[0], { a: "move", value: r.target + 8 }, ctx);
    ok(game, game.round!.locker, { a: "lock" }, ctx);
    assert.equal(game.phase, "reveal", "no bonus in co-op");
    total += game.round!.result!.points;
    ok(game, ids[0], { a: "next" }, ctx);
  }
  assert.equal(game.phase, "over");
  assert.equal(game.coopScore, total);
  assert.equal(game.best, total);
  assert.deepEqual(givers.slice(0, 3).sort(), [...ids].sort(), "everyone takes a turn");
  ok(game, ids[0], { a: "again" }, ctx);
  assert.equal(game.phase, "lobby");
  assert.equal(game.best, total);
});

test("host-only settings, custom cards and the custom-only deck", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar"], [0, 0, 1, 1]);
  assert.equal(act(game, ids[1], { a: "settings", settings: { goal: 5 } }, ctx).ok, false);
  assert.equal(act(game, ids[1], { a: "shuffle" }, ctx).ok, false);
  ok(game, ids[0], { a: "settings", settings: { goal: 15, rounds: 99 } }, ctx);
  assert.equal(game.settings.goal, 15);
  assert.equal(game.settings.rounds, 10, "an unknown round count is ignored");
  ok(game, ids[0], { a: "settings", settings: { customOnly: true } }, ctx);
  assert.equal(act(game, ids[0], { a: "start" }, ctx).ok, false, "custom-only with no custom cards");
  assert.equal(act(game, ids[0], { a: "add-card", left: "Frændi", right: "" }, ctx).ok, false);
  ok(game, ids[0], { a: "add-card", left: "Leiðinlegur frændi", right: "Skemmtilegur frændi" }, ctx);
  ok(game, ids[0], { a: "start" }, ctx);
  assert.deepEqual(game.round!.card, ["Leiðinlegur frændi", "Skemmtilegur frændi"]);
  ok(game, game.round!.giver, { a: "redraw" }, ctx);
  assert.deepEqual(game.round!.card, ["Leiðinlegur frændi", "Skemmtilegur frændi"], "the only card comes round again");
});

test("the host lets the earliest online player take over while away", () => {
  const { game, ctx, ids, online } = table(["Anna", "Bjarni", "Dóra", "Einar"], [0, 0, 1, 1]);
  online.delete(ids[0]);
  assert.equal(act(game, ids[2], { a: "shuffle" }, ctx).ok, false);
  ok(game, ids[1], { a: "shuffle" }, ctx);
  assert.equal(viewFor(game, ids[1], online).host, ids[1]);
});

test("starting needs two players a team; a skipped round goes to the same team", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra"], [0, 0, 1]);
  assert.equal(act(game, ids[0], { a: "start" }, ctx).ok, false);
  const more = addPlayer(game, "Einar", 1, ctx);
  assert.ok(more.ok);
  ctx.online instanceof Set && (ctx.online as Set<string>).add(more.player.id);
  ok(game, ids[0], { a: "start" }, ctx);
  const team = game.round!.team;
  const giver = game.round!.giver;
  ok(game, ids[0], { a: "skip" }, ctx);
  assert.equal(game.round!.team, team);
  assert.equal(game.round!.n, 1);
  assert.notEqual(game.round!.giver, giver);
});

test("removing the clue-giver mid-round starts a new round", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar", "Fríða", "Gunni"], [0, 0, 0, 1, 1, 1]);
  ok(game, ids[0], { a: "start" }, ctx);
  let giver = game.round!.giver;
  if (giver === ids[0]) {
    ok(game, ids[0], { a: "skip" }, ctx);
    giver = game.round!.giver;
  }
  ok(game, ids[0], { a: "kick", pid: giver }, ctx);
  assert.equal(game.players.length, 5);
  assert.notEqual(game.round!.giver, giver);
  assert.equal(game.phase, "clue");
});

test("text is cleaned: control characters, long names, long clues", () => {
  const { game, ctx, ids } = table(["Anna", "Bjarni", "Dóra", "Einar"], [0, 0, 1, 1]);
  ok(game, ids[0], { a: "start" }, ctx);
  ok(game, game.round!.giver, { a: "ready", clue: "  Hver\u0000 er\n  þetta?  " + "x".repeat(200) }, ctx);
  assert.ok(game.round!.clue.startsWith("Hver er þetta?"));
  assert.ok(game.round!.clue.length <= 80);
  const long = addPlayer(game, "Þórður Ægir Björnsson Ólafsson", 0, ctx);
  assert.ok(long.ok && long.player.name.length <= 20);
});
