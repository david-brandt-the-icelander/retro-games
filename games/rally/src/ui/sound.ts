// Short synthesised blips. The audio context starts on the first key or tap, as browsers require.
import type { GameEvent } from "../engine/rules";
import { MAX_SPEED, SERVE_SPEED } from "../engine/rules";

type Ctx = AudioContext;

export class Sound {
  private ctx: Ctx | null = null;
  constructor(public on: boolean) {}

  /** Call from a user gesture. */
  wake(): void {
    if (!this.on) return;
    try {
      const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!this.ctx && AC) this.ctx = new AC();
      if (this.ctx?.state === "suspended") void this.ctx.resume();
    } catch { this.ctx = null; }
  }

  private tone(freq: number, start: number, dur: number, type: OscillatorType, vol: number, slideTo?: number): void {
    const ctx = this.ctx;
    if (!this.on || !ctx || ctx.state !== "running") return;
    const t = ctx.currentTime + start;
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(freq, t);
    if (slideTo) osc.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    gain.gain.setValueAtTime(vol, t);
    gain.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    osc.connect(gain).connect(ctx.destination);
    osc.start(t);
    osc.stop(t + dur + 0.02);
  }

  play(e: GameEvent, cheer: boolean): void {
    switch (e.kind) {
      case "paddle": {
        // Faster balls click higher.
        const f = 480 + 360 * ((e.speed - SERVE_SPEED) / (MAX_SPEED - SERVE_SPEED));
        this.tone(f, 0, 0.06, "triangle", 0.25);
        break;
      }
      case "wall": this.tone(240, 0, 0.05, "triangle", 0.18); break;
      case "serve": this.tone(660, 0, 0.04, "sine", 0.12); break;
      case "point": cheer ? this.tone(520, 0, 0.18, "square", 0.08, 880) : this.tone(330, 0, 0.25, "square", 0.08, 140); break;
      case "win":
        if (cheer) [523, 659, 784, 1046].forEach((f, i) => this.tone(f, 0.25 + i * 0.11, 0.16, "square", 0.07));
        else [392, 330, 262].forEach((f, i) => this.tone(f, 0.25 + i * 0.16, 0.22, "square", 0.07));
        break;
    }
  }
}
