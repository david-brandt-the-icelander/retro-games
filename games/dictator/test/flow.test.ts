// Flow: the order of screens in a month (RULES §4), every ending, the draw order across screens,
// and the rating and best score.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame } from "../src/engine";
import type { GameState, Screen } from "../src/engine";
import { ARMY, GUERRILLAS, NEIGHBOUR, pick, POLICE } from "../src/engine/state";
import { drawsBetween, kinds, patient, recorder, rotating, Step } from "./helpers";

type Answer = (screen: Screen, n: number) => string;
/** Always the same key, except a digit at the help list (which waits for 1-6). */
const always = (k: string): Answer => (sc) => (sc.kind === "helpList" && !/^[1-6]$/.test(k) ? "2" : k);

async function run(s: GameState, answer: Answer, best: number | null = null) {
  const { io, log } = recorder(s, patient(answer));
  const outcome = await playGame(io, s, best);
  return { log, outcome, s };
}

/** Find a seed whose game satisfies a predicate. */
async function find(make: (seed: number) => GameState, answer: () => Answer, ok: (log: Step[], s: GameState) => boolean, tries = 3000) {
  for (let seed = 1; seed <= tries; seed++) {
    const r = await run(make(seed), answer());
    if (ok(r.log, r.s)) return { ...r, seed };
  }
  throw new Error("no seed found");
}

const after = (log: Step[], kind: string, i = 0) => log.findIndex((x, j) => j >= i && x.screen.kind === kind);
/** The screens from log[i] to the end of its month, leaving out any news (which may or may not come). */
const restOfMonth = (log: Step[], i: number) => {
  const end = after(log, "month", i + 1);
  return kinds(log).slice(i, end < 0 ? undefined : end).filter((k) => k !== "newsAlert" && k !== "newsHeadline");
};
/** The last screen of a kind before log[before] (-1 if none). */
const lastBefore = (log: Step[], kind: string, before = log.length) => {
  for (let j = before - 1; j >= 0; j--) if (log[j].screen.kind === kind) return j;
  return -1;
};
const followedBy = (log: Step[], seq: string[]) => {
  const ks = kinds(log);
  for (let i = 0; i + seq.length <= ks.length; i++) if (seq.every((k, j) => ks[i + j] === k)) return i;
  return -1;
};

/** A reign where nobody plots and the Neighbour is friendly. */
function calm(seed: number, over: Partial<GameState> = {}): GameState {
  const s = newGame(seed);
  s.popularity = [9, 9, 9, 0, 9, 9, 9, 9];
  return Object.assign(s, over);
}

// ── The opening and a month ──────────────────────────────────────────────

test("the reign opens with welcome, the treasury and a free first report, then month 1", async () => {
  const { log } = await run(newGame(5), rotating(["n"]), 42);
  assert.deepEqual(kinds(log).slice(0, 8), ["welcome", "treasury", "report", "month", "audience", "adviceOffer", "dialog", "treasury"]);
  assert.deepEqual(log[0].screen, { kind: "welcome", best: 42 });
  const first = log[2];
  assert.equal(first.screen.kind === "report" && first.screen.variant, "first");
  assert.equal(first.snap.revolutionStrength, 10);
  assert.equal(first.snap.treasury, 1000);
  assert.equal(first.snap.month, 0);
  assert.deepEqual(first.snap.status, ["none", "none", "none"]);
  assert.equal(log[3].snap.month, 1);
});

test("a calm month follows RULES §4: audience, decision, news, then the month's only report offer", async () => {
  let withNews = 0, without = 0;
  for (let seed = 1; seed <= 20; seed++) {
    const { log } = await run(calm(seed), always("n"));
    const i = after(log, "month");
    const end = after(log, "month", i + 1);
    const seq = kinds(log).slice(i, end + 1);
    const news = seq.includes("newsAlert") ? ["newsAlert", "newsHeadline"] : [];
    if (news.length) withNews++; else without++;
    assert.deepEqual(seq, ["month", "audience", "adviceOffer", "dialog", "treasury", "menu", ...news, "reportOffer", "month"], `seed ${seed}`);
  }
  assert.ok(withNews > 0 && without > 0);
});

test("a quiet month draws exactly in RULES §15.4 order", async () => {
  for (let seed = 1; seed <= 60; seed++) {
    const s = calm(seed);
    const { log } = await run(s, always("n"));
    const ref = newGame(seed);
    const at = (kind: string, from = 0) => log[after(log, kind, from)].snap;
    // month 1
    const threshold = pick(ref, 3) + 2, rev = pick(ref, 3) + 10;
    const m1 = at("month");
    assert.deepEqual([m1.threshold, m1.revolutionStrength, m1.rng], [threshold, rev, ref.rng]);
    const request = pick(ref, 24);
    const aud = log[after(log, "audience")];
    assert.equal(aud.screen.kind === "audience" && aud.screen.request, request);
    assert.equal(aud.snap.rng, ref.rng);
    pick(ref, 3); // assassin's faction (nobody plots)
    const news = pick(ref, 3) === 0;
    let headline = -1;
    if (news) headline = pick(ref, 6);
    if (news) {
      const n = log[after(log, "newsHeadline")];
      assert.equal(n.screen.kind === "newsHeadline" && n.screen.headline, headline);
    }
    for (let k = 0; k < 3; k++) pick(ref, 3); // revolution: nobody plots, three picks
    assert.equal(log[after(log, "reportOffer")].snap.rng, ref.rng); // the offer comes after them and draws nothing
    const m2 = log[after(log, "month", after(log, "month") + 1)];
    assert.equal(drawsBetween(ref.rng, m2.snap.rng), 2, `seed ${seed}`);
  }
});

test("a bankrupt month: penalties first, then the notice and a plot check; the offer waits for the month's end", async () => {
  const s = calm(3, { treasury: -10 });
  const { log } = await run(s, always("n"));
  const i = after(log, "bankrupt");
  assert.equal(log[i - 1].screen.kind, "month");
  assert.equal(log[i + 1].screen.kind, "audience");
  assert.deepEqual([log[i].snap.pop[ARMY], log[i].snap.pop[POLICE], log[i].snap.str[POLICE], log[i].snap.presidentStrength], [8, 8, 5, 3]);
  assert.equal(log[i].snap.treasury, -10);
  const rest = restOfMonth(log, i);
  assert.equal(rest.filter((k) => k === "reportOffer").length, 1);
  assert.equal(rest[rest.length - 1], "reportOffer");
  const offer = log[after(log, "reportOffer", i)].screen;
  assert.ok(offer.kind === "reportOffer" && !offer.available && offer.cannotPay);
});

test("the treasury at exactly 0 neither pays nor is penalised", async () => {
  const s = calm(3, { treasury: 0 });
  const { log } = await run(s, always("n"));
  const m = log[after(log, "audience")];
  assert.equal(m.snap.treasury, 0);
  const b = after(log, "bankrupt");
  assert.ok(b === -1 || b > after(log, "audience"));
  assert.equal(log[after(log, "month")].snap.pop[ARMY], 9);
});

test("a bought report costs 1 and shows the month", async () => {
  const s = calm(4);
  const { log } = await run(s, (sc) => (sc.kind === "reportOffer" ? "Y" : "n"));
  const i = after(log, "reportOffer");
  assert.equal(log[i + 1].screen.kind, "report");
  assert.equal(log[i + 1].snap.treasury, log[i].snap.treasury - 1);
  const r = log[i + 1].screen;
  assert.ok(r.kind === "report" && r.variant === "bought" && r.month === 1);
});

// ── The audience ─────────────────────────────────────────────────────────

test("granting a request applies it; refusing costs the requester its gain", async () => {
  const yes = await run(calm(9), (sc) => (sc.kind === "dialog" ? "y" : "n"));
  const no = await run(calm(9), always("n"));
  const a = yes.log[after(yes.log, "audience")].screen;
  const b = no.log[after(no.log, "audience")].screen;
  assert.deepEqual(a, b);
  const ty = yes.log[after(yes.log, "treasury", 4)].snap, tn = no.log[after(no.log, "treasury", 4)].snap;
  assert.ok(a.kind === "audience");
  assert.ok(tn.pop[a.faction] < 9);
  assert.equal(ty.pop[a.faction], 9);
  assert.ok(ty.requestUsed[a.request] && tn.requestUsed[a.request]);
});

test("an unaffordable request: the dialog by itself, cash short, must refuse, then refused", async () => {
  const r = await find((seed) => calm(seed, { treasury: -500 }), () => always("y"),
    (log) => followedBy(log, ["dialog", "cashShort", "mustRefuse", "treasury"]) >= 0);
  const i = followedBy(r.log, ["dialog", "cashShort", "mustRefuse", "treasury"]);
  const d = r.log[i].screen;
  assert.ok(d.kind === "dialog" && !d.affordable);
  const aud = r.log[i - 3].screen.kind === "audience" ? r.log[i - 3].screen : r.log[i - 2].screen;
  assert.ok(aud.kind === "audience");
  // the "y" returned by the timed dialog was ignored: refused, not granted
  assert.ok(r.log[i + 3].snap.pop[aud.faction] < 9);
  const cs = r.log[i + 1].screen;
  assert.ok(cs.kind === "cashShort" && cs.askEast && cs.askWest);
});

test("advice is offered after the audience and shown on yes, changing nothing", async () => {
  const r = await run(calm(12), (sc) => (sc.kind === "adviceOffer" ? "y" : "n"));
  const i = after(r.log, "adviceOffer");
  assert.deepEqual(kinds(r.log).slice(i, i + 3), ["adviceOffer", "advice", "dialog"]);
  assert.deepEqual(r.log[i + 1].snap, r.log[i + 2].snap);
  const adv = r.log[i + 1].screen;
  assert.ok(adv.kind === "advice" && adv.lines.filter((l) => l.own).length === 1);
});

// ── Decisions ────────────────────────────────────────────────────────────

/** Keys for the first decision menu only, "n" everywhere else. */
function decisionKeys(keys: string[]): Answer {
  let k = 0, menus = 0;
  return (sc) => {
    if (sc.kind === "menu") menus++;
    if (menus === 1 && k < keys.length && ["menu", "section", "adviceOffer", "dialog"].includes(sc.kind)) return keys[k++];
    return "n";
  };
}

test("taking a decision: section, advice offer, dialog, treasury; the report offer ends the month", async () => {
  const r = await run(calm(2), decisionKeys(["1", "1", "n", "y"]));
  const i = after(r.log, "menu");
  assert.deepEqual(restOfMonth(r.log, i), ["menu", "section", "adviceOffer", "dialog", "treasury", "reportOffer"]);
  assert.ok(r.log[i + 4].snap.decisionUsed[0]);
  assert.ok(!r.log[i + 3].snap.decisionUsed[0]);
});

test("declining a decision's dialog goes back to the menu", async () => {
  const r = await run(calm(2), decisionKeys(["1", "2", "n", "n", "Enter"]));
  const i = after(r.log, "menu");
  assert.deepEqual(restOfMonth(r.log, i), ["menu", "section", "adviceOffer", "dialog", "menu", "reportOffer"]);
});

test("the Swiss account: its own screen, and the decision is over; repeatable", async () => {
  const r = await run(calm(2, { treasury: 501 }), decisionKeys(["3", "4"]));
  const i = after(r.log, "swiss");
  const sw = r.log[i].screen;
  assert.deepEqual(sw, { kind: "swiss", before: 501 - 60, moved: 220, treasury: 221, costs: 60, swiss: 220 });
  assert.deepEqual(restOfMonth(r.log, i), ["swiss", "reportOffer"]);
  assert.ok(!r.log[after(r.log, "reportOffer", i)].snap.decisionUsed[12]);
});

test("the bodyguard decision adds 2 and stays available", async () => {
  const r = await run(calm(2), decisionKeys(["3", "2", "n", "y"]));
  const t = r.log[after(r.log, "treasury", after(r.log, "menu"))].snap;
  assert.equal(t.presidentStrength, 6);
  assert.ok(!t.decisionUsed[10]);
});

test("a loan: wait, result, treasury, and the decision is over; too early in month 1", async () => {
  const r = await run(calm(2), decisionKeys(["4", "1"]));
  const i = after(r.log, "loanWait");
  assert.deepEqual(restOfMonth(r.log, i), ["loanWait", "loanResult", "treasury", "reportOffer"]);
  const res = r.log[i + 1].screen;
  assert.ok(res.kind === "loanResult" && res.outcome === "early" && res.power === "east");
  assert.equal(drawsBetween(r.log[i].snap.rng, r.log[i + 1].snap.rng), 1);
});

test("a granted loan draws pick(5) then pick(200) and hides the option", async () => {
  const r = await find((seed) => calm(seed, { month: 20 }), () => decisionKeys(["4", "2"]), (log) => log.some((x) => x.screen.kind === "loanResult" && x.screen.outcome === "granted"));
  const i = after(r.log, "loanResult");
  assert.equal(drawsBetween(r.log[i - 1].snap.rng, r.log[i].snap.rng), 2);
  assert.ok(r.log[i].snap.loanWest && r.log[i].snap.decisionUsed[14]);
  const res = r.log[i].screen;
  assert.ok(res.kind === "loanResult" && res.amount >= 270 && res.amount < 470);
});

test("a used-up section shows the note and returns to the menu", async () => {
  const s = calm(2);
  s.decisionUsed[6] = s.decisionUsed[7] = s.decisionUsed[8] = true;
  const r = await run(s, decisionKeys(["2", "x"]));
  const i = after(r.log, "menu");
  assert.deepEqual(restOfMonth(r.log, i), ["menu", "sectionUsed", "menu", "reportOffer"]);
});

test("an unaffordable decision: dialog by itself, cash short, back to the menu", async () => {
  const r = await run(calm(2, { treasury: 50 }), decisionKeys(["3", "3", "n", "y", "n"]));
  const i = after(r.log, "menu");
  assert.deepEqual(restOfMonth(r.log, i), ["menu", "section", "adviceOffer", "dialog", "cashShort", "menu", "reportOffer"]);
  assert.ok(!r.log[i + 5].snap.helicopter);
});

// ── Endings ──────────────────────────────────────────────────────────────

const ENDING_TAIL = ["funeral", "rating", "report"];

test("ending: killed when all three factions hire assassins", async () => {
  const s = newGame(1);
  Object.assign(s, { month: 5, popularity: [0, 0, 0, 0, 9, 9, 9, 9], strength: [0, 0, 0, 0, 0, 9] });
  const r = await run(s, always("n"));
  assert.deepEqual(kinds(r.log).slice(-5), ["assassinAttempt", "assassinResult", ...ENDING_TAIL]);
  const res = r.log[r.log.length - 4];
  assert.ok(res.screen.kind === "assassinResult" && res.screen.killed);
  assert.equal(res.snap.alive, false);
  assert.ok(!r.s.alive && !r.s.escaped);
  const fin = r.log[r.log.length - 1].screen;
  assert.ok(fin.kind === "report" && fin.variant === "final");
});

test("an assassin can miss, and the war check still follows", async () => {
  const r = await find((seed) => {
    const s = newGame(seed);
    return Object.assign(s, { month: 5, popularity: [0, 9, 9, 0, 9, 0, 9, 9], strength: [0, 0, 0, 0, 0, 0] });
  }, () => always("n"), (log) => log.some((x) => x.screen.kind === "assassinResult" && !x.screen.killed));
  const i = r.log.findIndex((x) => x.screen.kind === "assassinResult" && !x.screen.killed);
  assert.equal(drawsBetween(r.log[i - 1].snap.rng, r.log[i].snap.rng), 1); // the coin flip
  assert.equal(r.log[i].snap.alive, true);
});

/** The Neighbour hostile and overwhelming; home groups loyal but weak. */
const warState = (heli: boolean, bodyguard = 0) => (seed: number) => {
  const s = newGame(seed);
  return Object.assign(s, { popularity: [9, 9, 9, 0, 0, 9, 9, 9], strength: [0, 0, 0, 9, 9, 0], helicopter: heli, bodyguard });
};

test("ending: executed after a lost war without a helicopter", async () => {
  const r = await find(warState(false), () => always("n"), (log) => log.some((x) => x.screen.kind === "invasion"));
  const i = after(r.log, "invasion");
  const inv = r.log[i].screen;
  assert.ok(inv.kind === "invasion" && inv.theirs >= inv.ours + 1);
  assert.deepEqual(kinds(r.log).slice(i), ["invasion", "warResult", "execution", ...ENDING_TAIL]);
  const ex = r.log[i + 2].screen;
  assert.ok(ex.kind === "execution" && !ex.heliFailed);
  assert.equal(drawsBetween(r.log[i].snap.rng, r.log[i + 1].snap.rng), 1); // the swing, after the invasion screen
  assert.equal(r.log[i + 2].snap.rng, r.log[i + 1].snap.rng);
});

test("ending: a lost war with a helicopter: away (2 in 3) or executed under the failed helicopter", async () => {
  const away = await find(warState(true), () => always("n"), (log) => log.some((x) => x.screen.kind === "heliEscape"));
  const i = after(away.log, "heliEscape");
  assert.deepEqual(kinds(away.log).slice(i - 2), ["invasion", "warResult", "heliEscape", "rating", "report"]);
  assert.equal(drawsBetween(away.log[i - 1].snap.rng, away.log[i].snap.rng), 1);
  assert.ok(away.s.alive && away.s.escaped);
  const rating = away.log[i + 1].screen;
  assert.ok(rating.kind === "rating" && rating.alive && rating.survivalBonus === 10);

  const shot = await find(warState(true), () => always("n"), (log) => log.some((x) => x.screen.kind === "execution"));
  const ex = shot.log[after(shot.log, "execution")].screen;
  assert.ok(ex.kind === "execution" && ex.heliFailed);
  assert.ok(!shot.s.alive && !shot.s.escaped);
});

test("a won war wipes out the Neighbour's strength and the month goes on to the decision", async () => {
  const r = await find(warState(false, 40), () => always("n"), (log) => log.some((x) => x.screen.kind === "warResult"));
  const i = after(r.log, "warResult");
  const w = r.log[i].screen;
  assert.ok(w.kind === "warResult" && w.won);
  assert.equal(r.log[i].snap.str[NEIGHBOUR], 0);
  assert.equal(r.log[i + 1].screen.kind, "menu");
});

test("a threat of war rallies the home groups, then the decision", async () => {
  const r = await find((seed) => Object.assign(warState(false)(seed), { popularity: [5, 5, 5, 0, 0, 5, 9, 9] }), () => always("n"),
    (log) => log.some((x) => x.screen.kind === "warThreat"));
  const i = after(r.log, "warThreat");
  const before = r.log[i - 1].snap.pop, now = r.log[i].snap.pop;
  assert.deepEqual([now[0] - before[0], now[1] - before[1], now[2] - before[2], now[5] - before[5], now[4] - before[4]], [1, 1, 1, 1, 0]);
  assert.equal(r.log[i + 1].screen.kind, "menu");
});

/** The Army rises with the guerrillas; everyone else is loyal. */
const revoltState = (over: Partial<GameState> = {}) => (seed: number) => {
  const s = newGame(seed);
  return Object.assign(s, { popularity: [0, 9, 9, 0, 9, 9, 9, 9], strength: [9, 6, 6, 9, 6, 6], month: 4, ...over });
};
const escapeKeys = (yes: boolean, help = "2"): Answer => (sc) => (sc.kind === "escapeAsk" ? (yes ? "y" : "n") : sc.kind === "helpList" ? help : "n");

test("ending: escape on foot, caught or across the border", async () => {
  const caught = await find(revoltState(), () => escapeKeys(true), (log) => log.some((x) => x.screen.kind === "caught"));
  const i = after(caught.log, "revoltAlarm");
  assert.deepEqual(kinds(caught.log).slice(i), ["revoltAlarm", "escapeAsk", "mountains", "caught", ...ENDING_TAIL]);
  assert.equal(drawsBetween(caught.log[i + 2].snap.rng, caught.log[i + 3].snap.rng), 1); // the raw draw, after the trek screen
  assert.ok(!caught.s.alive);
  const free = await find(revoltState(), () => escapeKeys(true), (log) => log.some((x) => x.screen.kind === "escaped"));
  assert.deepEqual(kinds(free.log).slice(after(free.log, "revoltAlarm")), ["revoltAlarm", "escapeAsk", "mountains", "escaped", "rating", "report"]);
  assert.ok(free.s.alive && free.s.escaped);
});

test("ending: escape by helicopter after a revolt, or a dead engine and the mountains", async () => {
  const up = await find(revoltState({ helicopter: true }), () => escapeKeys(true), (log) => log.some((x) => x.screen.kind === "heliEscape"));
  assert.deepEqual(kinds(up.log).slice(after(up.log, "revoltAlarm")), ["revoltAlarm", "escapeAsk", "heliEscape", "rating", "report"]);
  const down = await find(revoltState({ helicopter: true }), () => escapeKeys(true), (log) => log.some((x) => x.screen.kind === "heliFail"));
  const i = after(down.log, "heliFail");
  assert.deepEqual(kinds(down.log).slice(i, i + 2), ["heliFail", "mountains"]);
  assert.equal(drawsBetween(down.log[i - 1].snap.rng, down.log[i].snap.rng), 1);
});

test("ending: overthrown when the rebels are too strong", async () => {
  const r = await find(revoltState({ bodyguard: 0 }), () => escapeKeys(false), (log) => log.some((x) => x.screen.kind === "revoltAlarm"));
  const i = after(r.log, "revoltAlarm");
  assert.deepEqual(kinds(r.log).slice(i), ["revoltAlarm", "escapeAsk", "helpList", "strength", "revoltStart", "overthrown", ...ENDING_TAIL]);
  const h = r.log[i + 2].screen;
  assert.ok(h.kind === "helpList" && h.faction === ARMY && h.ally === GUERRILLAS && h.combined === 18);
  assert.deepEqual(h.kind === "helpList" && h.listed, [false, true, true, false, true, true]);
  const st = r.log[i + 3].screen;
  assert.deepEqual(st, { kind: "strength", bodyguard: 0, helper: 1, helperStrength: 6, rebels: 18 });
  assert.equal(drawsBetween(r.log[i + 4].snap.rng, r.log[i + 5].snap.rng), 1); // the swing, after the start screen
});

test("a crushed revolt: punish, the helper to 9, plots paused, a plot check, then the month's only report offer", async () => {
  const r = await find(revoltState({ bodyguard: 30 }), () => (sc: Screen) => (sc.kind === "crushed" ? "Y" : sc.kind === "reportOffer" ? "y" : escapeKeys(false, "6")(sc, 0)),
    (log) => log.some((x) => x.screen.kind === "crushed"));
  const i = after(r.log, "crushed");
  assert.equal(r.log[i].snap.status[ARMY], "revolution");
  const m = after(r.log, "month", i);
  const tail = kinds(r.log).slice(i, m + 1);
  // Bought or not, the offer follows the crushed screen and nothing else comes before the next month.
  assert.deepEqual(tail, tail.length === 3 ? ["crushed", "reportOffer", "month"] : ["crushed", "reportOffer", "report", "month"]);
  const offer = r.log[i + 1];
  assert.ok(offer.screen.kind === "reportOffer");
  const monthStart = lastBefore(r.log, "month", i);
  assert.equal(kinds(r.log).slice(monthStart, i).filter((k) => k === "reportOffer").length, 0, "no earlier offer this month");
  const snap = offer.snap;
  assert.deepEqual([snap.pop[ARMY], snap.str[ARMY], snap.pop[GUERRILLAS], snap.str[GUERRILLAS]], [0, 0, 0, 0]);
  assert.equal(snap.str[POLICE], 9);
  assert.equal(snap.plotPause, snap.month + 2);
  // the plot check ran between the crushed screen and the offer: the pause has cleared the plots
  assert.deepEqual(snap.status, ["none", "none", "none"]);
  assert.equal(snap.rng, r.log[i].snap.rng);
});

// ── The report offer: once a month, at its end (RULES §4 step 15) ───────

const ENDINGS = new Set(["execution", "heliEscape", "overthrown", "caught", "escaped"]);
const isEnding = (x: Step) => ENDINGS.has(x.screen.kind) || (x.screen.kind === "assassinResult" && x.screen.killed);

test("exactly one report offer per completed month, its last step, after the revolution check; offers draw nothing", async () => {
  let months = 0, bought = 0, revolutions = 0;
  for (let seed = 1; seed <= 300; seed++) {
    const keys = seed % 2 ? ["y", "1", "n", "3", "Y", "2", "Enter", "4", "5", "6"] : ["n", "y", "2", "5"];
    const { log } = await run(newGame(seed), rotating(keys, seed));
    const starts = log.flatMap((x, j) => (x.screen.kind === "month" ? [j] : []));
    assert.equal(kinds(log).slice(0, starts[0] ?? log.length).filter((k) => k === "reportOffer").length, 0, "none before month 1");
    for (let k = 0; k + 1 < starts.length; k++) {
      const seg = log.slice(starts[k], starts[k + 1]);
      const offers = seg.flatMap((x, j) => (x.screen.kind === "reportOffer" ? [j] : []));
      assert.equal(offers.length, 1, `seed ${seed} month ${k + 1}: ${kinds(seg)}`);
      const o = offers[0];
      const tail = kinds(seg).slice(o + 1);
      assert.ok(tail.length === 0 || (tail.length === 1 && tail[0] === "report"), `seed ${seed}: ${tail}`);
      if (tail.length) bought++;
      if (kinds(seg).includes("revoltAlarm")) revolutions++;
      // the next month's mood roll is the only draw between the offer and the next month screen
      assert.equal(drawsBetween(seg[o].snap.rng, log[starts[k + 1]].snap.rng), 2, `seed ${seed}`);
      months++;
    }
  }
  assert.ok(months > 1000 && bought > 50 && revolutions > 5, `${months} ${bought} ${revolutions}`);
});

test("no report offer after a game-ending screen: the reign's last month has none", async () => {
  const endings = new Set<string>();
  for (let seed = 1; seed <= 300; seed++) {
    const keys = seed % 2 ? ["y", "1", "n", "3", "Y", "2", "Enter", "4", "5", "6"] : ["n", "y", "2", "5"];
    const { log } = await run(newGame(seed), rotating(keys, seed));
    const end = log.findIndex(isEnding);
    assert.ok(end > 0, `seed ${seed}`);
    endings.add(log[end].screen.kind);
    const lastMonth = lastBefore(log, "month");
    assert.ok(lastMonth < end);
    assert.deepEqual(kinds(log).slice(lastMonth).filter((k) => k === "reportOffer"), [], `seed ${seed}`);
    assert.ok(log.slice(end).every((x) => x.screen.kind !== "reportOffer" && x.screen.kind !== "month"));
  }
  assert.ok(endings.size >= 4, [...endings].join());
});

test("the help list ignores other keys and shows itself again; an unlisted group is a joke and a run", async () => {
  const keys = ["y", "Enter", "0", "7", " ", "1"];
  let k = 0;
  const r = await find(revoltState({ helicopter: true }), () => { k = 0; return (sc) => (sc.kind === "helpList" ? keys[k++ % keys.length] : sc.kind === "escapeAsk" ? "n" : "n"); },
    (log) => log.some((x) => x.screen.kind === "joke"));
  const i = after(r.log, "helpList");
  assert.deepEqual(kinds(r.log).slice(i, i + 8), ["helpList", "helpList", "helpList", "helpList", "helpList", "helpList", "joke", "mountains"]);
  // the snapshot does not move while the list is shown again
  for (let j = i; j < i + 6; j++) assert.deepEqual(r.log[j].snap, r.log[i].snap);
  // the joke skips the helicopter: straight to the mountains, one raw draw after them
  assert.equal(r.log[i + 7].snap.rng, r.log[i + 6].snap.rng);
});

test("alone: no one to ask, any key, and the fight goes on without a helper", async () => {
  const r = await find((seed) => {
    const s = newGame(seed);
    return Object.assign(s, { popularity: [0, 0, 0, 0, 0, 0, 9, 9], strength: [9, 0, 0, 9, 0, 9], month: 4, bodyguard: 0 });
  }, () => escapeKeys(false), (log) => log.some((x) => x.screen.kind === "alone"));
  const i = after(r.log, "alone");
  assert.deepEqual(kinds(r.log).slice(i, i + 3), ["alone", "strength", "revoltStart"]);
  const st = r.log[i + 1].screen;
  assert.ok(st.kind === "strength" && st.helper === -1 && st.helperStrength === 0);
});

// ── The rating and the best ──────────────────────────────────────────────

test("the rating counts popularity, months, and for the living 10 and the Swiss money", async () => {
  const r = await find(revoltState({ swiss: 1234 }), () => escapeKeys(true), (log) => log.some((x) => x.screen.kind === "escaped"));
  const rating = r.log[after(r.log, "rating")];
  const sc = rating.screen;
  assert.ok(sc.kind === "rating");
  const pop = rating.snap.pop.reduce((a, b) => a + b, 0);
  assert.deepEqual([sc.popularity, sc.monthsPoints, sc.survivalBonus, sc.swissPoints], [pop, 3 * rating.snap.month, 10, 123]);
  assert.equal(sc.total, pop + 3 * rating.snap.month + 133);
  assert.equal(r.outcome.score, sc.total);
});

test("the best so far includes this reign; a new best is flagged only when beaten", async () => {
  const first = await run(newGame(7), rotating(["n", "1", "y"]), null);
  const rate = (log: Step[]) => log[after(log, "rating")].screen as Extract<Screen, { kind: "rating" }>;
  assert.equal(rate(first.log).newBest, true);
  assert.equal(first.outcome.best, first.outcome.score);
  const again = await run(newGame(7), rotating(["n", "1", "y"]), first.outcome.score);
  assert.equal(rate(again.log).newBest, false);
  assert.equal(again.outcome.best, first.outcome.score);
  const low = await run(newGame(7), rotating(["n", "1", "y"]), 0);
  assert.equal(rate(low.log).newBest, first.outcome.score > 0);
  const high = await run(newGame(7), rotating(["n", "1", "y"]), 99999);
  assert.equal(rate(high.log).best, 99999);
  assert.equal(high.outcome.best, 99999);
});

test("the same seed and keys replay the same reign", async () => {
  const a = await run(newGame(1234), rotating(["y", "n", "3", "2", "Y", "Enter"]));
  const b = await run(newGame(1234), rotating(["y", "n", "3", "2", "Y", "Enter"]));
  assert.deepEqual(a.log, b.log);
});
