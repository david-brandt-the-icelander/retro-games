// The page: a canvas, the keyboard and touch buttons, and a fixed 60 Hz loop that steps the engine.
import { Game, NO_INPUT, type Input } from "../engine/game";
import { H, W } from "../engine/levels";
import { Sound } from "./audio";
import { drawStage, drawTitle } from "./render";

const canvas = document.getElementById("screen") as HTMLCanvasElement;
const ctx = canvas.getContext("2d") as CanvasRenderingContext2D;
const stage = document.getElementById("stage") as HTMLElement;
const sound = new Sound();
const touch = window.matchMedia("(pointer: coarse)").matches;

const held = new Set<string>();
const keyMap: Record<string, string> = {
  ArrowLeft: "left",
  KeyA: "left",
  ArrowRight: "right",
  KeyD: "right",
  ArrowUp: "up",
  KeyW: "up",
  ArrowDown: "down",
  KeyS: "down",
  Space: "jump",
  KeyZ: "jump",
  KeyX: "jump",
  Enter: "jump",
};

let game: Game | null = null;
let paused = false;
let high = 0;
let frame = 0;
let beat = 0;
let scale = 1;
try {
  high = Number(localStorage.getItem("kong-climb-high") ?? 0) || 0;
} catch {
  /* private mode: no stored high score */
}

function resize(): void {
  const dpr = window.devicePixelRatio || 1;
  const css = Math.min(stage.clientWidth / W, stage.clientHeight / H);
  scale = Math.max(1, Math.floor(css * dpr));
  canvas.width = W * scale;
  canvas.height = H * scale;
  canvas.style.width = `${(W * scale) / dpr}px`;
  canvas.style.height = `${(H * scale) / dpr}px`;
  ctx.imageSmoothingEnabled = false;
}
window.addEventListener("resize", resize);
resize();

function begin(): void {
  sound.unlock();
  game = new Game(Math.floor(Math.random() * 2 ** 31));
  paused = false;
}

function press(code: string, down: boolean): void {
  if (down) held.add(code);
  else held.delete(code);
  if (down) sound.unlock();
}

window.addEventListener("keydown", (e) => {
  const k = keyMap[e.code];
  if (k || e.code === "KeyP" || e.code === "KeyM" || e.code === "Escape") e.preventDefault();
  if (e.repeat) return;
  if (e.code === "KeyM") {
    sound.muted = !sound.muted;
    return;
  }
  if (!game) {
    if (k === "jump" || e.code === "Enter") begin();
    return;
  }
  if (e.code === "KeyP" || e.code === "Escape") {
    paused = !paused;
    return;
  }
  if (game.mode === "over" && game.modeT > 90 && k) {
    game = null;
    return;
  }
  if (k) press(k, true);
});
window.addEventListener("keyup", (e) => {
  const k = keyMap[e.code];
  if (k) press(k, false);
});
window.addEventListener("blur", () => {
  held.clear();
  if (game && game.mode === "play") paused = true;
});

for (const btn of document.querySelectorAll<HTMLElement>("[data-key]")) {
  const k = btn.dataset.key as string;
  const on = (e: Event) => {
    e.preventDefault();
    if (!game && k === "jump") begin();
    else if (game && game.mode === "over" && game.modeT > 90) game = null;
    else press(k, true);
    btn.classList.add("down");
  };
  const off = (e: Event) => {
    e.preventDefault();
    press(k, false);
    btn.classList.remove("down");
  };
  btn.addEventListener("pointerdown", on);
  for (const ev of ["pointerup", "pointercancel", "pointerleave"]) btn.addEventListener(ev, off);
}
canvas.addEventListener("pointerdown", () => {
  if (!game) begin();
  else if (paused) paused = false;
  else if (game.mode === "over" && game.modeT > 90) game = null;
});
document.getElementById("pause")?.addEventListener("click", () => {
  if (game) paused = !paused;
});
document.getElementById("mute")?.addEventListener("click", (e) => {
  sound.muted = !sound.muted;
  (e.currentTarget as HTMLElement).setAttribute("aria-pressed", String(sound.muted));
});

function readInput(): Input {
  return { left: held.has("left"), right: held.has("right"), up: held.has("up"), down: held.has("down"), jump: held.has("jump") };
}

function tick(): void {
  frame++;
  if (!game) return;
  if (paused) return;
  game.step(game.mode === "play" ? readInput() : NO_INPUT);
  for (const e of game.events) sound.event(e);
  if (game.mode === "play") {
    if (game.hero.moving && game.hero.state === "ground" && game.hero.anim % 10 === 0) sound.step();
    if (game.hero.hammer > 0 && game.frame % 8 === 0) sound.beep(game.frame % 16 === 0 ? 300 : 400, 0.05, "square", 0.04);
    else if (game.frame % 15 === 0) sound.music(game.kind, beat++, game.bonus <= 1000);
  }
  if (game.score > high) {
    high = game.score;
    try {
      localStorage.setItem("kong-climb-high", String(high));
    } catch {
      /* ignore */
    }
  }
}

function draw(): void {
  ctx.setTransform(scale, 0, 0, scale, 0, 0);
  if (!game) drawTitle(ctx, frame, high, touch);
  else {
    drawStage(ctx, game);
    if (paused) {
      ctx.fillStyle = "rgba(0,0,0,.6)";
      ctx.fillRect(0, 0, W, H);
      ctx.fillStyle = "#ffd84a";
      ctx.font = 'bold 14px "Courier New", monospace';
      ctx.textAlign = "center";
      ctx.fillText("PAUSED", W / 2, H / 2);
    }
  }
}

let last = performance.now();
let acc = 0;
function loop(now: number): void {
  acc += Math.min(100, now - last);
  last = now;
  while (acc >= 1000 / 60) {
    tick();
    acc -= 1000 / 60;
  }
  draw();
  requestAnimationFrame(loop);
}
requestAnimationFrame(loop);

// For tests and tinkering in the browser console.
(window as unknown as { kongClimb: unknown }).kongClimb = { get game() { return game; }, begin };
