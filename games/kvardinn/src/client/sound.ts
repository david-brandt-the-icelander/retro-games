// A few soft tones made on the spot with Web Audio: a chime for the reveal, rising with the points.
// Off when the player turns sound off (kept on this device).

let ctx: AudioContext | null = null;
const KEY = "kvardinn.sound";

export function soundOn(): boolean {
  try {
    return localStorage.getItem(KEY) !== "off";
  } catch {
    return true;
  }
}

export function setSound(on: boolean): void {
  try {
    localStorage.setItem(KEY, on ? "on" : "off");
  } catch {
    /* ignore */
  }
}

/** Browsers start audio only after a tap: call this from one. */
export function unlockAudio(): void {
  if (!soundOn()) return;
  try {
    ctx ??= new AudioContext();
    if (ctx.state === "suspended") void ctx.resume();
  } catch {
    ctx = null;
  }
}

function tone(freq: number, at: number, len: number, gain = 0.18, type: OscillatorType = "sine"): void {
  if (!ctx) return;
  const t = ctx.currentTime + at;
  const o = ctx.createOscillator();
  const g = ctx.createGain();
  o.type = type;
  o.frequency.value = freq;
  g.gain.setValueAtTime(0.0001, t);
  g.gain.exponentialRampToValueAtTime(gain, t + 0.02);
  g.gain.exponentialRampToValueAtTime(0.0001, t + len);
  o.connect(g).connect(ctx.destination);
  o.start(t);
  o.stop(t + len + 0.05);
}

/** A rising sweep while the target is uncovered. */
export function playSweep(): void {
  if (!soundOn() || !ctx) return;
  [392, 440, 494, 523].forEach((f, i) => tone(f, i * 0.16, 0.25, 0.06, "triangle"));
}

/** The result: more notes for more points; a low tone for none. */
export function playPoints(points: number): void {
  if (!soundOn() || !ctx) return;
  if (points === 0) {
    tone(196, 0, 0.5, 0.12, "triangle");
    tone(174.6, 0.18, 0.6, 0.1, "triangle");
    return;
  }
  const notes = [523.3, 659.3, 784, 1046.5].slice(0, points);
  notes.forEach((f, i) => tone(f, i * 0.12, 0.6));
}

export function playTick(): void {
  if (!soundOn() || !ctx) return;
  tone(880, 0, 0.12, 0.05);
}
