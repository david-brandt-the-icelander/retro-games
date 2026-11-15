// Art every opened window shares: the golden arched frame the card is seen
// through, the snowy ledge in front of the friend, and the props and little
// effects the scenes use.
import { Defs, svgDoc, g, path, ellipse, circle, rect, blob, smooth, painted, strokes, spot, mix, tint, shade, rng, TAU } from './paint.mjs';

export const CW = 360, CH = 640;
// The arch, in card units. The game clips each scene to the same path.
export const ARCH = 'M36 602L36 210C36 100 110 56 180 56C250 56 324 100 324 210L324 602Z';
const ARCH_OUT = 'M14 640L14 206C14 84 98 30 180 30C262 30 346 84 346 206L346 640Z';
const f = n => +n.toFixed(2);

function item(id, box, scale, build) {
  const D = new Defs(id.replace(/\W/g, '') + '_');
  return { id, box, scale, svg: svgDoc(box, scale, D, build(D)) };
}

function frame(D) {
  const r = rng(4);
  let logs = '';
  for (let y = -10, i = 0; y < CH; y += 28, i++) {
    const tone = ['#9a5c30', '#a3653a', '#93552b'][i % 3];
    logs += rect(0, y, CW, 28, { fill: D.lg([[0, tint(tone, 0.3)], [0.35, tone], [0.85, shade(tone, 0.3)], [1, shade(tone, 0.55)]]) });
    logs += rect(0, y + 26, CW, 2, { fill: '#2e170c', opacity: 0.8 });
    for (let k = 0; k < 6; k++) { const x = r() * CW, L = 40 + r() * 90, yy = y + 5 + r() * 18; logs += path(`M${f(x)} ${f(yy)}q${f(L / 2)} ${f((r() - 0.5) * 4)} ${f(L)} 0`, { stroke: r() < 0.5 ? shade(tone, 0.4) : tint(tone, 0.3), strokeWidth: 0.9, fill: 'none', opacity: 0.5 }); }
  }
  const wall = `M0 0H${CW}V${CH}H0Z` + ARCH_OUT;
  let s = g({ filter: D.rough({ k: 1.4, wob: 1.2, grain: 0.16, seed: 2 }) }, g({ clipPath: D.clip(path(wall, { clipRule: 'evenodd' })) }, logs,
    rect(0, 0, CW, CH, { fill: D.rg([[0.55, '#1a0c06', 0], [1, '#1a0c06', 0.55]], { r: 0.75 }) })));
  // warm light falling on the wall from the window
  s += path(ARCH_OUT, { fill: 'none', stroke: '#ffb34a', strokeWidth: 26, opacity: 0.22, filter: D.blur(12) });
  // the golden moulding round the arch
  const mould = ARCH_OUT + ARCH;
  s += g({ filter: D.paint({ k: 1.4, seed: 5, rim: '#fff0c8', rimA: 0.7, shA: 0.5 }) },
    path(mould, { fillRule: 'evenodd', fill: D.lg([[0, '#f0bd6a'], [0.5, '#d18f45'], [1, '#a8672e']], 0, 0, 1, 1) }),
    g({ clipPath: D.clip(path(mould, { clipRule: 'evenodd' })) }, strokes(180, 330, 175, 310, '#c8873e', { n: 160, len: 20, w: 1, seed: 6, a: 0.45 })),
    path(ARCH, { fill: 'none', stroke: '#6a3a18', strokeWidth: 3.5 }),
    path('M25 640L25 208C25 92 104 43 180 43C256 43 335 92 335 208L335 640', { fill: 'none', stroke: '#fff0c8', strokeWidth: 1.6, opacity: 0.55 }));
  // inner shadow so the scene sits back inside the window
  s += g({ clipPath: D.clip(path(ARCH)) }, path(ARCH, { fill: 'none', stroke: '#1a0a14', strokeWidth: 26, opacity: 0.45, filter: D.blur(8) }));
  // hinges: the door has swung open to the left
  [196, 430].forEach(y => {
    s += g({ filter: D.paint({ k: 0.4, seed: 7, rim: '#a0a0b8' }) }, path(`M0 ${y}H44q8 7 0 14H0Z`, { fill: '#33282a' }), [10, 22, 34].map(x => circle(x, y + 7, 2.2, { fill: '#8a7a76' })).join(''));
  });
  // snow lying on top of the arch
  const cap = smooth([[2, 214], [8, 150], [40, 82], [100, 40], [180, 22], [260, 40], [320, 82], [352, 150], [358, 214], [348, 210], [338, 150], [306, 86], [250, 50], [180, 36], [110, 50], [54, 86], [22, 150], [12, 210]], true, 0.9);
  s += painted(D, cap, '#f3f7ff', { paint: { k: 0.9, rim: '#ffffff', rimA: 0.9, sh: '#4a64b8', shA: 0.4, seed: 8 }, hi: 0.2, lo: 0.15, strokes: strokes(180, 100, 170, 90, '#dfe7fa', { n: 80, len: 4, w: 3, seed: 9, a: 0.4 }) });
  // holly at the top
  [[118, 34, -0.5], [242, 34, 0.5]].forEach(([x, y, a]) => {
    let h = '';
    [-1, 0, 1].forEach(k => { const aa = a + k * 0.7; h += ellipse(x + Math.cos(aa) * 11, y + Math.sin(aa) * 6, 11, 5, { fill: k ? '#2a6e3e' : '#327f48', transform: `rotate(${f(aa * 57)} ${f(x + Math.cos(aa) * 11)} ${f(y + Math.sin(aa) * 6)})` }); });
    h += circle(x - 2, y - 1, 3.6, { fill: '#d8243a' }) + circle(x + 3, y - 2, 3.4, { fill: '#c81e32' }) + circle(x, y + 3, 3.4, { fill: '#e02a40' });
    s += g({ filter: D.paint({ k: 0.3, seed: 10 }) }, h);
  });
  // the number plaque on the keystone; the number is live text
  s += ellipse(181, 66, 60, 30, { fill: '#2a1408', opacity: 0.4, filter: D.blur(5) });
  s += painted(D, blob(180, 62, 58, 28, 3, 0.012), '#f7e8c6', { paint: { k: 0.6, seed: 11, rim: '#ffffff', rimA: 0.7, shA: 0.3 }, hi: 0.3, lo: 0.1 });
  s += path(blob(180, 62, 52, 23, 3, 0.012), { fill: 'none', stroke: '#c8902e', strokeWidth: 2.4 });
  s += path(blob(180, 62, 58, 28, 3, 0.012), { fill: 'none', stroke: '#8a5a1a', strokeWidth: 2 });
  return s;
}

function ledge(D) {
  const r = rng(12);
  let s = '';
  s += painted(D, 'M4 600H356V628H4Z', '#a2622e', { paint: { k: 0.8, seed: 13, shA: 0.5 }, hi: 0.35, strokes: strokes(180, 614, 175, 12, '#a2622e', { n: 50, len: 30, w: 1, seed: 3, a: 0.45, dir: 0 }) });
  const top = [[0, 606]];
  for (let x = 10; x <= 350; x += 34) top.push([x, 560 + Math.sin(x * 0.05) * 6 + r() * 12]);
  top.push([360, 604], [362, 612]);
  const d = smooth([...top, [300, 612], [180, 616], [60, 612], [-2, 612]], true, 0.9);
  s += painted(D, d, '#f3f7ff', { paint: { k: 1.1, rim: '#ffffff', rimA: 0.95, sh: '#3f5aa8', shA: 0.42, seed: 14 }, hi: 0.18, lo: 0.2, cy: 0.1, strokes: strokes(180, 590, 175, 30, '#dfe7fa', { n: 90, len: 5, w: 3.4, seed: 15, a: 0.4 }) });
  // a few drips of snow over the sill and warm window light on the snow
  [70, 150, 236, 300].forEach((x, i) => { s += painted(D, `M${x - 8} 610Q${x - 7} ${626 + i * 2} ${x} ${628 + i * 2}Q${x + 7} ${626 + i * 2} ${x + 8} 610Z`, '#eef3ff', { paint: { k: 0.3, rim: '#fff', sh: '#3f5aa8', seed: 16 + i } }); });
  s += ellipse(180, 572, 120, 14, { fill: '#ffcf7a', opacity: 0.25, filter: D.blur(8) });
  let spark = '';
  for (let i = 0; i < 26; i++) spark += circle(10 + r() * 340, 568 + r() * 34, 0.7 + r() * 0.8, { fill: '#ffffff', opacity: f(0.5 + r() * 0.5) });
  return s + spark;
}

const glossy = (D, d, col, seed, o = {}) => painted(D, d, col, { paint: { k: o.k ?? 0.35, seed, rimA: 0.75, ...(o.paint || {}) }, hi: o.hi ?? 0.45, lo: o.lo ?? 0.35, inner: o.inner });

function props() {
  const P = 3, out = [];
  const add = (id, box, build, scale = P) => out.push(item(id, box, scale, build));
  add('bauble', [-30, -36, 30, 30], D => glossy(D, blob(0, 0, 24, 24, 2, 0.008), '#d8283e', 31, { inner: path('M-24 4Q0 14 24 4', { stroke: '#f4c95d', strokeWidth: 3, fill: 'none', opacity: 0.8 }) + path('M-22 -6Q0 4 22 -6', { stroke: '#ffffff', strokeWidth: 1.6, fill: 'none', opacity: 0.5, strokeDasharray: '2 4' }) }) +
    ellipse(-8, -9, 6, 4, { fill: '#ffffff', opacity: 0.7, transform: 'rotate(-30 -8 -9)' }) + glossy(D, 'M-5 -30H5V-21H-5Z', '#f4c95d', 32, { k: 0.12 }));
  add('candle', [-18, -62, 18, 10], D => glossy(D, 'M-15 0Q-15 -5 0 -5Q15 -5 15 0Q15 6 0 7Q-15 6 -15 0Z', '#e0b040', 33, { k: 0.2 }) +
    painted(D, 'M-6 -48Q-6 -51 0 -51Q6 -51 6 -48V-2H-6Z', '#f6ecd6', { paint: { k: 0.2, seed: 34, rim: '#ffffff' }, hi: 0.3, lo: 0.2, inner: path('M-6 -46q2 8 0 12', { stroke: '#fffaf0', strokeWidth: 2.4, fill: 'none' }) }) +
    path('M0 -51V-57', { stroke: '#2a1a12', strokeWidth: 1.6, strokeLinecap: 'round' }));
  add('giftBox', [-30, -44, 30, 4], D => painted(D, 'M-25 0V-40H25V0Z', '#d9304a', { paint: { k: 0.4, seed: 35 }, inner: rect(-4.5, -40, 9, 40, { fill: '#f4c95d' }) + rect(-25, -22, 50, 5, { fill: '#f4c95d' }) + rect(0, -40, 25, 40, { fill: '#000', opacity: 0.12 }) }));
  add('giftLid', [-34, -32, 34, 6], D => painted(D, 'M-28 2V-10H28V2Z', '#e23a52', { paint: { k: 0.3, seed: 36 }, inner: rect(-4.5, -10, 9, 12, { fill: '#f4c95d' }) }) +
    g({ filter: D.paint({ k: 0.25, seed: 37 }) }, path('M0 -10q-20 -18 -18 -2q3 7 18 2z', { fill: '#f4c95d' }), path('M0 -10q20 -18 18 -2q-3 7 -18 2z', { fill: '#e6b84a' }), circle(0, -10, 3.6, { fill: '#f8d870' })));
  add('cookie', [-28, -28, 28, 28], D => painted(D, blob(0, 0, 24, 23, 5, 0.05), '#d9a45a', { paint: { k: 0.35, seed: 38 }, hi: 0.3, inner: [[-9, -6], [8, -10], [4, 8], [-8, 9], [12, 3], [-2, -1]].map(([x, y]) => ellipse(x, y, 3.4, 3, { fill: '#5a321a' })).join('') + strokes(0, 0, 20, 20, '#c0884a', { n: 30, len: 1, w: 2, seed: 3, a: 0.5 }) }));
  add('cookieBit', [-28, -28, 28, 28], D => painted(D, 'M-24 0A24 23 0 0 1 20 -12Q10 -8 12 0Q4 2 8 10Q0 12 -2 22A24 23 0 0 1 -24 0Z', '#d9a45a', { paint: { k: 0.35, seed: 38 }, hi: 0.3, inner: [[-9, -6], [-8, 9], [-2, -1]].map(([x, y]) => ellipse(x, y, 3.4, 3, { fill: '#5a321a' })).join('') }));
  add('bell', [-18, -34, 18, 18], D => painted(D, 'M-3 -28H3V-17H-3Z', '#7a4a2a', { paint: { k: 0.15, seed: 39 } }) +
    glossy(D, 'M-15 10Q-15 -16 0 -18Q15 -16 15 10Q0 13 -15 10Z', '#f0c24a', 40, { k: 0.25 }) + glossy(D, blob(0, 11, 4, 4, 3), '#a06a14', 41, { k: 0.1 }));
  add('mug', [-30, -48, 40, 16], D => g({ filter: D.paint({ k: 0.2, seed: 42 }) }, path('M22 -24a11 11 0 0 1 0 22', { stroke: '#4aa3c8', strokeWidth: 5, fill: 'none' })) +
    glossy(D, 'M-22 -30H22V2Q22 10 14 10H-14Q-22 10 -22 2Z', '#4aa3c8', 43, { inner: rect(-22, -14, 44, 8, { fill: '#fffaf0' }) + path('M-14 -10l3 -3 3 3 3 -3 3 3 3 -3 3 3', { stroke: '#d8304a', strokeWidth: 1.4, fill: 'none' }) }) +
    ellipse(0, -30, 21, 5.5, { fill: '#5a321c' }) + glossy(D, 'M-14 -40h12v10h-12z', '#fffaf4', 44, { k: 0.15, hi: 0.1 }) + glossy(D, 'M1 -38h11v9h-11z', '#ffe0ea', 45, { k: 0.15, hi: 0.1 }));
  add('lantern', [-18, -36, 18, 34], D => g({ filter: D.paint({ k: 0.3, seed: 46, rim: '#ffd9a0' }) },
    path('M-9 -30H9M0 -30V-6', { stroke: '#2a2530', strokeWidth: 2.4, fill: 'none', strokeLinecap: 'round' }),
    path('M-15 -4L0 -12L15 -4Z', { fill: '#2a2530' }),
    rect(-13, -4, 26, 32, { fill: '#ffe6a0', opacity: 0.18 }),
    path('M-13 -4h26v32h-26zM0 -4v32', { stroke: '#2a2530', strokeWidth: 2.8, fill: 'none' }),
    rect(-15, 27, 30, 5, { fill: '#2a2530', rx: 1.5 })));
  add('snowball', [-16, -16, 16, 16], D => painted(D, blob(0, 0, 12, 12, 7, 0.06), '#f8faff', { paint: { k: 0.3, rim: '#fff', sh: '#3f5aa8', shA: 0.5, seed: 47 }, hi: 0.1, lo: 0.2 }));
  add('splat', [-120, -100, 120, 100], D => {
    const r = rng(19); const pts = [];
    for (let i = 0; i < 22; i++) { const a = i / 22 * TAU, q = i % 2 ? 0.55 + r() * 0.2 : 0.8 + r() * 0.35; pts.push([Math.cos(a) * 100 * q, Math.sin(a) * 76 * q]); }
    let s = painted(D, smooth(pts, true, 1), '#fbfdff', { paint: { k: 1.4, rim: '#ffffff', sh: '#5a74c0', shA: 0.4, seed: 48 }, hi: 0.05, lo: 0.12, strokes: strokes(0, 0, 80, 60, '#e4ebfb', { n: 60, len: 6, w: 4, seed: 4, a: 0.4 }) });
    for (let i = 0; i < 7; i++) { const a = r() * TAU; s += painted(D, blob(Math.cos(a) * 108, Math.sin(a) * 84, 6 + r() * 6, 6 + r() * 6, i), '#fbfdff', { paint: { k: 0.3, sh: '#5a74c0', seed: 50 + i } }); }
    return s;
  }, 2);
  add('star', [-20, -20, 20, 20], D => glossy(D, smooth([0, 1, 2, 3, 4, 5, 6, 7, 8, 9].map(i => { const a = -Math.PI / 2 + i * Math.PI / 5, q = i % 2 ? 7 : 16; return [Math.cos(a) * q, Math.sin(a) * q]; }), true, 0.25), '#f6cf5a', 49, { k: 0.3, paint: { rim: '#fffbe0' } }));
  add('heart', [-14, -14, 14, 14], D => glossy(D, 'M0 9C-14 0 -10 -12 0 -5C10 -12 14 0 0 9Z', '#e8466e', 51, { k: 0.2 }) + ellipse(-4, -3, 2.6, 1.6, { fill: '#fff', opacity: 0.6 }));
  ['#b3243b', '#2f6d4f', '#7a3fa0'].forEach((c, i) => add('note' + i, [-14, -26, 14, 12], D => g({ filter: D.paint({ k: 0.2, seed: 52 + i }) }, ellipse(0, 0, 6, 4.6, { fill: c, transform: 'rotate(-22)' }), path('M5 -1V-20Q12 -16 11 -9', { stroke: c, strokeWidth: 2.4, fill: 'none', strokeLinecap: 'round' }))));
  add('flake', [-12, -12, 12, 12], D => { let s = ''; for (let i = 0; i < 6; i++) { const a = i * Math.PI / 3, x = Math.cos(a) * 9, y = Math.sin(a) * 9; s += path(`M0 0L${f(x)} ${f(y)}M${f(x * 0.55)} ${f(y * 0.55)}l${f(Math.cos(a + 0.8) * 3.4)} ${f(Math.sin(a + 0.8) * 3.4)}M${f(x * 0.55)} ${f(y * 0.55)}l${f(Math.cos(a - 0.8) * 3.4)} ${f(Math.sin(a - 0.8) * 3.4)}`, { stroke: '#ffffff', strokeWidth: 1.5, strokeLinecap: 'round' }); } return g({ filter: D.glow(1, 0.7) }, s); });
  add('sparkle', [-14, -14, 14, 14], D => g({ filter: D.glow(1.6, 0.9) }, path('M0 -11Q1.4 -1.4 11 0Q1.4 1.4 0 11Q-1.4 1.4 -11 0Q-1.4 -1.4 0 -11Z', { fill: '#fff6cc' })));
  add('banner', [-150, -34, 150, 34], D => {
    const d = 'M-140 -22Q-70 -30 0 -22Q70 -30 140 -22L132 0L140 22Q70 14 0 22Q-70 14 -140 22L-132 0Z';
    return painted(D, d, '#c8283d', { paint: { k: 0.8, seed: 55 }, inner: path('M-136 -17Q-70 -25 0 -17Q70 -25 136 -17M-136 17Q-70 9 0 17Q70 9 136 17', { stroke: '#f4c95d', strokeWidth: 2, fill: 'none', strokeDasharray: '5 4' }) + strokes(0, 0, 130, 18, '#c8283d', { n: 30, len: 20, w: 3, seed: 3, a: 0.15, dir: 1.57 }) });
  }, 2.2);
  return out;
}

export function commonSheet() {
  const items = [item('frame', [0, 0, CW, CH], 2.2, frame), item('ledge', [-4, 540, CW + 4, 640], 2.2, ledge), ...props()];
  return { kind: 'atlas', file: 'common.webp', q: 0.84, items, meta: { arch: ARCH, cw: CW, ch: CH } };
}
