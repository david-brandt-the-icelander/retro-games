// Lundey's numbers: the size of the island, how fast everyone moves, how long things last and what they score.
// Times are in steps (the game takes 60 steps a second); distances are in thousandths of a tile.

export const COLS = 21;
export const ROWS = 23;
/** One tile, in the units positions and speeds are kept in. */
export const UNIT = 1000;
export const STEPS_PER_SECOND = 60;

/** What a tile is. Only hunters go through the den and its door. */
export const WALL = 0, PATH = 1, DEN = 2, DOOR = 3;

/** Directions, clockwise from up. `DX[d]`, `DY[d]` is one tile that way. */
export type Dir = 0 | 1 | 2 | 3;
export const UP: Dir = 0, RIGHT: Dir = 1, DOWN: Dir = 2, LEFT: Dir = 3;
export const DX = [0, 1, 0, -1];
export const DY = [-1, 0, 1, 0];
export const opposite = (d: Dir): Dir => ((d + 2) % 4) as Dir;

export const START_LIVES = 3;
export const MAX_LIVES = 5;
/** The first extra puffin, and how many more points each one after it takes. */
export const EXTRA_AT = 4000;
export const EXTRA_EVERY = 8000;

export const EEL_POINTS = 5;
export const FEATHER_POINTS = 25;
/** Routing the first hunter under one feather; the second scores twice this, the third three times, the fourth four. */
export const ROUT_POINTS = 250;
/** Finishing a burrow without losing a puffin. */
export const CLEAN_POINTS = 500;
/** The treat washed up on each burrow (the last repeats): herring, crab, mussel, starfish, pearl. */
export const TREATS = ["herring", "crab", "mussel", "starfish", "pearl"] as const;
export type Treat = (typeof TREATS)[number];
export const TREAT_POINTS = [100, 200, 300, 500, 800];
/** A treat appears when this many tenths of a burrow's eels are eaten, and stays this long. */
export const TREAT_AT_TENTHS = [3, 7];
export const TREAT_STEPS = 600;

export const PUFFIN_SPEED = 100;
export type HunterKind = "fox" | "mink" | "skua" | "raven";
export const KINDS: HunterKind[] = ["fox", "mink", "skua", "raven"];
export const HUNTER_SPEED: Record<HunterKind, number> = { fox: 90, mink: 84, skua: 94, raven: 80 };
/** Each burrow after the first makes every hunter this much faster, up to the cap. */
export const SPEED_PER_LEVEL = 2;
export const SPEED_CAP = 12;
export const DIVE_BONUS = 28;
export const MOBBED_SPEED = 52;
export const ROUTED_SPEED = 220;
export const LEAVING_SPEED = 60;

/** How long each hunter waits in the den at the start of a burrow or a life (the fox starts outside). */
export const DEN_WAIT: Record<HunterKind, number> = { fox: 0, mink: 120, skua: 420, raven: 720 };
export const DEN_WAIT_PER_LEVEL = 30;
export const DEN_WAIT_MIN: Record<HunterKind, number> = { fox: 0, mink: 60, skua: 120, raven: 180 };
/** A routed hunter rests this long in the den before coming out again. */
export const DEN_REST = 150;

/** How long a hunter hunts, then prowls (wanders), in turn. The raven only wanders and dives. */
export const HUNT_STEPS: Record<HunterKind, number> = { fox: 840, mink: 600, skua: 720, raven: 0 };
export const PROWL_STEPS: Record<HunterKind, number> = { fox: 240, mink: 300, skua: 240, raven: 0 };
export const PROWL_LESS_PER_LEVEL = 30;
export const PROWL_MIN = 60;

/** The fox follows scent no older than this. */
export const SCENT_STEPS = 480;
/** The skua goes for the eel nearest the puffin that is at least this many tiles from it, until it is this close itself. */
export const SKUA_MEAL_MIN = 4;
export const SKUA_CLOSE = 6;
/** A raven that sees the puffin down a tunnel dives for this long, then needs this long before it can dive again. */
export const DIVE_STEPS = 180;
export const DIVE_REST = 150;

/** How long the terns mob the hunters after a feather: this on the first burrow, less on each one after, never under the minimum. */
export const MOB_STEPS = 480;
export const MOB_LESS_PER_LEVEL = 30;
export const MOB_MIN = 180;
/** The hunters flash for this long before the terns leave. */
export const MOB_WARNING = 120;

/** Puffin and hunter touch when they are closer than this along the tunnel. */
export const TOUCH = 600;

export const READY_STEPS = 120;
export const FIRST_READY_STEPS = 170;
export const CAUGHT_STEPS = 120;
export const CLEARED_STEPS = 170;
export const OVER_STEPS = 300;
/** The game stands still this long when a hunter is routed. */
export const HIT_STOP = 24;
export const POPUP_STEPS = 60;

export const mobSteps = (level: number): number => Math.max(MOB_MIN, MOB_STEPS - (level - 1) * MOB_LESS_PER_LEVEL);
export const hunterSpeed = (kind: HunterKind, level: number): number =>
  HUNTER_SPEED[kind] + Math.min(SPEED_CAP, (level - 1) * SPEED_PER_LEVEL);
export const denWait = (kind: HunterKind, level: number): number =>
  Math.max(DEN_WAIT_MIN[kind], DEN_WAIT[kind] - (level - 1) * DEN_WAIT_PER_LEVEL);
export const prowlSteps = (kind: HunterKind, level: number): number =>
  Math.max(PROWL_MIN, PROWL_STEPS[kind] - (level - 1) * PROWL_LESS_PER_LEVEL);
export const treatFor = (level: number): number => Math.min(TREATS.length, level) - 1;
