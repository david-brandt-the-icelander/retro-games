// Wires the pure game to the page: menus, the frame loop, input, sound and the scoreboard.
import { Cpu, LEVELS, type LevelName } from "./engine/ai";
import { H, W, newMatch, step, type Control, type GameEvent, type Side, type State } from "./engine/rules";
import { Input } from "./ui/input";
import { Renderer } from "./ui/render";
import { Sound } from "./ui/sound";

type Screen = "title" | "help" | "play" | "paused" | "over";

/** The simulation's fixed step, in seconds. */
const DT = 1 / 120;
/** How long the control hints stay on the table at the start of a match, in seconds. */
const HINT_TIME = 4;

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const app = $<HTMLDivElement>("app");
const canvas = $<HTMLCanvasElement>("table");
const board = $<HTMLElement>("board");
const rotate = $<HTMLElement>("rotate");
const panels: Record<Exclude<Screen, "play">, HTMLElement> = { title: $("title"), help: $("help"), paused: $("paused"), over: $("over") };
const announce = $<HTMLElement>("announce");
const soundButton = $<HTMLButtonElement>("sound");
const pauseButton = $<HTMLButtonElement>("pause");

const saved = {
  get(key: string): string | null { try { return localStorage.getItem(`rally.${key}`); } catch { return null; } },
  set(key: string, value: string): void { try { localStorage.setItem(`rally.${key}`, value); } catch { /* private mode */ } },
};

const input = new Input(canvas);
const renderer = new Renderer(canvas);
const sound = new Sound(saved.get("sound") !== "off");

let screen: Screen = "title";
let players: 1 | 2 = 1;
let level: LevelName = (["easy", "normal", "hard"] as const).find((l) => l === saved.get("level")) ?? "normal";
let match: State = newMatch(seed());
let cpu: Cpu | null = null;
let hintLeft = 0;
/** The computer-against-computer match that plays behind the menus. */
let demo = newDemo();

function seed(): number {
  return (Math.random() * 2 ** 32) >>> 0;
}

function newDemo(): { s: State; cpus: [Cpu, Cpu] } {
  const n = seed();
  return { s: newMatch(n), cpus: [new Cpu(0, LEVELS.hard, n + 1), new Cpu(1, LEVELS.normal, n + 2)] };
}

const names = (): [string, string] => (players === 1 ? ["YOU", "CPU"] : ["LEFT", "RIGHT"]);

// ——— Screens ———

function show(next: Screen): void {
  screen = next;
  for (const [name, el] of Object.entries(panels)) el.hidden = name !== next;
  document.body.classList.toggle("menu", next !== "play");
  pauseButton.hidden = next !== "play" && next !== "paused";
  pauseButton.textContent = next === "paused" ? "▶" : "II";
  pauseButton.setAttribute("aria-label", next === "paused" ? "Resume" : "Pause");
  input.reset();
  if (next !== "play") (panels[next].querySelector("button.big, button[aria-checked='true']") as HTMLButtonElement | null)?.focus();
  else (document.activeElement as HTMLElement | null)?.blur();
  updateBoard();
}

function start(n: 1 | 2): void {
  players = n;
  match = newMatch(seed());
  cpu = n === 1 ? new Cpu(1, LEVELS[level], seed()) : null;
  hintLeft = HINT_TIME;
  sound.wake();
  show("play");
  say(`${n === 1 ? "One player, " + level : "Two players"}. First to 11.`);
}

function setLevel(next: LevelName): void {
  level = next;
  saved.set("level", next);
  for (const b of panels.title.querySelectorAll<HTMLButtonElement>("[data-level]")) {
    b.setAttribute("aria-checked", String(b.dataset.level === next));
  }
}

function setSound(on: boolean): void {
  sound.on = on;
  saved.set("sound", on ? "on" : "off");
  soundButton.setAttribute("aria-pressed", String(on));
  if (on) sound.wake();
}

function updateBoard(): void {
  const s = screen === "title" || screen === "help" ? demo.s : match;
  const n = screen === "title" || screen === "help" ? ["CPU", "CPU"] : names();
  for (const side of [0, 1] as Side[]) {
    $(`name${side}`).textContent = n[side];
    $(`score${side}`).textContent = String(s.score[side]);
    $(`serve${side}`).classList.toggle("on", s.phase !== "over" && s.server === side);
  }
}

function say(text: string): void {
  announce.textContent = text;
}

function gameOver(winner: Side): void {
  const [a, b] = names();
  const title = players === 1 ? (winner === 0 ? "YOU WIN" : "CPU WINS") : `${winner === 0 ? a : b} WINS`;
  $("over-h").textContent = title;
  $("final").textContent = `${match.score[0]} – ${match.score[1]}`;
  say(`${title.toLowerCase()}, ${match.score[0]} to ${match.score[1]}.`);
  show("over");
}

// ——— The frame loop ———

function controls(): [Control, Control] {
  if (players === 2) return input.two();
  return [input.one(), cpu!.control(match, DT)];
}

function handle(events: GameEvent[]): void {
  renderer.events(events);
  for (const e of events) {
    // In a one-player game, cheer the human's points; in a two-player game, every point sounds the same.
    sound.play(e, players === 2 || ("side" in e && e.side === 0));
    if (e.kind === "point") {
      const [a, b] = names();
      say(`Point ${e.side === 0 ? a : b}. ${match.score[0]}–${match.score[1]}.`);
    }
  }
  if (events.some((e) => e.kind === "point" || e.kind === "serve")) updateBoard();
  const win = events.find((e) => e.kind === "win");
  if (win && win.kind === "win") gameOver(win.side);
}

let last = performance.now();
let acc = 0;

function frame(now: number): void {
  const dt = Math.min((now - last) / 1000, 0.25);
  last = now;

  if (screen === "play") {
    acc += dt;
    hintLeft = Math.max(0, hintLeft - dt);
    while (acc >= DT && screen === "play") {
      acc -= DT;
      handle(step(match, controls(), DT));
    }
  } else {
    acc = 0;
  }

  if (screen === "title" || screen === "help") {
    // The demo plays silently behind the menu, and starts again when it ends.
    const { s, cpus } = demo;
    for (let t = 0; t < dt; t += DT) {
      const events = step(s, [cpus[0].control(s, DT), cpus[1].control(s, DT)], DT);
      renderer.events(events);
      if (events.length) updateBoard();
    }
    if (s.phase === "over") { demo = newDemo(); updateBoard(); }
    renderer.draw(demo.s, dt, null);
  } else {
    const hints: [string, string] | null = hintLeft > 0 && screen === "play"
      ? players === 1 ? ["W / S, ↑ / ↓ or drag", ""] : ["W / S or drag here", "↑ / ↓ or drag here"]
      : null;
    renderer.draw(match, screen === "play" ? dt : 0, hints);
  }
  requestAnimationFrame(frame);
}

// ——— Layout: the largest table that fits, with the scoreboard above it ———

function layout(): void {
  const style = getComputedStyle(app);
  const padX = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
  const padY = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
  const extra = board.offsetHeight + 10 + (rotate.offsetHeight ? rotate.offsetHeight + 10 : 0);
  const width = Math.max(240, Math.min(document.documentElement.clientWidth - padX, ((window.innerHeight - padY - extra) * W) / H, 1100));
  app.style.setProperty("--w", `${Math.floor(width)}px`);
  renderer.resize(Math.floor(width));
}

// ——— Events ———

function act(action: string | undefined): void {
  sound.wake();
  switch (action) {
    case "one": start(1); break;
    case "two": start(2); break;
    case "again": start(players); break;
    case "help": show("help"); break;
    case "menu": cpu = null; demo = newDemo(); show("title"); break;
    case "resume": show("play"); break;
  }
}

document.addEventListener("click", (e) => {
  const el = (e.target as HTMLElement).closest<HTMLElement>("button");
  if (!el) return;
  if (el.dataset.level) setLevel(el.dataset.level as LevelName);
  else act(el.dataset.action);
});
soundButton.addEventListener("click", () => setSound(!sound.on));
pauseButton.addEventListener("click", () => show(screen === "paused" ? "play" : "paused"));

document.addEventListener("keydown", (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  sound.wake();
  const k = e.key.toLowerCase();
  if (k === "m") { setSound(!sound.on); return; }

  if (screen === "play") {
    if (input.key(e.code, true)) e.preventDefault();
    if (k === "p" || e.key === "Escape") { e.preventDefault(); show("paused"); }
    return;
  }
  if (screen === "paused" && (k === "p" || e.key === "Escape" || k === " ")) { e.preventDefault(); show("play"); return; }
  if (screen === "title") {
    if (k === "1") start(1);
    else if (k === "2") start(2);
    else if (k === "h") show("help");
    return;
  }
  if (screen === "help" && (e.key === "Escape" || k === "h")) { show("title"); return; }
  if (screen === "over" && e.key === "Escape") show("title");
});
document.addEventListener("keyup", (e) => { input.key(e.code, false); });

document.addEventListener("visibilitychange", () => { if (document.hidden && screen === "play") show("paused"); });
window.addEventListener("blur", () => { if (screen === "play") show("paused"); });
window.addEventListener("resize", layout);
new ResizeObserver(layout).observe(document.documentElement);
window.addEventListener("orientationchange", layout);

setLevel(level);
setSound(sound.on);
show("title");
layout();
requestAnimationFrame((now) => { last = now; frame(now); });
