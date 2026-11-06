// The pure game engine: no DOM, no timers.
export { newGame } from "./state";
export type { GameState, Plot } from "./state";
export { playGame, isYes, digit } from "./flow";
export type { Outcome } from "./flow";
export { snapshot } from "./snapshot";
export type { Snapshot } from "./snapshot";
export type { IO, Screen, ScreenKind, Item, AdviceLine } from "./screens";
export { SCREEN_KINDS } from "./screens";
