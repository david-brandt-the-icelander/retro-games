// Layout: every screen at its worst case stays inside the grid, its regions and clear of the footer
// and the art; flashing, footers and borders follow the UI design.
import assert from "node:assert/strict";
import { test } from "node:test";
import { newGame, playGame, SCREEN_KINDS } from "../src/engine";
import type { Screen } from "../src/engine";
import { SoundOverlay } from "../src/ui/overlay";
import { drawScreen, drawTitle, finish } from "../src/ui/screens";
import * as T from "../src/ui/text";
import { hasGlyph } from "../src/zx/font";
import { BLACK, BLUE, COLS, GREEN, RED, WHITE, WIDTH, YELLOW, ZXScreen } from "../src/zx/screen";
import { rotating } from "./helpers";
import { isHeld, LAYOUT_SAMPLES, SAMPLES, SCREENS } from "./samples";

const flashCells = (z: ZXScreen): number[] => [...z.attrs.keys()].filter((i) => z.attrs[i] & 128);
const draw = (s: Screen) => { const z = new ZXScreen(); const pr = finish(drawScreen(z, s)); return { z, pr }; };

test("no screen runs off the edge, out of its region, under the footer or into art", () => {
  const z = new ZXScreen();
  for (const s of LAYOUT_SAMPLES) {
    s.draw(z);
    assert.equal(z.clipped, 0, `${s.name}: ${JSON.stringify(z.textRows())}`);
  }
});

test("every engine kind has a sample, and the flow shows only sampled kinds", async () => {
  const sampled = new Set(SCREENS.map((s) => s.kind));
  for (const k of SCREEN_KINDS) assert.ok(sampled.has(k), `no sample for ${k}`);
  const seen = new Set<string>();
  for (let seed = 1; seed <= 300; seed++) {
    const next = rotating(seed % 2 ? ["y", "1", "n", "3", "Y", "2", "Enter", "4", "5", "6"] : ["n", "y", "2", "5"]);
    await playGame({ show: async (s) => { seen.add(s.kind); return next(s, 0); } }, newGame(seed), null);
  }
  for (const k of seen) assert.ok(sampled.has(k as never), `no sample for ${k}`);
});

test("every screen, drawn in full, has the footer, and its cursor is the only flash", () => {
  for (const s of SCREENS) {
    const { z } = draw(s);
    assert.ok(z.hasFooter, s.kind);
    const flashing = flashCells(z);
    assert.equal(flashing.length, 1, `${s.kind}: ${flashing}`);
    assert.equal(flashing[0] >> 5, 22, s.kind);
    assert.equal(z.chars[flashing[0]], "█");
    const a = z.attrAt(0, 22);
    assert.deepEqual([a.ink, a.paper, a.bright], [BLACK, WHITE, false]);
    // the perforation: every other pixel on y = 171
    assert.equal(z.pixels[171 * WIDTH], 1);
    assert.equal(z.pixels[171 * WIDTH + 1], 0);
  }
});

test("the footer prompt is centred and the cursor sits one cell after it", () => {
  const { z } = draw({ kind: "reportOffer", available: true, policeDisloyal: false, policeWeak: false, cannotPay: false, policePopularity: 9, policeStrength: 9 });
  const row = z.textRows()[22];
  const start = Math.floor((32 - T.PROMPT.yes.length) / 2);
  assert.equal(row.slice(start, start + T.PROMPT.yes.length), T.PROMPT.yes);
  assert.equal(row[start + T.PROMPT.yes.length + 1], "█");
});

test("while a held screen waits out its time, it flashes only the alarm lamp or the rifle sight, and nothing in the footer rows", () => {
  const allowed: Partial<Record<Screen["kind"], number>> = { newsAlert: 4, revoltAlarm: 4, assassinAttempt: 9 };
  for (const s of SCREENS) {
    if (!isHeld(s)) continue;
    const z = new ZXScreen();
    const pr = drawScreen(z, s);
    for (const step of pr.steps.slice(0, -1)) step.run(); // everything but the footer
    assert.equal(flashCells(z).length, allowed[s.kind] ?? 0, s.kind);
    for (let i = 21 * COLS; i < 24 * COLS; i++) assert.equal(z.chars[i], " ", `${s.kind} has text in the footer rows`);
  }
});

test("the report never flashes and marks plots in words", () => {
  const s = SCREENS.find((x) => x.kind === "report" && x.variant === "bought")!;
  const { z } = draw(s);
  const rows = z.textRows();
  assert.ok(rows[15].includes("RISE +6 SEC. POLICE"));
  assert.ok(rows[17].includes("HIRE AN ASSASSIN"));
  assert.equal(flashCells(z).length, 1); // the footer cursor only
  assert.equal(rows[6].slice(1), "1  ARMY           9     9");
  assert.equal(rows[13].slice(1), "8  WEST           9     -");
  const bar = z.attrAt(0, 15);
  assert.deepEqual([bar.ink, bar.paper, bar.bright], [BLACK, RED, true]);
});

test("debt shows a minus sign and a worded warning, not only red", () => {
  const { z } = draw({ kind: "treasury", treasury: -119, costs: 60, swiss: 0 });
  const rows = z.textRows();
  assert.ok(rows[4].endsWith("-$119,000"));
  assert.ok(rows[5].includes("IN DEBT!"));
  assert.equal(rows[9], "");
});

test("money is written in thousands with commas", () => {
  assert.equal(T.money(0), "$0");
  assert.equal(T.money(1), "$1,000");
  assert.equal(T.money(60), "$60,000");
  assert.equal(T.money(1000), "$1,000,000");
  assert.equal(T.money(-119), "-$119,000");
  assert.equal(T.money(12345), "$12,345,000");
  assert.equal(T.money(-12345).length, 12);
});

test("borders follow the colour families", () => {
  const border = (s: Screen) => draw(s).z.border;
  assert.equal(border({ kind: "treasury", treasury: 1, costs: 1, swiss: 0 }), GREEN);
  assert.equal(border({ kind: "bankrupt" }), RED);
  assert.equal(border({ kind: "assassinResult", killed: true }), BLACK);
  assert.equal(border({ kind: "assassinResult", killed: false }), RED);
  assert.equal(border({ kind: "warResult", won: true }), GREEN);
  assert.equal(border({ kind: "warResult", won: false }), RED);
  assert.equal(border({ kind: "crushed" }), YELLOW);
  assert.equal(border({ kind: "escaped" }), YELLOW);
  assert.equal(border({ kind: "month", month: 1 }), BLUE);
  const t = new ZXScreen();
  drawTitle(t);
  assert.equal(t.border, BLACK);
});

test("the advice line of the petitioners is marked in words and colour", () => {
  const { z } = draw(SCREENS.find((x) => x.kind === "advice" && x.item.type === "request")!);
  const rows = z.textRows();
  assert.equal(rows[6].slice(0, 2), "=>");
  assert.equal(z.attrAt(3, 6).ink, YELLOW);
  assert.ok(rows[20].includes("=> marks the petitioners"));
  assert.equal(rows[5].slice(26, 28), "-1");
  assert.equal(rows[6].slice(26, 28), "+4");
});

test("a used decision leaves its row empty and the others keep their numbers", () => {
  const { z } = draw(SCREENS.find((x) => x.kind === "section" && x.section === 3)!);
  const rows = z.textRows();
  assert.ok(rows[6].includes("Volunteer masked police"));
  assert.ok(rows[8].includes("More palace guards"));
  assert.equal(rows[10], "");
  assert.ok(rows[12].startsWith("  4  Half to my Swiss account"));
});

test("the sound overlay restores the cells it covered, unless the screen was redrawn", () => {
  const z = new ZXScreen();
  finish(drawScreen(z, SCREENS[0]));
  const before = { pixels: z.pixels.slice(), attrs: z.attrs.slice(), rows: z.textRows() };
  const o = new SoundOverlay(z);
  o.draw(true);
  assert.equal(z.textRows()[0].slice(21), "SOUND: ON");
  o.draw(false); // a second M keeps the first saved copy
  assert.equal(z.textRows()[0].slice(21), "SOUND: OFF");
  o.restore();
  assert.deepEqual(z.pixels, before.pixels);
  assert.deepEqual(z.attrs, before.attrs);
  assert.deepEqual(z.textRows(), before.rows);
  o.draw(true);
  drawScreen(z, { kind: "month", month: 3 });
  const redrawn = z.attrs.slice();
  o.restore();
  assert.deepEqual(z.attrs, redrawn);
});

test("every string the player sees fits 32 columns and the font", () => {
  const strings: string[] = [];
  const collect = (v: unknown): void => {
    if (typeof v === "string") strings.push(v);
    else if (Array.isArray(v)) v.forEach(collect);
    else if (typeof v === "function") collect((v as (...a: unknown[]) => unknown)(99999, 99999, [], 0));
    else if (v && typeof v === "object") Object.values(v).forEach(collect);
  };
  collect([T.LABELS, T.PROMPT, T.OFFICE, T.HOWTO_PAGES, T.ABOUT.credit, T.ABOUT.remake, T.REQUEST_TEXT, T.DECISION_LABEL, T.DECISION_TEXT, T.HEADLINE_TEXT]);
  for (const s of strings) {
    assert.ok(s.length <= 32, s);
    for (const ch of s) assert.ok(hasGlyph(ch), `no glyph for ${JSON.stringify(ch)} in ${s}`);
  }
  for (const s of SAMPLES) {
    const z = new ZXScreen();
    const pr = s.draw(z);
    for (const ch of pr.speech) assert.ok(ch.charCodeAt(0) < 128 || "£©█".includes(ch), `${s.name}: ${ch}`);
  }
});

test("every screen has screen-reader text, and alarms and deaths are assertive", () => {
  const assertive = new Set(["bankrupt", "newsAlert", "assassinAttempt", "assassinResult", "warThreat", "invasion", "warResult", "execution", "revoltAlarm", "helpList", "revoltStart", "overthrown", "caught"]);
  for (const s of SCREENS) {
    const { pr } = draw(s);
    assert.ok(pr.speech.length > 10, s.kind);
    assert.ok(!pr.speech.includes("undefined") && !pr.speech.includes("{"), `${s.kind}: ${pr.speech}`);
    assert.equal(pr.assertive, assertive.has(s.kind), s.kind);
  }
});

test("data texts fit their 30-column regions and headlines are capitals", () => {
  for (const [a, b] of T.REQUEST_TEXT) assert.ok(a.length <= 30 && b.length <= 30, a);
  for (const t of T.DECISION_TEXT) if (t) assert.ok(t[0].length <= 30 && t[1].length <= 30, t[0]);
  for (const l of T.DECISION_LABEL) assert.ok(l.length <= 27, l);
  for (const h of T.HEADLINE_TEXT) for (const l of h) { assert.ok(l.length <= 30, l); assert.equal(l, l.toUpperCase()); }
  for (const page of T.HOWTO_PAGES) { assert.ok(page.length <= 16); for (const l of page) assert.ok(l.length <= 30, l); }
});
