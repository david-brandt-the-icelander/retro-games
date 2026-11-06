// Renders every sample screen headlessly into one PNG contact sheet for review:
//   npm run sheet                     → docs/contact-sheet.png
//   node dist-test/scripts/contact-sheet.mjs out.png report   (only samples whose name matches the pattern)
// Each screen is drawn twice side by side, FLASH off and FLASH on, with its name above it.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { deflateSync } from "node:zlib";
import { SAMPLES } from "../test/samples";
import { glyph } from "../src/zx/font";
import { FULL_HEIGHT, FULL_WIDTH, ZXScreen } from "../src/zx/screen";

const out = process.argv[2] ?? "docs/contact-sheet.png";
const filter = process.argv[3] ?? "";
const samples = SAMPLES.filter((s) => new RegExp(filter).test(s.name));
const PAIRS = Number(process.env.SHEET_PAIRS ?? 3); // screens per row of the sheet
const GAP = 8, CAPTION = 12;
const TILE_W = 2 * FULL_WIDTH + GAP, TILE_H = CAPTION + FULL_HEIGHT;
const rows = Math.ceil(samples.length / PAIRS);
const W = PAIRS * TILE_W + (PAIRS + 1) * GAP * 2;
const H = rows * (TILE_H + GAP) + GAP;
const rgb = new Uint8Array(W * H * 3).fill(0x22);

const z = new ZXScreen();
const frame = new Uint32Array(FULL_WIDTH * FULL_HEIGHT);
samples.forEach((sample, i) => {
  sample.draw(z);
  const ox = GAP * 2 + (i % PAIRS) * (TILE_W + GAP * 2), oy = GAP + Math.floor(i / PAIRS) * (TILE_H + GAP);
  caption(sample.name, ox, oy + 2);
  for (let c = 0; c < 2; c++) {
    z.render(frame, c === 1);
    const fx = ox + c * (FULL_WIDTH + GAP), fy = oy + CAPTION;
    for (let y = 0; y < FULL_HEIGHT; y++)
      for (let x = 0; x < FULL_WIDTH; x++) {
        const p = frame[y * FULL_WIDTH + x], k = ((fy + y) * W + fx + x) * 3;
        rgb[k] = p & 255; rgb[k + 1] = (p >>> 8) & 255; rgb[k + 2] = (p >>> 16) & 255;
      }
  }
});

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, png(W, H, rgb));
console.log(`contact sheet: ${samples.length} screens → ${out} (${W}×${H})`);

/** Write a caption in the game's font, light grey on the sheet's background. */
function caption(text: string, x0: number, y0: number): void {
  [...text].forEach((ch, i) => {
    const g = glyph(ch);
    for (let y = 0; y < 8; y++)
      for (let x = 0; x < 8; x++)
        if ((g[y] >> (7 - x)) & 1) { const k = ((y0 + y) * W + x0 + i * 8 + x) * 3; rgb[k] = rgb[k + 1] = rgb[k + 2] = 0xcc; }
  });
}

/** A minimal PNG encoder: 8-bit RGB, no filtering. */
function png(width: number, height: number, data: Uint8Array): Buffer {
  const raw = Buffer.alloc((width * 3 + 1) * height);
  for (let y = 0; y < height; y++) Buffer.from(data.buffer, y * width * 3, width * 3).copy(raw, y * (width * 3 + 1) + 1);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0); ihdr.writeUInt32BE(height, 4); ihdr[8] = 8; ihdr[9] = 2;
  return Buffer.concat([Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]), chunk("IHDR", ihdr), chunk("IDAT", deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
}
function chunk(type: string, body: Buffer): Buffer {
  const len = Buffer.alloc(4); len.writeUInt32BE(body.length);
  const tb = Buffer.concat([Buffer.from(type, "ascii"), body]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(tb) >>> 0);
  return Buffer.concat([len, tb, crc]);
}
function crc32(b: Buffer): number {
  let c = ~0;
  for (const byte of b) { c ^= byte; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); }
  return ~c;
}
