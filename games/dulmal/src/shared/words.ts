// Word lists: the built-in one in data/ord.txt and the ones a host pastes in. A word may carry
// "|" where it can be split over two lines on a small screen (Reykja|vík); the mark is part of
// what is stored and sent, and the page turns it into a soft hyphen.

/** At most this many characters in a word, break marks left out. */
export const MAX_WORD = 24;

/** The word as players see and type it: no break marks, no surrounding space. */
export const plain = (word: string): string => word.replace(/\|/g, "").trim();

/** For comparing words: lower case, no break marks. Icelandic letters are kept as they are. */
export const key = (word: string): string => plain(word).toLocaleLowerCase("is-IS");

/** Words that are reserved for the game itself and never go on the board. */
export const RESERVED = ["hraun", "jökull", "draugur"];

/**
 * Reads a word list: one word per line (a pasted list may also use commas or semicolons),
 * "#" starts a comment line, blanks are skipped, the first copy of a repeated word is kept.
 * A word with a space in it, or one that is too long or names a team, is left out.
 */
export function parseWords(text: string): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const line of text.split(/\r?\n/)) {
    if (line.trim().startsWith("#")) continue;
    for (const raw of line.split(/[,;\t]/)) {
      const word = raw.trim().replace(/\s*\|\s*/g, "|").replace(/^\|+|\|+$/g, "");
      const k = key(word);
      if (!k || /\s/.test(k) || k.length > MAX_WORD || seen.has(k)) continue;
      if (RESERVED.some((r) => k.includes(r))) continue;
      seen.add(k);
      out.push(word.charAt(0).toLocaleUpperCase("is-IS") + word.slice(1));
    }
  }
  return out;
}

/** Two words too alike to share a board: one contains the other, or they start or end alike. */
export function similar(a: string, b: string): boolean {
  const x = key(a), y = key(b);
  if (x === y) return true;
  const [short, long] = x.length <= y.length ? [x, y] : [y, x];
  if (long.startsWith(short) || long.endsWith(short)) return true;
  if (short.length >= 3 && long.includes(short)) return true;
  if (x.length >= 4 && y.length >= 4 && x.slice(0, 4) === y.slice(0, 4)) return true;
  if (x.length >= 5 && y.length >= 5 && x.slice(-5) === y.slice(-5)) return true;
  return false;
}

/**
 * Picks `count` words, none too like another, in random order. Returns null when the list
 * cannot give that many (a short custom list full of look-alikes).
 */
export function pickWords(list: readonly string[], count: number, random: () => number): string[] | null {
  for (let attempt = 0; attempt < 20; attempt++) {
    const pool = shuffle([...list], random);
    const chosen: string[] = [];
    for (const word of pool) {
      if (chosen.every((c) => !similar(c, word))) chosen.push(word);
      if (chosen.length === count) return chosen;
    }
  }
  return null;
}

/** Fisher–Yates, in place. */
export function shuffle<T>(items: T[], random: () => number): T[] {
  for (let i = items.length - 1; i > 0; i--) {
    const j = Math.floor(random() * (i + 1));
    [items[i], items[j]] = [items[j]!, items[i]!];
  }
  return items;
}
