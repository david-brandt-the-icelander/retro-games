import assert from "node:assert/strict";
import { test } from "node:test";
import { CELL, FONT_CHARS, FONT_H, FONT_W, KIND_PALETTE, SHIP, Sprite, alienSprite, glyph } from "../src/ui/art";
import type { Kind } from "../src/engine/rules";

function checkSprite(name: string, s: Sprite): void {
  const w = s.rows[0].length;
  s.rows.forEach((row, i) => {
    assert.equal(row.length, w, `${name} row ${i} width`);
    for (const ch of row) if (ch !== ".") assert.ok(s.palette[ch], `${name} colour ${ch}`);
  });
}

test("every sprite is rectangular and every colour is in its palette", () => {
  for (const k of Object.keys(KIND_PALETTE) as Kind[]) {
    const a = alienSprite(k, 0), b = alienSprite(k, 1);
    checkSprite(`${k}/0`, a);
    checkSprite(`${k}/1`, b);
    assert.equal(a.rows.length, b.rows.length);
    assert.equal(a.rows[0].length, b.rows[0].length);
  }
  checkSprite("ship", SHIP);
  checkSprite("cell", CELL);
});

test("every font glyph is 5×7", () => {
  for (const ch of FONT_CHARS) {
    const g = glyph(ch)!;
    assert.equal(g.length, FONT_H, ch);
    for (const row of g) assert.match(row, new RegExp(`^[#.]{${FONT_W}}$`), `glyph ${ch}`);
  }
  for (const ch of "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -:!") assert.ok(glyph(ch), `has ${ch}`);
});
