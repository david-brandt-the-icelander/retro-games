// The page around the Godot game (web/shell.html): starts the engine with a loading screen, and
// gives the game what only the page can do, as window.chessBridge:
//   baseUrl, returnPath, navigate     the game's address, and going to a sign-in page
//   takeChallenge                     an invitation in the address (?challenge=ID), once
//   setTitle, copy                    the tab's title, the clipboard
//   bestMove, cancelEngine, preloadEngine   Stockfish (bridge/engine.ts), for games against the computer
import { Engine as Stockfish } from "./engine";

declare const Engine: new (config: unknown) => { startGame(o: { onProgress(c: number, t: number): void }): Promise<void> };

const stockfish = new Stockfish();
const params = new URLSearchParams(location.search);
const challengeParam = params.get("challenge") ?? "";
let pendingChallenge = /^[a-z0-9]{8,40}$/.test(challengeParam) ? challengeParam : "";

(window as unknown as Record<string, unknown>).chessBridge = {
  baseUrl: () => new URL(".", document.baseURI).href,
  /** Where sign-in should come back to: this page, still holding an invitation that hasn't been seen. */
  returnPath: () => `${location.pathname}${pendingChallenge ? `?challenge=${pendingChallenge}` : ""}`,
  navigate: (url: string) => { location.href = url; },
  takeChallenge: () => {
    const id = pendingChallenge;
    if (id) history.replaceState(null, "", location.pathname);
    return id;
  },
  setTitle: (t: string) => { document.title = t; },
  copy: (t: string) => { void navigator.clipboard?.writeText(t).catch(() => undefined); },
  bestMove: (moves: string, level: number, done: (uci: string) => void) => {
    stockfish.bestMove(moves ? moves.split(" ") : [], level).then(done, (e) => { if (String(e?.message) !== "cancelled") done(""); });
  },
  cancelEngine: () => stockfish.cancel(),
  preloadEngine: () => stockfish.preload(),
};

// ── Start the game ──

const status = document.getElementById("status")!;
const fill = document.getElementById("bar-fill")!;
const notice = document.getElementById("notice")!;
try {
  const config = JSON.parse(document.getElementById("godot-config")!.textContent!);
  const engine = new Engine(config);
  engine.startGame({
    onProgress: (current, total) => { if (total > 0) fill.style.width = `${Math.round((current / total) * 100)}%`; },
  }).then(() => { status.classList.add("done"); setTimeout(() => status.remove(), 600); }, (err: unknown) => {
    notice.textContent = err instanceof Error ? err.message : String(err);
    status.classList.add("failed");
  });
} catch (err) {
  notice.textContent = `This browser can't run the game: ${err instanceof Error ? err.message : String(err)}`;
  status.classList.add("failed");
}
