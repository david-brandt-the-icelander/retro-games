// Sine and cosine from + - * / only. IEEE arithmetic gives the same answer in every browser and on
// the server, which Math.sin does not promise; the high-score check replays games on the server and
// must reach exactly the same positions the player saw.
const TAU = 2 * Math.PI;
const HALF_PI = Math.PI / 2;

export function dsin(x: number): number {
  let r = x - Math.round(x / TAU) * TAU; // now in [-π, π]
  if (r > HALF_PI) r = Math.PI - r;
  else if (r < -HALF_PI) r = -Math.PI - r; // now in [-π/2, π/2], where the series below is good to 1e-7
  const r2 = r * r;
  return r * (1 - (r2 / 6) * (1 - (r2 / 20) * (1 - (r2 / 42) * (1 - (r2 / 72) * (1 - r2 / 110)))));
}

export const dcos = (x: number): number => dsin(x + HALF_PI);
