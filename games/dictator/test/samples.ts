// Worst-case examples of every screen, shared by the layout tests and the contact sheet:
// longest names, biggest numbers, negative money, every option present, every flag set.
import type { Screen } from "../src/engine/screens";
import { SoundOverlay } from "../src/ui/overlay";
import { drawAbout, drawHowto, drawScreen, drawTitle, finish, Presentation } from "../src/ui/screens";
import type { ZXScreen } from "../src/zx/screen";

const BIG = 12345, NEG = -12345;
const allPops = [9, 9, 9, 9, 9, 9, 9, 9], allStr = [9, 9, 9, 9, 9, 9];

/** Samples for the contact sheet and the layout tests: every engine kind and every variant. */
export const SCREENS: Screen[] = [
  { kind: "welcome", best: 99999 },
  { kind: "welcome", best: null },
  { kind: "month", month: 999 },
  { kind: "treasury", treasury: BIG, costs: BIG, swiss: BIG },
  { kind: "treasury", treasury: NEG, costs: 0, swiss: 0 },
  { kind: "report", variant: "bought", month: 999, popularity: allPops, strength: allStr, plots: ["revolution", "revolution", "assassination"], allies: [5, 5, -1], bodyguard: 999, revolutionStrength: 12 },
  { kind: "report", variant: "first", month: 0, popularity: [7, 7, 7, 0, 7, 7, 7, 7], strength: [6, 6, 6, 6, 6, 6], plots: ["none", "none", "none"], allies: [-1, -1, -1], bodyguard: 4, revolutionStrength: 10 },
  { kind: "report", variant: "final", month: 999, popularity: allPops, strength: allStr, plots: ["assassination", "none", "revolution"], allies: [-1, -1, 3], bodyguard: 4, revolutionStrength: 11 },
  { kind: "reportOffer", available: true, policeDisloyal: false, policeWeak: false, cannotPay: false, policePopularity: 9, policeStrength: 9 },
  { kind: "reportOffer", available: false, policeDisloyal: true, policeWeak: true, cannotPay: true, policePopularity: 4, policeStrength: 4 },
  { kind: "bankrupt" },
  { kind: "audience", request: 0, faction: 0 },
  { kind: "audience", request: 9, faction: 1 },
  { kind: "adviceOffer", item: { type: "request", index: 12 } },
  {
    kind: "advice", item: { type: "request", index: 12 }, lines: [
      { group: 0, measure: "popularity", change: -1, own: false }, { group: 1, measure: "popularity", change: 4, own: true },
      { group: 2, measure: "popularity", change: -2, own: false }, { group: 4, measure: "popularity", change: 2, own: false },
      { group: 5, measure: "popularity", change: -1, own: false }, { group: 6, measure: "popularity", change: 1, own: false },
      { group: 1, measure: "strength", change: 1, own: false }, { group: 2, measure: "strength", change: -1, own: false },
      { group: 3, measure: "strength", change: -1, own: false },
    ],
  },
  {
    kind: "advice", item: { type: "decision", index: 8 }, lines: [
      { group: 0, measure: "popularity", change: 3, own: false }, { group: 1, measure: "popularity", change: 3, own: false },
      { group: 2, measure: "popularity", change: 3, own: false }, { group: 5, measure: "popularity", change: -9, own: false },
      { group: 0, measure: "strength", change: 2, own: false }, { group: 1, measure: "strength", change: 1, own: false },
      { group: 2, measure: "strength", change: 1, own: false }, { group: 3, measure: "strength", change: 1, own: false },
      { group: 5, measure: "strength", change: -9, own: false },
    ],
  },
  { kind: "dialog", item: { type: "request", index: 12 }, affordable: true, once: -100, monthly: 8 },
  { kind: "dialog", item: { type: "request", index: 18 }, affordable: true, once: 100, monthly: 5 },
  { kind: "dialog", item: { type: "request", index: 15 }, affordable: true, once: 0, monthly: -6 },
  { kind: "dialog", item: { type: "request", index: 1 }, affordable: true, once: 0, monthly: 0 },
  { kind: "dialog", item: { type: "decision", index: 11 }, affordable: false, once: -120, monthly: 0 },
  { kind: "cashShort", item: { type: "decision", index: 0 }, askEast: true, askWest: true },
  { kind: "cashShort", item: { type: "request", index: 9 }, askEast: false, askWest: true },
  { kind: "mustRefuse" },
  { kind: "menu", month: 999 },
  { kind: "section", section: 1, options: [0, 1, 2, 3, 4, 5].map((d) => ({ number: d + 1, decision: d, available: true })) },
  { kind: "section", section: 3, options: [9, 10, 11, 12].map((d, i) => ({ number: i + 1, decision: d, available: d !== 11 })) },
  { kind: "section", section: 4, options: [13, 14, 15].map((d, i) => ({ number: i + 1, decision: d, available: true })) },
  { kind: "sectionUsed", section: 2 },
  { kind: "swiss", before: BIG, moved: 6172, treasury: 6173, costs: BIG, swiss: BIG },
  { kind: "swiss", before: NEG, moved: 0, treasury: NEG, costs: BIG, swiss: BIG },
  { kind: "loanWait", power: "west" },
  { kind: "loanResult", power: "west", outcome: "early", amount: 0 },
  { kind: "loanResult", power: "east", outcome: "noMore", amount: 0 },
  { kind: "loanResult", power: "east", outcome: "refused", amount: 0 },
  { kind: "loanResult", power: "west", outcome: "refused", amount: 0 },
  { kind: "loanResult", power: "west", outcome: "granted", amount: 469 },
  { kind: "newsAlert" },
  { kind: "newsHeadline", headline: 3 },
  { kind: "assassinAttempt", faction: 1 },
  { kind: "assassinResult", killed: true },
  { kind: "assassinResult", killed: false },
  { kind: "warThreat" },
  { kind: "invasion", ours: 999, theirs: 999 },
  { kind: "warResult", won: true },
  { kind: "warResult", won: false },
  { kind: "heliEscape" },
  { kind: "execution", heliFailed: true },
  { kind: "execution", heliFailed: false },
  { kind: "revoltAlarm" },
  { kind: "escapeAsk" },
  { kind: "helpList", faction: 1, ally: 5, combined: 999, listed: [true, true, true, true, true, true] },
  { kind: "alone", faction: 1, ally: 5, combined: 999 },
  { kind: "joke", group: 5 },
  { kind: "strength", bodyguard: 999, helper: 5, helperStrength: 9, rebels: 999 },
  { kind: "strength", bodyguard: 999, helper: -1, helperStrength: 0, rebels: 999 },
  { kind: "revoltStart" },
  { kind: "overthrown" },
  { kind: "crushed" },
  { kind: "heliFail" },
  { kind: "mountains" },
  { kind: "caught" },
  { kind: "escaped" },
  { kind: "funeral", months: 999 },
  { kind: "rating", popularity: 72, months: 999, monthsPoints: 2997, alive: true, survivalBonus: 10, swiss: BIG, swissPoints: 1234, total: 99999, best: 99999, newBest: true },
  { kind: "rating", popularity: 0, months: 1, monthsPoints: 3, alive: false, survivalBonus: 0, swiss: 0, swissPoints: 0, total: 3, best: 99999, newBest: false },
];

/** The screens the original moved on by itself (RULES §15.5): they now hold, then wait for a key. */
export const HELD_KINDS: ReadonlySet<Screen["kind"]> = new Set<Screen["kind"]>([
  "month", "bankrupt", "cashShort", "mustRefuse", "sectionUsed", "loanWait", "newsAlert", "newsHeadline", "assassinAttempt",
  "assassinResult", "warThreat", "invasion", "warResult", "heliEscape", "execution", "revoltAlarm", "joke", "strength",
  "revoltStart", "overthrown", "heliFail", "mountains", "caught", "escaped",
]);
export const isHeld = (s: Screen): boolean =>
  HELD_KINDS.has(s.kind) || (s.kind === "reportOffer" && !s.available) || (s.kind === "dialog" && !s.affordable);

/** Every data text on its screens (for the layout tests only, not the contact sheet). */
export const DATA_SCREENS: Screen[] = [
  ...Array.from({ length: 24 }, (_, r): Screen => ({ kind: "audience", request: r, faction: Math.floor(r / 8) })),
  ...Array.from({ length: 24 }, (_, r): Screen => ({ kind: "dialog", item: { type: "request", index: r }, affordable: true, once: -120, monthly: 10 })),
  ...[0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 15, 16, 17, 18].map((d): Screen => ({ kind: "dialog", item: { type: "decision", index: d }, affordable: true, once: -120, monthly: -10 })),
  ...Array.from({ length: 19 }, (_, d): Screen => ({ kind: "cashShort", item: { type: "decision", index: d }, askEast: true, askWest: true })),
  ...Array.from({ length: 6 }, (_, n): Screen => ({ kind: "newsHeadline", headline: n })),
  ...[2, 5].map((s): Screen => ({ kind: "section", section: s, options: [0, 1, 2].map((i) => ({ number: i + 1, decision: (s === 2 ? 6 : 16) + i, available: true })) })),
  ...[0, 1, 2].map((f): Screen => ({ kind: "helpList", faction: f, ally: 5, combined: 999, listed: [true, true, true, true, true, true] })),
];

export interface Sample { name: string; draw: (z: ZXScreen) => Presentation }

const label = (s: Screen, i: number) => `${s.kind}-${i}`;

/** Everything to render: the extras, then every engine screen, each in its final animation frame. */
export const SAMPLES: Sample[] = [
  { name: "title", draw: (z) => drawTitle(z) },
  ...[1, 2, 3, 4, 5, 6].map((page) => ({ name: `howto-${page}`, draw: (z: ZXScreen) => drawHowto(z, page) })),
  { name: "about", draw: (z) => drawAbout(z) },
  {
    name: "sound-overlay",
    draw: (z) => { const pr = finish(drawScreen(z, SCREENS[0])); new SoundOverlay(z).draw(false); return pr; },
  },
  ...SCREENS.map((s, i) => ({ name: label(s, i), draw: (z: ZXScreen) => finish(drawScreen(z, s)) })),
];

export const LAYOUT_SAMPLES: Sample[] = [
  ...SAMPLES,
  ...DATA_SCREENS.map((s, i) => ({ name: `data-${label(s, i)}`, draw: (z: ZXScreen) => finish(drawScreen(z, s)) })),
];
