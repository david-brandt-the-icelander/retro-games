// Dulmál's page: one script for every device. It keeps a WebSocket to the room's Durable Object
// and redraws from each View the room sends; it never decides anything about the game itself.
// The screens: start (make or join a room), join (name, or take back a seat), lobby, game, and
// the big screen's lobby and game. Each screen is a fixed frame of regions; a region is only
// rewritten when its HTML changes, so typing in a text box survives the room's updates.
import qrcode from "qrcode-generator";
import type { CardKind, ClientMsg, GameView, PlayerView, ServerMsg, Team, View } from "../shared/protocol";
import { TEAMS, TIMERS, other } from "../shared/protocol";
import { ERROR, GAME_NAME, HOW_TO, T, TEAM_NAME } from "./text";

// ── Where we are ──

const BASE = location.pathname.replace(/\/(index\.html)?$/, "").replace(/\/$/, "");
const params = new URLSearchParams(location.search);
const code = (params.get("herbergi") ?? "").toUpperCase().replace(/[^A-Z]/g, "").slice(0, 4);
const wantScreen = params.get("skjar") === "1";
const joinUrl = (c: string) => `${location.origin}${BASE}/?herbergi=${c}`;

const app = document.getElementById("app")!;
const seatKey = `dulmal:seat:${code}`;

interface Seat { id: string; token: string }
function loadSeat(): Seat | null {
  try { const s = JSON.parse(localStorage.getItem(seatKey) ?? "null"); return s && s.id && s.token ? s : null; } catch { return null; }
}
function storeSeat(s: Seat | null): void {
  try { if (s) localStorage.setItem(seatKey, JSON.stringify(s)); else localStorage.removeItem(seatKey); } catch { /* private mode */ }
}
const lastName = {
  get: () => { try { return localStorage.getItem("dulmal:name") ?? ""; } catch { return ""; } },
  set: (n: string) => { try { localStorage.setItem("dulmal:name", n); } catch { /* private mode */ } },
};

let seat = loadSeat();
let view: View | null = null;
let gone = false;
let connected = false;
let everConnected = false;
let clockOffset = 0; // room clock minus ours
let picked: number | null = null;
let clueNumber: number | null = null;
let menuOpen = false;
let qrOpen = false;
let toastTimer = 0;
let screenMode = wantScreen;

// ── Small helpers ──

const esc = (s: string): string => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
const plain = (w: string) => w.replace(/\|/g, "");
const $ = <E extends HTMLElement = HTMLElement>(sel: string) => document.querySelector<E>(sel);

/** Rewrites a region only when its content changed. Returns whether it did. */
function patch(id: string, html: string): boolean {
  const el = document.getElementById(id);
  if (!el || el.dataset.html === html) return false;
  el.innerHTML = html;
  el.dataset.html = html;
  return true;
}

function toast(text: string): void {
  let el = $("#toast");
  if (!el) { el = document.createElement("div"); el.id = "toast"; el.setAttribute("role", "alert"); document.body.append(el); }
  el.textContent = text;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = window.setTimeout(() => el!.classList.remove("show"), 4000);
}

const ICON: Record<CardKind, string> = {
  hraun: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M1.5 22 8.5 10h7l7 12z" fill="currentColor"/><path d="M12 8V5M8.5 6.5 7 4.5M15.5 6.5 17 4.5" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/></svg>`,
  jokull: `<svg viewBox="0 0 24 24" aria-hidden="true" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"><path d="M12 2v20M3.3 7l17.4 10M3.3 17 20.7 7M9 3.5l3 2 3-2M9 20.5l3-2 3 2"/></svg>`,
  neutral: `<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="12" cy="12" r="5" fill="none" stroke="currentColor" stroke-width="2.4"/></svg>`,
  ghost: `<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4.5 22V10.5a7.5 7.5 0 0 1 15 0V22l-2.6-2-2.4 2-2.5-2-2.5 2-2.4-2z" fill="currentColor"/><circle cx="9.3" cy="10.8" r="1.6" fill="#1b1325"/><circle cx="14.7" cy="10.8" r="1.6" fill="#1b1325"/></svg>`,
};
const teamIcon = (t: Team) => `<span class="ticon">${ICON[t]}</span>`;

// ── Connection ──

let ws: WebSocket | null = null;
let retry = 0;
let retryTimer = 0;
let pingTimer = 0;

function send(msg: ClientMsg): void {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
  else toast(T.reconnecting);
}

function connect(): void {
  if (!code || gone) return;
  clearTimeout(retryTimer);
  const url = `${location.protocol === "https:" ? "wss" : "ws"}://${location.host}${BASE}/api/rooms/${code}/ws`;
  const sock = new WebSocket(url);
  ws = sock;
  sock.onopen = () => {
    connected = true; everConnected = true; retry = 0;
    sock.send(JSON.stringify({ t: "hello", seat: screenMode ? null : seat, screen: screenMode } satisfies ClientMsg));
    clearInterval(pingTimer);
    pingTimer = window.setInterval(() => { if (sock.readyState === WebSocket.OPEN) sock.send("ping"); }, 25000);
    render();
  };
  sock.onmessage = (e) => {
    if (e.data === "pong") return;
    let msg: ServerMsg;
    try { msg = JSON.parse(String(e.data)); } catch { return; }
    receive(msg);
  };
  sock.onclose = () => {
    if (ws !== sock) return;
    connected = false;
    clearInterval(pingTimer);
    render();
    if (gone) return;
    retry = Math.min(retry + 1, 6);
    retryTimer = window.setTimeout(connect, Math.min(1000 * 2 ** (retry - 1), 10000));
  };
}

// A phone that wakes up reconnects at once rather than waiting out the back-off.
document.addEventListener("visibilitychange", () => {
  if (document.visibilityState === "visible" && code && !gone && (!ws || ws.readyState === WebSocket.CLOSED)) { retry = 0; connect(); }
});
window.addEventListener("online", () => { if (code && !gone && (!ws || ws.readyState !== WebSocket.OPEN)) { retry = 0; connect(); } });

function receive(msg: ServerMsg): void {
  switch (msg.t) {
    case "state": {
      const before = view;
      view = msg.view;
      clockOffset = msg.view.now - Date.now();
      // A selection that no longer makes sense (the card came up, or the turn moved on) is dropped.
      const g = view.game;
      if (picked !== null && (!g || g.phase !== "guess" || g.cards[picked]?.revealed || !canGuess(view))) picked = null;
      if (!g || g.phase !== "clue") clueNumber = null;
      if (g && before?.game && before.game.number !== g.number) { picked = null; menuOpen = false; }
      if (!g) menuOpen = false;
      if (view.you) lastName.set(view.you.name);
      render();
      break;
    }
    case "seat": seat = { id: msg.id, token: msg.token }; storeSeat(seat); break;
    case "unseated": seat = null; storeSeat(null); render(); break;
    case "error": toast(ERROR[msg.code] ?? ERROR.bad); break;
    case "gone": gone = true; render(); break;
  }
}

// ── What this device may do ──

const me = (v: View): PlayerView | null => v.you;
const isHost = (v: View) => !!v.you && v.hostId === v.you.id;
const hostName = (v: View) => v.players.find((p) => p.id === v.hostId)?.name ?? "";
function canGuess(v: View): boolean {
  const g = v.game, you = me(v);
  return !!g && !!you && g.phase === "guess" && you.team === g.turn && you.role === "guess";
}
const isClueGiverNow = (v: View) => !!v.game && !!v.you && v.game.phase === "clue" && v.you.team === v.game.turn && v.you.role === "clue";

// ── Rendering ──

let frame = "";

/** Puts up a screen's frame (its fixed regions) when the screen changes. */
function setFrame(name: string, html: string): void {
  if (frame === name) return;
  frame = name;
  app.innerHTML = html;
  app.dataset.screen = name;
  window.scrollTo(0, 0);
}

function render(): void {
  document.body.classList.toggle("offline", !!code && !connected && everConnected && !gone);
  if (!code) return renderHome();
  if (gone) return renderGone();
  if (!view) {
    setFrame("connecting", `<main class="center"><div class="logo-sm">${logo()}</div><p class="big-note">${T.connecting}</p></main>`);
    return;
  }
  if (view.screen) return view.game ? renderScreenGame(view) : renderScreenLobby(view);
  if (!view.you) return renderJoin(view);
  if (!view.game) return renderLobby(view);
  return renderGame(view);
}

const logo = () => `<span class="logo" aria-label="${GAME_NAME}"><svg class="aurora" viewBox="0 0 120 30" aria-hidden="true"><path d="M2 22C20 4 38 26 60 12S100 2 118 14" fill="none" stroke="url(#ag)" stroke-width="5" stroke-linecap="round"/><defs><linearGradient id="ag" x1="0" x2="1"><stop offset="0" stop-color="#4fe3a3"/><stop offset=".55" stop-color="#7fd6ff"/><stop offset="1" stop-color="#b08cff"/></linearGradient></defs></svg><span>${GAME_NAME}</span></span>`;

const reconnectBar = `<div class="reconnect" role="status">${T.reconnecting}</div>`;

function howTo(): string {
  return `<details class="howto" open><summary>${T.howTo}</summary><ol>${HOW_TO.map((l) => `<li>${esc(l)}</li>`).join("")}</ol></details>`;
}

// Start page

function renderHome(): void {
  setFrame("home", `
    <main class="home">
      <header class="hero">${logo()}<p class="tagline">${T.tagline}</p></header>
      <section class="panel">
        <h2>${T.newGame}</h2>
        <form id="create-form" class="stack">
          <label for="create-name">${T.yourName}</label>
          <input id="create-name" maxlength="20" autocomplete="nickname" placeholder="${T.namePlaceholder}" value="${esc(lastName.get())}" required>
          <button class="btn primary" type="submit" id="create-btn">${T.createRoom}</button>
        </form>
      </section>
      <section class="panel">
        <h2>${T.joinGame}</h2>
        <form id="code-form" class="stack">
          <label for="code-input">${T.roomCode}</label>
          <input id="code-input" class="code-input" maxlength="4" autocomplete="off" autocapitalize="characters" spellcheck="false" placeholder="${T.codePlaceholder}" required>
          <button class="btn" type="submit">${T.go}</button>
        </form>
      </section>
      ${howTo()}
    </main>`);
}

function renderGone(): void {
  setFrame("gone", `<main class="center"><div class="logo-sm">${logo()}</div><p class="big-note">${T.noRoom}</p><a class="btn primary" href="${BASE}/">${T.toStart}</a></main>`);
}

// Joining

function renderJoin(v: View): void {
  setFrame("join", `
    ${reconnectBar}
    <main class="home">
      <header class="hero small">${logo()}<p class="room-title">${T.room(esc(v.code))}</p></header>
      <section class="panel">
        <form id="join-form" class="stack">
          <label for="join-name">${T.whatName}</label>
          <input id="join-name" maxlength="20" autocomplete="nickname" placeholder="${T.namePlaceholder}" value="${esc(lastName.get())}" required>
          <button class="btn primary" type="submit">${T.join}</button>
        </form>
      </section>
      <section class="panel" id="claim"></section>
      <section class="panel muted">
        <h2>${T.bigScreen}</h2>
        <p>${T.bigScreenHint}</p>
        <button class="btn" data-act="screen">${T.useAsScreen}</button>
      </section>
      ${howTo()}
    </main>`);
  const away = v.players.filter((p) => !p.online);
  const claim = $("#claim")!;
  claim.hidden = away.length === 0;
  patch("claim", away.length ? `<p>${T.rejoin}</p><div class="chips">${away.map((p) => `<button class="btn chip t-${p.team}" data-act="claim" data-id="${p.id}">${teamIcon(p.team)}${esc(p.name)}</button>`).join("")}</div>` : "");
}

// Lobby

function playerRow(v: View, p: PlayerView): string {
  const you = v.you!;
  const host = isHost(v);
  const self = p.id === you.id;
  const tags = [
    self ? `<span class="tag you">${T.you}</span>` : "",
    p.id === v.hostId ? `<span class="tag">${T.host}</span>` : "",
    p.online ? "" : `<span class="tag away">${T.away}</span>`,
  ].join("");
  const actions: string[] = [];
  if (self || host) actions.push(`<button class="btn small" data-act="team" data-id="${p.id}" data-team="${other(p.team)}">${T.switchTeam}</button>`);
  if (p.role === "guess" && (self || host)) actions.push(`<button class="btn small" data-act="clueGiver" data-id="${p.id}">${self ? T.becomeClueGiver : T.makeClueGiver}</button>`);
  if (host && !self && !p.online) actions.push(`<button class="btn small danger" data-act="remove" data-id="${p.id}">${T.removePlayer}</button>`);
  return `<li class="player ${p.online ? "" : "is-away"}">
    <div class="pname"><span class="dot ${p.online ? "on" : ""}"></span><strong>${esc(p.name)}</strong>${tags}</div>
    <div class="prole">${p.role === "clue" ? `<span class="role clue">${T.clueGiver}</span>` : `<span class="role">${T.guesser}</span>`}</div>
    ${actions.length ? `<div class="pactions">${actions.join("")}</div>` : ""}
  </li>`;
}

function teamsHtml(v: View, rows: (p: PlayerView) => string): string {
  return TEAMS.map((t) => {
    const list = v.players.filter((p) => p.team === t);
    return `<section class="team t-${t}">
      <h3>${teamIcon(t)}${TEAM_NAME[t]} <span class="count">${list.length}</span></h3>
      <ul class="plist">${list.map(rows).join("") || `<li class="empty">—</li>`}</ul>
    </section>`;
  }).join("");
}

function qrSvg(url: string): string {
  const qr = qrcode(0, "M");
  qr.addData(url);
  qr.make();
  return qr.createSvgTag({ cellSize: 6, margin: 2, scalable: true });
}

function renderLobby(v: View): void {
  setFrame("lobby", `
    ${reconnectBar}
    <main class="lobby">
      <header class="bar">${logo()}<div class="room-code" aria-label="${T.roomCode}">${esc(v.code)}</div></header>
      <section class="panel invite">
        <h2>${T.invite}</h2>
        <p>${T.inviteHint}</p>
        <div class="link-row"><code id="join-url">${esc(joinUrl(v.code))}</code></div>
        <div class="row">
          <button class="btn" data-act="copy">${T.copyLink}</button>
          ${typeof navigator.share === "function" ? `<button class="btn" data-act="share">${T.share}</button>` : ""}
          <button class="btn" data-act="qr" id="qr-btn">${T.showQr}</button>
        </div>
        <div id="qr" class="qr" hidden></div>
        <p class="hint">${T.screenTip}</p>
      </section>
      <div id="you"></div>
      <h2 class="section-title">${T.teams}</h2>
      <div id="teams" class="teams"></div>
      <div id="lobby-actions" class="panel actions"></div>
      <section id="settings" class="panel" hidden>
        <h2>${T.settings}</h2>
        <label for="timer-select">${T.timer}</label>
        <select id="timer-select">${TIMERS.map((s) => `<option value="${s}">${s ? T.timerChoice(s) : T.timerOff}</option>`).join("")}</select>
        <h3>${T.wordList}</h3>
        <p id="list-state"></p>
        <label for="words-input">${T.pasteHint}</label>
        <textarea id="words-input" rows="5" spellcheck="false"></textarea>
        <div class="row">
          <button class="btn" data-act="words">${T.useMyList}</button>
          <button class="btn" data-act="builtin" id="builtin-btn">${T.useBuiltin}</button>
        </div>
      </section>
      ${howTo()}
      <div class="footer-actions"><button class="btn small ghostbtn" data-act="leave">${T.leave}</button></div>
    </main>`);
  const you = v.you!;
  patch("you", `<form id="rename-form" class="rename"><label for="rename-input">${T.rename}</label><div class="row"><input id="rename-input" maxlength="20" value="${esc(you.name)}"><button class="btn small" type="submit">${T.save}</button></div></form>`);
  patch("teams", teamsHtml(v, (p) => playerRow(v, p)));
  const host = isHost(v);
  const ok = TEAMS.every((t) => v.players.some((p) => p.team === t && p.role === "clue") && v.players.some((p) => p.team === t && p.role === "guess"));
  patch("lobby-actions", host
    ? `<button class="btn primary huge" data-act="start" ${ok ? "" : "disabled"}>${T.start}</button>
       ${ok ? "" : `<p class="hint">${T.needTeams}</p>`}
       <button class="btn" data-act="shuffle">${T.shuffle}</button>`
    : `<p class="big-note">${esc(T.waitForHost(hostName(v)))}</p>${ok ? "" : `<p class="hint">${T.needTeams}</p>`}`);
  const settings = $("#settings")!;
  settings.hidden = !host;
  const sel = $<HTMLSelectElement>("#timer-select");
  if (sel && document.activeElement !== sel) sel.value = String(v.timer);
  patch("list-state", v.customWords ? T.customList(v.customWords) : T.builtinList);
  const b = $<HTMLButtonElement>("#builtin-btn");
  if (b) b.hidden = !v.customWords;
}

// The game, on a player's device

function cardHtml(v: View, g: GameView, i: number, big: boolean): string {
  const c = g.cards[i]!;
  const tappable = !big && canGuess(v) && !c.revealed;
  const cls = ["card"];
  if (c.revealed) cls.push("revealed", `k-${c.kind}`);
  else if (c.kind) cls.push("key", `k-${c.kind}`);
  if (tappable) cls.push("tap");
  if (picked === i) cls.push("picked");
  if (g.event?.type === "guess" && g.event.index === i) cls.push("last");
  const label = `${plain(c.word)}${c.kind ? `, ${T.kind[c.kind]}` : ""}`;
  const icon = c.kind ? `<i class="cicon">${ICON[c.kind]}</i>` : "";
  return `<button class="${cls.join(" ")}" data-act="pick" data-i="${i}" ${tappable ? "" : `aria-disabled="true"`} aria-label="${esc(label)}"><span class="w" data-w="${esc(c.word)}">${esc(plain(c.word))}</span>${icon}</button>`;
}

function boardHtml(v: View, g: GameView, big: boolean): string {
  return g.cards.map((_, i) => cardHtml(v, g, i, big)).join("");
}

function scoreHtml(g: GameView): string {
  return TEAMS.map((t) => `<div class="score t-${t} ${g.turn === t && g.phase !== "over" ? "on" : ""}">${teamIcon(t)}<span class="sname">${TEAM_NAME[t]}</span><span class="snum">${g.remaining[t]}</span><span class="sleft">${T.left}</span></div>`).join("");
}

function eventText(g: GameView): string {
  const e = g.event;
  if (!e) return "";
  if (e.type === "clue") return "";
  if (e.type === "stop") return T.stopped(e.team);
  if (e.type === "timeout") return T.timeout(e.team);
  const c = g.cards[e.index]!;
  const w = plain(c.word);
  if (c.kind === "ghost") return T.ghostPicked(e.by, w);
  if (c.kind === e.team) return T.right(e.by, w);
  if (c.kind === "neutral") return T.neutral(e.by, w);
  return T.theirs(e.by, w, other(e.team));
}

function statusText(v: View, g: GameView): string {
  const you = v.you!;
  if (g.phase === "clue") {
    if (you.team === g.turn && you.role === "clue") return T.youGiveClue;
    if (you.team === g.turn) return T.teammateThinking;
    return T.otherThinking(g.turn);
  }
  if (you.team === g.turn) return you.role === "guess" ? T.yourTurnGuess : T.teamGuessing;
  return T.otherGuessing(g.turn);
}

const clueHtml = (g: GameView) => g.clue
  ? `<div class="clue t-${g.clue.team}"><span class="clabel">${T.clueLabel}</span><span class="cword">${esc(g.clue.word)}</span><span class="cnum">${g.clue.number}</span></div>`
  : "";

const countdownHtml = (g: GameView) => g.deadline !== null && g.phase !== "over"
  ? `<span class="countdown" data-deadline="${g.deadline}" aria-label="${T.timeLeft}"></span>` : "";

function overHtml(v: View, g: GameView): string {
  const w = g.winner!;
  const sub = g.ghost ? T.lostGhost(other(w)) : T.wonAll(w);
  const buttons = isHost(v)
    ? `<button class="btn primary huge" data-act="newGame">${T.playAgain}</button><button class="btn" data-act="lobby">${T.changeTeams}</button>`
    : `<p class="hint">${esc(T.hostCanRestart(hostName(v)))}</p>`;
  return `<div class="over t-${w}"><div class="otitle">${teamIcon(w)}${T.wins(w)}</div><p>${esc(sub)}</p>${v.screen ? "" : buttons}</div>`;
}

function actionHtml(v: View, g: GameView): string {
  if (g.phase === "over") return overHtml(v, g);
  if (isClueGiverNow(v)) {
    return `<form id="clue-form" class="clue-form">
      <label for="clue-word">${T.clueWord}</label>
      <input id="clue-word" maxlength="30" autocomplete="off" autocapitalize="sentences" spellcheck="false" placeholder="${T.cluePlaceholder}" enterkeyhint="done">
      <span class="label">${T.clueNumber}</span>
      <div class="numbers">${[1, 2, 3, 4, 5, 6, 7, 8, 9].map((n) => `<button type="button" class="num" data-act="num" data-n="${n}">${n}</button>`).join("")}</div>
      <button class="btn primary huge" type="submit" id="clue-send">${T.sendClue}</button>
    </form>`;
  }
  if (canGuess(v)) {
    if (picked !== null) {
      const w = plain(g.cards[picked]!.word);
      return `<div class="confirm"><p class="ctext">${esc(T.pick(w))}</p><div class="row"><button class="btn primary huge" data-act="confirm">${T.yesPick}</button><button class="btn" data-act="unpick">${T.cancel}</button></div></div>`;
    }
    return `<div class="guessbar"><span class="gleft">${T.guessesLeft(g.left)}</span><button class="btn" data-act="stop" ${g.made ? "" : "disabled"}>${T.stopGuessing}</button></div>`;
  }
  if (g.phase === "guess") return `<div class="guessbar quiet"><span class="gleft">${T.guessesLeft(g.left)}</span></div>`;
  return "";
}

function menuHtml(v: View, g: GameView): string {
  const host = isHost(v);
  const clues = g.clues.length
    ? `<ol class="clue-log">${g.clues.map((c) => `<li class="t-${c.team}">${teamIcon(c.team)}<strong>${esc(c.word)}</strong> ${c.number}</li>`).join("")}</ol>`
    : `<p class="hint">${T.noClues}</p>`;
  const rows = (p: PlayerView) => `<li class="player ${p.online ? "" : "is-away"}"><div class="pname"><span class="dot ${p.online ? "on" : ""}"></span><strong>${esc(p.name)}</strong>${p.id === v.you?.id ? `<span class="tag you">${T.you}</span>` : ""}${p.online ? "" : `<span class="tag away">${T.away}</span>`}</div><div class="prole">${p.role === "clue" ? `<span class="role clue">${T.clueGiver}</span>` : `<span class="role">${T.guesser}</span>`}</div></li>`;
  return `<div class="menu-inner">
    <div class="menu-head"><h2>${T.menu}</h2><button class="btn small" data-act="menu">${T.close}</button></div>
    <h3>${T.clues}</h3>${clues}
    <h3>${T.players}</h3><div class="teams compact">${teamsHtml(v, rows)}</div>
    ${host ? `<h3>${T.settings}</h3>
      <label for="timer-select-g">${T.timer}</label>
      <select id="timer-select-g">${TIMERS.map((s) => `<option value="${s}" ${s === v.timer ? "selected" : ""}>${s ? T.timerChoice(s) : T.timerOff}</option>`).join("")}</select>
      <div class="stack"><button class="btn" data-act="newGameAsk">${T.newBoard}</button><button class="btn" data-act="lobbyAsk">${T.backToTeams}</button></div>` : ""}
    <p class="room-line">${T.room(esc(v.code))} · <code>${esc(joinUrl(v.code))}</code></p>
    <button class="btn small ghostbtn" data-act="leave">${T.leave}</button>
  </div>`;
}

function renderGame(v: View): void {
  const g = v.game!;
  setFrame("game", `
    ${reconnectBar}
    <main class="game">
      <header class="gtop">
        <div id="scores" class="scores"></div>
        <button class="btn small menu-btn" data-act="menu" aria-label="${T.menu}">☰</button>
      </header>
      <div id="turn" class="turn"></div>
      <div id="clue"></div>
      <div id="board" class="board"></div>
      <div id="event" class="event" aria-live="polite"></div>
      <div id="action" class="action"></div>
      <aside id="menu" class="menu" hidden></aside>
    </main>`);
  const you = v.you!;
  document.body.dataset.team = you.team;
  document.body.dataset.role = you.role;
  patch("scores", scoreHtml(g));
  patch("turn", g.phase === "over" ? "" : `<div class="tbanner t-${g.turn}">${teamIcon(g.turn)}<span class="tname">${T.onTurn(g.turn)}</span>${countdownHtml(g)}</div><p class="status ${you.team === g.turn ? "mine" : ""}">${esc(statusText(v, g))}</p>`);
  patch("clue", clueHtml(g));
  if (patch("board", boardHtml(v, g, false))) fitBoard();
  $("#board")!.classList.toggle("clue-view", you.role === "clue");
  patch("event", esc(eventText(g)));
  patch("action", actionHtml(v, g));
  document.querySelectorAll<HTMLButtonElement>(".num").forEach((b) => b.classList.toggle("on", Number(b.dataset.n) === clueNumber));
  const menu = $("#menu")!;
  menu.hidden = !menuOpen;
  if (menuOpen) patch("menu", menuHtml(v, g));
  tick();
}

// The big screen

function renderScreenLobby(v: View): void {
  setFrame("screen-lobby", `
    ${reconnectBar}
    <main class="screen slobby">
      <header class="sbar">${logo()}</header>
      <div class="sjoin">
        <div class="qr big" id="sqr"></div>
        <div>
          <p class="scan">${T.scanToJoin}</p>
          <p class="sorurl">${T.orOpen} <strong>${esc(location.host + BASE)}</strong> ${T.andEnterCode}</p>
          <div class="room-code huge">${esc(v.code)}</div>
        </div>
      </div>
      <div id="steams" class="teams"></div>
      <div class="howto-screen"><h2>${T.howTo}</h2><ol>${HOW_TO.map((l) => `<li>${esc(l)}</li>`).join("")}</ol></div>
    </main>`);
  patch("sqr", qrSvg(joinUrl(v.code)));
  const rows = (p: PlayerView) => `<li class="player ${p.online ? "" : "is-away"}"><div class="pname"><strong>${esc(p.name)}</strong></div><div class="prole">${p.role === "clue" ? `<span class="role clue">${T.clueGiver}</span>` : ""}</div></li>`;
  patch("steams", teamsHtml(v, rows));
}

function renderScreenGame(v: View): void {
  const g = v.game!;
  setFrame("screen-game", `
    ${reconnectBar}
    <main class="screen sgame">
      <div id="sboard" class="board big"></div>
      <aside class="sside">
        <div class="sbar">${logo()}<span class="room-code">${esc(v.code)}</span></div>
        <div id="sscores" class="scores"></div>
        <div id="sturn"></div>
        <div id="sclue"></div>
        <div id="sevent" class="event"></div>
        <div id="sover"></div>
      </aside>
    </main>`);
  if (patch("sboard", boardHtml(v, g, true))) fitBoard();
  patch("sscores", scoreHtml(g));
  patch("sturn", g.phase === "over" ? "" : `<div class="tbanner t-${g.turn}">${teamIcon(g.turn)}<span class="tname">${T.onTurn(g.turn)}</span>${countdownHtml(g)}</div>
    <p class="status">${g.phase === "clue" ? esc(T.otherThinking(g.turn)) : esc(T.guessesLeft(g.left))}</p>`);
  patch("sclue", clueHtml(g));
  patch("sevent", esc(eventText(g)));
  patch("sover", g.phase === "over" ? overHtml(v, g) : "");
  tick();
}

// ── Fitting long words into cards ──

const measureCtx = document.createElement("canvas").getContext("2d");

/** The largest font size (px) at which the word fits its card, on one line or split at a "|" mark. */
function fitWord(span: HTMLElement, width: number, height: number, max: number): void {
  const word = span.dataset.w ?? "";
  const family = getComputedStyle(span).fontFamily;
  const measure = (text: string, size: number) => {
    if (!measureCtx) return text.length * size * 0.6;
    measureCtx.font = `700 ${size}px ${family}`;
    return measureCtx.measureText(text).width;
  };
  const whole = plain(word);
  const one = Math.min(max, height * 0.62, (width / measure(whole, 100)) * 100);
  let best = { size: one, html: esc(whole) };
  const parts = word.split("|");
  for (let i = 1; i < parts.length; i++) {
    const a = parts.slice(0, i).join("") + "-", b = parts.slice(i).join("");
    const size = Math.min(max, height * 0.45, (width / Math.max(measure(a, 100), measure(b, 100))) * 100);
    if (size > best.size * 1.08) best = { size, html: `${esc(a)}<br>${esc(b)}` };
  }
  span.innerHTML = best.html;
  span.style.fontSize = `${Math.floor(best.size * 10) / 10}px`;
}

function fitBoard(): void {
  const cards = document.querySelectorAll<HTMLElement>(".board .card");
  if (!cards.length) return;
  const first = cards[0]!;
  const box = first.getBoundingClientRect();
  const big = !!first.closest(".big");
  const width = box.width - (big ? 24 : 6);
  const height = box.height - (big ? 16 : 6);
  const max = big ? Math.min(64, box.height * 0.4) : Math.min(26, box.height * 0.42);
  cards.forEach((c) => { const s = c.querySelector<HTMLElement>(".w"); if (s) fitWord(s, width, height, max); });
}

let resizeTimer = 0;
window.addEventListener("resize", () => { clearTimeout(resizeTimer); resizeTimer = window.setTimeout(fitBoard, 120); });

// ── The turn timer ──

function tick(): void {
  document.querySelectorAll<HTMLElement>(".countdown").forEach((el) => {
    const left = Math.max(0, Math.ceil((Number(el.dataset.deadline) - (Date.now() + clockOffset)) / 1000));
    el.textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, "0")}`;
    el.classList.toggle("low", left <= 10);
  });
}
window.setInterval(tick, 500);

// ── Input ──

async function createRoom(name: string): Promise<void> {
  const btn = $<HTMLButtonElement>("#create-btn");
  if (btn) { btn.disabled = true; btn.textContent = T.creating; }
  try {
    const res = await fetch(`${BASE}/api/rooms`, { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name }) });
    if (!res.ok) throw new Error(String(res.status));
    const r = (await res.json()) as { code: string; id: string; token: string };
    localStorage.setItem(`dulmal:seat:${r.code}`, JSON.stringify({ id: r.id, token: r.token }));
    lastName.set(name);
    location.href = `${BASE}/?herbergi=${r.code}`;
  } catch {
    toast(ERROR.bad);
    if (btn) { btn.disabled = false; btn.textContent = T.createRoom; }
  }
}

document.addEventListener("submit", (e) => {
  const form = e.target as HTMLFormElement;
  e.preventDefault();
  const val = (id: string) => ($<HTMLInputElement>(id)?.value ?? "").trim();
  switch (form.id) {
    case "create-form": { const n = val("#create-name"); if (n) void createRoom(n); else toast(ERROR.name); break; }
    case "code-form": {
      const c = val("#code-input").toUpperCase().replace(/[^A-Z]/g, "");
      if (c.length === 4) location.href = `${BASE}/?herbergi=${c}`; else toast(ERROR.noRoom);
      break;
    }
    case "join-form": { const n = val("#join-name"); if (n) send({ t: "join", name: n }); else toast(ERROR.name); break; }
    case "rename-form": { const n = val("#rename-input"); if (n && n !== view?.you?.name) send({ t: "name", name: n }); break; }
    case "clue-form": {
      const w = val("#clue-word");
      if (!w || /\s/.test(w)) { toast(ERROR.clueWord); break; }
      if (clueNumber === null) { toast(ERROR.clueNumber); break; }
      send({ t: "clue", word: w, number: clueNumber });
      break;
    }
  }
});

document.addEventListener("change", (e) => {
  const el = e.target as HTMLElement;
  if (el.id === "timer-select" || el.id === "timer-select-g") send({ t: "timer", seconds: Number((el as HTMLSelectElement).value) });
});

document.addEventListener("click", (e) => {
  const el = (e.target as HTMLElement).closest<HTMLElement>("[data-act]");
  if (!el || (el as HTMLButtonElement).disabled) return;
  const v = view;
  const id = el.dataset.id ?? "";
  switch (el.dataset.act) {
    case "screen": screenMode = true; send({ t: "screen" }); history.replaceState(null, "", `${BASE}/?herbergi=${code}&skjar=1`); break;
    case "claim": send({ t: "claim", id }); break;
    case "team": send({ t: "team", id, team: el.dataset.team as Team }); break;
    case "clueGiver": send({ t: "clueGiver", id }); break;
    case "remove": send({ t: "remove", id }); break;
    case "shuffle": send({ t: "shuffle" }); break;
    case "start": send({ t: "start" }); break;
    case "newGame": send({ t: "newGame" }); break;
    case "lobby": send({ t: "lobby" }); break;
    case "newGameAsk": if (confirm(T.newBoardConfirm)) send({ t: "newGame" }); break;
    case "lobbyAsk": if (confirm(T.backToTeamsConfirm)) send({ t: "lobby" }); break;
    case "leave": if (confirm(T.leaveConfirm)) send({ t: "leave" }); break;
    case "words": {
      const text = $<HTMLTextAreaElement>("#words-input")?.value ?? "";
      send({ t: "words", text });
      toast(T.listSaved);
      break;
    }
    case "builtin": send({ t: "words", text: null }); break;
    case "copy": {
      const url = joinUrl(code);
      navigator.clipboard?.writeText(url).then(() => toast(T.copied), () => toast(url));
      break;
    }
    case "share": navigator.share?.({ title: GAME_NAME, text: T.room(code), url: joinUrl(code) }).catch(() => undefined); break;
    case "qr": {
      qrOpen = !qrOpen;
      const box = $("#qr")!;
      box.hidden = !qrOpen;
      if (qrOpen) box.innerHTML = qrSvg(joinUrl(code));
      el.textContent = qrOpen ? T.hideQr : T.showQr;
      break;
    }
    case "menu": menuOpen = !menuOpen; render(); if (menuOpen) $("#menu")?.scrollTo(0, 0); break;
    case "num": clueNumber = Number(el.dataset.n); render(); break;
    case "pick": {
      if (!v || !canGuess(v)) return;
      const i = Number(el.dataset.i);
      if (v.game!.cards[i]?.revealed) return;
      picked = picked === i ? null : i;
      render();
      $("#action")?.scrollIntoView({ block: "nearest", behavior: "smooth" });
      break;
    }
    case "unpick": picked = null; render(); break;
    case "confirm": if (picked !== null) { send({ t: "guess", index: picked }); picked = null; render(); } break;
    case "stop": send({ t: "stop" }); break;
  }
});

render();
connect();
