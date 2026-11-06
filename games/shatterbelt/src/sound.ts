// Every sound is made on the fly with Web Audio: no sound files.
import { W } from "./engine/config";
import type { Game, GameEvent } from "./engine/game";

const MUTE_KEY = "shatterbelt.muted";

export class Sound {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  private thrustGain: GainNode | null = null;
  private droneGain: GainNode | null = null;
  private droneOsc: OscillatorNode | null = null;
  muted = false;

  constructor() {
    try { this.muted = localStorage.getItem(MUTE_KEY) === "1"; } catch { /* storage blocked: start unmuted */ }
  }

  /** Browsers only allow audio after a key press or tap; call this from one. */
  unlock(): void {
    if (this.ctx) {
      if (this.ctx.state === "suspended") void this.ctx.resume();
      return;
    }
    const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!AC) return;
    const ctx = new AC();
    this.ctx = ctx;
    this.master = ctx.createGain();
    this.master.gain.value = this.muted ? 0 : 0.5;
    this.master.connect(ctx.destination);
    const len = ctx.sampleRate;
    this.noise = ctx.createBuffer(1, len, ctx.sampleRate);
    const data = this.noise.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;

    // The engine rumble: looped noise through a low band-pass, faded in while anyone thrusts.
    const rumble = ctx.createBufferSource();
    rumble.buffer = this.noise;
    rumble.loop = true;
    const band = ctx.createBiquadFilter();
    band.type = "lowpass";
    band.frequency.value = 380;
    this.thrustGain = ctx.createGain();
    this.thrustGain.gain.value = 0;
    rumble.connect(band).connect(this.thrustGain).connect(this.master);
    rumble.start();

    // The drone's warble: a square wave wobbled by a slow oscillator.
    this.droneOsc = ctx.createOscillator();
    this.droneOsc.type = "square";
    this.droneOsc.frequency.value = 150;
    const lfo = ctx.createOscillator();
    lfo.frequency.value = 5;
    const lfoDepth = ctx.createGain();
    lfoDepth.gain.value = 30;
    lfo.connect(lfoDepth).connect(this.droneOsc.frequency);
    this.droneGain = ctx.createGain();
    this.droneGain.gain.value = 0;
    this.droneOsc.connect(this.droneGain).connect(this.master);
    this.droneOsc.start();
    lfo.start();
  }

  toggle(): boolean {
    this.muted = !this.muted;
    try { localStorage.setItem(MUTE_KEY, this.muted ? "1" : "0"); } catch { /* not saved */ }
    if (this.master && this.ctx) this.master.gain.setTargetAtTime(this.muted ? 0 : 0.5, this.ctx.currentTime, 0.02);
    return this.muted;
  }

  /** The continuous sounds follow the game: engine rumble while anyone thrusts, a warble while a drone is out. */
  follow(g: Game | null): void {
    if (!this.ctx || !this.thrustGain || !this.droneGain || !this.droneOsc) return;
    const t = this.ctx.currentTime;
    const thrusting = g ? g.ships.filter((s) => s.alive && s.thrusting).length : 0;
    this.thrustGain.gain.setTargetAtTime(Math.min(0.35, thrusting * 0.18), t, 0.05);
    const drone = g?.drones[0];
    this.droneGain.gain.setTargetAtTime(drone ? 0.025 : 0, t, 0.08);
    if (drone) this.droneOsc.frequency.setTargetAtTime(drone.small ? 330 : 150, t, 0.05);
  }

  play(events: GameEvent[]): void {
    if (!this.ctx || this.muted) return;
    let shots = 0;
    for (const e of events) {
      const pan = Math.max(-1, Math.min(1, (e.x / W) * 2 - 1)) * 0.7;
      switch (e.type) {
        case "shot":
          if (shots++ < 3) this.tone(880 + (e.ship ?? 0) * 40, 220, 0.07, "square", 0.09, pan);
          break;
        case "boom":
          this.burst(0.12 + (e.n ?? 1) * 0.12, 300 + (e.n ?? 1) * 500, 0.25 + (e.n ?? 1) * 0.08, pan);
          if (e.kind === "crystal") this.tone(1600, 2400, 0.15, "triangle", 0.06, pan);
          break;
        case "clank": this.tone(320, 180, 0.08, "square", 0.12, pan); break;
        case "die": this.burst(0.9, 2400, 0.45, pan); this.tone(500, 60, 0.7, "sawtooth", 0.12, pan); break;
        case "droneBoom": this.burst(0.5, 1800, 0.35, pan); this.tone(900, 120, 0.4, "square", 0.08, pan); break;
        case "zap": this.tone(1200, 500, 0.12, "sawtooth", 0.05, pan); break;
        case "blink": this.tone(200, 1400, 0.15, "sine", 0.15, pan); break;
        case "pod": this.arp([660, 880, 1320], 0.06, 0.1, pan); break;
        case "shieldHit": this.tone(1400, 300, 0.25, "triangle", 0.15, pan); break;
        case "extra": this.arp([523, 659, 784, 1046], 0.08, 0.1, pan); break;
        case "streak": this.tone(500 + (e.n ?? 2) * 200, 900 + (e.n ?? 2) * 250, 0.12, "triangle", 0.08, pan); break;
        case "wave": this.arp([392, 523], 0.12, 0.08, 0); break;
        case "clear": this.arp([523, 784, 1046], 0.1, 0.08, 0); break;
        case "spawn": this.tone(300, 600, 0.2, "sine", 0.06, pan); break;
        case "over": this.arp([392, 330, 262, 196], 0.22, 0.1, 0); break;
        default: break;
      }
    }
  }

  private out(pan: number): AudioNode {
    const ctx = this.ctx!;
    if (!ctx.createStereoPanner) return this.master!;
    const p = ctx.createStereoPanner();
    p.pan.value = pan;
    p.connect(this.master!);
    return p;
  }

  private tone(from: number, to: number, dur: number, type: OscillatorType, vol: number, pan: number, delay = 0): void {
    const ctx = this.ctx!;
    const t = ctx.currentTime + delay;
    const o = ctx.createOscillator();
    o.type = type;
    o.frequency.setValueAtTime(from, t);
    o.frequency.exponentialRampToValueAtTime(Math.max(20, to), t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(this.out(pan));
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  private arp(notes: number[], step: number, vol: number, pan: number): void {
    notes.forEach((f, i) => this.tone(f, f, step * 1.6, "triangle", vol, pan, i * step));
  }

  private burst(dur: number, cutoff: number, vol: number, pan: number): void {
    const ctx = this.ctx!;
    const t = ctx.currentTime;
    const src = ctx.createBufferSource();
    src.buffer = this.noise;
    const f = ctx.createBiquadFilter();
    f.type = "lowpass";
    f.frequency.setValueAtTime(cutoff, t);
    f.frequency.exponentialRampToValueAtTime(60, t + dur);
    const g = ctx.createGain();
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    src.connect(f).connect(g).connect(this.out(pan));
    src.start(t, Math.random() * 0.5);
    src.stop(t + dur + 0.02);
  }
}
