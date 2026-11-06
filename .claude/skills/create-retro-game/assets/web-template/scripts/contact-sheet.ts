// Renders every sample screen headlessly into one PNG contact sheet for review:
//   npm run sheet            → docs/contact-sheet.png
// Each screen is drawn twice side by side: FLASH off and FLASH on.
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname } from "node:path";
import { deflateSync } from "node:zlib";
import { SAMPLES } from "../test/samples";
import { FULL_HEIGHT, FULL_WIDTH, ZXScreen } from "../src/zx/screen";

const out = process.argv[2] ?? "docs/contact-sheet.png";
const COLS = 2; // flash off, flash on
const GAP = 8;
const W = COLS * FULL_WIDTH + (COLS + 1) * GAP;
const H = SAMPLES.length * (FULL_HEIGHT + GAP) + GAP;
const rgb = new Uint8Array(W * H * 3).fill(0x22);

const z = new ZXScreen();
const frame = new Uint32Array(FULL_WIDTH * FULL_HEIGHT);
SAMPLES.forEach((sample, row) => {
  sample.draw(z);
  for (let c = 0; c < COLS; c++) {
    z.render(frame, c === 1);
    const ox = GAP + c * (FULL_WIDTH + GAP), oy = GAP + row * (FULL_HEIGHT + GAP);
    for (let y = 0; y < FULL_HEIGHT; y++)
      for (let x = 0; x < FULL_WIDTH; x++) {
        const p = frame[y * FULL_WIDTH + x], i = ((oy + y) * W + ox + x) * 3;
        rgb[i] = p & 255; rgb[i + 1] = (p >>> 8) & 255; rgb[i + 2] = (p >>> 16) & 255;
      }
  }
});

mkdirSync(dirname(out), { recursive: true });
writeFileSync(out, png(W, H, rgb));
console.log(`contact sheet: ${SAMPLES.length} screens → ${out} (${W}×${H})`);

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
