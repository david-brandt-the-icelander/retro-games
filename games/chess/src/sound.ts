// Square-wave blips in the spirit of an 8-bit sound chip. Every tune here is our own.

let ctx: AudioContext | null = null;
let muted = (() => { try { return localStorage.getItem("chess.muted") === "1"; } catch { return false; } })();

export const isMuted = () => muted;
export function setMuted(m: boolean): void {
  muted = m;
  try { localStorage.setItem("chess.muted", m ? "1" : "0"); } catch { /* storage blocked */ }
}

function audio(): AudioContext | null {
  if (muted) return null;
  try {
    ctx ??= new AudioContext();
    if (ctx.state === "suspended") void ctx.resume();
    return ctx;
  } catch {
    return null;
  }
}

/** Plays notes as [frequency Hz (0 for a rest), length s]. */
function tune(notes: [number, number][], type: OscillatorType = "square", volume = 0.06): void {
  const a = audio();
  if (!a) return;
  let t = a.currentTime + 0.01;
  for (const [f, len] of notes) {
    if (f > 0) {
      const o = a.createOscillator();
      const g = a.createGain();
      o.type = type;
      o.frequency.setValueAtTime(f, t);
      g.gain.setValueAtTime(volume, t);
      g.gain.exponentialRampToValueAtTime(0.0001, t + len * 0.95);
      o.connect(g).connect(a.destination);
      o.start(t);
      o.stop(t + len);
    }
    t += len;
  }
}

export const sounds = {
  select: () => tune([[880, 0.03]], "square", 0.03),
  move: () => tune([[330, 0.04], [220, 0.05]], "triangle", 0.18),
  capture: () => tune([[196, 0.04], [147, 0.04], [98, 0.08]], "square", 0.07),
  check: () => tune([[784, 0.07], [0, 0.03], [784, 0.07]]),
  illegal: () => tune([[110, 0.08]], "sawtooth", 0.05),
  notify: () => tune([[523, 0.06], [784, 0.09]]),
  win: () => tune([[523, 0.1], [659, 0.1], [784, 0.1], [1047, 0.25]]),
  lose: () => tune([[392, 0.15], [330, 0.15], [262, 0.15], [196, 0.3]], "triangle", 0.15),
  draw: () => tune([[440, 0.12], [440, 0.12], [392, 0.25]], "triangle", 0.15),
};
