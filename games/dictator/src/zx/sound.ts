// Beeper-style sound: square-wave notes given as (seconds, semitones from middle C), rests,
// and short noise bursts. Silent until the first key unlocks audio (browser rule).
// The game's own motifs are in src/ui/sounds.ts (art bible §9).

/** A note: duration in seconds and pitch in semitones from middle C, a rest (null) or noise. */
export type Note = readonly [seconds: number, pitch: number | null | "noise"];

/** Frequency of a pitch given in semitones from middle C. */
export const frequency = (pitch: number): number => 261.63 * 2 ** (pitch / 12);

/** A short generic tick, e.g. for key presses. */
export const TICK: readonly Note[] = [[0.004, 36]];

export class Sound {
  private ctx: AudioContext | null = null;
  private playing: AudioScheduledSourceNode[] = [];
  private noiseBuffer: AudioBuffer | null = null;

  constructor(public muted = false) {}

  /** Browsers only allow audio after a user gesture: call this from a key or tap handler. */
  unlock(): void {
    if (!this.ctx) {
      const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!Ctor) return;
      this.ctx = new Ctor();
    }
    if (this.ctx.state === "suspended") void this.ctx.resume();
  }

  /** Stop whatever is playing. */
  stop(): void {
    for (const n of this.playing) { try { n.stop(); } catch { /* already stopped */ } }
    this.playing = [];
  }

  /** True once audio has been unlocked by a user gesture. */
  get unlocked(): boolean { return this.ctx !== null; }

  /** Play notes one after another, `delay` seconds from now; with `stopFirst` false, mix over what is playing. */
  play(notes: readonly Note[], volume = 0.05, stopFirst = true, delay = 0): void {
    const ctx = this.ctx;
    if (this.muted || !ctx) return;
    if (stopFirst) this.stop();
    let t = ctx.currentTime + 0.02 + delay;
    for (const [seconds, pitch] of notes) {
      if (pitch !== null) {
        const gain = ctx.createGain();
        gain.gain.setValueAtTime(volume, t);
        gain.gain.setValueAtTime(volume, t + Math.max(0, seconds - 0.01));
        gain.gain.linearRampToValueAtTime(0, t + seconds);
        gain.connect(ctx.destination);
        let source: AudioScheduledSourceNode;
        if (pitch === "noise") {
          const b = ctx.createBufferSource();
          b.buffer = this.noise(ctx);
          source = b;
        } else {
          const o = ctx.createOscillator();
          o.type = "square";
          o.frequency.value = frequency(pitch);
          source = o;
        }
        source.connect(gain);
        source.start(t);
        source.stop(t + seconds);
        this.playing.push(source);
        source.onended = () => { this.playing = this.playing.filter((n) => n !== source); };
      }
      t += seconds;
    }
  }

  private noise(ctx: AudioContext): AudioBuffer {
    if (!this.noiseBuffer) {
      this.noiseBuffer = ctx.createBuffer(1, ctx.sampleRate, ctx.sampleRate);
      const data = this.noiseBuffer.getChannelData(0);
      for (let i = 0; i < data.length; i++) data[i] = Math.random() * 2 - 1;
    }
    return this.noiseBuffer;
  }
}
