// The four stages, as data: platforms (sloped girders, belts, lifts), ladders and where everything starts.
// The geometry is this game's own. The screen is 224 × 256 and y grows downward; a thing's y is its feet.

export const W = 224;
export const H = 256;

export type Kind = "girders" | "conveyors" | "elevators" | "rivets";

export interface Platform {
  id: number;
  x1: number;
  y1: number;
  x2: number;
  y2: number;
  /** A conveyor belt's push in pixels a frame (positive is to the right); 0 for a plain platform. */
  belt: number;
  /** A lift's speed in pixels a frame (negative is up); 0 for a fixed platform. */
  lift: number;
}

export interface Ladder {
  x: number;
  /** The platform at the ladder's foot (lower on screen) and the one at its top. */
  low: number;
  high: number;
  broken: boolean;
  yTop: number;
  yBottom: number;
}

export type ItemKind = "hat" | "purse" | "umbrella";

export interface Spot {
  x: number;
  plat: number;
}

export interface LevelDef {
  kind: Kind;
  /** The height the stage's name shows. */
  meters: number;
  platforms: Platform[];
  ladders: Ladder[];
  start: Spot;
  kong: Spot;
  lady: Spot;
  /** The platform that is the goal, and the x the hero must be at or left of (or null: reaching it is enough). */
  goal: { plat: number; maxX: number } | null;
  hammers: Spot[];
  items: { x: number; plat: number; kind: ItemKind }[];
  rivets: Spot[];
  fires: Spot[];
  /** Where barrels fall into the oil drum (girders only): the drum's centre x on platform 0. */
  oilX: number | null;
  /** Whether the hero is stopped at the end of a platform instead of walking off it. */
  walls: boolean;
  liftTop: number;
  liftBottom: number;
}

function plat(id: number, x1: number, y1: number, x2: number, y2: number, belt = 0, lift = 0): Platform {
  return { id, x1, y1, x2, y2, belt, lift };
}

/** The y of a platform's surface at x. */
export function surface(p: Platform, x: number): number {
  if (p.x2 === p.x1) return p.y1;
  return p.y1 + ((p.y2 - p.y1) * (x - p.x1)) / (p.x2 - p.x1);
}

function ladders(ps: Platform[], defs: [low: number, high: number, x: number, broken?: boolean][]): Ladder[] {
  return defs.map(([low, high, x, broken]) => ({
    x,
    low,
    high,
    broken: broken === true,
    yTop: surface(ps[high], x),
    yBottom: surface(ps[low], x),
  }));
}

function girders(): LevelDef {
  const platforms = [
    plat(0, 0, 246, 224, 238),
    plat(1, 0, 206, 208, 214),
    plat(2, 16, 182, 224, 174),
    plat(3, 0, 142, 208, 150),
    plat(4, 16, 118, 224, 110),
    plat(5, 0, 78, 208, 86),
    plat(6, 84, 46, 140, 46),
  ];
  return {
    kind: "girders",
    meters: 25,
    platforms,
    ladders: ladders(platforms, [
      [0, 1, 168],
      [0, 1, 96, true],
      [1, 2, 40],
      [1, 2, 136, true],
      [2, 3, 168],
      [2, 3, 88, true],
      [3, 4, 44],
      [3, 4, 120, true],
      [4, 5, 168],
      [4, 5, 96, true],
      [5, 6, 108],
    ]),
    start: { x: 48, plat: 0 },
    kong: { x: 22, plat: 5 },
    lady: { x: 124, plat: 6 },
    goal: { plat: 6, maxX: 224 },
    hammers: [
      { x: 200, plat: 2 },
      { x: 26, plat: 4 },
    ],
    items: [
      { x: 128, plat: 1, kind: "hat" },
      { x: 104, plat: 3, kind: "purse" },
      { x: 140, plat: 5, kind: "umbrella" },
    ],
    rivets: [],
    fires: [],
    oilX: 18,
    walls: true,
    liftTop: 0,
    liftBottom: 0,
  };
}

function conveyors(): LevelDef {
  const platforms = [
    plat(0, 0, 246, 224, 246),
    plat(1, 0, 212, 208, 212, 0.5),
    plat(2, 16, 178, 224, 178, -0.5),
    plat(3, 0, 144, 208, 144, 0.5),
    plat(4, 16, 110, 224, 110, -0.5),
    plat(5, 0, 76, 208, 76, 0.5),
    plat(6, 84, 44, 140, 44),
  ];
  return {
    kind: "conveyors",
    meters: 50,
    platforms,
    ladders: ladders(platforms, [
      [0, 1, 176],
      [0, 1, 56],
      [1, 2, 40],
      [1, 2, 128],
      [2, 3, 176],
      [2, 3, 96],
      [3, 4, 40],
      [3, 4, 136],
      [4, 5, 176],
      [4, 5, 100],
      [5, 6, 108],
    ]),
    start: { x: 40, plat: 0 },
    kong: { x: 22, plat: 5 },
    lady: { x: 124, plat: 6 },
    goal: { plat: 6, maxX: 224 },
    hammers: [
      { x: 188, plat: 3 },
      { x: 20, plat: 1 },
    ],
    items: [
      { x: 150, plat: 0, kind: "hat" },
      { x: 120, plat: 2, kind: "purse" },
      { x: 60, plat: 4, kind: "umbrella" },
    ],
    rivets: [],
    fires: [{ x: 120, plat: 0 }],
    oilX: null,
    walls: true,
    liftTop: 0,
    liftBottom: 0,
  };
}

function elevators(): LevelDef {
  const top = 94;
  const bottom = 250;
  const platforms = [
    plat(0, 0, 238, 56, 238),
    plat(1, 92, 104, 140, 104),
    plat(2, 172, 170, 220, 170),
    plat(3, 176, 136, 220, 136),
    plat(4, 172, 102, 220, 102),
    plat(5, 96, 66, 220, 66),
  ];
  const lifts: Platform[] = [];
  for (let i = 0; i < 3; i++) lifts.push(plat(6 + i, 68, 238 - 52 * i, 84, 238 - 52 * i, 0, -0.45));
  for (let i = 0; i < 3; i++) lifts.push(plat(9 + i, 148, 100 + 52 * i, 164, 100 + 52 * i, 0, 0.45));
  const all = [...platforms, ...lifts];
  return {
    kind: "elevators",
    meters: 75,
    platforms: all,
    ladders: ladders(all, [
      [2, 3, 180],
      [3, 4, 212],
      [4, 5, 180],
    ]),
    start: { x: 20, plat: 0 },
    kong: { x: 208, plat: 5 },
    lady: { x: 108, plat: 5 },
    goal: { plat: 5, maxX: 120 },
    hammers: [
      { x: 192, plat: 2 },
      { x: 204, plat: 4 },
    ],
    items: [
      { x: 30, plat: 0, kind: "hat" },
      { x: 122, plat: 1, kind: "purse" },
      { x: 196, plat: 3, kind: "umbrella" },
    ],
    rivets: [],
    fires: [{ x: 200, plat: 3 }],
    oilX: null,
    walls: false,
    liftTop: top,
    liftBottom: bottom,
  };
}

function rivets(): LevelDef {
  const platforms = [
    plat(0, 0, 246, 224, 246),
    plat(1, 16, 206, 208, 206),
    plat(2, 16, 166, 208, 166),
    plat(3, 16, 126, 208, 126),
    plat(4, 16, 86, 208, 86),
    plat(5, 80, 62, 144, 62),
  ];
  const rv: Spot[] = [];
  for (let p = 1; p <= 4; p++) rv.push({ x: 32, plat: p }, { x: 192, plat: p });
  return {
    kind: "rivets",
    meters: 100,
    platforms,
    ladders: ladders(platforms, [
      [0, 1, 56],
      [0, 1, 168],
      [1, 2, 88],
      [1, 2, 144],
      [2, 3, 56],
      [2, 3, 168],
      [3, 4, 88],
      [3, 4, 144],
    ]),
    start: { x: 112, plat: 0 },
    kong: { x: 100, plat: 5 },
    lady: { x: 128, plat: 5 },
    goal: null,
    hammers: [
      { x: 150, plat: 1 },
      { x: 50, plat: 3 },
    ],
    items: [
      { x: 30, plat: 0, kind: "hat" },
      { x: 104, plat: 2, kind: "purse" },
      { x: 60, plat: 4, kind: "umbrella" },
    ],
    rivets: rv,
    fires: [
      { x: 60, plat: 3 },
      { x: 180, plat: 1 },
    ],
    oilX: null,
    walls: true,
    liftTop: 0,
    liftBottom: 0,
  };
}

export function buildLevel(kind: Kind): LevelDef {
  switch (kind) {
    case "girders":
      return girders();
    case "conveyors":
      return conveyors();
    case "elevators":
      return elevators();
    case "rivets":
      return rivets();
  }
}

/** The stages of a round: the first round has two, the second three, later rounds all four. */
export function stagesFor(round: number): Kind[] {
  if (round <= 1) return ["girders", "rivets"];
  if (round === 2) return ["girders", "conveyors", "rivets"];
  return ["girders", "conveyors", "elevators", "rivets"];
}
