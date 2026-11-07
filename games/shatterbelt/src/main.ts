// The browser side: screens, the frame loop, and wiring input, sound and drawing to the engine.
import { DT, MAX_PLAYERS } from "./engine/config";
import { newGame, standings, step, type Controls, type Game } from "./engine/game";
import { Recorder, fromBits, toBits, type Recording } from "./engine/replay";
import { Input, deviceLabel, fireDevice, menuAct, type Device, type Press } from "./input";
import { MENU_ITEMS, PLAYER_COLORS, Renderer, inRect, menuRect } from "./render";
import { addScore, loadScores, qualifies, TABLE_SIZE } from "./scores";
import { NAME_MAX, cleanName } from "./name";
import { loadPublic, startGame, submitGame, type PublicRow, type Result, type Ticket } from "./net";
import { Sound } from "./sound";
import { Lockstep, MULTIPLAYER_PAGE, REFUSALS, Room, delaySteps, everyoneIn, fingerprint, matchInAddress, type RoomMessage, type Start } from "./online";

type Scene =
  | { kind: "title"; sel: number }
  | { kind: "lobby"; mode: "coop" | "versus"; devices: Device[]; launching: boolean }
  | { kind: "play"; game: Game; devices: Device[]; paused: boolean; rec: Recorder; ticket: Ticket | null; net?: Net }
  | { kind: "over"; game: Game; rec: Recorder; ticket: Ticket | null; t: number; net?: Net }
  | { kind: "entry"; game: Game; id: number; ranked: boolean }
  | { kind: "saving"; game: Game }
  | { kind: "saved"; game: Game; results: Result[] | null; t: number };

/** A finished game on its way to the tables. */
type Finished = { game: Game; rec: Recorder; ticket: Ticket | null; net?: Net };

/** An online game: this browser plays one ship; the others are other browsers in the room. */
interface Net {
  room: Room;
  lock: Lockstep;
  /** The ships' slots in the room: ship i is slots[i]. */
  slots: number[];
}

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
  leaveRoom();
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
  if (scene.kind !== "play" || scene.paused === on || scene.net) return; // an online game goes on
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
async function afterGame({ game, rec, ticket, net }: Finished): Promise<void> {
  const queue = standings(game)
    .filter((s) => !net || s.id === net.lock.me) // online, each browser asks its own pilot
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
  if (net) return afterOnline(game, rec, ticket, net, names[net.lock.me]);
  if (!ticket || names.every((n) => n === null)) return toTitle();
  await submit(game, rec, ticket, names);
}

/** Sends the game to the server, which replays it and lists the named players. */
async function submit(game: Game, rec: Recorder, ticket: Ticket, names: (string | null)[]): Promise<Result[] | null> {
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
  return results;
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
      if (scene.net) {
        // Online there's no pause; Escape twice leaves the game.
        if (p.code === "Escape") {
          if (clock - escAt < 2) { leaveRoom(); noteUntil = 0; toTitle(); return; }
          escAt = clock;
          note("ESC AGAIN TO LEAVE THE GAME", 2);
        }
        break;
      }
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

/** One step. Online, `online` is every ship's controls for it. */
function tick(online?: Controls[]): void {
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
      const inputs: Controls[] = online ?? scene.devices.map((d) => input.controls(d));
      scene.rec.record(inputs);
      step(g, inputs);
      renderer.absorb(g.events, g);
      renderer.trails(g);
      sound.play(g.events);
      for (const e of g.events) if (e.type === "wave") say(`Wave ${e.n}.`);
      if (g.over) {
        const ranked = standings(g);
        if (scene.net) scene.net.lock.stop();
        scene = { kind: "over", game: g, rec: scene.rec, ticket: scene.ticket, t: 0, net: scene.net };
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

// ——— Online: each pilot on their own computer ———
//
// Online games start on the multiplayer page (icelander.net/games/multiplayer/), which opens this page
// with ?match=ID&mode=coop (or versus) for every pilot. Every browser runs the same game in lockstep
// (src/online.ts) and sends only its own pilot's controls. The host (the first in the lobby) starts
// the game with a seed the high-score server issued, so an online game goes on the public table like
// any other: each browser asks its own pilot's name, and the host sends the game with every name.

const netLine = document.getElementById("net") as HTMLElement;
/** The mode the multiplayer page chose, from the address. */
const onlineMode: "coop" | "versus" = new URLSearchParams(location.search).get("mode") === "versus" ? "versus" : "coop";
/** The match this browser is in, if any, and whether its game has begun. */
let room: Room | null = null;
let begun = false;
/** What the status line says while there is no game: connecting, waiting, or why not. */
let netText = "";
/** A short message for the status line, until `noteUntil` (clock seconds). */
let noteText = "";
let noteUntil = 0;
let escAt = -10;
const note = (text: string, seconds = 6) => { noteText = text; noteUntil = clock + seconds; say(text); };

/** Connects to the match in the address, and starts it once every pilot is there. */
async function joinMatch(id: string): Promise<void> {
  netText = "CONNECTING TO THE GAME…";
  let r: Room;
  try {
    r = await Room.open(id);
  } catch (e) {
    netText = (REFUSALS[(e as Error).message] ?? REFUSALS.unreachable).toUpperCase();
    return;
  }
  room = r;
  const waiting = () => {
    if (room === r && !begun) {
      netText = r.peers.size < r.size ? `WAITING FOR ${r.size - r.peers.size} MORE…` : "STARTING…";
    }
  };
  waiting();
  r.listen((msg) => { roomMessage(r, msg); waiting(); });
  await everyoneIn(r);
  if (room !== r || (scene.kind === "play" && scene.net)) return; // the host has started it already
  if (r.isHost) void startOnline(r);
  // If the host never comes, whoever is host by then starts it.
  else setTimeout(() => { if (room === r && !(scene.kind === "play" && scene.net) && r.isHost) void startOnline(r); }, 5000);
}

/** Leaves the match, if this browser is in one. */
function leaveRoom(): void {
  if (scene.kind === "play" && scene.net) scene.net.lock.stop();
  if (matchInAddress()) history.replaceState(null, "", location.pathname); // a reload doesn't join it again
  room?.close();
  room = null;
  netText = "";
}

let starting = false;
/** The host starts a game: a seed from the server if it can be had, the mode, and a delay to suit everyone's connection. */
async function startOnline(room: Room): Promise<void> {
  if (starting) return;
  starting = true;
  const ticket = await startGame();
  starting = false;
  if (room.closed) return;
  const slots = [...room.peers].sort((a, b) => a - b).slice(0, MAX_PLAYERS);
  if (slots.length < 2) { netText = "NOBODY ELSE ARRIVED"; return; }
  const start: Start & { mode: string; ticket: Ticket | null } = {
    slots, seed: ticket ? ticket.seed : seed(), mode: onlineMode, ticket,
    delay: delaySteps(slots.map((s) => room.rtts.get(s) ?? 150), DT),
  };
  room.send({ t: "start", ...start });
  beginOnline(room, start, onlineMode, ticket);
}

function roomMessage(r: Room, msg: RoomMessage): void {
  if (room !== r) return;
  if (msg.t === "start" && Array.isArray(msg.slots) && msg.slots.includes(r.you)) {
    const t = msg.ticket as Ticket | null;
    const ticket = t && typeof t.id === "string" && Number.isInteger(t.seed) ? { id: t.id, seed: t.seed >>> 0 } : null;
    const slots = (msg.slots as unknown[]).map(Number).slice(0, MAX_PLAYERS);
    beginOnline(r, { slots, seed: Number(msg.seed) >>> 0, delay: Math.max(1, Math.min(60, Number(msg.delay) | 0)) }, msg.mode === "versus" ? "versus" : "coop", ticket);
  } else if (msg.t === "closed") {
    if (scene.kind === "play" && scene.net) { scene.net.lock.stop(); toTitle(); }
    netText = "THE CONNECTION TO THE GAME WAS LOST";
  } else if (msg.t === "name" || msg.t === "leave") {
    namesHeard.push(msg);
    wakeNames();
  } else if (msg.t === "results") {
    gotResults(msg.results === null ? null : (msg.results as Result[]));
  }
}

function beginOnline(room: Room, start: Start, mode: "coop" | "versus", ticket: Ticket | null): void {
  if (scene.kind === "play" && scene.net) scene.net.lock.stop();
  document.querySelector("form.entry")?.remove();
  document.body.classList.remove("entering");
  const lock = new Lockstep(room, start, 0);
  const net: Net = { room, lock, slots: start.slots };
  lock.onLeave = (i) => note(`P${i + 1} LEFT THE GAME`);
  lock.onDesync = () => {
    if (scene.kind === "play" && scene.net === net) { lock.stop(); toTitle(); }
    note("THE GAMES FELL OUT OF STEP, SO IT ENDED. SORRY!", 10);
  };
  namesHeard = [];
  const game = newGame(mode, start.slots.length, start.seed);
  scene = { kind: "play", game, devices: [], paused: false, rec: new Recorder(start.slots.length), ticket, net };
  begun = true;
  netText = "ONLINE GAME OVER";
  renderer.clearEffects();
  acc = 0;
  sound.unlock();
  const n = start.slots.length;
  say(`Online, ${n} ${n === 1 ? "pilot" : "pilots"}, ${mode === "versus" ? "versus" : "co-op"}. You are player ${lock.me + 1}. Go.`);
  updateButtons();
}

/** This browser's pilot: any keys, any gamepad, or the touch buttons. */
function localControls(): Controls {
  const all = ["kb", "touch", "pad0", "pad1", "pad2", "pad3"].map((d) => input.controls(d));
  return {
    left: all.some((c) => c.left), right: all.some((c) => c.right), thrust: all.some((c) => c.thrust),
    fire: all.some((c) => c.fire), blink: all.some((c) => c.blink),
  };
}

/** A fingerprint of the game, compared between the browsers. */
const gamePrint = (g: Game): number => fingerprint([
  g.rng, g.time, g.wave, g.rocks.length, g.bullets.length, g.drones.length,
  ...g.ships.flatMap((s) => [s.x, s.y, s.angle, s.score, s.lives]),
]);

function stepOnline(net: Net, now: number): void {
  let stuck = false;
  while (acc >= DT && scene.kind === "play" && scene.net === net) {
    net.lock.local(toBits(localControls()));
    if (!net.lock.ready()) { stuck = true; acc = Math.min(acc, DT); break; }
    acc -= DT;
    tick(net.lock.next().map((b) => fromBits(b ?? 0)));
    net.lock.check(gamePrint(scene.game));
  }
  net.lock.flush(now);
  net.lock.stalled(now, stuck);
}

// After an online game: every browser sends its pilot's name (or null); the host waits for them all
// (or for those who leave), sends the game, and tells the others how it went.
let namesHeard: RoomMessage[] = [];
let wakeNames: () => void = () => {};
let gotResults: (r: Result[] | null) => void = () => {};

async function afterOnline(game: Game, rec: Recorder, ticket: Ticket | null, net: Net, mine: string | null): Promise<void> {
  const { room, lock, slots } = net;
  room.send({ t: "name", player: lock.me, name: mine });
  if (!ticket) return toTitle();
  const lead = Math.min(...slots.filter((s) => room.peers.has(s)));
  if (room.you !== lead) {
    scene = { kind: "saving", game };
    say("Waiting for the scores.");
    const results = await new Promise<Result[] | null | "none">((resolve) => {
      const timer = setTimeout(() => resolve(null), 120_000);
      gotResults = (r) => { clearTimeout(timer); resolve(r ?? "none"); };
    });
    gotResults = () => {};
    if (results === "none" || scene.kind !== "saving") return toTitle();
    if (results) await refreshPublic();
    scene = { kind: "saved", game, results, t: 0 };
    return;
  }
  const names: (string | null)[] = slots.map(() => null);
  names[lock.me] = mine;
  scene = { kind: "saving", game };
  say("Waiting for every pilot's name.");
  await new Promise<void>((resolve) => {
    const timer = setTimeout(done, 120_000);
    function done(): void { clearTimeout(timer); wakeNames = () => {}; resolve(); }
    wakeNames = () => {
      const heard = new Set<number>([lock.me]);
      for (const m of namesHeard) {
        if (m.t === "name" && typeof m.player === "number" && slots[m.player] === m.from) {
          heard.add(m.player);
          names[m.player] = typeof m.name === "string" ? cleanName(m.name) || null : null;
        }
      }
      if (slots.every((s, i) => heard.has(i) || !room.peers.has(s))) done();
    };
    wakeNames();
  });
  if (names.every((n) => n === null)) { room.send({ t: "results", results: null }); return toTitle(); }
  const results = await submit(game, rec, ticket, names);
  room.send({ t: "results", results });
}

/** The status line under the field: which pilot you are, any waiting, and the way back to the multiplayer page. */
function showNet(now: number): void {
  let text = netText;
  let color = "";
  if (clock < noteUntil) text = noteText;
  else if (scene.kind === "play" && scene.net) {
    const lock = scene.net.lock;
    const waiting = lock.waitingSince !== null && now - lock.waitingSince > 400 ? lock.waiting() : [];
    text = waiting.length ? `WAITING FOR ${waiting.map((i) => `P${i + 1}`).join(", ")}…` : `ONLINE · YOU ARE P${lock.me + 1}`;
    color = waiting.length ? "" : PLAYER_COLORS[lock.me];
  }
  // Back to the multiplayer page once the online game is over, or couldn't start.
  const back = !!text && !(scene.kind === "play" && scene.net) && !text.endsWith("…") && (room === null || netText === "ONLINE GAME OVER" || room.closed);
  netLine.hidden = !text;
  netLine.style.color = color;
  const key = `${text}|${back}`;
  if (netLine.dataset.key === key) return;
  netLine.dataset.key = key;
  const link = document.createElement("a");
  link.href = MULTIPLAYER_PAGE;
  link.textContent = "BACK TO MULTIPLAYER";
  netLine.replaceChildren(text, ...(back ? [" · ", link] : []));
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
  if (scene.kind === "play" && scene.net) stepOnline(scene.net, now);
  else {
    while (acc >= DT) {
      acc -= DT;
      tick();
    }
  }
  showNet(now);
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
  setPaused(true); // (not online: the others wait for this browser's moves instead)
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
// Opened from the multiplayer page with ?match=ID: join that match.
const invited = matchInAddress();
if (invited) void joinMatch(invited);
requestAnimationFrame(frame);
