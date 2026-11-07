// The page: runs the game at a steady 60 steps a second, draws it each animation frame, plays its
// sounds, records each game's controls, and offers the high-score table when a game ends.
import { Game, Input, NO_INPUT } from "./engine/game";
import { Recorder } from "./engine/replay";
import { H, W } from "./engine/rules";
import { NAME_MAX, cleanName } from "./name";
import { Lockstep, MULTIPLAYER_PAGE, REFUSALS, Room, delaySteps, everyoneIn, fingerprint, matchInAddress, type RoomMessage, type Start } from "./online";
import { Ticket, loadTable, newTicket, qualifies, submitGame } from "./scores";
import { Controls } from "./ui/input";
import { View, render } from "./ui/render";
import { Sound } from "./ui/sound";

const HI_KEY = "hivestorm.hiscore";
const SOUND_KEY = "hivestorm.sound";

function load(key: string): string | null { try { return localStorage.getItem(key); } catch { return null; } }
function save(key: string, value: string): void { try { localStorage.setItem(key, value); } catch { /* private window */ } }

const canvas = document.getElementById("screen") as HTMLCanvasElement;
canvas.width = W;
canvas.height = H;
const ctx = canvas.getContext("2d")!;
const pad = document.getElementById("pad") as HTMLElement;

const game = new Game((Math.random() * 2 ** 32) >>> 0);
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

// Pause when the tab is hidden, so nobody dies while away. It goes through the controls like a
// key press, so the recording (and the server's replay) sees it on the frame it happened.
// (An online game can't be paused: the other player waits for this browser's moves instead.)
document.addEventListener("visibilitychange", () => {
  if (document.hidden && !online?.lock && !game.paused && game.phase !== "attract" && game.phase !== "gameOver") controls.queuePause();
});

// ── The high-score table ─────────────────────────────────────────────────

const view: View = { table: null, highlight: [], showTable: false };
/** Until this game frame, the title screens show the table (after a score is entered). */
let tableUntil = 0;

async function refreshTable(): Promise<void> {
  const rows = await loadTable();
  if (rows) {
    view.table = rows;
    game.hiScore = Math.max(game.hiScore, rows[0]?.score ?? 0);
  }
}

/** A seed from the server for the next game, fetched ahead so pressing 1 or 2 never waits. */
let ticket: Ticket | null = null;
let fetching = false;
async function fetchTicket(): Promise<void> {
  if (ticket || fetching) return;
  fetching = true;
  ticket = await newTicket();
  fetching = false;
  if (ticket) game.nextSeed = ticket.seed;
}

interface Recording { ticket: Ticket | null; recorder: Recorder }
let recording: Recording | null = null;

/** An HTML form under the screen for a player's name. Resolves with the cleaned name, or null to skip. */
function askName(label: string, error = ""): Promise<string | null> {
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
    for (const [k, v] of [["data-1p-ignore", ""], ["data-lpignore", "true"], ["data-bwignore", ""], ["data-form-type", "other"], ["autocapitalize", "characters"]]) field.setAttribute(k, v);
    const message = document.createElement("p");
    message.className = "entry-error";
    message.setAttribute("role", "alert");
    message.textContent = error;
    const submit = document.createElement("button");
    submit.type = "submit";
    submit.textContent = "ENTER";
    const skip = document.createElement("button");
    skip.type = "button";
    skip.textContent = "SKIP";
    const buttons = document.createElement("div");
    buttons.className = "entry-buttons";
    buttons.append(submit, skip);
    const note = document.createElement("p");
    note.className = "entry-note";
    note.textContent = `Up to ${NAME_MAX} letters or digits. Only the name is kept, and the server checks the score by replaying the game.`;
    form.append(caption, field, message, buttons, note);
    const done = (value: string | null) => { form.remove(); document.body.classList.remove("entering"); resolve(value); };
    // Typing in the form must never reach the game's keys (M would toggle the sound, 1 would start a game).
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
    pad.prepend(form);
    field.focus();
  });
}

/** After a game: ask each player whose score makes the table for a name, then send the game to be replayed. */
async function offerTable(rec: Recording, scores: number[], net: OnlineGame | null): Promise<void> {
  if (!rec.ticket) return; // started without a seed from the server (offline): it can't be checked
  if (!view.table) await refreshTable();
  const names: (string | null)[] = scores.map(() => null);
  for (let i = 0; i < scores.length; i++) {
    if (net && i !== net.me) continue; // online, each browser asks its own player
    if (!qualifies(scores[i], view.table)) continue;
    const who = scores.length === 2 ? `PLAYER ${i + 1}: ${scores[i]} POINTS!` : `${scores[i]} POINTS!`;
    names[i] = await askName(`${who} Your name for the high-score table:`);
  }
  if (net) {
    // Online, one browser sends the game for both: the host, once it has the other player's name.
    net.room.send({ t: "name", player: net.me, name: names[net.me] });
    if (net.room.you !== net.lead()) return;
    const theirs = await net.names;
    theirs[net.me] = names[net.me];
    names.splice(0, names.length, ...theirs);
  }
  if (names.every((n) => n === null)) return;
  let error = "";
  for (;;) {
    const result = await submitGame(rec.ticket, rec.recorder.runs, names);
    if (result) {
      await refreshTable();
      view.highlight = result.entries.map((e) => e.rank - 1).filter((r) => r < 10);
      tableUntil = game.frame + 900;
      net?.room.send({ t: "table", highlight: view.highlight });
      return;
    }
    error = "The score could not be sent. Try again, or skip.";
    if ((await askName("Send your score again? Your name:", error)) === null) return;
  }
}

// ── Online: two players on different computers, taking turns ────────────
//
// Online games start on the multiplayer page (games.icelander.net/multiplayer/), which opens this
// page with ?match=ID for both players. Both browsers run the same game in lockstep (src/online.ts).
// Each sends only its own player's controls, and each frame the game plays the controls of the
// player whose turn it is. The host (the first in the lobby) is player 1, and starts the game with
// a seed the high-score server issued, so an online game can go on the table too.

interface OnlineGame {
  room: Room;
  /** The game's lockstep while it is being played, else null. */
  lock: Lockstep | null;
  /** This browser's player: 0 or 1. */
  me: number;
  /** The players' slots in the room, from the game's start (empty before one). */
  slots: number[];
  /** The slot that sends the game to the table: the lowest one still here. */
  lead: () => number;
  ticket: Ticket | null;
  /** The other player's name for the table, once it arrives. */
  names: Promise<(string | null)[]>;
  gotName: (player: number, name: string | null) => void;
  /** Why the game was cut short, shown above the screen. */
  note: string;
}

let online: OnlineGame | null = null;
const net = document.getElementById("net") as HTMLElement;

/** Connects to the match in the address, and starts it once both players are there. */
async function joinMatch(id: string): Promise<void> {
  failed = "CONNECTING TO THE GAME…";
  let room: Room;
  try {
    room = await Room.open(id);
  } catch (e) {
    failed = (REFUSALS[(e as Error).message] ?? REFUSALS.unreachable).toUpperCase();
    return;
  }
  failed = "";
  online = newOnline(room, null, room.you);
  online.note = "WAITING FOR THE OTHER PLAYER…";
  room.listen((msg) => roomMessage(room, msg));
  await everyoneIn(room);
  if (online?.room !== room || online.lock) return; // the host has started it already
  if (room.isHost) startOnline(room);
  // If the host never comes, whoever is host by then starts it.
  else setTimeout(() => { if (online?.room === room && !online.lock && room.isHost) startOnline(room); }, 5000);
}

/** Why there is no online game, when the page was opened for one. */
let failed = "";

function newOnline(room: Room, ticket: Ticket | null, me: number, slots: number[] = []): OnlineGame {
  let gotName: (player: number, name: string | null) => void = () => {};
  // The other player's name (or null: none, or they left), or nothing after 90 seconds.
  const names = new Promise<(string | null)[]>((resolve) => {
    const got: (string | null)[] = [null, null];
    const timer = setTimeout(() => resolve(got), 90_000);
    gotName = (player, name) => {
      if (player !== 1 - me) return;
      got[player] = name;
      clearTimeout(timer);
      resolve(got);
    };
  });
  return { room, lock: null, me, slots, ticket, names, gotName, note: "", lead: () => Math.min(...slots.filter((s) => room.peers.has(s))) };
}

/** Inputs as bits: only left, right and fire travel; the starts and pause are the page's own business online. */
const pack = (i: Input): number => (i.left ? 1 : 0) | (i.right ? 2 : 0) | (i.fire ? 4 : 0);
const unpack = (b: number): Input => ({ ...NO_INPUT, left: !!(b & 1), right: !!(b & 2), fire: !!(b & 4) });

/** The host starts a game, with a seed from the server if it has one. */
function startOnline(room: Room): void {
  const slots = [...room.peers].sort((a, b) => a - b).slice(0, 2);
  if (slots.length < 2) {
    if (online) online.note = "THE OTHER PLAYER DIDN'T ARRIVE";
    return;
  }
  const t = ticket;
  ticket = null;
  void fetchTicket();
  const start: Start & { ticket: Ticket | null } = {
    slots, seed: t ? t.seed : (Math.random() * 2 ** 32) >>> 0, ticket: t,
    delay: delaySteps(slots.map((s) => room.rtts.get(s) ?? 150), 1 / 60),
  };
  room.send({ t: "start", ...start });
  beginOnline(room, start, t);
}

function roomMessage(room: Room, msg: RoomMessage): void {
  if (!online || online.room !== room) return;
  if (msg.t === "start" && Array.isArray(msg.slots) && msg.slots.includes(room.you)) {
    const t = msg.ticket as Ticket | null;
    const valid = t && typeof t.id === "string" && Number.isInteger(t.seed) ? { id: t.id, seed: t.seed >>> 0 } : null;
    beginOnline(room, { slots: msg.slots as number[], seed: Number(msg.seed) >>> 0, delay: Math.max(1, Math.min(60, Number(msg.delay) | 0)) }, valid);
  } else if (msg.t === "name" && typeof msg.player === "number") {
    online.gotName(msg.player, typeof msg.name === "string" ? cleanName(msg.name) || null : null);
  } else if (msg.t === "table" && Array.isArray(msg.highlight)) {
    void refreshTable().then(() => { view.highlight = (msg.highlight as number[]).filter((r) => Number.isInteger(r) && r >= 0 && r < 10); tableUntil = game.frame + 900; });
  } else if (msg.t === "closed") {
    if (online.lock) endOnline("CONNECTION LOST");
    else online.note = "THE CONNECTION TO THE GAME WAS LOST";
  } else if (msg.t === "leave") {
    const player = online.slots.indexOf(Number(msg.slot));
    if (player >= 0) online.gotName(player, null);
  }
}

function beginOnline(room: Room, start: Start, t: Ticket | null): void {
  online?.lock?.stop();
  const lock = new Lockstep(room, start, 0);
  online = newOnline(room, t, lock.me, start.slots);
  online.lock = lock;
  lock.onLeave = () => { if (online) online.note = "PLAYER LEFT: YOU PLAY BOTH TURNS"; };
  lock.onDesync = () => endOnline("OUT OF STEP: THE GAMES DIFFERED");
  // Whatever this browser was doing, the online game starts from the title, unpaused.
  document.querySelector("form.entry")?.remove();
  document.body.classList.remove("entering");
  recording = null;
  game.paused = false;
  game.phase = "attract";
  game.nextSeed = start.seed;
  sound.unlock();
  acc = 0;
}

/** The online game is over, or cut short. */
function endOnline(why: string): void {
  if (!online?.lock) return;
  online.lock.stop();
  online.lock = null;
  online.note = why;
  if (why && game.phase !== "attract" && game.phase !== "gameOver") {
    // Cut short: it can't go on without the other browser.
    recording = null;
    game.phase = "attract";
  }
}

/** A fingerprint of the game, compared between the two browsers. */
const gamePrint = (g: Game): number => fingerprint([
  g.frame, g.playerX, g.current, g.aliveCount, g.sway, g.shot?.x ?? -1, g.shot?.y ?? -1, g.bullets.length,
  ...g.players.flatMap((p) => [p.score, p.lives]), (g.rng as unknown as { s: number }).s,
]);

function stepOnline(o: OnlineGame, lock: Lockstep, now: number): void {
  let stuck = false;
  while (acc >= STEP && o.lock === lock) {
    lock.local(pack(controls.read()));
    if (!lock.ready()) { stuck = true; acc = Math.min(acc, STEP); break; }
    acc -= STEP;
    const all = lock.next();
    // The first frame starts a two-player game; after that, the player whose turn it is plays
    // (or, if they have left, the one still here).
    let input: Input;
    if (lock.frame === 1) input = { ...NO_INPUT, start2: true };
    else {
      const turn = all[game.current] ?? all[1 - game.current] ?? 0;
      input = unpack(turn);
    }
    step(input, o);
    lock.check(gamePrint(game));
    if (game.phase === "gameOver") endOnline("");
  }
  lock.flush(now);
  lock.stalled(now, stuck);
}

/** The line under the screen: whose game it is, any waiting, and the way back to the multiplayer page. */
function showNet(now: number): void {
  let text = failed;
  let back = !!failed && !failed.endsWith("…");
  if (online) {
    const lock = online.lock;
    const other = (online.room.names[1 - online.me] ?? "").toUpperCase() || `PLAYER ${2 - online.me}`;
    if (lock && lock.waitingSince !== null && now - lock.waitingSince > 400) text = `WAITING FOR ${other}…`;
    else if (online.note) text = online.note;
    else if (lock) text = `ONLINE · YOU ARE PLAYER ${lock.me + 1} · VS ${other}`;
    else text = "ONLINE GAME OVER";
    back = !lock || online.room.closed;
  }
  net.hidden = !text;
  document.body.classList.toggle("online-on", !!text);
  document.body.classList.toggle("online-play", !!online?.lock);
  const key = `${text}|${back}`;
  if (net.dataset.key === key) return;
  net.dataset.key = key;
  const link = document.createElement("a");
  link.href = MULTIPLAYER_PAGE;
  link.textContent = "BACK TO MULTIPLAYER";
  net.replaceChildren(text, ...(back ? [" · ", link] : []));
}

// ── The loop ─────────────────────────────────────────────────────────────

void refreshTable();
void fetchTicket();

const STEP = 1000 / 60;
let last = performance.now();
let acc = 0;

function step(input: Input, net: OnlineGame | null = null): void {
  const wasAttract = game.phase === "attract";
  if (wasAttract && (input.start1 || input.start2) && !net) {
    // The game about to start uses the server's seed if one arrived; otherwise one of its own.
    if (!ticket) game.nextSeed = (Math.random() * 2 ** 32) >>> 0;
  }
  const events = game.step(input);
  for (const e of events) sound.play(e);
  if (wasAttract && game.phase === "ready") {
    if (net) recording = { ticket: net.ticket, recorder: new Recorder() };
    else {
      recording = { ticket: ticket && game.nextSeed === ticket.seed ? ticket : null, recorder: new Recorder() };
      ticket = null;
      void fetchTicket();
    }
    view.highlight = [];
  }
  if (recording) {
    recording.recorder.push(input);
    if (game.phase === "gameOver") {
      const done = recording;
      recording = null;
      void offerTable(done, game.players.map((p) => p.score), net);
    }
  }
}

function frame(now: number): void {
  acc = Math.min(acc + (now - last), 250);
  last = now;
  if (online?.lock) stepOnline(online, online.lock, now);
  else {
    while (acc >= STEP) {
      step(controls.read());
      acc -= STEP;
    }
  }
  showNet(now);
  if (game.hiScore !== savedHi) { savedHi = game.hiScore; save(HI_KEY, String(savedHi)); }
  // On the title screens: the title for 10 seconds, then the table for 10, unless a score was just entered.
  view.showTable = game.phase === "attract" && (game.frame < tableUntil || Math.floor(game.frame / 600) % 2 === 1);
  view.you = online?.lock ? online.me : null;
  setMode();
  render(ctx, game, view);
  requestAnimationFrame(frame);
}
// Opened from the multiplayer page with ?match=ID: join that match.
const invited = matchInAddress();
if (invited) void joinMatch(invited);
requestAnimationFrame(frame);
