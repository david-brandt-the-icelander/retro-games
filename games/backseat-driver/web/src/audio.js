// Synthesised sound: engine, road noise, passing traffic, horns, and event cues. No audio files.
const AU = {
  ctx: null, on: true, master: null, eng1: null, eng2: null, engGain: null, engLp: null, roadGain: null, roadBp: null, noise: null,
  next: 3, init() {
    if (this.ctx) { if (this.ctx.state === "suspended") this.ctx.resume(); return; }
    try {
      const C = window.AudioContext || window.webkitAudioContext; if (!C) return;
      const c = (this.ctx = new C());
      this.master = c.createGain(); this.master.gain.value = this.on ? 0.8 : 0; this.master.connect(c.destination);
      const len = c.sampleRate * 2, buf = c.createBuffer(1, len, c.sampleRate), d = buf.getChannelData(0);
      for (let i = 0; i < len; i++) d[i] = Math.random() * 2 - 1;
      this.noise = buf;
      this.engLp = c.createBiquadFilter(); this.engLp.type = "lowpass"; this.engLp.frequency.value = 300;
      this.engGain = c.createGain(); this.engGain.gain.value = 0.0;
      this.eng1 = c.createOscillator(); this.eng1.type = "sawtooth";
      this.eng2 = c.createOscillator(); this.eng2.type = "square";
      this.eng1.connect(this.engLp); this.eng2.connect(this.engLp); this.engLp.connect(this.engGain); this.engGain.connect(this.master);
      this.eng1.start(); this.eng2.start();
      const rs = c.createBufferSource(); rs.buffer = buf; rs.loop = true;
      this.roadBp = c.createBiquadFilter(); this.roadBp.type = "bandpass"; this.roadBp.frequency.value = 700; this.roadBp.Q.value = 0.6;
      this.roadGain = c.createGain(); this.roadGain.gain.value = 0;
      rs.connect(this.roadBp); this.roadBp.connect(this.roadGain); this.roadGain.connect(this.master); rs.start();
    } catch (e) { this.ctx = null; }
  },
  toggle() {
    this.on = !this.on;
    if (this.master) this.master.gain.setTargetAtTime(this.on ? 0.8 : 0, this.ctx.currentTime, 0.05);
    return this.on;
  },
  // called every frame
  update(mph, dt, driving) {
    const c = this.ctx; if (!c) return;
    const t = c.currentTime, v = Math.max(0, mph);
    this.eng1.frequency.setTargetAtTime(34 + v * 1.3, t, 0.08);
    this.eng2.frequency.setTargetAtTime(17 + v * 0.65, t, 0.08);
    this.engLp.frequency.setTargetAtTime(160 + v * 7, t, 0.1);
    this.engGain.gain.setTargetAtTime(driving ? 0.05 : 0.0, t, 0.2);
    this.roadGain.gain.setTargetAtTime(Math.min(0.14, v / 80 * 0.14), t, 0.1);
    this.roadBp.frequency.setTargetAtTime(400 + v * 10, t, 0.1);
    if (driving) { this.next -= dt; if (this.next <= 0) { this.next = 2 + Math.random() * 5; Math.random() < 0.6 ? this.pass() : this.honk(true); } }
  },
  _env(g, t0, a, d, peak) { g.gain.setValueAtTime(0.0001, t0); g.gain.linearRampToValueAtTime(peak, t0 + a); g.gain.exponentialRampToValueAtTime(0.0001, t0 + a + d); },
  noiseBurst(dur, type, f0, f1, peak, att, pan) {
    const c = this.ctx; if (!c || !this.on) return; const t = c.currentTime;
    const s = c.createBufferSource(); s.buffer = this.noise;
    const f = c.createBiquadFilter(); f.type = type; f.frequency.setValueAtTime(f0, t); f.frequency.exponentialRampToValueAtTime(Math.max(20, f1), t + dur);
    const g = c.createGain(); this._env(g, t, att === undefined ? 0.02 : att, dur, peak);
    s.connect(f); f.connect(g);
    if (c.createStereoPanner && pan !== undefined) { const p = c.createStereoPanner(); p.pan.setValueAtTime(pan, t); p.pan.linearRampToValueAtTime(-pan, t + dur); g.connect(p); p.connect(this.master); } else g.connect(this.master);
    s.start(t); s.stop(t + dur + 0.2);
  },
  tone(freq, dur, type, peak, f1, delay) {
    const c = this.ctx; if (!c || !this.on) return; const t = c.currentTime + (delay || 0);
    const o = c.createOscillator(); o.type = type; o.frequency.setValueAtTime(freq, t);
    if (f1) o.frequency.exponentialRampToValueAtTime(f1, t + dur);
    const g = c.createGain(); this._env(g, t, 0.01, dur, peak);
    o.connect(g); g.connect(this.master); o.start(t); o.stop(t + dur + 0.1);
  },
  pass() { const d = 0.9 + Math.random() * 0.8, side = Math.random() < 0.5 ? -1 : 1; this.noiseBurst(d, "bandpass", 250, 900 + Math.random() * 500, 0.22, d * 0.45, side * 0.9); },
  honk(far) { const k = far ? 0.05 : 0.16, f = 330 + Math.random() * 120; this.tone(f, 0.35, "square", k, f * 0.99); this.tone(f * 1.26, 0.35, "square", k, f * 1.25); },
  screech() { this.noiseBurst(1.0, "bandpass", 3200, 1700, 0.3, 0.03); this.tone(1900, 0.9, "sawtooth", 0.05, 1200); },
  crash() { this.noiseBurst(0.8, "lowpass", 2600, 120, 0.7, 0.005); this.tone(90, 0.6, "sine", 0.6, 28); this.tone(230, 0.25, "square", 0.12, 90); this.noiseBurst(1.4, "highpass", 5000, 3000, 0.08, 0.1); },
  good() { this.tone(660, 0.18, "triangle", 0.2); this.tone(880, 0.25, "triangle", 0.2, null, 0.12); this.tone(1320, 0.3, "triangle", 0.15, null, 0.26); },
  ding() { this.tone(1046, 0.25, "sine", 0.18); },
  tick() { this.tone(700, 0.05, "square", 0.05); },
  scream() { this.tone(520, 0.5, "sawtooth", 0.09, 880); this.tone(780, 0.5, "square", 0.04, 1250); },
  cue(id) {
    switch (id) {
      case "ducks": for (let i = 0; i < 4; i++) { this.tone(430, 0.12, "sawtooth", 0.1, 250, i * 0.22); this.tone(380, 0.1, "sawtooth", 0.08, 230, i * 0.22 + 0.11); } break;
      case "police": for (let i = 0; i < 4; i++) this.tone(i % 2 ? 960 : 720, 0.3, "sine", 0.1, null, i * 0.3); break;
      case "train": this.tone(311, 1.4, "sawtooth", 0.1); this.tone(392, 1.4, "sawtooth", 0.1); this.tone(311, 0.8, "sawtooth", 0.1, null, 1.5); this.tone(392, 0.8, "sawtooth", 0.1, null, 1.5); break;
      case "wrongway": this.honk(false); this.tone(330, 0.5, "square", 0.12, null, 0.5); this.tone(415, 0.5, "square", 0.12, null, 0.5); break;
      case "bus": for (let i = 0; i < 3; i++) this.tone(900, 0.12, "square", 0.07, null, i * 0.28); break;
      case "gator": this.noiseBurst(1.2, "lowpass", 220, 70, 0.3, 0.2); break;
      case "deer": this.tone(600, 0.2, "triangle", 0.06, 420); this.tone(520, 0.25, "triangle", 0.06, 360, 0.3); break;
      case "rocks": for (let i = 0; i < 6; i++) this.noiseBurst(0.18, "lowpass", 900, 200, 0.18, 0.005); break;
      case "minspeed": this.honk(false); break;
      default: this.honk(true);
    }
  },
};
