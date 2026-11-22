// Painting helpers shared by every piece of art: colour mixing, a seeded
// random generator, SVG shape builders and the filters that turn flat SVG
// shapes into soft, textured, storybook-painted ones.

export const TAU = Math.PI * 2;

export function rng(seed) {
  let s = (seed >>> 0) || 1;
  return () => (s = (Math.imul(s, 1664525) + 1013904223) >>> 0) / 4294967296;
}

const hex = h => { const n = parseInt(h.slice(1), 16); return [n >> 16, (n >> 8) & 255, n & 255]; };
const toHex = a => '#' + a.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, '0')).join('');
export const mix = (a, b, t) => { const A = hex(a), B = hex(b); return toHex(A.map((v, i) => v + (B[i] - v) * t)); };
export const tint = (c, t) => mix(c, '#fff8ec', t);
export const shade = (c, t) => mix(c, '#24122a', t);
export const cool = (c, t) => mix(c, '#3b4f9a', t);

const f = n => +n.toFixed(2);
const attrs = o => Object.entries(o || {}).filter(([, v]) => v != null && v !== false)
  .map(([k, v]) => ` ${k.replace(/[A-Z]/g, m => '-' + m.toLowerCase())}="${typeof v === 'number' ? f(v) : v}"`).join('');

export const el = (tag, a, inner) => inner == null ? `<${tag}${attrs(a)}/>` : `<${tag}${attrs(a)}>${inner}</${tag}>`;
export const g = (a, ...kids) => el('g', a, kids.flat().join(''));
export const path = (d, a) => el('path', { d, ...a });
export const ellipse = (cx, cy, rx, ry, a) => el('ellipse', { cx, cy, rx, ry, ...a });
export const circle = (cx, cy, r, a) => el('circle', { cx, cy, r, ...a });
export const rect = (x, y, width, height, a) => el('rect', { x, y, width, height, ...a });

// A closed, slightly irregular ellipse: painted shapes are never perfect.
export function blob(cx, cy, rx, ry, seed = 1, wob = 0.035, rot = 0) {
  const r = rng(seed), n = 14, pts = [];
  const ph = r() * TAU, ph2 = r() * TAU;
  for (let i = 0; i < n; i++) {
    const a = i / n * TAU, k = 1 + wob * (Math.sin(a * 3 + ph) * 0.6 + Math.sin(a * 5 + ph2) * 0.4);
    const x = Math.cos(a) * rx * k, y = Math.sin(a) * ry * k;
    pts.push([cx + x * Math.cos(rot) - y * Math.sin(rot), cy + x * Math.sin(rot) + y * Math.cos(rot)]);
  }
  return smooth(pts, true);
}

// Catmull-Rom through points, as cubic Béziers.
export function smooth(pts, closed = false, tension = 1) {
  const P = i => closed ? pts[(i + pts.length) % pts.length] : pts[Math.max(0, Math.min(pts.length - 1, i))];
  let d = `M${f(pts[0][0])} ${f(pts[0][1])}`;
  const last = closed ? pts.length : pts.length - 1;
  for (let i = 0; i < last; i++) {
    const p0 = P(i - 1), p1 = P(i), p2 = P(i + 1), p3 = P(i + 2), k = tension / 6;
    d += `C${f(p1[0] + (p2[0] - p0[0]) * k)} ${f(p1[1] + (p2[1] - p0[1]) * k)} ${f(p2[0] - (p3[0] - p1[0]) * k)} ${f(p2[1] - (p3[1] - p1[1]) * k)} ${f(p2[0])} ${f(p2[1])}`;
  }
  return d + (closed ? 'Z' : '');
}

// Collects <defs> for one SVG document and hands out unique ids.
export class Defs {
  constructor(prefix = 'd') { this.items = []; this.n = 0; this.prefix = prefix; }
  id() { return this.prefix + (this.n++); }
  add(s) { this.items.push(s); }
  toString() { return this.items.join(''); }
  // Radial gradient in bounding-box units; stops are [offset, colour, opacity?].
  rg(stops, { cx = 0.5, cy = 0.5, r = 0.5, fx, fy, units } = {}) {
    const id = this.id();
    this.add(el('radialGradient', { id, cx, cy, r, fx, fy, gradientUnits: units },
      stops.map(([o, c, a]) => el('stop', { offset: o, stopColor: c, stopOpacity: a })).join('')));
    return `url(#${id})`;
  }
  lg(stops, x1 = 0, y1 = 0, x2 = 0, y2 = 1, units) {
    const id = this.id();
    this.add(el('linearGradient', { id, x1, y1, x2, y2, gradientUnits: units },
      stops.map(([o, c, a]) => el('stop', { offset: o, stopColor: c, stopOpacity: a })).join('')));
    return `url(#${id})`;
  }
  clip(inner) { const id = this.id(); this.add(el('clipPath', { id }, inner)); return `url(#${id})`; }
  blur(sd) { const id = this.id(); this.add(el('filter', { id, x: '-50%', y: '-50%', width: '200%', height: '200%' }, el('feGaussianBlur', { stdDeviation: sd }))); return `url(#${id})`; }

  // The painted look. Volume from a soft shadow on the side away from the
  // light (top left) and a warm rim on the lit side; a little edge wobble;
  // mottled colour; fine paper grain. k scales the effect to the shape size.
  paint({ k = 1, rim = '#fff3d6', rimA = 0.55, sh = '#2a1736', shA = 0.42, wob = 1.6, wobF = 0.06, fur = 0, grain = 0.16, mottle = 0.22, seed = 3, light = [1, 1] } = {}) {
    const id = this.id(), lx = light[0], ly = light[1];
    const furPart = fur ? `<feTurbulence type="turbulence" baseFrequency="${f(0.32 / k)}" numOctaves="2" seed="${seed + 5}" result="fz"/>
      <feDisplacementMap in="w0" in2="fz" scale="${f(fur * k)}" xChannelSelector="R" yChannelSelector="B" result="w"/>`
      : `<feOffset in="w0" result="w"/>`;
    this.add(`<filter id="${id}" x="-25%" y="-25%" width="150%" height="150%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="${f(wobF / k)}" numOctaves="2" seed="${seed}" result="wn"/>
      <feDisplacementMap in="SourceGraphic" in2="wn" scale="${f(wob * k)}" xChannelSelector="R" yChannelSelector="G" result="w0"/>
      ${furPart}
      <feColorMatrix in="w" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="A"/>
      <feOffset in="A" dx="${f(-5 * k * lx)}" dy="${f(-6 * k * ly)}" result="o1"/>
      <feComposite in="A" in2="o1" operator="out" result="e1"/>
      <feGaussianBlur in="e1" stdDeviation="${f(4.5 * k)}" result="b1"/>
      <feComposite in="b1" in2="A" operator="in" result="s1"/>
      <feFlood flood-color="${sh}" flood-opacity="${shA}"/><feComposite in2="s1" operator="in" result="shadow"/>
      <feOffset in="A" dx="${f(2.6 * k * lx)}" dy="${f(3.2 * k * ly)}" result="o2"/>
      <feComposite in="A" in2="o2" operator="out" result="e2"/>
      <feGaussianBlur in="e2" stdDeviation="${f(1.8 * k)}" result="b2"/>
      <feComposite in="b2" in2="A" operator="in" result="s2"/>
      <feFlood flood-color="${rim}" flood-opacity="${rimA}"/><feComposite in2="s2" operator="in" result="rimc"/>
      <feTurbulence type="fractalNoise" baseFrequency="${f(0.045 / k)}" numOctaves="3" seed="${seed + 2}" result="mn"/>
      <feColorMatrix in="mn" type="matrix" values="0 0 0 0 .5  0 0 0 0 .5  0 0 0 0 .5  ${f(mottle * 2.2)} 0 0 0 ${f(-mottle * 0.9)}" result="mo"/>
      <feComposite in="mo" in2="A" operator="in" result="mott"/>
      <feTurbulence type="fractalNoise" baseFrequency="${f(0.9 / k)}" numOctaves="2" seed="${seed + 9}" result="gn"/>
      <feColorMatrix in="gn" type="saturate" values="0" result="gg"/>
      <feComponentTransfer in="gg" result="gr"><feFuncA type="linear" slope="${grain}" intercept="0"/></feComponentTransfer>
      <feComposite in="gr" in2="A" operator="in" result="grain"/>
      <feBlend in="mott" in2="w" mode="soft-light" result="m1"/>
      <feBlend in="grain" in2="m1" mode="overlay" result="m2"/>
      <feComposite in="m2" in2="A" operator="in" result="m3"/>
      <feMerge><feMergeNode in="m3"/><feMergeNode in="shadow"/><feMergeNode in="rimc"/></feMerge>
    </filter>`);
    return `url(#${id})`;
  }

  // Soft wobble and grain only, for things with their own shading.
  rough({ k = 1, wob = 1.4, grain = 0.12, seed = 4 } = {}) {
    const id = this.id();
    this.add(`<filter id="${id}" x="-20%" y="-20%" width="140%" height="140%" color-interpolation-filters="sRGB">
      <feTurbulence type="fractalNoise" baseFrequency="${f(0.06 / k)}" numOctaves="2" seed="${seed}" result="wn"/>
      <feDisplacementMap in="SourceGraphic" in2="wn" scale="${f(wob * k)}" xChannelSelector="R" yChannelSelector="G" result="w"/>
      <feColorMatrix in="w" type="matrix" values="0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 1 0" result="A"/>
      <feTurbulence type="fractalNoise" baseFrequency="${f(0.9 / k)}" numOctaves="2" seed="${seed + 9}" result="gn"/>
      <feColorMatrix in="gn" type="saturate" values="0" result="gg"/>
      <feComponentTransfer in="gg" result="gr"><feFuncA type="linear" slope="${grain}"/></feComponentTransfer>
      <feComposite in="gr" in2="A" operator="in" result="grain"/>
      <feBlend in="grain" in2="w" mode="overlay" result="m"/>
      <feComposite in="m" in2="A" operator="in"/>
    </filter>`);
    return `url(#${id})`;
  }

  // A soft outer glow of the shape's own colour.
  glow(sd, a = 0.8) {
    const id = this.id();
    this.add(`<filter id="${id}" x="-100%" y="-100%" width="300%" height="300%">
      <feGaussianBlur in="SourceGraphic" stdDeviation="${sd}" result="b"/>
      <feComponentTransfer in="b" result="b2"><feFuncA type="linear" slope="${a}"/></feComponentTransfer>
      <feMerge><feMergeNode in="b2"/><feMergeNode in="SourceGraphic"/></feMerge></filter>`);
    return `url(#${id})`;
  }
}

// A rounded body: radial-gradient fill with a lit top-left, painted through
// the paint filter, clipped texture strokes inside.
export function painted(D, d, col, o = {}) {
  const fill = D.rg([[0, tint(col, o.hi ?? 0.32)], [0.55, col], [1, shade(col, o.lo ?? 0.22)]],
    { cx: o.cx ?? 0.36, cy: o.cy ?? 0.3, r: o.r ?? 0.85 });
  const clip = D.clip(path(d));
  const tex = o.strokes ? g({ clipPath: clip }, o.strokes) : '';
  const extra = o.inner ? g({ clipPath: clip }, o.inner) : '';
  return g({ filter: D.paint(o.paint || {}) }, path(d, { fill }), tex, extra);
}

// Short curved brush strokes scattered inside an ellipse, for fur, wood or
// snow texture. The colours wander around `col`.
export function strokes(cx, cy, rx, ry, col, { n = 60, len = 6, w = 1.4, seed = 7, a = 0.35, dir = null, spread = 0.18 } = {}) {
  const r = rng(seed); let s = '';
  for (let i = 0; i < n; i++) {
    const t = r() * TAU, q = Math.sqrt(r());
    const x = cx + Math.cos(t) * rx * q, y = cy + Math.sin(t) * ry * q;
    // fur follows the surface outwards and down
    const ang = dir != null ? dir + (r() - 0.5) * 0.6 : Math.atan2(y - cy + ry * 0.6, x - cx) + (r() - 0.5) * 0.5;
    const L = len * (0.6 + r() * 0.8), bend = (r() - 0.5) * L * 0.6;
    const x2 = x + Math.cos(ang) * L, y2 = y + Math.sin(ang) * L;
    const mx = (x + x2) / 2 - Math.sin(ang) * bend, my = (y + y2) / 2 + Math.cos(ang) * bend;
    const c = r() < 0.5 ? tint(col, spread * r() * 2) : shade(col, spread * r() * 1.6);
    s += path(`M${f(x)} ${f(y)}Q${f(mx)} ${f(my)} ${f(x2)} ${f(y2)}`, { stroke: c, strokeWidth: w * (0.6 + r() * 0.7), strokeLinecap: 'round', fill: 'none', opacity: f(a * (0.5 + r() * 0.7)) });
  }
  return s;
}

// Fuzzy fur tufts around the rim of an ellipse.
export function tufts(cx, cy, rx, ry, col, { n = 40, len = 5, w = 2.2, seed = 9, from = 0, to = TAU } = {}) {
  const r = rng(seed); let s = '';
  for (let i = 0; i < n; i++) {
    const t = from + (to - from) * (i + r() * 0.8) / n;
    const x = cx + Math.cos(t) * rx * 0.97, y = cy + Math.sin(t) * ry * 0.97;
    const ang = t + (r() - 0.5) * 0.7, L = len * (0.5 + r());
    s += path(`M${f(x - Math.cos(t) * 2)} ${f(y - Math.sin(t) * 2)}Q${f(x + Math.cos(ang) * L * 0.6 + (r() - 0.5) * 2)} ${f(y + Math.sin(ang) * L * 0.6)} ${f(x + Math.cos(ang) * L)} ${f(y + Math.sin(ang) * L)}`,
      { stroke: r() < 0.3 ? tint(col, 0.15) : col, strokeWidth: w * (0.6 + r() * 0.6), strokeLinecap: 'round', fill: 'none' });
  }
  return s;
}

// A soft blurred spot: blush, glow or painted shadow.
export const spot = (D, cx, cy, rx, ry, col, a = 1, blurK = 0.35) =>
  ellipse(cx, cy, rx, ry, { fill: col, opacity: a, filter: D.blur(f(Math.min(rx, ry) * blurK)) });

// Wraps content in a document sized to `box` (units) at `scale` px per unit.
export function svgDoc(box, scale, D, body) {
  const [x0, y0, x1, y1] = box, w = x1 - x0, h = y1 - y0;
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${Math.ceil(w * scale)}" height="${Math.ceil(h * scale)}" viewBox="${x0} ${y0} ${w} ${h}"><defs>${D}</defs>${body}</svg>`;
}

// The arched opening shared by the house windows, the shutters and the card.
export function archD(x, y, w, h, ah) {
  return `M${f(x)} ${f(y + h)}L${f(x)} ${f(y + ah)}A${f(w / 2)} ${f(ah)} 0 0 1 ${f(x + w)} ${f(y + ah)}L${f(x + w)} ${f(y + h)}Z`;
}
