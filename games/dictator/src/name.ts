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

/** The characters the name-entry keyboard types (src/ui/entry.ts): capitals, digits, . - and space. */
export const KEY_CHARS = new Set([..."ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- "]);

/** A typed key as a name character (letters in capitals), or null when the keyboard has no such key. */
export function nameChar(key: string): string | null {
  const ch = key.length === 1 ? key.toUpperCase() : "";
  return KEY_CHARS.has(ch) ? ch : null;
}

/**
 * The name offered to a player signed in to the games: their email before the @ (and before any
 * +tag), cleaned as above, in capitals, with underscores as hyphens, so every character is a key.
 */
export function nameFromEmail(localPart: string): string {
  const base = localPart.split("@")[0].split("+")[0].replace(/_/g, "-");
  return [...cleanName(base).toUpperCase()].filter((c) => KEY_CHARS.has(c)).join("").trim();
}
