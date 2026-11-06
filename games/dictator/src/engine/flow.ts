// One reign, played as an async script over IO (docs/RULES.md §4), so tests can drive it headless.
// The state changes in the order RULES gives, and each screen is shown at the point RULES and
// GDD §7 place it. A random draw happens just before the first screen that reveals its outcome.
import { DECISIONS, GROUP_KEYS, REQUESTS, SECTIONS } from "./data";
import * as rules from "./rules";
import type { AdviceLine, IO, Item, Screen } from "./screens";
import { GameState, POLICE } from "./state";

/** RULES §15.1: only Y means yes, in either case. */
export const isYes = (key: string): boolean => key === "y" || key === "Y";

/** A digit key 1…max as a number, or 0 for any other key. */
export function digit(key: string, max: number): number {
  if (key.length !== 1 || key < "1" || key > "9") return 0;
  const n = key.charCodeAt(0) - 48;
  return n <= max ? n : 0;
}

export interface Outcome {
  /** This reign's rating. */
  score: number;
  /** The best rating so far, including this reign. */
  best: number;
}

/** Thrown inside the flow when the reign ends; caught by playGame. */
class ReignOver {}

/** Play one reign, from the welcome screen to the final report. */
export async function playGame(io: IO, s: GameState, best: number | null = null): Promise<Outcome> {
  const show = (screen: Screen) => io.show(screen);

  // ── Shared screens ───────────────────────────────────────────────────
  const treasury = () => show({ kind: "treasury", treasury: s.treasury, costs: s.costs, swiss: s.swiss });

  const report = (variant: "first" | "bought" | "final") => show({
    kind: "report", variant, month: s.month, popularity: [...s.popularity], strength: [...s.strength],
    plots: [...s.plots], allies: [...s.allies], bodyguard: s.bodyguard, revolutionStrength: s.revolutionStrength,
  });

  async function reportOffer(): Promise<void> {
    const a = rules.reportAvailability(s);
    const key = await show({
      kind: "reportOffer", ...a, policePopularity: s.popularity[POLICE], policeStrength: s.strength[POLICE],
    });
    if (a.available && isYes(key)) {
      rules.buyReport(s);
      await report("bought");
    }
  }

  /** The President dies: the death screen has been shown; on to the funeral. */
  function die(): never {
    s.alive = false;
    throw new ReignOver();
  }
  function getAway(): never {
    s.escaped = true;
    throw new ReignOver();
  }

  // ── Advice and the decision dialog (§8.2, §8.3) ─────────────────────
  function adviceLines(item: Item): AdviceLine[] {
    const e = item.type === "request" ? REQUESTS[item.index] : DECISIONS[item.index];
    const from = item.type === "request" ? REQUESTS[item.index].from : -1;
    const lines: AdviceLine[] = [];
    GROUP_KEYS.forEach((k, g) => {
      const change = e.popularity[k];
      if (change) lines.push({ group: g, measure: "popularity", change, own: g === from });
    });
    GROUP_KEYS.forEach((k, g) => {
      const change = e.strength[k];
      if (change) lines.push({ group: g, measure: "strength", change, own: false });
    });
    return lines;
  }

  /** Advice offer, advice, then the dialog. Returns "yes", "no" or "unaffordable". */
  async function consider(item: Item): Promise<"yes" | "no" | "unaffordable"> {
    if (isYes(await show({ kind: "adviceOffer", item }))) await show({ kind: "advice", item, lines: adviceLines(item) });
    const e = item.type === "request" ? REQUESTS[item.index] : DECISIONS[item.index];
    const affordable = rules.isAffordable(s, e);
    const key = await show({ kind: "dialog", item, affordable, once: e.once, monthly: e.monthly });
    if (!affordable) {
      await show({ kind: "cashShort", item, askEast: !s.loanEast, askWest: !s.loanWest });
      return "unaffordable";
    }
    return isYes(key) ? "yes" : "no";
  }

  // ── The audience (§8) ────────────────────────────────────────────────
  async function audience(): Promise<void> {
    const r = rules.chooseRequest(s);
    await show({ kind: "audience", request: r, faction: REQUESTS[r].from });
    const answer = await consider({ type: "request", index: r });
    if (answer === "unaffordable") await show({ kind: "mustRefuse" });
    if (answer === "yes") rules.grantRequest(s, r);
    else rules.refuseRequest(s, r);
    await treasury();
  }

  // ── Dangers (§10, §11) ───────────────────────────────────────────────
  async function assassination(): Promise<void> {
    const f = rules.assassinStrikes(s);
    if (f < 0) return;
    await show({ kind: "assassinAttempt", faction: f });
    const killed = rules.attemptKills(s);
    if (killed) s.alive = false;
    await show({ kind: "assassinResult", killed });
    if (killed) die();
  }

  async function war(): Promise<void> {
    if (!rules.isNeighbourHostile(s)) return;
    if (!rules.neighbourInvades(s)) {
      rules.rallyToTheFlag(s);
      await show({ kind: "warThreat" });
      return;
    }
    const ours = rules.homeForce(s), theirs = rules.invaderForce(s);
    await show({ kind: "invasion", ours, theirs });
    const lost = rules.neighbourWins(ours, theirs, rules.swing(s));
    if (!lost) {
      rules.winWar(s);
      await show({ kind: "warResult", won: true });
      return;
    }
    await show({ kind: "warResult", won: false });
    const heliFailed = s.helicopter && !rules.helicopterStarts(s);
    if (s.helicopter && !heliFailed) {
      s.escaped = true;
      await show({ kind: "heliEscape" });
      getAway();
    }
    s.alive = false;
    await show({ kind: "execution", heliFailed });
    die();
  }

  // ── Presidential decisions (§9) ──────────────────────────────────────
  async function decide(): Promise<void> {
    for (;;) {
      const section = digit(await show({ kind: "menu", month: s.month }), 5);
      if (!section) return;
      const options = SECTIONS[section - 1].map((d, i) => ({ number: i + 1, decision: d, available: rules.isDecisionAvailable(s, d) }));
      if (!options.some((o) => o.available)) {
        await show({ kind: "sectionUsed", section });
        continue;
      }
      const chosen = options[digit(await show({ kind: "section", section, options }), options.length) - 1];
      if (!chosen || !chosen.available) continue;
      const d = chosen.decision;
      const special = DECISIONS[d].special;
      if (special === "swiss") {
        const before = s.treasury;
        const moved = rules.moveToSwiss(s);
        await show({ kind: "swiss", before, moved, treasury: s.treasury, costs: s.costs, swiss: s.swiss });
        return;
      }
      if (special === "loanEast" || special === "loanWest") {
        const power = special === "loanEast" ? "east" : "west";
        await show({ kind: "loanWait", power });
        const result = rules.requestLoan(s, power);
        await show({ kind: "loanResult", power, outcome: result.outcome, amount: result.outcome === "granted" ? result.amount : 0 });
        await treasury();
        return;
      }
      const answer = await consider({ type: "decision", index: d });
      if (answer !== "yes") continue;
      rules.takeDecision(s, d);
      await treasury();
      return;
    }
  }

  // ── News (§12) ───────────────────────────────────────────────────────
  async function news(): Promise<void> {
    const n = rules.newsToday(s);
    if (n < 0) return;
    rules.printHeadline(s, n);
    await show({ kind: "newsAlert" });
    await show({ kind: "newsHeadline", headline: n });
    rules.checkPlots(s);
  }

  // ── Revolution (§13) ─────────────────────────────────────────────────
  async function onFoot(): Promise<void> {
    await show({ kind: "mountains" });
    if (rules.caughtOnFoot(s)) {
      s.alive = false;
      await show({ kind: "caught" });
      die();
    }
    s.escaped = true;
    await show({ kind: "escaped" });
    getAway();
  }

  async function escape(): Promise<void> {
    if (s.helicopter) {
      if (rules.helicopterStarts(s)) {
        s.escaped = true;
        await show({ kind: "heliEscape" });
        getAway();
      }
      await show({ kind: "heliFail" });
    }
    await onFoot();
  }

  async function fight(faction: number): Promise<void> {
    const ally = s.allies[faction];
    const combined = rules.rebelForce(s, faction);
    const listed = rules.helpers(s);
    let helper = -1;
    if (!listed.some(Boolean)) {
      await show({ kind: "alone", faction, ally, combined });
    } else {
      let n = 0;
      while (!n) n = digit(await show({ kind: "helpList", faction, ally, combined, listed }), 6);
      if (!listed[n - 1]) {
        await show({ kind: "joke", group: n - 1 });
        await onFoot();
      }
      helper = n - 1;
    }
    const helperStrength = helper >= 0 ? s.strength[helper] : 0;
    await show({ kind: "strength", bodyguard: s.bodyguard, helper, helperStrength, rebels: combined });
    await show({ kind: "revoltStart" });
    if (!rules.revoltCrushed(combined, s.bodyguard, helperStrength, rules.swing(s))) {
      s.alive = false;
      await show({ kind: "overthrown" });
      die();
    }
    if (isYes(await show({ kind: "crushed" }))) rules.punishRebels(s, faction);
    rules.afterVictory(s, helper);
    rules.checkPlots(s); // the month ends with its report offer (step 15)
  }

  async function revolution(): Promise<void> {
    const f = rules.whoRises(s);
    if (f < 0) return;
    await show({ kind: "revoltAlarm" });
    if (isYes(await show({ kind: "escapeAsk" }))) await escape();
    else await fight(f);
  }

  // ── One month (§4) ───────────────────────────────────────────────────
  // The remake offers a report once a month, at its end (step 15, owner decision); the plot
  // checks stay where RULES puts them. A reign that ends mid-month never reaches the offer.
  async function month(): Promise<void> {
    rules.rollMood(s); // step 1
    s.month++; // step 2
    await show({ kind: "month", month: s.month });
    rules.checkPlots(s); // step 3
    if (rules.settleAccounts(s) === "bankrupt") { // step 4
      await show({ kind: "bankrupt" });
      rules.checkPlots(s);
    }
    await audience(); // step 5
    rules.checkPlots(s); // step 6
    await assassination(); // step 7
    await war(); // step 8
    rules.checkPlots(s); // step 9 (step 10: no offer here)
    await decide(); // step 11
    rules.checkPlots(s); // step 12
    await news(); // step 13
    await revolution(); // step 14
    await reportOffer(); // step 15: the month's only offer
  }

  // ── The reign ────────────────────────────────────────────────────────
  await show({ kind: "welcome", best });
  await treasury();
  await report("first");
  try {
    for (;;) await month();
  } catch (e) {
    if (!(e instanceof ReignOver)) throw e;
  }
  if (!s.alive) await show({ kind: "funeral", months: s.month });
  const r = rules.rate(s);
  const newBest = best === null || r.total > best;
  const bestSoFar = best === null ? r.total : Math.max(best, r.total);
  await show({ kind: "rating", ...r, best: bestSoFar, newBest });
  await report("final");
  return { score: r.total, best: bestSoFar };
}
