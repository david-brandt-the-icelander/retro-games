// A whole game as its inputs, and the replay the high-score server runs to score it.
//
// Each frame's Input packs into a few bits; runs of the same input are stored as [bits, count]
// pairs, so a long game stays small. The browser records from the frame a player pressed 1 or 2
// until the frame the game ended; the server replays those frames from the seed it issued and
// records the scores the replay produces, never scores sent by the browser.
import { Game, Input } from "./game";

const LEFT = 1, RIGHT = 2, FIRE = 4, START1 = 8, START2 = 16, PAUSE = 32;

export const toBits = (i: Input): number =>
  (i.left ? LEFT : 0) | (i.right ? RIGHT : 0) | (i.fire ? FIRE : 0) | (i.start1 ? START1 : 0) | (i.start2 ? START2 : 0) | (i.pause ? PAUSE : 0);

export const fromBits = (b: number): Input =>
  ({ left: !!(b & LEFT), right: !!(b & RIGHT), fire: !!(b & FIRE), start1: !!(b & START1), start2: !!(b & START2), pause: !!(b & PAUSE) });

/** Two hours of play at 60 frames a second; a longer game is not accepted. */
export const MAX_FRAMES = 2 * 60 * 60 * 60;
/** The most [bits, count] pairs a game may send. */
export const MAX_RUNS = 200_000;

/** Records a game's inputs as runs. */
export class Recorder {
  runs: number[] = [];
  frames = 0;
  push(input: Input): void {
    const bits = toBits(input);
    const n = this.runs.length;
    if (n > 0 && this.runs[n - 2] === bits) this.runs[n - 1]++;
    else this.runs.push(bits, 1);
    this.frames++;
  }
}

export interface ReplayResult {
  players: number;
  /** Per player: their final score and the wave they reached. */
  scores: { score: number; wave: number }[];
  frames: number;
}

/**
 * Plays a recorded game again from its seed. Returns null unless the runs start a game on their
 * first frame and end it on their last: no more, no less.
 */
export function replay(seed: number, runs: unknown): ReplayResult | null {
  if (!Array.isArray(runs) || runs.length === 0 || runs.length % 2 !== 0 || runs.length > MAX_RUNS * 2) return null;
  let total = 0;
  for (let i = 0; i < runs.length; i += 2) {
    const bits = runs[i], count = runs[i + 1];
    if (!Number.isInteger(bits) || bits < 0 || bits > 63 || !Number.isInteger(count) || count < 1) return null;
    total += count;
    if (total > MAX_FRAMES) return null;
  }
  const game = new Game(1);
  game.nextSeed = seed >>> 0;
  let frame = 0;
  for (let i = 0; i < runs.length; i += 2) {
    const input = fromBits(runs[i]);
    for (let k = 0; k < runs[i + 1]; k++) {
      if (game.phase === "gameOver") return null; // inputs left over after the game ended
      const wasAttract = game.phase === "attract";
      game.step(input);
      if (frame === 0 && !(wasAttract && game.phase === "ready")) return null; // must start a game at once
      frame++;
    }
  }
  if (game.phase !== "gameOver") return null; // the game never ended
  return { players: game.numPlayers, scores: game.players.map((p) => ({ score: p.score, wave: p.wave })), frames: frame };
}
