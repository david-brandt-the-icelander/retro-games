// The friends. Each species is painted as separate parts (body, head, ears,
// eyes, mouths, arms, tail, hat ...) so the game can pose and animate them.
// Every part is drawn around its own pivot: the point it turns about.
// Dimensions are in the character's own units: feet at (0,0), body centre at
// (0,-bh), head centre at (0, HY(S)). The game reads the same table.
import { Defs, svgDoc, g, path, ellipse, circle, rect, blob, smooth, painted, strokes, tufts, spot, mix, tint, shade, rng, TAU } from './paint.mjs';

export const INK = '#2b1b1a';
export const HY = S => -2 * S.bh - S.hh * 0.4;

// The species table. Sizes match the earlier canvas version, so the scene
// choreography carries over. fur: how fuzzy the edges are; mouth: 'w' is an
// animal's little w, 'smile' a plain curve.
export const SP = {
  snowman: { bw: 50, bh: 46, hw: 36, hh: 33, body: '#f4f7fd', ears: 'none', nose: 'carrot', cheek: '#f4a3a8', arm: 36, aw: 6, twig: 1, armCol: '#6b4326', pawCol: '#c8303f', hat: 'top', hatCol: '#2a2733', scarf: '#c8304a', buttons: 1, foot: '#e5ecfa', snow: 1, mouth: 'coal' },
  penguin: { bw: 42, bh: 48, hw: 38, hh: 33, body: '#2a3a63', belly: '#f6f4ee', patch: '#f6f4ee', patchBig: 1, ears: 'none', nose: 'beak', noseCol: '#f2a03a', flip: 1, arm: 34, aw: 20, foot: '#f2a03a', fur: 0.6 },
  fox: { bw: 40, bh: 40, hw: 44, hh: 36, body: '#e2782a', belly: '#fbebd2', patch: '#fbebd2', ears: 'point', earIn: '#fbe3c8', earCol: '#d26c22', nose: 'dot', tail: 'fox', arm: 30, aw: 15, pawCol: '#4a3028', fur: 2.4, mouth: 'w' },
  bunny: { bw: 38, bh: 40, hw: 34, hh: 31, body: '#f6efea', belly: '#ffffff', ears: 'long', earIn: '#f5b7c4', nose: 'pink', tail: 'ball', arm: 28, aw: 14, fur: 2.2, mouth: 'w' },
  hedgehog: { bw: 40, bh: 34, hw: 36, hh: 30, body: '#c09a72', belly: '#f0dcc0', spikes: '#5a4030', ears: 'round', earS: 0.7, earIn: '#e8c4a6', nose: 'dot', noseBig: 1, arm: 26, aw: 13, fur: 1.4, mouth: 'w' },
  puppy: { bw: 42, bh: 40, hw: 40, hh: 34, body: '#e0a04a', belly: '#f8e3b8', patch: '#f8e3b8', ears: 'floppy', earCol: '#a8662a', nose: 'dot', tail: 'wag', arm: 30, aw: 15, fur: 1.8, mouth: 'w' },
  kitten: { bw: 36, bh: 38, hw: 38, hh: 32, body: '#a6aabb', belly: '#eceaf2', stripes: '#71768c', ears: 'point', earIn: '#f2b8c6', nose: 'pink', whisk: 1, tail: 'wag', arm: 28, aw: 13, fur: 2.2, mouth: 'w' },
  polar: { bw: 46, bh: 42, hw: 40, hh: 34, body: '#f1f4fb', ears: 'round', earIn: '#d6deef', patch: '#e2e9f6', nose: 'dot', scarf: '#c8304a', arm: 30, aw: 16, tail: 'ball', fur: 2.4, mouth: 'w' },
  owl: { bw: 42, bh: 44, hw: 42, hh: 36, body: '#8c6a48', belly: '#ecd9b4', ears: 'tuft', owlFace: 1, nose: 'beak', noseCol: '#e8a43a', flip: 1, arm: 32, aw: 22, foot: '#e8a43a', fur: 1.4 },
  mouse: { bw: 32, bh: 34, hw: 33, hh: 29, body: '#c9bec6', belly: '#f3eaee', ears: 'round', earS: 1.35, earIn: '#f4b4c4', nose: 'pink', tail: 'mouse', arm: 26, aw: 12, fur: 1.6, whisk: 1, mouth: 'w' },
  robin: { bw: 40, bh: 38, hw: 36, hh: 33, body: '#8a6a4e', belly: '#e2582f', patch: '#e2582f', ears: 'none', nose: 'beak', noseCol: '#f2b53a', flip: 1, arm: 26, aw: 16, foot: '#8a5a3a', fur: 1.4 },
  squirrel: { bw: 36, bh: 38, hw: 34, hh: 31, body: '#b8672e', belly: '#f6dfbf', ears: 'point', earIn: '#f1c9a2', nose: 'dot', tail: 'squirrel', arm: 28, aw: 13, fur: 2.2, mouth: 'w' },
  lamb: { bw: 40, bh: 38, hw: 30, hh: 28, body: '#fbf7f0', head: '#4a4350', wool: 1, ears: 'floppy', earCol: '#4a4350', nose: 'pinkdark', arm: 26, aw: 14, armCol: '#4a4350', foot: '#4a4350', fur: 0.8, mouth: 'w' },
  ginger: { bw: 38, bh: 40, hw: 42, hh: 36, body: '#bb7a3c', ears: 'none', nose: 'none', icing: 1, buttons: 2, arm: 30, aw: 15, cheek: '#e08a5a', mouth: 'icing' },
  teddy: { bw: 44, bh: 42, hw: 40, hh: 34, body: '#b98250', belly: '#e9cb9d', patch: '#e9cb9d', ears: 'round', earIn: '#e9cb9d', nose: 'dot', arm: 30, aw: 16, fur: 1.8, mouth: 'w', stitch: 1 },
  elf: { bw: 34, bh: 38, hw: 34, hh: 31, body: '#2f8a55', head: '#f5d3b3', ears: 'elf', nose: 'pinkdark', hat: 'elf', hatCol: '#2f8a55', belt: '#5a3a1f', armCol: '#2f8a55', pawCol: '#f5d3b3', foot: '#b3243b', arm: 28, aw: 14, cheek: '#f0707c', hair: '#c9773a', mouth: 'smile', cloth: 1 },
  reindeer: { bw: 40, bh: 42, hw: 40, hh: 34, body: '#b5733c', belly: '#f2dcb8', patch: '#f2dcb8', ears: 'side', antlers: '#8a5a32', nose: 'brown', collar: '#c8304a', arm: 30, aw: 15, tail: 'ball', fur: 1.8, mouth: 'w' },
  panda: { bw: 44, bh: 42, hw: 40, hh: 34, body: '#f7f6f2', ears: 'round', earCol: '#2a2a33', earIn: '#2a2a33', eyePatch: '#2a2a33', nose: 'dot', armCol: '#2a2a33', foot: '#2a2a33', arm: 30, aw: 17, fur: 2, mouth: 'w' },
  nut: { bw: 36, bh: 48, hw: 34, hh: 32, body: '#b3243b', head: '#f3d4b2', hat: 'tall', hatCol: '#b3243b', ears: 'none', nose: 'pinkdark', stache: 1, belt: '#f4c95d', armCol: '#b3243b', pawCol: '#ffffff', foot: '#222222', arm: 32, aw: 14, cheek: '#f0707c', mouth: 'smile', cloth: 1, braid: 1, hair: '#2a2228' },
  husky: { bw: 40, bh: 38, hw: 40, hh: 34, body: '#76839c', belly: '#f4f6fa', patch: '#f4f6fa', ears: 'point', earIn: '#f4f6fa', nose: 'dot', tail: 'wag', scarf: '#f2c24a', arm: 30, aw: 15, fur: 2.4, mouth: 'w', mask: 1 },
  whitecat: { bw: 36, bh: 38, hw: 38, hh: 32, body: '#f4f0ea', belly: '#ffffff', ears: 'point', earIn: '#f2b8c6', nose: 'pink', whisk: 1, tail: 'wag', scarf: '#c8304a', arm: 28, aw: 13, fur: 2.2, mouth: 'w' },
  santa: { bw: 56, bh: 48, hw: 40, hh: 34, body: '#c8283d', head: '#f5d3b3', beard: 1, hat: 'santa', belt: '#1f1a1f', armCol: '#c8283d', pawCol: '#ffffff', foot: '#2a1a1a', nose: 'pinkdark', noseBig: 1, arm: 32, aw: 19, cheek: '#f0707c', mouth: 'smile', cloth: 1, trim: 1 },
};

// Where each kind of ear hangs from (right ear; the left one is mirrored),
// whether it sits in front of the face, and how `ear` (-1..1) turns it.
export function earSpec(S) {
  const { hw, hh } = S;
  switch (S.ears) {
    case 'round': return { at: [hw * 0.72, -hh * 0.74], front: 0, rot: [0, 0.12] };
    case 'point': return { at: [hw * 0.6, -hh * 0.7], front: 0, rot: [0, 0.3] };
    case 'long': return { at: [hw * 0.42, -hh * 0.8], front: 0, rot: [0.1, 0.45] };
    case 'tuft': return { at: [hw * 0.45, -hh * 0.75], front: 0, rot: [0, 0.15] };
    case 'elf': return { at: [hw * 0.85, -hh * 0.05], front: 0, rot: [0, 0.25] };
    case 'side': return { at: [hw * 0.95, -hh * 0.45], front: 0, rot: [-0.55, 0.6] };
    case 'floppy': return { at: [hw * 0.86, -hh * 0.2], front: 1, rot: [0.28, 0.25] };
    default: return null;
  }
}
export const TAIL = {
  fox: S => ({ at: [S.bw * 0.7, -S.bh * 0.5], rot: [-0.9, 0.25] }),
  wag: S => ({ at: [S.bw * 0.7, -S.bh * 0.45], rot: [-0.5, 0.5] }),
  squirrel: S => ({ at: [S.bw * 0.6, -S.bh * 0.5], rot: [0.2, 0.1] }),
  mouse: S => ({ at: [S.bw * 0.6, -8], rot: [0, 0.2] }),
  ball: S => ({ at: [S.bw * 0.55, -10], rot: [0, 0.15] }),
};
// Face feature positions relative to the head centre.
export function face(S) {
  const { hw, hh } = S, ny = hh * (S.owlFace ? 0.28 : 0.3);
  return { ex: hw * 0.4, ey: hh * 0.06, ny, my: S.nose === 'carrot' ? ny + 15 : ny + hh * 0.2 };
}

const SCALE = 3;
let seedN = 11, uid = 0;
function item(id, box, build, scale = SCALE) {
  const D = new Defs('c' + (uid++) + '_');
  const body = build(D);
  // frag: the same part as a fragment, for embedding in a larger painting
  return { id, box, scale, svg: svgDoc(box, scale, D, body), frag: `<defs>${D}</defs>${body}` };
}

const furOpts = (S, k = 1, extra = {}) => ({ k, fur: (S.fur || 0) * (k < 0.7 ? 0.6 : 1), seed: seedN++, ...extra });
const snowPaint = { rim: '#ffffff', rimA: 0.8, sh: '#3f5aa8', shA: 0.38, mottle: 0.12, grain: 0.22 };

// ---------------------------------------------------------------- body
function bodyPart(S) {
  const { bw, bh } = S;
  return item('body', [-bw * 1.6, -bh * 2.6, bw * 1.6, 12], D => {
    let s = '';
    if (S.spikes) {
      const r = rng(5), cy = -bh * 1.02, R = bw * 1.08;
      for (let i = 0; i < 46; i++) {
        const a = Math.PI * 1.02 + (i / 45) * Math.PI * 0.96 + (r() - 0.5) * 0.06, L = 16 + r() * 8, w = 6 + r() * 3;
        const x = Math.cos(a) * R * (0.82 + r() * 0.12), y = cy + Math.sin(a) * R * 0.95 * (0.82 + r() * 0.12);
        const tx = x + Math.cos(a) * L, ty = y + Math.sin(a) * L, nx = -Math.sin(a) * w / 2, ny = Math.cos(a) * w / 2;
        s += path(`M${x + nx} ${y + ny}Q${(x + tx) / 2 + nx * 0.6} ${(y + ty) / 2 + ny * 0.6} ${tx} ${ty}Q${(x + tx) / 2 - nx * 0.6} ${(y + ty) / 2 - ny * 0.6} ${x - nx} ${y - ny}Z`,
          { fill: D.lg([[0, shade(S.spikes, 0.2)], [0.7, S.spikes], [1, tint(S.spikes, 0.55)]], x, y, tx, ty, 'userSpaceOnUse') });
      }
      s = g({ filter: D.paint({ k: 0.8, fur: 0, seed: 21, rimA: 0.35 }) }, s);
    }
    // feet
    const fc = shade(S.foot || S.armCol || S.body, 0.1);
    [-1, 1].forEach(k => { s += painted(D, blob(k * bw * 0.5, -7, 17, 10, 30 + k), fc, { paint: { k: 0.45, seed: 40 + k }, hi: 0.25 }); });
    if (S.wool) {
      // a cloud of fleece: overlapping painted puffs
      const r = rng(8); let puffs = '';
      for (let i = 0; i < 22; i++) {
        const a = i / 22 * TAU, q = i < 16 ? 0.86 : 0.35;
        const x = Math.cos(a + r() * 0.2) * bw * q, y = -bh + Math.sin(a + r() * 0.2) * bh * q, rr = 15 + r() * 6;
        puffs += circle(x, y, rr, { fill: D.rg([[0, '#ffffff'], [0.6, S.body], [1, shade(S.body, 0.12)]], { cx: 0.35, cy: 0.3 }) });
      }
      s += g({ filter: D.paint({ k: 0.9, rim: '#fffdf5', sh: '#6a5a86', shA: 0.35, wob: 2.4, seed: 22 }) }, ellipse(0, -bh, bw * 0.9, bh * 0.9, { fill: S.body }), puffs);
      return s;
    }
    const d = blob(0, -bh, bw, bh, 50, 0.03);
    let inner = '', tex = '';
    if (S.belly) inner += spot(D, 0, -bh * 0.84, bw * 0.6, bh * 0.66, S.belly, 1, 0.24);
    if (S.owlFace) {
      for (let r = 0; r < 3; r++) for (let k = -1; k <= 1; k++)
        inner += path(`M${k * 15 + (r % 2) * 7.5 - 12} ${-bh * 1.32 + r * 13}q8 7 16 0`, { stroke: shade(S.belly, 0.35), strokeWidth: 2.2, fill: 'none', opacity: 0.6, strokeLinecap: 'round' });
    }
    if (S.stripes) [-0.55, 0, 0.55].forEach((k, i) => {
      inner += path(`M${k * bw * 0.72 - 4} ${-bh * 1.95}q${4 + k * 6} 10 ${2 + k * 10} 20`, { stroke: S.stripes, strokeWidth: 6, fill: 'none', strokeLinecap: 'round', opacity: 0.8, filter: D.blur(0.8) });
    });
    if (S.trim) {
      inner += rect(-bw, -bh * 0.38, bw * 2, bh * 0.4, { fill: '#fbfbf8' }) + rect(-9, -bh * 2, 18, bh * 2, { fill: '#fbfbf8' });
      inner += strokes(0, -bh * 0.2, bw, bh * 0.2, '#e7ecf6', { n: 50, len: 4, w: 2.2, seed: 3, a: 0.6 });
    }
    if (S.cloth) inner += strokes(0, -bh, bw * 0.9, bh * 0.9, shade(S.body, 0.15), { n: 22, len: 14, w: 3.5, seed: 4, a: 0.12, dir: 1.4, spread: 0.05 });
    if (S.braid) [0.55, 0.85, 1.15].forEach(y => { inner += path(`M${-bw * 0.6} ${-bh * 2 + bh * y}h${bw * 1.2}`, { stroke: '#f4c95d', strokeWidth: 3.2, strokeLinecap: 'round', opacity: 0.9 }); });
    if (S.belt) {
      inner += rect(-bw, -bh * 0.92, bw * 2, 11, { fill: shade(S.belt, 0.05) });
      inner += rect(-9, -bh * 0.92 - 2, 18, 15, { rx: 2.5, fill: D.lg([[0, '#fff1b0'], [0.5, '#f4c95d'], [1, '#b8862a']]) }) + rect(-4.5, -bh * 0.92 + 2, 9, 7, { fill: shade(S.belt, 0.05) });
    }
    if (S.snow) inner += strokes(0, -bh, bw * 0.9, bh * 0.9, '#dfe7f8', { n: 60, len: 3, w: 3, seed: 6, a: 0.5 });
    if (S.fur) tex = strokes(0, -bh, bw * 0.95, bh * 0.95, S.body, { n: 90, len: 7, w: 1.5, seed: 9, a: 0.4 });
    if (S.stitch) inner += path(`M0 ${-bh * 1.9}V${-bh * 0.2}`, { stroke: shade(S.body, 0.35), strokeWidth: 1.6, strokeDasharray: '4 4', fill: 'none', opacity: 0.7 });
    if (S.icing) inner += path(blob(0, -bh, bw - 5, bh - 5, 50, 0.03), { stroke: '#fffaf0', strokeWidth: 3.6, fill: 'none', strokeDasharray: '7 5', strokeLinecap: 'round' });
    if (S.icing) tex = strokes(0, -bh, bw * 0.9, bh * 0.9, '#8a5226', { n: 40, len: 1, w: 2, seed: 2, a: 0.5 });
    let fuzz = '';
    if ((S.fur || 0) > 1.5) fuzz = tufts(0, -bh, bw, bh, S.body, { n: 70, len: 2.6, w: 3.6, seed: 12 });
    s += g({ filter: D.paint(S.snow ? { ...snowPaint, k: 1.1, seed: 5 } : furOpts(S, 1)) },
      fuzz, path(d, { fill: D.rg([[0, tint(S.body, 0.3)], [0.55, S.body], [1, shade(S.body, 0.25)]], { cx: 0.36, cy: 0.3, r: 0.85 }) }),
      g({ clipPath: D.clip(path(d)) }, tex, inner));
    if (S.buttons) {
      const cols = S.buttons === 2 ? ['#d9304a', '#3a8f5e', '#d9304a'] : ['#2a2430', '#2a2430', '#2a2430'];
      cols.forEach((c, i) => { s += painted(D, blob(0, -bh * 1.42 + i * 18, 5, 5, 60 + i), c, { paint: { k: 0.2, seed: 61 + i }, hi: 0.5 }); });
    }
    if (S.braid || S.cloth && S.belt && !S.trim) { /* gold buttons on the nutcracker / elf */
      if (S.braid) [0.55, 0.85, 1.15].forEach((y, i) => { s += painted(D, blob(0, -bh * 2 + bh * y, 3.6, 3.6, 70 + i), '#f4c95d', { paint: { k: 0.15, seed: 71 }, hi: 0.6 }); });
    }
    return s;
  });
}

// ---------------------------------------------------------------- head
function headPart(S) {
  const { hw, hh } = S, hc = S.head || S.body, F = face(S);
  return item('head', [-hw * 1.5, -hh * 1.6, hw * 1.5, hh * 1.7], D => {
    const d = blob(0, 0, hw, hh, 80, 0.025);
    let inner = '', tex = '', over = '';
    if (S.patch) inner += S.patchBig ? spot(D, 0, hh * 0.2, hw * 0.8, hh * 0.7, S.patch, 1, 0.08) : spot(D, 0, hh * 0.4, hw * 0.6, hh * 0.46, S.patch, 1, 0.12);
    if (S.mask) inner += spot(D, 0, hh * 0.15, hw * 0.75, hh * 0.55, S.patch, 1, 0.12) + path(`M0 ${-hh * 0.95}L${-hw * 0.18} ${-hh * 0.1}L0 ${hh * 0.2}L${hw * 0.18} ${-hh * 0.1}Z`, { fill: S.patch, filter: D.blur(2) });
    if (S.eyePatch) [-1, 1].forEach(s => { inner += ellipse(s * F.ex, F.ey + 2, hw * 0.21, hh * 0.31, { fill: S.eyePatch, transform: `rotate(${s * 26} ${s * F.ex} ${F.ey + 2})`, filter: D.blur(1.4) }); });
    if (S.owlFace) [-1, 1].forEach(s => { inner += spot(D, s * hw * 0.42, hh * 0.02, hh * 0.55, hh * 0.55, '#f2e3c4', 1, 0.1); });
    if (S.stripes) [-1, 0, 1].forEach(k => { inner += path(`M${k * 9} ${-hh * 0.98}l${-k * 2} ${12 - Math.abs(k) * 3}`, { stroke: S.stripes, strokeWidth: 5, strokeLinecap: 'round', filter: D.blur(0.6) }); });
    if (S.fur) tex = strokes(0, 0, hw * 0.95, hh * 0.95, hc, { n: 70, len: 6, w: 1.4, seed: 14, a: 0.35 });
    if (S.snow) tex = strokes(0, 0, hw * 0.9, hh * 0.9, '#dfe7f8', { n: 40, len: 3, w: 3, seed: 7, a: 0.5 });
    if (S.icing) {
      tex = strokes(0, 0, hw * 0.9, hh * 0.9, '#8a5226', { n: 30, len: 1, w: 2, seed: 3, a: 0.5 });
      inner += path(`M${-hw * 0.7} ${-hh * 0.55}q${hw * 0.17} ${-hh * 0.22} ${hw * 0.35} 0t${hw * 0.35} 0t${hw * 0.35} 0t${hw * 0.35} 0`, { stroke: '#fffaf0', strokeWidth: 3.6, fill: 'none', strokeLinecap: 'round' });
    }
    if (S.hair) inner += ellipse(0, -hh * 0.75, hw * 0.95, hh * 0.35, { fill: S.hair, filter: D.blur(1.2) });
    if (S.cheek !== false && !S.owlFace) [-1, 1].forEach(s => { inner += spot(D, s * hw * 0.62, hh * (S.beard ? 0.12 : 0.38), hw * 0.17, hw * 0.13, S.cheek || '#f58c9a', 0.55, 0.45); });
    if (S.beard) {
      const bd = `M${-hw * 0.98} ${hh * 0.05}Q${-hw * 1.1} ${hh * 1.4} 0 ${hh * 1.45}Q${hw * 1.1} ${hh * 1.4} ${hw * 0.98} ${hh * 0.05}Q0 ${hh * 0.42} ${-hw * 0.98} ${hh * 0.05}Z`;
      over += g({ filter: D.paint({ k: 0.8, sh: '#5a6aa8', shA: 0.35, rim: '#ffffff', fur: 2.4, seed: 88 }) },
        path(bd, { fill: D.rg([[0, '#ffffff'], [1, '#d8dff0']], { cx: 0.4, cy: 0.3 }) }), g({ clipPath: D.clip(path(bd)) }, strokes(0, hh * 0.9, hw, hh * 0.5, '#e9eef8', { n: 50, len: 6, w: 2.6, seed: 8, a: 0.45, dir: 1.6, spread: 0.06 })));
    }
    if (S.whisk) [-1, 1].forEach(s => { for (let k = -1; k <= 1; k++) over += path(`M${s * hw * 0.42} ${F.ny + 2 + k * 3}Q${s * hw * 0.8} ${F.ny + k * 6 - 2} ${s * hw * 1.15} ${F.ny + k * 9}`, { stroke: '#fffaf4', strokeWidth: 1.2, fill: 'none', opacity: 0.8, strokeLinecap: 'round' }); });
    const fuzz = (S.fur || 0) > 1.5 ? tufts(0, 0, hw, hh, hc, { n: 50, len: 2.4, w: 3.4, seed: 15, from: Math.PI * 0.05, to: Math.PI * 0.95 }) + tufts(0, 0, hw, hh, hc, { n: 16, len: 2.6, w: 3.4, seed: 16, from: Math.PI * 1.2, to: Math.PI * 1.8 }) : '';
    return g({ filter: D.paint(S.snow ? { ...snowPaint, k: 0.9, seed: 9 } : furOpts(S, 0.9)) },
      fuzz, path(d, { fill: D.rg([[0, tint(hc, 0.3)], [0.6, hc], [1, shade(hc, 0.22)]], { cx: 0.36, cy: 0.3, r: 0.85 }) }),
      g({ clipPath: D.clip(path(d)) }, tex, inner)) + over;
  });
}

// ---------------------------------------------------------------- face parts
function eyeParts(S) {
  const big = S.owlFace, rx = S.hw * (big ? 0.2 : 0.14), ry = S.hh * (big ? 0.3 : 0.22);
  const out = [];
  out.push(item('eye', [-rx * 1.6, -ry * 1.6, rx * 1.6, ry * 1.6], D => {
    const fill = D.rg([[0, '#6a3c26'], [0.45, '#3a1c12'], [1, '#110607']], { cx: 0.5, cy: 0.72, r: 0.65 });
    return g({ filter: D.rough({ k: 0.3, wob: 0.6, grain: 0.1 }) },
      ellipse(0, 0, rx, ry, { fill }),
      ellipse(0, ry * 0.45, rx * 0.6, ry * 0.3, { fill: '#8a5a8a', opacity: 0.35, filter: D.blur(rx * 0.15) }),
      ellipse(-rx * 0.28, -ry * 0.34, rx * 0.4, ry * 0.3, { fill: '#ffffff' }),
      circle(rx * 0.36, ry * 0.36, rx * 0.17, { fill: '#ffffff', opacity: 0.9 }));
  }));
  if (big) out.push(item('iris', [-ry * 1.5, -ry * 1.5, ry * 1.5, ry * 1.5], D =>
    painted(D, blob(0, 0, S.hh * 0.4, S.hh * 0.4, 5), '#f5c542', { paint: { k: 0.35, seed: 4 }, hi: 0.4 })));
  out.push(item('eyeHappy', [-rx * 1.8, -ry * 1.4, rx * 1.8, ry * 0.8], D =>
    path(`M${-rx * 1.1} ${ry * 0.2}Q0 ${-ry * 1.1} ${rx * 1.1} ${ry * 0.2}`, { stroke: S.icing ? '#fffaf0' : INK, strokeWidth: 2.8, fill: 'none', strokeLinecap: 'round' })));
  return out;
}

function nosePart(S) {
  const k = S.noseBig ? 1.4 : 1, out = [];
  const glossy = (D, d, col, id) => painted(D, d, col, { paint: { k: 0.22, seed: 5, rimA: 0.3 }, hi: 0.35 }) +
    ellipse(-2.2 * k, -1.8 * k, 1.8 * k, 1.2 * k, { fill: '#ffffff', opacity: 0.75 });
  switch (S.nose) {
    case 'dot': out.push(item('nose', [-12, -10, 12, 10], D => glossy(D, `M${-7 * k} ${-3 * k}Q0 ${-6.5 * k} ${7 * k} ${-3 * k}Q${6 * k} ${4 * k} 0 ${5 * k}Q${-6 * k} ${4 * k} ${-7 * k} ${-3 * k}Z`, '#2a1a1c'))); break;
    case 'pink': out.push(item('nose', [-10, -8, 10, 8], D => glossy(D, `M-5 -2.5Q0 -5 5 -2.5Q4 3 0 3.8Q-4 3 -5 -2.5Z`, '#ef8fa2'))); break;
    case 'pinkdark': out.push(item('nose', [-12, -10, 12, 10], D => glossy(D, blob(0, 0, 6.5 * k, 5 * k, 3), '#e48a7a'))); break;
    case 'brown':
      out.push(item('nose', [-16, -12, 16, 12], D => glossy(D, blob(0, 0, 10, 7.5, 4), '#5a3a28')));
      out.push(item('noseLit', [-16, -12, 16, 12], D => glossy(D, blob(0, 0, 10.5, 8, 4), '#ff2a2a') + ellipse(0, 0, 6, 4, { fill: '#ffd0c0', opacity: 0.5, filter: D.blur(2) })));
      break;
    case 'carrot': out.push(item('nose', [-10, -8, 34, 14], D => {
      const d = 'M-2 -6Q14 -3 30 5Q14 6 -1 6Q-5 0 -2 -6Z';
      return painted(D, d, '#f4842a', { paint: { k: 0.3, seed: 6 }, inner: [-1, 7, 14].map(x => path(`M${x + 4} -4q1 4 0 8`, { stroke: '#c95f12', strokeWidth: 1.2, fill: 'none' })).join('') });
    })); break;
    case 'beak':
      out.push(item('beakT', [-14, -8, 14, 14], D => painted(D, 'M-10 -4Q0 -7 10 -4Q4 4 0 10Q-4 4 -10 -4Z', S.noseCol, { paint: { k: 0.25, seed: 7 } })));
      out.push(item('beakB', [-12, -4, 12, 14], D => painted(D, 'M-8 0Q0 2 8 0Q3 6 0 9Q-3 6 -8 0Z', shade(S.noseCol, 0.15), { paint: { k: 0.2, seed: 8 } })));
      break;
  }
  return out;
}

function mouthParts(S) {
  const out = [], ink = S.icing ? '#fffaf0' : S.mouth === 'coal' ? '#2a2430' : '#3a1f1c';
  if (S.nose === 'beak') return out;
  out.push(item('smile', [-14, -6, 14, 14], D => {
    if (S.mouth === 'coal') return [-9, -4.5, 0, 4.5, 9].map((x, i) => circle(x, 1 + Math.cos((x / 9) * 1.2) * 0 + (1 - (x / 9) ** 2) * 6, 2.3, { fill: ink, filter: D.rough({ k: 0.1 }) })).join('');
    const d = S.mouth === 'w' ? 'M-9 0Q-4.5 6 0 0Q4.5 6 9 0' : 'M-9 0Q0 9 9 0';
    return path(d, { stroke: ink, strokeWidth: S.icing ? 3.4 : 2.4, fill: 'none', strokeLinecap: 'round', strokeLinejoin: 'round' });
  }));
  out.push(item('mouthOpen', [-15, -4, 15, 28], D => {
    const d = 'M-12 0Q0 -2.5 12 0Q12.5 22 0 24Q-12.5 22 -12 0Z';
    return g({ filter: D.rough({ k: 0.15 }) }, path(d, { fill: D.rg([[0, '#5a1420'], [1, '#2a0810']], { cx: 0.5, cy: 0.3 }) }),
      g({ clipPath: D.clip(path(d)) }, ellipse(0, 22, 9, 7, { fill: '#ef7d8f' }), ellipse(-2, 19, 3, 1.6, { fill: '#ffb0bc', opacity: 0.7 })),
      path(d, { stroke: S.icing ? '#fffaf0' : '#3a1218', strokeWidth: 1.4, fill: 'none' }));
  }));
  if (S.mouth === 'w' && (S.ears === 'floppy' || S.ears === 'point' || S.ears === 'side'))
    out.push(item('tongue', [-10, -2, 10, 24], D => painted(D, 'M-6.5 0Q-7 18 0 20Q7 18 6.5 0Z', '#f27d93', { paint: { k: 0.2, seed: 9, rimA: 0.4 }, inner: path('M0 2V15', { stroke: '#c4506a', strokeWidth: 1.2 }) })));
  return out;
}

// ---------------------------------------------------------------- ears
function earParts(S) {
  const { hw, hh } = S, eb = S.earCol || S.head || S.body, es = S.earS || 1, out = [];
  const furry = (D, d, col, inD, inCol, k = 0.5) => g({ filter: D.paint(furOpts(S, k)) },
    path(d, { fill: D.rg([[0, tint(col, 0.25)], [0.6, col], [1, shade(col, 0.25)]], { cx: 0.35, cy: 0.3 }) }),
    inD ? path(inD, { fill: inCol, filter: D.blur(1.8), opacity: 0.9 }) : '');
  switch (S.ears) {
    case 'round': out.push(item('ear', [-hw * 0.5, -hw * 0.5, hw * 0.5, hw * 0.5], D => furry(D, blob(0, 0, hw * 0.3 * es, hw * 0.3 * es, 3), eb, blob(0, hw * 0.02, hw * 0.17 * es, hw * 0.17 * es, 4), S.earIn || '#f4b8c4'))); break;
    case 'point': out.push(item('ear', [-hw * 0.6, -hh * 1.2, hw * 0.7, hh * 0.5], D => furry(D,
      smooth([[-hw * 0.4, 0.02 * hh], [-hw * 0.05, -hh * 0.55], [hw * 0.2, -hh * 0.97], [hw * 0.36, -hh * 0.4], [hw * 0.4, hh * 0.28]], true, 0.6), eb,
      smooth([[-hw * 0.2, 0], [hw * 0.02, -hh * 0.38], [hw * 0.16, -hh * 0.62], [hw * 0.26, -hh * 0.2], [hw * 0.28, hh * 0.14]], true, 0.6), S.earIn || '#f4b8c4'))); break;
    case 'long': out.push(item('ear', [-hw * 0.4, -hh * 1.9, hw * 0.4, hh * 0.2], D => furry(D,
      blob(0, -hh * 0.85, hw * 0.2, hh * 0.88, 5, 0.02), eb, blob(0, -hh * 0.82, hw * 0.1, hh * 0.64, 6, 0.02), S.earIn))); break;
    case 'tuft': out.push(item('ear', [-hw * 0.5, -hh * 0.9, hw * 0.7, hh * 0.6], D => {
      const r = rng(4); let s = '';
      for (let i = 0; i < 5; i++) { const a = -1.1 + i * 0.12; s += path(`M${-hw * 0.25 + i * 3} ${hh * 0.3}Q${hw * 0.05} ${-hh * 0.2} ${Math.cos(a) * hw * 0.45 + r() * 3} ${-hh * 0.6 - i * 2}`, { stroke: shade(S.body, 0.15 + i * 0.03), strokeWidth: 7 - i, fill: 'none', strokeLinecap: 'round' }); }
      return g({ filter: D.paint({ k: 0.4, seed: 4 }) }, s);
    })); break;
    case 'elf': out.push(item('ear', [-hw * 0.2, -hh * 0.8, hw * 0.9, hh * 0.6], D => furry(D,
      smooth([[0, -hh * 0.15], [hw * 0.45, -hh * 0.38], [hw * 0.72, -hh * 0.55], [hw * 0.4, hh * 0.05], [hw * 0.05, hh * 0.38]], true, 0.6), eb,
      smooth([[hw * 0.08, -hh * 0.08], [hw * 0.45, -hh * 0.3], [hw * 0.25, hh * 0.05]], true, 0.6), shade(eb, 0.12), 0.4))); break;
    case 'side': out.push(item('ear', [-hw * 0.3, -hh * 0.5, hw * 0.75, hh * 0.5], D => furry(D,
      blob(hw * 0.22, 0, hw * 0.36, hh * 0.2, 7), eb, blob(hw * 0.24, 0, hw * 0.2, hh * 0.1, 8), S.belly || '#f2dcb8'))); break;
    case 'floppy': out.push(item('ear', [-hw * 0.45, -hh * 0.4, hw * 0.45, hh * 1.2], D => furry(D,
      smooth([[-hw * 0.12, -hh * 0.18], [hw * 0.16, -hh * 0.15], [hw * 0.28, hh * 0.45], [hw * 0.12, hh * 0.95], [-hw * 0.18, hh * 0.85], [-hw * 0.26, hh * 0.3]], true), eb, null, null, 0.55))); break;
  }
  if (S.antlers) out.push(item('antlers', [-hw * 1.4, -hh * 2.4, hw * 1.4, -hh * 0.3], D => {
    let s = '';
    [-1, 1].forEach(k => {
      const br = (pts, w) => path(smooth(pts), { stroke: S.antlers, strokeWidth: w, fill: 'none', strokeLinecap: 'round' });
      s += br([[k * hw * 0.32, -hh * 0.7], [k * hw * 0.5, -hh * 1.3], [k * hw * 0.42, -hh * 2.0]], 7);
      s += br([[k * hw * 0.46, -hh * 1.2], [k * hw * 0.75, -hh * 1.35], [k * hw * 0.98, -hh * 1.62]], 5.5);
      s += br([[k * hw * 0.46, -hh * 1.62], [k * hw * 0.68, -hh * 1.8], [k * hw * 0.82, -hh * 2.05]], 4.5);
      s += br([[k * hw * 0.42, -hh * 1.0], [k * hw * 0.2, -hh * 1.3]], 4);
    });
    return g({ filter: D.paint({ k: 0.5, seed: 11, rim: '#ffe9c4', rimA: 0.6 }) }, s);
  }));
  return out;
}

// ---------------------------------------------------------------- hats, scarves, beards
function wearParts(S) {
  const { hw, hh } = S, out = [];
  if (S.hat === 'santa') out.push(item('hat', [-hw * 1.3, -hh * 2.3, hw * 1.4, -hh * 0.2], D => {
    const cone = `M${-hw * 0.95} ${-hh * 0.55}Q${-hw * 0.85} ${-hh * 1.7} ${hw * 0.55} ${-hh * 1.78}Q${hw * 1.05} ${-hh * 1.25} ${hw * 0.95} ${-hh * 0.55}Z`;
    return painted(D, cone, '#c8283d', { paint: { k: 0.8, seed: 3 }, strokes: strokes(0, -hh * 1.1, hw, hh * 0.6, '#c8283d', { n: 14, len: 14, w: 3.5, seed: 5, a: 0.12, dir: 0.3, spread: 0.06 }) }) +
      painted(D, blob(0, -hh * 0.58, hw * 1.02, hh * 0.19, 9, 0.06), '#f8f8f4', { paint: { k: 0.5, fur: 2.5, sh: '#5a6aa8', rim: '#ffffff', seed: 4 } }) +
      painted(D, blob(hw * 0.6, -hh * 1.8, 10, 10, 10, 0.1), '#f8f8f4', { paint: { k: 0.3, fur: 2.5, sh: '#5a6aa8', rim: '#ffffff', seed: 5 } });
  }));
  if (S.hat === 'top') out.push(item('hat', [-hw * 1.1, -hh * 2.2, hw * 1.1, -hh * 0.5], D => {
    const c = S.hatCol;
    return painted(D, blob(0, -hh * 0.78, hw * 0.88, hh * 0.18, 3, 0.02), c, { paint: { k: 0.5, seed: 3, rim: '#c8d4ff' }, hi: 0.35 }) +
      painted(D, `M${-hw * 0.5} ${-hh * 0.8}L${-hw * 0.46} ${-hh * 1.85}Q0 ${-hh * 1.98} ${hw * 0.46} ${-hh * 1.85}L${hw * 0.5} ${-hh * 0.8}Q0 ${-hh * 0.7} ${-hw * 0.5} ${-hh * 0.8}Z`, c,
        { paint: { k: 0.6, seed: 4, rim: '#c8d4ff' }, hi: 0.35, inner: rect(-hw * 0.6, -hh * 1.05, hw * 1.2, hh * 0.18, { fill: '#c8304a' }) }) +
      g({}, [[-4, -8, 0], [4, -9, 1]].map(([x, y, i]) => ellipse(hw * 0.25 + x, -hh * 1.0 + y * 0.4, 6, 3, { fill: '#2f8a55', transform: `rotate(${i ? 30 : -30} ${hw * 0.25 + x} ${-hh})` })).join('') +
        circle(hw * 0.25, -hh * 0.98, 2.6, { fill: '#e2283d' }) + circle(hw * 0.25 + 4, -hh * 0.96, 2.4, { fill: '#e2283d' }));
  }));
  if (S.hat === 'elf') out.push(item('hat', [-hw * 1.2, -hh * 2.4, hw * 1.4, -hh * 0.2], D =>
    painted(D, `M${-hw * 0.9} ${-hh * 0.55}Q${-hw * 0.6} ${-hh * 1.6} ${hw * 0.95} ${-hh * 1.95}Q${hw * 0.5} ${-hh * 1.1} ${hw * 0.92} ${-hh * 0.55}Z`, S.hatCol, { paint: { k: 0.7, seed: 6 }, strokes: strokes(0, -hh, hw, hh * 0.6, S.hatCol, { n: 14, len: 14, w: 3.5, seed: 4, a: 0.12, dir: -0.4, spread: 0.06 }) }) +
    painted(D, blob(0, -hh * 0.58, hw * 0.98, hh * 0.16, 7, 0.03), '#b3243b', { paint: { k: 0.45, seed: 7 }, inner: path(`M${-hw} ${-hh * 0.55}${Array.from({ length: 10 }, (_, i) => `l${hw * 0.1} ${i % 2 ? -5 : 5}`).join('')}`, { stroke: '#f4c95d', strokeWidth: 1.6, fill: 'none' }) }) +
    painted(D, blob(hw * 0.97, -hh * 1.97, 6.5, 6.5, 8, 0.1), '#f4c95d', { paint: { k: 0.2, seed: 8, fur: 1.5 } })));
  if (S.hat === 'tall') out.push(item('hat', [-hw * 0.9, -hh * 2.4, hw * 0.9, -hh * 0.45], D =>
    painted(D, `M${-hw * 0.6} ${-hh * 0.6}L${-hw * 0.66} ${-hh * 2.08}Q0 ${-hh * 2.2} ${hw * 0.66} ${-hh * 2.08}L${hw * 0.6} ${-hh * 0.6}Z`, S.hatCol, {
      paint: { k: 0.7, seed: 9 }, inner: rect(-hw, -hh * 0.98, hw * 2, hh * 0.17, { fill: '#f4c95d' }) + rect(-hw, -hh * 2.2, hw * 2, hh * 0.14, { fill: '#f4c95d' }) + rect(-hw, -hh * 0.76, hw * 2, hh * 0.16, { fill: '#1f1a1f' }) +
        path(`M0 ${-hh * 1.72}l4 8 9 1-7 6 2 9-8-5-8 5 2-9-7-6 9-1z`, { fill: '#f6d36a' })
    })));
  if (S.wool) out.push(item('hat', [-hw * 1.1, -hh * 1.5, hw * 1.1, -hh * 0.2], D => {
    let s = ''; [-1, 0, 1].forEach(k => { s += circle(k * hw * 0.4, -hh * 0.82 + Math.abs(k) * 6, hw * 0.34, { fill: D.rg([[0, '#ffffff'], [0.7, '#fbf7f0'], [1, '#e6dccf']], { cx: 0.35, cy: 0.3 }) }); });
    return g({ filter: D.paint({ k: 0.5, rim: '#fffdf5', sh: '#6a5a86', shA: 0.3, wob: 2.4, seed: 23 }) }, s);
  }));
  if (S.stache || S.beard) out.push(item('stache', [-hw * 0.9, -hh * 0.4, hw * 0.9, hh * 0.45], D => {
    let s = ''; [-1, 1].forEach(k => { s += ellipse(k * hw * 0.3, S.beard ? 2 : hh * 0.06, hw * (S.beard ? 0.33 : 0.36), hh * (S.beard ? 0.2 : 0.16), { fill: '#fbfbf8', transform: `rotate(${k * (S.beard ? 20 : 18)} ${k * hw * 0.3} 0)` }); });
    return g({ filter: D.paint({ k: 0.4, fur: 2, sh: '#5a6aa8', rim: '#ffffff', seed: 31 }) }, s);
  }));
  if (S.scarf || S.collar) out.push(item('scarf', [-S.hw * 1.1, -16, S.hw * 1.1, 52], D => {
    const col = S.scarf || S.collar;
    let s = painted(D, blob(0, 0, hw * 0.82, 10, 4, 0.04), col, { paint: { k: 0.4, seed: 12 }, inner: S.scarf ? strokes(0, 0, hw * 0.8, 9, col, { n: 30, len: 3, w: 2, seed: 2, a: 0.5, dir: 1.5 }) + [-0.5, 0, 0.5].map(x => rect(hw * x - 2, -10, 4, 20, { fill: '#ffffff', opacity: 0.28 })).join('') : '' });
    if (S.scarf) s = painted(D, `M${hw * 0.25} -2Q${hw * 0.27} 20 ${hw * 0.3} 40L${hw * 0.3 + 17} 38Q${hw * 0.27 + 17} 18 ${hw * 0.28 + 16} -2Z`, shade(col, 0.06),
      { paint: { k: 0.35, seed: 13 }, inner: rect(hw * 0.2, 12, 30, 4, { fill: '#ffffff', opacity: 0.35 }) + rect(hw * 0.2, 25, 30, 4, { fill: '#ffffff', opacity: 0.35 }) }) + s;
    return s;
  }));
  if (S.collar) out.push(item('bell', [-9, -4, 9, 14], D => painted(D, blob(0, 6, 6.5, 6.5, 3), '#f4c95d', { paint: { k: 0.15, seed: 14, rimA: 0.8 }, hi: 0.6, inner: path('M-3 8.5h6', { stroke: '#8a5a14', strokeWidth: 1.3 }) })));
  return out;
}

// ---------------------------------------------------------------- arms and tail
function armPart(S) {
  const L = S.arm, w = S.aw;
  return item('arm', [-w * 1.6, -w, w * 1.6, L + w * 1.6], D => {
    if (S.flip) {
      const d = blob(0, L * 0.5, w * 0.58, L * 0.64, 21, 0.02);
      return painted(D, d, shade(S.armCol || S.body, 0.04), { paint: furOpts(S, 0.45), strokes: S.fur ? strokes(0, L * 0.5, w * 0.5, L * 0.6, S.armCol || S.body, { n: 20, len: 5, w: 1.2, seed: 4, a: 0.4, dir: 1.57 }) : '' });
    }
    if (S.twig) {
      const b = path(`M0 0Q2 ${L * 0.5} -1 ${L}M0 ${L * 0.45}l-7 6M-1 ${L * 0.7}l6 5`, { stroke: S.armCol, strokeWidth: 4.5, fill: 'none', strokeLinecap: 'round' });
      return g({ filter: D.paint({ k: 0.3, seed: 6 }) }, b) +
        painted(D, `M-7 ${L - 3}Q-9 ${L + 9} 0 ${L + 11}Q9 ${L + 9} 7 ${L - 3}Z`, S.pawCol, { paint: { k: 0.3, fur: 1.4, seed: 7 }, inner: rect(-8, L - 4, 16, 4, { fill: '#ffffff', opacity: 0.8 }) }) +
        painted(D, blob(-7, L + 3, 3, 4.5, 9), S.pawCol, { paint: { k: 0.15, seed: 8 } });
    }
    const col = S.armCol || S.body, pc = S.pawCol || col, pr = w * 0.62;
    const d = `M${-w / 2} 0Q${-w * 0.55} ${L * 0.5} ${-w * 0.45} ${L}L${w * 0.45} ${L}Q${w * 0.55} ${L * 0.5} ${w / 2} 0Q0 ${-w * 0.5} ${-w / 2} 0Z`;
    let s = painted(D, d, col, { paint: furOpts(S, 0.4), lo: 0.3, strokes: S.fur ? strokes(0, L * 0.5, w * 0.4, L * 0.5, col, { n: 20, len: 5, w: 1.2, seed: 5, a: 0.4, dir: 1.57 }) : S.icing ? path(`M${-w * 0.35} ${L * 0.65}l${w * 0.17} -5l${w * 0.17} 5l${w * 0.17} -5l${w * 0.17} 5`, { stroke: '#fffaf0', strokeWidth: 2.4, fill: 'none', strokeLinecap: 'round' }) : '' });
    if (S.trim) s += painted(D, blob(0, L - 2, w * 0.62, 5, 3, 0.08), '#f8f8f4', { paint: { k: 0.3, fur: 2, sh: '#5a6aa8', rim: '#fff', seed: 9 } });
    s += painted(D, blob(0, L + 1, pr, pr * 0.95, 33), pc, { paint: furOpts(S, 0.3), hi: 0.3 });
    return s;
  });
}

function tailPart(S) {
  const t = S.tail, c = S.body;
  if (!t) return [];
  const box = [-80, -130, 90, 40];
  return [item('tail', box, D => {
    if (t === 'fox') {
      const d = smooth([[-8, 6], [-20, -18], [-30, -50], [-22, -82], [0, -96], [16, -84], [10, -60], [8, -30], [10, 4]], true);
      return g({ filter: D.paint(furOpts(S, 0.7)) }, tufts(-8, -48, 18, 46, c, { n: 50, len: 3, w: 4, seed: 3 }), path(d, { fill: D.rg([[0, tint(c, 0.25)], [0.6, c], [1, shade(c, 0.25)]], { cx: 0.35, cy: 0.4 }) }),
        g({ clipPath: D.clip(path(d)) }, ellipse(-6, -86, 22, 20, { fill: '#fbebd2', filter: D.blur(3) }), strokes(-8, -48, 15, 44, c, { n: 40, len: 8, w: 1.4, seed: 6, a: 0.4, dir: -1.7 })));
    }
    if (t === 'wag') {
      const d = smooth([[-7, 2], [-10, -20], [-5, -42], [4, -44], [9, -20], [7, 2]], true);
      return g({ filter: D.paint(furOpts(S, 0.45)) }, tufts(0, -22, 8, 22, shade(c, 0.06), { n: 24, len: 4, w: 2.4, seed: 4 }), path(d, { fill: D.rg([[0, tint(c, 0.15)], [1, shade(c, 0.18)]], { cx: 0.35, cy: 0.3 }) }));
    }
    if (t === 'squirrel') {
      const d = smooth([[-6, 6], [10, -20], [40, -40], [52, -80], [36, -112], [12, -104], [16, -78], [6, -50], [-8, -20]], true, 1);
      return g({ filter: D.paint(furOpts(S, 0.8)) }, path(d, { fill: D.rg([[0, tint(c, 0.25)], [0.6, c], [1, shade(c, 0.25)]], { cx: 0.6, cy: 0.4 }) }),
        g({ clipPath: D.clip(path(d)) }, path(smooth([[0, -8], [22, -38], [36, -80], [26, -102]]), { stroke: '#e3a56a', strokeWidth: 12, fill: 'none', filter: D.blur(3), strokeLinecap: 'round' }), strokes(26, -60, 26, 50, c, { n: 60, len: 8, w: 1.5, seed: 8, a: 0.4 })),
        tufts(26, -58, 26, 54, c, { n: 40, len: 5, w: 2.6, seed: 5 }));
    }
    if (t === 'mouse') return g({ filter: D.rough({ k: 0.3 }) }, path(`M0 0Q${S.bw * 0.8} 4 ${S.bw * 0.7} -22Q${S.bw * 0.62} -36 ${S.bw * 0.82} -40`, { stroke: '#e8a9b8', strokeWidth: 4.5, fill: 'none', strokeLinecap: 'round' }));
    if (t === 'ball') return g({ filter: D.paint({ ...furOpts(S, 0.3), fur: 2.4 }) }, tufts(0, 0, 10, 10, tint(c, 0.3), { n: 22, len: 4, w: 2.4, seed: 6 }), circle(0, 0, 11, { fill: D.rg([[0, tint(c, 0.5)], [1, tint(c, 0.1)]], { cx: 0.35, cy: 0.3 }) }));
  })];
}

// Every sprite for one species.
export function speciesItems(name) {
  const S = SP[name];
  seedN = 11;
  return [bodyPart(S), headPart(S), ...eyeParts(S), ...nosePart(S), ...mouthParts(S), ...earParts(S), ...wearParts(S), armPart(S), ...tailPart(S)];
}

// One posed character as an SVG fragment (feet at 0,0), assembled exactly the
// way the game's rig assembles the sprites. For the house's figures.
export function poseSVG(name, P = {}) {
  const S = SP[name], parts = Object.fromEntries(speciesItems(name).map(i => [i.id, i.frag]));
  P = { hr: 0, aL: 0.28, aR: 0.28, lx: 0, ly: 0, ear: 0, tail: 0, sm: 0.8, ...P };
  const F = face(S), deg = r => (r * 180 / Math.PI).toFixed(2);
  const at = (x, y, r = 0, sx = 1, sy = 1, inner = '') => g({ transform: `translate(${x} ${y}) rotate(${deg(r)}) scale(${sx} ${sy})` }, inner);
  let s = '';
  if (parts.tail) { const T = TAIL[S.tail](S); s += at(T.at[0], T.at[1], T.rot[0] + T.rot[1] * P.tail, 1, 1, parts.tail); }
  s += parts.body;
  const E = earSpec(S);
  const ears = front => E && E.front === front ? [-1, 1].map(k => g({ transform: `scale(${k} 1)` }, at(E.at[0], E.at[1], E.rot[0] + E.rot[1] * P.ear, 1, 1, parts.ear))).join('') : '';
  let h = (parts.antlers || '') + ears(0) + parts.head;
  if (parts.iris) [-1, 1].forEach(k => { h += at(k * F.ex, F.ey, 0, 1, 1, parts.iris); });
  [-1, 1].forEach(k => { h += at(k * F.ex + P.lx * 3.2, F.ey + P.ly * 3, 0, 1, 1, P.happy ? parts.eyeHappy : parts.eye); });
  if (parts.beakT) h += at(0, F.ny + 3, 0, 1, 1, parts.beakB) + at(0, F.ny, 0, 1, 1, parts.beakT);
  else if (parts.nose) h += at(0, F.ny, 0, 1, 1, parts.nose);
  if (parts.smile) h += at(0, F.my, 0, 1, P.sm, parts.smile);
  if (parts.stache) h += at(0, F.ny + (S.beard ? 5 : S.hh * 0.1), 0, 1, 1, parts.stache);
  h += ears(1) + (parts.hat || '');
  s += at(0, HY(S), P.hr, 1, 1, h);
  if (parts.scarf) s += at(0, HY(S) + S.hh * 1.05, 0, 1, 1, parts.scarf);
  [-1, 1].forEach(k => {
    const a = k > 0 ? P.aR : P.aL;
    s += g({ transform: `translate(${k * S.bw * 0.78} ${-S.bh * 1.5}) scale(${k} 1) rotate(${deg(-a)})` }, parts.arm);
  });
  return s;
}
