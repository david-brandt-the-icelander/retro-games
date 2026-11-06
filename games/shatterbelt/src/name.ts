// A player's name for the high-score table, cleaned the same way in the browser and on the server.
// The game's own font draws plain ASCII only, so accented letters lose their accents and a few
// letters are spelled out (Davíð → David, Þór → Thor). Kept: letters, digits, spaces and . - ' _,
// at most 12 characters (the width of the in-game table's name column).

export const NAME_MAX = 12;

const SPELLED: Record<string, string> = { þ: "th", Þ: "Th", ð: "d", Ð: "D", æ: "ae", Æ: "Ae", ø: "o", Ø: "O", ß: "ss", œ: "oe", Œ: "Oe", ł: "l", Ł: "L" };

/** The name as the table shows it, or "" when nothing usable is left. */
export function cleanName(raw: unknown): string {
  if (typeof raw !== "string") return "";
  const spelled = [...raw.slice(0, 200)].map((c) => SPELLED[c] ?? c).join("");
  const plain = spelled.normalize("NFD").replace(/[̀-ͯ]/g, "");
  const kept = plain.replace(/[^A-Za-z0-9 .'_-]/g, "").replace(/\s+/g, " ").trim().slice(0, NAME_MAX).trim();
  return /[A-Za-z0-9]/.test(kept) ? kept : "";
}
