// The browser side: screens, the frame loop, and wiring input, sound and drawing to the engine.
import { DT, MAX_PLAYERS } from "./engine/config";
import { newGame, standings, step, type Controls, type Game } from "./engine/game";
import { Input, deviceLabel, fireDevice, menuAct, type Device, type Press } from "./input";
import { MENU_ITEMS, Renderer, inRect, menuRect } from "./render";
import { addScore, loadScores, qualifies } from "./scores";
import { Sound } from "./sound";

type Scene =
  | { kind: "title"; sel: number }
  | { kind: "lobby"; mode: "coop" | "versus"; devices: Device[] }
  | { kind: "play"; game: Game; devices: Device[]; paused: boolean }
  | { kind: "over"; game: Game; devices: Device[]; t: number }
  | { kind: "entry"; game: Game; devices: Device[]; queue: number[]; letters: string[]; pos: number };

const canvas = document.getElementById("game") as HTMLCanvasElement;
const touchPad = document.getElementById("touch") as HTMLElement;
const soundButton = document.getElementById("sound") as HTMLButtonElement;
const pauseButton = document.getElementById("pause") as HTMLButtonElement;
const live = document.getElementById("live") as HTMLElement;

const renderer = new Renderer(canvas);
const input = new Input(window);
const sound = new Sound();
let scores = loadScores();
let scene: Scene = { kind: "title", sel: 0 };
const seed = () => (Math.random() * 2 ** 32) >>> 0;
let attract = newGame("attract", 0, seed());
let clock = 0;

const say = (text: string) => { live.textContent = text; };
const best = () => scores[0]?.score ?? 0;
const touchMode = () => input.touchSeen || matchMedia("(pointer: coarse)").matches;

function showTouch(): void {
  touchPad.hidden = !touchMode();
}

function updateButtons(): void {
  soundButton.textContent = sound.muted ? "SOUND: OFF (M)" : "SOUND: ON (M)";
  soundButton.setAttribute("aria-pressed", String(!sound.muted));
  pauseButton.hidden = scene.kind !== "play";
  pauseButton.textContent = scene.kind === "play" && scene.paused ? "RESUME (P)" : "PAUSE (P)";
}

function toTitle(): void {
  scene = { kind: "title", sel: 0 };
  renderer.clearEffects();
  say("Shatterbelt. Choose co-op or versus.");
  updateButtons();
}

function toLobby(mode: "coop" | "versus"): void {
  scene = { kind: "lobby", mode, devices: [] };
  say(`${mode === "versus" ? "Versus" : "Co-op"}. Each player presses their fire key or button to join, then Space or Start to launch.`);
}

function join(devices: Device[], d: Device): void {
  if (devices.length < MAX_PLAYERS && !devices.includes(d)) {
    devices.push(d);
    say(`Player ${devices.length} joined with ${deviceLabel(d)}.`);
  }
}

function launch(mode: "coop" | "versus", devices: Device[]): void {
  if (devices.length === 0) devices.push("kb");
  // A lone keyboard player may use every key set.
  const keyboards = devices.filter((d) => d.startsWith("kb"));
  if (keyboards.length === 1) devices[devices.indexOf(keyboards[0])] = "kb";
  const game = newGame(mode, devices.length, seed());
  scene = { kind: "play", game, devices, paused: false };
  renderer.clearEffects();
  say(`${devices.length} ${devices.length === 1 ? "player" : "players"}, ${mode === "versus" ? "versus" : "co-op"}. Go.`);
  updateButtons();
}

function setPaused(on: boolean): void {
  if (scene.kind !== "play" || scene.paused === on) return;
  scene.paused = on;
  input.release();
  say(on ? "Paused." : "Resumed.");
  updateButtons();
}

function afterGame(game: Game, devices: Device[]): void {
  const queue = standings(game).filter((s) => qualifies(scores, s.score)).map((s) => s.id);
  if (queue.length) {
    scene = { kind: "entry", game, devices, queue, letters: ["A", "A", "A"], pos: 0 };
    say(`Player ${queue[0] + 1}, new best score. Type your initials and press Enter.`);
  } else toTitle();
}

function saveEntry(s: Extract<Scene, { kind: "entry" }>): void {
  const id = s.queue.shift()!;
  const ship = s.game.ships[id];
  scores = addScore(scores, {
    name: s.letters.join(""), score: ship.score, wave: s.game.wave,
    mode: s.game.mode === "versus" ? "versus" : "coop", players: s.game.ships.length,
  });
  while (s.queue.length && !qualifies(scores, s.game.ships[s.queue[0]].score)) s.queue.shift();
  if (s.queue.length) {
    s.letters = ["A", "A", "A"];
    s.pos = 0;
    say(`Player ${s.queue[0] + 1}, new best score. Type your initials.`);
  } else toTitle();
}

const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ";
function cycle(letter: string, by: number): string {
  const i = LETTERS.indexOf(letter);
  return LETTERS[(i + by + LETTERS.length) % LETTERS.length];
}

function handle(p: Press): void {
  sound.unlock();
  const act = menuAct(p);
  switch (scene.kind) {
    case "title": {
      if (act === "mute") break;
      if (act === "up" || act === "left") scene.sel = (scene.sel + MENU_ITEMS.length - 1) % MENU_ITEMS.length;
      else if (act === "down" || act === "right") scene.sel = (scene.sel + 1) % MENU_ITEMS.length;
      else if (act === "ok" || act === "start" || fireDevice(p)) toLobby(scene.sel === 0 ? "coop" : "versus");
      break;
    }
    case "lobby": {
      const d = fireDevice(p);
      if (d) join(scene.devices, d);
      else if (act === "start") {
        const pad = /^(pad\d+):/.exec(p.code);
        if (pad && scene.devices.length === 0) join(scene.devices, pad[1]);
        launch(scene.mode, scene.devices);
      } else if (act === "back") toTitle();
      break;
    }
    case "play": {
      if (act === "pause" || (act === "start" && p.code !== "Space")) setPaused(!scene.paused);
      else if (p.code === "Escape") scene.paused ? toTitle() : setPaused(true);
      else if (scene.paused && /^pad\d+:back$/.test(p.code)) toTitle();
      break;
    }
    case "over": {
      if (scene.t > 1.2 && (act === "ok" || act === "start" || fireDevice(p))) afterGame(scene.game, scene.devices);
      break;
    }
    case "entry": {
      const letter = /^(?:Key|Digit)([A-Z0-9])$/.exec(p.code);
      if (letter) {
        scene.letters[scene.pos] = letter[1];
        scene.pos = Math.min(2, scene.pos + 1);
      } else if (act === "erase" || act === "back") scene.pos = Math.max(0, scene.pos - 1);
      else if (act === "up" || act === "right") scene.letters[scene.pos] = cycle(scene.letters[scene.pos], 1);
      else if (act === "down" || act === "left") scene.letters[scene.pos] = cycle(scene.letters[scene.pos], -1);
      else if (p.code === "Enter" || p.code === "NumpadEnter" || p.code === "Space" || act === "start") saveEntry(scene);
      else if (act === "ok") {
        if (scene.pos < 2) scene.pos++;
        else saveEntry(scene);
      }
      return; // M is a letter here
    }
  }
  if (act === "mute") {
    sound.toggle();
    updateButtons();
  }
}

function tick(): void {
  renderer.update(DT);
  switch (scene.kind) {
    case "title":
    case "lobby":
      step(attract);
      renderer.absorb(attract.events, attract);
      break;
    case "play": {
      if (scene.paused) break;
      const g = scene.game;
      const inputs: Controls[] = scene.devices.map((d) => input.controls(d));
      step(g, inputs);
      renderer.absorb(g.events, g);
      renderer.trails(g);
      sound.play(g.events);
      for (const e of g.events) if (e.type === "wave") say(`Wave ${e.n}.`);
      if (g.over) {
        const ranked = standings(g);
        scene = { kind: "over", game: g, devices: scene.devices, t: 0 };
        say(`Game over. ${ranked.map((s) => `Player ${s.id + 1}: ${s.score}`).join(", ")}.`);
        updateButtons();
      }
      break;
    }
    case "over":
    case "entry":
      step(scene.game);
      renderer.absorb(scene.game.events, scene.game);
      if (scene.kind === "over") scene.t += DT;
      break;
  }
}

function draw(): void {
  renderer.begin();
  switch (scene.kind) {
    case "title":
      renderer.world(attract, clock);
      renderer.title(scene.sel, clock, scores, touchMode());
      break;
    case "lobby":
      renderer.world(attract, clock);
      renderer.lobby(scene.mode, scene.devices, scene.devices.map(deviceLabel), clock, touchMode());
      break;
    case "play":
      renderer.world(scene.game, clock);
      renderer.hud(scene.game, best());
      if (scene.paused) renderer.paused();
      break;
    case "over":
      renderer.world(scene.game, clock);
      renderer.gameOver(scene.game, scene.t);
      break;
    case "entry": {
      const id = scene.queue[0];
      renderer.world(scene.game, clock);
      renderer.entry(id, scene.game.ships[id].score, scene.letters, scene.pos, clock);
      break;
    }
  }
}

let last = performance.now();
let acc = 0;
function frame(now: number): void {
  const dt = Math.min(0.25, (now - last) / 1000);
  last = now;
  clock += dt;
  input.poll();
  for (const p of input.drain()) handle(p);
  acc += dt;
  while (acc >= DT) {
    acc -= DT;
    tick();
  }
  sound.follow(scene.kind === "play" && !scene.paused ? scene.game : null);
  draw();
  requestAnimationFrame(frame);
}

// Taps on the canvas: menu items, launching, continuing.
canvas.addEventListener("pointerdown", (e) => {
  sound.unlock();
  if (e.pointerType === "touch") {
    input.touchSeen = true;
    showTouch();
  }
  const { x, y } = renderer.toField(e.clientX, e.clientY);
  if (scene.kind === "title") {
    MENU_ITEMS.forEach((_, i) => {
      if (inRect(menuRect(i), x, y)) {
        scene = { kind: "title", sel: i };
        toLobby(i === 0 ? "coop" : "versus");
      }
    });
  } else if (scene.kind === "lobby") {
    if (scene.devices.length === 0 && e.pointerType === "touch") join(scene.devices, "touch");
    if (scene.devices.length > 0) launch(scene.mode, scene.devices);
  } else if (scene.kind === "over" && scene.t > 1.2) afterGame(scene.game, scene.devices);
});

// The on-screen buttons for phones and tablets.
for (const b of touchPad.querySelectorAll<HTMLButtonElement>("button[data-ctl]")) {
  const ctl = b.dataset.ctl as keyof Controls | "pause";
  const on = (e: PointerEvent) => {
    e.preventDefault();
    sound.unlock();
    b.setPointerCapture(e.pointerId);
    b.classList.add("on");
    input.setTouch(ctl, true);
  };
  const off = () => {
    b.classList.remove("on");
    input.setTouch(ctl, false);
  };
  b.addEventListener("pointerdown", on);
  b.addEventListener("pointerup", off);
  b.addEventListener("pointercancel", off);
  b.addEventListener("lostpointercapture", off);
  b.addEventListener("contextmenu", (e) => e.preventDefault());
}

soundButton.addEventListener("click", () => {
  sound.unlock();
  sound.toggle();
  updateButtons();
  soundButton.blur();
});
pauseButton.addEventListener("click", () => {
  if (scene.kind === "play") setPaused(!scene.paused);
  pauseButton.blur();
});

// Leaving the tab or window pauses the game; held keys would never see their keyup.
window.addEventListener("blur", () => {
  input.release();
  setPaused(true);
});
document.addEventListener("visibilitychange", () => {
  if (document.hidden) setPaused(true);
});
window.addEventListener("resize", () => renderer.fit());
window.addEventListener("touchstart", () => {
  input.touchSeen = true;
  showTouch();
}, { passive: true, once: true });

showTouch();
updateButtons();
toTitle();
requestAnimationFrame(frame);
