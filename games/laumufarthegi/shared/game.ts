// Laumufarþegi's rules, as pure functions over a room's state. The Durable Object (worker/room.ts) keeps the
// state, calls these, and sends every player their own view(). Nothing here touches the network or the clock:
// the time and the random numbers come in as arguments, so the tests can replay any game.
//
// A round: everyone sees a topic with 16 words. The server picks one secret word and one stowaway. Everyone but
// the stowaway sees the secret word. In turn, each player gives a short clue; then everyone votes for who they
// think the stowaway is. If the stowaway is caught, they get one guess at the secret word.
//
// Points:  each player who voted for the stowaway +1;
//          stowaway not caught (wrong person, or a tie) → stowaway +3;
//          caught and guesses the word → stowaway +1;  caught and guesses wrong → every other player +1.

export const MIN_PLAYERS = 3;
export const MAX_PLAYERS = 10;
export const NAME_MAX = 20;
export const CLUE_MAX = 30;
/** How long the host may be away before another player may take over. */
export const HOST_GRACE_MS = 30_000;
export const GUESS_SECONDS = 45;

export type Phase = "lobby" | "clues" | "voting" | "guess" | "reveal" | "over";

export interface Topic { efni: string; ord: string[]; barnvaent: boolean; erfidleiki: number; flokkur?: string }

export interface Settings {
  rounds: number;        // 1–20
  clueSeconds: number;   // 15–180
  voteSeconds: number;   // 20–300
  maxDifficulty: number; // 1–3: the hardest topics allowed
  childOnly: boolean;    // only topics marked child-friendly
}
export const DEFAULT_SETTINGS: Settings = { rounds: 6, clueSeconds: 45, voteSeconds: 90, maxDifficulty: 2, childOnly: false };

export interface Player {
  id: string;
  name: string;
  token: string;      // the player's secret: whoever sends it gets this seat back
  score: number;
  connected: boolean;
  joinedAt: number;
}

export interface Round {
  number: number;     // 1-based
  topic: number;      // index into the topic list
  secret: number;     // 0–15
  stowaway: string;   // player id
  order: string[];    // the players in this round, in clue order
  turn: number;       // index into order while giving clues
  clues: { player: string; text: string }[];
  votes: Record<string, string>; // voter → accused
  accused: string | null;        // most votes; null on a tie
  guess: number | null;          // the stowaway's guess, when caught
  points: Record<string, number>;
  deadline: number | null;       // ms epoch when the current step times out
}

export interface State {
  code: string;
  hostId: string;
  hostAwaySince: number | null;
  phase: Phase;
  settings: Settings;
  players: Player[];
  round: Round | null;
  roundsPlayed: number;
  usedTopics: number[];
  notice: string | null;   // a short message for everyone, e.g. that the topics started over
  updatedAt: number;
}

export type Action =
  | { t: "settings"; settings: Partial<Settings> }
  | { t: "start" }
  | { t: "clue"; text: string }
  | { t: "vote"; target: string }
  | { t: "guess"; index: number }
  | { t: "next" }
  | { t: "end" }
  | { t: "kick"; player: string }
  | { t: "claimHost" }
  | { t: "resetTopics" };

export type Result = { ok: true } | { ok: false; error: string };
const fail = (error: string): Result => ({ ok: false, error });
const OK: Result = { ok: true };

// ── Making a room and joining it ──

export function newRoom(code: string, host: { id: string; name: string; token: string }, now: number): State {
  return {
    code, hostId: host.id, hostAwaySince: null, phase: "lobby", settings: { ...DEFAULT_SETTINGS },
    players: [{ ...host, name: cleanName(host.name) || "Gestgjafi", score: 0, connected: false, joinedAt: now }],
    round: null, roundsPlayed: 0, usedTopics: [], notice: null, updatedAt: now,
  };
}

/** A name as shown: trimmed, single spaces, no control characters, at most NAME_MAX characters. */
export function cleanName(x: unknown): string {
  if (typeof x !== "string") return "";
  return x.replace(/[\u0000-\u001f\u007f]/g, "").replace(/\s+/g, " ").trim().slice(0, NAME_MAX);
}

/** A clue as stored: like a name, but up to CLUE_MAX characters. */
export function cleanClue(x: unknown): string {
  if (typeof x !== "string") return "";
  return x.replace(/[\u0000-\u001f\u007f]/g, "").replace(/\s+/g, " ").trim().slice(0, CLUE_MAX);
}

/** The player holding this token, if any. */
export const byToken = (s: State, token: unknown) => (typeof token === "string" && token ? s.players.find((p) => p.token === token) : undefined);

/** Adds a new player. Fails when the room is full or the name is taken. */
export function addPlayer(s: State, name: string, id: string, token: string, now: number): Result {
  const n = cleanName(name);
  if (!n) return fail("Sláðu inn nafn.");
  if (s.players.length >= MAX_PLAYERS) return fail(`Leikurinn er fullur (${MAX_PLAYERS} leikmenn).`);
  if (s.players.some((p) => p.name.toLowerCase() === n.toLowerCase())) return fail("Einhver er þegar með þetta nafn. Veldu annað.");
  s.players.push({ id, name: n, token, score: 0, connected: false, joinedAt: now });
  s.updatedAt = now;
  return OK;
}

/** Marks a player connected or not (several tabs count as connected while any is open). */
export function setConnected(s: State, playerId: string, connected: boolean, now: number): void {
  const p = s.players.find((x) => x.id === playerId);
  if (!p || p.connected === connected) return;
  p.connected = connected;
  if (playerId === s.hostId) s.hostAwaySince = connected ? null : now;
  s.updatedAt = now;
}

// ── Actions ──

/** Applies one player's action. `rand` gives numbers in [0, 1); `topics` is the whole topic list. */
export function act(s: State, playerId: string, a: Action, now: number, topics: Topic[], rand: () => number): Result {
  const me = s.players.find((p) => p.id === playerId);
  if (!me) return fail("Þú ert ekki í þessum leik.");
  const host = playerId === s.hostId;
  const r = s.round;
  s.notice = null;
  switch (a.t) {
    case "settings": {
      if (!host) return fail("Aðeins stjórnandinn breytir stillingum.");
      if (s.phase !== "lobby" && s.phase !== "over") return fail("Stillingum er breytt milli leikja.");
      s.settings = clampSettings({ ...s.settings, ...a.settings });
      break;
    }
    case "start": {
      if (!host) return fail("Aðeins stjórnandinn byrjar leikinn.");
      if (s.phase !== "lobby" && s.phase !== "over") return fail("Leikurinn er þegar hafinn.");
      for (const p of s.players) p.score = 0;
      s.roundsPlayed = 0;
      const started = startRound(s, now, topics, rand);
      if (!started.ok) return started;
      break;
    }
    case "clue": {
      if (s.phase !== "clues" || !r) return fail("Það er ekki verið að gefa vísbendingar.");
      if (r.order[r.turn] !== playerId) return fail("Það er ekki komið að þér.");
      const text = cleanClue(a.text);
      if (!text) return fail("Skrifaðu vísbendingu.");
      if (playerId !== r.stowaway && sameWord(text, topics[r.topic].ord[r.secret])) return fail("Þú mátt ekki segja leyniorðið sjálft!");
      r.clues.push({ player: playerId, text });
      advanceClues(s, now);
      break;
    }
    case "vote": {
      if (s.phase !== "voting" || !r) return fail("Það er ekki verið að kjósa.");
      if (!r.order.includes(playerId)) return fail("Þú tekur ekki þátt í þessari umferð.");
      if (a.target === playerId) return fail("Þú getur ekki kosið sjálfan þig.");
      if (!r.order.includes(a.target)) return fail("Sá leikmaður er ekki í umferðinni.");
      r.votes[playerId] = a.target;
      if (r.order.every((id) => r.votes[id])) closeVoting(s, now);
      break;
    }
    case "guess": {
      if (s.phase !== "guess" || !r) return fail("Það er ekki verið að giska.");
      if (playerId !== r.stowaway) return fail("Aðeins laumufarþeginn giskar.");
      if (!Number.isInteger(a.index) || a.index < 0 || a.index > 15) return fail("Veldu eitt orðanna.");
      r.guess = a.index;
      finishRound(s, now);
      break;
    }
    case "next": {
      if (!host) return fail("Aðeins stjórnandinn heldur áfram.");
      if (s.phase !== "reveal") return fail("Umferðinni er ekki lokið.");
      if (s.roundsPlayed >= s.settings.rounds) { s.phase = "over"; s.round = null; break; }
      const next = startRound(s, now, topics, rand);
      if (!next.ok) return next;
      break;
    }
    case "end": {
      if (!host) return fail("Aðeins stjórnandinn lýkur leiknum.");
      if (s.phase === "lobby" || s.phase === "over") return fail("Enginn leikur er í gangi.");
      s.phase = "over"; s.round = null;
      break;
    }
    case "kick": {
      if (!host) return fail("Aðeins stjórnandinn getur fjarlægt leikmenn.");
      if (a.player === playerId) return fail("Þú getur ekki fjarlægt sjálfan þig.");
      if (r && (s.phase === "clues" || s.phase === "voting" || s.phase === "guess") && r.order.includes(a.player)) {
        return fail("Bíddu þar til umferðinni lýkur.");
      }
      const before = s.players.length;
      s.players = s.players.filter((p) => p.id !== a.player);
      if (s.players.length === before) return fail("Sá leikmaður er ekki í leiknum.");
      break;
    }
    case "claimHost": {
      if (host) return OK;
      const h = s.players.find((p) => p.id === s.hostId);
      if (h && (h.connected || (s.hostAwaySince !== null && now - s.hostAwaySince < HOST_GRACE_MS))) {
        return fail("Stjórnandinn er enn tengdur.");
      }
      s.hostId = playerId; s.hostAwaySince = null;
      break;
    }
    case "resetTopics": {
      if (!host) return fail("Aðeins stjórnandinn getur það.");
      s.usedTopics = [];
      s.notice = "Öll efni eru nú tiltæk aftur.";
      break;
    }
    default:
      return fail("Óþekkt aðgerð.");
  }
  s.updatedAt = now;
  return OK;
}

/** Runs out whatever step has timed out: a missing clue, the vote, or the stowaway's guess. Returns true if anything changed. */
export function tick(s: State, now: number): boolean {
  const r = s.round;
  if (!r || r.deadline === null || now < r.deadline) return false;
  if (s.phase === "clues") {
    r.clues.push({ player: r.order[r.turn], text: "—" });
    advanceClues(s, now);
  } else if (s.phase === "voting") {
    closeVoting(s, now);
  } else if (s.phase === "guess") {
    r.guess = -1; // no guess counts as a wrong one
    finishRound(s, now);
  } else {
    return false;
  }
  s.updatedAt = now;
  return true;
}

// ── Steps of a round ──

function startRound(s: State, now: number, topics: Topic[], rand: () => number): Result {
  const playing = s.players.filter((p) => p.connected);
  if (playing.length < MIN_PLAYERS) return fail(`Það þarf minnst ${MIN_PLAYERS} tengda leikmenn.`);
  const fits = (t: Topic) => t.erfidleiki <= s.settings.maxDifficulty && (!s.settings.childOnly || t.barnvaent);
  let pool = topics.map((t, i) => i).filter((i) => fits(topics[i]) && !s.usedTopics.includes(i));
  if (!pool.length) {
    s.usedTopics = s.usedTopics.filter((i) => !fits(topics[i]));
    pool = topics.map((t, i) => i).filter((i) => fits(topics[i]));
    if (!pool.length) return fail("Ekkert efni passar við stillingarnar.");
    s.notice = "Öll efnin hafa verið notuð, svo þau byrja upp á nýtt.";
  }
  const topic = pool[Math.floor(rand() * pool.length)];
  s.usedTopics.push(topic);
  const order = shuffle(playing.map((p) => p.id), rand);
  s.round = {
    number: s.roundsPlayed + 1, topic, secret: Math.floor(rand() * 16),
    stowaway: order[Math.floor(rand() * order.length)], order, turn: 0, clues: [], votes: {},
    accused: null, guess: null, points: {}, deadline: now + s.settings.clueSeconds * 1000,
  };
  s.phase = "clues";
  return OK;
}

function advanceClues(s: State, now: number): void {
  const r = s.round!;
  r.turn++;
  if (r.turn < r.order.length) { r.deadline = now + s.settings.clueSeconds * 1000; return; }
  s.phase = "voting";
  r.deadline = now + s.settings.voteSeconds * 1000;
}

function closeVoting(s: State, now: number): void {
  const r = s.round!;
  const count = new Map<string, number>();
  for (const target of Object.values(r.votes)) count.set(target, (count.get(target) ?? 0) + 1);
  const top = Math.max(0, ...count.values());
  const leaders = [...count.entries()].filter(([, n]) => n === top).map(([id]) => id);
  r.accused = top > 0 && leaders.length === 1 ? leaders[0] : null;
  if (r.accused === r.stowaway) {
    s.phase = "guess";
    r.deadline = now + GUESS_SECONDS * 1000;
  } else {
    finishRound(s, now);
  }
}

function finishRound(s: State, _now: number): void {
  const r = s.round!;
  const pts: Record<string, number> = Object.fromEntries(r.order.map((id) => [id, 0]));
  for (const [voter, target] of Object.entries(r.votes)) if (target === r.stowaway && voter !== r.stowaway) pts[voter] += 1;
  if (r.accused !== r.stowaway) pts[r.stowaway] += 3;
  else if (r.guess === r.secret) pts[r.stowaway] += 1;
  else for (const id of r.order) if (id !== r.stowaway) pts[id] += 1;
  r.points = pts;
  for (const p of s.players) p.score += pts[p.id] ?? 0;
  r.deadline = null;
  s.roundsPlayed++;
  s.phase = "reveal";
}

// ── What each player may see ──

export interface PlayerView {
  id: string; name: string; score: number; connected: boolean; host: boolean;
  inRound: boolean; voted: boolean;
}
export interface View {
  code: string;
  phase: Phase;
  me: { id: string; name: string; host: boolean; inRound: boolean; stowaway: boolean };
  players: PlayerView[];
  settings: Settings;
  roundsPlayed: number;
  canClaimHost: boolean;
  notice: string | null;
  now: number;
  round: null | {
    number: number;
    topic: { efni: string; ord: string[] };
    secret: number | null;   // only for players in the round who are not the stowaway, or after the round
    order: string[];
    turn: number;
    clues: { player: string; text: string }[];
    deadline: number | null;
    myVote: string | null;
    accused: string | null;  // known to all once the vote has caught someone (the guess) and after the round
    reveal: null | {
      secret: number; stowaway: string; accused: string | null; guess: number | null;
      votes: Record<string, string>; points: Record<string, number>;
    };
  };
}

/** The state as one player may see it: the secret word only for those who should know it, the stowaway only after the round. */
export function view(s: State, playerId: string, topics: Topic[], now: number): View {
  const me = s.players.find((p) => p.id === playerId)!;
  const r = s.round;
  const inRound = !!r && r.order.includes(playerId);
  const isStowaway = !!r && r.stowaway === playerId && s.phase !== "lobby";
  const done = s.phase === "reveal";
  const host = s.players.find((p) => p.id === s.hostId);
  return {
    code: s.code,
    phase: s.phase,
    me: { id: me.id, name: me.name, host: me.id === s.hostId, inRound, stowaway: isStowaway },
    players: s.players.map((p) => ({
      id: p.id, name: p.name, score: p.score, connected: p.connected, host: p.id === s.hostId,
      inRound: !!r && r.order.includes(p.id), voted: !!r && s.phase === "voting" && !!r.votes[p.id],
    })),
    settings: s.settings,
    roundsPlayed: s.roundsPlayed,
    canClaimHost: me.id !== s.hostId && !!host && !host.connected && s.hostAwaySince !== null && now - s.hostAwaySince >= HOST_GRACE_MS,
    notice: s.notice,
    now,
    round: r ? {
      number: r.number,
      topic: { efni: topics[r.topic].efni, ord: topics[r.topic].ord },
      secret: done || (inRound && !isStowaway) ? r.secret : null,
      order: r.order, turn: r.turn, clues: r.clues, deadline: r.deadline,
      myVote: r.votes[playerId] ?? null,
      accused: s.phase === "guess" || done ? r.accused : null,
      reveal: done ? { secret: r.secret, stowaway: r.stowaway, accused: r.accused, guess: r.guess, votes: r.votes, points: r.points } : null,
    } : null,
  };
}

// ── Helpers ──

export function clampSettings(x: Settings): Settings {
  const int = (v: unknown, lo: number, hi: number, d: number) => {
    const n = Math.round(Number(v));
    return Number.isFinite(n) ? Math.min(hi, Math.max(lo, n)) : d;
  };
  return {
    rounds: int(x.rounds, 1, 20, DEFAULT_SETTINGS.rounds),
    clueSeconds: int(x.clueSeconds, 15, 180, DEFAULT_SETTINGS.clueSeconds),
    voteSeconds: int(x.voteSeconds, 20, 300, DEFAULT_SETTINGS.voteSeconds),
    maxDifficulty: int(x.maxDifficulty, 1, 3, DEFAULT_SETTINGS.maxDifficulty),
    childOnly: x.childOnly === true,
  };
}

/** True if a clue is the secret word itself (ignoring case, spaces and a trailing full stop). */
function sameWord(clue: string, secret: string): boolean {
  const norm = (w: string) => w.toLocaleLowerCase("is").replace(/[\s.!?]+/g, "");
  return norm(clue) === norm(secret);
}

function shuffle<T>(xs: T[], rand: () => number): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rand() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}
