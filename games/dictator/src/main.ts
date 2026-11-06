// Wires the engine, the painters and the platform layer together in the browser, and runs the
// extras that live outside the engine: the title, how to play, About and the sound overlay.
import { isYes, newGame, playGame } from "./engine";
import type { IO, Screen } from "./engine";
import { SoundOverlay } from "./ui/overlay";
import { drawAbout, drawHowto, drawScreen, drawTitle, Presentation } from "./ui/screens";
import { MotifId, MOTIFS } from "./ui/sounds";
import { HOWTO_PAGES, SOUND_SPOKEN } from "./ui/text";
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
  if (pr.ms > 0) await sleep(pr.ms); // timed screens, and the first part of swiss and rating, read no key
  if (pr.mode === "timed") return "";
  const key = await input.waitKey({ offer: pr.offer, tapCounts: pr.mode !== "digits" });
  display.fit(); // the keypad may have wrapped onto another row
  return key;
}

const io: IO = { show: (s: Screen) => present(drawScreen(screen, s)) };

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
    } else return;
  }
}

(async () => {
  for (;;) {
    await title(true);
    const outcome = await playGame(io, newGame(), loadBest());
    store(BEST_KEY, String(outcome.best));
  }
})();
