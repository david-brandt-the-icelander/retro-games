HAZ.police = (s, hc, et, bad) => {
  const u = s, p = P(470, s);
  rc(o(p, 0, -60, u), 380 * u, 70 * u, "#f2f2f2");
  rc(o(p, 0, -35, u), 380 * u, 34 * u, "#16161c");
  rc(o(p, -20, -120, u), 170 * u, 50 * u, "#16161c");
  rc(o(p, -20, -120, u), 140 * u, 34 * u, "#a8d8f0");
  [-120, 120].forEach((wx) => circ(o(p, wx, -22, u), 30 * u, "#0e0e12"));
  const fl = (hc > 0.55 || bad) && Math.sin(et * 14) > 0;
  circ(o(p, -50, -154, u), 14 * u, fl ? "#ff2a2a" : "#5a1a1a");
  circ(o(p, 10, -154, u), 14 * u, fl ? "#1a2a5a" : "#2a6aff");
  const bx = P(330, s);
  rc(o(bx, 0, -120, u), 10 * u, 120 * u, "#555");
  rc(o(bx, 230, -120, u), 10 * u, 120 * u, "#555");
  rc(o(bx, 115, -170, u), 260 * u, 120 * u, "#2f7a3a");
  if (s > 0.2) txt("JOE'S", bx[0] + 115 * u, bx[1] - 150 * u, Math.floor(34 * u), "#fff", "center");
};
HAZ.bridgeout = (s, hc, et, bad) => {
  const ya = P(0, s * 0.5)[1], yb = P(0, s)[1];
  poly([[0, ya], [W, ya], [W, yb], [0, yb]], "#2f7fc0");
  for (let k = 0; k < 6; k++) {
    const y = ya + (yb - ya) * (k + 0.5) / 6;
    for (let j = 0; j < 8; j++) { const x = j * 170 + fpos(et * 40 + k * 55, 170); line([x, y], [x + 60 * s, y], "rgba(255,255,255,0.5)", 3 * s); }
  }
  for (let k = 0; k < 8; k++) rc(o(P(-490 + k * 140, s * 1.05), 0, -50, s), 100 * s, 36 * s, k % 2 === 0 ? "#ff8a1f" : "#fff");
  if (!bad && hc > 1) {
    const fy = yb - 90 * s - Math.abs(Math.sin(et * 3)) * 60 * s, fx = W / 2;
    el([fx + 120 * s, fy], 36 * s, 16 * s, "#f08a3a");
    poly([[fx + 150 * s, fy], [fx + 180 * s, fy - 16 * s], [fx + 180 * s, fy + 16 * s]], "#f08a3a");
  }
};
HAZ.rocks = (s, hc, et, bad, swerve) => {
  for (let k = 0; k < 6; k++) {
    const f = fpos(et * 0.9 + k * 0.37, 1), x = -520 + k * 210;
    el([P(x, s * 0.8)[0], lerp(-30, P(0, s * 0.8)[1] - 20, f)], 12 + 18 * s, 10 + 14 * s, "#6b6e75");
  }
  const gp = P(lerp(0, 380, swerve), s), t = clamp(hc, 0, 1), r = 130 * s;
  const bp = [gp[0], lerp(-250, gp[1] - r * 0.9, t * t)];
  el(bp, r, r * 0.9, "#7d7f86");
  el(o(bp, -r * 0.2, -r * 0.2, 1), r * 0.65, r * 0.55, "#9a9ca4");
  if (t > 0.7) [-0.32, 0.32].forEach((sx) => {
    circ(o(bp, sx * r, -r * 0.1, 1), r * 0.18, "#fff");
    circ(o(bp, sx * r + r * 0.03, -r * 0.08, 1), r * 0.08, "#000");
  });
};
HAZ.gas = (s, hc, et, bad) => {
  const u = s, p = P(700, s);
  rc(o(p, 0, -130, u), 420 * u, 260 * u, "#f2eadb");
  rc(o(p, 0, -275, u), 460 * u, 40 * u, "#c0392b");
  rc(o(p, -80, -70, u), 130 * u, 140 * u, "#a8d8f0");
  rc(o(p, -380, -70, u), 70 * u, 140 * u, "#c0392b");
  rc(o(p, -480, -70, u), 70 * u, 140 * u, "#c0392b");
  signPlate("rect", o(P(500, s), 0, -360, u), 120 * u, "#1f6fd1", "#fff", "GAS");
  if (bad) for (let k = 0; k < 3; k++) {
    const a = et * 0.7 + k * 2.1, v = [W / 2 + Math.cos(a) * 220, 120 + Math.sin(a * 1.3) * 40 + k * 28];
    line(v, o(v, -14, -9, 1), "#221a1a", 3); line(v, o(v, 14, -9, 1), "#221a1a", 3);
  }
};
HAZ.curve = (s) => {
  const p = P(0, s), u = s;
  rc(o(p, 0, -330, u), 700 * u, 250 * u, "#ffd21f");
  ctx.strokeStyle = "#111"; ctx.lineWidth = Math.max(1, 6 * u);
  ctx.strokeRect(p[0] - 350 * u, p[1] - 455 * u, 700 * u, 250 * u);
  for (let k = 0; k < 3; k++) {
    const cx = -190 + k * 190;
    poly([[cx - 70, -420], [cx - 30, -420], [cx + 50, -330], [cx - 30, -240], [cx - 70, -240], [cx + 10, -330]].map((q) => o(p, q[0], q[1], u)), "#111");
  }
  rc(o(p, 0, -150, u), 20 * u, 140 * u, "#555");
};
HAZ.wrongway = (s) => {
  const u = s, p = P(-120, s);
  el(o(p, 0, -200, u), 340 * u, 260 * u, "rgba(255,255,204,0.18)");
  rc(o(p, 0, -170, u), 380 * u, 300 * u, "#3c4a5c");
  rc(o(p, 0, -270, u), 300 * u, 80 * u, "#a8d8f0");
  rc(o(p, 0, -110, u), 260 * u, 60 * u, "#1a1a20");
  [-140, 140].forEach((sx) => circ(o(p, sx, -170, u), 38 * u, "#fffbd0"));
  rc(o(p, 0, -20, u), 400 * u, 40 * u, "#141418");
};
HAZ.ice = (s, hc, et) => {
  const p = P(0, s);
  el(o(p, 0, -8, s), 560 * s, 70 * s, "#b6dff2");
  el(o(p, -60, -14, s), 380 * s, 40 * s, "#d8f0fb");
  for (let k = 0; k < 5; k++) {
    const tw = 0.5 + 0.5 * Math.sin(et * 4 + k * 1.9), sp = o(p, -300 + k * 150, -20 - 8 * (k % 2), s), c = `rgba(255,255,255,${tw})`;
    line(o(sp, -10, 0, s), o(sp, 10, 0, s), c, 3 * s); line(o(sp, 0, -10, s), o(sp, 0, 10, s), c, 3 * s);
  }
  const cp = P(-650, s);
  el(o(cp, 0, -60, s), 90 * s, 46 * s, "#fff");
  circ(o(cp, -30, -70, s), 16 * s, "#222"); circ(o(cp, 30, -50, s), 14 * s, "#222");
  el(o(cp, 96, -88, s), 32 * s, 22 * s, "#fff");
};
HAZ.bus = (s, hc, et) => {
  const u = s, p = P(360, s);
  rc(o(p, 0, -130, u), 760 * u, 200 * u, "#f2b81f");
  rc(o(p, 0, -150, u), 760 * u, 18 * u, "#1a1a1a");
  for (let k = 0; k < 6; k++) rc(o(p, -300 + k * 120, -190, u), 90 * u, 60 * u, "#a8d8f0");
  [-230, 240].forEach((wx) => circ(o(p, wx, -30, u), 40 * u, "#0e0e12"));
  const on = Math.sin(et * 8) > 0;
  circ(o(p, -340, -250, u), 14 * u, on ? "#ff2a2a" : "#5a1a1a");
  circ(o(p, 340, -250, u), 14 * u, on ? "#5a1a1a" : "#ff2a2a");
  signPlate("octagon", o(p, -420, -170, u), 90 * u, "#d62828", "#fff", "STOP");
  const shirts = ["#e8453c", "#3c8de8", "#2fb36b", "#c06ae0"];
  for (let k = 0; k < 4; k++) person(P(-330 + k * 120 + (hc - 1) * 500, s * 1.02), 120 * s, shirts[k], "#f1c9a5", et * 6 + k, "#3a2a1a");
};
HAZ.minspeed = () => {};
HAZ.bump = (s) => {
  for (let k = 0; k < 12; k++) {
    const x0 = -540 + k * 90;
    poly([P(x0, s * 0.95), P(x0 + 90, s * 0.95), P(x0 + 90, s * 1.05), P(x0, s * 1.05)], k % 2 ? "#1a1a1a" : "#ffd21f");
  }
  const a = P(-540, s * 0.95), b = P(540, s * 0.95), h = 26 * s;
  poly([[a[0], a[1]], [a[0] + 60 * s, a[1] - h], [b[0] - 60 * s, b[1] - h], [b[0], b[1]]], "rgba(255,210,31,0.35)");
};
