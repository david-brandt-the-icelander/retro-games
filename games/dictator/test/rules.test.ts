// One test per rule in docs/RULES.md, with its boundaries.
import assert from "node:assert/strict";
import { test } from "node:test";
import { DECISIONS, GROUP_KEYS, HEADLINES, REQUESTS, SECTIONS } from "../src/engine/data";
import * as rules from "../src/engine/rules";
import { ARMY, draw, EAST, GameState, GUERRILLAS, LANDOWNERS, NEIGHBOUR, newGame, PEASANTS, pick, POLICE, WEST } from "../src/engine/state";
import { drawsBetween } from "./helpers";

/** A state for testing: month 5, threshold 3, revolution strength 11, nobody plotting. */
function state(over: Partial<GameState> = {}): GameState {
  return { ...newGame(1), month: 5, threshold: 3, revolutionStrength: 11, ...over };
}

// ── §1, §2 ────────────────────────────────────────────────────────────────

test("a reign starts with RULES §1 and §2's values", () => {
  const s = newGame(99);
  assert.deepEqual(s.popularity, [7, 7, 7, 0, 7, 7, 7, 7]);
  assert.deepEqual(s.strength, [6, 6, 6, 6, 6, 6]);
  assert.deepEqual([s.treasury, s.costs, s.swiss, s.bodyguard, s.month], [1000, 60, 0, 4, 0]);
  assert.deepEqual([s.helicopter, s.loanEast, s.loanWest, s.plotPause, s.revolutionStrength], [false, false, false, 0, 10]);
  assert.deepEqual(s.plots, ["none", "none", "none"]);
  assert.deepEqual(s.allies, [-1, -1, -1]);
  assert.equal(s.requestUsed.length, 24);
  assert.equal(s.decisionUsed.length, 19);
  assert.equal(s.newsUsed.length, 6);
  assert.ok(s.alive && !s.escaped);
  assert.equal(s.rng, 99);
});

test("changes clamp each group to 0-9", () => {
  const s = state({ popularity: [8, 1, 5, 0, 5, 5, 9, 0], strength: [9, 0, 5, 5, 5, 5] });
  rules.applyChanges(s, { army: 4, peasants: -3, east: 2, west: -1 }, { army: 3, peasants: -2 });
  assert.deepEqual(s.popularity, [9, 0, 5, 0, 5, 5, 9, 0]);
  assert.deepEqual(s.strength.slice(0, 2), [9, 0]);
});

test("monthly costs never fall below 0", () => {
  const s = state({ costs: 3 });
  rules.changeCosts(s, -10);
  assert.equal(s.costs, 0);
  rules.changeCosts(s, 5);
  assert.equal(s.costs, 5);
});

// ── §3 ────────────────────────────────────────────────────────────────────

test("the mood: threshold 2-4 then revolution strength 10-12, each equally likely", () => {
  const s = newGame(7);
  const t = [0, 0, 0], r = [0, 0, 0];
  for (let i = 0; i < 30000; i++) { rules.rollMood(s); t[s.threshold - 2]++; r[s.revolutionStrength - 10]++; }
  for (const n of [...t, ...r]) assert.ok(Math.abs(n / 30000 - 1 / 3) < 0.015, `${t} ${r}`);
  const a = newGame(5), b = newGame(5);
  rules.rollMood(a);
  assert.equal(a.threshold, pick(b, 3) + 2);
  assert.equal(a.revolutionStrength, pick(b, 3) + 10);
});

test("disaffected means popularity at or below the threshold", () => {
  const s = state({ threshold: 3 });
  s.popularity[ARMY] = 3; assert.ok(rules.isDisaffected(s, ARMY));
  s.popularity[ARMY] = 4; assert.ok(!rules.isDisaffected(s, ARMY));
});

// ── §5 ────────────────────────────────────────────────────────────────────

test("accounts: in debt, nothing is paid and four values drop by 1", () => {
  const s = state({ treasury: -1, costs: 60 });
  assert.equal(rules.settleAccounts(s), "bankrupt");
  assert.equal(s.treasury, -1);
  assert.deepEqual([s.popularity[ARMY], s.popularity[POLICE], s.strength[POLICE], s.bodyguard], [6, 6, 5, 3]);
});

test("accounts: the bankrupt penalties stop at 0", () => {
  const s = state({ treasury: -5, bodyguard: 0 });
  s.popularity[ARMY] = 0; s.popularity[POLICE] = 0; s.strength[POLICE] = 0;
  rules.settleAccounts(s);
  assert.deepEqual([s.popularity[ARMY], s.popularity[POLICE], s.strength[POLICE], s.bodyguard], [0, 0, 0, 0]);
});

test("accounts: in credit the costs are paid, even into debt; exactly 0 does nothing", () => {
  const s = state({ treasury: 10, costs: 60 });
  assert.equal(rules.settleAccounts(s), "paid");
  assert.equal(s.treasury, -50);
  const z = state({ treasury: 0 });
  const before = structuredClone(z);
  assert.equal(rules.settleAccounts(z), "even");
  assert.deepEqual(z, before);
});

// ── §6 ────────────────────────────────────────────────────────────────────

test("plots: nothing happens in months 1 and 2, statuses are kept", () => {
  for (const month of [1, 2]) {
    const s = state({ month, plots: ["assassination", "none", "revolution"], allies: [-1, -1, 3] });
    s.popularity[PEASANTS] = 0;
    rules.checkPlots(s);
    assert.deepEqual(s.plots, ["assassination", "none", "revolution"]);
    assert.deepEqual(s.allies, [-1, -1, 3]);
  }
});

test("plots: cleared and suppressed while the month is below the pause", () => {
  const s = state({ month: 6, plotPause: 7, revolutionStrength: 13, plots: ["assassination", "assassination", "revolution"], allies: [-1, -1, 3] });
  s.popularity[ARMY] = 0;
  rules.checkPlots(s);
  assert.deepEqual(s.plots, ["none", "none", "none"]);
  assert.deepEqual(s.allies, [-1, -1, -1]);
  s.month = 7;
  rules.checkPlots(s);
  assert.equal(s.plots[ARMY], "assassination");
});

test("plots: a disaffected faction rises with the first strong enough disaffected group, else hires an assassin", () => {
  const s = state({ threshold: 3, revolutionStrength: 11 });
  s.popularity = [3, 2, 9, 0, 0, 9, 9, 9];
  s.strength = [5, 6, 9, 6, 9, 9];
  rules.checkPlots(s);
  // Army (5): Peasants 5+6=11 qualifies before the guerrillas.
  assert.equal(s.plots[ARMY], "revolution"); assert.equal(s.allies[ARMY], PEASANTS);
  // Peasants (6): the Army 6+5=11 is first.
  assert.equal(s.plots[PEASANTS], "revolution"); assert.equal(s.allies[PEASANTS], ARMY);
  // Landowners are loyal (9 > 3).
  assert.equal(s.plots[LANDOWNERS], "none");
  s.strength = [1, 1, 1, 9, 1, 1];
  s.revolutionStrength = 11;
  rules.checkPlots(s);
  assert.equal(s.plots[ARMY], "assassination"); assert.equal(s.allies[ARMY], -1);
  s.revolutionStrength = 10;
  rules.checkPlots(s);
  assert.equal(s.plots[ARMY], "revolution"); assert.equal(s.allies[ARMY], GUERRILLAS); // 1 + 9 ≥ 10
});

test("plots: the faction itself and loyal groups never count as allies", () => {
  const s = state({ threshold: 3, revolutionStrength: 10 });
  s.popularity = [0, 9, 9, 9, 9, 9, 9, 9];
  s.strength = [9, 9, 9, 9, 9, 9];
  rules.checkPlots(s);
  assert.equal(s.plots[ARMY], "assassination");
  s.popularity[POLICE] = 3;
  rules.checkPlots(s);
  assert.equal(s.allies[ARMY], POLICE);
});

// ── §7 ────────────────────────────────────────────────────────────────────

test("reports: available only with money, loyal police and strong police (strictly above)", () => {
  const s = state({ threshold: 3, treasury: 1 });
  s.popularity[POLICE] = 4; s.strength[POLICE] = 4;
  assert.deepEqual(rules.reportAvailability(s), { available: true, policeDisloyal: false, policeWeak: false, cannotPay: false });
  s.popularity[POLICE] = 3; s.strength[POLICE] = 3; s.treasury = 0;
  assert.deepEqual(rules.reportAvailability(s), { available: false, policeDisloyal: true, policeWeak: true, cannotPay: true });
  rules.buyReport(state({ treasury: 5 }));
  const t = state({ treasury: 5 }); rules.buyReport(t); assert.equal(t.treasury, 4);
});

// ── §8 ────────────────────────────────────────────────────────────────────

test("requests: the first unused from a random start, wrapping, and marked used at once", () => {
  const s = state();
  const copy = structuredClone(s);
  const start = pick(copy, 24);
  s.requestUsed[start] = true;
  const r = rules.chooseRequest(s);
  assert.equal(r, (start + 1) % 24);
  assert.ok(s.requestUsed[r]);
  assert.equal(drawsBetween(1, s.rng), 1);
});

test("requests: only 22 places are looked at; if none is unused, all marks reset and it draws again", () => {
  const s = state();
  const copy = structuredClone(s);
  const start = pick(copy, 24);
  const second = pick(copy, 24);
  s.requestUsed.fill(true);
  // leave free only the two places the first look cannot reach
  s.requestUsed[(start + 22) % 24] = false;
  s.requestUsed[(start + 23) % 24] = false;
  const r = rules.chooseRequest(s);
  assert.equal(r, second);
  assert.equal(drawsBetween(1, s.rng), 2);
  assert.equal(s.requestUsed.filter(Boolean).length, 1);
});

test("affordability follows RULES §8.3 exactly", () => {
  const item = (once: number, monthly: number) => ({ popularity: {}, strength: {}, once, monthly });
  const at = (treasury: number) => state({ treasury });
  assert.ok(rules.isAffordable(at(101), item(-100, 0))); // 1 > 0
  assert.ok(rules.isAffordable(at(100), item(-100, 0))); // exactly 0: not short, no rise
  assert.ok(!rules.isAffordable(at(99), item(-100, 0))); // −1 < 0
  assert.ok(!rules.isAffordable(at(0), item(0, 5))); // 0 − 5 < 0
  assert.ok(rules.isAffordable(at(5), item(0, 5))); // 5 > 0
  assert.ok(rules.isAffordable(at(0), item(0, -6))); // lowers costs: never fails the rise test
  assert.ok(rules.isAffordable(at(-50), item(0, -6)));
  assert.ok(rules.isAffordable(at(-50), item(0, 0))); // free items are always affordable
  assert.ok(!rules.isAffordable(at(-200), item(100, 5))); // −100 < 0 and costs rise
  assert.ok(rules.isAffordable(at(-50), item(100, 5))); // 50 > 0
  assert.ok(rules.isAffordable(at(-100), item(100, 0))); // 0, costs no money
});

test("granting applies the changes, then the money; costs never below 0", () => {
  const s = state({ treasury: 500, costs: 2 });
  rules.grantRequest(s, 12); // R13: −100 once, +8 monthly
  assert.equal(s.treasury, 400);
  assert.equal(s.costs, 10);
  assert.equal(s.popularity[PEASANTS], 9); // 7 + 4 clamped
  assert.equal(s.popularity[EAST], 8);
  const t = state({ costs: 2 });
  rules.grantRequest(t, 15); // R16: −6 monthly
  assert.equal(t.costs, 0);
});

test("refusing costs the requester exactly what it would have gained, and nothing else", () => {
  for (let r = 0; r < 24; r++) {
    const s = state();
    const before = structuredClone(s);
    rules.refuseRequest(s, r);
    const from = REQUESTS[r].from;
    const gain = REQUESTS[r].popularity[GROUP_KEYS[from]]!;
    assert.ok(gain > 0);
    assert.equal(s.popularity[from], Math.max(0, 7 - gain));
    s.popularity[from] = before.popularity[from];
    assert.deepEqual(s, before);
  }
});

// ── §9 ────────────────────────────────────────────────────────────────────

test("the five sections hold D1-D6, D7-D9, D10-D13, D14-D16 and D17-D19 in order", () => {
  assert.deepEqual(SECTIONS, [[0, 1, 2, 3, 4, 5], [6, 7, 8], [9, 10, 11, 12], [13, 14, 15], [16, 17, 18]]);
});

test("a decision is used once taken, except the bodyguard and the Swiss account", () => {
  for (let d = 0; d < 19; d++) {
    if (DECISIONS[d].special) continue;
    const s = state({ treasury: 9999 });
    rules.takeDecision(s, d);
    assert.equal(s.decisionUsed[d], d !== 10, `D${d + 1}`);
  }
  assert.ok(DECISIONS[12].repeatable && DECISIONS[12].special === "swiss");
});

test("the bodyguard adds 2 to the President's strength with no upper limit", () => {
  const s = state({ treasury: 9999 });
  for (let i = 0; i < 6; i++) rules.takeDecision(s, 10);
  assert.equal(s.bodyguard, 16);
  assert.equal(s.treasury, 9999 - 240);
});

test("the helicopter decision gives the helicopter", () => {
  const s = state();
  rules.takeDecision(s, 11);
  assert.ok(s.helicopter);
  assert.equal(s.treasury, 880);
});

test("the Swiss account takes half the treasury rounded down, if that is at least 1", () => {
  const s = state({ treasury: 7 });
  assert.equal(rules.moveToSwiss(s), 3);
  assert.deepEqual([s.treasury, s.swiss], [4, 3]);
  for (const t of [1, 0, -1, -40]) {
    const u = state({ treasury: t });
    assert.equal(rules.moveToSwiss(u), 0);
    assert.deepEqual([u.treasury, u.swiss], [t, 0]);
  }
});

test("loans: too early below month 3 + pick(5); always drawn first", () => {
  for (let seed = 1; seed < 200; seed++) {
    const s = state({ month: 4, rng: seed });
    const wait = pick(structuredClone(s), 5);
    const r = rules.requestLoan(s, "east");
    if (4 < 3 + wait) { assert.equal(r.outcome, "early"); assert.equal(drawsBetween(seed, s.rng), 1); }
  }
});

test("loans: refused when the power is disaffected; granted is popularity × 30 + pick(200), once", () => {
  const s = state({ month: 99, threshold: 3, treasury: 10 });
  s.popularity[WEST] = 3;
  const before = s.rng;
  assert.equal(rules.requestLoan(s, "west").outcome, "refused");
  assert.equal(drawsBetween(before, s.rng), 1);
  s.popularity[WEST] = 6;
  const copy = structuredClone(s);
  pick(copy, 5);
  const extra = pick(copy, 200);
  const r = rules.requestLoan(s, "west");
  assert.deepEqual(r, { outcome: "granted", amount: 180 + extra });
  assert.equal(s.treasury, 10 + 180 + extra);
  assert.ok(s.loanWest && s.decisionUsed[14] && !s.loanEast && !s.decisionUsed[13]);
  assert.equal(rules.requestLoan(s, "west").outcome, "noMore");
});

test("loans: the checks run too early, no more, refused, granted", () => {
  const s = state({ month: 99, loanEast: true });
  s.popularity[EAST] = 0;
  assert.equal(rules.requestLoan(s, "east").outcome, "noMore"); // no more before refused
});

// ── §10 ───────────────────────────────────────────────────────────────────

test("assassination: one pick(3) for the faction; only a plotting assassin strikes", () => {
  let strikes = 0;
  for (let seed = 1; seed <= 3000; seed++) {
    const s = state({ rng: seed, plots: ["none", "assassination", "revolution"] });
    const f = rules.assassinStrikes(s);
    assert.equal(drawsBetween(seed, s.rng), 1);
    if (f >= 0) { assert.equal(f, PEASANTS); strikes++; }
  }
  assert.ok(Math.abs(strikes / 3000 - 1 / 3) < 0.03);
});

test("assassination: all three plotting kills without a draw; strong or loyal police foil it", () => {
  const all = state({ plots: ["assassination", "assassination", "assassination"] });
  assert.ok(rules.attemptKills(all));
  assert.equal(all.rng, 1);
  const loyal = state({ plots: ["assassination", "none", "none"], threshold: 3 });
  loyal.popularity[POLICE] = 4; loyal.strength[POLICE] = 0;
  assert.ok(!rules.attemptKills(loyal));
  const strong = state({ plots: ["assassination", "none", "none"], threshold: 3 });
  strong.popularity[POLICE] = 0; strong.strength[POLICE] = 4;
  assert.ok(!rules.attemptKills(strong));
  assert.equal(loyal.rng + strong.rng, 2);
});

test("assassination: unloved and weak police leave it to a coin flip (0 kills)", () => {
  let kills = 0;
  for (let seed = 1; seed <= 4000; seed++) {
    const s = state({ rng: seed, plots: ["assassination", "none", "none"], threshold: 3 });
    s.popularity[POLICE] = 3; s.strength[POLICE] = 3;
    const expect = pick(structuredClone(s), 2) === 0;
    assert.equal(rules.attemptKills(s), expect);
    if (expect) kills++;
  }
  assert.ok(Math.abs(kills / 4000 - 0.5) < 0.03);
});

// ── §11 ───────────────────────────────────────────────────────────────────

test("war: the Neighbour is hostile when unloved (≤) and strong (≥ the threshold)", () => {
  const s = state({ threshold: 3 });
  s.popularity[NEIGHBOUR] = 3; s.strength[NEIGHBOUR] = 3;
  assert.ok(rules.isNeighbourHostile(s));
  s.strength[NEIGHBOUR] = 2;
  assert.ok(!rules.isNeighbourHostile(s));
  s.strength[NEIGHBOUR] = 9; s.popularity[NEIGHBOUR] = 4;
  assert.ok(!rules.isNeighbourHostile(s));
});

test("war: one chance in three of invasion", () => {
  const s = newGame(3);
  let n = 0;
  for (let i = 0; i < 30000; i++) if (rules.neighbourInvades(s)) n++;
  assert.ok(Math.abs(n / 30000 - 1 / 3) < 0.015);
});

test("war: a threat rallies the Army, Peasants, Landowners and police", () => {
  const s = state();
  s.popularity = [9, 0, 5, 0, 1, 2, 3, 3];
  rules.rallyToTheFlag(s);
  assert.deepEqual(s.popularity, [9, 1, 6, 0, 1, 3, 3, 3]);
});

test("war: the forces count loyal home groups plus the President, against every disaffected group", () => {
  const s = state({ threshold: 3, bodyguard: 12 });
  s.popularity = [4, 3, 9, 0, 0, 4, 0, 0];
  s.strength = [1, 2, 3, 4, 5, 6];
  assert.equal(rules.homeForce(s), 12 + 1 + 3 + 6);
  assert.equal(rules.invaderForce(s), 2 + 4 + 5);
});

test("war: the Neighbour wins if its force plus the swing reaches ours", () => {
  assert.ok(rules.neighbourWins(10, 9, 1));
  assert.ok(!rules.neighbourWins(10, 9, 0));
  assert.ok(rules.neighbourWins(10, 11, -1));
  const s = state(); rules.winWar(s); assert.equal(s.strength[NEIGHBOUR], 0);
});

test("the swing is -1, 0 or +1 and the helicopter starts two times in three", () => {
  const s = newGame(11);
  const sw = new Map<number, number>();
  let starts = 0;
  for (let i = 0; i < 30000; i++) { const v = rules.swing(s); sw.set(v, (sw.get(v) ?? 0) + 1); if (rules.helicopterStarts(s)) starts++; }
  assert.deepEqual([...sw.keys()].sort(), [-1, 0, 1]);
  assert.ok(Math.abs(starts / 30000 - 2 / 3) < 0.015);
});

// ── §12 ───────────────────────────────────────────────────────────────────

test("news: one chance in three, then the first unused headline from pick(6)", () => {
  let news = 0;
  for (let seed = 1; seed <= 3000; seed++) {
    const s = state({ rng: seed });
    s.newsUsed[2] = true;
    const c = structuredClone(s);
    const happens = pick(c, 3) === 0;
    const n = rules.newsToday(s);
    if (!happens) { assert.equal(n, -1); assert.equal(drawsBetween(seed, s.rng), 1); continue; }
    news++;
    const start = pick(c, 6);
    assert.equal(n, start === 2 ? 3 : start);
    assert.equal(drawsBetween(seed, s.rng), 2);
  }
  assert.ok(Math.abs(news / 3000 - 1 / 3) < 0.03);
});

test("news: with all six used there is no news, but pick(6) is still drawn", () => {
  for (let seed = 1; seed < 100; seed++) {
    const s = state({ rng: seed });
    s.newsUsed.fill(true);
    const happens = pick(structuredClone(s), 3) === 0;
    assert.equal(rules.newsToday(s), -1);
    assert.equal(drawsBetween(seed, s.rng), happens ? 2 : 1);
  }
});

test("news: a headline is marked used and moves no money", () => {
  for (let n = 0; n < 6; n++) {
    const s = state();
    rules.printHeadline(s, n);
    assert.ok(s.newsUsed[n]);
    assert.deepEqual([s.treasury, s.costs], [1000, 60]);
  }
  const s = state();
  rules.printHeadline(s, 1);
  assert.deepEqual(s.strength, [5, 6, 6, 9, 6, 6]);
  assert.equal(HEADLINES.length, 6);
});

// ── §13 ───────────────────────────────────────────────────────────────────

test("revolution: up to three picks, stopping at the first faction that plans one", () => {
  for (let seed = 1; seed <= 500; seed++) {
    const s = state({ rng: seed, plots: ["assassination", "none", "revolution"], allies: [-1, -1, 3] });
    const c = structuredClone(s);
    let expect = -1, draws = 0;
    for (let i = 0; i < 3; i++) { draws++; if (pick(c, 3) === 2) { expect = 2; break; } }
    assert.equal(rules.whoRises(s), expect);
    assert.equal(drawsBetween(seed, s.rng), draws);
  }
});

test("revolution: helpers are groups 1-6 above the threshold; rebels add the ally's strength", () => {
  const s = state({ threshold: 3, plots: ["revolution", "none", "none"], allies: [3, -1, -1] });
  s.popularity = [0, 4, 3, 0, 9, 9, 9, 9];
  s.strength = [7, 1, 1, 8, 1, 1];
  assert.deepEqual(rules.helpers(s), [false, true, false, false, true, true]);
  assert.equal(rules.rebelForce(s, ARMY), 15);
});

test("on foot: caught when floor(u × (guerrillas ÷ 3 + 0.4)) is not 0", () => {
  const rate = (g: number) => {
    let caught = 0;
    for (let seed = 1; seed <= 20000; seed++) {
      const s = state({ rng: seed });
      s.strength[GUERRILLAS] = g;
      const u = draw(structuredClone(s));
      const c = rules.caughtOnFoot(s);
      assert.equal(c, Math.floor(u * (g / 3 + 0.4)) !== 0);
      if (c) caught++;
    }
    return caught / 20000;
  };
  assert.equal(rate(0), 0);
  assert.ok(Math.abs(rate(3) - (1 - 1 / 1.4)) < 0.015);
  assert.ok(Math.abs(rate(6) - (1 - 1 / 2.4)) < 0.015);
  assert.ok(Math.abs(rate(9) - (1 - 1 / 3.4)) < 0.015);
});

test("the revolt is crushed when the rebels are at most the President, the helper and the swing", () => {
  assert.ok(rules.revoltCrushed(10, 6, 4, 0));
  assert.ok(!rules.revoltCrushed(10, 6, 4, -1));
  assert.ok(rules.revoltCrushed(11, 6, 4, 1));
  assert.ok(!rules.revoltCrushed(12, 6, 4, 1));
});

test("punishment zeroes the rebel faction and its ally; victory sets the helper to 9 and pauses plots", () => {
  const s = state({ month: 8, plots: ["none", "revolution", "none"], allies: [-1, 4, -1] });
  rules.punishRebels(s, PEASANTS);
  assert.deepEqual([s.popularity[PEASANTS], s.strength[PEASANTS], s.popularity[NEIGHBOUR], s.strength[NEIGHBOUR]], [0, 0, 0, 0]);
  rules.afterVictory(s, POLICE);
  assert.equal(s.strength[POLICE], 9);
  assert.equal(s.plotPause, 10);
  const alone = state({ month: 3 });
  const before = [...alone.strength];
  rules.afterVictory(alone, -1);
  assert.deepEqual(alone.strength, before);
  assert.equal(alone.plotPause, 5);
});

// ── §14 ───────────────────────────────────────────────────────────────────

test("the rating: popularity + 3 a month, and if alive 10 + floor(Swiss ÷ 10)", () => {
  const alive = state({ month: 12, swiss: 129 });
  alive.popularity = [1, 2, 3, 4, 5, 6, 7, 8];
  assert.deepEqual(rules.rate(alive), { popularity: 36, months: 12, monthsPoints: 36, alive: true, survivalBonus: 10, swiss: 129, swissPoints: 12, total: 94 });
  const dead = { ...alive, alive: false };
  assert.equal(rules.rate(dead).total, 72);
  assert.equal(rules.rate(dead).swissPoints, 0);
});

// ── §17 ───────────────────────────────────────────────────────────────────

test("the data tables have RULES §17's sizes and order", () => {
  assert.equal(REQUESTS.length, 24);
  REQUESTS.forEach((r, i) => assert.equal(r.from, Math.floor(i / 8)));
  assert.equal(DECISIONS.length, 19);
  assert.deepEqual(DECISIONS.map((d) => d.section), [1, 1, 1, 1, 1, 1, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 5, 5, 5]);
  assert.deepEqual(DECISIONS.map((d) => d.special), [null, null, null, null, null, null, null, null, null, null, null, null, "swiss", "loanEast", "loanWest", null, null, null, null]);
  // a few spot checks against the table
  assert.deepEqual(REQUESTS[23], { from: 2, popularity: { army: 1, peasants: 1, landowners: 3, neighbour: -3, east: 2, west: 1 }, strength: { landowners: 3, neighbour: -2 }, once: -120, monthly: 10 });
  assert.equal(DECISIONS[15].once, 130);
  assert.deepEqual(HEADLINES[0], { popularity: { police: -4 }, strength: { guerrillas: 4, police: -4 } });
});
