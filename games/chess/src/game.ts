// The game screen, shared by every way of playing: the board between two name plates, the
// moves so far, and the buttons for this kind of game. A Mode decides who may move and what
// a move does (src/modes.ts).
import { Chess, type Move } from "chess.js";
import { Board } from "./board";
import { describe, replay, sideToMove, type Outcome, type Side } from "./shared/rules";
import type { PieceColor, PieceType } from "./sprites";
import { h, pieceIcon, put } from "./ui";

export interface Seat { name: string; detail?: string }

const VALUE: Record<string, number> = { p: 1, n: 3, b: 3, r: 5, q: 9, k: 0 };
const START_COUNT: Record<string, number> = { p: 8, n: 2, b: 2, r: 2, q: 1 };

export class GameScreen {
  readonly root: HTMLElement;
  readonly board: Board;
  private moves: string[] = [];
  private san: string[] = [];
  /** The position being looked at: null for the latest, otherwise how many moves in. */
  private view: number | null = null;
  private plates: Record<Side, HTMLElement>;
  private list: HTMLOListElement;
  private statusEl: HTMLElement;
  readonly actions: HTMLElement;
  readonly banner: HTMLElement;
  private navLabel: HTMLElement;
  /** May the player move now? Asked after every change. */
  canMove: (turn: Side) => boolean = () => false;
  onMove: (uci: string) => void = () => undefined;

  constructor(host: HTMLElement, private seats: Record<Side, Seat>, orientation: Side) {
    this.plates = { white: h("div", { class: "plate" }), black: h("div", { class: "plate" }) };
    const boardHost = h("div", { class: "board-host" });
    this.statusEl = h("p", { class: "status", role: "status", "aria-live": "polite" });
    this.list = h("ol", { class: "moves", "aria-label": "Moves" });
    this.actions = h("div", { class: "actions" });
    this.banner = h("div", { class: "banner", hidden: true });
    this.navLabel = h("span", { class: "nav-label" });
    const nav = h("div", { class: "nav" },
      h("button", { class: "btn small", title: "First position", "aria-label": "First position", onclick: () => this.goto(0) }, "|◀"),
      h("button", { class: "btn small", title: "Back one move", "aria-label": "Back one move", onclick: () => this.step(-1) }, "◀"),
      this.navLabel,
      h("button", { class: "btn small", title: "Forward one move", "aria-label": "Forward one move", onclick: () => this.step(1) }, "▶"),
      h("button", { class: "btn small", title: "Latest position", "aria-label": "Latest position", onclick: () => this.goto(null) }, "▶|"),
      h("button", { class: "btn small", title: "Turn the board around", "aria-label": "Turn the board around", onclick: () => this.flip() }, "⇅"),
    );
    this.root = h("section", { class: "game" },
      h("div", { class: "board-col" }, h("div", { class: "plate-slot top" }), boardHost, h("div", { class: "plate-slot bottom" }), nav),
      h("aside", { class: "panel" }, this.statusEl, this.banner, h("div", { class: "moves-box" }, this.list), this.actions),
    );
    host.append(this.root);
    this.board = new Board(boardHost);
    this.board.onMove = (uci) => this.onMove(uci);
    this.board.flipped = orientation === "black";
    this.placePlates();
    this.root.addEventListener("keydown", (e) => {
      if (e.target instanceof HTMLInputElement || this.board.canvas === document.activeElement) return;
      if (e.key === "ArrowLeft") this.step(-1);
      else if (e.key === "ArrowRight") this.step(1);
    });
  }

  destroy(): void { this.board.destroy(); this.root.remove(); }

  setSeats(seats: Record<Side, Seat>): void { this.seats = seats; this.renderPlates(); }

  private placePlates(): void {
    const top = this.root.querySelector(".plate-slot.top")!, bottom = this.root.querySelector(".plate-slot.bottom")!;
    const near: Side = this.board.flipped ? "black" : "white";
    put(bottom, this.plates[near]);
    put(top, this.plates[near === "white" ? "black" : "white"]);
  }

  flip(): void {
    this.board.flipped = !this.board.flipped;
    this.placePlates();
  }

  /** The moves of the game. When one more move than before arrives, it slides into place. */
  setMoves(moves: string[], animate = true): void {
    const grew = moves.length === this.moves.length + 1 && moves.slice(0, -1).every((m, i) => m === this.moves[i]);
    const r = replay(moves);
    if (!r) return;
    this.moves = [...moves];
    this.san = r.san;
    if (this.view !== null && this.view >= moves.length) this.view = null;
    this.render(grew && animate && this.view === null);
  }

  get length(): number { return this.moves.length; }
  get turn(): Side { return sideToMove(this.moves.length); }
  get viewing(): boolean { return this.view !== null; }

  goto(ply: number | null): void {
    this.view = ply === null || ply >= this.moves.length ? null : Math.max(0, ply);
    this.render(false);
  }

  private step(d: number): void {
    const cur = this.view ?? this.moves.length;
    this.goto(cur + d);
    if (d > 0 && this.view === null) return;
  }

  status(text: string, tone: "" | "good" | "bad" | "turn" = ""): void {
    this.statusEl.textContent = text;
    this.statusEl.className = `status ${tone}`;
  }

  /** Shows a finished game's result. */
  finish(o: Outcome): void {
    const w = this.seats.white.name, b = this.seats.black.name;
    this.status(describe(o, w, b), o.result === "1/2-1/2" ? "" : "good");
  }

  render(animate: boolean): void {
    const ply = this.view ?? this.moves.length;
    const chess = new Chess();
    let last: Move | null = null;
    for (const uci of this.moves.slice(0, ply)) last = chess.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
    this.board.show(chess, last, animate);
    this.board.movable = this.view === null && this.canMove(sideToMove(ply)) ? (sideToMove(ply) === "white" ? "w" : "b") : null;
    this.navLabel.textContent = this.view === null ? "LIVE" : `${ply}/${this.moves.length}`;
    this.navLabel.classList.toggle("past", this.view !== null);
    this.renderList(ply);
    this.renderPlates(chess);
  }

  private renderList(ply: number): void {
    this.list.replaceChildren();
    for (let i = 0; i < this.san.length; i += 2) {
      const li = h("li", null, h("span", { class: "num" }, `${i / 2 + 1}.`));
      for (const j of [i, i + 1]) {
        if (j >= this.san.length) break;
        li.append(h("button", { class: `mv${j + 1 === ply ? " on" : ""}`, onclick: () => this.goto(j + 1) }, this.san[j]));
      }
      this.list.append(li);
    }
    const on = this.list.querySelector(".on");
    (on ?? this.list.lastElementChild)?.scrollIntoView({ block: "nearest" });
  }

  private renderPlates(chess?: Chess): void {
    const c = chess ?? new Chess();
    if (!chess) for (const uci of this.moves.slice(0, this.view ?? this.moves.length)) c.move({ from: uci.slice(0, 2), to: uci.slice(2, 4), promotion: uci[4] });
    const count: Record<string, number> = {};
    for (const row of c.board()) for (const p of row) if (p) count[p.color + p.type] = (count[p.color + p.type] ?? 0) + 1;
    const material = (col: PieceColor) => Object.entries(VALUE).reduce((s, [t, v]) => s + v * (count[col + t] ?? 0), 0);
    const diff = material("w") - material("b");
    const turn = sideToMove(this.view ?? this.moves.length);
    for (const side of ["white", "black"] as Side[]) {
      const me: PieceColor = side === "white" ? "w" : "b", them: PieceColor = me === "w" ? "b" : "w";
      const taken = h("span", { class: "taken", "aria-label": "Captured pieces" });
      for (const t of ["q", "r", "b", "n", "p"] as PieceType[]) {
        const n = Math.max(0, START_COUNT[t] - (count[them + t] ?? 0));
        for (let i = 0; i < n; i++) taken.append(pieceIcon(t, them, 1));
      }
      const adv = side === "white" ? diff : -diff;
      const seat = this.seats[side];
      put(this.plates[side], 
        h("span", { class: `pip ${side}` }),
        h("span", { class: "who" }, h("b", null, seat.name), seat.detail ? h("small", null, seat.detail) : null),
        taken,
        adv > 0 ? h("span", { class: "adv" }, `+${adv}`) : null,
      );
      this.plates[side].classList.toggle("to-move", turn === side && !c.isGameOver());
    }
  }
}
