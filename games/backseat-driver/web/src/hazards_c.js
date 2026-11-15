// Animals reuse the sign silhouettes, in colour: they draw in unit scale at a point.
function herd(kind, s, hc, et, col, n, spread) {
  for (let k = 0; k < n; k++) {
    const sk = s * (1 - 0.05 * (k % 3)), x = -spread + k * (2 * spread / (n - 1 || 1)) + (hc - 1) * 700, p = P(x, sk);
    const bob = Math.abs(Math.sin(et * 4 + k * 1.3)) * 6 * sk, u = sk * 170;
    K = col; ctx.save(); ctx.translate(0, -bob);
    if (kind === "sheep") { sheep(p[0], p[1] - u * 0.6, u); circ([p[0] + u * 0.42, p[1] - u * 0.65], u * 0.1, "#2a2a2a"); }
    else if (kind === "horse") horse(p[0], p[1] - u * 0.65, u);
    else cow(p[0], p[1] - u * 0.6, u);
    ctx.restore(); K = INK;
  }
}
HAZ.sheep = (s, hc, et) => herd("sheep", s, hc, et, "#f4f1ea", 7, 430);
HAZ.horse = (s, hc, et) => herd("horse", s, hc, et, "#8a5a2b", 3, 220);
HAZ.cow = (s, hc, et) => herd("cow", s, hc, et, "#e8e4dc", 2, 170);
HAZ.cyclist = (s, hc, et) => {
  const p = P((hc - 1) * 650, s), u = s * 200;
  K = "#222"; bike(p[0], p[1] - u * 0.3, u); K = INK;
  rc(o(p, 0, -u * 0.78, 1), u * 0.28, u * 0.4, "#3cd0a0"); circ(o(p, 0, -u * 1.08, 1), u * 0.12, "#f1c9a5"); el(o(p, 0, -u * 1.15, 1), u * 0.14, u * 0.08, "#d62828");
};
HAZ.steep = (s, hc, et, bad) => {
  if (bad) for (let k = 0; k < 8; k++) { const t = fpos(et * 0.7 + k * 0.13, 1); circ([W / 2 - 180 + k * 50 + Math.sin(et + k) * 12, 560 - t * 260], 18 + t * 30, `rgba(180,180,190,${0.5 - t * 0.4})`); }
  const y = P(0, s * 0.4)[1]; line([W / 2 - 560 * s * 0.4, y], [W / 2 + 560 * s * 0.4, y], "rgba(255,255,255,0.35)", 3);
};
HAZ.narrow = (s, hc) => {
  const k = clamp(hc, 0, 1), off = 560 - 290 * k;
  [-1, 1].forEach((sd) => { poly([P(sd * off, s), P(sd * (off + 340), s), P(sd * (off + 340), s * 0.4), P(sd * off, s * 0.4)], "#9a9aa2"); for (let i = 0; i < 6; i++) poly([P(sd * off, s * (0.4 + i * 0.1)), P(sd * (off - 30), s * (0.4 + i * 0.1)), P(sd * (off - 30), s * (0.44 + i * 0.1)), P(sd * off, s * (0.44 + i * 0.1))], i % 2 ? "#d3262b" : "#fff"); });
};
HAZ.work = (s, hc, et) => {
  for (let k = 0; k < 7; k++) { const p = P(-420 + k * 140, s * (1 - 0.02 * k)), u = s; poly([o(p, 0, -90, u), o(p, 40, 0, u), o(p, -40, 0, u)], "#ff8a1f"); rc(o(p, 0, -50, u), 50 * u, 14 * u, "#fff"); }
  const p = P(250, s); sPerson(p[0], p[1] - 160 * s, 180 * s, 0); rc(o(p, 130, -60, s), 220 * s, 120 * s, "#f2b81f"); rc(o(p, 130, -150, s), 90 * s, 70 * s, "#a8d8f0");
};
HAZ.gravel = (s, hc, et) => { for (let k = 0; k < 40; k++) { const t = fpos(et * 1.2 + k * 0.071, 1), x = ((k * 97) % 700) - 350; circ(P(x, s * (0.5 + t * 0.7)), 4 + t * 8, "#b8a48a"); } };
HAZ.edge = (s, hc, et, bad) => { poly([P(300, s), P(1400, s), P(1400, s * 0.3), P(300, s * 0.3)], "#4a3d30"); for (let k = 0; k < 6; k++) rc(o(P(300, s * (0.4 + k * 0.1)), 0, -30, s), 10 * s, 60 * s, "#d8d8d8"); if (bad) el(P(420, s * 0.8), 120 * s, 30 * s, "#1a1a22"); };
HAZ.tunnel = (s, hc) => { const gp = P(0, s * 0.8); ctx.fillStyle = "#6b6e75"; ctx.fillRect(0, gp[1] - 440 * s, W, 440 * s + 8); ctx.fillStyle = "#07070a"; ctx.beginPath(); ctx.moveTo(gp[0] - 340 * s, gp[1]); ctx.lineTo(gp[0] - 340 * s, gp[1] - 220 * s); ctx.arc(gp[0], gp[1] - 220 * s, 340 * s, Math.PI, 0); ctx.lineTo(gp[0] + 340 * s, gp[1]); ctx.fill(); for (let k = 0; k < 4; k++) circ([gp[0], gp[1] - 80 * s - k * 40 * s], 6 * s, "#ffd21f"); };
HAZ.cross = (s, hc, et) => {
  const ya = P(0, s * 0.9)[1], yb = P(0, s * 1.1)[1]; poly([[0, ya], [W, ya], [W, yb], [0, yb]], "#55555c");
  const p = P(-(1 - hc) * 1500, s), u = s; rc(o(p, 0, -60, u), 360 * u, 80 * u, "#d62828"); rc(o(p, 20, -125, u), 190 * u, 60 * u, "#a8d8f0"); [-110, 110].forEach((wx) => circ(o(p, wx, -22, u), 32 * u, "#0e0e12"));
};
HAZ.roundabout = (s, hc, et) => {
  const c = P(0, s * 0.85); el(c, 420 * s, 90 * s, "#55555c"); el(o(c, 0, -6, s), 230 * s, 46 * s, "#4c9a3c"); circ(o(c, 0, -70, s), 40 * s, "#2f7a34"); rc(o(c, 0, -20, s), 14 * s, 60 * s, "#5a3d24");
  const a = et * 0.9, q = [c[0] + Math.cos(a) * 330 * s, c[1] + Math.sin(a) * 62 * s]; rc(q, 120 * s, 40 * s, "#3c8de8");
};
HAZ.lights = (s, hc, et) => {
  const b = P(560, s), u = s; line(b, o(b, 0, -430, u), "#555", 16 * u); rc(o(b, 0, -480, u), 90 * u, 230 * u, "#111");
  const ph = hc < 0.35 ? 2 : hc < 0.6 ? 1 : 0; [0, 1, 2].forEach((i) => circ(o(b, 0, -540 + i * 60, u), 24 * u, ["#d62828", "#f6c600", "#2aa84a"][i] + (ph === i ? "" : "55")));
  poly([P(-520, s * 1.12), P(520, s * 1.12), P(520, s * 1.16), P(-520, s * 1.16)], "#fff");
};
HAZ.plane = (s, hc, et) => { const t = clamp(hc, 0, 1), x = lerp(W + 200, -200, fpos(t * 1.0, 1)), y = 90 + 60 * t, sz = 60 + 220 * t; K = "#e8ecff"; ctx.save(); ctx.translate(x, y); ctx.scale(sz, sz); ctx.rotate(-Math.PI / 2); PIC.plane(); ctx.restore(); K = INK; };
HAZ.wind = (s, hc, et) => {
  for (let k = 0; k < 14; k++) { const t = fpos(et * 1.5 + k * 0.17, 1), y = 140 + (k * 53) % 400; line([W - t * (W + 300), y], [W - t * (W + 300) + 120, y - 6], "rgba(255,255,255,0.55)", 3); }
  const x = W - fpos(et * 0.25 + 0.1, 1) * (W + 300), y = 430 + Math.abs(Math.sin(et * 5)) * -80; stk(x, y, 70, 8, "#222"); ctx.save(); ctx.beginPath(); ctx.arc(x, y, 62, 0, TAU); ctx.fillStyle = "#1c3a6b"; ctx.fill(); ctx.restore();
};
HAZ.none = () => {};
