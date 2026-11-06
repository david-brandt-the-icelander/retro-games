// The page: runs the game at a steady 60 steps a second, draws it each animation frame, plays its
// sounds, records each game's controls, and offers the high-score table when a game ends.
import { Game, Input } from "./engine/game";
import { Recorder } from "./engine/replay";
import { H, W } from "./engine/rules";
import { NAME_MAX, cleanName } from "./name";
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
document.addEventListener("visibilitychange", () => {
  if (document.hidden && !game.paused && game.phase !== "attract" && game.phase !== "gameOver") controls.queuePause();
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
async function offerTable(rec: Recording, scores: number[]): Promise<void> {
  if (!rec.ticket) return; // started without a seed from the server (offline): it can't be checked
  if (!view.table) await refreshTable();
  const names: (string | null)[] = scores.map(() => null);
  for (let i = 0; i < scores.length; i++) {
    if (!qualifies(scores[i], view.table)) continue;
    const who = scores.length === 2 ? `PLAYER ${i + 1}: ${scores[i]} POINTS!` : `${scores[i]} POINTS!`;
    names[i] = await askName(`${who} Your name for the high-score table:`);
  }
  if (names.every((n) => n === null)) return;
  let error = "";
  for (;;) {
    const result = await submitGame(rec.ticket, rec.recorder.runs, names);
    if (result) {
      await refreshTable();
      view.highlight = result.entries.map((e) => e.rank - 1).filter((r) => r < 10);
      tableUntil = game.frame + 900;
      return;
    }
    error = "The score could not be sent. Try again, or skip.";
    if ((await askName("Send your score again? Your name:", error)) === null) return;
  }
}

// ── The loop ─────────────────────────────────────────────────────────────

void refreshTable();
void fetchTicket();

const STEP = 1000 / 60;
let last = performance.now();
let acc = 0;

function step(input: Input): void {
  const wasAttract = game.phase === "attract";
  if (wasAttract && (input.start1 || input.start2)) {
    // The game about to start uses the server's seed if one arrived; otherwise one of its own.
    if (!ticket) game.nextSeed = (Math.random() * 2 ** 32) >>> 0;
  }
  const events = game.step(input);
  for (const e of events) sound.play(e);
  if (wasAttract && game.phase === "ready") {
    recording = { ticket: ticket && game.nextSeed === ticket.seed ? ticket : null, recorder: new Recorder() };
    ticket = null;
    view.highlight = [];
    void fetchTicket();
  }
  if (recording) {
    recording.recorder.push(input);
    if (game.phase === "gameOver") {
      const done = recording;
      recording = null;
      void offerTable(done, game.players.map((p) => p.score));
    }
  }
}

function frame(now: number): void {
  acc = Math.min(acc + (now - last), 250);
  last = now;
  while (acc >= STEP) {
    step(controls.read());
    acc -= STEP;
  }
  if (game.hiScore !== savedHi) { savedHi = game.hiScore; save(HI_KEY, String(savedHi)); }
  // On the title screens: the title for 10 seconds, then the table for 10, unless a score was just entered.
  view.showTable = game.phase === "attract" && (game.frame < tableUntil || Math.floor(game.frame / 600) % 2 === 1);
  setMode();
  render(ctx, game, view);
  requestAnimationFrame(frame);
}
requestAnimationFrame(frame);
