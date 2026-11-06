// The page: runs the game at a steady 60 steps a second, draws it each animation frame, and plays its sounds.
import { Game } from "./engine/game";
import { H, W } from "./engine/rules";
import { Controls } from "./ui/input";
import { render } from "./ui/render";
import { Sound } from "./ui/sound";

const HI_KEY = "hivestorm.hiscore";
const SOUND_KEY = "hivestorm.sound";

function load(key: string): string | null { try { return localStorage.getItem(key); } catch { return null; } }
function save(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* private window */ } }

const canvas = document.getElementById("screen") as HTMLCanvasElement;
canvas.width = W;
canvas.height = H;
const ctx = canvas.getContext("2d")!;

const game = new Game();
game.hiScore = Number(load(HI_KEY)) || 0;
let savedHi = game.hiScore;

const sound = new Sound();
sound.on = load(SOUND_KEY) !== "off";
const soundButton = document.getElementById("sound") as HTMLButtonElement;
const showSound = () => {
  soundButton.textContent = sound.on ? "SOUND ON (M)" : "SOUND OFF (M)";
  soundButton.setAttribute("aria-pressed", String(sound.on));
};
const toggleSound = () => { sound.on = !sound.on; save(SOUND_KEY, sound.on ? "on" : "off"); showSound(); };
showSound();

const controls = new Controls(document);
controls.onActivity = () => sound.unlock();
controls.onMute = toggleSound;
soundButton.addEventListener("click", (e) => { e.preventDefault(); sound.unlock(); toggleSound(); soundButton.blur(); });
document.querySelectorAll<HTMLElement>("[data-action]").forEach((el) => controls.bindButton(el, el.dataset.action!));

// Hide the start buttons while a game is on, and the pause button while it is not.
const setMode = () => { document.body.dataset.phase = game.phase === "attract" ? "attract" : "playing"; };

// Pause when the tab is hidden, so nobody dies while away.
document.addEventListener("visibilitychange", () => {
  if (document.hidden && !game.paused && game.phase !== "attract" && game.phase !== "gameOver") {
    game.step({ left: false, right: false, fire: false, start1: false, start2: false, pause: true });
  }
});

const STEP = 1000 / 60;
let last = performance.now();
let acc = 0;
function frame(now: number): void {
  acc = Math.min(acc + (now - last), 250);
  last = now;
  while (acc >= STEP) {
    for (const e of game.step(controls.read())) sound.play(e);
    acc -= STEP;
  }
  if (game.hiScore !== savedHi) { savedHi = game.hiScore; save(HI_KEY, String(savedHi)); }
  setMode();
  render(ctx, game);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
