// A player's name on the high-score table: up to 12 characters, in the style of the old arcade
// tables. The same rules run in the browser (name entry) and on the server (the table).

export const NAME_LENGTH = 12;

/** The characters a name may hold: what the on-screen keyboard offers. */
export const NAME_CHARS = new Set([..."ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.- "]);

/** A typed key as a name character (letters in capitals), or null when names can't hold it. */
export function nameChar(key: string): string | null {
  const ch = key.length === 1 ? key.toUpperCase() : "";
  return NAME_CHARS.has(ch) ? ch : null;
}

/** A name as stored: only name characters, no spaces at either end, at most NAME_LENGTH long. */
export function cleanName(raw: string): string {
  return [...raw.toUpperCase()].filter((c) => NAME_CHARS.has(c)).join("").trim().slice(0, NAME_LENGTH).trim();
}

export function validName(name: unknown): name is string {
  return typeof name === "string" && name.length > 0 && name.length <= NAME_LENGTH && cleanName(name) === name;
}

/**
 * The default name for a signed-in player: the part of their email address before the @
 * (and before any +tag), with underscores as hyphens and anything else a name can't hold left out.
 */
export function nameFromEmail(localPart: string): string {
  return cleanName(localPart.split("@")[0].split("+")[0].replace(/_/g, "-"));
}
