const red = (fn) => { K = RED; fn(); K = INK; };
const slash = () => { ctx.strokeStyle = RED; ctx.lineWidth = 0.16; ctx.beginPath(); ctx.moveTo(-0.62, -0.62); ctx.lineTo(0.62, 0.62); ctx.stroke(); };
const diag = () => { K = "#888"; [-0.35, 0, 0.35].forEach((q) => pl([[-0.55 + q, 0.6], [0.45 + q, -0.6]], 0.08)); K = INK; };
const vslash = (fn) => { ctx.save(); ctx.scale(0.8, 0.8); fn(); ctx.restore(); slash(); };
const num = (t) => utxt(t, 0, 0, t.length > 2 ? 0.7 : 0.95);
Object.assign(PIC, {
  giveOnc: () => { arrow([[0.3, 0.75], [0.3, -0.1]], 0.1); red(() => arrow([[-0.25, -0.75], [-0.25, 0.8]], 0.2)); },
  noEntryBar: () => {},
  veh_car: () => vslash(() => car(0, 0, 1.1)), veh_truck: () => vslash(() => truck(0, 0, 1.0)), veh_bus: () => vslash(() => bus(0, 0, 1.0)),
  veh_moto: () => vslash(() => moto(0, 0, 1.0)), veh_motor: () => vslash(() => { car(-0.35, 0.0, 0.7); moto(0.45, 0.05, 0.7); }), veh_bike: () => vslash(() => bike(0, 0, 1.0)),
  veh_horse: () => vslash(() => horse(0, 0.1, 1.0)), veh_ped: () => vslash(() => sPerson(0, 0, 1.2, true)),
  veh_snow: () => vslash(() => { pg([[-0.7, 0.15], [-0.6, -0.15], [0.1, -0.2], [0.5, -0.4], [0.7, -0.1], [0.4, 0.15]]); pl([[-0.7, 0.3], [0.5, 0.3]], 0.12); }),
  veh_tractor: () => vslash(() => { pg([[-0.5, -0.2], [0.1, -0.2], [0.1, 0.15], [-0.5, 0.15]]); pg([[0.1, -0.5], [0.35, -0.5], [0.35, 0.15], [0.1, 0.15]]); ci(-0.35, 0.25, 0.28); ci(0.3, 0.3, 0.15); }),
  lim: (a) => { if (a.k === "w") { arrow([[-0.1, -0.35], [-0.75, -0.35]], 0.09); arrow([[0.1, -0.35], [0.75, -0.35]], 0.09); pl([[-0.8, -0.55], [-0.8, -0.15]], 0.09); pl([[0.8, -0.55], [0.8, -0.15]], 0.09); utxt(a.t, 0, 0.35, 0.42); } else if (a.k === "h") { arrow([[-0.5, -0.1], [-0.5, -0.75]], 0.09); arrow([[-0.5, 0.1], [-0.5, 0.75]], 0.09); pl([[-0.7, -0.78], [-0.3, -0.78]], 0.09); pl([[-0.7, 0.78], [-0.3, 0.78]], 0.09); utxt(a.t, 0.25, 0, 0.42); } else utxt(a.t, 0, 0, 0.55); },
  noturn: (a) => { ctx.save(); if (a.flip) ctx.scale(-1, 1); arrow([[-0.3, 0.6], [-0.3, -0.1], [0.45, -0.1]], 0.15); ctx.restore(); slash(); },
  uturn: (a) => { ctx.strokeStyle = K; ctx.lineWidth = 0.15; ctx.beginPath(); ctx.moveTo(-0.3, 0.6); ctx.lineTo(-0.3, -0.1); ctx.arc(0, -0.1, 0.3, Math.PI, 0); ctx.lineTo(0.3, 0.2); ctx.stroke(); head(0.3, 0.3, Math.PI / 2, 0.3); if (a.slash) slash(); },
  overtake: (a) => { car(-0.3, 0.0, 0.8); red(() => car(0.4, 0.05, 0.8)); if (a.end) diag(); },
  speed: (a) => { num(a.t); if (a.end) diag(); },
  nostop: () => { red(() => { pl([[-0.55, -0.55], [0.55, 0.55]], 0.2); pl([[0.55, -0.55], [-0.55, 0.55]], 0.2); }); },
  noparking: () => { utxt("P", 0, 0, 1.0); slash(); },
  allclear: () => { pl([[-0.6, 0.6], [0.6, -0.6]], 0.14); },
  zone: (a) => { num(a.t); utxt("ZONE", 0, 0.62, 0.28); if (a.end) diag(); },
  mandArrow: (a) => { K = WHT; ctx.save(); ctx.rotate(a.r || 0); arrow([[0, 0.7], [0, -0.45]], 0.2); ctx.restore(); K = INK; },
  mandTurn: (a) => { K = WHT; ctx.save(); if (a.flip) ctx.scale(-1, 1); arrow([[-0.3, 0.6], [-0.3, -0.1], [0.45, -0.1]], 0.2); ctx.restore(); K = INK; },
  mandKeep: (a) => { K = WHT; ctx.save(); if (a.flip) ctx.scale(-1, 1); arrow([[0.5, -0.6], [-0.4, 0.55]], 0.22); ctx.restore(); K = INK; },
  mandRound: () => { K = WHT; PIC.roundabout(); K = INK; },
  mandBike: () => { K = WHT; bike(0, 0, 1.15); K = INK; },
  mandPed: () => { K = WHT; sPerson(0, 0, 1.2, true); K = INK; },
  mandHorse: () => { K = WHT; horse(0, 0.1, 1.15); K = INK; },
  mandPass: () => { K = WHT; ctx.save(); ctx.scale(0.8, 0.8); arrow([[-0.3, 0.6], [-0.3, -0.5]], 0.2); arrow([[0.4, -0.6], [0.4, 0.5]], 0.2); ctx.restore(); K = INK; },
  infoText: (a) => { K = WHT; utxt(a.t, 0, a.y || 0, a.fs || 1.0); K = INK; },
  infoPic: (a) => { K = WHT; PIC[a.p](a.a || {}); K = INK; },
  camera: () => { pg([[-0.8, -0.25], [0.35, -0.25], [0.35, 0.3], [-0.8, 0.3]]); pg([[0.4, -0.15], [0.85, -0.35], [0.85, 0.4], [0.4, 0.2]]); pl([[-0.3, 0.3], [-0.3, 0.75]], 0.1); },
  house: () => { pg([[-0.8, 0.0], [0, -0.7], [0.8, 0.0]]); rc0(0, 0.35, 1.2, 0.7); },
  passing: () => { pl([[-0.5, 0.8], [-0.5, -0.8]], 0.14); pl([[0.5, 0.8], [0.5, -0.8]], 0.14); pl([[-0.5, 0.2], [-0.9, 0.2]], 0.14); pl([[0.5, -0.4], [0.9, -0.4]], 0.0); },
  deadend: () => { utxt("T", 0, 0, 1.3); },
  star: () => {},
});
// ---- plates ----
function drawSignCode(code, c, size) {
  const d = SIGN[code]; if (!d) return;
  const r = size / 2, f = d.f || {};
  const picAt = (x, y, sc, ink) => { ctx.save(); ctx.translate(x, y); ctx.scale(sc, sc); K = ink || INK; PIC[d.pic](d.a || {}); K = INK; ctx.restore(); };
  const tri = (cx, cy, s, up, col) => { const h = s * 0.95, pts = up ? [[cx, cy - h], [cx + s * 1.1, cy + h * 0.9], [cx - s * 1.1, cy + h * 0.9]] : [[cx, cy + h], [cx + s * 1.1, cy - h * 0.9], [cx - s * 1.1, cy - h * 0.9]]; poly(pts, col); return pts; };
  ctx.save(); ctx.lineJoin = "round";
  if (d.cat === "warn") {
    const oy = d.plate ? -r * 0.35 : 0;
    tri(c[0], c[1] + oy + r * 0.05, r * 1.02, true, RED); tri(c[0], c[1] + oy + r * 0.2, r * 0.72, true, YEL);
    picAt(c[0], c[1] + oy + r * 0.22, r * 0.5);
    if (d.plate) {
      const py = c[1] + r * 1.12, pw = r * 2.4, ph = r * 0.5;
      rc([c[0], py], pw, ph, INK); rc([c[0], py], pw - r * 0.06, ph - r * 0.06, YEL);
      if (size >= 40) txt(d.plate, c[0], py + ph * 0.18, Math.max(8, Math.floor(r * (d.plate.length > 12 ? 0.2 : 0.26))), INK, "center", false);
    }
  } else if (d.cat === "yield") {
    tri(c[0], c[1] - r * 0.05, r * 1.02, false, RED); tri(c[0], c[1] - r * 0.2, r * 0.72, false, YEL);
  } else if (d.cat === "stop") {
    const pts = []; for (let i = 0; i < 8; i++) { const a = Math.PI / 8 + i * Math.PI / 4; pts.push([c[0] + Math.cos(a) * r * 1.12, c[1] + Math.sin(a) * r * 1.12]); }
    poly(pts, WHT); const p2 = pts.map((p) => [c[0] + (p[0] - c[0]) * 0.92, c[1] + (p[1] - c[1]) * 0.92]); poly(p2, RED);
    if (size >= 30) txt("STOP", c[0], c[1] + size * 0.11, Math.floor(size * 0.3), WHT, "center", false);
  } else if (d.cat === "prohib") {
    circ(c, r * 1.05, RED); circ(c, r * 0.78, YEL);
    if (d.pic === "noEntry") rc(c, r * 1.5, r * 0.35, WHT);
    else if (d.pic === "closed") {} else picAt(c[0], c[1], r * 0.62);
    if (d.pic === "noEntry") { circ(c, r * 1.05, RED); rc(c, r * 1.55, r * 0.34, WHT); }
  } else if (d.cat === "mand") {
    circ(c, r * 1.05, WHT); circ(c, r * 0.98, BLU); picAt(c[0], c[1], r * 0.62);
  } else if (d.cat === "prio") {
    const dm = (s, col) => poly([[c[0], c[1] - s], [c[0] + s, c[1]], [c[0], c[1] + s], [c[0] - s, c[1]]], col);
    dm(r * 1.3, INK); dm(r * 1.2, WHT); dm(r * 0.98, YEL);
    if (d.pic === "end") { ctx.save(); ctx.beginPath(); ctx.moveTo(c[0], c[1] - r * 0.98); ctx.lineTo(c[0] + r * 0.98, c[1]); ctx.lineTo(c[0], c[1] + r * 0.98); ctx.lineTo(c[0] - r * 0.98, c[1]); ctx.closePath(); ctx.clip(); ctx.strokeStyle = INK; ctx.lineWidth = Math.max(1, r * 0.07); [-0.45, 0, 0.45].forEach((o) => { ctx.beginPath(); ctx.moveTo(c[0] - r * 0.8 + o * r, c[1] + r * 0.8); ctx.lineTo(c[0] + r * 0.8 + o * r - r * 0.9, c[1] - r * 0.8); ctx.stroke(); }); ctx.restore(); }
  } else if (d.cat === "prioOnc") {
    rc(c, r * 2.1, r * 2.1, WHT); rc(c, r * 1.95, r * 1.95, BLU);
    ctx.save(); ctx.translate(c[0], c[1]); ctx.scale(r * 0.62, r * 0.62); K = WHT; arrow([[-0.3, 0.75], [-0.3, -0.7]], 0.2); red(() => arrow([[0.35, -0.55], [0.35, 0.55]], 0.12)); ctx.restore();
  } else {
    rc(c, r * 2.2, r * 1.8, WHT); rc(c, r * 2.1, r * 1.7, BLU); picAt(c[0], c[1], r * 0.62, WHT);
  }
  ctx.restore();
}
