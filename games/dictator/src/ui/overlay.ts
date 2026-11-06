// The sound overlay (UI-DESIGN § sound): row 0, cols 20–31, "SOUND: ON/OFF" in BRIGHT white on
// black, drawn over whatever screen is up and restored afterwards unless the screen was redrawn.
import { BLACK, WHITE, WIDTH, ZXScreen } from "../zx/screen";
import { SOUND_STATE } from "./text";

const FIRST = 20, LAST = 31;

interface Saved { clears: number; pixels: Uint8Array; attrs: Uint8Array; chars: string[] }

export class SoundOverlay {
  private saved: Saved | null = null;

  constructor(private readonly z: ZXScreen) {}

  /** Draw the overlay with the new state, saving what was under it unless it is already up. */
  draw(on: boolean): void {
    const z = this.z;
    if (!this.saved || this.saved.clears !== z.clears) {
      const pixels = new Uint8Array(8 * (LAST - FIRST + 1) * 8);
      for (let y = 0; y < 8; y++)
        for (let x = 0; x < (LAST - FIRST + 1) * 8; x++) pixels[y * (LAST - FIRST + 1) * 8 + x] = z.pixels[y * WIDTH + FIRST * 8 + x];
      this.saved = { clears: z.clears, pixels, attrs: z.attrs.slice(FIRST, LAST + 1), chars: z.chars.slice(FIRST, LAST + 1) };
    }
    z.clearCells(FIRST, 0, LAST - FIRST + 1, 1, { ink: WHITE, paper: BLACK, bright: true });
    z.print(FIRST + 1, 0, SOUND_STATE(on));
  }

  /** Put back what was under the overlay, unless the screen has been cleared since. */
  restore(): void {
    const z = this.z, s = this.saved;
    this.saved = null;
    if (!s || s.clears !== z.clears) return;
    const w = (LAST - FIRST + 1) * 8;
    for (let y = 0; y < 8; y++) for (let x = 0; x < w; x++) z.pixels[y * WIDTH + FIRST * 8 + x] = s.pixels[y * w + x];
    for (let c = FIRST; c <= LAST; c++) { z.attrs[c] = s.attrs[c - FIRST]; z.chars[c] = s.chars[c - FIRST]; }
    z.version++;
  }

  get showing(): boolean { return this.saved !== null; }
}

