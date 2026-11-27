// Sound effects made on the fly with Web Audio: no sound files. Nothing plays until the player first presses a key
// or touches the screen, as browsers require.
import type { GameEvent } from "../engine/game";

export class Sound {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private pip = 0;
  on = true;

  /** Call from a key press or touch so the browser lets audio start. */
  unlock(): void {
    if (!this.ctx) {
      const AC = window.AudioContext || (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AC) return;
      this.ctx = new AC();
      this.master = this.ctx.createGain();
      this.master.gain.value = 0.3;
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
      // Eels: two little gulps, one after the other.
      case "eel": this.pip ^= 1; return this.sweep("triangle", this.pip ? 520 : 660, this.pip ? 760 : 480, 0.06, 0.14);
      case "feather": this.tune([1175, 1568, 2093], 0.06, "sine", 0.16); return this.tern();
      case "rout": this.burst(0.2, 2600, 500, 0.4); return this.tune([392, 523, 784, 1047], 0.05, "square", 0.1);
      case "mobEnd": return this.sweep("sine", 900, 300, 0.25, 0.1);
      case "dive": return this.sweep("sawtooth", 300, 140, 0.4, 0.08);
      case "treatShown": return this.tune([1319, 1760], 0.07, "sine", 0.1);
      case "treat": return this.tune([784, 1047, 1319, 1760, 2093], 0.05, "triangle", 0.18);
      case "extra": return this.tune([784, 988, 1175, 1568, 1175, 1568], 0.07, "square", 0.1);
      case "caught": this.burst(0.5, 1800, 120, 0.5); return this.tune([659, 554, 466, 370, 294, 220, 165], 0.1, "triangle", 0.2);
      case "clear": return this.tune([523, 659, 784, 1047, 784, 1047, 1319, 1568], 0.085, "triangle", 0.2);
      case "start": return this.tune([392, 494, 587, 784, 587, 784, 988, 1175], 0.1, "triangle", 0.16);
      case "ready": return this.tune([587, 784], 0.1, "triangle", 0.14);
      case "over": return this.tune([523, 466, 392, 311, 262, 196], 0.17, "triangle", 0.2);
      case "pause": return this.sweep("sine", 600, 600, 0.06, 0.08);
    }
  }

  /** A tern's cry: a short rasping screech that falls. The page calls it again and again while the terns are out. */
  tern(): void {
    if (!this.on || !this.ctx) return;
    this.sweep("sawtooth", 2300, 1500, 0.09, 0.05);
    this.sweep("square", 1900, 1300, 0.08, 0.03, 0.1);
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
    f.type = "bandpass";
    f.frequency.setValueAtTime(from, t);
    f.frequency.exponentialRampToValueAtTime(Math.max(20, to), t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.001, t + dur);
    src.connect(f).connect(g).connect(this.master!);
    src.start(t);
    src.stop(t + dur + 0.02);
  }

  private tune(notes: number[], each: number, type: OscillatorType, vol: number): void {
    notes.forEach((n, i) => this.sweep(type, n, n, each * 0.95, vol, i * each));
  }
}
