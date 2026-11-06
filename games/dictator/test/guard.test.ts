// Clean-room guard: fails if any string or invented name from the original game appears
// anywhere in this game's sources, page or docs. The original's text is never stored here;
// test/original-hashes.json holds only truncated SHA-256 hashes of its normalised strings
// (lower case, words joined by single spaces), grouped by word count.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readdirSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const HASHES: Record<string, string[]> = JSON.parse(readFileSync("test/original-hashes.json", "utf8"));
const WORD = /[a-z0-9]+(?:'[a-z0-9]+)?/g;
const SKIP = new Set(["node_modules", "dist", "dist-test", ".wrangler"]);
const hash = (s: string) => createHash("sha256").update(s).digest("hex").slice(0, 16);

function files(dir: string): string[] {
  return readdirSync(dir).flatMap((f) => {
    const p = join(dir, f);
    if (SKIP.has(f)) return [];
    if (statSync(p).isDirectory()) return files(p);
    return /\.(ts|mjs|js|html|css|md|json|jsonc|txt)$/.test(f) && f !== "original-hashes.json" && !f.startsWith("package") ? [p] : [];
  });
}

test("no string or name from the original appears in the game", () => {
  const sets = Object.entries(HASHES).map(([n, hs]) => [Number(n), new Set(hs)] as const);
  const hits: string[] = [];
  for (const file of files(".")) {
    readFileSync(file, "utf8").split("\n").forEach((line, i) => {
      const words = line.toLowerCase().match(WORD) ?? [];
      for (const [n, set] of sets) {
        for (let k = 0; k + n <= words.length; k++) {
          if (set.has(hash(words.slice(k, k + n).join(" ")))) hits.push(`${file}:${i + 1} (${n} words)`);
        }
      }
    });
  }
  assert.deepEqual(hits, [], "original text found; rewrite the whole message");
});

test("the hash list is loaded and complete", () => {
  const anyFive = HASHES["5"]?.length ?? 0;
  assert.ok(anyFive > 0 && Object.values(HASHES).flat().length > 100, "hash list looks complete");
});
