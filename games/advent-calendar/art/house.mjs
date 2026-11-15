// The house: a snowy log house at night under the aurora, with 24 arched
// windows in its gable wall, string lights, a wreath, a snowman, gifts, a
// dog and a cat. Plus the shutter doors that close each window.
import { Defs, svgDoc, g, path, ellipse, circle, rect, blob, smooth, painted, strokes, spot, mix, tint, shade, rng, archD, TAU } from './paint.mjs';
import { poseSVG } from './characters.mjs';

export const HW = 390, HH = 960;
// The 24 window openings, 4 across and 6 down. The game places the doors here.
export const WIN = { x0: 43, dx: 79, w: 66, y0: 318, dy: 84, h: 72, ah: 20 };
export const winBox = i => ({ x: WIN.x0 + (i % 4) * WIN.dx, y: WIN.y0 + Math.floor(i / 4) * WIN.dy, w: WIN.w, h: WIN.h });

const HUES = [0, 42, 130, 205, 320];
const f = n => +n.toFixed(2);

function pine(D, x, base, h, w, seed, col = '#173f3a', dark = false) {
  const r = rng(seed); let s = '';
  const tiers = 6;
  for (let i = 0; i < tiers; i++) {
    const u = i / tiers, y = base - h * u * 0.9, tw = w * (1 - u * 0.82), th = h / tiers * 1.7;
    const d = `M${x - tw} ${y}Q${x - tw * 0.4} ${y - th * 0.35} ${x} ${y - th}Q${x + tw * 0.4} ${y - th * 0.35} ${x + tw} ${y}Q${x} ${y - th * 0.18} ${x - tw} ${y}Z`;
    s += path(d, { fill: D.lg([[0, tint(col, 0.08)], [0.5, col], [1, shade(col, 0.35)]], 0, 0, 1, 0) });
    // snow resting on each tier
    const sd = `M${x - tw * 0.92} ${y - 2}Q${x - tw * 0.4} ${y - th * 0.4} ${x} ${y - th * 0.82}Q${x - tw * 0.2} ${y - th * 0.3} ${x - tw * 0.1} ${y - th * 0.12}Q${x - tw * 0.5} ${y - th * 0.08} ${x - tw * 0.92} ${y - 2}Z`;
    s += path(sd, { fill: dark ? '#9fb3dd' : '#eef3ff', opacity: dark ? 0.55 : 0.95 });
    if (r() < 0.6) s += ellipse(x + tw * (0.3 + r() * 0.3), y - th * 0.15, tw * 0.25, th * 0.07, { fill: dark ? '#9fb3dd' : '#e2eafb', opacity: dark ? 0.4 : 0.85 });
  }
  s += rect(x - w * 0.06, base - 4, w * 0.12, 12, { fill: '#2a1a14' });
  return s;
}

function aurora(D) {
  const r = rng(12); let s = '';
  const bands = [
    { y: 150, A: 34, f: 0.012, ph: 0.6, h: 120, c: '#5cf2b4', a: 0.75 },
    { y: 112, A: 26, f: 0.016, ph: 2.1, h: 95, c: '#47d8d0', a: 0.5 },
    { y: 205, A: 22, f: 0.01, ph: 4.0, h: 80, c: '#9b7bff', a: 0.42 },
  ];
  for (const b of bands) {
    const pts = [];
    for (let x = -30; x <= 420; x += 10) pts.push([x, b.y + Math.sin(x * b.f + b.ph) * b.A + Math.sin(x * b.f * 2.7 + b.ph) * b.A * 0.3]);
    const top = pts.map(([x, y]) => [x + 12, y - b.h]).reverse();
    const d = smooth(pts) + 'L' + smooth(top).slice(1) + 'Z';
    const id = D.lg([[0, b.c, 0], [0.55, b.c, b.a * 0.5], [0.9, tint(b.c, 0.3), b.a], [1, b.c, 0]], 0, 0, 0, 1);
    s += path(d, { fill: id, filter: D.blur(5) });
    // the curtain's vertical rays
    let rays = '';
    for (let x = -20; x < 420; x += 3.4) {
      const y = b.y + Math.sin(x * b.f + b.ph) * b.A + Math.sin(x * b.f * 2.7 + b.ph) * b.A * 0.3, L = b.h * (0.3 + r() * 0.75);
      rays += path(`M${f(x)} ${f(y - 4)}l7 ${f(-L)}`, { stroke: tint(b.c, 0.3), strokeWidth: 2.4 + r() * 3, opacity: f(b.a * (0.06 + r() * 0.16)) });
    }
    s += g({ filter: D.blur(2.6) }, rays);
  }
  return g({ style: 'mix-blend-mode:screen' }, s);
}

function logWall(D) {
  const wall = 'M22 834L22 320L195 168L368 320L368 834Z', r = rng(31);
  let logs = '';
  for (let y = 160, i = 0; y < 840; y += 21, i++) {
    const tone = ['#9a5c30', '#a3653a', '#93552b'][i % 3];
    logs += rect(0, y, HW, 21, { fill: D.lg([[0, tint(tone, 0.32)], [0.35, tone], [0.85, shade(tone, 0.3)], [1, shade(tone, 0.55)]]) });
    logs += rect(0, y + 19.6, HW, 1.6, { fill: '#2e170c', opacity: 0.8 });
    for (let k = 0; k < 7; k++) {
      const x = r() * HW, L = 30 + r() * 80, yy = y + 4 + r() * 13;
      logs += path(`M${f(x)} ${f(yy)}q${f(L / 2)} ${f((r() - 0.5) * 3)} ${f(L)} 0`, { stroke: r() < 0.5 ? shade(tone, 0.4) : tint(tone, 0.3), strokeWidth: 0.7 + r() * 0.6, fill: 'none', opacity: 0.55 });
    }
    if (r() < 0.6) { const kx = r() * HW; logs += ellipse(kx, y + 10, 3.2, 2.2, { fill: shade(tone, 0.45) }) + ellipse(kx, y + 10, 5.5, 3.6, { fill: 'none', stroke: shade(tone, 0.3), strokeWidth: 0.7 }); }
  }
  // warm light pooled under the eaves and cool moonlight down the left
  const light = rect(0, 150, HW, 700, { fill: D.lg([[0, '#1a2050', 0.45], [0.25, '#1a2050', 0], [1, '#0d1030', 0.25]]) }) +
    rect(0, 150, HW, 700, { fill: D.lg([[0, '#4a64c8', 0.22], [0.15, '#4a64c8', 0], [0.85, '#ff9a40', 0], [1, '#ff9a40', 0.12]], 0, 0, 1, 0) });
  return g({ filter: D.rough({ k: 1.2, wob: 1.2, grain: 0.18, seed: 5 }) }, g({ clipPath: D.clip(path(wall)) }, logs, light));
}

function logEnds(D) {
  let s = '';
  for (let y = 170.5, i = 0; y < 832; y += 21, i++) {
    [[22 - (i % 2 ? 4 : 1), 1], [368 + (i % 2 ? 4 : 1), -1]].forEach(([x, k]) => {
      if (y < 330) return; // above the eaves the logs end under the roof
      s +=ellipse(x, y, 11, 10.2, { fill: D.rg([[0, '#e7bd85'], [0.45, '#c99158'], [0.8, '#a06a3a'], [1, '#5e3518']], { cx: 0.42, cy: 0.4 }) });
      for (let q = 3; q <= 8; q += 2.5) s += ellipse(x + 0.6, y + 0.4, q, q * 0.92, { fill: 'none', stroke: '#8a5428', strokeWidth: 0.6, opacity: 0.7 });
      s += path(`M${x - 6} ${y - 7}q6 -5 12 0`, { stroke: '#f8fbff', strokeWidth: 2.6, fill: 'none', strokeLinecap: 'round', opacity: i % 3 ? 0 : 0.9 });
    });
  }
  return g({ filter: D.paint({ k: 0.3, seed: 6, shA: 0.5 }) }, s);
}

function windowArt(D, b, i) {
  const { x, y, w, h } = b, ah = WIN.ah, r = rng(100 + i);
  let s = '';
  s += ellipse(x + w / 2, y + h * 0.5, w * 0.78, h * 0.68, { fill: '#ffb347', opacity: 0.22, filter: D.blur(9) });
  // outer frame
  const fd = archD(x - 5, y - 5, w + 10, h + 8, ah + 5);
  s += painted(D, fd, '#c8873e', { paint: { k: 0.45, seed: 7 + i, shA: 0.5 }, hi: 0.35, strokes: strokes(x + w / 2, y + h / 2, w * 0.6, h * 0.6, '#c8873e', { n: 30, len: 9, w: 0.9, seed: i, a: 0.45, dir: 1.57 }) });
  // warm glass and a hint of the room behind it
  const od = archD(x, y, w, h, ah);
  const clip = D.clip(path(od));
  s += path(od, { fill: D.rg([[0, '#fff3c4'], [0.45, '#ffc861'], [1, '#c0641f']], { cx: 0.5, cy: 0.62, r: 0.75 }) });
  s += g({ clipPath: clip }, path(`M${x + w / 2} ${y}V${y + h}`, { stroke: '#d0802a', strokeWidth: 2, opacity: 0.35 }), ellipse(x + w / 2, y + h, w * 0.5, h * 0.25, { fill: '#8a3a12', opacity: 0.3, filter: D.blur(4) }));
  // sill and its heap of snow
  s += painted(D, `M${x - 9} ${y + h + 1}h${w + 18}v6h${-(w + 18)}Z`, '#8a5228', { paint: { k: 0.3, seed: 30 + i }, hi: 0.3 });
  const sn = smooth([[x - 10, y + h + 3], [x - 6, y + h - 2], [x + w * 0.25, y + h - 4 - r() * 2], [x + w * 0.6, y + h - 3.5 - r() * 2], [x + w + 6, y + h - 2], [x + w + 10, y + h + 3], [x + w * 0.5, y + h + 5]], true);
  s += painted(D, sn, '#f2f6ff', { paint: { k: 0.35, rim: '#ffffff', rimA: 0.9, sh: '#4a64b8', shA: 0.4, seed: 50 + i }, hi: 0.2, lo: 0.12 });
  // snow on the arch
  const cap = `M${x - 6} ${y + ah + 2}A${w / 2 + 6} ${ah + 7} 0 0 1 ${x + w + 6} ${y + ah + 2}Q${x + w + 2} ${y + ah - 6} ${x + w * 0.72} ${y - 4}Q${x + w / 2} ${y - 7} ${x + w * 0.28} ${y - 4}Q${x - 2} ${y + ah - 6} ${x - 6} ${y + ah + 2}Z`;
  s += painted(D, cap, '#f4f7ff', { paint: { k: 0.3, rim: '#ffffff', rimA: 0.9, sh: '#4a64b8', shA: 0.35, seed: 70 + i }, hi: 0.2, lo: 0.1 });
  return s;
}

function wreath(D, cx, cy, R) {
  const r = rng(77); let s = '';
  s += circle(cx, cy, R, { fill: 'none', stroke: '#173f2c', strokeWidth: 16 });
  for (let i = 0; i < 260; i++) {
    const a = r() * TAU, q = R + (r() - 0.5) * 14, x = cx + Math.cos(a) * q, y = cy + Math.sin(a) * q, t = a + Math.PI / 2 + (r() - 0.5) * 1.2, L = 4 + r() * 4;
    s += path(`M${f(x)} ${f(y)}l${f(Math.cos(t) * L)} ${f(Math.sin(t) * L)}`, { stroke: mix('#1f5a3a', '#4f9a5a', r()), strokeWidth: 1.6, strokeLinecap: 'round' });
  }
  for (let i = 0; i < 9; i++) {
    const a = i / 9 * TAU + 0.3, x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R;
    if (Math.sin(a) > 0.75) continue;
    [[0, 0], [3.4, 1.4], [0.8, 3.6]].forEach(([dx, dy]) => { s += circle(x + dx, y + dy, 2.5, { fill: D.rg([[0, '#ff8a8a'], [0.4, '#d8243a'], [1, '#7a0f1e']], { cx: 0.35, cy: 0.3 }) }); });
  }
  [0.9, 2.6, 4.4].forEach(a => { const x = cx + Math.cos(a) * R, y = cy + Math.sin(a) * R; s += ellipse(x, y, 3.4, 5, { fill: '#7a4a2a', transform: `rotate(${f(a * 57)} ${f(x)} ${f(y)})` }); });
  // red bow with ribbon tails
  const by = cy + R + 2;
  s += path(`M${cx - 2} ${by}q-6 14 -10 24l5 -2 3 4q4 -12 5 -24z`, { fill: '#b8202f' }) + path(`M${cx + 2} ${by}q6 14 10 24l-5 -2 -3 4q-4 -12 -5 -24z`, { fill: '#a81c2a' });
  s += path(`M${cx} ${by}q-16 -14 -18 0q2 12 18 0z`, { fill: '#d42a3a' }) + path(`M${cx} ${by}q16 -14 18 0q-2 12 -18 0z`, { fill: '#c82434' }) + ellipse(cx, by, 4.2, 4, { fill: '#e8404e' });
  return g({ filter: D.paint({ k: 0.5, seed: 78, rim: '#ffe6b0', rimA: 0.45 }) }, s);
}

function gift(D, x, base, w, h, col, rib, seed) {
  const d = `M${x - w / 2} ${base}V${base - h}H${x + w / 2}V${base}Z`;
  let s = painted(D, d, col, { paint: { k: 0.4, seed }, inner: rect(x - w * 0.09, base - h, w * 0.18, h, { fill: rib }) + rect(x - w / 2, base - h * 0.55, w, h * 0.13, { fill: rib }) + rect(x - w / 2, base - h, w, h, { fill: D.lg([[0, '#000', 0], [1, '#000', 0.25]], 0, 0, 1, 0) }) });
  s += painted(D, `M${x - w / 2 - 2} ${base - h}v-6h${w + 4}v6Z`, tint(col, 0.08), { paint: { k: 0.25, seed: seed + 1 }, inner: rect(x - w * 0.09, base - h - 6, w * 0.18, 6, { fill: rib }) });
  s += g({ filter: D.paint({ k: 0.25, seed: seed + 2 }) }, path(`M${x} ${base - h - 6}q-12 -12 -12 -2q2 6 12 2z`, { fill: rib }), path(`M${x} ${base - h - 6}q12 -12 12 -2q-2 6 -12 2z`, { fill: shade(rib, 0.1) }));
  return s;
}

function lantern(D, x, y) {
  return g({ filter: D.paint({ k: 0.25, seed: 91, rim: '#ffe7b0' }) },
    path(`M${x} ${y - 30}v-6`, { stroke: '#2a2228', strokeWidth: 1.6 }), path(`M${x - 6} ${y - 34}a6 6 0 0 1 12 0`, { fill: 'none', stroke: '#2a2228', strokeWidth: 1.6 }),
    path(`M${x - 10} ${y - 24}L${x} ${y - 32}L${x + 10} ${y - 24}Z`, { fill: '#2a2430' }),
    rect(x - 8, y - 24, 16, 20, { fill: D.rg([[0, '#fff7d0'], [0.5, '#ffc455'], [1, '#d77a20']]) }),
    path(`M${x - 8} ${y - 24}v20M${x + 8} ${y - 24}v20M${x} ${y - 24}v20`, { stroke: '#2a2430', strokeWidth: 1.6 }),
    rect(x - 10, y - 5, 20, 4, { fill: '#2a2430', rx: 1 }));
}

export function houseSheet() {
  const D = new Defs('h'), r = rng(9);
  const lights = [], twinkle = [], glows = [];
  let s = '';
  // sky
  s += rect(0, 0, HW, HH, { fill: D.lg([[0, '#070d2e'], [0.25, '#0f1d52'], [0.5, '#1e3474'], [0.75, '#2c4a8a'], [1, '#2c4a8a']]) });
  s += ellipse(195, 520, 330, 260, { fill: '#5a74c0', opacity: 0.25, filter: D.blur(40) });
  let stars = '';
  for (let i = 0; i < 150; i++) {
    const x = r() * HW, y = r() * 560, a = 0.25 + r() * 0.7, rr = 0.35 + r() * 0.9;
    stars += circle(x, y, rr, { fill: r() < 0.2 ? '#ffe9b8' : '#ffffff', opacity: f(a) });
  }
  s += g({ filter: D.glow(0.8, 0.9) }, stars);
  for (let i = 0; i < 12; i++) twinkle.push([f(10 + r() * 370), f(10 + r() * 330), f(1 + r() * 1.4), f(r() * TAU)]);
  // moon
  s += circle(334, 72, 44, { fill: '#fff2c8', opacity: 0.18, filter: D.blur(14) });
  s += painted(D, blob(334, 72, 19, 19, 3, 0.01), '#fff4d8', { paint: { k: 0.4, sh: '#c8a878', shA: 0.25, rim: '#ffffff', seed: 2 }, hi: 0.2, lo: 0.12, inner: circle(340, 66, 4, { fill: '#e8d6aa', opacity: 0.5 }) + circle(328, 80, 3, { fill: '#e8d6aa', opacity: 0.45 }) });
  s += aurora(D);
  // distant hills and the forest behind the house
  s += path(smooth([[-20, 600], [40, 520], [110, 548], [180, 500], [260, 540], [330, 505], [410, 560], [410, 900], [-20, 900]], false) + 'Z', { fill: D.lg([[0, '#3a5698'], [1, '#22346a']]), filter: D.rough({ k: 2, wob: 3 }) });
  let back = '';
  [[-12, 880, 300, 46, 3], [24, 870, 230, 36, 4], [370, 880, 320, 48, 5], [404, 860, 240, 38, 6], [350, 870, 200, 32, 7]].forEach(([x, b, h, w, sd]) => { back += pine(D, x, b, h, w, sd, '#14332f', true); });
  s += g({ filter: D.paint({ k: 1, seed: 8, shA: 0.3, rimA: 0.2 }) }, back);
  // chimney, behind the roof
  let ch = '';
  ch += rect(296, 190, 34, 80, { fill: D.lg([[0, '#8a8a9e'], [1, '#4e4e66']], 0, 0, 1, 0) });
  for (let y = 192, k = 0; y < 268; y += 9, k++) for (let x = 296 + (k % 2) * 6 - 6; x < 330; x += 12)
    ch += rect(Math.max(296, x), y, Math.min(11, 330 - Math.max(296, x)), 8, { rx: 2.5, fill: mix('#9a9ab0', '#6a6a84', r()), stroke: '#3a3a50', strokeWidth: 0.6 });
  ch += rect(292, 184, 42, 9, { rx: 2, fill: '#5a5a72' });
  ch += path(smooth([[289, 186], [296, 176], [312, 172], [328, 175], [337, 186], [312, 190]], true), { fill: '#f2f6ff' });
  s += g({ filter: D.paint({ k: 0.5, seed: 9, rim: '#c8d8ff' }) }, ch);
  // the wall
  s += logWall(D);
  s += logEnds(D);
  // the roof edge: dark barge boards under a deep blanket of snow
  s += painted(D, 'M-16 334L195 144L406 334L406 354L195 166L-16 354Z', '#5a3220', { paint: { k: 0.6, seed: 12, shA: 0.5 }, hi: 0.25, strokes: strokes(195, 250, 220, 100, '#5a3220', { n: 120, len: 14, w: 1, seed: 3, a: 0.4 }) });
  const sl = [], sr = [];
  for (let i = 0; i <= 22; i++) {
    const u = i / 22, x = -24 + u * 219, y = 340 - u * 197;
    sl.push([x - 10 - r() * 5, y - 22 - r() * 10]);
    const x2 = 414 - u * 219; sr.push([x2 + 10 + r() * 5, y - 22 - r() * 10]);
  }
  const snowTop = [...sl, [195, 118], ...sr.reverse()];
  const snowD = smooth([[-28, 352], ...snowTop, [418, 352], [412, 338], [195, 148], [-22, 338]], true, 0.8);
  s += painted(D, snowD, '#f3f7ff', { paint: { k: 0.8, rim: '#ffffff', rimA: 0.9, sh: '#3f5aa8', shA: 0.45, seed: 13 }, hi: 0.25, lo: 0.18, strokes: strokes(195, 240, 220, 120, '#dfe7fa', { n: 120, len: 5, w: 3, seed: 4, a: 0.4 }) });
  // icicles and string lights hang from the underside
  let ice = '', wire = '', bulbs = '';
  const under = u => u < 0.5 ? [-16 + u * 2 * 211, 354 - u * 2 * 188] : [195 + (u - 0.5) * 2 * 211, 166 + (u - 0.5) * 2 * 188];
  for (let i = 0; i < 46; i++) {
    const u = (i + 0.5) / 46, [x, y] = under(u), L = 5 + r() * 11;
    if (Math.abs(u - 0.5) < 0.03) continue;
    ice += path(`M${f(x - 2.2)} ${f(y - 1)}L${f(x + 0.4)} ${f(y + L)}L${f(x + 2.2)} ${f(y - 1)}Z`, { fill: D.lg([[0, '#ffffff'], [1, '#a9c4f2', 0.6]]) });
  }
  const N = 26, hook = [];
  for (let i = 0; i <= N; i++) hook.push(under(i / N));
  for (let i = 0; i < N; i++) {
    const [x0, y0] = hook[i], [x1, y1] = hook[i + 1], mx = (x0 + x1) / 2, my = (y0 + y1) / 2 + 7;
    wire += path(`M${f(x0)} ${f(y0 + 1)}Q${f(mx)} ${f(my + 4)} ${f(x1)} ${f(y1 + 1)}`, { stroke: '#1d2a22', strokeWidth: 1.1, fill: 'none' });
    const hue = HUES[i % HUES.length], bx = mx, by = my + 4;
    const col = `hsl(${hue},85%,62%)`;
    bulbs += rect(bx - 1.6, by - 3, 3.2, 3, { fill: '#2a3a30' }) + ellipse(bx, by + 3, 2.8, 4.2, { fill: col }) + ellipse(bx - 0.9, by + 1.6, 0.9, 1.4, { fill: '#ffffff', opacity: 0.8 });
    lights.push([f(bx), f(by + 3), hue]);
  }
  s += g({ filter: D.rough({ k: 0.3 }) }, ice) + wire + g({ filter: D.glow(1.2, 0.9) }, bulbs);
  // windows
  for (let i = 0; i < 24; i++) s += windowArt(D, winBox(i), i);
  // the round attic window in its wreath
  const ax = 195, ay = 242;
  s += ellipse(ax, ay, 44, 44, { fill: '#ffb347', opacity: 0.25, filter: D.blur(10) });
  s += painted(D, blob(ax, ay, 27, 27, 4, 0.01), '#c8873e', { paint: { k: 0.4, seed: 20 } });
  s += circle(ax, ay, 21, { fill: D.rg([[0, '#fff3c4'], [0.5, '#ffc861'], [1, '#c0641f']]) }) + path(`M${ax - 21} ${ay}h42M${ax} ${ay - 21}v42`, { stroke: '#8a5228', strokeWidth: 3.2 });
  s += wreath(D, ax, ay, 33);
  glows.push([ax, ay, 60]);
  // stone footing and the snowy ground
  let stones = '';
  for (let x = 16; x < 376; x += 15) stones += ellipse(x + r() * 3, 840 + r() * 3, 8.5, 6, { fill: mix('#8c90a8', '#5f6480', r()) });
  s += g({ filter: D.paint({ k: 0.3, seed: 22, rim: '#c8d8ff' }) }, stones);
  const gnd = smooth([[-20, 880], [-20, 852], [40, 846], [110, 852], [195, 843], [280, 850], [350, 845], [410, 852], [410, 880]], false) + 'L410 970L-20 970Z';
  s += painted(D, gnd, '#eef3ff', { paint: { k: 1.4, rim: '#ffffff', rimA: 0.9, sh: '#3f5aa8', shA: 0.35, seed: 23 }, hi: 0.15, lo: 0.2, cx: 0.5, cy: 0.1, inner: ellipse(195, 852, 190, 10, { fill: '#7a8fd0', opacity: 0.5, filter: D.blur(5) }) + ellipse(195, 900, 150, 26, { fill: '#ffd28a', opacity: 0.18, filter: D.blur(14) }) });
  let prints = '';
  for (let i = 0; i < 9; i++) { const x = 92 + i * 13, y = 948 - i * 3.6 + (i % 2) * 5; prints += ellipse(x, y, 3, 1.8, { fill: '#8aa0dc', opacity: 0.45 }); }
  s += prints;
  // front pines in the corners
  s += g({ filter: D.paint({ k: 0.8, seed: 24, rim: '#bfe0d0', rimA: 0.35 }) }, pine(D, -2, 968, 150, 34, 30, '#1c4a40'), pine(D, 394, 968, 170, 38, 31, '#1c4a40'));
  // the snowman, the gifts, the cat on top and the dog
  s += g({ transform: 'translate(66 935) scale(0.56)' }, poseSVG('snowman', { aR: 2.3, aL: 0.5, hr: 0.06, sm: 1 }));
  s += gift(D, 168, 942, 40, 30, '#c8303f', '#f4c95d', 40) + gift(D, 208, 944, 34, 24, '#2f8a55', '#f2e6c8', 44) + gift(D, 190, 913, 28, 20, '#4a7ac8', '#f4c95d', 48);
  s += g({ transform: 'translate(192 895) scale(0.36)' }, poseSVG('kitten', { hr: -0.12, tail: 0.6, lx: -0.4, sm: 1 }));
  s += g({ transform: 'translate(292 944) scale(0.5)' }, poseSVG('puppy', { hr: 0.1, lx: -0.5, tail: 0.8, sm: 1, aR: 0.5 }));
  s += lantern(D, 352, 948); glows.push([352, 934, 50]);
  // falling-snow haze at the very top so the title reads
  s += rect(0, 0, HW, 140, { fill: D.lg([[0, '#050a24', 0.55], [1, '#050a24', 0]]) });
  return { kind: 'image', file: 'house.webp', q: 0.8, scale: 2.4, svg: svgDoc([0, 0, HW, HH], 2.4, D, s), meta: { win: WIN, lights, twinkle, glows, smoke: [312, 172] } };
}

// ---------------------------------------------------------------- shutters
const DOOR_DECOR = ['holly', 'star', 'heart', 'wreath', 'bell', 'flake'];

function decor(D, kind, cx, cy) {
  switch (kind) {
    case 'holly': return g({ filter: D.paint({ k: 0.12, seed: 3 }) }, ellipse(cx - 5, cy, 5.5, 2.6, { fill: '#2f7a45', transform: `rotate(-20 ${cx - 5} ${cy})` }), ellipse(cx + 5, cy, 5.5, 2.6, { fill: '#2a6e3e', transform: `rotate(20 ${cx + 5} ${cy})` }),
      circle(cx - 1.4, cy - 1, 2, { fill: '#d8243a' }), circle(cx + 1.6, cy - 1.4, 2, { fill: '#c81e32' }), circle(cx, cy + 1.2, 2, { fill: '#e02a40' }));
    case 'star': return g({ filter: D.paint({ k: 0.12, seed: 4, rimA: 0.8 }) }, path(`M${cx} ${cy - 7}l2.1 4.6 5 .5-3.8 3.4 1.1 5-4.4-2.6-4.4 2.6 1.1-5-3.8-3.4 5-.5z`, { fill: '#f6d36a' }));
    case 'heart': return g({ filter: D.paint({ k: 0.12, seed: 5 }) }, path(`M${cx} ${cy + 5}C${cx - 9} ${cy - 1} ${cx - 5} ${cy - 8} ${cx} ${cy - 3}C${cx + 5} ${cy - 8} ${cx + 9} ${cy - 1} ${cx} ${cy + 5}Z`, { fill: '#d8304a' }));
    case 'wreath': return g({ filter: D.paint({ k: 0.12, seed: 6 }) }, circle(cx, cy, 5.2, { fill: 'none', stroke: '#2f7a45', strokeWidth: 3 }), circle(cx - 3, cy + 3.6, 1.4, { fill: '#e02a40' }), circle(cx + 3.4, cy - 3, 1.3, { fill: '#e02a40' }),
      path(`M${cx - 3} ${cy + 5.5}l3 -1.5 3 1.5-3 1z`, { fill: '#d8243a' }));
    case 'bell': return g({ filter: D.paint({ k: 0.12, seed: 7, rimA: 0.8 }) }, path(`M${cx - 6} ${cy + 4}Q${cx - 6} ${cy - 7} ${cx} ${cy - 7}Q${cx + 6} ${cy - 7} ${cx + 6} ${cy + 4}Z`, { fill: '#f0c24a' }), circle(cx, cy + 5, 1.8, { fill: '#a06a14' }));
    default: {
      let s = ''; for (let i = 0; i < 3; i++) { const a = i * Math.PI / 3; s += path(`M${f(cx - Math.cos(a) * 6)} ${f(cy - Math.sin(a) * 6)}L${f(cx + Math.cos(a) * 6)} ${f(cy + Math.sin(a) * 6)}`, { stroke: '#fff8e8', strokeWidth: 1.4, strokeLinecap: 'round' }); }
      return g({ opacity: 0.9 }, s);
    }
  }
}

function doorFace(D, v, back) {
  const { w, h, ah } = WIN, od = archD(0, 0, w, h, ah), clip = D.clip(path(od)), r = rng(200 + v + (back ? 50 : 0));
  const base = back ? '#9a6430' : ['#e2a650', '#e8ae58', '#dca04c'][v % 3];
  let planks = '';
  for (let i = 0; i < 3; i++) {
    const x = i * w / 3;
    planks += rect(x, 0, w / 3, h, { fill: D.lg([[0, shade(base, 0.12)], [0.3, tint(base, 0.18)], [0.7, base], [1, shade(base, 0.18)]], 0, 0, 1, 0) });
    planks += strokes(x + w / 6, h / 2, w / 7, h / 2, base, { n: 14, len: 14, w: 0.7, seed: i + v * 3, a: 0.5, dir: 1.57 });
    if (i) planks += rect(x - 0.6, 0, 1.2, h, { fill: shade(base, 0.55) });
    if (r() < 0.5) planks += ellipse(x + w / 6 + (r() - 0.5) * 8, 20 + r() * 40, 1.6, 2.6, { fill: shade(base, 0.4) });
  }
  if (back) planks += path(`M4 ${h - 14}L${w - 4} ${ah + 12}`, { stroke: shade(base, 0.25), strokeWidth: 8 }) + rect(0, ah + 6, w, 7, { fill: shade(base, 0.15) }) + rect(0, h - 18, w, 7, { fill: shade(base, 0.15) });
  // bevelled edge: dark rim, lit top-left
  const edge = path(od, { fill: 'none', stroke: shade(base, 0.5), strokeWidth: 3.5 }) + path(archD(1.5, 1.5, w - 3, h - 3, ah - 1.5), { fill: 'none', stroke: tint(base, 0.45), strokeWidth: 1, opacity: 0.7 });
  let hw = '';
  if (!back) {
    [h * 0.34, h * 0.8].forEach(y => {
      hw += path(`M-1 ${y - 3}H${w * 0.5}q5 3 0 6H-1Z`, { fill: '#33282a' }) + [6, 16, 26].map(x => circle(x, y, 1.2, { fill: '#7a6a66' })).join('');
    });
    hw += circle(w * 0.86, h * 0.6, 3.2, { fill: D.rg([[0, '#fff3b0'], [0.5, '#e0b040'], [1, '#7a5410']], { cx: 0.35, cy: 0.3 }) });
    // the number plaque; the number itself is live text in the game
    hw += rect(w / 2 - 15, h * 0.47 - 11, 30, 22, { rx: 6, fill: '#3a2414', opacity: 0.35, transform: 'translate(0.8 1.4)' });
    hw += rect(w / 2 - 15, h * 0.47 - 11, 30, 22, { rx: 6, fill: D.lg([[0, '#fff8e4'], [1, '#f0dcb0']]), stroke: '#b8862a', strokeWidth: 1.6 });
    hw += decor(D, DOOR_DECOR[v], w / 2, ah * 0.62);
  }
  return g({ filter: D.paint({ k: 0.3, seed: 300 + v, shA: 0.3, rimA: 0.35, wob: 0.6 }) }, g({ clipPath: clip }, planks), edge) + g({ filter: D.rough({ k: 0.2, wob: 0.5 }) }, hw);
}

export function doorSheet() {
  const items = [];
  const one = (id, v, back) => { const D = new Defs(id); const body = doorFace(D, v, back); return { id, box: [-2, -2, WIN.w + 2, WIN.h + 2], scale: 3.6, svg: svgDoc([-2, -2, WIN.w + 2, WIN.h + 2], 3.6, D, body) }; };
  DOOR_DECOR.forEach((_, v) => items.push(one('door' + v, v, false)));
  items.push(one('back', 0, true));
  return { kind: 'atlas', file: 'doors.webp', q: 0.86, items, meta: { variants: DOOR_DECOR.length, pad: 2 } };
}
