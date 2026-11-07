// Wires the pure game to the page: menus, the frame loop, input, sound and the scoreboard.
import { Cpu, LEVELS, type LevelName } from "./engine/ai";
import { DT, Recorder, cpuSeed, quantise, scoreOf } from "./engine/match";
import { H, IDLE, W, newMatch, step, type Control, type GameEvent, type Side, type State } from "./engine/rules";
import { cleanName } from "./name";
import { Lockstep, MULTIPLAYER_PAGE, REFUSALS, Room, delaySteps, everyoneIn, fingerprint, matchInAddress, type RoomMessage, type Start } from "./online";
import { defaultName, loadTable, saveName, startMatch, submitMatch, type Match, type TableRow } from "./scores";
import { actionFor, edit, NameEntry } from "./ui/entry";
import { Input } from "./ui/input";
import { Renderer } from "./ui/render";
import { Sound } from "./ui/sound";

type Screen = "title" | "help" | "play" | "paused" | "over" | "entry" | "scores" | "online";
/** How long the control hints stay on the table at the start of a match, in seconds. */
const HINT_TIME = 4;

const $ = <T extends HTMLElement>(id: string) => document.getElementById(id) as T;
const app = $<HTMLDivElement>("app");
const canvas = $<HTMLCanvasElement>("table");
const board = $<HTMLElement>("board");
const rotate = $<HTMLElement>("rotate");
const siteLinks = $<HTMLElement>("site-links");
const panels: Record<Exclude<Screen, "play">, HTMLElement> = {
  title: $("title"), help: $("help"), paused: $("paused"), over: $("over"), entry: $("entry"), scores: $("scores"), online: $("online"),
};
const netwait = $<HTMLElement>("netwait");
const onlineStatus = $<HTMLElement>("online-status");
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
/** A one-player match the server issued a seed for, and its recording: it may enter the table. */
let ranked: { match: Match; level: LevelName; recorder: Recorder } | null = null;
/** True while a one-player match waits for its seed. */
let starting = false;
/** The computer-against-computer match that plays behind the menus. */
let demo = newDemo();

/**
 * Online: the match this browser is in (started from the multiplayer page), which side it plays,
 * and the match's lockstep (null before and after it). The first to join the game in the lobby
 * plays on the left.
 */
let online: { room: Room; side: Side; lock: Lockstep | null; ended: string | null } | null = null;

function seed(): number {
  return (Math.random() * 2 ** 32) >>> 0;
}

function newDemo(): { s: State; cpus: [Cpu, Cpu] } {
  const n = seed();
  return { s: newMatch(n), cpus: [new Cpu(0, LEVELS.hard, n + 1), new Cpu(1, LEVELS.normal, n + 2)] };
}

/** The menus play a computer match behind them; a table opened from the title does too. */
const demoShowing = (): boolean => screen === "title" || screen === "help" || screen === "online" || (screen === "scores" && $("scores-again").hidden);

/** The other player's name online: their address before the @, as the scoreboard shows it. */
const rivalName = (): string => (online?.room.names[1 - online.side] ?? "").toUpperCase().slice(0, 12) || "RIVAL";
const names = (): [string, string] =>
  online ? (online.side === 0 ? ["YOU", rivalName()] : [rivalName(), "YOU"]) : players === 1 ? ["YOU", "CPU"] : ["LEFT", "RIGHT"];
/** Whether an online match is being played (it can't be paused: it goes on behind the menu). */
const playingOnline = (): boolean => online?.lock != null && match.phase !== "over";

// ——— Screens ———

function show(next: Screen): void {
  screen = next;
  for (const [name, el] of Object.entries(panels)) el.hidden = name !== next;
  document.body.classList.toggle("menu", next !== "play");
  pauseButton.hidden = (next !== "play" && next !== "paused") || playingOnline();
  if (next === "paused") {
    const net = playingOnline();
    $("paused-h").textContent = net ? "ONLINE MATCH" : "PAUSED";
    $("paused-note").hidden = !net;
    $("resume").textContent = net ? "BACK TO THE MATCH" : "RESUME";
    $("quit").textContent = net ? "LEAVE THE MATCH" : "QUIT TO MENU";
  }
  pauseButton.textContent = next === "paused" ? "▶" : "II";
  pauseButton.setAttribute("aria-label", next === "paused" ? "Resume" : "Pause");
  input.reset();
  if (next !== "play" && next !== "entry" && next !== "online") (panels[next].querySelector("button.big:not([hidden]), button[aria-checked='true']") as HTMLButtonElement | null)?.focus();
  else (document.activeElement as HTMLElement | null)?.blur(); // play and name entry read keys themselves
  updateBoard();
}

async function start(n: 1 | 2): Promise<void> {
  if (starting) return;
  leaveOnline();
  players = n;
  sound.wake();
  ranked = null;
  let s = seed();
  if (n === 1) {
    // The server's seed lets it replay the match later. Without one (offline), the match still plays.
    starting = true;
    const issued = await startMatch();
    starting = false;
    if (issued) { s = issued.seed >>> 0; ranked = { match: issued, level, recorder: new Recorder() }; }
  }
  match = newMatch(s);
  cpu = n === 1 ? new Cpu(1, LEVELS[level], cpuSeed(s)) : null;
  hintLeft = HINT_TIME;
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
  const s = demoShowing() ? demo.s : match;
  const n = demoShowing() ? ["CPU", "CPU"] : names();
  for (const side of [0, 1] as Side[]) {
    $(`name${side}`).textContent = n[side];
    $(`score${side}`).textContent = String(s.score[side]);
    $(`serve${side}`).classList.toggle("on", s.phase !== "over" && s.server === side);
  }
}

function say(text: string): void {
  announce.textContent = text;
}

const resultTitle = (winner: Side): string => {
  const [a, b] = names();
  if (online) return winner === online.side ? "YOU WIN" : `${rivalName()} WINS`;
  return players === 1 ? (winner === 0 ? "YOU WIN" : "CPU WINS") : `${winner === 0 ? a : b} WINS`;
};
/** The player's score for this one-player match. */
const points = (): number => scoreOf(ranked?.level ?? level, match.score, match.winner);

function gameOver(winner: Side): void {
  const title = resultTitle(winner);
  const final = `${match.score[0]} – ${match.score[1]}`;
  if (online) { endOnline(null); return; }
  if (players === 1 && ranked && points() > 0) { void offerEntry(title, final); return; }
  showOver(ranked || players === 2 ? "" : "Offline: this score can't go on the table.");
}

/** The result panel: who won, the points, and (one player) the score. */
function showOver(note = ""): void {
  const title = online?.ended ?? resultTitle(match.winner ?? 0);
  $("over-h").textContent = title;
  $("final").textContent = `${match.score[0]} – ${match.score[1]}`;
  const p = $("over-points");
  p.hidden = players !== 1;
  p.textContent = `SCORE ${points().toLocaleString("en")}${note ? ` · ${note}` : ""}`;
  const onlineNote = online ? (online.room.closed ? "The connection to the game was lost." : online.room.peers.size < 2 ? `${rivalName()} has left.` : "") : "";
  $("over-note").textContent = onlineNote;
  $("over-note").hidden = !onlineNote;
  // Another online match starts from the multiplayer page.
  $("over-again").textContent = online ? "BACK TO MULTIPLAYER" : "PLAY AGAIN";
  say(`${title.toLowerCase()}, ${match.score[0]} to ${match.score[1]}.${players === 1 ? ` Score ${points()}.` : ""} ${onlineNote}`);
  show("over");
}

// ——— Online: a match started from the multiplayer page ———
//
// The multiplayer page (icelander.net/games/multiplayer/) opens this page with ?match=ID for both
// players. Both connect to the match; once both are there, the host (the first in the lobby) starts it.

/** Connects to the match in the address, and starts it once both players are there. */
async function joinMatch(id: string): Promise<void> {
  show("online");
  onlineStatus.textContent = "Connecting to the game…";
  let room: Room;
  try {
    room = await Room.open(id);
  } catch (e) {
    onlineStatus.textContent = REFUSALS[(e as Error).message] ?? REFUSALS.unreachable;
    return;
  }
  online = { room, side: room.you === 0 ? 0 : 1, lock: null, ended: null };
  room.listen((msg) => roomMessage(room, msg));
  const waiting = () => {
    if (online?.room === room && !online.lock && screen === "online") {
      onlineStatus.textContent = room.peers.size < room.size ? `Waiting for ${rivalName()} to arrive…` : "Starting…";
    }
  };
  waiting();
  room.listen(waiting);
  await everyoneIn(room);
  if (online?.room !== room || online.lock) return; // the host has started it already
  if (room.isHost) startOnline(room);
  // If the host never comes, whoever is host by then starts it.
  else setTimeout(() => { if (online?.room === room && !online.lock && room.isHost) startOnline(room); }, 5000);
}

/** A Control as a whole number, to send: 0–2 for the keys' direction, 3 + y for a finger or mouse. */
const pack = (c: Control): number => (c.target === null ? c.dir + 1 : 3 + c.target);
const unpack = (n: number | null): Control =>
  n === null ? IDLE : n < 3 ? { dir: (n - 1) as -1 | 0 | 1, target: null } : { dir: 0, target: Math.min(H, n - 3) };
const IDLE_PACKED = pack(IDLE);

/** The host starts a match: a fresh seed, and a delay to suit both connections. */
function startOnline(room: Room): void {
  const slots = [...room.peers].sort((a, b) => a - b).slice(0, 2);
  if (slots.length < 2) {
    onlineStatus.textContent = `${rivalName()} didn't arrive. Start a new game from the multiplayer page.`;
    return;
  }
  const start: Start = { slots, seed: seed(), delay: delaySteps(slots.map((s) => room.rtts.get(s) ?? 150), DT) };
  room.send({ t: "start", ...start });
  beginOnline(room, start);
}

function roomMessage(room: Room, msg: RoomMessage): void {
  if (!online || online.room !== room) return;
  if (msg.t === "start" && Array.isArray(msg.slots) && msg.slots.includes(room.you)) {
    beginOnline(room, { slots: msg.slots as number[], seed: Number(msg.seed) >>> 0, delay: Math.max(1, Math.min(120, Number(msg.delay) | 0)) });
  } else if (msg.t === "closed" && online.lock) {
    endOnline("CONNECTION LOST");
  } else if ((msg.t === "leave" || msg.t === "closed") && screen === "over") {
    showOver();
  } else if (msg.t === "closed" && screen === "online") {
    onlineStatus.textContent = REFUSALS.lost;
  }
}

function beginOnline(room: Room, start: Start): void {
  if (!online) return;
  online.lock?.stop();
  const lock = new Lockstep(room, start, IDLE_PACKED);
  online.side = lock.me as Side;
  online.lock = lock;
  online.ended = null;
  lock.onLeave = () => endOnline(`${rivalName()} LEFT`);
  lock.onDesync = () => endOnline("OUT OF STEP");
  sound.wake();
  ranked = null;
  cpu = null;
  players = 2;
  match = newMatch(start.seed);
  hintLeft = HINT_TIME;
  acc = 0;
  show("play");
  say(`Online match. You play on the ${online.side === 0 ? "left" : "right"}. First to 11.`);
}

/** The online match is over: won, or cut short (why, as the result's title). */
function endOnline(why: string | null): void {
  if (!online?.lock) return;
  online.lock.stop();
  online.lock = null;
  online.ended = why;
  netwait.hidden = true;
  showOver();
}

/** Leaves the match, if this browser is in one. */
function leaveOnline(): void {
  if (matchInAddress()) history.replaceState(null, "", location.pathname); // a reload doesn't join it again
  if (!online) return;
  online.lock?.stop();
  online.room.close();
  online = null;
  netwait.hidden = true;
}

// ——— High scores: name entry, then the table ———

let entry: NameEntry | null = null;
let name = "";
let typed = false;
let sending = false;

async function offerEntry(title: string, final: string): Promise<void> {
  $("entry-h").textContent = `${title} ${final}`;
  $("entry-points").textContent = `SCORE ${points().toLocaleString("en")}`;
  entry = new NameEntry($("slots"), $("keyboard"), (key) => entryKey(key));
  name = "";
  typed = false;
  sending = false;
  message("Type, or tap the keys. ENTER saves.");
  entry.show(name);
  show("entry");
  say(`${title}, ${final}. Score ${points()}. Type a name of up to 12 letters for the high-score table, then press Enter. Backspace deletes, Escape skips.`);
  const suggested = await defaultName();
  if (!typed && screen === "entry") { name = suggested; entry.show(name); if (name) say(`Name: ${[...name].join(" ")}.`); }
}

const message = (text: string) => { $("entry-message").textContent = text; };

async function entryKey(key: string): Promise<void> {
  const a = actionFor(key);
  if (a.kind === "none" || !entry || screen !== "entry") return;
  entry.blink(key);
  sound.key();
  if (sending) return;
  if (a.kind === "skip") { showOver(); return; }
  if (a.kind === "enter") {
    const final = cleanName(name);
    if (!final) { message("Type a name first."); say("Type a name first."); return; }
    if (!ranked) return;
    sending = true;
    message("Sending your match…");
    const result = await submitMatch(ranked.match, ranked.level, ranked.recorder.recording, final);
    sending = false;
    if (!result) { message("The table can't be reached. ENTER tries again."); say("The table can't be reached."); return; }
    saveName(final);
    ranked = null; // each match enters once
    await showScores(result);
    return;
  }
  typed = true;
  name = edit(name, a);
  entry.show(name);
  message("Type, or tap the keys. ENTER saves.");
  say(name ? `Name: ${[...name].join(" ")}.` : "No name yet.");
}

const LEVEL_LABEL: Record<LevelName, string> = { easy: "EASY", normal: "NORMAL", hard: "HARD" };

async function showScores(mine?: { rank: number; score: number }): Promise<void> {
  const rows = await loadTable();
  const table = $("table-rows");
  table.replaceChildren();
  const tr = (cells: string[], head = false, own = false) => {
    const r = document.createElement("tr");
    if (own) r.className = "mine";
    cells.forEach((text, i) => {
      const cell = document.createElement(head ? "th" : "td");
      cell.textContent = text;
      if (i === 0 || i === 2) cell.className = "num";
      r.append(cell);
    });
    table.append(r);
  };
  tr(["#", "NAME", "SCORE", "CPU", "MATCH"], true);
  (rows ?? []).forEach((r: TableRow, i) =>
    tr([String(i + 1), r.name, r.score.toLocaleString("en"), LEVEL_LABEL[r.level] ?? "", `${r.won ? "WON" : "LOST"} ${r.mine}–${r.theirs}`], false, mine?.rank === i + 1));
  const note = rows === null ? "The table can't be reached right now." : rows.length === 0 ? "No match recorded yet. Be the first." : "";
  $("scores-message").textContent = mine ? `Your score: ${mine.score.toLocaleString("en")}, ranked ${mine.rank}.${note ? " " + note : ""}` : note;
  $("scores-again").hidden = !mine;
  say(`High scores. ${rows ? rows.map((r, i) => `${i + 1}: ${r.name}, ${r.score}.`).join(" ") : note} ${$("scores-message").textContent}`);
  show("scores");
}

// ——— The frame loop ———

/** A fingerprint of the match, compared between the two browsers of an online match. */
const matchPrint = (s: State): number =>
  fingerprint([s.ball.x, s.ball.y, s.ball.vx, s.ball.vy, s.paddles[0].y, s.paddles[1].y, s.score[0], s.score[1], s.timer]);

/** Steps an online match by real time: this browser's control goes out, and each step waits for the rival's. */
function stepOnline(lock: Lockstep, dt: number, now: number): void {
  acc += dt;
  let stuck = false;
  while (acc >= DT && online?.lock === lock && match.phase !== "over") {
    lock.local(pack(screen === "play" ? quantise(input.one()) : IDLE));
    if (!lock.ready()) { stuck = true; acc = Math.min(acc, DT); break; }
    acc -= DT;
    const [a, b] = lock.next();
    handle(step(match, [unpack(a), unpack(b)], DT));
    lock.check(matchPrint(match));
  }
  lock.flush(now);
  lock.stalled(now, stuck);
  const late = stuck && lock.waitingSince !== null && now - lock.waitingSince > 400;
  if (late) netwait.textContent = "Waiting for your rival's moves…";
  netwait.hidden = !late;
}

function controls(): [Control, Control] {
  if (players === 2) return input.two();
  // The player's control in whole pixels, as it is recorded, so the server's replay matches exactly.
  const human = quantise(input.one());
  ranked?.recorder.record(human);
  return [human, cpu!.control(match, DT)];
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

  if (online?.lock && (screen === "play" || screen === "paused")) {
    hintLeft = Math.max(0, hintLeft - dt);
    stepOnline(online.lock, dt, now);
  } else if (screen === "play") {
    acc += dt;
    hintLeft = Math.max(0, hintLeft - dt);
    while (acc >= DT && screen === "play") {
      acc -= DT;
      handle(step(match, controls(), DT));
    }
  } else {
    acc = 0;
  }

  if (demoShowing()) {
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
      ? online ? (online.side === 0 ? ["YOU: W / S, ↑ / ↓ or drag", ""] : ["", "YOU: W / S, ↑ / ↓ or drag"])
        : players === 1 ? ["W / S, ↑ / ↓ or drag", ""] : ["W / S or drag here", "↑ / ↓ or drag here"]
      : null;
    renderer.draw(match, screen === "play" || playingOnline() ? dt : 0, hints);
  }
  requestAnimationFrame(frame);
}

// ——— Layout: the largest table that fits, with the scoreboard above it ———

function layout(): void {
  const style = getComputedStyle(app);
  const padX = parseFloat(style.paddingLeft) + parseFloat(style.paddingRight);
  const padY = parseFloat(style.paddingTop) + parseFloat(style.paddingBottom);
  const extra = board.offsetHeight + 10 + (rotate.offsetHeight ? rotate.offsetHeight + 10 : 0) + siteLinks.offsetHeight + 10;
  const width = Math.max(240, Math.min(document.documentElement.clientWidth - padX, ((window.innerHeight - padY - extra) * W) / H, 1100));
  app.style.setProperty("--w", `${Math.floor(width)}px`);
  renderer.resize(Math.floor(width));
}

// ——— Events ———

function act(action: string | undefined): void {
  sound.wake();
  switch (action) {
    case "one": void start(1); break;
    case "two": void start(2); break;
    case "again": if (online) { leaveOnline(); location.assign(MULTIPLAYER_PAGE); } else void start(players); break;
    case "help": show("help"); break;
    case "scores": void showScores(); break;
    case "menu": leaveOnline(); cpu = null; demo = newDemo(); show("title"); break;
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
pauseButton.addEventListener("click", () => { if (!playingOnline()) show(screen === "paused" ? "play" : "paused"); });

document.addEventListener("keydown", (e) => {
  if (e.metaKey || e.ctrlKey || e.altKey) return;
  sound.wake();
  const k = e.key.toLowerCase();
  // Typing a name: every key is a letter (M included), Backspace deletes, Enter saves, Escape skips.
  if (screen === "entry") {
    if (e.repeat && e.key !== "Backspace") return;
    if (actionFor(e.key).kind !== "none") { e.preventDefault(); void entryKey(e.key); }
    return;
  }
  if (k === "m") { setSound(!sound.on); return; }

  if (screen === "play") {
    if (input.key(e.code, true)) e.preventDefault();
    // Escape opens the menu over an online match, which goes on; P can't pause it.
    if ((k === "p" && !playingOnline()) || e.key === "Escape") { e.preventDefault(); show("paused"); }
    return;
  }
  if (screen === "paused" && (k === "p" || e.key === "Escape" || k === " ")) { e.preventDefault(); show("play"); return; }
  if (screen === "title") {
    if (k === "1") void start(1);
    else if (k === "2") void start(2);
    else if (k === "h") show("help");
    else if (k === "s") void showScores();
    return;
  }
  if (screen === "help" && (e.key === "Escape" || k === "h")) { show("title"); return; }
  if (screen === "scores" && e.key === "Escape") { show("title"); return; }
  if (screen === "online" && e.key === "Escape") { leaveOnline(); show("title"); return; }
  if (screen === "over" && e.key === "Escape") show("title");
});
document.addEventListener("keyup", (e) => { input.key(e.code, false); });

// Leaving the page pauses a match, except online, where the rival waits for this browser's moves instead.
document.addEventListener("visibilitychange", () => { if (document.hidden && screen === "play" && !playingOnline()) show("paused"); });
window.addEventListener("blur", () => { if (screen === "play" && !playingOnline()) show("paused"); });
window.addEventListener("resize", layout);
new ResizeObserver(layout).observe(document.documentElement);
window.addEventListener("orientationchange", layout);

setLevel(level);
setSound(sound.on);
show("title");
// Opened from the multiplayer page with ?match=ID: join that match.
const invited = matchInAddress();
if (invited) void joinMatch(invited);
layout();
requestAnimationFrame((now) => { last = now; frame(now); });
