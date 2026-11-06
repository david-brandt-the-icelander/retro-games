// Sound effects made on the fly with Web Audio: no sound files. Nothing plays until the player first presses a key
// or touches the screen, as browsers require.
import type { GameEvent } from "../engine/game";

export class Sound {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  on = true;

  /** Call from a key press or touch so the browser lets audio start. */
  unlock(): void {
    if (!this.ctx) {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.35;
      this.master.connect(this.ctx.destination);
      const len = this.ctx.sampleRate;
      this.noise = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
      const d = this.noise.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
    }
    if (this.ctx.state === "suspended") void this.ctx.resume();
  }

  play(e: GameEvent): void {
    if (!this.on || !this.ctx) return;
    switch (e) {
      case "shoot": return this.sweep("square", 1400, 320, 0.11, 0.12);
      case "hit": return this.burst(0.18, 2400, 300, 0.5);
      case "queen": this.burst(0.35, 3000, 200, 0.6); return this.sweep("triangle", 900, 120, 0.35, 0.25);
      case "dive": return this.sweep("sine", 1100, 380, 0.55, 0.06);
      case "die": this.burst(0.9, 1800, 60, 0.8); return this.sweep("sawtooth", 420, 40, 0.9, 0.18);
      case "extra": return this.tune([784, 988, 1175, 1568, 1175, 1568], 0.07, "square", 0.1);
      case "wave": return this.tune([523, 659, 784, 1047, 784, 1047, 1319], 0.08, "triangle", 0.2);
      case "start": return this.tune([392, 523, 659, 523, 659, 784, 1047], 0.1, "square", 0.08);
      case "over": return this.tune([523, 466, 392, 311, 262], 0.16, "triangle", 0.2);
      case "pause": return this.sweep("sine", 600, 600, 0.06, 0.08);
      default: return;
    }
  }

  private sweep(type: OscillatorType, from: number, to: number, dur: number, vol: number, at = 0): void {
    const c = this.ctx!, t = c.currentTime + at;
    const o = c.createOscillator(), g = c.createGain();
    o.type = type;
    o.frequency.setValueAtTime(from, t);
    o.frequency.exponentialRampToValueAtTime(Math.max(20, to), t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    o.connect(g).connect(this.master!);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  private burst(dur: number, from: number, to: number, vol: number): void {
    const c = this.ctx!, t = c.currentTime;
    const src = c.createBufferSource(), f = c.createBiquadFilter(), g = c.createGain();
    src.buffer = this.noise;
    f.type = "lowpass";
    f.frequency.setValueAtTime(from, t);
    f.frequency.exponentialRampToValueAtTime(to, t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.master!);
    src.start(t);
    src.stop(t + dur + 0.02);
  }

  private tune(notes: number[], step: number, type: OscillatorType, vol: number): void {
    notes.forEach((n, i) => this.sweep(type, n, n * 0.98, step * 0.95, vol, i * step));
  }
}
