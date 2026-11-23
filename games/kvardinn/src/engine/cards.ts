// Reads the scale cards from data/kvardar.txt: one card per line, "Left ↔ Right" (or "<->" or "|"),
// with "#" starting a comment line. The Worker bundles the file as text (wrangler's default rule
// for .txt), and the tests do the same through esbuild.
import type { Card } from "./game";

export interface ParseProblem { line: number; text: string }

export function parseCards(text: string): { cards: Card[]; problems: ParseProblem[] } {
  const cards: Card[] = [];
  const problems: ParseProblem[] = [];
  text.split(/\r?\n/).forEach((raw, i) => {
    const line = raw.trim();
    if (!line || line.startsWith("#")) return;
    const parts = line.split(/\s*(?:↔|<->|\|)\s*/);
    if (parts.length !== 2 || !parts[0] || !parts[1]) problems.push({ line: i + 1, text: raw });
    else cards.push([parts[0].normalize("NFC"), parts[1].normalize("NFC")]);
  });
  return { cards, problems };
}
