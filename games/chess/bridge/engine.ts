// The computer opponent: Stockfish 19 (lite, single-threaded WebAssembly; GPL-3.0, from the
// stockfish.js project), run in a Web Worker and spoken to in UCI. Strength 1–8 sets Stockfish's
// Skill Level and how deep or long it searches.

/** Per strength: Skill Level 0–20, and a search limit. */
export const STRENGTH: readonly { skill: number; go: string; pause: number }[] = [
  { skill: 0, go: "depth 1", pause: 450 },
  { skill: 3, go: "depth 2", pause: 450 },
  { skill: 6, go: "depth 4", pause: 400 },
  { skill: 9, go: "depth 6", pause: 350 },
  { skill: 12, go: "depth 9", pause: 250 },
  { skill: 15, go: "depth 12", pause: 150 },
  { skill: 18, go: "movetime 1000", pause: 0 },
  { skill: 20, go: "movetime 2000", pause: 0 },
];

/** The UCI commands that ask for a move at a strength, after the given moves. */
export function commandsFor(level: number, moves: readonly string[]): string[] {
  const s = STRENGTH[Math.min(8, Math.max(1, level)) - 1];
  return [
    `setoption name Skill Level value ${s.skill}`,
    `position startpos${moves.length ? ` moves ${moves.join(" ")}` : ""}`,
    `go ${s.go}`,
  ];
}

export class Engine {
  private worker: Worker | null = null;
  private ready: Promise<void> | null = null;
  private waiting: ((line: string) => void) | null = null;
  private generation = 0;
  /** Answers still to come from cancelled searches, to be ignored. */
  private stale = 0;

  private start(): Promise<void> {
    if (this.ready) return this.ready;
    this.ready = new Promise<void>((resolve, reject) => {
      try {
        this.worker = new Worker(new URL("engine/stockfish.js", document.baseURI).toString());
      } catch (e) {
        reject(e);
        return;
      }
      this.worker.onmessage = (e: MessageEvent) => {
        const line = String(e.data);
        if (line === "uciok") resolve();
        if (line.startsWith("bestmove") && this.stale > 0) { this.stale--; return; }
        this.waiting?.(line);
      };
      this.worker.onerror = () => reject(new Error("The engine couldn't start."));
      this.worker.postMessage("uci");
    });
    return this.ready;
  }

  /** Warms the engine up, so the first move comes quickly. */
  preload(): void { void this.start().catch(() => undefined); }

  /** The engine's move after `moves`, at strength `level`. Rejects if cancelled. */
  async bestMove(moves: readonly string[], level: number): Promise<string> {
    await this.start();
    const gen = ++this.generation;
    const began = performance.now();
    const move = await new Promise<string>((resolve) => {
      this.waiting = (line) => {
        const m = /^bestmove (\S+)/.exec(line);
        if (m) { this.waiting = null; resolve(m[1]); }
      };
      for (const c of commandsFor(level, moves)) this.worker!.postMessage(c);
    });
    // The weakest levels answer at once; a short pause makes them feel like an opponent.
    const pause = STRENGTH[level - 1].pause - (performance.now() - began);
    if (pause > 0) await new Promise((r) => setTimeout(r, pause));
    if (gen !== this.generation) throw new Error("cancelled");
    return move;
  }

  /** Stops any search; its answer is thrown away. */
  cancel(): void {
    this.generation++;
    if (this.waiting && this.worker) {
      this.waiting = null;
      this.stale++;
      this.worker.postMessage("stop");
    }
  }
}
