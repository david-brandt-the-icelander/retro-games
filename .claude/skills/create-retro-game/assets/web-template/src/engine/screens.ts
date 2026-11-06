// EXAMPLE GAME (replace): every screen the engine shows, and the one interface it talks through.

export type Screen =
  | { kind: "night"; night: number; oil: number; storm: boolean }
  | { kind: "ending"; survived: boolean; nights: number };

export interface IO {
  /** Show a screen and resolve with the key pressed (lower case; "enter" for any key). */
  show(screen: Screen): Promise<string>;
}
