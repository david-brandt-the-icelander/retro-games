// Wires the engine, the painters and the platform layer together in the browser, and runs the
// extras that live outside the engine: the title, how to play, About and the sound overlay.
import { isYes, newGame, playGame } from "./engine";
import type { IO, Screen } from "./engine";
import { SoundOverlay } from "./ui/overlay";
import { drawAbout, drawEntry, drawHowto, drawScores, drawScreen, drawTitle, Presentation } from "./ui/screens";
import { loadTable, looksLikeEmail, Reign, startReign, submitReign } from "./scores";
import { MotifId, MOTIFS } from "./ui/sounds";
import { HOWTO_PAGES, SCORES, SOUND_SPOKEN } from "./ui/text";
import { Display } from "./zx/display";
import { Input } from "./zx/input";
import { ZXScreen } from "./zx/screen";
import { Sound } from "./zx/sound";

const canvas = document.getElementById("zx") as HTMLCanvasElement;
const keypad = document.getElementById("keypad")!;
const controls = document.getElementById("controls")!;
const politeText = document.getElementById("screen-text")!;
const alertText = document.getElementById("screen-alert")!;
const soundButton = document.getElementById("sound") as HTMLButtonElement;

// Short landscape screens (phones on their side) put the controls beside the screen.
const sideways = matchMedia("(orientation: landscape) and (max-height: 520px)");
const screen = new ZXScreen();
const display = new Display(canvas, screen, () => (sideways.matches
  ? [innerWidth - controls.offsetWidth - 48, innerHeight - 24]
  : [innerWidth - 32, innerHeight - controls.offsetHeight - 42]));
sideways.addEventListener("change", () => display.fit());
const input = new Input(canvas, keypad);

// The browser's storage, best effort: it may be blocked (private browsing), and the game still runs.
const BEST_KEY = "samosa.best", SOUND_KEY = "samosa.sound";
const load = (k: string): string | null => { try { return localStorage.getItem(k); } catch { return null; } };
const store = (k: string, v: string): void => { try { localStorage.setItem(k, v); } catch { /* this visit only */ } };
function loadBest(): number | null {
  const v = load(BEST_KEY);
  if (v === null) return null;
  const n = Number(v);
  return Number.isFinite(n) && n >= 0 ? Math.floor(n) : null;
}

// ── Sound ────────────────────────────────────────────────────────────────

const sound = new Sound(load(SOUND_KEY) === "off");
const overlay = new SoundOverlay(screen);
let overlayTimer: ReturnType<typeof setTimeout> | undefined;
/** The anthem is owed to the title screen until audio can play it. */
let anthemOwed = false;

function playMotifs(ids: readonly MotifId[]): void {
  let delay = 0;
  ids.forEach((id, i) => {
    const m = MOTIFS[id];
    sound.play(m.notes, m.volume, i === 0, delay);
    delay += m.seconds;
  });
}

function announce(text: string, assertive: boolean): void {
  politeText.textContent = text;
  alertText.textContent = assertive ? text : "";
}

const showSoundButton = () => {
  soundButton.textContent = `SOUND: ${sound.muted ? "OFF" : "ON"} (M)`;
  soundButton.setAttribute("aria-pressed", String(!sound.muted));
};

function toggleSound(): void {
  sound.unlock();
  sound.muted = !sound.muted;
  if (sound.muted) sound.stop();
  store(SOUND_KEY, sound.muted ? "off" : "on");
  showSoundButton();
  overlay.draw(!sound.muted);
  clearTimeout(overlayTimer);
  overlayTimer = setTimeout(() => overlay.restore(), 1500);
  politeText.textContent = SOUND_SPOKEN(!sound.muted);
  if (anthemOwed && !sound.muted) { anthemOwed = false; playMotifs(["anthem"]); }
}

showSoundButton();
soundButton.addEventListener("click", toggleSound);
input.reserve("m", toggleSound);
input.onKey((key) => {
  sound.unlock();
  const blip = MOTIFS[isYes(key) ? "answer-yes" : "answer-blip"];
  sound.play(blip.notes, blip.volume, false);
});

// ── Presenting a screen ──────────────────────────────────────────────────

/** Bumped by every new screen, so the animation steps of the last one stop. */
let current = 0;
const sleep = (ms: number) => new Promise<void>((r) => setTimeout(r, ms));

/** Show what has been drawn: announce it, play its sound, run its animation and read its key. */
async function present(pr: Presentation, motifs: readonly MotifId[] = pr.motifs): Promise<string> {
  const id = ++current;
  overlay.restore();
  announce(pr.speech, pr.assertive);
  playMotifs(motifs);
  for (const step of pr.steps) {
    setTimeout(() => {
      if (id !== current) return;
      step.run();
      if (step.sound) sound.play(step.sound.notes, step.sound.volume, false);
      if (step.motif) playMotifs([step.motif]);
    }, step.at);
  }
  input.idle();
  // A screen holds for pr.ms reading no key (keys pressed meanwhile are dropped); its last step,
  // due at the same moment and scheduled first, draws the footer. Then it waits for a key; a screen
  // the original moved on by itself (pr.autoMs) moves on by itself too, 7 s after it appeared.
  if (pr.ms > 0) await sleep(pr.ms);
  const timeoutMs = pr.autoMs === undefined ? undefined : pr.autoMs - pr.ms;
  const key = await input.waitKey({ offer: pr.offer, tapCounts: pr.mode !== "digits", timeoutMs });
  display.fit(); // the keypad may have wrapped onto another row
  return key;
}

/** Every key the engine receives, in order: the server replays a reign from its seed and these. */
let keyLog: string[] = [];
const io: IO = {
  show: async (s: Screen) => {
    const key = await present(drawScreen(screen, s));
    keyLog.push(key);
    return key;
  },
};

// ── The high-score table ─────────────────────────────────────────────────

/** An HTML form below the screen for the player's email. Resolves with the address, or null to skip. */
function askEmail(error = ""): Promise<string | null> {
  return new Promise((resolve) => {
    const form = document.createElement("form");
    form.className = "entry";
    form.noValidate = true;
    const label = document.createElement("label");
    label.htmlFor = "entry-email";
    label.textContent = SCORES.formLabel;
    const field = document.createElement("input");
    Object.assign(field, { id: "entry-email", type: "email", autocomplete: "email", required: true, maxLength: 254, spellcheck: false });
    const note = document.createElement("p");
    note.className = "entry-note";
    note.textContent = SCORES.formNote;
    const message = document.createElement("p");
    message.className = "entry-error";
    message.setAttribute("role", "alert");
    message.textContent = error;
    const submit = document.createElement("button");
    submit.type = "submit";
    submit.textContent = SCORES.formSubmit;
    const skip = document.createElement("button");
    skip.type = "button";
    skip.textContent = SCORES.formSkip;
    const buttons = document.createElement("div");
    buttons.className = "entry-buttons";
    buttons.append(submit, skip);
    form.append(label, field, message, buttons, note);
    const done = (value: string | null) => { form.remove(); keypad.hidden = false; display.fit(); resolve(value); };
    // Typing in the form must never reach the game's keys (M would toggle the sound).
    form.addEventListener("keydown", (e) => { e.stopPropagation(); if (e.key === "Escape") done(null); });
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const email = field.value.trim();
      if (!looksLikeEmail(email)) { message.textContent = SCORES.formInvalid; field.focus(); return; }
      done(email);
    });
    skip.addEventListener("click", () => done(null));
    keypad.hidden = true;
    controls.prepend(form);
    display.fit();
    field.focus();
  });
}

/** After a reign: offer the table, send the reign to be replayed, then show the table. */
async function offerTable(reign: Reign, score: number, keys: string[]): Promise<void> {
  const pr = drawEntry(screen, score);
  overlay.restore();
  announce(pr.speech, pr.assertive);
  let error = "";
  for (;;) {
    const email = await askEmail(error);
    if (email === null) return;
    const entry = await submitReign(reign, keys, email);
    if (entry) {
      await present(drawScores(screen, await loadTable(), { rank: entry.rank, score: entry.score }));
      return;
    }
    error = SCORES.formFailed;
  }
}

// ── The extras and the game loop ─────────────────────────────────────────

async function title(fresh: boolean): Promise<void> {
  for (;;) {
    const pr = drawTitle(screen);
    anthemOwed = fresh && (!sound.unlocked || sound.muted);
    const key = (await present(pr, fresh && !anthemOwed ? pr.motifs : [])).toLowerCase();
    anthemOwed = false;
    fresh = false;
    if (key === "h") {
      for (let page = 1; page <= HOWTO_PAGES.length; page++) await present(drawHowto(screen, page));
    } else if (key === "a") {
      await present(drawAbout(screen));
    } else if (key === "s") {
      await present(drawScores(screen, await loadTable()));
    } else return;
  }
}

(async () => {
  for (;;) {
    await title(true);
    const reign = await startReign(); // null when offline: the reign plays, but can't be entered
    keyLog = [];
    const outcome = await playGame(io, newGame(reign?.seed), loadBest());
    store(BEST_KEY, String(outcome.best));
    if (reign) await offerTable(reign, outcome.score, keyLog);
  }
})();
