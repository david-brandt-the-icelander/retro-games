// Kvarðinn's rules: one room's whole state and every move a player can make, as plain data and
// pure functions. The room's Durable Object (worker/room.ts) holds a Game, feeds it each player's
// message through act(), and sends every device its own viewFor(): the hidden target leaves the
// server only for the round's clue-giver, until the reveal.
//
// No clocks and no Math.random here: random numbers come in through Ctx.rng, so the tests can
// play whole games from a seed.

export type TeamId = 0 | 1;
export type Phase = "lobby" | "clue" | "guess" | "bonus" | "reveal" | "over";
export type Mode = "teams" | "coop";
export type Side = "L" | "R";
/** A scale card: its left and right ends. */
export type Card = [string, string];

export const TEAM_NAMES = ["Aldan", "Sólin"] as const;
export const MAX_PLAYERS = 12;
export const MAX_NAME = 20;
export const MAX_CLUE = 80;
export const MAX_END = 30;
export const MAX_CUSTOM = 60;
/** Half-widths of the scoring bands around the target, on the 0–100 scale: 4, 3 and 2 points. */
export const BANDS: readonly [number, number, number] = [3, 9, 15];
export const GOALS = [5, 10, 15, 20] as const;
export const ROUND_COUNTS = [5, 10, 15] as const;

export interface Player {
  id: string;
  /** The seat's secret: a device that shows it gets the seat back after a refresh or a drop. */
  token: string;
  name: string;
  team: TeamId;
  /** Join order: clue-givers take turns in it. */
  seq: number;
}

export interface Settings {
  mode: Mode;
  /** Points to win, in team mode. */
  goal: number;
  /** Rounds in a game, when everyone plays together. */
  rounds: number;
  /** The other team's left-or-right guess, for one point. */
  bonus: boolean;
  /** Play only the host's own scales. */
  customOnly: boolean;
}

export interface Result {
  points: number;
  /** The team that made the left-or-right guess, and whether it was right. */
  bonusTeam: TeamId | null;
  bonusOk: boolean | null;
  /** The game is over after this round; winner is null in co-op mode. */
  finished: boolean;
  winner: TeamId | null;
  newBest: boolean;
}

export interface Round {
  n: number;
  giver: string;
  /** The guessing team; null when everyone plays together. */
  team: TeamId | null;
  card: Card;
  /** Where the hidden target sits, 0–100. Never in a view before the reveal, except the giver's. */
  target: number;
  clue: string;
  pointer: number;
  /** Who last moved the pointer. */
  mover: string | null;
  /** The player who locks the team's guess in. */
  locker: string;
  /** The player who confirms the other team's left-or-right guess. */
  bonusLocker: string | null;
  bonusPick: Side | null;
  result: Result | null;
}

export interface Game {
  code: string;
  phase: Phase;
  players: Player[];
  host: string | null;
  settings: Settings;
  customs: Card[];
  scores: [number, number];
  coopScore: number;
  /** The group's best co-op score in this room. */
  best: number | null;
  /** How many clues each team has given, and the group in co-op: whose turn is next. */
  turns: [number, number];
  coopTurns: number;
  round: Round | null;
  deck: Card[];
  nextSeq: number;
  startTeam: TeamId;
}

/** What act() needs from outside: who is connected, randomness and the built-in cards. */
export interface Ctx {
  online: ReadonlySet<string>;
  rng: () => number;
  cards: readonly Card[];
}

export type Action =
  | { a: "team"; team: TeamId }
  | { a: "rename"; name: string }
  | { a: "settings"; settings: Partial<Settings> }
  | { a: "shuffle" }
  | { a: "move-player"; pid: string; team: TeamId }
  | { a: "add-card"; left: string; right: string }
  | { a: "remove-card"; index: number }
  | { a: "kick"; pid: string }
  | { a: "start" }
  | { a: "redraw" }
  | { a: "ready"; clue: string }
  | { a: "move"; value: number }
  | { a: "lock" }
  | { a: "pick"; side: Side }
  | { a: "bonus-lock" }
  | { a: "next" }
  | { a: "skip" }
  | { a: "again" };

/** ok: what changed — "full" means send everyone a new view, "pointer" only the pointer. */
export type Outcome = { ok: true; change: "full" | "pointer" } | { ok: false; error: string };

const fail = (error: string): Outcome => ({ ok: false, error });
const FULL: Outcome = { ok: true, change: "full" };

export function newGame(code: string): Game {
  return {
    code,
    phase: "lobby",
    players: [],
    host: null,
    settings: { mode: "teams", goal: 10, rounds: 10, bonus: true, customOnly: false },
    customs: [],
    scores: [0, 0],
    coopScore: 0,
    best: null,
    turns: [0, 0],
    coopTurns: 0,
    round: null,
    deck: [],
    nextSeq: 1,
    startTeam: 0,
  };
}

/** Trims, squeezes spaces and drops control characters. */
export function cleanText(s: unknown, max: number): string {
  if (typeof s !== "string") return "";
  // eslint-disable-next-line no-control-regex
  return s.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, max);
}

const randomId = (rng: () => number, n: number): string => {
  const abc = "abcdefghijklmnopqrstuvwxyz0123456789";
  let s = "";
  for (let i = 0; i < n; i++) s += abc[Math.floor(rng() * abc.length)];
  return s;
};

/** Seats a new player. The first one in is the host. */
export function addPlayer(game: Game, rawName: unknown, team: unknown, ctx: Ctx): { ok: true; player: Player } | { ok: false; error: string } {
  const name = cleanText(rawName, MAX_NAME);
  if (!name) return { ok: false, error: "Skrifaðu nafnið þitt." };
  if (game.players.length >= MAX_PLAYERS) return { ok: false, error: "Leikurinn er fullur." };
  if (game.players.some((p) => p.name.toLowerCase() === name.toLowerCase())) return { ok: false, error: "Einhver annar heitir þessu nafni. Veldu annað nafn." };
  const t: TeamId = team === 0 || team === 1 ? team : smallerTeam(game);
  const player: Player = { id: randomId(ctx.rng, 10), token: randomId(ctx.rng, 24), name, team: t, seq: game.nextSeq++ };
  game.players.push(player);
  if (!game.host || !game.players.some((p) => p.id === game.host)) game.host = player.id;
  return { ok: true, player };
}

function smallerTeam(game: Game): TeamId {
  const a = game.players.filter((p) => p.team === 0).length;
  const b = game.players.length - a;
  return a <= b ? 0 : 1;
}

/** The host, or, while the host is offline, the earliest-joined player who is online. */
export function effectiveHost(game: Game, online: ReadonlySet<string>): string | null {
  if (game.host && online.has(game.host)) return game.host;
  const first = [...game.players].sort((x, y) => x.seq - y.seq).find((p) => online.has(p.id));
  return first ? first.id : game.host;
}

export function membersOf(game: Game, team: TeamId | null): Player[] {
  return game.players.filter((p) => team === null || p.team === team).sort((x, y) => x.seq - y.seq);
}

/** Points for a guess: 4 in the centre band, then 3, then 2, else 0. */
export function scoreFor(target: number, pointer: number): number {
  const d = Math.abs(pointer - target);
  if (d <= BANDS[0]) return 4;
  if (d <= BANDS[1]) return 3;
  if (d <= BANDS[2]) return 2;
  return 0;
}

/** Is the target on that side of the pointer? A target right under it is on neither. */
export function sideIsRight(side: Side, target: number, pointer: number): boolean {
  return side === "L" ? target < pointer : target > pointer;
}

const present = (game: Game, pid: string | null, online: ReadonlySet<string>): boolean =>
  !!pid && online.has(pid) && game.players.some((p) => p.id === pid);

export function canMove(game: Game, pid: string): boolean {
  const r = game.round;
  if (game.phase !== "guess" || !r || pid === r.giver) return false;
  const p = game.players.find((x) => x.id === pid);
  return !!p && (r.team === null || p.team === r.team);
}

export function canLock(game: Game, pid: string, online: ReadonlySet<string>): boolean {
  const r = game.round;
  return !!r && canMove(game, pid) && (pid === r.locker || !present(game, r.locker, online));
}

export function bonusTeam(game: Game): TeamId | null {
  const r = game.round;
  return r && r.team !== null ? ((1 - r.team) as TeamId) : null;
}

export function canPick(game: Game, pid: string): boolean {
  const t = bonusTeam(game);
  const p = game.players.find((x) => x.id === pid);
  return game.phase === "bonus" && t !== null && !!p && p.team === t;
}

export function canBonusLock(game: Game, pid: string, online: ReadonlySet<string>): boolean {
  const r = game.round;
  return !!r && canPick(game, pid) && r.bonusPick !== null && (pid === r.bonusLocker || !present(game, r.bonusLocker, online));
}

function shuffled<T>(xs: readonly T[], rng: () => number): T[] {
  const a = [...xs];
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(rng() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

function draw(game: Game, ctx: Ctx, avoid?: Card): Card {
  if (game.deck.length === 0) {
    const pool = game.settings.customOnly && game.customs.length > 0 ? game.customs : [...ctx.cards, ...game.customs];
    game.deck = shuffled(pool, ctx.rng);
    if (avoid && game.deck.length > 1 && game.deck[game.deck.length - 1][0] === avoid[0] && game.deck[game.deck.length - 1][1] === avoid[1]) game.deck.unshift(game.deck.pop()!);
  }
  return game.deck.pop() ?? ["Kalt", "Heitt"];
}

/** The next player in turn order after index i who is online (or i itself when nobody else is). */
function nextOnline(list: Player[], from: number, online: ReadonlySet<string>): number {
  for (let k = 0; k < list.length; k++) {
    const j = (from + k) % list.length;
    if (online.has(list[j].id)) return j;
  }
  return from % list.length;
}

function startRound(game: Game, ctx: Ctx): void {
  const prev = game.round;
  const coop = game.settings.mode === "coop";
  const team: TeamId | null = coop ? null : prev && prev.team !== null ? ((1 - prev.team) as TeamId) : game.startTeam;
  const list = membersOf(game, team);
  const counter = team === null ? game.coopTurns : game.turns[team];
  const gi = nextOnline(list, counter, ctx.online);
  if (team === null) game.coopTurns = gi + 1;
  else game.turns[team] = gi + 1;
  const giver = list[gi];
  // The locker is the next player after the giver who is online (or simply the next one).
  let locker = list[(gi + 1) % list.length];
  for (let k = 1; k < list.length; k++) {
    const p = list[(gi + k) % list.length];
    if (ctx.online.has(p.id)) { locker = p; break; }
  }

  let bonusLocker: string | null = null;
  if (team !== null) {
    const other = membersOf(game, (1 - team) as TeamId);
    if (other.length > 0) bonusLocker = other[nextOnline(other, game.turns[1 - team], ctx.online)].id;
  }
  game.round = {
    n: (prev?.n ?? 0) + 1,
    giver: giver.id,
    team,
    card: draw(game, ctx),
    target: 5 + Math.floor(ctx.rng() * 91),
    clue: "",
    pointer: 50,
    mover: null,
    locker: locker.id,
    bonusLocker,
    bonusPick: null,
    result: null,
  };
  game.phase = "clue";
}

function reveal(game: Game): void {
  const r = game.round!;
  const points = scoreFor(r.target, r.pointer);
  const res: Result = { points, bonusTeam: null, bonusOk: null, finished: false, winner: null, newBest: false };
  if (r.team === null) {
    game.coopScore += points;
    if (r.n >= game.settings.rounds) {
      res.finished = true;
      if (game.best === null || game.coopScore > game.best) {
        res.newBest = game.best !== null || game.coopScore > 0;
        game.best = game.coopScore;
      }
    }
  } else {
    game.scores[r.team] += points;
    if (r.bonusPick) {
      const other = (1 - r.team) as TeamId;
      res.bonusTeam = other;
      res.bonusOk = sideIsRight(r.bonusPick, r.target, r.pointer);
      if (res.bonusOk) game.scores[other] += 1;
    }
    const [a, b] = game.scores;
    if (Math.max(a, b) >= game.settings.goal && a !== b) {
      res.finished = true;
      res.winner = a > b ? 0 : 1;
    }
  }
  r.result = res;
  game.phase = "reveal";
}

function startGame(game: Game, ctx: Ctx): Outcome {
  const coop = game.settings.mode === "coop";
  if (coop) {
    if (game.players.length < 2) return fail("Það þarf að minnsta kosti tvo leikmenn.");
  } else if (membersOf(game, 0).length < 2 || membersOf(game, 1).length < 2) {
    return fail("Hvort lið þarf að minnsta kosti tvo leikmenn.");
  }
  if (game.settings.customOnly && game.customs.length === 0) return fail("Það eru engir eigin kvarðar. Bættu einhverjum við eða slökktu á „Bara eigin kvarðar“.");
  game.scores = [0, 0];
  game.coopScore = 0;
  game.turns = [0, 0];
  game.coopTurns = 0;
  game.round = null;
  game.deck = [];
  game.startTeam = ctx.rng() < 0.5 ? 0 : 1;
  startRound(game, ctx);
  return FULL;
}

/** Applies one player's action. Checks everything first, so a refused action changes nothing. */
export function act(game: Game, pid: string, action: Action, ctx: Ctx): Outcome {
  const me = game.players.find((p) => p.id === pid);
  if (!me) return fail("Þú ert ekki í þessum leik.");
  const isHost = effectiveHost(game, ctx.online) === pid;
  const r = game.round;
  const hostOnly = (): Outcome | null => (isHost ? null : fail("Aðeins gestgjafinn getur gert þetta."));
  const inLobby = (): Outcome | null => (game.phase === "lobby" ? null : fail("Þetta er bara hægt áður en leikurinn hefst."));

  switch (action.a) {
    case "team": {
      if (action.team !== 0 && action.team !== 1) return fail("Óþekkt lið.");
      const e = inLobby();
      if (e) return e;
      me.team = action.team;
      return FULL;
    }
    case "rename": {
      const name = cleanText(action.name, MAX_NAME);
      if (!name) return fail("Skrifaðu nafnið þitt.");
      if (game.players.some((p) => p.id !== pid && p.name.toLowerCase() === name.toLowerCase())) return fail("Einhver annar heitir þessu nafni. Veldu annað nafn.");
      me.name = name;
      return FULL;
    }
    case "settings": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      const s = action.settings ?? {};
      const next = { ...game.settings };
      if (s.mode === "teams" || s.mode === "coop") next.mode = s.mode;
      if (typeof s.goal === "number" && (GOALS as readonly number[]).includes(s.goal)) next.goal = s.goal;
      if (typeof s.rounds === "number" && (ROUND_COUNTS as readonly number[]).includes(s.rounds)) next.rounds = s.rounds;
      if (typeof s.bonus === "boolean") next.bonus = s.bonus;
      if (typeof s.customOnly === "boolean") next.customOnly = s.customOnly;
      game.settings = next;
      return FULL;
    }
    case "shuffle": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      const order = shuffled(game.players, ctx.rng);
      order.forEach((p, i) => (p.team = (i % 2) as TeamId));
      return FULL;
    }
    case "move-player": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      const p = game.players.find((x) => x.id === action.pid);
      if (!p || (action.team !== 0 && action.team !== 1)) return fail("Leikmaður finnst ekki.");
      p.team = action.team;
      return FULL;
    }
    case "add-card": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      const left = cleanText(action.left, MAX_END);
      const right = cleanText(action.right, MAX_END);
      if (!left || !right) return fail("Skrifaðu báða enda kvarðans.");
      if (game.customs.length >= MAX_CUSTOM) return fail("Ekki er hægt að bæta við fleiri kvörðum.");
      game.customs.push([left, right]);
      return FULL;
    }
    case "remove-card": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      if (!Number.isInteger(action.index) || action.index < 0 || action.index >= game.customs.length) return fail("Kvarðinn finnst ekki.");
      game.customs.splice(action.index, 1);
      return FULL;
    }
    case "kick": {
      const e = hostOnly();
      if (e) return e;
      if (action.pid === pid) return fail("Þú getur ekki fjarlægt sjálfa(n) þig.");
      const i = game.players.findIndex((x) => x.id === action.pid);
      if (i < 0) return fail("Leikmaður finnst ekki.");
      game.players.splice(i, 1);
      if (game.host === action.pid) game.host = pid;
      if (r && (game.phase === "clue" || game.phase === "guess" || game.phase === "bonus") && r.giver === action.pid) {
        undoRound(game);
        startRound(game, ctx);
      }
      return FULL;
    }
    case "start": {
      const e = hostOnly() ?? inLobby();
      if (e) return e;
      return startGame(game, ctx);
    }
    case "redraw": {
      if (game.phase !== "clue" || !r || r.giver !== pid) return fail("Aðeins sá sem gefur vísbendingu getur skipt um spjald.");
      r.card = draw(game, ctx, r.card);
      return FULL;
    }
    case "ready": {
      if (game.phase !== "clue" || !r || r.giver !== pid) return fail("Aðeins sá sem gefur vísbendingu getur gert þetta.");
      r.clue = cleanText(action.clue, MAX_CLUE);
      game.phase = "guess";
      return FULL;
    }
    case "move": {
      if (!r || !canMove(game, pid)) return fail("Þú getur ekki fært vísinn núna.");
      const v = Number(action.value);
      if (!Number.isFinite(v)) return fail("Ógilt gildi.");
      r.pointer = Math.round(Math.min(100, Math.max(0, v)) * 10) / 10;
      const first = r.mover !== pid;
      r.mover = pid;
      return { ok: true, change: first ? "full" : "pointer" };
    }
    case "lock": {
      if (!r || !canLock(game, pid, ctx.online)) return fail("Þú getur ekki læst ágiskuninni.");
      const t = bonusTeam(game);
      const bonusOn = game.settings.bonus && t !== null && membersOf(game, t).some((p) => ctx.online.has(p.id));
      if (bonusOn) game.phase = "bonus";
      else reveal(game);
      return FULL;
    }
    case "pick": {
      if (!r || !canPick(game, pid) || (action.side !== "L" && action.side !== "R")) return fail("Þú getur ekki valið núna.");
      r.bonusPick = action.side;
      return FULL;
    }
    case "bonus-lock": {
      if (!r || !canBonusLock(game, pid, ctx.online)) return fail("Þú getur ekki staðfest valið.");
      reveal(game);
      return FULL;
    }
    case "next": {
      if (game.phase !== "reveal" || !r?.result) return fail("Umferðinni er ekki lokið.");
      if (r.result.finished) game.phase = "over";
      else startRound(game, ctx);
      return FULL;
    }
    case "skip": {
      const e = hostOnly();
      if (e) return e;
      if (game.phase !== "clue" && game.phase !== "guess" && game.phase !== "bonus") return fail("Engin umferð í gangi.");
      undoRound(game);
      startRound(game, ctx);
      return FULL;
    }
    case "again": {
      const e = hostOnly();
      if (e) return e;
      if (game.phase === "lobby") return fail("Leikurinn er ekki hafinn.");
      game.phase = "lobby";
      game.round = null;
      game.scores = [0, 0];
      game.coopScore = 0;
      return FULL;
    }
    default:
      return fail("Óþekkt aðgerð.");
  }
}

/** A skipped round doesn't count: the same team goes again with its next clue-giver. */
function undoRound(game: Game): void {
  const r = game.round;
  if (!r) return;
  game.round = r.n > 1 ? { ...r, n: r.n - 1, team: r.team === null ? null : ((1 - r.team) as TeamId) } : null;
  if (!game.round && r.team !== null) game.startTeam = r.team;
}

export interface PlayerView {
  id: string;
  name: string;
  team: TeamId;
  online: boolean;
}

export type RoundView = Omit<Round, "target"> & { target: number | null };

export interface View {
  code: string;
  phase: Phase;
  you: string | null;
  host: string | null;
  players: PlayerView[];
  settings: Settings;
  customs: Card[];
  scores: [number, number];
  coopScore: number;
  best: number | null;
  round: RoundView | null;
  /** Whose turn comes next, for the reveal screen. */
  nextGiver: string | null;
}

/**
 * What one device may see. Seat tokens and the deck never leave the server, and the target only
 * goes to the round's clue-giver until the reveal. A big screen (viewer null) sees what a
 * non-giver sees.
 */
export function viewFor(game: Game, viewer: string | null, online: ReadonlySet<string>): View {
  const r = game.round;
  const revealed = game.phase === "reveal" || game.phase === "over";
  const round: RoundView | null = r
    ? { ...r, card: [r.card[0], r.card[1]], result: r.result ? { ...r.result } : null, target: revealed || (viewer !== null && viewer === r.giver) ? r.target : null }
    : null;
  return {
    code: game.code,
    phase: game.phase,
    you: viewer,
    host: effectiveHost(game, online),
    players: membersOf(game, null).map((p) => ({ id: p.id, name: p.name, team: p.team, online: online.has(p.id) })),
    settings: { ...game.settings },
    customs: game.customs.map((c) => [c[0], c[1]] as Card),
    scores: [game.scores[0], game.scores[1]],
    coopScore: game.coopScore,
    best: game.best,
    round,
    nextGiver: game.phase === "reveal" ? predictNextGiver(game, online) : null,
  };
}

function predictNextGiver(game: Game, online: ReadonlySet<string>): string | null {
  const r = game.round;
  if (!r || r.result?.finished) return null;
  const team: TeamId | null = r.team === null ? null : ((1 - r.team) as TeamId);
  const list = membersOf(game, team);
  if (list.length === 0) return null;
  const counter = team === null ? game.coopTurns : game.turns[team];
  return list[nextOnline(list, counter, online)].id;
}
