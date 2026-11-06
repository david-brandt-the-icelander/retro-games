// One painter per screen kind, cell for cell from docs/UI-DESIGN.md, plus the extras (title,
// how to play, About). Each painter draws the screen and says how it is presented: the keypad
// offer, whether it waits for a key or moves on by itself, its sound, its animation steps and
// its screen-reader text.
import { REQUESTS } from "../engine/data";
import type { Item, Screen } from "../engine/screens";
import type { Note } from "../zx/sound";
import { Attr, BLACK, BLUE, COLS, CYAN, GREEN, MAGENTA, RED, WHITE, YELLOW, ZXScreen } from "../zx/screen";
import * as ART from "./art";
import { at, Painter } from "./paint";
import { MotifId, tally } from "./sounds";
import * as T from "./text";

/** A keypad offer: [key sent, button label]. */
export type Offer = ReadonlyArray<readonly [key: string, label: string]>;

/** A drawing step of an animated screen, `at` milliseconds after the screen appears. */
export interface Step {
  at: number;
  run: () => void;
  /** A blip mixed over what is playing. */
  sound?: { notes: readonly Note[]; volume: number };
  /** A motif that replaces what is playing. */
  motif?: MotifId;
}

export interface Presentation {
  /** Buttons on the touch keypad (shown once keys are read). */
  offer: Offer;
  /** key: any key answers; digits: only the keypad or keys answer, a tap on the screen is ignored; timed: no key is read. */
  mode: "key" | "digits" | "timed";
  /** timed: how long the screen stays; key/digits: how long before keys are read. */
  ms: number;
  /** Motifs played one after another when the screen has been drawn. */
  motifs: MotifId[];
  steps: Step[];
  speech: string;
  assertive: boolean;
}

/** The neutral "any key" a button or a tap sends. */
export const ANY_KEY = "Enter";

const NEXT: Offer = [[ANY_KEY, T.BUTTON.next]];
const YES_NO: Offer = [["y", T.BUTTON.yes], ["n", T.BUTTON.no]];

const keyScreen = (speech: string, offer: Offer = NEXT, motifs: MotifId[] = []): Presentation =>
  ({ offer, mode: "key", ms: 0, motifs, steps: [], speech, assertive: false });
const timed = (ms: number, speech: string, motifs: MotifId[] = [], assertive = false): Presentation =>
  ({ offer: [], mode: "timed", ms, motifs, steps: [], speech, assertive });

// ── Colour families (ART-BIBLE §3) ──────────────────────────────────────

const PALACE_BAND = at(BLUE, YELLOW, { bright: true });
const LEDGER_BAND = at(BLACK, GREEN);
const DOSSIER_BAND = at(BLACK, YELLOW); // a manila tab on the dark file
const AUDIENCE_BAND = at(BLACK, MAGENTA);
const CABINET_BAND = at(WHITE, BLUE);

function palace(p: Painter, office: string): void {
  p.page(WHITE, BLUE, BLUE).letterhead(office, PALACE_BAND, ART.SEAL);
}

function ledgerPage(p: Painter, office: string, border = GREEN): void {
  p.page(BLUE, WHITE, border).letterhead(office, LEDGER_BAND, ART.SEAL);
  p.fill(2, 2, 2, 20, at(RED, WHITE));
  p.vline(20, 16, 167);
}

function dossier(p: Painter): void {
  p.page(WHITE, BLACK, BLACK).letterhead(T.OFFICE.security, DOSSIER_BAND, ART.SEAL);
}

function audienceHall(p: Painter, office: string): void {
  p.page(WHITE, BLACK, MAGENTA).letterhead(office, AUDIENCE_BAND, ART.SEAL);
}

function cabinet(p: Painter, title: string): void {
  p.page(BLACK, CYAN, BLUE).letterhead(T.OFFICE.directorate, CABINET_BAND, ART.SEAL);
  p.centre(3, title);
  p.hline(33, 32, 223);
}

/** Lines in a region, one per row from `row`, centred in columns c0–c1. */
function lines(p: Painter, row: number, c0: number, c1: number, ls: readonly string[], attr?: Attr, align: "left" | "centre" = "centre"): void {
  ls.forEach((l, i) => p.text(row + i, c0, c1, l, attr, align));
}

/** The treasury balance lines (credit or debt), costs and Swiss line, in columns 4–30. */
function treasuryLines(p: Painter, rows: [number, number, number, number], treasury: number, costs: number, swiss: number): void {
  const ink = at(BLUE, WHITE);
  p.text(rows[0], 4, 30, T.ledger(T.TREASURY.holds, T.money(treasury), 27), ink);
  if (treasury < 0) p.bar(rows[1], 4, 30, T.TREASURY.debt, 4, RED);
  else p.text(rows[1], 4, 30, T.TREASURY.solvent, ink);
  p.text(rows[2], 4, 30, T.ledger(T.TREASURY.costs, T.money(costs), 27), ink);
  if (swiss > 0) p.text(rows[3], 4, 30, T.ledger(T.TREASURY.swiss, T.money(swiss), 27), ink);
}

/** The two text lines of a request or decision. */
export function itemText(item: Item): readonly [string, string] {
  return item.type === "request" ? T.REQUEST_TEXT[item.index] : (T.DECISION_TEXT[item.index] ?? ["", ""]);
}

/** What could not be paid for: a decision's label, or the request's petition line. */
export function itemName(item: Item): string {
  return item.type === "request" ? T.DIALOG.petition(T.LABELS[REQUESTS[item.index].from]) : T.DECISION_LABEL[item.index];
}

/** The dialog's money lines. */
export function moneyLines(once: number, monthly: number): string[] {
  const out: string[] = [];
  if (once > 0) out.push(T.DIALOG.paidIn(T.money(once)));
  if (once < 0) out.push(T.DIALOG.paidOut(T.money(-once)));
  if (monthly > 0) out.push(T.DIALOG.costsRise(T.money(monthly)));
  if (monthly < 0) out.push(T.DIALOG.costsFall(T.money(-monthly)));
  if (!out.length) out.push(T.DIALOG.free);
  return out;
}

/** A 3-cell number box with its digit in the middle. */
function numberBox(p: Painter, row: number, c0: number, n: number, attr: Attr): void {
  p.fill(c0, row, c0 + 2, row, attr);
  p.print(c0 + 1, row, String(n), attr);
}

/** The northern ridge (ART-BIBLE §6): every pixel from the ridge line down to y = 103 is ink. */
const RIDGE: ReadonlyArray<readonly [number, number]> = [
  [0, 92], [18, 78], [34, 86], [56, 62], [70, 72], [92, 54], [110, 68], [128, 58], [150, 76], [168, 56], [186, 66],
  [204, 50], [224, 70], [240, 62], [255, 84],
];
export function ridgeY(x: number): number {
  for (let i = 1; i < RIDGE.length; i++) {
    const [x0, y0] = RIDGE[i - 1], [x1, y1] = RIDGE[i];
    if (x <= x1) return Math.round(y0 + ((y1 - y0) * (x - x0)) / (x1 - x0));
  }
  return RIDGE[RIDGE.length - 1][1];
}
function ridge(p: Painter, paper: number): void {
  p.fill(0, 6, COLS - 1, 12, at(BLACK, paper));
  for (let x = 0; x < 256; x++) p.vline(x, ridgeY(x), 103);
}

// ── Game screens ────────────────────────────────────────────────────────

type Draw<K extends Screen["kind"]> = (p: Painter, s: Extract<Screen, { kind: K }>) => Presentation;

const DRAW: { [K in Screen["kind"]]: Draw<K> } = {
  welcome(p, s) {
    palace(p, T.OFFICE.palace);
    p.icon(15, 3, ART.ROSETTE, at(YELLOW, BLUE, { bright: true }));
    const w = s.best === null ? T.WELCOME.first : T.WELCOME.best(s.best);
    w.forEach((l, i) => p.text(8 + i, 1, 30, l, at(i === 1 ? YELLOW : WHITE, BLUE), "centre"));
    p.fill(0, 12, 31, 15, at(BLUE, WHITE));
    lines(p, 13, 0, 31, T.WELCOME.voucher, at(BLUE, WHITE));
    for (let x = 0; x < 256; x++) if (Math.min(x, 255 - x) % 8 < 4) { p.z.plot(x, 96); p.z.plot(x, 127); }
    for (let y = 96; y < 128; y++) if (Math.min(y - 96, 127 - y) % 8 < 4) { p.z.plot(0, y); p.z.plot(255, y); }
    p.footer(T.PROMPT.any);
    return keyScreen(T.WELCOME.speech(w), NEXT, ["welcome-fanfare"]);
  },

  month(p, s) {
    p.page(YELLOW, BLUE, BLUE);
    p.icon(11, 3, ART.RING, at(WHITE, BLUE));
    p.icon(20, 3, ART.RING, at(WHITE, BLUE));
    p.fill(8, 4, 23, 5, at(BLACK, RED, { bright: true }));
    p.big(4, 8, 23, T.MONTH.heading, at(BLACK, RED, { bright: true }));
    p.fill(8, 6, 23, 15, at(BLACK, WHITE));
    p.big(9, 10, 21, String(s.month), at(BLACK, WHITE));
    p.hline(127, 64, 191, 2);
    p.centre(18, T.MONTH.line, at(YELLOW, BLUE));
    return timed(1000, T.MONTH.speech(s.month), ["month-chime"]);
  },

  treasury(p, s) {
    ledgerPage(p, T.OFFICE.treasury);
    treasuryLines(p, [4, 5, 7, 9], s.treasury, s.costs, s.swiss);
    p.hline(51, 32, 247, 2).hline(67, 32, 247, 2).hline(82, 32, 247).hline(84, 32, 247);
    p.footer(T.PROMPT.any);
    return keyScreen(T.TREASURY.speech(s.treasury, s.costs, s.swiss), NEXT, ["ledger"]);
  },

  report(p, s) {
    dossier(p);
    p.bar(2, 0, 31, T.REPORT.classified, 1, RED);
    const sub = s.variant === "first" ? T.REPORT.first : s.variant === "final" ? T.REPORT.final : T.REPORT.bought(s.month);
    p.text(3, 1, 31, sub);
    p.text(5, 1, 30, T.REPORT.heading, at(YELLOW, BLACK, { bright: true }));
    for (let g = 0; g < 8; g++) {
      const row = 6 + g;
      p.print(1, row, String(g + 1));
      p.text(row, 4, 14, T.LABELS[g]);
      p.print(19, row, String(s.popularity[g]));
      p.print(25, row, g < 6 ? String(s.strength[g]) : "-");
    }
    const plots: string[] = [];
    const spoken: string[] = [];
    for (let f = 0; f < 3; f++) {
      if (s.plots[f] === "revolution") {
        plots.push(T.REPORT.rise(T.LABELS[f], s.allies[f] + 1, T.LABELS[s.allies[f]]));
        spoken.push(T.REPORT.speechPlotRise(f, s.allies[f]));
      } else if (s.plots[f] === "assassination") {
        plots.push(T.REPORT.assassin(T.LABELS[f]));
        spoken.push(T.REPORT.speechPlotAssassin(f));
      }
    }
    if (plots.length) plots.forEach((l, i) => p.bar(15 + i, 0, 31, l, 1, RED));
    else p.text(15, 1, 31, T.REPORT.noPlots);
    p.text(19, 1, 30, T.REPORT.bodyguard(s.bodyguard));
    p.text(20, 1, 30, T.REPORT.revolt(s.revolutionStrength));
    p.footer(T.PROMPT.any);
    const title = s.variant === "first" ? T.REPORT.speechTitle.first : s.variant === "final" ? T.REPORT.speechTitle.final : T.REPORT.speechTitle.bought(s.month);
    const groups = T.SPOKEN.map((n, g) => (g < 6 ? `${n}: popularity ${s.popularity[g]}, strength ${s.strength[g]}.` : `${n}: popularity ${s.popularity[g]}.`));
    const speech = `State Security file, top secret, ${title}. ${groups.join(" ")} ${spoken.length ? spoken.join(" ") : T.REPORT.speechNoPlots} ` +
      `${T.REPORT.speechOdds(s.bodyguard, s.revolutionStrength)} Press any key.`;
    return keyScreen(speech, NEXT, ["report-open"]);
  },

  reportOffer(p, s) {
    dossier(p);
    p.icon(14, 3, ART.FOLDER, at(YELLOW, BLACK));
    const price = T.money(1);
    if (s.available) {
      p.text(8, 1, 30, T.OFFER.ask[0], undefined, "centre");
      p.text(9, 1, 30, T.OFFER.ask[1](price), undefined, "centre");
      p.footer(T.PROMPT.yes);
      return keyScreen(T.OFFER.speechAvailable(price), YES_NO);
    }
    p.text(8, 1, 30, T.OFFER.none, undefined, "centre");
    const reasons: string[] = [];
    if (s.policeDisloyal) reasons.push(T.OFFER.disloyal(s.policePopularity));
    if (s.policeWeak) reasons.push(T.OFFER.weak(s.policeStrength));
    if (s.cannotPay) reasons.push(T.OFFER.cannotPay);
    lines(p, 11, 1, 30, reasons);
    return timed(2500, T.OFFER.speechUnavailable(reasons), ["report-none"]);
  },

  bankrupt(p) {
    ledgerPage(p, T.OFFICE.treasury, RED);
    const stamp = p.stamp(7, 3, 24, 4, RED);
    p.big(3, 8, 23, T.BANKRUPT.stamp, stamp);
    lines(p, 7, 4, 30, T.BANKRUPT.lines, at(BLUE, WHITE), "left");
    p.icon(14, 14, ART.COFFER, at(BLUE, WHITE));
    return timed(5000, T.BANKRUPT.speech, ["bankrupt-slide"], true);
  },

  audience(p, s) {
    audienceHall(p, T.OFFICE.audience);
    p.icon(13, 3, ART.DOOR_AJAR, at(YELLOW, BLACK));
    p.fill(13, 9, 18, 9, at(WHITE, MAGENTA));
    p.centre(10, T.AUDIENCE.announce(T.LABELS[s.faction]), at(WHITE, BLACK));
    p.fill(0, 12, 31, 15, at(BLUE, WHITE));
    const text = T.REQUEST_TEXT[s.request];
    lines(p, 13, 1, 30, text, at(BLUE, WHITE));
    p.footer(T.PROMPT.any);
    return keyScreen(T.AUDIENCE.speech(s.faction, text), NEXT, ["audience-bell"]);
  },

  adviceOffer(p) {
    audienceHall(p, T.OFFICE.counsel);
    p.icon(15, 5, ART.QUILL, at(WHITE, BLACK));
    p.centre(9, T.ADVICE.ask, at(WHITE, BLACK));
    p.footer(T.PROMPT.yes);
    return keyScreen(T.ADVICE.askSpeech, YES_NO);
  },

  advice(p, s) {
    audienceHall(p, T.OFFICE.counsel);
    p.fill(0, 2, 31, 3, at(BLUE, WHITE));
    const text = itemText(s.item);
    lines(p, 2, 1, 30, text, at(BLUE, WHITE));
    s.lines.forEach((l, i) => {
      const row = 5 + i;
      const ink = at(l.own ? YELLOW : WHITE, BLACK);
      if (l.own) p.print(0, row, T.ADVICE.marker, ink);
      p.text(row, 3, 13, T.LABELS[l.group], ink);
      p.text(row, 15, 24, T.ADVICE.measure[l.measure], ink);
      p.text(row, 26, 27, T.signed(l.change), l.change > 0 ? at(GREEN, BLACK) : at(RED, BLACK, { bright: true }), "right");
    });
    if (s.item.type === "request") p.text(20, 0, 31, T.ADVICE.key, at(YELLOW, BLACK));
    p.footer(T.PROMPT.any);
    return keyScreen(T.ADVICE.speech(text, s.lines));
  },

  dialog(p, s) {
    p.page(BLUE, WHITE, MAGENTA).letterhead(T.OFFICE.signature, AUDIENCE_BAND, ART.SEAL);
    const header = s.item.type === "request" ? T.DIALOG.petition(T.LABELS[REQUESTS[s.item.index].from]) : T.DIALOG.decree;
    p.text(3, 1, 30, header, undefined, "centre");
    const text = itemText(s.item);
    lines(p, 5, 1, 30, text);
    p.hline(68, 8, 247);
    const money = moneyLines(s.once, s.monthly);
    lines(p, 10, 0, 31, money);
    p.icon(3, 14, ART.QUILL, at(BLUE, WHITE));
    for (let i = 0; i < 5; i++) { p.z.plot(48 + i, 120 + i); p.z.plot(52 - i, 120 + i); }
    p.hline(126, 56, 207, 2);
    const spokenHeader = s.item.type === "request" ? `Petition of ${T.SPOKEN_THE[REQUESTS[s.item.index].from]}` : "By decree of President Ortiga";
    const speech = T.DIALOG.speech(spokenHeader, text, money, s.affordable);
    if (!s.affordable) return timed(5000, speech);
    p.footer(T.PROMPT.yes);
    return keyScreen(speech, YES_NO);
  },

  cashShort(p, s) {
    ledgerPage(p, T.OFFICE.treasury);
    const ink = at(BLUE, WHITE);
    const item = itemName(s.item);
    p.text(4, 4, 31, item, ink);
    lines(p, 6, 4, 31, T.CASH_SHORT.lines, ink, "left");
    const hints = [...(s.askEast ? [T.CASH_SHORT.ask(T.POWER.east)] : []), ...(s.askWest ? [T.CASH_SHORT.ask(T.POWER.west)] : [])];
    lines(p, 9, 4, 31, hints, ink, "left");
    p.icon(14, 13, ART.COFFER, ink);
    return timed(7000, T.CASH_SHORT.speech(item, hints), ["cash-short-raspberry"]);
  },

  mustRefuse(p) {
    audienceHall(p, T.OFFICE.audience);
    p.icon(13, 3, ART.DOOR_SHUT, at(YELLOW, BLACK));
    const stamp = p.stamp(1, 10, 30, 13, RED);
    lines(p, 11, 2, 29, T.MUST_REFUSE.lines, stamp);
    return timed(5000, T.MUST_REFUSE.speech, ["refuse-thud"]);
  },

  menu(p, s) {
    cabinet(p, T.MENU.title(s.month));
    T.MENU.sections.forEach((label, i) => {
      numberBox(p, 6 + 2 * i, 1, i + 1, at(WHITE, BLACK));
      p.text(6 + 2 * i, 5, 31, label);
    });
    p.centre(17, T.MENU.other);
    p.footer(T.PROMPT.menu);
    const offer: Offer = [...[1, 2, 3, 4, 5].map((n) => [String(n), String(n)] as const), [ANY_KEY, T.BUTTON.noDecision]];
    return keyScreen(T.MENU.speech(s.month), offer);
  },

  section(p, s) {
    cabinet(p, T.SECTION.title(s.section));
    const listed: Array<readonly [number, string]> = [];
    for (const o of s.options) {
      if (!o.available) continue;
      numberBox(p, 4 + 2 * o.number, 1, o.number, at(WHITE, BLACK));
      p.text(4 + 2 * o.number, 5, 31, T.DECISION_LABEL[o.decision]);
      listed.push([o.number, T.DECISION_LABEL[o.decision]]);
    }
    p.footer(T.PROMPT.section);
    const offer: Offer = [...listed.map(([n]) => [String(n), String(n)] as const), [ANY_KEY, T.BUTTON.back]];
    return keyScreen(T.SECTION.speech(s.section, listed), offer);
  },

  sectionUsed(p, s) {
    cabinet(p, T.SECTION.title(s.section));
    const stamp = p.stamp(1, 8, 30, 11, RED);
    lines(p, 9, 2, 29, T.SECTION.used, stamp);
    return timed(3000, T.SECTION.usedSpeech(s.section));
  },

  swiss(p, s) {
    ledgerPage(p, T.OFFICE.offshore);
    const ink = at(BLUE, WHITE);
    p.text(3, 4, 30, T.ledger(T.SWISS.was, T.money(s.before), 27), ink);
    if (s.moved > 0) {
      p.text(4, 4, 30, T.ledger(T.SWISS.slipped, T.money(s.moved), 27), ink);
      p.text(5, 4, 30, T.SWISS.moved, ink);
    } else lines(p, 4, 4, 30, T.SWISS.nothing, ink, "left");
    p.icon(15, 7, ART.BRIEFCASE, ink);
    p.hline(82, 32, 247).hline(84, 32, 247);
    const speech = T.SWISS.speech(s.before, s.moved);
    return {
      offer: NEXT, mode: "key", ms: 2000, motifs: s.moved > 0 ? ["swiss-whistle"] : [], assertive: false,
      speech,
      steps: [{
        at: 2000,
        run: () => { treasuryLines(p, [12, 13, 14, 15], s.treasury, s.costs, s.swiss); p.footer(T.PROMPT.any); },
      }],
    };
  },

  loanWait(p, s) {
    ledgerPage(p, T.OFFICE.foreign);
    p.icon(14, 5, ART.ENVELOPE, at(BLUE, WHITE));
    lines(p, 10, 4, 30, [T.LOAN.letter(T.POWER[s.power]), T.LOAN.considered], at(BLUE, WHITE));
    return timed(1000, T.LOAN.waitSpeech(T.POWER[s.power]), ["loan-typewriter"]);
  },

  loanResult(p, s) {
    ledgerPage(p, T.OFFICE.foreign);
    p.icon(14, 3, ART.ENVELOPE, at(BLUE, WHITE));
    const power = T.POWER[s.power];
    const ls = s.outcome === "early" ? T.LOAN.early(power)
      : s.outcome === "noMore" ? T.LOAN.noMore(power)
      : s.outcome === "refused" ? (s.power === "east" ? T.LOAN.refusedEast : T.LOAN.refusedWest)
      : T.LOAN.granted(power, T.money(s.amount));
    const stamp = p.stamp(1, 8, 30, 12, s.outcome === "granted" ? GREEN : RED);
    lines(p, 9, 2, 29, ls, stamp);
    p.footer(T.PROMPT.any);
    return keyScreen(T.LOAN.resultSpeech(ls), NEXT, [s.outcome === "granted" ? "loan-yes" : "loan-no"]);
  },

  newsAlert(p) {
    p.page(WHITE, BLACK, WHITE);
    p.icon(15, 4, ART.LAMP, at(RED, BLACK, { bright: true, flash: true }));
    p.fill(0, 9, 31, 12, at(BLACK, WHITE));
    for (let x = 4; x < 256; x += 8) for (const y of [75, 99]) { p.z.plot(x, y); p.z.plot(x + 1, y); p.z.plot(x, y + 1); p.z.plot(x + 1, y + 1); }
    const steps: Step[] = [];
    let t = 0;
    T.NEWS.alert.forEach((line, r) => {
      for (let i = 0; i < line.length; i++) {
        const ch = line[i], col = i, row = 10 + r;
        if (ch !== " ") steps.push({ at: t, run: () => { p.print(col, row, ch, at(BLACK, WHITE)); } });
        t += 60;
      }
    });
    return { ...timed(6000, T.NEWS.alertSpeech, ["news-teleprinter"], true), steps };
  },

  newsHeadline(p, s) {
    p.page(BLACK, WHITE, WHITE);
    p.fill(0, 0, 31, 1, at(WHITE, BLACK));
    p.big(0, 0, 31, T.NEWS.masthead, at(WHITE, BLACK));
    p.hline(17, 0, 255).hline(18, 0, 255).hline(19, 0, 255);
    const h = T.HEADLINE_TEXT[s.headline];
    lines(p, 5, 1, 30, h);
    const left = [112, 112, 104, 112, 96, 112, 112, 80, 112, 108, 64];
    const right = [112, 100, 112, 112, 112, 88, 112, 112, 104, 112, 72];
    for (let i = 0; i < 11; i++) {
      const y = 75 + 8 * i;
      p.hline(y, 8, 8 + left[i] - 1).hline(y, 136, 136 + right[i] - 1);
    }
    return timed(2000, T.NEWS.headlineSpeech(h));
  },

  assassinAttempt(p, s) {
    p.page(WHITE, BLACK, RED);
    p.icon(14, 4, ART.RETICLE, at(RED, BLACK, { bright: true, flash: true }));
    lines(p, 10, 0, 31, T.ASSASSIN.attempt(T.LABELS[s.faction]));
    return timed(1600, T.ASSASSIN.attemptSpeech(s.faction), ["assassin-shot"], true);
  },

  assassinResult(p, s) {
    p.page(WHITE, BLACK, s.killed ? BLACK : RED);
    if (!s.killed) p.icon(15, 4, ART.ROSETTE, at(YELLOW, BLACK, { bright: true }));
    const ls = s.killed ? T.ASSASSIN.killed : T.ASSASSIN.survived;
    lines(p, 10, 0, 31, ls);
    return timed(s.killed ? 2500 : 2000, ls.join(" "), [s.killed ? "assassin-dead" : "assassin-miss"], true);
  },

  warThreat(p) {
    p.page(GREEN, BLACK, GREEN);
    p.icon(14, 3, ART.BUGLE, at(YELLOW, BLACK));
    T.WAR.threat.forEach((l, i) => p.centre(8 + i, l, at(GREEN, BLACK, { bright: i === 0 })));
    return timed(3500, T.WAR.threatSpeech, ["war-drums"], true);
  },

  invasion(p, s) {
    p.page(GREEN, BLACK, RED);
    p.centre(2, T.WAR.invades, at(RED, BLACK, { bright: true }));
    p.icon(14, 4, ART.FIELDGUN, at(GREEN, BLACK));
    p.text(8, 1, 14, T.WAR.ours, undefined, "centre");
    p.text(8, 17, 30, T.WAR.theirs, undefined, "centre");
    p.big(10, 1, 14, String(s.ours), at(GREEN, BLACK, { bright: true }));
    p.big(10, 17, 30, String(s.theirs), at(GREEN, BLACK, { bright: true }));
    p.vline(127, 64, 95).vline(128, 64, 95);
    p.centre(14, T.WAR.guns, at(WHITE, BLACK));
    return timed(4000, T.WAR.invasionSpeech(s.ours, s.theirs), ["war-short"], true);
  },

  warResult(p, s) {
    p.page(GREEN, BLACK, s.won ? GREEN : RED);
    if (s.won) p.icon(14, 3, ART.BUGLE, at(YELLOW, BLACK));
    const stamp = p.stamp(1, 8, 30, 11, s.won ? GREEN : RED);
    const ls = s.won ? T.WAR.won : T.WAR.lost;
    lines(p, 9, 2, 29, ls, stamp);
    return timed(2500, ls.join(" "), [s.won ? "war-won" : "war-lost"], true);
  },

  heliEscape(p) {
    p.page(WHITE, BLUE, BLUE);
    p.fill(12, 11, 27, 12, at(WHITE, BLACK));
    p.rect(136, 90, 183, 93);
    p.fill(0, 13, 31, 13, at(WHITE, BLACK));
    lines(p, 15, 0, 31, T.HELI.escape);
    const sky = at(WHITE, BLUE);
    p.icon(18, 9, ART.HELICOPTER, sky);
    const steps: Step[] = [];
    for (let k = 1; k <= 5; k++) {
      const row = 9 - k;
      steps.push({ at: 500 * k, run: () => { p.clear(18, row + 2, 21, row + 2, sky); p.icon(18, row, ART.HELICOPTER, sky); } });
    }
    return { ...timed(3000, T.HELI.escapeSpeech, ["rotor"]), steps };
  },

  execution(p, s) {
    p.page(WHITE, BLACK, BLACK);
    const heading = s.heliFailed ? T.EXECUTION.heliHeading : T.EXECUTION.neighbourHeading;
    p.centre(4, heading, at(RED, BLACK, { bright: true }));
    p.hline(52, 64, 191);
    lines(p, 9, 0, 31, T.EXECUTION.lines);
    return timed(s.heliFailed ? 4500 : 3000, `${heading} ${T.EXECUTION.lines.join(" ")}`, s.heliFailed ? ["sputter", "volley"] : ["volley"], true);
  },

  revoltAlarm(p) {
    p.page(WHITE, BLACK, RED);
    p.icon(15, 3, ART.LAMP, at(RED, BLACK, { bright: true, flash: true }));
    p.big(7, 0, 31, T.REVOLT.alarm, at(RED, BLACK, { bright: true }));
    p.centre(11, T.REVOLT.streets);
    p.icon(14, 14, ART.STATUE, at(WHITE, BLACK));
    return timed(5000, T.REVOLT.alarmSpeech, ["revolt-siren"], true);
  },

  escapeAsk(p) {
    p.page(WHITE, BLACK, RED);
    p.icon(13, 3, ART.DOOR_AJAR, at(YELLOW, BLACK));
    lines(p, 11, 0, 31, T.REVOLT.ask);
    p.footer(T.PROMPT.yes);
    return keyScreen(T.REVOLT.askSpeech, YES_NO);
  },

  helpList(p, s) {
    p.page(WHITE, BLACK, RED);
    lines(p, 2, 0, 31, T.REVOLT.risen(T.LABELS[s.faction], T.LABELS[s.ally], s.combined));
    p.centre(4, T.REVOLT.who, at(YELLOW, BLACK));
    const listed: number[] = [];
    s.listed.forEach((ok, g) => {
      if (!ok) return;
      listed.push(g);
      numberBox(p, 7 + 2 * g, 9, g + 1, at(BLACK, WHITE));
      p.text(7 + 2 * g, 13, 24, T.LABELS[g]);
    });
    p.footer(T.PROMPT.help);
    const offer: Offer = [1, 2, 3, 4, 5, 6].map((n) => [String(n), String(n)] as const);
    return { ...keyScreen(T.REVOLT.helpSpeech(s.faction, s.ally, s.combined, listed), offer), mode: "digits", assertive: true };
  },

  alone(p, s) {
    p.page(WHITE, BLACK, RED);
    lines(p, 2, 0, 31, T.REVOLT.risen(T.LABELS[s.faction], T.LABELS[s.ally], s.combined));
    lines(p, 9, 0, 31, T.REVOLT.alone, at(YELLOW, BLACK));
    p.footer(T.PROMPT.any);
    return keyScreen(T.REVOLT.aloneSpeech(s.faction, s.ally, s.combined));
  },

  joke(p, s) {
    p.page(WHITE, BLACK, RED);
    lines(p, 9, 0, 31, T.REVOLT.joke(T.LABELS[s.group]));
    return timed(3000, T.REVOLT.jokeSpeech(s.group));
  },

  strength(p, s) {
    p.page(WHITE, BLACK, RED);
    p.text(7, 6, 25, `${T.REVOLT.bodyguard} ${s.bodyguard}`);
    p.text(8, 6, 25, s.helper >= 0 ? `${T.LABELS[s.helper]} ${s.helperStrength}` : `${T.REVOLT.noHelper} 0`);
    p.hline(76, 48, 207);
    p.text(10, 6, 25, `${T.REVOLT.rebels} ${s.rebels}`, at(RED, BLACK, { bright: true }));
    p.centre(14, T.REVOLT.blink, at(YELLOW, BLACK));
    return timed(5000, T.REVOLT.strengthSpeech(s.bodyguard, s.helper, s.helperStrength, s.rebels), ["heartbeat"]);
  },

  revoltStart(p) {
    p.page(WHITE, BLACK, RED);
    p.icon(14, 3, ART.STATUE, at(WHITE, BLACK));
    lines(p, 11, 0, 31, T.REVOLT.start);
    return timed(2500, T.REVOLT.start.join(" "), ["skirmish"], true);
  },

  overthrown(p) {
    p.page(WHITE, BLACK, RED);
    p.icon(13, 4, ART.STATUE_FALLEN, at(WHITE, BLACK));
    lines(p, 10, 0, 31, T.REVOLT.overthrown);
    return timed(2500, T.REVOLT.overthrown.join(" "), ["overthrown-drop"], true);
  },

  crushed(p) {
    p.page(WHITE, BLACK, YELLOW);
    p.icon(14, 3, ART.STATUE, at(YELLOW, BLACK, { bright: true }));
    lines(p, 10, 0, 31, T.REVOLT.crushed, at(YELLOW, BLACK));
    p.centre(14, T.REVOLT.punish, at(WHITE, BLACK));
    p.footer(T.PROMPT.yes);
    return keyScreen(T.REVOLT.crushedSpeech, YES_NO, ["crushed-fanfare"]);
  },

  heliFail(p) {
    p.page(WHITE, BLUE, BLUE);
    p.fill(10, 11, 25, 12, at(WHITE, BLACK));
    p.rect(104, 90, 151, 93);
    p.fill(0, 13, 31, 13, at(WHITE, BLACK));
    p.icon(17, 7, ART.SMOKE, at(WHITE, BLUE));
    p.icon(14, 9, ART.HELICOPTER, at(WHITE, BLUE));
    lines(p, 15, 0, 31, T.HELI.fail);
    return timed(3000, T.HELI.failSpeech, ["sputter"]);
  },

  mountains(p) {
    p.page(WHITE, BLUE, BLUE);
    p.icon(26, 2, ART.MOON, at(WHITE, BLUE));
    ridge(p, BLUE);
    const path = at(WHITE, BLACK);
    p.fill(0, 13, 31, 14, path);
    p.icon(1, 13, ART.WALKER, path);
    lines(p, 17, 0, 31, T.FLIGHT.mountains);
    const steps: Step[] = [];
    for (let k = 1; k <= 28; k++) {
      const col = 1 + k;
      steps.push({ at: 140 * k, run: () => { p.clear(col - 1, 13, col - 1, 14, path); p.icon(col, 13, ART.WALKER, path); } });
    }
    return { ...timed(4000, T.FLIGHT.mountainsSpeech, ["footsteps"]), steps };
  },

  caught(p) {
    p.page(WHITE, BLUE, RED);
    p.icon(26, 2, ART.MOON, at(WHITE, BLUE));
    ridge(p, BLUE);
    p.fill(0, 13, 31, 14, at(WHITE, BLACK));
    lines(p, 17, 0, 31, T.FLIGHT.caught);
    return timed(3000, T.FLIGHT.caught.join(" "), ["caught-jig"], true);
  },

  escaped(p) {
    p.page(BLACK, YELLOW, YELLOW);
    ridge(p, YELLOW);
    p.icon(26, 13, ART.WALKER, at(BLACK, YELLOW));
    lines(p, 17, 0, 31, T.FLIGHT.escaped);
    return timed(2500, T.FLIGHT.escapedSpeech, ["escaped-whistle"]);
  },

  funeral(p, s) {
    p.page(WHITE, BLACK, BLACK);
    p.icon(14, 2, ART.WREATH, at(GREEN, BLACK));
    lines(p, 8, 0, 31, T.FUNERAL.lines(s.months));
    p.footer(T.PROMPT.any);
    return keyScreen(T.FUNERAL.speech(s.months), NEXT, ["funeral"]);
  },

  rating(p, s) {
    palace(p, T.OFFICE.reckoning);
    p.hline(66, 16, 239).hline(68, 16, 239);
    const w = 28;
    const show: Array<() => void> = [
      () => p.text(4, 2, 29, T.ledger(T.RATING.popularity, String(s.popularity), w)),
      () => p.text(5, 2, 29, T.ledger(T.RATING.months(s.months), String(s.monthsPoints), w)),
    ];
    if (s.alive) {
      show.push(() => p.text(6, 2, 29, T.ledger(T.RATING.survival, String(s.survivalBonus), w)));
      show.push(() => p.text(7, 2, 29, T.ledger(T.RATING.swiss(T.money(s.swiss)), String(s.swissPoints), w)));
    }
    show.push(() => p.big(10, 2, 29, T.RATING.total(s.total), at(YELLOW, BLUE)));
    show.push(() => p.centre(14, T.RATING.best(s.best)));
    if (s.newBest) show.push(() => { p.centre(15, T.RATING.newBest); p.icon(15, 17, ART.ROSETTE, at(YELLOW, BLUE, { bright: true })); });
    const last = show.length - 1;
    const steps: Step[] = show.map((run, i) => ({
      at: 300 * i,
      run: i === last ? () => { run(); p.footer(T.PROMPT.any); } : run,
      sound: { notes: tally(i), volume: 0.03 },
    }));
    if (s.newBest) steps.push({ at: 300 * last + 30, run: () => undefined, motif: "new-best" });
    return { offer: NEXT, mode: "key", ms: 300 * last, motifs: [], steps, speech: T.RATING.speech(s), assertive: false };
  },
};

/** Draw an engine screen; returns how it is to be presented. */
export function drawScreen(z: ZXScreen, s: Screen): Presentation {
  return (DRAW[s.kind] as Draw<typeof s.kind>)(new Painter(z), s as never);
}

// ── Extras ──────────────────────────────────────────────────────────────

export function drawTitle(z: ZXScreen): Presentation {
  const p = new Painter(z).page(WHITE, BLACK, BLACK);
  const brass = at(YELLOW, BLACK, { bright: true });
  p.fill(4, 2, 26, 2, brass).fill(4, 6, 26, 6, brass);
  for (const y of [22, 23, 48, 49]) p.hline(y, 32, 215);
  "SAMOSA".split("").forEach((ch, i) => p.bigIcon(4 + 4 * i, 3, ART.LOGO[ch], brass));
  p.centre(8, T.TITLE.tagline, at(CYAN, BLACK));
  p.icon(12, 10, ART.BALCONY, at(WHITE, BLACK));
  ART.BALCONY_ATTRS.forEach((line, r) => [...line].forEach((a, c) => {
    if (a === "Y") p.fill(12 + c, 10 + r, 12 + c, 10 + r, at(BLACK, YELLOW, { bright: true }));
  }));
  p.hline(128, 16, 239);
  p.footer(T.PROMPT.takePower, T.PROMPT.titleKeys);
  return keyScreen(T.TITLE.speech, [[ANY_KEY, T.BUTTON.play], ["h", T.BUTTON.howto], ["a", T.BUTTON.about]], ["anthem"]);
}

export function drawHowto(z: ZXScreen, page: number): Presentation {
  const p = new Painter(z);
  palace(p, T.OFFICE.howto);
  const ls = T.HOWTO_PAGES[page - 1];
  const pages = T.HOWTO_PAGES.length;
  ls.forEach((l, i) => p.text(3 + i, 1, 30, l, at(i === 0 ? YELLOW : WHITE, BLUE)));
  p.text(19, 18, 30, T.HOWTO.pageOf(page, pages), at(CYAN, BLUE), "right");
  p.footer(page < pages ? T.PROMPT.nextPage : T.PROMPT.backToTitle);
  return keyScreen(T.HOWTO.speech(page, pages, ls));
}

export function drawAbout(z: ZXScreen): Presentation {
  const p = new Painter(z);
  palace(p, T.OFFICE.about);
  lines(p, 3, 0, 31, T.ABOUT.credit, at(YELLOW, BLUE));
  p.fill(8, 9, 23, 9, at(CYAN, BLUE));
  p.hline(76, 64, 191);
  lines(p, 11, 0, 31, T.ABOUT.remake, at(WHITE, BLUE));
  p.footer(T.PROMPT.backToTitle);
  return keyScreen(T.ABOUT.speech);
}

/** Run every animation step at once (the final frame), as the contact sheet and layout tests do. */
export function finish(pr: Presentation): Presentation {
  for (const step of pr.steps) step.run();
  return pr;
}

