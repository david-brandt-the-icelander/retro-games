// Sound: square and triangle beeps made with the Web Audio API when the page runs. No audio files.
export class Sound {
  private ctx: AudioContext | null = null;
  muted = false;

  /** Must be called from a key press or tap, as browsers only start audio then. */
  unlock(): void {
    if (!this.ctx) {
      try {
        const AC = window.AudioContext ?? (window as unknown as { webkitAudioContext: typeof AudioContext }).webkitAudioContext;
        this.ctx = new AC();
      } catch {
        this.ctx = null;
      }
    }
    if (this.ctx && this.ctx.state === "suspended") void this.ctx.resume();
  }

  beep(freq: number, dur: number, type: OscillatorType = "square", vol = 0.06, slideTo = 0, delay = 0): void {
    if (this.muted || !this.ctx) return;
    const t = this.ctx.currentTime + delay;
    const o = this.ctx.createOscillator();
    const g = this.ctx.createGain();
    o.type = type;
    o.frequency.setValueAtTime(freq, t);
    if (slideTo > 0) o.frequency.exponentialRampToValueAtTime(slideTo, t + dur);
    g.gain.setValueAtTime(vol, t);
    g.gain.exponentialRampToValueAtTime(0.0001, t + dur);
    o.connect(g).connect(this.ctx.destination);
    o.start(t);
    o.stop(t + dur + 0.02);
  }

  event(name: string): void {
    switch (name) {
      case "jump":
        this.beep(260, 0.18, "square", 0.05, 620);
        break;
      case "land":
        this.beep(120, 0.05, "triangle", 0.06);
        break;
      case "over":
        this.beep(660, 0.1, "square", 0.06, 1320);
        break;
      case "pickup":
        [523, 659, 784, 1047].forEach((f, i) => this.beep(f, 0.09, "square", 0.05, 0, i * 0.07));
        break;
      case "hammer":
        [392, 523, 392, 523, 784].forEach((f, i) => this.beep(f, 0.08, "square", 0.05, 0, i * 0.06));
        break;
      case "smash":
        this.beep(180, 0.2, "sawtooth", 0.07, 40);
        break;
      case "rivet":
        this.beep(900, 0.07, "square", 0.05, 500);
        break;
      case "throw":
        this.beep(90, 0.22, "sawtooth", 0.07, 55);
        break;
      case "oil":
        this.beep(300, 0.3, "sawtooth", 0.05, 80);
        break;
      case "death":
        [494, 466, 440, 415, 392, 370, 349, 330].forEach((f, i) => this.beep(f, 0.12, "square", 0.06, 0, i * 0.1));
        break;
      case "clear":
        [523, 659, 784, 1047, 784, 1047, 1319].forEach((f, i) => this.beep(f, 0.12, "square", 0.05, 0, i * 0.1));
        break;
      case "extra":
        [784, 988, 1175, 1568].forEach((f, i) => this.beep(f, 0.1, "square", 0.05, 0, i * 0.08));
        break;
      case "climb":
        this.beep(440, 0.04, "triangle", 0.04);
        break;
    }
  }

  step(): void {
    this.beep(150, 0.04, "triangle", 0.04);
  }

  /** One beat of the stage's tune; `n` counts beats. Each stage has its own short, original bass line. */
  music(kind: string, n: number, fast: boolean): void {
    const tunes: Record<string, number[]> = {
      girders: [110, 0, 165, 0, 147, 0, 196, 165],
      conveyors: [131, 131, 0, 196, 175, 0, 147, 147],
      elevators: [98, 147, 98, 147, 117, 175, 117, 175],
      rivets: [123, 0, 185, 165, 0, 247, 185, 0],
    };
    const t = tunes[kind] ?? tunes.girders;
    const f = t[n % t.length];
    if (f > 0) this.beep(fast ? f * 2 : f, 0.1, "triangle", 0.05);
  }
}
