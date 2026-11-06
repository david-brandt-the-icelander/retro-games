import assert from "node:assert/strict";
import { test } from "node:test";
import { CHARSET, glyph, hasGlyph, parseGlyph } from "../src/zx/font";
import { normaliseKey } from "../src/zx/input";
import { BLACK, BLUE, BORDER, FULL_HEIGHT, FULL_WIDTH, packRGBA, RED, rgb, WHITE, WIDTH, YELLOW, ZXScreen } from "../src/zx/screen";

test("the font covers printable ASCII plus £ and ©", () => {
  for (let c = 32; c < 127; c++) assert.ok(hasGlyph(String.fromCharCode(c)), `missing ${String.fromCharCode(c)}`);
  assert.ok(hasGlyph("£") && hasGlyph("©"));
  for (const ch of CHARSET) assert.equal(glyph(ch).length, 8);
});

test("glyphs are distinct and capitals keep the top row clear", () => {
  const seen = new Map<string, string>();
  for (const ch of CHARSET) {
    const key = glyph(ch).join(",");
    assert.ok(!seen.has(key) || ch === " ", `${ch} looks like ${seen.get(key)}`);
    seen.set(key, ch);
  }
  for (const ch of "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789") assert.equal(glyph(ch)[0], 0, ch);
});

test("parseGlyph reads rows left to right, bit 7 first", () => {
  assert.deepEqual(parseGlyph("#....... .#...... ........ ........ ........ ........ ........ .......#"), [128, 64, 0, 0, 0, 0, 0, 1]);
  assert.throws(() => parseGlyph("#"));
});

test("print draws glyph pixels and sets attributes", () => {
  const s = new ZXScreen();
  s.cls({ ink: BLACK, paper: WHITE });
  const end = s.print(30, 5, "HIJ", { ink: RED, paper: YELLOW });
  assert.equal(end, 32); // clipped at the right edge
  const h = glyph("H");
  for (let y = 0; y < 8; y++)
    for (let x = 0; x < 8; x++) assert.equal(s.pixels[(5 * 8 + y) * WIDTH + 30 * 8 + x], (h[y] >> (7 - x)) & 1);
  assert.deepEqual(s.attrAt(31, 5), { ink: RED, paper: YELLOW, bright: false, flash: false });
  assert.deepEqual(s.attrAt(29, 5), { ink: BLACK, paper: WHITE, bright: false, flash: false });
});

test("render paints border, paper and ink, and FLASH swaps ink and paper", () => {
  const s = new ZXScreen();
  s.cls({ ink: WHITE, paper: BLUE }, RED);
  s.cellBytes(0, 0, [0x80, 0, 0, 0, 0, 0, 0, 0], { ink: YELLOW, paper: BLACK, bright: true, flash: true });
  const out = new Uint32Array(FULL_WIDTH * FULL_HEIGHT);
  const at = (x: number, y: number) => out[(BORDER + y) * FULL_WIDTH + BORDER + x];

  s.render(out, false);
  assert.equal(out[0], packRGBA(rgb(RED, false)));
  assert.equal(at(0, 0), packRGBA(rgb(YELLOW, true))); // ink pixel
  assert.equal(at(1, 0), packRGBA(rgb(BLACK, true))); // paper pixel
  assert.equal(at(8, 0), packRGBA(rgb(BLUE, false))); // next cell: plain paper

  s.render(out, true);
  assert.equal(at(0, 0), packRGBA(rgb(BLACK, true)));
  assert.equal(at(1, 0), packRGBA(rgb(YELLOW, true)));
  assert.equal(at(8, 0), packRGBA(rgb(BLUE, false))); // non-flashing cell unchanged
});

test("palette: normal is 0xD7, BRIGHT is 0xFF, black stays black", () => {
  assert.deepEqual(rgb(YELLOW, false), [0xd7, 0xd7, 0]);
  assert.deepEqual(rgb(YELLOW, true), [0xff, 0xff, 0]);
  assert.deepEqual(rgb(BLUE, true), [0, 0, 0xff]);
  assert.deepEqual(rgb(BLACK, true), [0, 0, 0]);
});

test("pictures plot '#' as ink and colour the cells they cover", () => {
  const s = new ZXScreen();
  s.cls({ ink: BLACK, paper: WHITE });
  s.picture(2, 3, ["#".repeat(16), ...Array(15).fill("." .repeat(15) + "#")], { ink: RED, paper: WHITE });
  assert.equal(s.pixels[(3 * 8) * WIDTH + 2 * 8 + 15], 1);
  assert.equal(s.pixels[(3 * 8 + 15) * WIDTH + 2 * 8 + 15], 1);
  assert.equal(s.pixels[(3 * 8 + 1) * WIDTH + 2 * 8], 0);
  assert.equal(s.attrAt(3, 4).ink, RED);
  assert.equal(s.attrAt(4, 4).ink, BLACK);
});

test("version changes on every drawing call", () => {
  const s = new ZXScreen();
  const v = s.version;
  s.print(0, 0, "A");
  assert.ok(s.version > v);
});

test("keys reach the game as typed: case kept, Enter and Space kept, others ignored", () => {
  assert.equal(normaliseKey("Y"), "Y");
  assert.equal(normaliseKey("y"), "y");
  assert.equal(normaliseKey("3"), "3");
  assert.equal(normaliseKey("Enter"), "Enter");
  assert.equal(normaliseKey(" "), " ");
  assert.equal(normaliseKey("Shift"), null);
  assert.equal(normaliseKey("ArrowUp"), null);
});
