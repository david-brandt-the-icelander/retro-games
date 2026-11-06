// Messages copied from the 1983 original so the remake feels authentic.
export const TITLE = ["HARBOUR MASTER", "Devised and written by", "J. Q. EXAMPLE", "Copyright FICTISOFT 1983"];
export const PORT = "Saltreach";
export const EVENTS = [
  { text: "A Grevlish merchant offers cheap rum.", gold: -20, rep: 1 },
  { text: "Smugglers whisper of a moonless landing.", gold: 40, rep: -2 },
  { text: "The Admiralty demands harbour dues at once!", gold: -30, rep: 2 },
  { text: "A storm batters the quay. Repairs are needed.", gold: -25, rep: 0 },
];
export const ENDINGS = {
  ruined: "The moneylenders seize your keys. You are ruined.",
  deposed: "The townsfolk march on the harbour office and drag you out.",
  promoted: "The Admiralty makes you Governor of all the Grevlish Isles!",
  survived: "Thirty days pass and you keep your post. Well done, Master.",
};
// The harbour map from the original's DATA statements.
export const MAP = ["##########", "#..~~~~..#", "#.~~~~~~.#", "#.~~##~~.#", "#..~~~~..#", "####..####"];
