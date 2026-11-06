// The browser side: screens, the frame loop, and wiring input, sound and drawing to the engine.
import { DT, MAX_PLAYERS } from "./engine/config";
import { newGame, standings, step, type Controls, type Game } from "./engine/game";
import { Recorder, type Recording } from "./engine/replay";
import { Input, deviceLabel, fireDevice, menuAct, type Device, type Press } from "./input";
import { MENU_ITEMS, Renderer, inRect, menuRect } from "./render";
import { addScore, loadScores, qualifies, TABLE_SIZE } from "./scores";
import { NAME_MAX, cleanName } from "./name";
import { loadPublic, startGame, submitGame, type PublicRow, type Result, type Ticket } from "./net";
import { Sound } from "./sound";

type Scene =
  | { kind: "title"; sel: number }
  | { kind: "lobby"; mode: "coop" | "versus"; devices: Device[]; launching: boolean }
  | { kind: "play"; game: Game; devices: Device[]; paused: boolean; rec: Recorder; ticket: Ticket | null }
  | { kind: "over"; game: Game; rec: Recorder; ticket: Ticket | null; t: number }
  | { kind: "entry"; game: Game; id: number; ranked: boolean }
  | { kind: "saving"; game: Game }
  | { kind: "saved"; game: Game; results: Result[] | null; t: number };

/** A finished game on its way to the tables. */
type Finished = { game: Game; rec: Recorder; ticket: Ticket | null };

const canvas = document.getElementById("game") as HTMLCanvasElement;
const touchPad = document.getElementById("touch") as HTMLElement;
const soundButton = document.getElementById("sound") as HTMLButtonElement;
const pauseButton = document.getElementById("pause") as HTMLButtonElement;
const stage = document.getElementById("stage") as HTMLElement;
const live = document.getElementById("live") as HTMLElement;

const renderer = new Renderer(canvas);
const input = new Input(window);
const sound = new Sound();
let scores = loadScores();
/** The public table's top rows, once loaded (null while unknown or unreachable). */
let publicRows: PublicRow[] | null = null;
const refreshPublic = () => loadPublic().then((rows) => { if (rows) publicRows = rows; });
let scene: Scene = { kind: "title", sel: 0 };
const seed = () => (Math.random() * 2 ** 32) >>> 0;
let attract = newGame("attract", 0, seed());
let clock = 0;

const say = (text: string) => { live.textContent = text; };
const best = () => Math.max(scores[0]?.score ?? 0, publicRows?.[0]?.score ?? 0);
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
  scene = { kind: "lobby", mode, devices: [], launching: false };
  say(`${mode === "versus" ? "Versus" : "Co-op"}. Each player presses their fire key or button to join, then Space or Start to launch.`);
}

function join(devices: Device[], d: Device): void {
  if (devices.length < MAX_PLAYERS && !devices.includes(d)) {
    devices.push(d);
    say(`Player ${devices.length} joined with ${deviceLabel(d)}.`);
  }
}

async function launch(): Promise<void> {
  if (scene.kind !== "lobby" || scene.launching) return;
  const lobby = scene;
  const { mode, devices } = lobby;
  if (devices.length === 0) devices.push("kb");
  // A lone keyboard player may use every key set.
  const keyboards = devices.filter((d) => d.startsWith("kb"));
  if (keyboards.length === 1) devices[devices.indexOf(keyboards[0])] = "kb";
  lobby.launching = true;
  say("Launching.");
  // The server issues the seed, so that it can replay the game for the public table.
  // Without it the game still plays, and its scores stay on this device.
  const ticket = await startGame();
  if (scene !== lobby) return; // backed out while waiting
  const game = newGame(mode, devices.length, ticket ? ticket.seed : seed());
  scene = { kind: "play", game, devices, paused: false, rec: new Recorder(devices.length), ticket };
  renderer.clearEffects();
  say(`${devices.length} ${devices.length === 1 ? "player" : "players"}, ${mode === "versus" ? "versus" : "co-op"}.${ticket ? "" : " Offline: scores stay on this device."} Go.`);
  updateButtons();
}

function setPaused(on: boolean): void {
  if (scene.kind !== "play" || scene.paused === on) return;
  scene.paused = on;
  input.release();
  say(on ? "Paused." : "Resumed.");
  updateButtons();
}

/** Would this score show in the public table's top ten? (Unknown table: assume yes.) */
function onPublicTable(score: number): boolean {
  if (score <= 0) return false;
  if (!publicRows) return true;
  return publicRows.length < TABLE_SIZE || score > publicRows[TABLE_SIZE - 1].score;
}

/** An HTML form over the screen for a player's name. Resolves with the cleaned name, or null to skip. */
function askName(label: string): Promise<string | null> {
  return new Promise((resolve) => {
    const form = document.createElement("form");
    form.className = "entry";
    form.noValidate = true;
    const caption = document.createElement("label");
    caption.htmlFor = "entry-name";
    caption.textContent = label;
    const field = document.createElement("input");
    // A name, not an account: tell browsers and password managers to stay out of it.
    Object.assign(field, { id: "entry-name", name: "player-name", type: "text", autocomplete: "off", required: true, maxLength: NAME_MAX * 2, spellcheck: false });
    for (const [k, v] of [["data-1p-ignore", ""], ["data-lpignore", "true"], ["data-bwignore", ""], ["data-form-type", "other"], ["autocapitalize", "words"]]) field.setAttribute(k, v);
    const message = document.createElement("p");
    message.className = "entry-error";
    message.setAttribute("role", "alert");
    const submit = document.createElement("button");
    submit.type = "submit";
    submit.textContent = "SAVE";
    const skip = document.createElement("button");
    skip.type = "button";
    skip.textContent = "SKIP";
    const buttons = document.createElement("div");
    buttons.className = "entry-buttons";
    buttons.append(submit, skip);
    const note = document.createElement("p");
    note.className = "entry-note";
    note.textContent = `Up to ${NAME_MAX} letters or digits. Only the name is kept. Esc skips.`;
    form.append(caption, field, message, buttons, note);
    const done = (value: string | null) => {
      form.remove();
      document.body.classList.remove("entering");
      canvas.focus();
      resolve(value);
    };
    // Typing in the form must never reach the game's keys (M would toggle the sound, P would pause).
    form.addEventListener("keydown", (e) => { e.stopPropagation(); if (e.key === "Escape") done(null); });
    form.addEventListener("keyup", (e) => e.stopPropagation());
    form.addEventListener("submit", (e) => {
      e.preventDefault();
      const name = cleanName(field.value);
      if (!name) { message.textContent = "Please type a name with at least one letter or digit."; field.focus(); return; }
      done(name);
    });
    skip.addEventListener("click", () => done(null));
    document.body.classList.add("entering");
    input.release();
    stage.append(form);
    field.focus();
  });
}

/** After the game-over screen: a name from everyone who made a table, then the public table. */
async function afterGame({ game, rec, ticket }: Finished): Promise<void> {
  const queue = standings(game)
    .filter((s) => (ticket && onPublicTable(s.score)) || qualifies(scores, s.score))
    .map((s) => s.id);
  const names: (string | null)[] = game.ships.map(() => null);
  for (const id of queue) {
    const ship = game.ships[id];
    scene = { kind: "entry", game, id, ranked: ticket !== null };
    say(`Player ${id + 1}, a new high score: ${ship.score}. Type your name for the high-score table.`);
    const name = await askName(`P${id + 1}, ${ship.score.toLocaleString("en-US")} points. Your name for the high-score table:`);
    names[id] = name;
    if (name && qualifies(scores, ship.score)) {
      scores = addScore(scores, {
        name, score: ship.score, wave: game.wave,
        mode: game.mode === "versus" ? "versus" : "coop", players: game.ships.length,
      });
    }
  }
  if (!ticket || names.every((n) => n === null)) return toTitle();
  await submit(game, rec, ticket, names);
}

/** Sends the game to the server, which replays it and lists the named players. */
async function submit(game: Game, rec: Recorder, ticket: Ticket, names: (string | null)[]): Promise<void> {
  const recording: Recording = {
    mode: game.mode === "versus" ? "versus" : "coop", players: game.ships.length,
    seed: 0, steps: rec.steps, log: rec.log,
  };
  scene = { kind: "saving", game };
  say("Saving scores.");
  const results = await submitGame(ticket, recording, names);
  if (results) await refreshPublic();
  scene = { kind: "saved", game, results, t: 0 };
  say(results
    ? results.filter((r) => r.rank).map((r) => `Player ${r.player + 1}, ${r.name}: ${r.score}, number ${r.rank} of all pilots.`).join(" ")
    : "The score server could not be reached. Your scores are kept on this device.");
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
      if (scene.launching) break;
      const d = fireDevice(p);
      if (d) join(scene.devices, d);
      else if (act === "start") {
        const pad = /^(pad\d+):/.exec(p.code);
        if (pad && scene.devices.length === 0) join(scene.devices, pad[1]);
        void launch();
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
      if (scene.t > 1.2 && (act === "ok" || act === "start" || fireDevice(p))) void afterGame(scene);
      break;
    }
    case "saving":
      return;
    case "saved": {
      if (scene.t > 0.8 && (act === "ok" || act === "start" || act === "back" || fireDevice(p))) toTitle();
      return;
    }
    case "entry":
      return; // the name form has the keyboard
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
      scene.rec.record(inputs);
      step(g, inputs);
      renderer.absorb(g.events, g);
      renderer.trails(g);
      sound.play(g.events);
      for (const e of g.events) if (e.type === "wave") say(`Wave ${e.n}.`);
      if (g.over) {
        const ranked = standings(g);
        scene = { kind: "over", game: g, rec: scene.rec, ticket: scene.ticket, t: 0 };
        say(`Game over. ${ranked.map((s) => `Player ${s.id + 1}: ${s.score}`).join(", ")}.`);
        updateButtons();
      }
      break;
    }
    case "over":
    case "entry":
    case "saving":
    case "saved":
      step(scene.game);
      renderer.absorb(scene.game.events, scene.game);
      if (scene.kind === "over" || scene.kind === "saved") scene.t += DT;
      break;
  }
}

function draw(): void {
  renderer.begin();
  switch (scene.kind) {
    case "title":
      renderer.world(attract, clock);
      renderer.title(scene.sel, clock, publicRows ?? scores, publicRows !== null, touchMode());
      break;
    case "lobby":
      renderer.world(attract, clock);
      renderer.lobby(scene.mode, scene.devices, scene.devices.map(deviceLabel), clock, touchMode(), scene.launching);
      break;
    case "play":
      renderer.world(scene.game, clock);
      renderer.hud(scene.game, best(), scene.ticket === null);
      if (scene.paused) renderer.paused();
      break;
    case "over":
      renderer.world(scene.game, clock);
      renderer.gameOver(scene.game, scene.t);
      break;
    case "entry": {
      renderer.world(scene.game, clock);
      renderer.entry(scene.id, scene.game.ships[scene.id].score, scene.ranked);
      break;
    }
    case "saving":
      renderer.world(scene.game, clock);
      renderer.saving(clock);
      break;
    case "saved":
      renderer.world(scene.game, clock);
      renderer.saved(scene.results, scene.t);
      break;
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
    if (scene.devices.length > 0) void launch();
  } else if (scene.kind === "over" && scene.t > 1.2) void afterGame(scene);
  else if (scene.kind === "saved" && scene.t > 0.8) toTitle();
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
void refreshPublic();
requestAnimationFrame(frame);
