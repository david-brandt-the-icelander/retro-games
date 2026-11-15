const W = 1280, H = 720, HORIZON = 285, ROAD_B = 600, TAU = Math.PI * 2;
const cv = document.getElementById("c");
const ctx = cv.getContext("2d");
const FONT = 'system-ui, "Segoe UI", Roboto, Helvetica, Arial, sans-serif';

const P = (x, s) => [W / 2 + x * s, HORIZON + (ROAD_B - HORIZON) * s];
const scaleOf = (d) => 0.03 + d * d;
// point offset: p + Vector2(dx, dy) * u
const o = (p, dx, dy, u) => [p[0] + dx * u, p[1] + dy * u];
const hexc = (h) => "#" + h;
const lerp = (a, b, t) => a + (b - a) * t;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const fpos = (a, b) => ((a % b) + b) % b;
const moveToward = (v, t, d) => (Math.abs(t - v) <= d ? t : v + Math.sign(t - v) * d);
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)];

function poly(pts, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.moveTo(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length; i++) ctx.lineTo(pts[i][0], pts[i][1]);
  ctx.closePath();
  ctx.fill();
}
function el(p, rx, ry, color) {
  ctx.fillStyle = color;
  ctx.beginPath();
  ctx.ellipse(p[0], p[1], Math.max(0.01, rx), Math.max(0.01, ry), 0, 0, TAU);
  ctx.fill();
}
function circ(p, r, color) { el(p, r, r, color); }
function rc(p, w, h, color) {
  ctx.fillStyle = color;
  ctx.fillRect(p[0] - w / 2, p[1] - h / 2, w, h);
}
function rect(x, y, w, h, color) { ctx.fillStyle = color; ctx.fillRect(x, y, w, h); }
function line(a, b, color, w) {
  ctx.strokeStyle = color;
  ctx.lineWidth = Math.max(1, w);
  ctx.lineCap = "butt";
  ctx.beginPath();
  ctx.moveTo(a[0], a[1]);
  ctx.lineTo(b[0], b[1]);
  ctx.stroke();
}
function arc(p, r, a0, a1, color, w) {
  ctx.strokeStyle = color;
  ctx.lineWidth = w;
  ctx.beginPath();
  ctx.arc(p[0], p[1], r, a0, a1);
  ctx.stroke();
}
function setFont(fs, bold) { ctx.font = (bold === false ? "" : "bold ") + fs + "px " + FONT; }
function txt(s, x, y, fs, color, align, shadow) {
  setFont(fs);
  ctx.textAlign = align || "left";
  if (shadow !== false) { ctx.fillStyle = "rgba(0,0,0,0.7)"; ctx.fillText(s, x + 2, y + 2); }
  ctx.fillStyle = color;
  ctx.fillText(s, x, y);
}
function wrap(text, maxW, fs, bold) {
  setFont(fs, bold);
  const out = [];
  for (const para of text.split("\n")) {
    let cur = "";
    for (const w of para.split(" ")) {
      const t = cur ? cur + " " + w : w;
      if (ctx.measureText(t).width > maxW && cur) { out.push(cur); cur = w; } else cur = t;
    }
    out.push(cur);
  }
  return out;
}
function mtxt(text, x, y, maxW, fs, color, align, bold) {
  const lines = wrap(text, maxW, fs, bold);
  setFont(fs, bold);
  ctx.textAlign = align || "left";
  ctx.fillStyle = color;
  lines.forEach((l, i) => ctx.fillText(l, x, y + i * fs * 1.28));
  return lines.length * fs * 1.28;
}
function panel(x, y, w, h, fill, edge) {
  rect(x, y, w, h, fill);
  ctx.strokeStyle = edge; ctx.lineWidth = 3; ctx.strokeRect(x, y, w, h);
}
function bubble(x, y, text, width, fill, ink, fs) {
  const lh = fs * 1.28, n = wrap(text, width, fs, false).length, h = n * lh + 20;
  panel(x, y, width + 24, h, fill, ink);
  mtxt(text, x + 12, y + 10 + fs, width, fs, ink, "left", false);
  return h;
}
function person(g, h, shirt, skin, walk, hair) {
  const sw = Math.sin(walk) * h * 0.12, legc = "#2b2b3a", hip = o(g, 0, -h * 0.45, 1);
  line(hip, o(g, sw, 0, 1), legc, h * 0.09);
  line(hip, o(g, -sw, 0, 1), legc, h * 0.09);
  rc(o(g, 0, -h * 0.65, 1), h * 0.28, h * 0.4, shirt);
  line(o(g, 0, -h * 0.8, 1), o(g, sw * 1.3, -h * 0.55, 1), skin, h * 0.07);
  line(o(g, 0, -h * 0.8, 1), o(g, -sw * 1.3, -h * 0.55, 1), skin, h * 0.07);
  circ(o(g, 0, -h * 0.9, 1), h * 0.1, skin);
  el(o(g, 0, -h * 0.96, 1), h * 0.1, h * 0.055, hair);
}
function signPlate(shape, c, size, col, ink, glyph) {
  const r = size * 0.5;
  let pts = [];
  if (shape === "diamond") { const k = r * 1.3; pts = [[c[0], c[1] - k], [c[0] + k, c[1]], [c[0], c[1] + k], [c[0] - k, c[1]]]; }
  else if (shape === "octagon") for (let i = 0; i < 8; i++) { const a = Math.PI / 8 + i * Math.PI / 4; pts.push([c[0] + Math.cos(a) * r * 1.15, c[1] + Math.sin(a) * r * 1.15]); }
  else if (shape === "circle") for (let i = 0; i < 24; i++) { const a = TAU * i / 24; pts.push([c[0] + Math.cos(a) * r * 1.1, c[1] + Math.sin(a) * r * 1.1]); }
  else pts = [[c[0] - r * 1.15, c[1] - r * 0.95], [c[0] + r * 1.15, c[1] - r * 0.95], [c[0] + r * 1.15, c[1] + r * 0.95], [c[0] - r * 1.15, c[1] + r * 0.95]];
  poly(pts, col);
  ctx.strokeStyle = "#111"; ctx.lineWidth = Math.max(1, size * 0.04);
  ctx.beginPath(); pts.forEach((p, i) => (i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]))); ctx.closePath(); ctx.stroke();
  if (size < 34) return;
  const lines = glyph.split("\n"), fs = Math.floor(size * (glyph.length <= 4 ? 0.3 : 0.2));
  lines.forEach((l, i) => txt(l, c[0], c[1] + (i - (lines.length - 1) / 2) * fs * 1.1 + fs * 0.35, fs, ink, "center", false));
}
