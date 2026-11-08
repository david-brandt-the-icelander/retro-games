// The ways to play: against Stockfish, two players on one device, online with a friend, and
// replaying a finished game. Each builds a GameScreen and returns a function that tears it down.
import { api, ApiError, Live } from "./api";
import { Engine } from "./engine";
import { GameScreen, type Seat } from "./game";
import { LEVELS, type GameView, type Me } from "./shared/protocol";
import { boardOutcome, describe, other, replay, resignation, scoreFor, sideToMove, type Outcome, type Side } from "./shared/rules";
import { sounds } from "./sound";
import { h, put, toast } from "./ui";

export type Cleanup = () => void;

const engine = new Engine();
export const preloadEngine = () => engine.preload();

/** A button that asks "sure?" on the first press and acts on the second. */
function sureButton(label: string, sure: string, act: () => void, cls = "btn"): HTMLButtonElement {
  let armed: ReturnType<typeof setTimeout> | null = null;
  const b = h("button", { class: cls }, label);
  b.addEventListener("click", () => {
    if (armed) { clearTimeout(armed); armed = null; b.textContent = label; b.classList.remove("armed"); act(); return; }
    b.textContent = sure;
    b.classList.add("armed");
    armed = setTimeout(() => { armed = null; b.textContent = label; b.classList.remove("armed"); }, 3000);
  });
  return b;
}

function endSound(o: Outcome, mine: Side | null): void {
  if (o.result === "1/2-1/2") sounds.draw();
  else if (!mine || scoreFor(o.result, mine) === "win") sounds.win();
  else sounds.lose();
}

// ── Against the computer ──

export interface ComputerSave { level: number; color: Side; moves: string[]; outcome: Outcome | null; saved: boolean }
const SAVE_KEY = "chess.computer";
const LOCAL_HISTORY = "chess.history";

export function loadComputer(): ComputerSave | null {
  try {
    const s = JSON.parse(localStorage.getItem(SAVE_KEY) ?? "null") as ComputerSave | null;
    return s && replay(s.moves) ? s : null;
  } catch { return null; }
}
function storeComputer(s: ComputerSave): void {
  try { localStorage.setItem(SAVE_KEY, JSON.stringify(s)); } catch { /* storage blocked */ }
}

/** Finished games against the computer, kept in this browser for players who aren't signed in. */
export function localHistory(): GameView[] {
  try { return JSON.parse(localStorage.getItem(LOCAL_HISTORY) ?? "[]") as GameView[]; } catch { return []; }
}
function addLocalHistory(g: GameView): void {
  try { localStorage.setItem(LOCAL_HISTORY, JSON.stringify([g, ...localHistory()].slice(0, 50))); } catch { /* storage blocked */ }
}

function computerView(s: ComputerSave, me: Me): GameView {
  const you = { id: me.user?.id ?? null, email: me.user?.email ?? null, name: me.user?.name ?? "You" };
  const cpu = { id: null, email: null, name: `Stockfish · ${LEVELS[s.level - 1].name}` };
  const now = Date.now();
  return {
    id: `local-${now}`, kind: "computer", level: s.level, white: s.color === "white" ? you : cpu, black: s.color === "black" ? you : cpu,
    moves: s.moves, result: s.outcome?.result ?? "*", reason: s.outcome?.reason ?? null, drawOffer: null, created: now, updated: now,
  };
}

export function computerGame(host: HTMLElement, save: ComputerSave, me: Me, newGame: () => void): Cleanup {
  const s = { ...save, moves: [...save.moves] };
  const you: Seat = { name: me.user?.name ?? "You" };
  const cpu: Seat = { name: "Stockfish", detail: `Level ${s.level} · ${LEVELS[s.level - 1].name}` };
  const screen = new GameScreen(host, s.color === "white" ? { white: you, black: cpu } : { white: cpu, black: you }, s.color);
  let alive = true;

  const over = () => s.outcome !== null;
  screen.canMove = (turn) => !over() && turn === s.color;

  const end = (o: Outcome) => {
    s.outcome = o;
    storeComputer(s);
    screen.finish(o);
    endSound(o, s.color);
    renderActions();
    if (s.saved) return;
    s.saved = true;
    storeComputer(s);
    if (me.user) {
      api.saveComputer(s.level, s.color, s.moves, o.reason === "resign").catch(() => {
        s.saved = false;
        storeComputer(s);
        toast("Couldn't save this game to your history.", "error");
      });
    } else addLocalHistory(computerView(s, me));
  };

  const afterMove = () => {
    storeComputer(s);
    screen.setMoves(s.moves);
    const r = replay(s.moves)!;
    const o = boardOutcome(r.chess);
    if (o.result !== "*") { end(o); return; }
    if (sideToMove(s.moves.length) === s.color) { screen.status("Your move", "turn"); return; }
    think();
  };

  const think = () => {
    screen.status("Stockfish is thinking…");
    const at = s.moves.length;
    engine.bestMove(s.moves, s.level).then((uci) => {
      if (!alive || s.moves.length !== at || over()) return;
      if (!replay([...s.moves, uci])) { toast("The engine made an odd move; try again.", "error"); return; }
      s.moves.push(uci);
      afterMove();
    }).catch((e) => {
      if (alive && String(e?.message) !== "cancelled") screen.status("The engine couldn't start in this browser.", "bad");
    });
  };

  screen.onMove = (uci) => {
    if (over() || !replay([...s.moves, uci])) { sounds.illegal(); return; }
    s.moves.push(uci);
    afterMove();
  };

  const takeBack = () => {
    if (over()) return;
    engine.cancel();
    // Back to the last position where it was the player's move, before their last move.
    let n = s.moves.length;
    if (sideToMove(n) === s.color) n -= 2; else n -= 1;
    if (n < 0) return;
    s.moves = s.moves.slice(0, n);
    storeComputer(s);
    screen.setMoves(s.moves, false);
    screen.status("Your move", "turn");
  };

  const renderActions = () => {
    put(screen.actions, 
      over() ? null : h("button", { class: "btn", onclick: takeBack }, "Take back"),
      over() ? null : sureButton("Resign", "Sure? Resign", () => { engine.cancel(); end(resignation(s.color)); }, "btn danger"),
      h("button", { class: over() ? "btn primary" : "btn", onclick: () => { engine.cancel(); newGame(); } }, "New game"),
    );
  };

  screen.setMoves(s.moves, false);
  renderActions();
  if (s.outcome) screen.finish(s.outcome);
  else if (sideToMove(s.moves.length) === s.color) screen.status("Your move", "turn");
  else think();

  return () => { alive = false; engine.cancel(); screen.destroy(); };
}

// ── Two players on one device ──

export function localGame(host: HTMLElement): Cleanup {
  let moves: string[] = [];
  let outcome: Outcome | null = null;
  const screen = new GameScreen(host, { white: { name: "White" }, black: { name: "Black" } }, "white");
  screen.canMove = () => outcome === null;
  const update = () => {
    screen.setMoves(moves);
    const o = boardOutcome(replay(moves)!.chess);
    if (o.result !== "*") { outcome = o; screen.finish(o); endSound(o, null); }
    else screen.status(`${sideToMove(moves.length) === "white" ? "White" : "Black"} to move`, "turn");
    actions();
  };
  screen.onMove = (uci) => { if (replay([...moves, uci])) { moves = [...moves, uci]; update(); } };
  const actions = () => put(screen.actions, 
    outcome ? null : h("button", { class: "btn", onclick: () => { moves = moves.slice(0, -1); screen.setMoves(moves, false); update(); } }, "Undo"),
    outcome ? null : sureButton(`${sideToMove(moves.length) === "white" ? "White" : "Black"} resigns`, "Sure? Resign", () => {
      outcome = resignation(sideToMove(moves.length)); screen.finish(outcome); endSound(outcome, null); actions(); screen.render(false);
    }, "btn danger"),
    h("button", { class: outcome ? "btn primary" : "btn", onclick: () => { moves = []; outcome = null; screen.setMoves([], false); update(); } }, "New game"),
  );
  update();
  return () => screen.destroy();
}

// ── Online with a friend ──

export function onlineGame(host: HTMLElement, id: string, me: Me, go: (hash: string) => void): Cleanup {
  const user = me.user!;
  let game: GameView | null = null;
  let screen: GameScreen | null = null;
  let live: Live | null = null;
  let pending = false;
  let alive = true;
  const title = document.title;
  const loading = h("p", { class: "loading" }, "Loading the game…");
  host.append(loading);

  const mySide = (g: GameView): Side => (g.white.id === user.id ? "white" : "black");
  const seat = (p: GameView["white"]): Seat => ({ name: p.name, detail: p.email ?? undefined });

  const apply = (g: GameView) => {
    if (!alive) return;
    const prev = game;
    game = g;
    const side = mySide(g);
    if (!screen) {
      loading.remove();
      screen = new GameScreen(host, { white: seat(g.white), black: seat(g.black) }, side);
      screen.canMove = (turn) => !pending && game!.result === "*" && turn === mySide(game!);
      screen.onMove = move;
      screen.setMoves(g.moves, false);
    } else {
      screen.setMoves(g.moves);
    }
    const opp = side === "white" ? g.black : g.white;
    if (g.result !== "*") {
      screen.finish({ result: g.result, reason: g.reason });
      if (prev && prev.result === "*") endSound({ result: g.result, reason: g.reason }, side);
    } else if (sideToMove(g.moves.length) === side) {
      screen.status("Your move", "turn");
      if (prev && prev.moves.length < g.moves.length && document.hidden) { sounds.notify(); document.title = `♞ Your move · ${title}`; }
    } else screen.status(`Waiting for ${opp.name}…`);

    screen.banner.hidden = !(g.result === "*" && g.drawOffer);
    if (g.result === "*" && g.drawOffer === other(side)) {
      if (prev?.drawOffer !== g.drawOffer) sounds.notify();
      put(screen.banner, 
        h("span", null, `${opp.name} offers a draw.`),
        h("button", { class: "btn small primary", onclick: () => act({ type: "draw-accept" }) }, "Accept"),
        h("button", { class: "btn small", onclick: () => act({ type: "draw-decline" }) }, "Decline"),
      );
    } else if (g.result === "*" && g.drawOffer === side) {
      put(screen.banner, h("span", null, "You offered a draw. Your opponent can accept, or answer with a move."));
    }

    put(screen.actions, 
      g.result === "*" && !g.drawOffer ? h("button", { class: "btn", onclick: () => act({ type: "draw-offer" }) }, "Offer draw") : null,
      g.result === "*" ? sureButton("Resign", "Sure? Resign", () => act({ type: "resign" }), "btn danger") : null,
      g.result !== "*" && opp.email ? h("button", { class: "btn primary", onclick: () => rematch(opp.email!, other(side)) }, "Rematch") : null,
      h("button", { class: "btn", onclick: () => go("#/online") }, "Lobby"),
    );
  };

  const act = (action: Parameters<typeof api.act>[1]) => {
    if (!game) return;
    pending = true;
    api.act(game.id, action).then((r) => { pending = false; apply(r.game); }).catch((e: ApiError) => {
      pending = false;
      toast(e.message, "error");
      const g = e.body?.game as GameView | undefined;
      if (g) apply(g); else if (game) apply(game);
    });
  };

  function move(uci: string): void {
    if (!game || !screen) return;
    const ply = game.moves.length;
    if (!replay([...game.moves, uci])) { sounds.illegal(); return; }
    // Show the move at once; the server's answer confirms it, or puts the board back.
    screen.setMoves([...game.moves, uci]);
    act({ type: "move", uci, ply });
  }

  const rematch = (email: string, color: Side) => {
    api.challenge(email, color).then(() => { toast("Rematch sent! It's waiting in their lobby."); go("#/online"); })
      .catch((e: ApiError) => toast(e.message, "error"));
  };

  const onVisible = () => { if (!document.hidden) document.title = title; };
  document.addEventListener("visibilitychange", onVisible);

  api.game(id).then((r) => {
    apply(r.game);
    if (r.game.result === "*") live = new Live(id, apply, (on) => screen?.root.classList.toggle("offline", !on));
  }).catch((e: ApiError) => { loading.textContent = e.message; });

  return () => {
    alive = false;
    live?.close();
    screen?.destroy();
    loading.remove();
    document.removeEventListener("visibilitychange", onVisible);
    document.title = title;
  };
}

// ── Replaying a finished game ──

export function replayGame(host: HTMLElement, g: GameView, me: Me): Cleanup {
  const blackIsMe = g.kind === "computer" ? g.white.id === null && g.white.name.startsWith("Stockfish") : g.black.id === me.user?.id;
  const mine: Side = blackIsMe ? "black" : "white";
  const seat = (p: GameView["white"]): Seat => ({ name: p.name, detail: p.email ?? undefined });
  const screen = new GameScreen(host, { white: seat(g.white), black: seat(g.black) }, mine);
  screen.setMoves(g.moves, false);
  screen.goto(0);
  screen.status(`${describe({ result: g.result, reason: g.reason }, g.white.name, g.black.name)}. Step through with ◀ ▶`);
  put(screen.actions, h("button", { class: "btn", onclick: () => history.back() }, "Back"));
  return () => screen.destroy();
}
