// The rules of a reign as small pure functions over the state (docs/RULES.md §3–§14).
// Each one changes only what RULES says it changes, and draws only the numbers RULES lists.
import { Changes, DECISIONS, Effects, GROUP_KEYS, HEADLINES, REQUESTS } from "./data";
import {
  ARMY, clampGroup, EAST, FACTIONS, GameState, GUERRILLAS, LANDOWNERS, NEIGHBOUR, PEASANTS, pick, draw, POLICE, STRENGTH_COUNT, WEST,
} from "./state";

// ── The month's mood (§3) ────────────────────────────────────────────────

/** Roll the hidden threshold (2–4), then the revolution strength (10–12). */
export function rollMood(s: GameState): void {
  s.threshold = pick(s, 3) + 2;
  s.revolutionStrength = pick(s, 3) + 10;
}

/** A group whose popularity is at or below the threshold has turned against the President. */
export const isDisaffected = (s: GameState, group: number): boolean => s.popularity[group] <= s.threshold;

// ── Changes ──────────────────────────────────────────────────────────────

/** Apply popularity and strength changes, clamping each group to 0–9. */
export function applyChanges(s: GameState, popularity: Changes, strength: Changes): void {
  GROUP_KEYS.forEach((k, g) => {
    if (popularity[k]) s.popularity[g] = clampGroup(s.popularity[g] + popularity[k]!);
    if (g < STRENGTH_COUNT && strength[k]) s.strength[g] = clampGroup(s.strength[g] + strength[k]!);
  });
}

/** Add to the monthly running costs, which never go below 0. */
export function changeCosts(s: GameState, by: number): void {
  s.costs = Math.max(0, s.costs + by);
}

// ── Accounts (§5) ────────────────────────────────────────────────────────

export type Accounts = "bankrupt" | "paid" | "even";

/** Debt is checked before credit: in debt nothing is paid and loyalty slips; in credit the costs are paid. */
export function settleAccounts(s: GameState): Accounts {
  if (s.treasury < 0) {
    s.popularity[ARMY] = clampGroup(s.popularity[ARMY] - 1);
    s.popularity[POLICE] = clampGroup(s.popularity[POLICE] - 1);
    s.strength[POLICE] = clampGroup(s.strength[POLICE] - 1);
    s.bodyguard = Math.max(0, s.bodyguard - 1);
    return "bankrupt";
  }
  if (s.treasury > 0) {
    s.treasury -= s.costs;
    return "paid";
  }
  return "even";
}

// ── Plots (§6) ───────────────────────────────────────────────────────────

/** The first disaffected group (1–6, in order, not the faction itself) strong enough to rise with it, or -1. */
export function findAlly(s: GameState, faction: number): number {
  for (let g = 0; g < STRENGTH_COUNT; g++) {
    if (g === faction || !isDisaffected(s, g)) continue;
    if (s.strength[g] + s.strength[faction] >= s.revolutionStrength) return g;
  }
  return -1;
}

/** Work out what each domestic faction plans this month. */
export function checkPlots(s: GameState): void {
  if (s.month <= 2) return;
  for (const f of FACTIONS) { s.plots[f] = "none"; s.allies[f] = -1; }
  if (s.month < s.plotPause) return;
  for (const f of FACTIONS) {
    if (!isDisaffected(s, f)) continue;
    const ally = findAlly(s, f);
    s.plots[f] = ally >= 0 ? "revolution" : "assassination";
    s.allies[f] = ally;
  }
}

// ── Intelligence reports (§7) ────────────────────────────────────────────

export interface ReportAvailability {
  available: boolean;
  policeDisloyal: boolean;
  policeWeak: boolean;
  cannotPay: boolean;
}

export function reportAvailability(s: GameState): ReportAvailability {
  const policeDisloyal = s.popularity[POLICE] <= s.threshold;
  const policeWeak = s.strength[POLICE] <= s.threshold;
  const cannotPay = s.treasury <= 0;
  return { available: !policeDisloyal && !policeWeak && !cannotPay, policeDisloyal, policeWeak, cannotPay };
}

export const REPORT_PRICE = 1;

export function buyReport(s: GameState): void {
  s.treasury -= REPORT_PRICE;
}

// ── The audience (§8) ────────────────────────────────────────────────────

export const REQUEST_LOOKAHEAD = 22;

/** Choose this month's request, marking it used: one pick(24) per attempt, resetting the marks when needed. */
export function chooseRequest(s: GameState): number {
  for (;;) {
    const start = pick(s, 24);
    for (let i = 0; i < REQUEST_LOOKAHEAD; i++) {
      const r = (start + i) % 24;
      if (!s.requestUsed[r]) { s.requestUsed[r] = true; return r; }
    }
    s.requestUsed.fill(false);
  }
}

/** Does an item cost money: a payment out, or a rise in monthly costs? */
export const costsMoney = (e: Effects): boolean => e.once < 0 || e.monthly > 0;

/** Can the treasury cover an item (§8.3)? */
export function isAffordable(s: GameState, e: Effects): boolean {
  if (s.treasury + e.once > 0) return true;
  if (costsMoney(e) && (s.treasury + e.once < 0 || s.treasury - e.monthly < 0)) return false;
  return true;
}

/** Grant an item: its popularity and strength changes, then its money. */
export function grantEffects(s: GameState, e: Effects): void {
  applyChanges(s, e.popularity, e.strength);
  s.treasury += e.once;
  changeCosts(s, e.monthly);
}

export const grantRequest = (s: GameState, r: number): void => grantEffects(s, REQUESTS[r]);

/** Refusing costs the requester exactly the popularity it would have gained. */
export function refuseRequest(s: GameState, r: number): void {
  const req = REQUESTS[r];
  const gain = req.popularity[GROUP_KEYS[req.from]] ?? 0;
  s.popularity[req.from] = clampGroup(s.popularity[req.from] - gain);
}

// ── Presidential decisions (§9) ──────────────────────────────────────────

export const isDecisionAvailable = (s: GameState, d: number): boolean => !s.decisionUsed[d];

/** Take a normal decision: its effects, the bodyguard and helicopter extras, and the used mark. */
export function takeDecision(s: GameState, d: number): void {
  const dec = DECISIONS[d];
  grantEffects(s, dec);
  if (dec.bodyguard) s.bodyguard += 2;
  if (dec.helicopter) s.helicopter = true;
  if (!dec.repeatable) s.decisionUsed[d] = true;
}

/** Move half the treasury (rounded down) to Switzerland, if that is at least 1; returns the amount moved. */
export function moveToSwiss(s: GameState): number {
  const amount = Math.floor(s.treasury / 2);
  if (amount < 1) return 0;
  s.treasury -= amount;
  s.swiss += amount;
  return amount;
}

export type Power = "east" | "west";
export type LoanResult = { outcome: "early" } | { outcome: "noMore" } | { outcome: "refused" } | { outcome: "granted"; amount: number };

export const LOAN_DECISION: Record<Power, number> = { east: 13, west: 14 };

/** Ask a superpower for money: too early, no more, refused or granted, in that order (§9.2). */
export function requestLoan(s: GameState, power: Power): LoanResult {
  const wait = pick(s, 5);
  if (s.month < 3 + wait) return { outcome: "early" };
  const lent = power === "east" ? s.loanEast : s.loanWest;
  if (lent) return { outcome: "noMore" };
  const group = power === "east" ? EAST : WEST;
  if (isDisaffected(s, group)) return { outcome: "refused" };
  const amount = s.popularity[group] * 30 + pick(s, 200);
  s.treasury += amount;
  if (power === "east") s.loanEast = true; else s.loanWest = true;
  s.decisionUsed[LOAN_DECISION[power]] = true;
  return { outcome: "granted", amount };
}

// ── Assassination (§10) ──────────────────────────────────────────────────

/** Pick the faction that might strike; returns it if it plans an assassination, else -1. */
export function assassinStrikes(s: GameState): number {
  const f = FACTIONS[pick(s, 3)];
  return s.plots[f] === "assassination" ? f : -1;
}

/** Settle an attempt: all three plotting kills; unloved, weak police leave it to a coin flip. */
export function attemptKills(s: GameState): boolean {
  if (FACTIONS.every((f) => s.plots[f] === "assassination")) return true;
  if (isDisaffected(s, POLICE) && s.strength[POLICE] <= s.threshold) return pick(s, 2) === 0;
  return false;
}

// ── War (§11) ────────────────────────────────────────────────────────────

export const isNeighbourHostile = (s: GameState): boolean =>
  s.popularity[NEIGHBOUR] <= s.threshold && s.strength[NEIGHBOUR] >= s.threshold;

/** One chance in three that a hostile Neighbour invades rather than threatens. */
export const neighbourInvades = (s: GameState): boolean => pick(s, 3) === 0;

/** A threat of war rallies the home groups. */
export function rallyToTheFlag(s: GameState): void {
  for (const g of [ARMY, PEASANTS, LANDOWNERS, POLICE]) s.popularity[g] = clampGroup(s.popularity[g] + 1);
}

/** The country's force: the President plus each loyal home group's strength. */
export function homeForce(s: GameState): number {
  let total = s.bodyguard;
  for (const g of [ARMY, PEASANTS, LANDOWNERS, POLICE]) if (!isDisaffected(s, g)) total += s.strength[g];
  return total;
}

/** The invaders' force: every disaffected group 1–6. */
export function invaderForce(s: GameState): number {
  let total = 0;
  for (let g = 0; g < STRENGTH_COUNT; g++) if (isDisaffected(s, g)) total += s.strength[g];
  return total;
}

/** A swing of −1, 0 or +1 for a battle. */
export const swing = (s: GameState): number => pick(s, 3) - 1;

/** The Neighbour wins if its force plus the swing reaches the country's. */
export const neighbourWins = (ours: number, theirs: number, swingBy: number): boolean => theirs + swingBy >= ours;

/** A won war wipes out the Neighbour's strength. */
export function winWar(s: GameState): void {
  s.strength[NEIGHBOUR] = 0;
}

/** The helicopter starts two times in three. */
export const helicopterStarts = (s: GameState): boolean => pick(s, 3) !== 0;

// ── News (§12) ───────────────────────────────────────────────────────────

/** One chance in three of news; then the first unused headline from a random start. Returns it, or -1. */
export function newsToday(s: GameState): number {
  if (pick(s, 3) !== 0) return -1;
  const start = pick(s, 6);
  for (let i = 0; i < 6; i++) {
    const n = (start + i) % 6;
    if (!s.newsUsed[n]) return n;
  }
  return -1;
}

/** Print a headline: mark it used and apply its changes (no money moves). */
export function printHeadline(s: GameState, n: number): void {
  s.newsUsed[n] = true;
  applyChanges(s, HEADLINES[n].popularity, HEADLINES[n].strength);
}

// ── Revolution (§13) ─────────────────────────────────────────────────────

/** Up to three picks of a faction; the first that plans a revolution rises. Returns it, or -1. */
export function whoRises(s: GameState): number {
  for (let i = 0; i < 3; i++) {
    const f = FACTIONS[pick(s, 3)];
    if (s.plots[f] === "revolution") return f;
  }
  return -1;
}

/** The rebels' combined strength: the faction and its ally. */
export const rebelForce = (s: GameState, faction: number): number => s.strength[faction] + s.strength[s.allies[faction]];

/** Groups 1–6 that may be asked for help: those whose popularity is above the threshold. */
export const helpers = (s: GameState): boolean[] =>
  Array.from({ length: STRENGTH_COUNT }, (_, g) => !isDisaffected(s, g));

/** On foot over the mountains: one raw draw; caught unless floor(u × (guerrillas ÷ 3 + 0.4)) is 0. */
export function caughtOnFoot(s: GameState): boolean {
  const u = draw(s);
  return Math.floor(u * (s.strength[GUERRILLAS] / 3 + 0.4)) !== 0;
}

/** The revolt is crushed if the rebels are no stronger than the President, the helper and the swing. */
export const revoltCrushed = (rebels: number, president: number, helper: number, swingBy: number): boolean =>
  rebels <= president + helper + swingBy;

/** Punish the rebels: popularity and strength 0 for the faction and its ally. */
export function punishRebels(s: GameState, faction: number): void {
  for (const g of [faction, s.allies[faction]]) { s.popularity[g] = 0; s.strength[g] = 0; }
}

/** After a crushed revolt: the helper grows to full strength and plots pause for two months. */
export function afterVictory(s: GameState, helper: number): void {
  if (helper >= 0) s.strength[helper] = 9;
  s.plotPause = s.month + 2;
}

// ── The end (§14) ────────────────────────────────────────────────────────

export interface Rating {
  popularity: number;
  months: number;
  monthsPoints: number;
  alive: boolean;
  survivalBonus: number;
  swiss: number;
  swissPoints: number;
  total: number;
}

export function rate(s: GameState): Rating {
  const popularity = s.popularity.reduce((a, b) => a + b, 0);
  const monthsPoints = 3 * s.month;
  const survivalBonus = s.alive ? 10 : 0;
  const swissPoints = s.alive ? Math.floor(s.swiss / 10) : 0;
  return {
    popularity, months: s.month, monthsPoints, alive: s.alive, survivalBonus, swiss: s.swiss, swissPoints,
    total: popularity + monthsPoints + survivalBonus + swissPoints,
  };
}

