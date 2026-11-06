// Deterministic maths for the engine. Math.sin, Math.cos, Math.atan2, Math.exp and Math.hypot may
// differ in the last bit between browsers and the server, and a game replayed on the server must
// come out exactly as it was played. These use only + − × ÷ and Math.sqrt, which IEEE 754 fixes
// to the bit, so every JavaScript engine computes the same numbers.

const HALF_PI_HI = 1.5707963267341256; // π/2 split in two, so that x − k·π/2 stays accurate
const HALF_PI_LO = 6.077100506506192e-11;
const INV_HALF_PI = 0.6366197723675814;

/** sin(r) for |r| ≤ π/4, Taylor series to r^15. */
function sinPoly(r: number): number {
  const r2 = r * r;
  return r * (1 + r2 * (-1 / 6 + r2 * (1 / 120 + r2 * (-1 / 5040 + r2 * (1 / 362880 + r2 * (-1 / 39916800 + r2 * (1 / 6227020800 + r2 * (-1 / 1307674368000))))))));
}

/** cos(r) for |r| ≤ π/4, Taylor series to r^16. */
function cosPoly(r: number): number {
  const r2 = r * r;
  return 1 + r2 * (-1 / 2 + r2 * (1 / 24 + r2 * (-1 / 720 + r2 * (1 / 40320 + r2 * (-1 / 3628800 + r2 * (1 / 479001600 + r2 * (-1 / 87178291200 + r2 * (1 / 20922789888000))))))));
}

function reduce(x: number): [number, number] {
  const k = Math.round(x * INV_HALF_PI);
  const r = x - k * HALF_PI_HI - k * HALF_PI_LO;
  return [r, ((k % 4) + 4) % 4];
}

export function sin(x: number): number {
  const [r, q] = reduce(x);
  return q === 0 ? sinPoly(r) : q === 1 ? cosPoly(r) : q === 2 ? -sinPoly(r) : -cosPoly(r);
}

export function cos(x: number): number {
  const [r, q] = reduce(x);
  return q === 0 ? cosPoly(r) : q === 1 ? -sinPoly(r) : q === 2 ? -cosPoly(r) : sinPoly(r);
}

/** atan(x) for any x: fold to |x| ≤ 1, halve the angle twice, then a short series. */
function atan(x: number): number {
  if (x < 0) return -atan(-x);
  if (x > 1) return Math.PI / 2 - atan(1 / x);
  // atan(x) = 2·atan(x / (1 + √(1 + x²))), twice: |t| ≤ tan(π/16) ≈ 0.199.
  let t = x / (1 + Math.sqrt(1 + x * x));
  t = t / (1 + Math.sqrt(1 + t * t));
  const t2 = t * t;
  let sum = 0;
  for (let n = 23; n >= 1; n -= 2) sum = 1 / n - t2 * sum;
  return 4 * t * sum;
}

export function atan2(y: number, x: number): number {
  if (x > 0) return atan(y / x);
  if (x < 0) return y >= 0 ? atan(y / x) + Math.PI : atan(y / x) - Math.PI;
  return y > 0 ? Math.PI / 2 : y < 0 ? -Math.PI / 2 : 0;
}

export const hypot = (x: number, y: number): number => Math.sqrt(x * x + y * y);
