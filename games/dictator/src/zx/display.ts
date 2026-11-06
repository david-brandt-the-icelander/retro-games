// Shows a ZXScreen on a <canvas>: redraws when the screen changes, toggles FLASH
// every 16 frames of 50 Hz (0.32 s) like the real machine, and scales to fit.
import { FULL_HEIGHT, FULL_WIDTH, ZXScreen } from "./screen";

export const FLASH_MS = 320;

export class Display {
  private readonly ctx: CanvasRenderingContext2D;
  private readonly image: ImageData;
  private readonly buffer: Uint32Array;
  private drawn = -1;
  private flashOn = false;

  /**
   * `room` reports the CSS pixels available for the canvas; by default the window less a
   * 16px gutter on each side.
   */
  constructor(
    readonly canvas: HTMLCanvasElement,
    readonly screen: ZXScreen,
    private readonly room: () => readonly [width: number, height: number] = () => [innerWidth - 32, innerHeight - 32],
  ) {
    canvas.width = FULL_WIDTH;
    canvas.height = FULL_HEIGHT;
    this.ctx = canvas.getContext("2d")!;
    this.image = this.ctx.createImageData(FULL_WIDTH, FULL_HEIGHT);
    this.buffer = new Uint32Array(this.image.data.buffer);
    this.fit();
    addEventListener("resize", () => this.fit());
    requestAnimationFrame(this.frame);
  }

  /** Scale to the largest whole multiple that fits; below 2× (phones) use the exact fit instead. */
  fit(): void {
    const [w, h] = this.room();
    const room = Math.min(w / FULL_WIDTH, h / FULL_HEIGHT);
    const scale = room >= 2 ? Math.floor(room) : Math.max(0.5, room);
    this.canvas.style.width = `${Math.round(FULL_WIDTH * scale)}px`;
    this.canvas.style.height = `${Math.round(FULL_HEIGHT * scale)}px`;
  }

  private readonly frame = (t: number) => {
    const flashOn = Math.floor(t / FLASH_MS) % 2 === 1;
    const flashChanged = flashOn !== this.flashOn && this.screen.hasFlash();
    if (this.drawn !== this.screen.version || flashChanged) {
      this.flashOn = flashOn;
      this.screen.render(this.buffer, flashOn);
      this.ctx.putImageData(this.image, 0, 0);
      this.drawn = this.screen.version;
    }
    requestAnimationFrame(this.frame);
  };
}
