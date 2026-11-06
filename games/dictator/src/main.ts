// Wires the engine, the painters and the platform layer together in the browser.
import { playGame } from "./engine/flow";
import type { IO, Screen } from "./engine/screens";
import { newGame } from "./engine/state";
import { drawScreen, drawTitle } from "./ui/screens";
import { Display } from "./zx/display";
import { Input, Offer } from "./zx/input";
import { ZXScreen } from "./zx/screen";
import { Note, Sound, TICK } from "./zx/sound";

const canvas = document.getElementById("zx") as HTMLCanvasElement;
const keypad = document.getElementById("keypad")!;
const controls = document.getElementById("controls")!;
const screenText = document.getElementById("screen-text")!;
const soundButton = document.getElementById("sound") as HTMLButtonElement;

// Short landscape screens (phones on their side) put the controls beside the screen.
const sideways = matchMedia("(orientation: landscape) and (max-height: 520px)");
const screen = new ZXScreen();
const display = new Display(canvas, screen, () => (sideways.matches
  ? [innerWidth - controls.offsetWidth - 48, innerHeight - 24]
  : [innerWidth - 32, innerHeight - controls.offsetHeight - 42]));
sideways.addEventListener("change", () => display.fit());
const input = new Input(canvas, keypad);

// Per-viewer preferences, best effort (storage may be unavailable).
const load = (k: string): string | null => { try { return localStorage.getItem(k); } catch { return null; } };
const store = (k: string, v: string): void => { try { localStorage.setItem(k, v); } catch { /* this visit only */ } };

const sound = new Sound(load("sound") === "off");
const showSound = () => {
  soundButton.textContent = `SOUND: ${sound.muted ? "OFF" : "ON"} (M)`;
  soundButton.setAttribute("aria-pressed", String(!sound.muted));
};
const toggleSound = () => { sound.muted = !sound.muted; if (sound.muted) sound.stop(); store("sound", sound.muted ? "off" : "on"); showSound(); };
showSound();
soundButton.addEventListener("click", () => { sound.unlock(); toggleSound(); });
input.reserve("m", toggleSound);
input.onKey(() => { sound.unlock(); sound.play(TICK, 0.03); });

/** Show what has been drawn, mirror its text for screen readers, play its sound, and wait for a key. */
async function present(offer: Offer, tune: readonly Note[] | null = null, timeoutMs?: number): Promise<string> {
  const text = screen.textRows().map((r) => r.trim()).filter(Boolean).join("\n");
  screenText.textContent = text;
  canvas.setAttribute("aria-label", text.split("\n")[0] ?? "");
  if (tune) sound.play(tune);
  const key = input.waitKey(offer, timeoutMs);
  display.fit(); // the keypad may have wrapped onto another row
  return key;
}

const io: IO = { show: (s: Screen) => present(drawScreen(screen, s)) };

(async () => {
  for (;;) {
    await present(drawTitle(screen));
    await playGame(io, newGame());
  }
})();
