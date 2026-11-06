// EXAMPLE GAME (replace): every player-facing string in one place, written to the GDD's budgets.
export const TEXT = {
  title: "LAMPLIGHT",
  subtitle: "an example game",
  pressKey: "PRESS A KEY",
  night: (n: number) => `NIGHT ${n}`,
  oil: (n: number) => `Oil left: ${n} cans`,
  calm: "A calm sea. The lamp burns low.",
  storm: "A storm rolls in from the west!",
  askTrim: "Trim the wick? (Y/N)",
  survived: "Dawn. The ships came home.",
  lost: "The lamp went out.",
  nights: (n: number) => `Nights kept: ${n}`,
} as const;
