// The page: runs the game at a steady 60 steps a second, draws it each animation frame at whatever size the
// screen gives it, plays its sounds, keeps the best score on this device and plays a demo when left alone.
import { autopilot } from "./engine/autopilot";
import { Game } from "./engine/game";
import { STEPS_PER_SECOND } from "./engine/rules";
import { Controls } from "./ui/input";
import { H, Renderer, W } from "./ui/render";
import { Sound } from "./ui/sound";

const BEST_KEY = "lundey.best";
const SOUND_KEY = "lundey.sound";
/** How long the title screen waits before the computer plays a demo, in steps. */
const DEMO_AFTER = 12 * STEPS_PER_SECOND;

function load(key: string): string | null { try { return localStorage.getItem(key); } catch { return null; } }
function save(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* private window */ } }

const canvas = document.getElementById("screen") as HTMLCanvasElement;
const ctx = canvas.getContext("2d")!;
const renderer = new Renderer(ctx);

const game = new Game((Math.random() * 2 ** 32) >>> 0);
game.best = Number(load(BEST_KEY)) || 0;
let savedBest = game.best;

const sound = new Sound();
sound.on = load(SOUND_KEY) !== "off";
const soundButton = document.getElementById("sound") as HTMLButtonElement;
const showSound = () => {
  soundButton.textContent = sound.on ? "SOUND ON (M)" : "SOUND OFF (M)";
  soundButton.setAttribute("aria-pressed", String(sound.on));
};
const toggleSound = () => { sound.on = !sound.on; save(SOUND_KEY, sound.on ? "on" : "off"); showSound(); };
showSound();

const controls = new Controls(document, canvas);
controls.onActivity = () => sound.unlock();
controls.onMute = toggleSound;
soundButton.addEventListener("click", (e) => { e.preventDefault(); sound.unlock(); toggleSound(); soundButton.blur(); });
document.querySelectorAll<HTMLElement>("[data-action]").forEach((el) => controls.bindButton(el, el.dataset.action!));

const playing = () => !game.demo && (game.phase === "ready" || game.phase === "play" || game.phase === "caught" || game.phase === "cleared");
// Hide the play button while a game is on, and the pause button while it is not.
const setMode = () => { document.body.dataset.phase = playing() ? "playing" : "attract"; };

// Pause when the tab is hidden, so nobody is caught while away.
document.addEventListener("visibilitychange", () => {
  if (document.hidden && !game.paused && !game.demo && (game.phase === "ready" || game.phase === "play")) controls.queuePause();
});

// The picture is drawn at the size the screen shows it, so the shapes stay sharp on any display.
let scale = 1;
function fit(): void {
  const next = Math.max(1, Math.min(8, (canvas.clientHeight * (window.devicePixelRatio || 1)) / H));
  if (Math.abs(next - scale) < 0.01 && canvas.width === Math.round(W * scale)) return;
  scale = next;
  canvas.width = Math.round(W * scale);
  canvas.height = Math.round(H * scale);
}
new ResizeObserver(fit).observe(canvas);
fit();

let idle = 0;
function step(): void {
  const input = controls.read(playing());
  if (game.demo) input.dir = autopilot(game);
  game.step(input);
  if (game.phase === "attract") {
    if (++idle >= DEMO_AFTER) { idle = 0; game.newGame(true); game.takeEvents(); }
  } else idle = 0;
  const events = game.takeEvents();
  if (!game.demo) {
    for (const e of events) sound.play(e);
    if (game.phase === "play" && !game.paused && game.mob > 0 && game.mob % 32 === 0) sound.tern();
    if (game.best > savedBest && (game.phase === "over" || game.phase === "cleared" || game.phase === "caught")) {
      savedBest = game.best;
      save(BEST_KEY, String(savedBest));
    }
  }
  setMode();
}

const STEP_MS = 1000 / STEPS_PER_SECOND;
let last = performance.now(), owed = 0;
function frame(now: number): void {
  owed += Math.min(250, now - last);
  last = now;
  while (owed >= STEP_MS) { step(); owed -= STEP_MS; }
  renderer.draw(game, scale);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);

// So the game can be looked at from the browser's console.
(window as unknown as { lundey: Game }).lundey = game;
