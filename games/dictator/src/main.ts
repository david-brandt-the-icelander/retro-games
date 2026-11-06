// Wires the engine, the painters and the platform layer together in the browser, and runs the
// extras that live outside the engine: the title, how to play, About and the sound overlay.
import { isYes, newGame, playGame } from "./engine";
import type { IO, Screen } from "./engine";
import { SoundOverlay } from "./ui/overlay";
import { drawAbout, drawHowto, drawScores, drawScreen, drawTitle, Presentation } from "./ui/screens";
import { DEL, ENTER, keyAt, NameEntry, SKIP, TYPING_KEYS } from "./ui/entry";
import { cleanName, NAME_LENGTH, nameChar } from "./names";
import { defaultName, loadTable, Reign, saveName, startReign, submitReign } from "./scores";
import { MotifId, MOTIFS } from "./ui/sounds";
import { HOWTO_PAGES, SCORES, SOUND_SPOKEN } from "./ui/text";
import { Display } from "./zx/display";
import { Input } from "./zx/input";
import { BORDER, FULL_HEIGHT, FULL_WIDTH, ZXScreen } from "./zx/screen";
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
  // due at the same moment and scheduled first, draws the footer. Then every screen waits for a key.
  if (pr.ms > 0) await sleep(pr.ms);
  const key = await input.waitKey({ offer: pr.offer, tapCounts: pr.mode !== "digits" });
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

/** Where a tap or click lands on the paper, in Spectrum pixels; then the on-screen key there, if any. */
function tappedKey(clientX: number, clientY: number): string | null {
  const r = canvas.getBoundingClientRect();
  const x = ((clientX - r.left) / r.width) * FULL_WIDTH - BORDER;
  const y = ((clientY - r.top) / r.height) * FULL_HEIGHT - BORDER;
  return keyAt(x, y);
}

/**
 * After a reign: the player types a name (up to 12 characters, as on the old arcade tables) on the
 * screen's keyboard or their own, then the reign is sent to be replayed and the table is shown.
 */
async function offerTable(reign: Reign, score: number, keys: string[]): Promise<void> {
  let name = await defaultName();
  current++; // stop any animation of the last screen
  overlay.restore();
  const entry = new NameEntry(screen).draw(score, name).start();
  announce(SCORES.entrySpeech(score, name), true);
  for (;;) {
    const key = await input.waitKey({ typing: TYPING_KEYS, tapKey: tappedKey });
    entry.blink(key);
    if (key === SKIP) return;
    if (key === ENTER) {
      const final = cleanName(name);
      if (!final) { entry.message(SCORES.entryEmpty); announce(SCORES.entryEmpty, true); continue; }
      entry.message(SCORES.entrySending);
      const result = await submitReign(reign, keys, final);
      if (result) {
        saveName(final);
        await present(drawScores(screen, await loadTable(), { rank: result.rank, score: result.score }));
        return;
      }
      entry.message(SCORES.entryFailed);
      announce(SCORES.entryFailed, true);
      continue;
    }
    if (key === DEL || key === "Delete") name = name.slice(0, -1);
    else {
      const ch = nameChar(key);
      if (ch === null || name.length >= NAME_LENGTH) continue;
      name += ch;
    }
    entry.name(name).message("");
    announce(SCORES.entryName(name), false);
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
