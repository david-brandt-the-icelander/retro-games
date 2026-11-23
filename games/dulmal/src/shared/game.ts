// The rules of Dulmál, as pure functions on a Room: who sits where, dealing a board, clues,
// guesses and turns. The room's Durable Object (worker/room.ts) keeps the Room, calls these for
// each message and sends every connection the view() it may see. Nothing here touches the network.
import {
  MAX_CUSTOM_WORDS, MAX_NAME, MAX_PLAYERS, TEAMS, TIMERS, other,
  type CardKind, type Clue, type ErrorCode, type GameEvent, type PlayerView, type Role, type Team, type View,
} from "./protocol";
import { key, parseWords, pickWords, plain, shuffle } from "./words";

export interface Player {
  id: string;
  token: string;
  name: string;
  team: Team;
  role: Role;
  joined: number;
}

export interface Card { word: string; kind: CardKind; revealed: boolean }

export interface Game {
  number: number;
  cards: Card[];
  first: Team;
  turn: Team;
  phase: "clue" | "guess" | "over";
  clue: Clue | null;
  left: number;
  made: number;
  winner: Team | null;
  ghost: boolean;
  clues: Clue[];
  deadline: number | null;
  event: GameEvent | null;
}

export interface Room {
  code: string;
  created: number;
  /** Last time anyone did anything; an idle room is deleted after a while. */
  active: number;
  /** Who created the room. */
  creator: string | null;
  players: Player[];
  timer: number;
  /** The host's own word list, or null for the built-in one. */
  words: string[] | null;
  game: Game | null;
  games: number;
}

/** What the rules need from outside: the clock, chance, the built-in words and who is online. */
export interface Ctx {
  now: number;
  random: () => number;
  builtin: readonly string[];
  online: ReadonlySet<string>;
}

export type Result = { ok: true } | { ok: false; error: ErrorCode };
const OK: Result = { ok: true };
const fail = (error: ErrorCode): Result => ({ ok: false, error });

export const BOARD = 25;
/** How many words each side gets: the team that starts has one more. */
export const SPLIT = { first: 9, second: 8, neutral: 7, ghost: 1 } as const;

export function newRoom(code: string, now: number): Room {
  return { code, created: now, active: now, creator: null, players: [], timer: 0, words: null, game: null, games: 0 };
}

// ── Seats ──

/** The creator while online; otherwise whoever joined first and is online; failing that, the creator. */
export function hostId(room: Room, online: ReadonlySet<string>): string | null {
  if (room.creator && online.has(room.creator) && room.players.some((p) => p.id === room.creator)) return room.creator;
  const here = room.players.filter((p) => online.has(p.id)).sort((a, b) => a.joined - b.joined)[0];
  return here?.id ?? (room.players.some((p) => p.id === room.creator) ? room.creator : room.players[0]?.id ?? null);
}

export const isHost = (room: Room, id: string, ctx: Ctx): boolean => hostId(room, ctx.online) === id;

/** A name trimmed to fit, made different from everyone else's by a number. */
export function cleanName(room: Room, name: string, self?: string): string | null {
  const base = name.replace(/\s+/g, " ").trim().slice(0, MAX_NAME).trim();
  if (!base) return null;
  const taken = new Set(room.players.filter((p) => p.id !== self).map((p) => key(p.name)));
  if (!taken.has(key(base))) return base;
  for (let n = 2; ; n++) {
    const candidate = `${base.slice(0, MAX_NAME - 2)} ${n}`;
    if (!taken.has(key(candidate))) return candidate;
  }
}

const members = (room: Room, team: Team) => room.players.filter((p) => p.team === team);

/** Each team with anyone in it has exactly one clue-giver: the first one, or its longest-serving member. */
function settleRoles(room: Room): void {
  for (const team of TEAMS) {
    const list = members(room, team).sort((a, b) => a.joined - b.joined);
    const givers = list.filter((p) => p.role === "clue");
    for (const extra of givers.slice(1)) extra.role = "guess";
    if (givers.length === 0 && list[0] && !room.game) list[0].role = "clue";
  }
}

/** The team a newcomer joins: the smaller one, or by chance when they are even. */
function smallerTeam(room: Room, random: () => number): Team {
  const h = members(room, "hraun").length, j = members(room, "jokull").length;
  if (h !== j) return h < j ? "hraun" : "jokull";
  return random() < 0.5 ? "hraun" : "jokull";
}

export function join(room: Room, name: string, id: string, token: string, ctx: Ctx): Result {
  if (room.players.length >= MAX_PLAYERS) return fail("full");
  const clean = cleanName(room, name);
  if (!clean) return fail("name");
  const team = smallerTeam(room, ctx.random);
  const role: Role = !room.game && !members(room, team).some((p) => p.role === "clue") ? "clue" : "guess";
  room.players.push({ id, token, name: clean, team, role, joined: ctx.now });
  if (!room.creator) room.creator = id;
  return OK;
}

export function rename(room: Room, id: string, name: string): Result {
  const p = room.players.find((x) => x.id === id);
  const clean = p && cleanName(room, name, id);
  if (!p || !clean) return fail("name");
  p.name = clean;
  return OK;
}

/** A player moves to the other team (themselves, or the host moves them), before a game starts. */
export function setTeam(room: Room, actor: string, id: string, team: Team, ctx: Ctx): Result {
  if (room.game) return fail("notNow");
  if (actor !== id && !isHost(room, actor, ctx)) return fail("notHost");
  const p = room.players.find((x) => x.id === id);
  if (!p || !TEAMS.includes(team)) return fail("bad");
  if (p.team === team) return OK;
  p.team = team;
  p.role = members(room, team).some((x) => x.id !== id && x.role === "clue") ? "guess" : "clue";
  settleRoles(room);
  return OK;
}

/** Someone becomes their team's clue-giver (themselves, or the host chooses), before a game starts. */
export function setClueGiver(room: Room, actor: string, id: string, ctx: Ctx): Result {
  if (room.game) return fail("notNow");
  if (actor !== id && !isHost(room, actor, ctx)) return fail("notHost");
  const p = room.players.find((x) => x.id === id);
  if (!p) return fail("bad");
  for (const m of members(room, p.team)) m.role = "guess";
  p.role = "clue";
  return OK;
}

/** The host deals everyone into two even teams at random, each with a random clue-giver. */
export function shuffleTeams(room: Room, actor: string, ctx: Ctx): Result {
  if (room.game) return fail("notNow");
  if (!isHost(room, actor, ctx)) return fail("notHost");
  const order = shuffle([...room.players], ctx.random);
  const firstTeam: Team = ctx.random() < 0.5 ? "hraun" : "jokull";
  order.forEach((p, i) => {
    p.team = i % 2 === 0 ? firstTeam : other(firstTeam);
    p.role = i < 2 ? "clue" : "guess";
  });
  return OK;
}

/** The host takes someone out of the room, or a player leaves. */
export function remove(room: Room, actor: string, id: string, ctx: Ctx): Result {
  if (actor !== id && !isHost(room, actor, ctx)) return fail("notHost");
  const at = room.players.findIndex((x) => x.id === id);
  if (at < 0) return fail("bad");
  const [gone] = room.players.splice(at, 1);
  // A clue-giver leaving mid-game hands the role to their team's longest-serving guesser.
  if (gone && gone.role === "clue" && room.game) {
    const next = members(room, gone.team).sort((a, b) => a.joined - b.joined)[0];
    if (next) next.role = "clue";
  }
  settleRoles(room);
  return OK;
}

/** A new device takes over a seat whose owner is not connected, with a new token. */
export function claim(room: Room, id: string, token: string, ctx: Ctx): Result {
  const p = room.players.find((x) => x.id === id);
  if (!p) return fail("bad");
  if (ctx.online.has(id)) return fail("seatTaken");
  p.token = token;
  return OK;
}

// ── Settings ──

export function setTimer(room: Room, actor: string, seconds: number, ctx: Ctx): Result {
  if (!isHost(room, actor, ctx)) return fail("notHost");
  if (!(TIMERS as readonly number[]).includes(seconds)) return fail("bad");
  room.timer = seconds;
  const g = room.game;
  if (g && g.phase !== "over") g.deadline = seconds ? ctx.now + seconds * 1000 : null;
  return OK;
}

/** The host's own list (null goes back to the built-in one), used from the next board dealt. */
export function setWords(room: Room, actor: string, text: string | null, ctx: Ctx): Result {
  if (!isHost(room, actor, ctx)) return fail("notHost");
  if (text === null) { room.words = null; return OK; }
  const list = parseWords(String(text)).slice(0, MAX_CUSTOM_WORDS);
  if (list.length < BOARD || !pickWords(list, BOARD, ctx.random)) return fail("fewWords");
  room.words = list;
  return OK;
}

// ── Playing ──

/** Both teams need a clue-giver and at least one guesser. */
export function ready(room: Room): boolean {
  return TEAMS.every((t) => {
    const m = members(room, t);
    return m.some((p) => p.role === "clue") && m.some((p) => p.role === "guess");
  });
}

/** Deals a new board with the teams as they are: a new game, from the lobby or after one. */
export function deal(room: Room, actor: string, ctx: Ctx): Result {
  if (!isHost(room, actor, ctx)) return fail("notHost");
  settleRoles(room);
  if (!ready(room)) return fail("needTeams");
  const words = pickWords(room.words ?? ctx.builtin, BOARD, ctx.random) ?? pickWords(ctx.builtin, BOARD, ctx.random);
  if (!words) return fail("fewWords");
  const first: Team = ctx.random() < 0.5 ? "hraun" : "jokull";
  const kinds: CardKind[] = [
    ...Array<CardKind>(SPLIT.first).fill(first),
    ...Array<CardKind>(SPLIT.second).fill(other(first)),
    ...Array<CardKind>(SPLIT.neutral).fill("neutral"),
    "ghost",
  ];
  shuffle(kinds, ctx.random);
  room.games += 1;
  room.game = {
    number: room.games,
    cards: words.map((word, i) => ({ word, kind: kinds[i]!, revealed: false })),
    first, turn: first, phase: "clue", clue: null, left: 0, made: 0,
    winner: null, ghost: false, clues: [], deadline: null, event: null,
  };
  startPhase(room, ctx.now);
  return OK;
}

/** The host takes everyone back to the lobby, ending any game. */
export function toLobby(room: Room, actor: string, ctx: Ctx): Result {
  if (!isHost(room, actor, ctx)) return fail("notHost");
  room.game = null;
  settleRoles(room);
  return OK;
}

function startPhase(room: Room, now: number): void {
  const g = room.game!;
  g.deadline = room.timer && g.phase !== "over" ? now + room.timer * 1000 : null;
}

function endTurn(room: Room, now: number): void {
  const g = room.game!;
  g.turn = other(g.turn);
  g.phase = "clue";
  g.clue = null;
  g.left = 0;
  g.made = 0;
  startPhase(room, now);
}

function finish(g: Game, winner: Team, ghost: boolean): void {
  g.phase = "over";
  g.winner = winner;
  g.ghost = ghost;
  g.deadline = null;
}

export const remaining = (g: Game, team: Team): number => g.cards.filter((c) => c.kind === team && !c.revealed).length;

/** A clue: one word (letters, digits or hyphens) that is not on the board, and a number from 1 to 9. */
export function clueError(g: Game, word: string, number: number): ErrorCode | null {
  const w = plain(String(word));
  if (!w || w.length > 30 || !/^[\p{L}\p{N}-]+$/u.test(w)) return "clueWord";
  if (g.cards.some((c) => !c.revealed && key(c.word) === key(w))) return "clueOnBoard";
  if (!Number.isInteger(number) || number < 1 || number > 9) return "clueNumber";
  return null;
}

export function giveClue(room: Room, actor: string, word: string, number: number, ctx: Ctx): Result {
  const g = room.game, p = room.players.find((x) => x.id === actor);
  if (!g || g.phase !== "clue") return fail("notNow");
  if (!p || p.team !== g.turn || p.role !== "clue") return fail("notYou");
  const error = clueError(g, word, number);
  if (error) return fail(error);
  const clean = plain(word);
  g.clue = { team: g.turn, word: clean.charAt(0).toLocaleUpperCase("is-IS") + clean.slice(1), number };
  g.clues.push(g.clue);
  g.phase = "guess";
  g.left = number + 1;
  g.made = 0;
  g.event = { type: "clue", team: g.turn };
  startPhase(room, ctx.now);
  return OK;
}

export function guess(room: Room, actor: string, index: number, ctx: Ctx): Result {
  const g = room.game, p = room.players.find((x) => x.id === actor);
  if (!g || g.phase !== "guess") return fail("notNow");
  if (!p || p.team !== g.turn || p.role !== "guess") return fail("notYou");
  const card = Number.isInteger(index) ? g.cards[index] : undefined;
  if (!card) return fail("bad");
  if (card.revealed) return fail("revealed");
  card.revealed = true;
  const team = g.turn;
  g.event = { type: "guess", team, index, by: p.name };
  g.made += 1;
  if (card.kind === "ghost") { finish(g, other(team), true); return OK; }
  if (card.kind === team) {
    if (remaining(g, team) === 0) { finish(g, team, false); return OK; }
    g.left -= 1;
    if (g.left <= 0) endTurn(room, ctx.now);
    return OK;
  }
  if (card.kind === other(team) && remaining(g, other(team)) === 0) { finish(g, other(team), false); return OK; }
  endTurn(room, ctx.now);
  return OK;
}

/** The guessers stop: allowed once they have made at least one guess this turn. */
export function stop(room: Room, actor: string, ctx: Ctx): Result {
  const g = room.game, p = room.players.find((x) => x.id === actor);
  if (!g || g.phase !== "guess") return fail("notNow");
  if (!p || p.team !== g.turn || p.role !== "guess") return fail("notYou");
  if (g.made < 1) return fail("guessFirst");
  g.event = { type: "stop", team: g.turn };
  endTurn(room, ctx.now);
  return OK;
}

/** The turn timer ran out: the team on turn loses the rest of it. True when that changed anything. */
export function expire(room: Room, now: number): boolean {
  const g = room.game;
  if (!g || g.phase === "over" || g.deadline === null || now < g.deadline) return false;
  g.event = { type: "timeout", team: g.turn };
  endTurn(room, now);
  return true;
}

// ── What each device sees ──

export interface Viewer { id: string | null; screen: boolean }

export function view(room: Room, viewer: Viewer, ctx: Ctx): View {
  const me = viewer.id ? room.players.find((p) => p.id === viewer.id) ?? null : null;
  const pv = (p: Player): PlayerView => ({ id: p.id, name: p.name, team: p.team, role: p.role, online: ctx.online.has(p.id) });
  const g = room.game;
  const seesKey = !!g && (g.phase === "over" || (!!me && me.role === "clue" && !viewer.screen));
  return {
    code: room.code,
    now: ctx.now,
    you: me && !viewer.screen ? pv(me) : null,
    screen: viewer.screen,
    hostId: hostId(room, ctx.online),
    players: [...room.players].sort((a, b) => a.joined - b.joined).map(pv),
    timer: room.timer,
    customWords: room.words?.length ?? 0,
    game: g && {
      number: g.number,
      cards: g.cards.map((c) => ({ word: c.word, revealed: c.revealed, kind: c.revealed || seesKey ? c.kind : null })),
      first: g.first, turn: g.turn, phase: g.phase, clue: g.clue, left: g.left, made: g.made,
      winner: g.winner, ghost: g.ghost, clues: g.clues,
      remaining: { hraun: remaining(g, "hraun"), jokull: remaining(g, "jokull") },
      deadline: g.deadline, event: g.event,
    },
  };
}
