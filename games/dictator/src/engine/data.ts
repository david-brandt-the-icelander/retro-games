// The game's balance, restated from docs/RULES.md §17 as objects with named fields.
// Money is in thousands of dollars. `once` is added to the treasury when granted;
// `monthly` is added to the monthly running costs (negative lowers them).

export type GroupKey = "army" | "peasants" | "landowners" | "guerrillas" | "neighbour" | "police" | "east" | "west";

/** Group keys in the fixed group order (index 0–7). */
export const GROUP_KEYS: readonly GroupKey[] = ["army", "peasants", "landowners", "guerrillas", "neighbour", "police", "east", "west"];

export type Changes = Partial<Record<GroupKey, number>>;

export interface Effects {
  popularity: Changes;
  strength: Changes;
  once: number;
  monthly: number;
}

export interface Request extends Effects {
  /** The faction that asks: 0 Army, 1 Peasants, 2 Landowners. */
  from: number;
}

export interface Decision extends Effects {
  /** Section 1–5 of the decision menu. */
  section: number;
  /** Repeatable options are never marked used. */
  repeatable: boolean;
  /** Special options skip advice and the dialog (Swiss account, loans). */
  special: "swiss" | "loanEast" | "loanWest" | null;
  /** The bodyguard decision also raises the President's strength by 2. */
  bodyguard: boolean;
  /** The helicopter decision gives the President the helicopter. */
  helicopter: boolean;
}

export interface Headline {
  popularity: Changes;
  strength: Changes;
}

const req = (from: number, popularity: Changes, strength: Changes, once = 0, monthly = 0): Request =>
  ({ from, popularity, strength, once, monthly });

/** Requests R1–R24 (index 0–23): eight each from the Army, the Peasants and the Landowners. */
export const REQUESTS: readonly Request[] = [
  req(0, { army: 4, peasants: -3, landowners: -1 }, { army: 3, peasants: -2, landowners: -1 }, 0, 5),
  req(0, { army: 3, landowners: -3 }, { army: 1, landowners: -1 }),
  req(0, { army: 3, peasants: -1, landowners: 1, neighbour: -1, east: -1 }, { army: 1, landowners: 1, guerrillas: -4 }, -100),
  req(0, { army: 3, peasants: -1, neighbour: -4, east: -1 }, { army: 1, landowners: 1, guerrillas: -2 }, -80),
  req(0, { army: 4, peasants: 2, landowners: 1, police: -4 }, { army: 1, landowners: 1, police: -3 }),
  req(0, { army: 3, neighbour: -1, east: -4, west: 2 }, {}),
  req(0, { army: 4, landowners: -1 }, { army: 2, peasants: -1, landowners: -1, guerrillas: -1 }, 0, 9),
  req(0, { army: 4, peasants: -1, landowners: -1, neighbour: -1, police: -1 }, { army: 3, peasants: -1, landowners: -1, guerrillas: -2, neighbour: -1 }, -120),

  req(1, { army: -1, peasants: 2, landowners: 1 }, { army: -1, guerrillas: -1 }),
  req(1, { peasants: 4, landowners: -4, neighbour: 1 }, { peasants: 2, landowners: -1 }),
  req(1, { army: 1, peasants: 4, landowners: 2, police: -4 }, { army: 1, peasants: 1, landowners: 1, guerrillas: 1, police: -3 }, 0, -3),
  req(1, { peasants: 3, landowners: -2, neighbour: -2 }, { peasants: 2, landowners: -2 }),
  req(1, { army: -1, peasants: 4, landowners: -2, neighbour: 2, police: -1, east: 1 }, { peasants: 1, landowners: -1, guerrillas: -1 }, -100, 8),
  req(1, { peasants: 4, landowners: -3, neighbour: 1, police: -1, east: 1 }, { peasants: 3, landowners: -3, police: -1 }),
  req(1, { army: -1, peasants: 4, landowners: -2, neighbour: 1, police: -1 }, { peasants: 2, landowners: -1, guerrillas: -1 }),
  req(1, { peasants: 3, landowners: -1 }, { guerrillas: -1 }, 0, -6),

  req(2, { army: -2, landowners: 3 }, { army: -1 }),
  req(2, { peasants: -4, landowners: 4, neighbour: -1, east: -1 }, { peasants: -2, landowners: 2, guerrillas: 1 }),
  req(2, { landowners: 3, neighbour: 1, east: 2, west: -4 }, { landowners: 1 }, 100, 5),
  req(2, { landowners: 3, neighbour: -3, east: -1 }, { peasants: 1, landowners: 2, neighbour: -1 }, 0, -5),
  req(2, { army: 1, peasants: 1, landowners: 3, police: -4 }, { army: 1, landowners: 1, guerrillas: 1, police: -2 }, 0, -4),
  req(2, { landowners: 4 }, { landowners: 2 }, 0, 5),
  req(2, { army: -2, peasants: -1, landowners: 3 }, { army: -1, peasants: -1, landowners: 1, guerrillas: 1 }),
  req(2, { army: 1, peasants: 1, landowners: 3, neighbour: -3, east: 2, west: 1 }, { landowners: 3, neighbour: -2 }, -120, 10),
];

const dec = (section: number, popularity: Changes, strength: Changes, once = 0, monthly = 0, extra: Partial<Decision> = {}): Decision =>
  ({ section, popularity, strength, once, monthly, repeatable: false, special: null, bodyguard: false, helicopter: false, ...extra });

/** Presidential decisions D1–D19 (index 0–18). */
export const DECISIONS: readonly Decision[] = [
  dec(1, { army: 4, peasants: -1, landowners: -1, police: -1 }, { army: 1, guerrillas: -1, police: -1 }),
  dec(1, { army: -1, peasants: 4, landowners: 1, neighbour: 2, east: 1 }, { guerrillas: -1 }, -10, 4),
  dec(1, { army: -1, peasants: -2, landowners: 4, police: -1, east: -1 }, { army: -1, peasants: -1, landowners: 2, police: -1 }),
  dec(1, { army: -2, neighbour: 4, east: -2, west: 1 }, { army: -1, guerrillas: -1, neighbour: 3 }, 50),
  dec(1, { landowners: -1, neighbour: -1, east: -2, west: 3 }, {}, 120),
  dec(1, { army: -2, east: 3, west: -3 }, { neighbour: 1 }, 0, -10),

  dec(2, { army: 1, peasants: 3, landowners: 3 }, { army: -1, guerrillas: -1 }, 0, 8),
  dec(2, { army: 3, peasants: 3, landowners: 3 }, { guerrillas: -1 }, -80),
  dec(2, { army: 3, peasants: 3, landowners: 3, police: -9 }, { army: 2, peasants: 1, landowners: 1, guerrillas: 1, police: -9 }, 0, -8),

  dec(3, { army: -3, peasants: -3, landowners: -3, police: 8 }, { army: -1, peasants: -1, landowners: -1, guerrillas: -1, police: 8 }, 0, 6),
  dec(3, { army: -2, peasants: -1, landowners: -1, police: -1 }, { army: -2, police: -1 }, -40, 0, { repeatable: true, bodyguard: true }),
  dec(3, { army: -4, peasants: -4, landowners: -3, police: -2 }, {}, -120, 0, { helicopter: true }),
  dec(3, {}, {}, 0, 0, { repeatable: true, special: "swiss" }),

  dec(4, {}, {}, 0, 0, { special: "loanEast" }),
  dec(4, {}, {}, 0, 0, { special: "loanWest" }),
  dec(4, { army: 1, peasants: 1, landowners: 3, neighbour: -6, east: -2 }, {}, 130),

  dec(5, { army: 3, neighbour: -3, east: -1 }, { army: 5, guerrillas: -2, neighbour: -2, police: -1 }, -50),
  dec(5, { peasants: 3, landowners: -1, police: -1 }, { peasants: 5, landowners: -1, guerrillas: 3, police: -1 }),
  dec(5, { army: -1, peasants: -1, landowners: 3, police: -1 }, { army: -1, peasants: -1, landowners: 5, guerrillas: -1, police: -1 }),
];

/** Headlines N1–N6 (index 0–5). News moves no money (RULES §9.4). */
export const HEADLINES: readonly Headline[] = [
  { popularity: { police: -4 }, strength: { guerrillas: 4, police: -4 } },
  { popularity: {}, strength: { army: -1, guerrillas: 9 } },
  { popularity: {}, strength: { army: -4, guerrillas: 2, police: 1 } },
  { popularity: {}, strength: { landowners: -3, neighbour: -2 } },
  { popularity: {}, strength: { landowners: 2, neighbour: -4 } },
  { popularity: {}, strength: { peasants: -4, landowners: -1, guerrillas: -2 } },
];

/** The decision indexes (0–18) in each section 1–5, by position. */
export const SECTIONS: readonly (readonly number[])[] = [1, 2, 3, 4, 5].map((n) =>
  DECISIONS.map((d, i) => (d.section === n ? i : -1)).filter((i) => i >= 0));

/** A group's index from its key. */
export const groupIndex = (k: GroupKey): number => GROUP_KEYS.indexOf(k);
