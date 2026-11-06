// Pacing (RULES §15.5, UI-DESIGN timings) and sound (ART-BIBLE §9): every screen waits for a key;
// the screens the original moved on by itself hold for at least their old time first, then show the
// footer; and every motif matches its recipe.
import assert from "node:assert/strict";
import { test } from "node:test";
import type { Screen } from "../src/engine";
import { AUTO_ADVANCE_MS, drawScreen } from "../src/ui/screens";
import * as T from "../src/ui/text";
import { duration, MOTIF_SPECS, MOTIFS, parseRecipe, tally } from "../src/ui/sounds";
import { TICK } from "../src/zx/sound";
import { ZXScreen } from "../src/zx/screen";
import { isHeld, SCREENS } from "./samples";

const present = (s: Screen) => drawScreen(new ZXScreen(), s);

test("every motif parses into its stated number of notes and length", () => {
  for (const [id, spec] of Object.entries(MOTIF_SPECS)) {
    const notes = parseRecipe(spec.recipe);
    assert.equal(notes.length, spec.count, id);
    assert.ok(Math.abs(duration(notes) - spec.seconds) < 1e-6, `${id}: ${duration(notes)} ≠ ${spec.seconds}`);
    for (const [secs, pitch] of notes) {
      assert.ok(secs > 0);
      assert.ok(pitch === null || pitch === "noise" || (Number.isFinite(pitch) && pitch > -48 && pitch < 50), `${id} ${pitch}`);
    }
  }
});

test("recipe notation: names, ticks, rests, noise, repeats, sweeps, buzzes and pulses", () => {
  assert.deepEqual(parseRecipe("C4:0.5 A#4:0.25 G2:1 C6:0.03"), [[0.5, 0], [0.25, 10], [1, -17], [0.03, 24]]);
  assert.deepEqual(parseRecipe("T R:0.1 X:0.02 -30:0.04"), [...TICK, [0.1, null], [0.02, "noise"], [0.04, -30]]);
  assert.deepEqual(parseRecipe("(T R:0.1)x2"), [...TICK, [0.1, null], ...TICK, [0.1, null]]);
  const sweep = parseRecipe("sweep(1200,400,300,10)");
  assert.equal(sweep.length, 30);
  assert.ok(Math.abs((sweep[0][1] as number) - 12 * Math.log2(1200 / 261.63)) < 1e-9);
  assert.ok(Math.abs((sweep[29][1] as number) - 12 * Math.log2(400 / 261.63)) < 1e-9);
  assert.deepEqual(parseRecipe("buzz(-24,-22,20,60)"), [[0.02, -24], [0.02, -22], [0.02, -24]]);
  assert.equal(parseRecipe("pulse(1600,20,30,8)").length, 16);
  assert.throws(() => parseRecipe("Q9:1"));
});

test("the funeral is our own anthem slowed into G minor, 12 seconds long", () => {
  const f = MOTIFS.funeral.notes;
  assert.equal(MOTIFS.funeral.seconds, 12);
  const pitches = new Set(f.map((n) => n[1]));
  assert.ok(pitches.has(10) && pitches.has(15), "B flat and E flat");
  assert.ok(!pitches.has(11) && !pitches.has(16), "no B or E natural");
  assert.deepEqual(f.slice(4, 8).map((n) => n[1]), MOTIFS.anthem.notes.slice(0, 4).map((n) => (n[1] === 11 ? 10 : n[1])));
});

test("the rating tally climbs a whole tone per line", () => {
  assert.deepEqual([0, 1, 6].map((i) => tally(i)[0][1]), [12, 14, 24]);
});

const MINIMUM_MS: Partial<Record<Screen["kind"], number>> = {
  month: 1000, bankrupt: 5000, dialog: 5000, cashShort: 7000, mustRefuse: 5000, sectionUsed: 3000, loanWait: 1000,
  newsAlert: 6000, newsHeadline: 2000, revoltAlarm: 5000, heliFail: 3000, mountains: 4000, joke: 3000, strength: 5000,
};

const SOUND_TIMED = new Set(["reportOffer", "assassinAttempt", "assassinResult", "warThreat", "invasion", "warResult", "heliEscape", "execution", "revoltStart", "overthrown", "caught", "escaped"]);

test("held screens stay at least RULES §15.5's time, reading no key; screens timed by their sound exactly as long", () => {
  let n = 0;
  for (const s of SCREENS) {
    if (!isHeld(s)) continue;
    n++;
    const pr = present(s);
    if (SOUND_TIMED.has(s.kind)) {
      const total = pr.motifs.reduce((t, id) => t + MOTIFS[id].seconds, 0);
      assert.equal(pr.ms, Math.round(total * 1000), s.kind);
    } else {
      assert.ok(pr.ms >= MINIMUM_MS[s.kind]!, `${s.kind}: ${pr.ms}`);
    }
  }
  assert.equal(n, 31); // every formerly timed sample, the unavailable offer and unaffordable dialog included
});

test("then they show the any-key footer and wait for any key: [NEXT], and a tap counts", () => {
  for (const s of SCREENS) {
    if (!isHeld(s)) continue;
    const z = new ZXScreen();
    const pr = drawScreen(z, s);
    assert.equal(pr.mode, "key", s.kind);
    assert.deepEqual(pr.offer, [["Enter", T.BUTTON.next]], s.kind);
    assert.ok(!z.hasFooter, `${s.kind}: no footer while it holds`);
    const last = pr.steps[pr.steps.length - 1];
    assert.equal(last.at, pr.ms, s.kind);
    for (const step of pr.steps.slice(0, -1)) {
      assert.ok(step.at < pr.ms, s.kind);
      step.run();
    }
    assert.ok(!z.hasFooter, s.kind);
    last.run();
    assert.ok(z.hasFooter && z.textRows()[22].includes(T.PROMPT.any), s.kind);
    assert.ok(pr.speech.endsWith(" Press any key."), `${s.kind}: ${pr.speech}`);
  }
});

test("every screen waits for a key with a keypad offer; the others read keys at once, with their footer drawn", () => {
  for (const s of SCREENS) {
    const z = new ZXScreen();
    const pr = drawScreen(z, s);
    assert.ok(pr.offer.length > 0, s.kind);
    if (isHeld(s) || s.kind === "swiss" || s.kind === "rating") continue;
    assert.equal(pr.ms, 0, s.kind);
    assert.ok(z.hasFooter, s.kind);
  }
});

test("the screens the original timed move on by themselves 7 s after they appear; every other screen waits", () => {
  let held = 0;
  for (const s of SCREENS) {
    const pr = present(s);
    if (isHeld(s)) {
      held++;
      assert.equal(pr.autoMs, Math.max(AUTO_ADVANCE_MS, pr.ms), s.kind);
      assert.ok(pr.autoMs! >= pr.ms, `${s.kind}: never before its hold ends`);
    } else {
      assert.equal(pr.autoMs, undefined, `${s.kind} waits for its key`);
    }
  }
  assert.ok(held > 15);
  assert.equal(AUTO_ADVANCE_MS, 7000);
});

test("the help list reads only digits, and a tap there counts for nothing", () => {
  const pr = present(SCREENS.find((s) => s.kind === "helpList")!);
  assert.equal(pr.mode, "digits");
  assert.deepEqual(pr.offer.map(([k]) => k), ["1", "2", "3", "4", "5", "6"]);
});

test("keypad offers follow the UI design", () => {
  const offer = (s: Screen) => present(s).offer.map(([k, l]) => `${k}:${l}`);
  assert.deepEqual(offer({ kind: "escapeAsk" }), ["y:YES", "n:NO"]);
  assert.deepEqual(offer({ kind: "funeral", months: 3 }), ["Enter:NEXT"]);
  assert.deepEqual(offer({ kind: "menu", month: 3 }), ["1:1", "2:2", "3:3", "4:4", "5:5", "Enter:NO DECISION"]);
  const sec = SCREENS.find((s) => s.kind === "section" && s.section === 3)!;
  assert.deepEqual(offer(sec), ["1:1", "2:2", "4:4", "Enter:BACK"]);
});

test("the Swiss screen reads keys only after 2 s, when the treasury lines and footer appear", () => {
  const z = new ZXScreen();
  const pr = drawScreen(z, SCREENS.find((s) => s.kind === "swiss")!);
  assert.equal(pr.ms, 2000);
  assert.ok(!z.hasFooter && z.textRows()[12] === "");
  assert.equal(pr.steps.length, 1);
  assert.equal(pr.steps[0].at, 2000);
  pr.steps[0].run();
  assert.ok(z.hasFooter && z.textRows()[12].includes("Treasury holds"));
});

test("the rating shows a line every 300 ms with a tally, and reads keys with the last", () => {
  const z = new ZXScreen();
  const pr = drawScreen(z, SCREENS.find((s) => s.kind === "rating" && s.alive)!);
  const lines = pr.steps.filter((s) => s.sound);
  assert.deepEqual(lines.map((s) => s.at), [0, 300, 600, 900, 1200, 1500, 1800]);
  assert.equal(pr.ms, 1800);
  assert.ok(pr.ms <= 2400);
  assert.ok(pr.steps.some((s) => s.motif === "new-best"));
  const dead = drawScreen(new ZXScreen(), SCREENS.find((s) => s.kind === "rating" && !s.alive)!);
  assert.equal(dead.steps.length, 4);
  assert.ok(!dead.steps.some((s) => s.motif));
});

test("the helicopter rises a row every 0.5 s and the walker steps every 140 ms", () => {
  const heli = present({ kind: "heliEscape" });
  assert.deepEqual(heli.steps.map((s) => s.at), [500, 1000, 1500, 2000, 2500, 3000]); // the last draws the footer
  const walk = present({ kind: "mountains" });
  assert.equal(walk.steps.length, 29); // 28 steps of the walker, then the footer
  assert.equal(walk.steps[27].at, 3920);
  const news = present({ kind: "newsAlert" });
  const typing = news.steps.slice(0, -1); // the last step is the footer, at 6 s
  assert.ok(typing.every((s, i) => i === 0 || s.at > typing[i - 1].at));
  assert.ok(typing[typing.length - 1].at < 3200);
});

test("execution plays the sputter before the volley only under the helicopter heading", () => {
  assert.deepEqual(present({ kind: "execution", heliFailed: true }).motifs, ["sputter", "volley"]);
  assert.deepEqual(present({ kind: "execution", heliFailed: false }).motifs, ["volley"]);
  assert.equal(present({ kind: "execution", heliFailed: true }).ms, 4500);
});
