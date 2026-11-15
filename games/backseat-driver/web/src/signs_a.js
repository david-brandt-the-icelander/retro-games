// Icelandic-style road signs, redrawn in code (simplified; not the official artwork).
// Warning: red-bordered triangle on yellow. Prohibition: red-ringed circle on yellow.
// Mandatory: blue circle, white border. Information: blue rectangle. Stop: red octagon.
const YEL = "#f6c600", RED = "#d3262b", BLU = "#0d4fa6", INK = "#111", WHT = "#fff";
let K = INK; // current pictogram ink
const pl = (pts, w) => { ctx.strokeStyle = K; ctx.lineWidth = w || 0.12; ctx.lineJoin = "round"; ctx.lineCap = "round"; ctx.beginPath(); pts.forEach((p, i) => (i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]))); ctx.stroke(); };
const pg = (pts, col) => { ctx.fillStyle = col || K; ctx.beginPath(); pts.forEach((p, i) => (i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]))); ctx.closePath(); ctx.fill(); };
const ci = (x, y, r, col) => { ctx.fillStyle = col || K; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.fill(); };
const oval = (x, y, rx, ry, col) => { ctx.fillStyle = col || K; ctx.beginPath(); ctx.ellipse(x, y, rx, ry, 0, 0, TAU); ctx.fill(); };
const stk = (x, y, r, w, col) => { ctx.strokeStyle = col || K; ctx.lineWidth = w; ctx.beginPath(); ctx.arc(x, y, r, 0, TAU); ctx.stroke(); };
const head = (x, y, a, s) => pg([[x + Math.cos(a) * s, y + Math.sin(a) * s], [x + Math.cos(a + 2.5) * s, y + Math.sin(a + 2.5) * s], [x + Math.cos(a - 2.5) * s, y + Math.sin(a - 2.5) * s]]);
const arrow = (pts, w) => { pl(pts, w || 0.16); const a = pts[pts.length - 2], b = pts[pts.length - 1]; head(b[0], b[1], Math.atan2(b[1] - a[1], b[0] - a[0]), 0.3); };
const utxt = (s, x, y, fs) => { ctx.fillStyle = K; ctx.font = `bold ${fs}px ${FONT}`; ctx.textAlign = "center"; ctx.fillText(s, x, y + fs * 0.35); };

// vehicles (side view)
function car(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); pg([[-0.6, 0.15], [-0.55, -0.05], [-0.25, -0.3], [0.25, -0.3], [0.45, -0.05], [0.6, 0.15]]); ci(-0.33, 0.18, 0.14, K); ci(0.33, 0.18, 0.14, K); ctx.restore(); }
function truck(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); pg([[-0.7, -0.35], [0.2, -0.35], [0.2, 0.15], [-0.7, 0.15]]); pg([[0.25, -0.15], [0.5, -0.15], [0.65, 0.0], [0.65, 0.15], [0.25, 0.15]]); ci(-0.45, 0.2, 0.13, K); ci(0.0, 0.2, 0.13, K); ci(0.45, 0.2, 0.13, K); ctx.restore(); }
function bus(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); pg([[-0.7, -0.35], [0.65, -0.35], [0.7, 0.15], [-0.7, 0.15]]); ci(-0.4, 0.2, 0.13, K); ci(0.4, 0.2, 0.13, K); ctx.restore(); }
function moto(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); stk(-0.4, 0.1, 0.22, 0.09); stk(0.4, 0.1, 0.22, 0.09); pl([[-0.4, 0.1], [-0.1, -0.15], [0.3, -0.15], [0.4, 0.1]], 0.09); pg([[-0.15, -0.2], [0.2, -0.2], [0.15, -0.35], [-0.1, -0.35]]); ctx.restore(); }
function bike(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); stk(-0.4, 0.15, 0.25, 0.07); stk(0.4, 0.15, 0.25, 0.07); pl([[-0.4, 0.15], [-0.1, -0.2], [0.25, -0.2], [0.4, 0.15], [0.05, 0.15], [-0.1, -0.2]], 0.07); pl([[0.25, -0.2], [0.3, -0.4], [0.45, -0.4]], 0.07); pl([[-0.2, -0.25], [-0.05, -0.25]], 0.09); ctx.restore(); }
function sPerson(x, y, s, walk) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); ci(0, -0.6, 0.16); pg([[-0.18, -0.4], [0.18, -0.4], [0.14, 0.1], [-0.14, 0.1]]); const w = walk ? 0.16 : 0.08; pl([[-0.07, 0.1], [-w, 0.5]], 0.14); pl([[0.07, 0.1], [w, 0.5]], 0.14); pl([[-0.18, -0.35], [-0.3, 0.0]], 0.1); pl([[0.18, -0.35], [0.3, 0.0]], 0.1); ctx.restore(); }
function sheep(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); [[-0.4, 0], [-0.15, -0.12], [0.1, -0.08], [-0.25, 0.1], [0.0, 0.12], [0.2, 0.06], [-0.5, 0.1]].forEach((c) => ci(c[0], c[1], 0.2)); ci(0.42, -0.05, 0.14); [[-0.4, 0.2], [-0.1, 0.24], [0.15, 0.2]].forEach((c) => pl([[c[0], c[1]], [c[0], 0.55]], 0.08)); ctx.restore(); }
function cow(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); pg([[-0.55, -0.25], [0.3, -0.25], [0.3, 0.2], [-0.55, 0.2]]); pg([[0.3, -0.3], [0.65, -0.15], [0.62, 0.05], [0.3, 0.0]]); pl([[0.4, -0.3], [0.35, -0.5]], 0.07); pl([[0.55, -0.25], [0.62, -0.45]], 0.07); [-0.45, -0.3, 0.1, 0.25].forEach((px) => pl([[px, 0.2], [px, 0.6]], 0.1)); pl([[-0.55, -0.15], [-0.7, 0.1]], 0.05); ctx.restore(); }
function horse(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); oval(-0.05, -0.05, 0.5, 0.22); pg([[0.3, -0.15], [0.55, -0.6], [0.72, -0.5], [0.5, -0.05]]); pg([[0.55, -0.6], [0.85, -0.45], [0.8, -0.35], [0.55, -0.48]]); [-0.35, -0.2, 0.2, 0.35].forEach((px) => pl([[px, 0.1], [px, 0.6]], 0.09)); pl([[-0.5, -0.12], [-0.72, 0.2]], 0.07); ctx.restore(); }
function reindeer(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); oval(-0.1, 0.0, 0.45, 0.22); pg([[0.2, -0.1], [0.4, -0.4], [0.55, -0.35], [0.4, 0.0]]); oval(0.52, -0.4, 0.15, 0.1); [-0.35, -0.2, 0.1, 0.25].forEach((px) => pl([[px, 0.1], [px, 0.58]], 0.08)); pl([[0.45, -0.5], [0.35, -0.8], [0.2, -0.9]], 0.06); pl([[0.38, -0.68], [0.55, -0.75]], 0.06); pl([[0.55, -0.5], [0.62, -0.8], [0.78, -0.85]], 0.06); ctx.restore(); }
function arch(x, y, s) { ctx.save(); ctx.translate(x, y); ctx.scale(s, s); ctx.fillStyle = K; ctx.beginPath(); ctx.moveTo(-0.7, 0.55); ctx.lineTo(-0.7, -0.05); ctx.arc(0, -0.05, 0.7, Math.PI, 0); ctx.lineTo(0.7, 0.55); ctx.closePath(); ctx.fill(); pg([[-0.3, 0.55], [-0.12, -0.05], [0.12, -0.05], [0.3, 0.55]], YEL); ctx.restore(); }

// ---- pictograms: PIC[name](args) draws in unit space (about -1..1) with ink K ----
const PIC = {
  curve: (a) => { ctx.save(); if (a.flip) ctx.scale(-1, 1); arrow([[-0.25, 0.85], [-0.25, 0.1], [0.0, -0.2], [0.55, -0.45]]); ctx.restore(); },
  hill: (a) => { ctx.save(); if (a.up) ctx.scale(-1, 1); pg([[-0.8, -0.35], [0.8, 0.5], [-0.8, 0.5]]); car(-0.15, -0.25, 0.4); ctx.restore(); utxt(a.t || "10%", 0, -0.62, 0.4); },
  narrow: (a) => { const L = a.side !== "r", R = a.side !== "l"; if (L) pl([[-0.55, 0.85], [-0.55, 0.0], [-0.3, -0.85]], 0.14); if (R) pl([[0.55, 0.85], [0.55, 0.0], [0.3, -0.85]], 0.14); if (!L) pl([[-0.5, 0.85], [-0.5, -0.85]], 0.14); if (!R) pl([[0.5, 0.85], [0.5, -0.85]], 0.14); },
  bumpy: () => { pl([[-0.9, 0.35], [-0.5, 0.2], [-0.2, 0.45], [0.1, 0.2], [0.4, 0.45], [0.9, 0.3]], 0.1); car(0, -0.1, 0.65); },
  bump: () => { ctx.fillStyle = K; ctx.beginPath(); ctx.arc(0, 0.5, 0.5, Math.PI, 0); ctx.fill(); pl([[-0.9, 0.5], [0.9, 0.5]], 0.1); car(0, -0.2, 0.5); },
  works: () => { sPerson(-0.25, 0.0, 0.75, false); pl([[0.05, 0.35], [0.4, 0.0]], 0.1); pg([[0.15, 0.5], [0.75, 0.5], [0.45, 0.15]]); },
  gravel: () => { car(-0.1, -0.1, 0.7); [[0.55, 0.0], [0.7, -0.15], [0.7, 0.15], [0.85, 0.0], [0.55, -0.3]].forEach((c) => ci(c[0], c[1], 0.07)); },
  rocks: () => { pg([[-0.8, -0.6], [-0.1, 0.5], [-0.8, 0.5]]); ci(0.1, -0.5, 0.17); ci(0.4, -0.15, 0.15); ci(0.2, 0.3, 0.14); pl([[0.55, 0.5], [0.85, 0.5]], 0.1); },
  slippery: () => { car(0, -0.2, 0.75); pl([[-0.55, 0.3], [-0.35, 0.45], [-0.15, 0.3], [0.05, 0.45]], 0.09); pl([[0.05, 0.55], [0.25, 0.7], [0.45, 0.55], [0.6, 0.7]], 0.09); },
  ice: () => { car(0, -0.25, 0.65); pl([[-0.6, 0.35], [-0.35, 0.55], [-0.1, 0.35], [0.15, 0.55], [0.4, 0.35]], 0.09); [[-0.1, 0.8], [0.4, 0.8]].forEach((c) => { pl([[c[0] - 0.12, c[1]], [c[0] + 0.12, c[1]]], 0.06); pl([[c[0], c[1] - 0.12], [c[0], c[1] + 0.12]], 0.06); }); },
  shoulder: (a) => { pl([[-0.9, 0.2], [0.2, 0.2], [0.7, 0.75]], 0.1); ctx.save(); ctx.translate(0.45, -0.1); ctx.rotate(0.35); car(0, 0, 0.6); ctx.restore(); if (a && a.soft) [[-0.5, 0.45], [-0.2, 0.55], [0.1, 0.5]].forEach((c) => ci(c[0], c[1], 0.07)); },
  quay: () => { pg([[-0.9, 0.15], [0.1, 0.15], [0.1, 0.8], [-0.9, 0.8]]); pl([[0.15, 0.4], [0.35, 0.3], [0.55, 0.4], [0.75, 0.3], [0.9, 0.4]], 0.08); pl([[0.2, 0.6], [0.4, 0.5], [0.6, 0.6], [0.8, 0.5]], 0.08); car(-0.45, -0.1, 0.6); },
  tunnel: () => arch(0, 0.05, 0.95),
  cross: (a) => { pl([[0, -0.85], [0, 0.85]], a.main ? 0.22 : 0.16); pl([[-0.85, 0], [0.85, 0]], a.main ? 0.08 : 0.16); },
  roundabout: () => { for (let i = 0; i < 3; i++) { const a0 = i * TAU / 3 + 0.5; ctx.strokeStyle = K; ctx.lineWidth = 0.13; ctx.beginPath(); ctx.arc(0, 0, 0.55, a0, a0 + 1.5); ctx.stroke(); head(Math.cos(a0 + 1.5) * 0.55, Math.sin(a0 + 1.5) * 0.55, a0 + 1.5 + Math.PI / 2, 0.28); } },
  lights: () => { rc0(0, 0, 0.62, 1.4); ci(0, -0.42, 0.18, "#d3262b"); ci(0, 0, 0.18, "#f6c600"); ci(0, 0.42, 0.18, "#2aa84a"); },
  pedx: () => { for (let i = 0; i < 4; i++) pg([[-0.85 + i * 0.45, 0.85], [-0.55 + i * 0.45, 0.85], [-0.35 + i * 0.45, 0.45], [-0.65 + i * 0.45, 0.45]]); sPerson(0, -0.1, 0.7, true); },
  peds: () => { sPerson(-0.2, 0.0, 0.8, true); sPerson(0.4, 0.1, 0.55, true); },
  children: () => { sPerson(-0.35, 0.1, 0.65, true); sPerson(0.25, 0.1, 0.5, true); pl([[-0.2, -0.05], [0.12, -0.05]], 0.07); },
  bikex: () => { bike(0, 0, 1.0); },
  sheep: () => sheep(0, 0, 0.9),
  cow: () => cow(0, 0, 0.85),
  horse: () => horse(-0.05, 0.05, 0.9),
  rider: () => { horse(-0.05, 0.2, 0.8); ci(0.05, -0.45, 0.12); pl([[0.05, -0.35], [0.05, -0.1]], 0.14); },
  reindeer: () => reindeer(-0.1, 0.1, 0.85),
  animal: () => reindeer(-0.1, 0.1, 0.85),
  twoway: () => { arrow([[-0.35, 0.8], [-0.35, -0.7]], 0.14); arrow([[0.35, -0.8], [0.35, 0.7]], 0.14); },
  plane: () => { pg([[0, -0.9], [0.12, -0.2], [0.85, 0.2], [0.85, 0.35], [0.12, 0.15], [0.1, 0.6], [0.35, 0.75], [0.35, 0.85], [0, 0.8], [-0.35, 0.85], [-0.35, 0.75], [-0.1, 0.6], [-0.12, 0.15], [-0.85, 0.35], [-0.85, 0.2], [-0.12, -0.2]]); },
  wind: () => { pl([[-0.5, 0.8], [-0.5, -0.6]], 0.1); pg([[-0.5, -0.6], [0.7, -0.4], [0.6, -0.1], [-0.5, -0.2]]); pl([[0.2, 0.3], [0.8, 0.3]], 0.07); pl([[0.0, 0.55], [0.7, 0.55]], 0.07); },
  other: () => { pg([[-0.1, -0.7], [0.1, -0.7], [0.07, 0.15], [-0.07, 0.15]]); ci(0, 0.45, 0.11); },
};
function rc0(x, y, w, h) { ctx.fillStyle = K; ctx.fillRect(x - w / 2, y - h / 2, w, h); }
