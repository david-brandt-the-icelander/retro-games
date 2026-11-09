// Online play: friends on different computers play one game together. The same file is in Rally,
// Shatterbelt and Hivestorm.
//
// Games are started from the multiplayer page at icelander.net/games/multiplayer/, where signed-in
// players meet. When a game starts there, each player's browser opens the game with ?match=ID, and
// connects to that match's relay (GET /multiplayer/match/ID, a WebSocket served by the games
// hub, not by this game's Worker). Only the players the lobby put in the match may connect.
//
// Every browser runs the whole game itself, in lockstep. Each step, a browser takes its own
// player's controls and schedules them a few steps ahead (the delay), sends them to the others
// through the relay, and steps the game only once it has every player's controls for that step.
// The games are deterministic (the same seed and controls always play the same game, which is also
// what lets the high-score server replay them), so every browser sees the same game. A browser
// that is short of someone's controls waits for them. Now and then the browsers compare a
// fingerprint of their games, to notice if they ever drift apart.
//
//   Room       the WebSocket to the match: who is in it, and its messages
//   Lockstep   the controls of every player, step by step

/** A message from the room, or relayed by it from another member (`from` is their slot). */
export type RoomMessage = { t: string; from?: number; [key: string]: unknown };

export type RoomListener = (msg: RoomMessage) => void;

/** The multiplayer page, where games are started. */
export const MULTIPLAYER_PAGE = "/games/multiplayer/";

/** Why a match can't be played, in words for players. */
export const REFUSALS: Record<string, string> = {
  missing: "This game has ended, or never started. Start a new one from the multiplayer page.",
  "not-yours": "This game was started for other players. Start your own from the multiplayer page.",
  lost: "The connection to the game was lost.",
  unreachable: "The game can't be reached. Are you signed in? Games with friends start from the multiplayer page.",
};

/** The match in the page's address (?match=ID), if any. */
export function matchInAddress(): string | null {
  const id = new URLSearchParams(location.search).get("match") ?? "";
  return /^[A-Za-z0-9_-]{8,40}$/.test(id) ? id : null;
}

/** How often a browser sends its scheduled controls, in milliseconds. */
export const FLUSH_MS = 25;
const PING_MS = 3000;

/**
 * The delay, in steps, for players whose round trips to the room take `rtts` milliseconds: long
 * enough for controls to cross from one browser to another, with some to spare.
 */
export function delaySteps(rtts: number[], dt: number): number {
  const sorted = [...rtts].filter((r) => Number.isFinite(r) && r >= 0).sort((a, b) => b - a);
  // From A to B is half A's round trip plus half B's; the slowest two players set it.
  const oneWay = sorted.length === 0 ? 100 : sorted.length === 1 ? sorted[0] : (sorted[0] + sorted[1]) / 2;
  const ms = Math.min(400, Math.max(50, oneWay + FLUSH_MS + 25));
  return Math.ceil(ms / (dt * 1000) - 1e-9);
}

/** A fingerprint of some numbers, bit for bit, to compare games between browsers. */
export function fingerprint(values: readonly number[]): number {
  const f = new Float64Array(1);
  const u = new Uint32Array(f.buffer);
  let h = 0x811c9dc5;
  for (const v of values) {
    f[0] = v;
    h = Math.imul(h ^ u[0], 0x01000193);
    h = Math.imul(h ^ u[1], 0x01000193);
  }
  return h >>> 0;
}

export class Room {
  /** This browser's slot. */
  you = -1;
  /** How many players the match was made for. */
  size = 0;
  /** Each slot's player, by name (their address before the @). */
  names: string[] = [];
  /** The slots in the room, this browser's included. */
  readonly peers = new Set<number>();
  /** This browser's round trip to the room, in milliseconds (the best of the last few; 150 until measured). */
  rtt = 150;
  /** Every member's round trip, as they last reported it. */
  readonly rtts = new Map<number, number>();
  closed = false;
  private listeners = new Set<RoomListener>();
  private pingSent = 0;
  private told = -100;
  private recent: number[] = [];
  private timer: ReturnType<typeof setInterval> | null = null;

  private constructor(readonly match: string, private ws: WebSocket) {}

  /** Connects to a match. Resolves once the match has welcomed this browser. */
  static open(match: string): Promise<Room> {
    return new Promise((resolve, reject) => {
      const url = new URL(`/games/multiplayer/match/${match}`, location.href);
      url.protocol = url.protocol === "https:" ? "wss:" : "ws:";
      let ws: WebSocket;
      try { ws = new WebSocket(url.toString()); } catch { reject(new Error("unreachable")); return; }
      const room = new Room(match, ws);
      let welcomed = false;
      const timeout = setTimeout(() => { if (!welcomed) { ws.close(); reject(new Error("unreachable")); } }, 8000);
      ws.addEventListener("message", (e) => {
        if (e.data === "pong") { room.pong(); return; }
        let msg: RoomMessage;
        try { msg = JSON.parse(String(e.data)); } catch { return; }
        if (!msg || typeof msg.t !== "string") return;
        if (!welcomed) {
          clearTimeout(timeout);
          if (msg.t === "welcome") {
            welcomed = true;
            room.you = Number(msg.you);
            room.size = Number(msg.size);
            room.names = Array.isArray(msg.names) ? (msg.names as unknown[]).map(String) : [];
            for (const p of msg.peers as number[]) room.peers.add(p);
            room.startPinging();
            resolve(room);
          } else {
            reject(new Error(String(msg.reason ?? "unreachable")));
            ws.close();
          }
          return;
        }
        room.receive(msg);
      });
      ws.addEventListener("close", () => {
        clearTimeout(timeout);
        if (!welcomed) reject(new Error("unreachable"));
        else room.lost();
      });
    });
  }

  /** The host starts games: the lowest slot still in the room. */
  get host(): number { return Math.min(...this.peers); }
  get isHost(): boolean { return this.host === this.you; }

  listen(fn: RoomListener): () => void {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  }

  send(msg: object): void {
    if (this.closed || this.ws.readyState !== WebSocket.OPEN) return;
    this.ws.send(JSON.stringify(msg));
  }

  /** Leaves the room. */
  close(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.timer) clearInterval(this.timer);
    try { this.ws.close(1000, "bye"); } catch { /* already closed */ }
  }

  private receive(msg: RoomMessage): void {
    if (msg.t === "join") this.peers.add(Number(msg.slot));
    else if (msg.t === "leave") { this.peers.delete(Number(msg.slot)); this.rtts.delete(Number(msg.slot)); }
    else if (msg.t === "rtt" && typeof msg.from === "number") this.rtts.set(msg.from, Number(msg.ms));
    for (const fn of [...this.listeners]) fn(msg);
  }

  private lost(): void {
    if (this.closed) return;
    this.closed = true;
    if (this.timer) clearInterval(this.timer);
    for (const fn of [...this.listeners]) fn({ t: "closed", reason: "lost" });
  }

  private startPinging(): void {
    this.rtts.set(this.you, this.rtt);
    this.ping();
    this.timer = setInterval(() => this.ping(), PING_MS);
  }

  private ping(): void {
    if (this.ws.readyState !== WebSocket.OPEN) return;
    this.pingSent = performance.now();
    this.ws.send("ping");
  }

  private pong(): void {
    if (!this.pingSent) return;
    this.recent = [...this.recent.slice(-4), performance.now() - this.pingSent];
    this.pingSent = 0;
    this.rtt = Math.round(Math.min(...this.recent));
    this.rtts.set(this.you, this.rtt);
    // Tell the others only of a change worth knowing: it sets the delay when the host starts a game.
    if (Math.abs(this.rtt - this.told) >= 5) { this.told = this.rtt; this.send({ t: "rtt", ms: this.rtt }); }
    for (const fn of [...this.listeners]) fn({ t: "pong" });
  }
}

/** How a game starts online: sent by the host, the same for every player. */
export interface Start {
  /** The slots playing, in player order: player i is slots[i]. */
  slots: number[];
  seed: number;
  /** Steps between taking a player's controls and playing them. */
  delay: number;
}

/**
 * Every player's controls, step by step. Controls are whole numbers (each game packs its own);
 * a player who has left the room plays on as null.
 */
export class Lockstep {
  /** The next step to play. */
  frame = 0;
  /** Player index of this browser. */
  readonly me: number;
  /** The players' controls from `frame` on, as far as each is known. */
  private queues: number[][];
  /** The step after the last one each player's controls are known for. */
  private known: number[];
  /** For each player who has left: the step from which they are null. */
  private gone: (number | null)[];
  private pending: number[] = [];
  private lastFlush = 0;
  private mine = new Map<number, number>();
  private theirs: { f: number; h: number; from: number }[] = [];
  private unlisten: () => void;
  /** When this browser began waiting for someone's controls (performance.now()), or null. */
  waitingSince: number | null = null;
  /** Called if the browsers' games have drifted apart. */
  onDesync: () => void = () => {};
  /** Called when a player leaves, with their player index. */
  onLeave: (player: number) => void = () => {};

  /** Compare fingerprints every this many steps. */
  static readonly CHECK_EVERY = 120;

  constructor(readonly room: Room, readonly start: Start, idle: number) {
    const n = start.slots.length;
    this.me = start.slots.indexOf(room.you);
    // The first `delay` steps are idle for everyone: nobody's controls can have arrived yet.
    this.queues = Array.from({ length: n }, () => new Array(start.delay).fill(idle));
    this.known = new Array(n).fill(start.delay);
    this.gone = start.slots.map((s) => (room.peers.has(s) ? null : start.delay));
    this.unlisten = room.listen((msg) => this.receive(msg));
  }

  get players(): number { return this.start.slots.length; }

  /** Whether a player is still in the game (in the room). */
  present(player: number): boolean { return this.gone[player] === null; }

  /** Stops listening to the room. */
  stop(): void { this.unlisten(); this.flush(Infinity); }

  /** Schedules this browser's controls `delay` steps ahead, unless it is already that far ahead. Call once per step. */
  local(controls: number): void {
    if (this.queues[this.me].length >= this.start.delay) return;
    this.queues[this.me].push(controls);
    this.known[this.me]++;
    this.pending.push(controls);
  }

  /** Whether every player's controls for the next step are known. */
  ready(): boolean {
    return this.queues.every((q, i) => q.length > 0 || this.gone[i] !== null);
  }

  /** The players still awaited for the next step, by index. */
  waiting(): number[] {
    return this.queues.flatMap((q, i) => (q.length === 0 && this.gone[i] === null ? [i] : []));
  }

  /** The next step's controls, one per player (null for a player who has left). Only when ready(). */
  next(): (number | null)[] {
    this.frame++;
    return this.queues.map((q) => (q.length ? q.shift()! : null));
  }

  /** Sends the controls scheduled since the last send, at most every FLUSH_MS. Call once per animation frame. */
  flush(now: number): void {
    if (!this.pending.length || now - this.lastFlush < FLUSH_MS) return;
    this.lastFlush = now;
    this.room.send({ t: "in", f: this.known[this.me] - this.pending.length, b: this.pending });
    this.pending = [];
  }

  /** Keeps track of waiting, for the page to say who it is waiting for. */
  stalled(now: number, stuck: boolean): void {
    if (!stuck) this.waitingSince = null;
    else if (this.waitingSince === null) this.waitingSince = now;
  }

  /** Call after each step with a fingerprint of the game; every CHECK_EVERY steps it is compared. */
  check(hash: number): void {
    if (this.frame % Lockstep.CHECK_EVERY !== 0) return;
    this.mine.set(this.frame, hash);
    this.room.send({ t: "sum", f: this.frame, h: hash });
    this.compare();
    for (const f of this.mine.keys()) if (f < this.frame - 20 * Lockstep.CHECK_EVERY) this.mine.delete(f);
  }

  private compare(): void {
    this.theirs = this.theirs.filter((s) => {
      const h = this.mine.get(s.f);
      if (h === undefined) return true;
      if (h !== s.h) this.onDesync();
      return false;
    });
  }

  private receive(msg: RoomMessage): void {
    if (typeof msg.from !== "number") {
      if (msg.t === "leave") {
        const i = this.start.slots.indexOf(Number(msg.slot));
        if (i >= 0 && i !== this.me && this.gone[i] === null) {
          // Everything they sent came before this; from the step after it, they are gone.
          this.gone[i] = this.known[i];
          this.onLeave(i);
        }
      }
      return;
    }
    const i = this.start.slots.indexOf(msg.from);
    if (i < 0 || i === this.me) return;
    if (msg.t === "in") {
      const b = msg.b as number[];
      if (msg.f !== this.known[i] || !Array.isArray(b)) return; // not the steps expected next
      for (const v of b) this.queues[i].push(Number(v) | 0);
      this.known[i] += b.length;
    } else if (msg.t === "sum") {
      this.theirs.push({ f: Number(msg.f), h: Number(msg.h), from: msg.from });
      this.compare();
    }
  }
}

/**
 * Resolves once everyone the match was made for is connected, or after `ms` milliseconds: whoever
 * is here by then plays.
 */
export function everyoneIn(room: Room, ms = 15_000): Promise<void> {
  return new Promise((resolve) => {
    if (room.peers.size >= room.size) { resolve(); return; }
    const done = () => { clearTimeout(timer); stop(); resolve(); };
    const timer = setTimeout(done, ms);
    const stop = room.listen(() => { if (room.peers.size >= room.size) done(); });
  });
}
