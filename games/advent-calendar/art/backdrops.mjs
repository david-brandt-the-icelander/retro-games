// What you see through each opened window behind the friend: snowy nights,
// aurora, forests, cosy rooms with fires and trees, a kitchen, a workshop, a
// burrow. Kept a little soft so the friend in front stands out. The centre
// (where the friend stands) is left quiet.
import { Defs, svgDoc, g, path, ellipse, circle, rect, blob, smooth, painted, strokes, spot, mix, tint, shade, rng, TAU } from './paint.mjs';
import { CW, CH, ARCH } from './common.mjs';

const f = n => +n.toFixed(2);
const HUES = [0, 42, 130, 205, 320];

// ------------------------------------------------------------ outdoors
const SKIES = {
  night: ['#0b1440', '#1d2f6e', '#3a5596'],
  aurora: ['#081236', '#16306a', '#2d5a8c'],
  ice: ['#16305e', '#3f6fa6', '#9cc6e6'],
  day: ['#6a9ad8', '#a8c8ee', '#e6f0fb'],
  dawn: ['#6e74c4', '#e6a0b8', '#ffd9b0'],
  dusk: ['#1a1d54', '#7a4f8e', '#f2a86a'],
  fog: ['#2a2558', '#4a4a86', '#7a7aa8'],
};

function sky(D, kind, o) {
  const [a, b, c] = SKIES[kind], r = rng(o.seed || 3);
  let s = rect(0, 0, CW, CH, { fill: D.lg([[0, a], [0.55, b], [0.9, c]]) });
  if (kind !== 'day' && kind !== 'dawn') {
    let st = '';
    for (let i = 0; i < 90; i++) st += circle(36 + r() * 288, 56 + r() * 330, 0.4 + r() * 1.1, { fill: '#fff', opacity: f(0.2 + r() * 0.7) });
    s += g({ filter: D.glow(0.8, 0.9) }, st);
  }
  if (o.aurora) {
    [[250, 0.02, 1.0, '#5cf2b4', 0.7, 120], [205, 0.026, 2.5, '#9b7bff', 0.4, 90]].forEach(([y0, fr, ph, col, al, h]) => {
      const pts = []; for (let x = 0; x <= CW + 20; x += 12) pts.push([x, y0 + Math.sin(x * fr + ph) * 26]);
      const top = pts.map(([x, y]) => [x + 10, y - h]).reverse();
      s += g({ style: 'mix-blend-mode:screen' }, path(smooth(pts) + 'L' + smooth(top).slice(1) + 'Z', { fill: D.lg([[0, col, 0], [0.7, col, al * 0.6], [0.92, tint(col, 0.4), al], [1, col, 0]]), filter: D.blur(6) }));
    });
  }
  if (o.moon) {
    const [mx, my, mr] = o.moon;
    s += circle(mx, my, mr * 2.6, { fill: '#fff2c8', opacity: 0.2, filter: D.blur(mr) });
    s += painted(D, blob(mx, my, mr, mr, 2, 0.01), '#fff4d8', { paint: { k: 0.5, sh: '#c8a878', shA: 0.25, rim: '#fff', seed: 3 }, hi: 0.2, lo: 0.12 });
  }
  if (o.sun) s += circle(o.sun[0], o.sun[1], 70, { fill: '#fff0c8', opacity: 0.55, filter: D.blur(30) }) + circle(o.sun[0], o.sun[1], 22, { fill: '#fff6dc', opacity: 0.9, filter: D.blur(4) });
  return s;
}

function hills(D, o) {
  const r = rng(o.seed || 5);
  let s = '';
  const layers = [[430, '#7d93cc', 0.7], [470, '#a8b8e2', 0.85], [520, '#d8e2f6', 1]];
  layers.forEach(([y, col, a], i) => {
    const pts = [[-10, y + 30]];
    for (let x = 0; x <= CW + 10; x += 45) pts.push([x, y + Math.sin(x * 0.02 + i * 2 + (o.seed || 0)) * 22 + r() * 10]);
    const d = smooth(pts) + `L${CW + 10} ${CH}L-10 ${CH}Z`;
    s += path(d, { fill: D.lg([[0, o.tone ? mix(col, o.tone, 0.3) : col], [1, shade(col, 0.15)]]), opacity: a, filter: D.rough({ k: 2, wob: 3, grain: 0.1, seed: i }) });
    if (o.pines && i < 2) {
      let p = '';
      for (let k = 0; k < 9; k++) { const x = 20 + r() * 320; if (Math.abs(x - 180) < 60 && i > 0) continue; p += smallPine(x, y + 10 + r() * 10, 40 + r() * 50 - i * 6, i ? '#2a4e58' : '#24405a'); }
      s += g({ opacity: 0.85 - i * 0.1, filter: D.blur(0.8 + (1 - i) * 0.6) }, p);
    }
  });
  return s;
}

function smallPine(x, base, h, col) {
  let s = '';
  for (let i = 0; i < 4; i++) {
    const u = i / 4, y = base - h * u * 0.85, w = h * 0.36 * (1 - u * 0.75);
    s += path(`M${f(x - w)} ${f(y)}L${f(x)} ${f(y - h * 0.4)}L${f(x + w)} ${f(y)}Z`, { fill: col }) + path(`M${f(x - w * 0.7)} ${f(y - 2)}L${f(x)} ${f(y - h * 0.36)}L${f(x - w * 0.1)} ${f(y - 4)}Z`, { fill: '#e8eefc', opacity: 0.6 });
  }
  return s;
}

function bigPines(D, o) {
  let s = '';
  (o.pineAt || [[46, 600, 300], [318, 600, 330]]).forEach(([x, b, h], i) => {
    for (let k = 0; k < 7; k++) {
      const u = k / 7, y = b - h * u * 0.9, w = h * 0.3 * (1 - u * 0.8), th = h / 7 * 1.7;
      s += path(`M${f(x - w)} ${f(y)}Q${f(x - w * 0.4)} ${f(y - th * 0.35)} ${f(x)} ${f(y - th)}Q${f(x + w * 0.4)} ${f(y - th * 0.35)} ${f(x + w)} ${f(y)}Q${f(x)} ${f(y - th * 0.18)} ${f(x - w)} ${f(y)}Z`, { fill: D.lg([[0, '#2a5a50'], [1, '#0f2e2c']], 0, 0, 1, 0) });
      s += path(`M${f(x - w * 0.9)} ${f(y - 2)}Q${f(x - w * 0.4)} ${f(y - th * 0.4)} ${f(x)} ${f(y - th * 0.8)}Q${f(x - w * 0.2)} ${f(y - th * 0.3)} ${f(x - w * 0.9)} ${f(y - 2)}Z`, { fill: '#eef3ff', opacity: 0.92 });
    }
  });
  return g({ filter: D.paint({ k: 1.2, seed: 7, rim: '#cfe8ff', rimA: 0.3 }) }, s);
}

function trunks(D, o) {
  const r = rng(9); let s = '';
  [[60, 26], [118, 14], [252, 16], [308, 30], [210, 9], [150, 8]].forEach(([x, w], i) => {
    const far = w < 12, col = far ? '#3a3a6a' : '#4a3048';
    s += path(`M${x - w / 2} 640L${x - w * 0.4} 0H${x + w * 0.4}L${x + w / 2} 640Z`, { fill: D.lg([[0, tint(col, 0.15)], [0.5, col], [1, shade(col, 0.4)]], 0, 0, 1, 0), opacity: far ? 0.6 : 1, filter: far ? D.blur(1.4) : null });
    if (!far) for (let k = 0; k < 6; k++) s += path(`M${x - w * 0.42} ${120 + k * 80 + r() * 30}q${w * 0.4} 8 ${w * 0.84} 0`, { stroke: '#f2f6ff', strokeWidth: 3, fill: 'none', opacity: 0.6, strokeLinecap: 'round' });
  });
  return g({ filter: D.rough({ k: 1.5, wob: 2, seed: 4 }) }, s);
}

function iceberg(D) {
  return g({ filter: D.paint({ k: 1.4, rim: '#ffffff', sh: '#2f5a9a', shA: 0.4, seed: 12 }) },
    path('M10 470L50 360L92 330L120 400L150 470Z', { fill: D.lg([[0, '#f4fbff'], [1, '#9cc4ea']], 0, 0, 1, 1) }),
    path('M230 470L262 380L300 350L340 420L350 470Z', { fill: D.lg([[0, '#eaf6ff'], [1, '#8ab4e2']], 0, 0, 1, 1) }));
}

// ------------------------------------------------------------ indoors
const PATTERNS = {
  stripes: (c) => { let s = ''; for (let x = 0; x < CW; x += 24) s += rect(x, 0, 12, CH, { fill: c, opacity: 0.18 }); return s; },
  dots: (c) => { let s = ''; for (let y = 10, k = 0; y < CH; y += 30, k++) for (let x = (k % 2) * 15; x < CW; x += 30) s += circle(x, y, 3.2, { fill: c, opacity: 0.25 }); return s; },
  diamonds: (c) => { let s = ''; for (let y = 0, k = 0; y < CH; y += 36, k++) for (let x = (k % 2) * 18; x < CW; x += 36) s += path(`M${x} ${y - 7}l6 7-6 7-6-7z`, { fill: c, opacity: 0.22 }); return s; },
  hearts: (c) => { let s = ''; for (let y = 14, k = 0; y < CH; y += 40, k++) for (let x = (k % 2) * 20; x < CW; x += 40) s += path(`M${x} ${y + 4}c-7-5-5-11 0-7c5-4 7 2 0 7z`, { fill: c, opacity: 0.22 }); return s; },
  stars: (c) => { let s = ''; for (let y = 14, k = 0; y < CH; y += 38, k++) for (let x = (k % 2) * 19; x < CW; x += 38) s += path(`M${x} ${y - 5}l1.5 3.4 3.6.3-2.8 2.4.9 3.6-3.2-1.9-3.2 1.9.9-3.6-2.8-2.4 3.6-.3z`, { fill: c, opacity: 0.3 }); return s; },
  tiles: (c) => { let s = ''; for (let y = 0, k = 0; y < CH; y += 22, k++) for (let x = (k % 2) * 11; x < CW; x += 22) s += rect(x + 1, y + 1, 20, 20, { rx: 2, fill: c, opacity: 0.16 }); return s; },
};

function room(D, o) {
  const wall = o.wall, r = rng(o.seed || 7);
  let s = rect(0, 0, CW, CH, { fill: D.lg([[0, shade(wall, 0.18)], [0.5, wall], [1, shade(wall, 0.12)]]) });
  if (o.pattern) s += g({ filter: D.rough({ k: 1, wob: 1 }) }, PATTERNS[o.pattern](o.patCol || tint(wall, 0.5)));
  // wainscot and floor
  s += painted(D, `M0 ${o.dado || 470}H${CW}V${CH}H0Z`, o.wood || '#9a5f32', { paint: { k: 1.2, seed: 8, shA: 0.35 }, hi: 0.2, lo: 0.3, inner: [60, 130, 230, 300].map(x => rect(x - 26, (o.dado || 470) + 18, 52, 90, { rx: 4, fill: 'none', stroke: shade(o.wood || '#9a5f32', 0.3), strokeWidth: 2.5 })).join('') + rect(0, (o.dado || 470) - 4, CW, 8, { fill: tint(o.wood || '#9a5f32', 0.25) }) });
  return s;
}

function nightWindow(D, x, y, w, h) {
  const d = `M${x} ${y + h}V${y + w / 2}A${w / 2} ${w / 2} 0 0 1 ${x + w} ${y + w / 2}V${y + h}Z`, clip = D.clip(path(d));
  let view = rect(x, y, w, h, { fill: D.lg([[0, '#0f1c52'], [1, '#3a5a9a']]) });
  const r = rng(x | 0);
  for (let i = 0; i < 18; i++) view += circle(x + r() * w, y + r() * h * 0.7, 0.6 + r(), { fill: '#fff', opacity: 0.8 });
  view += path(`M${x} ${y + h * 0.78}Q${x + w * 0.4} ${y + h * 0.66} ${x + w} ${y + h * 0.74}V${y + h}H${x}Z`, { fill: '#dfe8fb' });
  view += smallPine(x + w * 0.3, y + h * 0.76, h * 0.34, '#1e3c4a') + smallPine(x + w * 0.72, y + h * 0.74, h * 0.26, '#1e3c4a');
  return g({ filter: D.paint({ k: 0.8, seed: 14, shA: 0.3 }) },
    path(`M${x - 8} ${y + h + 6}V${y + w / 2}A${w / 2 + 8} ${w / 2 + 8} 0 0 1 ${x + w + 8} ${y + w / 2}V${y + h + 6}Z`, { fill: '#e8dcc4' }),
    g({ clipPath: clip }, view), path(`M${x + w / 2} ${y}V${y + h}M${x} ${y + h * 0.5}H${x + w}`, { stroke: '#e8dcc4', strokeWidth: 4 }),
    path(`M${x} ${y + h - 4}Q${x + w / 2} ${y + h - 14} ${x + w} ${y + h - 4}V${y + h}H${x}Z`, { fill: '#f6f9ff' }),
    rect(x - 12, y + h + 4, w + 24, 8, { fill: '#c8b89a' }));
}

function fireplace(D, x, y) {
  return g({ filter: D.paint({ k: 1, seed: 15, rim: '#ffe0a0', rimA: 0.6 }) },
    rect(x - 70, y, 140, 190, { fill: D.lg([[0, '#b8a090'], [1, '#7a6458']]) }),
    path(`M${x - 46} ${y + 190}V${y + 70}Q${x} ${y + 40} ${x + 46} ${y + 70}V${y + 190}Z`, { fill: '#1a0e10' }),
    ellipse(x, y + 160, 50, 40, { fill: '#ff8a2a', opacity: 0.85, filter: D.blur(10) }),
    path(`M${x - 26} ${y + 180}Q${x - 20} ${y + 120} ${x - 6} ${y + 100}Q${x - 4} ${y + 140} ${x + 4} ${y + 110}Q${x + 14} ${y + 140} ${x + 22} ${y + 118}Q${x + 30} ${y + 160} ${x + 26} ${y + 180}Z`, { fill: '#ffb84a', filter: D.blur(2) }),
    path(`M${x - 12} ${y + 180}Q${x - 6} ${y + 150} ${x} ${y + 138}Q${x + 8} ${y + 160} ${x + 12} ${y + 180}Z`, { fill: '#fff0b0', filter: D.blur(1.5) }),
    rect(x - 40, y + 176, 80, 10, { rx: 5, fill: '#5a321c' }),
    rect(x - 84, y - 14, 168, 18, { rx: 3, fill: '#8a5228' }),
    [-40, 0, 40].map((dx, i) => path(`M${x + dx - 9} ${y + 4}v26q0 10 10 10h8l4 -8h-6v-28z`, { fill: ['#c8283d', '#2f8a55', '#c8283d'][i] }) + rect(x + dx - 10, y + 4, 20, 7, { fill: '#f8f4ea' })).join(''));
}

function tree(D, x, base, h, lights) {
  const r = rng(21); let s = '';
  for (let i = 0; i < 6; i++) {
    const u = i / 6, y = base - h * u * 0.88, w = h * 0.36 * (1 - u * 0.8), th = h / 6 * 1.6;
    s += path(`M${f(x - w)} ${f(y)}Q${f(x - w * 0.35)} ${f(y - th * 0.4)} ${f(x)} ${f(y - th)}Q${f(x + w * 0.35)} ${f(y - th * 0.4)} ${f(x + w)} ${f(y)}Q${f(x)} ${f(y + 8)} ${f(x - w)} ${f(y)}Z`, { fill: D.lg([[0, '#3f8a5c'], [0.6, '#1f5a3e'], [1, '#123a2c']], 0, 0, 1, 0) });
  }
  let orn = '';
  for (let i = 0; i < 22; i++) {
    const u = r() * 0.85, y = base - h * u, w = h * 0.34 * (1 - u * 0.85), xx = x + (r() - 0.5) * 2 * w * 0.85, hue = HUES[i % 5];
    if (i % 2) orn += circle(xx, y, 3.2, { fill: `hsl(${hue},75%,55%)` }) + circle(xx - 1, y - 1, 1, { fill: '#fff', opacity: 0.7 });
    else { orn += circle(xx, y, 2.2, { fill: `hsl(${hue},95%,75%)` }); lights.push([f(xx), f(y), hue]); }
  }
  s += rect(x - 8, base - 2, 16, 20, { fill: '#5a321c' });
  const star = smooth([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => { const a = -Math.PI / 2 + i * Math.PI / 5, q = i % 2 ? 5 : 12; return [x + Math.cos(a) * q, base - h - 6 + Math.sin(a) * q]; }), true, 0.25);
  lights.push([x, base - h - 6, 50]);
  return g({ filter: D.paint({ k: 1, seed: 22, rim: '#ffe0a0', rimA: 0.4 }) }, s) + g({ filter: D.glow(1.4, 0.8) }, orn, path(star, { fill: '#ffd860' }));
}

function garland(D, y, lights, sag = 46) {
  let s = path(`M20 ${y}Q180 ${y + sag * 2} 340 ${y}`, { stroke: '#1d5a3c', strokeWidth: 14, fill: 'none', strokeLinecap: 'round' });
  const r = rng(y | 0);
  for (let i = 0; i < 140; i++) { const u = r(), x = (1 - u) * (1 - u) * 20 + 2 * (1 - u) * u * 180 + u * u * 340, yy = (1 - u) * (1 - u) * y + 2 * (1 - u) * u * (y + sag * 2) + u * u * y, a = r() * TAU; s += path(`M${f(x)} ${f(yy)}l${f(Math.cos(a) * 7)} ${f(Math.sin(a) * 7)}`, { stroke: mix('#1f5a3a', '#5aa86a', r()), strokeWidth: 2, strokeLinecap: 'round' }); }
  let bulbs = '';
  for (let i = 0; i < 11; i++) { const u = (i + 0.5) / 11, x = (1 - u) * (1 - u) * 20 + 2 * (1 - u) * u * 180 + u * u * 340, yy = (1 - u) * (1 - u) * y + 2 * (1 - u) * u * (y + sag * 2) + u * u * y + 9, hue = HUES[i % 5]; bulbs += ellipse(x, yy, 3, 4.4, { fill: `hsl(${hue},90%,66%)` }); lights.push([f(x), f(yy), hue]); }
  return g({ filter: D.paint({ k: 0.6, seed: 23 }) }, s) + g({ filter: D.glow(1.2, 0.9) }, bulbs);
}

function shelf(D, y, kind) {
  const r = rng(y | 0); let s = painted(D, `M210 ${y}H330V${y + 9}H210Z`, '#8a5228', { paint: { k: 0.4, seed: 30 } });
  for (let i = 0; i < 4; i++) {
    const x = 226 + i * 26;
    if (kind === 'jars') s += painted(D, `M${x - 9} ${y}V${y - 26}Q${x - 9} ${y - 30} ${x} ${y - 30}Q${x + 9} ${y - 30} ${x + 9} ${y - 26}V${y}Z`, ['#e8c48a', '#c86a4a', '#e0a050', '#a8c070'][i], { paint: { k: 0.3, seed: 31 + i, rim: '#ffffff', rimA: 0.7 }, inner: rect(x - 9, y - 32, 18, 6, { fill: '#c8283d' }) + rect(x - 6, y - 18, 12, 9, { fill: '#f8f0dc' }) });
    else if (kind === 'toys') s += [painted(D, `M${x - 9} ${y}V${y - 18}H${x + 9}V${y}Z`, ['#c8283d', '#4a7ac8', '#f4c95d', '#2f8a55'][i], { paint: { k: 0.3, seed: 35 + i } }), painted(D, blob(x, y - 24, 6, 6, i), '#e8b070', { paint: { k: 0.2, seed: 39 + i } })][i % 2];
    else s += painted(D, `M${x - 7} ${y}V${y - 30 - r() * 8}H${x + 7}V${y}Z`, ['#7a2a3a', '#2a5a7a', '#5a7a2a', '#7a5a2a'][i], { paint: { k: 0.3, seed: 43 + i }, inner: rect(x - 7, y - 24, 14, 3, { fill: '#f4c95d' }) });
  }
  return s;
}

function bokeh(D, n, lights, seed, warm = true) {
  const r = rng(seed); let s = '';
  for (let i = 0; i < n; i++) {
    const x = 40 + r() * 280, y = 70 + r() * 300, rr = 6 + r() * 14, hue = warm ? [40, 30, 50, 0][i % 4] : HUES[i % 5];
    if (Math.abs(x - 180) < 70 && y > 300) continue;
    s += circle(x, y, rr, { fill: `hsl(${hue},90%,${warm ? 75 : 70}%)`, opacity: f(0.18 + r() * 0.2) });
    if (i % 3 === 0) lights.push([f(x), f(y), hue]);
  }
  return g({ filter: D.blur(2.4) }, s);
}

// ------------------------------------------------------------ the 24
export const BACKDROPS = [
  /* 1 snowman  */ { out: 'aurora', aurora: 1, moon: [262, 150, 16], hills: { pines: 1 }, snow: 1 },
  /* 2 penguin  */ { out: 'ice', moon: [92, 140, 12], ice: 1, hills: { tone: '#9cc6e6' }, snow: 1 },
  /* 3 fox      */ { out: 'night', trunks: 1, hills: { seed: 3 }, snow: 1, bokehCool: 1 },
  /* 4 bunny    */ { room: { wall: '#9a86d6', pattern: 'stars', patCol: '#fff4d0' }, window: [210, 150, 90, 150], garland: 128, shelf: [118, 'books'] },
  /* 5 hedgehog */ { burrow: 1 },
  /* 6 puppy    */ { room: { wall: '#e0a050', pattern: 'stripes', patCol: '#fff0c8' }, fire: [268, 330], garland: 120 },
  /* 7 kitten   */ { room: { wall: '#2e3a78', pattern: 'diamonds', patCol: '#c8d4ff' }, tree: [86, 600, 300], bokehWarm: 1 },
  /* 8 polar    */ { out: 'day', ice: 1, hills: { pines: 1, tone: '#b8d4ee' }, snow: 1, sun: [270, 150] },
  /* 9 owl      */ { out: 'night', moon: [250, 140, 30], trunks: 1, hills: { seed: 9 }, snow: 1 },
  /* 10 mouse   */ { room: { wall: '#d8857a', pattern: 'dots', patCol: '#fff0e0' }, window: [60, 150, 90, 150], shelf: [210, 'toys'], garland: 124 },
  /* 11 robin   */ { out: 'dawn', sun: [110, 260], branches: 1, hills: { tone: '#f2c8d4' } },
  /* 12 squirrel*/ { room: { wall: '#e8a46a', pattern: 'tiles', patCol: '#fff4e0', wood: '#b86a3a' }, shelf: [150, 'jars'], window: [56, 160, 80, 140] },
  /* 13 lamb    */ { out: 'dawn', sun: [260, 240], hills: { tone: '#e8d0e8', pines: 1 }, fence: 1, snow: 1 },
  /* 14 ginger  */ { room: { wall: '#e8b070', pattern: 'tiles', patCol: '#c8283d', wood: '#a86a3a' }, shelf: [160, 'jars'], oven: 1 },
  /* 15 teddy   */ { room: { wall: '#e09098', pattern: 'hearts', patCol: '#fff0f2' }, shelf: [150, 'toys'], window: [56, 150, 80, 150], bokehWarm: 1 },
  /* 16 elf     */ { room: { wall: '#3f8a66', pattern: 'stripes', patCol: '#d8f0d0', wood: '#8a5228' }, shelf: [140, 'toys'], shelf2: [220, 'toys'], garland: 116 },
  /* 17 rudolph */ { out: 'fog', hills: { pines: 1, tone: '#6a6aa0' }, snow: 1, fog: 1 },
  /* 18 panda   */ { room: { wall: '#c8707a', pattern: 'diamonds', patCol: '#ffe0e4' }, window: [210, 150, 90, 150], fire: [96, 360] },
  /* 19 nut     */ { room: { wall: '#253068', pattern: 'stars', patCol: '#f4c95d' }, tree: [282, 600, 290], bokehWarm: 1, garland: 120 },
  /* 20 husky   */ { out: 'day', hills: { pines: 1 }, pines: 1, snow: 1 },
  /* 21 star    */ { out: 'dusk', hills: { pines: 1, tone: '#c89ab8' } },
  /* 22 cat     */ { out: 'night', moon: [96, 140, 18], village: 1, hills: { seed: 22 }, snow: 1 },
  /* 23 santa   */ { room: { wall: '#c8404c', pattern: 'stripes', patCol: '#ffe0c8' }, fire: [268, 330], garland: 120, bokehWarm: 1 },
  /* 24 finale  */ { room: { wall: '#e8b860', pattern: 'stars', patCol: '#fffbe0' }, tree: [70, 600, 280], tree2: [290, 600, 260], garland: 116, bokehWarm: 1 },
];

function burrow(D) {
  let s = rect(0, 0, CW, CH, { fill: D.rg([[0, '#f0b070'], [0.5, '#a0603a'], [1, '#4a2a1c']], { cx: 0.5, cy: 0.55, r: 0.7 }) });
  const r = rng(5); let roots = '';
  for (let i = 0; i < 9; i++) { const x = 40 + r() * 280; roots += path(`M${f(x)} 50Q${f(x + (r() - 0.5) * 60)} ${f(120 + r() * 60)} ${f(x + (r() - 0.5) * 90)} ${f(200 + r() * 90)}`, { stroke: '#5a3220', strokeWidth: 3 + r() * 5, fill: 'none', strokeLinecap: 'round' }); }
  s += g({ filter: D.paint({ k: 1, seed: 6 }) }, roots);
  s += painted(D, 'M0 520Q180 470 360 520V640H0Z', '#8a5228', { paint: { k: 1.2, seed: 7 }, strokes: strokes(180, 560, 180, 50, '#c8783a', { n: 60, len: 10, w: 4, seed: 4, a: 0.6 }) });
  let leaves = '';
  for (let i = 0; i < 18; i++) { const x = 40 + r() * 280, y = 520 + r() * 60; if (Math.abs(x - 180) < 50) continue; leaves += ellipse(x, y, 9, 4.4, { fill: ['#d8803a', '#c8502a', '#e8b050'][i % 3], transform: `rotate(${f(r() * 180)} ${f(x)} ${f(y)})` }); }
  s += g({ filter: D.paint({ k: 0.4, seed: 8 }) }, leaves);
  s += circle(290, 150, 60, { fill: '#ffd07a', opacity: 0.4, filter: D.blur(26) }) + painted(D, 'M282 120h16v24h-16z', '#f4c95d', { paint: { k: 0.3, seed: 9 } });
  return s;
}

function branches(D) {
  return g({ filter: D.paint({ k: 1, seed: 10, rim: '#ffe8d0' }) },
    path('M0 210Q90 230 170 190Q230 160 300 170', { stroke: '#4a3030', strokeWidth: 11, fill: 'none', strokeLinecap: 'round' }),
    path('M120 214Q140 170 132 140M240 172Q262 140 290 132', { stroke: '#4a3030', strokeWidth: 5, fill: 'none', strokeLinecap: 'round' }),
    path('M2 202Q90 220 170 182Q230 152 302 162', { stroke: '#f6f9ff', strokeWidth: 6, fill: 'none', strokeLinecap: 'round' }),
    [[60, 214], [150, 196], [214, 172], [280, 168]].map(([x, y]) => circle(x, y + 10, 4, { fill: '#d8243a' })).join(''));
}

function fence(D) {
  let s = '';
  for (let x = 30; x < 340; x += 34) { if (Math.abs(x - 180) < 40) continue; s += path(`M${x - 7} 540V470L${x} 460L${x + 7} 470V540Z`, { fill: '#c8a070' }) + path(`M${x - 7} 470L${x} 460L${x + 7} 470L${x} 466Z`, { fill: '#f6f9ff' }); }
  s += rect(20, 486, 320, 8, { fill: '#a88058' }) + rect(20, 512, 320, 8, { fill: '#a88058' });
  return g({ filter: D.paint({ k: 0.8, seed: 11 }), opacity: 0.9 }, s);
}

function village(D, lights) {
  let s = '';
  [[60, 470, 70, 60], [140, 450, 60, 70], [300, 466, 74, 64]].forEach(([x, y, w, h], i) => {
    s += rect(x - w / 2, y - h, w, h, { fill: '#3a3060' }) + path(`M${x - w / 2 - 6} ${y - h}L${x} ${y - h - 34}L${x + w / 2 + 6} ${y - h}Z`, { fill: '#2a2450' }) + path(`M${x - w / 2 - 8} ${y - h + 2}L${x} ${y - h - 36}L${x + w / 2 + 8} ${y - h + 2}L${x + w / 2} ${y - h - 6}L${x} ${y - h - 28}L${x - w / 2} ${y - h - 6}Z`, { fill: '#e8eefc' });
    [[-12, -h * 0.6], [12, -h * 0.6], [0, -h * 0.25]].forEach(([dx, dy]) => { s += rect(x + dx - 6, y + dy - 7, 12, 14, { fill: '#ffc861' }); lights.push([x + dx, y + dy, 40]); });
  });
  return g({ filter: D.paint({ k: 0.8, seed: 13 }) }, s) + g({ filter: D.blur(1) }, path('M0 520Q180 470 360 520', { stroke: '#2a2450', strokeWidth: 0 }));
}

function oven(D) {
  return g({ filter: D.paint({ k: 1, seed: 16, rim: '#ffe0a0' }) },
    rect(226, 320, 110, 170, { rx: 8, fill: '#3a3040' }), rect(240, 380, 82, 70, { rx: 6, fill: '#1a1010' }),
    ellipse(281, 420, 34, 24, { fill: '#ff9a3a', opacity: 0.8, filter: D.blur(8) }),
    [252, 274, 296, 318].map(x => circle(x, 344, 6, { fill: '#a8a0b0' })).join(''));
}

export function backdropSheet(n) {
  const o = BACKDROPS[n - 1], D = new Defs('b' + n + '_'), lights = [];
  let s = '';
  if (o.room) {
    s += room(D, { seed: n, ...o.room });
    if (o.window) s += nightWindow(D, ...o.window);
    if (o.shelf) s += shelf(D, ...o.shelf);
    if (o.shelf2) s += shelf(D, ...o.shelf2);
    if (o.oven) s += oven(D);
    if (o.fire) s += fireplace(D, ...o.fire);
    if (o.tree) s += tree(D, ...o.tree, lights);
    if (o.tree2) s += tree(D, ...o.tree2, lights);
    if (o.garland) s += garland(D, o.garland, lights);
    if (o.bokehWarm) s += bokeh(D, 16, lights, n, true);
    // pooled warm light on the floor around the friend
    s += ellipse(180, 560, 150, 60, { fill: '#ffd28a', opacity: 0.22, filter: D.blur(26) });
  } else if (o.burrow) {
    s += burrow(D);
  } else {
    s += sky(D, o.out, { seed: n, ...o });
    if (o.ice) s += iceberg(D);
    if (o.trunks) s += trunks(D, o);
    if (o.hills) s += hills(D, { seed: n, ...o.hills });
    if (o.pines) s += bigPines(D, o);
    if (o.branches) s += branches(D);
    if (o.fence) s += fence(D);
    if (o.village) s += village(D, lights);
    if (o.fog) s += rect(0, 300, CW, 340, { fill: D.lg([[0, '#8a8ac0', 0], [0.5, '#9a9ac8', 0.55], [1, '#b0b0d8', 0.4]]) });
    if (o.bokehCool) s += bokeh(D, 10, lights, n, false);
  }
  // keep it soft so the friend reads first; darken the edges a touch
  const body = g({ filter: D.blur(0.7) }, s) + rect(0, 0, CW, CH, { fill: D.rg([[0.55, '#0a0618', 0], [1, '#0a0618', 0.45]], { r: 0.72 }) });
  // Only the arch is ever seen; the rest is left flat so it compresses away.
  const clip = D.clip(path(ARCH));
  return { kind: 'image', file: `bg-${String(n).padStart(2, '0')}.webp`, q: 0.8, scale: 2, svg: svgDoc([0, 0, CW, CH], 2, D, g({ clipPath: clip }, body)), meta: { lights, snow: !!o.snow, room: !!o.room } };
}
