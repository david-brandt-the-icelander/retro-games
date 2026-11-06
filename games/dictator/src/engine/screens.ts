// Every screen the engine shows (the engine kinds of docs/GDD.md §7), with the data it needs,
// and the one interface the engine talks through.
import type { Plot } from "./state";
import type { Power } from "./rules";

/** A request (R1–R24, index 0–23) or a presidential decision (D1–D19, index 0–18). */
export type Item = { type: "request"; index: number } | { type: "decision"; index: number };

/** One advice line: a group, which measure, and the change. */
export interface AdviceLine {
  group: number;
  measure: "popularity" | "strength";
  change: number;
  /** The requester's own popularity line. */
  own: boolean;
}

export type Screen =
  | { kind: "welcome"; best: number | null }
  | { kind: "month"; month: number }
  | { kind: "treasury"; treasury: number; costs: number; swiss: number }
  | {
      kind: "report"; variant: "first" | "bought" | "final"; month: number;
      popularity: number[]; strength: number[]; plots: Plot[]; allies: number[];
      bodyguard: number; revolutionStrength: number;
    }
  | {
      kind: "reportOffer"; available: boolean;
      policeDisloyal: boolean; policeWeak: boolean; cannotPay: boolean;
      policePopularity: number; policeStrength: number;
    }
  | { kind: "bankrupt" }
  | { kind: "audience"; request: number; faction: number }
  | { kind: "adviceOffer"; item: Item }
  | { kind: "advice"; item: Item; lines: AdviceLine[] }
  | { kind: "dialog"; item: Item; affordable: boolean; once: number; monthly: number }
  | { kind: "cashShort"; item: Item; askEast: boolean; askWest: boolean }
  | { kind: "mustRefuse" }
  | { kind: "menu"; month: number }
  | { kind: "section"; section: number; options: Array<{ number: number; decision: number; available: boolean }> }
  | { kind: "sectionUsed"; section: number }
  | { kind: "swiss"; before: number; moved: number; treasury: number; costs: number; swiss: number }
  | { kind: "loanWait"; power: Power }
  | { kind: "loanResult"; power: Power; outcome: "early" | "noMore" | "refused" | "granted"; amount: number }
  | { kind: "newsAlert" }
  | { kind: "newsHeadline"; headline: number }
  | { kind: "assassinAttempt"; faction: number }
  | { kind: "assassinResult"; killed: boolean }
  | { kind: "warThreat" }
  | { kind: "invasion"; ours: number; theirs: number }
  | { kind: "warResult"; won: boolean }
  | { kind: "heliEscape" }
  | { kind: "execution"; heliFailed: boolean }
  | { kind: "revoltAlarm" }
  | { kind: "escapeAsk" }
  | { kind: "helpList"; faction: number; ally: number; combined: number; listed: boolean[] }
  | { kind: "alone"; faction: number; ally: number; combined: number }
  | { kind: "joke"; group: number }
  | { kind: "strength"; bodyguard: number; helper: number; helperStrength: number; rebels: number }
  | { kind: "revoltStart" }
  | { kind: "overthrown" }
  | { kind: "crushed" }
  | { kind: "heliFail" }
  | { kind: "mountains" }
  | { kind: "caught" }
  | { kind: "escaped" }
  | { kind: "funeral"; months: number }
  | {
      kind: "rating"; popularity: number; months: number; monthsPoints: number; alive: boolean;
      survivalBonus: number; swiss: number; swissPoints: number; total: number; best: number; newBest: boolean;
    };

export type ScreenKind = Screen["kind"];

/** Every engine kind, in GDD §7 order. */
export const SCREEN_KINDS: readonly ScreenKind[] = [
  "welcome", "month", "treasury", "report", "reportOffer", "bankrupt", "audience", "adviceOffer", "advice", "dialog",
  "cashShort", "mustRefuse", "menu", "section", "sectionUsed", "swiss", "loanWait", "loanResult", "newsAlert",
  "newsHeadline", "assassinAttempt", "assassinResult", "warThreat", "invasion", "warResult", "heliEscape", "execution",
  "revoltAlarm", "escapeAsk", "helpList", "alone", "joke", "strength", "revoltStart", "overthrown", "crushed",
  "heliFail", "mountains", "caught", "escaped", "funeral", "rating",
];

export interface IO {
  /**
   * Show a screen and resolve with the raw key pressed ("y", "Y", "1", "Enter", " " …).
   * Timed screens resolve when their time is up; the engine ignores what they return.
   */
  show(screen: Screen): Promise<string>;
}
