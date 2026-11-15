const HAZ = {};
function zebra(s) {
  for (let k = 0; k < 9; k++) {
    const x = -480 + k * 120;
    poly([P(x - 35, s * 0.94), P(x + 35, s * 0.94), P(x + 35, s * 1.06), P(x - 35, s * 1.06)], "#f2f2f2");
  }
}
HAZ.ducks = (s, hc, et) => {
  const orange = "#f08a1c";
  for (let k = 0; k < 7; k++) {
    const sk = s * (1 - 0.05 * (k % 3)), x = -420 + k * 140 + (hc - 1) * 650;
    const hop = Math.abs(Math.sin(et * 6 + k * 1.7)) * 16 * sk;
    const p = o(P(x, sk), 0, -hop, 1), u = sk * 1.5;
    line(o(p, -8, -20, u), o(p, -8, 0, u), orange, 4 * u);
    line(o(p, 10, -20, u), o(p, 10, 0, u), orange, 4 * u);
    el(o(p, 0, -36, u), 38 * u, 26 * u, "#f2eedd");
    el(o(p, -8, -40, u), 22 * u, 13 * u, "#d8d2bc");
    poly([o(p, -34, -44, u), o(p, -56, -62, u), o(p, -30, -30, u)], "#f2eedd");
    circ(o(p, 30, -64, u), 17 * u, "#2d7a3a");
    el(o(p, 50, -60, u), 14 * u, 6 * u, orange);
    circ(o(p, 34, -68, u), 3 * u, "#000");
  }
};
HAZ.gator = (s, hc, et) => {
  const u = s, p = P((hc - 1) * 750, s), gr = "#3f7f3a", dk = "#2c5c2a", wag = Math.sin(et * 3) * 25;
  poly([o(p, -250, -90, u), o(p, -540, -20 + wag, u), o(p, -250, -20, u)], gr);
  [-170, -80, 120, 200].forEach((lx, k) => rc(o(p, lx, -16 + Math.sin(et * 4 + k) * 5, u), 44 * u, 40 * u, dk));
  el(o(p, 0, -52, u), 290 * u, 52 * u, gr);
  el(o(p, 0, -30, u), 250 * u, 26 * u, "#9bc27a");
  for (let k = 0; k < 9; k++) { const rx = -230 + k * 55; poly([o(p, rx, -96, u), o(p, rx + 22, -96, u), o(p, rx + 11, -118, u)], dk); }
  el(o(p, 300, -44, u), 135 * u, 34 * u, gr);
  line(o(p, 190, -34, u), o(p, 430, -34, u), "#1c3a1b", 5 * u);
  for (let k = 0; k < 7; k++) { const tx = 220 + k * 30; poly([o(p, tx, -33, u), o(p, tx + 14, -33, u), o(p, tx + 7, -14, u)], "#fff"); }
  circ(o(p, 270, -86, u), 20 * u, "#f3d23a");
  rc(o(p, 272, -86, u), 6 * u, 24 * u, "#000");
};
HAZ.walker = (s, hc, et) => {
  zebra(s);
  const h = 190 * s, p = P((hc - 1) * 520, s);
  person(p, h, "#7a5a3a", "#e8c4a0", et * 2, "#f0f0f0");
  const fx = o(p, h * 0.3, 0, 1), steel = "#b9bec8";
  line(fx, o(fx, 0, -h * 0.5, 1), steel, h * 0.025);
  line(o(fx, -h * 0.16, 0, 1), o(fx, -h * 0.16, -h * 0.5, 1), steel, h * 0.025);
  line(o(fx, -h * 0.16, -h * 0.5, 1), o(fx, 0, -h * 0.5, 1), steel, h * 0.03);
};
HAZ.kids = (s, hc, et) => {
  const shirts = ["#e8453c", "#3c8de8", "#f2c230"];
  for (let k = 0; k < 3; k++) {
    const x = -330 + k * 150 + (hc - 1) * 600;
    person(P(x, s * (1 - 0.04 * k)), 120 * s, shirts[k], "#f1c9a5", et * 9 + k, "#5a3a1a");
  }
  const bounce = Math.abs(Math.sin(et * 5)) * 90 * s;
  const bp = o(P(110 + (hc - 1) * 600, s), 0, -22 * s - bounce, 1);
  circ(bp, 22 * s, "#e8453c");
  line(o(bp, -22, 0, s), o(bp, 22, 0, s), "#fff", 5 * s);
};
HAZ.stop = (s, hc) => {
  const ya = P(0, s * 0.9)[1], yb = P(0, s * 1.1)[1];
  poly([[0, ya], [W, ya], [W, yb], [0, yb]], "#55555c");
  poly([P(-520, s * 1.15), P(520, s * 1.15), P(520, s * 1.19), P(-520, s * 1.19)], "#fff");
  const u = s, p = P((1 - hc) * 1500, s);
  rc(o(p, 60, -75, u), 620 * u, 30 * u, "#2b2b33");
  for (let row = 0; row < 3; row++) for (let k = 0; k < 5; k++) {
    const lx = -180 + k * 120 + (row % 2 === 1 ? 20 : 0);
    rc(o(p, lx + 60, -105 - row * 50, u), 118 * u, 48 * u, "#8a5a2b");
    el(o(p, lx + 118, -105 - row * 50, u), 8 * u, 22 * u, "#d9b27a");
  }
  rc(o(p, -290, -120, u), 150 * u, 160 * u, "#c0392b");
  rc(o(p, -310, -150, u), 70 * u, 60 * u, "#a8d8f0");
  [-290, -120, 100, 300].forEach((wx) => circ(o(p, wx, -34, u), 36 * u, "#141418"));
};
HAZ.train = (s, hc, et) => {
  const y1 = P(0, s * 0.92)[1], y2 = P(0, s * 1.08)[1];
  poly([[0, y1], [W, y1], [W, y2], [0, y2]], "#4a3f35");
  line([0, P(0, s * 0.97)[1]], [W, P(0, s * 0.97)[1]], "#b9bec8", 4 * s);
  line([0, P(0, s * 1.03)[1]], [W, P(0, s * 1.03)[1]], "#b9bec8", 4 * s);
  const u = s, p = P((1 - hc) * 2200, s);
  rc(o(p, -200, -140, u), 480 * u, 230 * u, "#1d1d22");
  rc(o(p, -200, -80, u), 480 * u, 26 * u, "#f2c230");
  rc(o(p, -380, -190, u), 90 * u, 70 * u, "#a8d8f0");
  circ(o(p, -445, -105, u), 22 * u, "#fff2a0");
  const wag = ["#6b2f2f", "#2f4f6b", "#4f4f4f", "#2f6b45"];
  for (let k = 0; k < 4; k++) rc(o(p, 80 + k * 460 + 150, -150, u), 440 * u, 250 * u, wag[k]);
  [-340, -80, 140, 400, 700].forEach((wx) => circ(o(p, wx, -28, u), 28 * u, "#0e0e12"));
  const on = Math.sin(et * 9) > 0;
  [-610, 610].forEach((sx) => {
    const b = P(sx, s);
    line(b, o(b, 0, -300, u), "#d8d8d8", 12 * u);
    circ(o(b, sx < 0 ? -26 : 26, -300, u), 20 * u, on ? "#ff2a2a" : "#6a1a1a");
  });
};
HAZ.kayak = (s) => {
  const gp = P(0, s), top = gp[1] - 235 * s;
  rect(0, top - 130 * s, W, 130 * s, "#8a8478");
  rect(0, top, P(-430, s)[0], gp[1] - top + 140 * s, "#77716a");
  rect(P(430, s)[0], top, W, gp[1] - top + 140 * s, "#77716a");
  for (let k = 0; k < 5; k++) { const y = top - 130 * s + k * 26 * s; line([0, y], [W, y], "#5f5a54", 3 * s); }
  signPlate("rect", [W / 2, top + 52 * s], 70 * s, "#ffd21f", "#111", "LOW\n8'6\"");
};
HAZ.deer = (s, hc, et) => {
  for (let k = 0; k < 2; k++) {
    const u = s * (1 - 0.12 * k), p = P((hc - 1) * 420 - 160 + k * 330, u), brown = "#8a5a2b";
    [-70, -42, 48, 78].forEach((lx) => line(o(p, lx, -120, u), o(p, lx, 0, u), "#6a4320", 12 * u));
    el(o(p, 0, -150, u), 105 * u, 52 * u, brown);
    circ(o(p, -102, -165, u), 12 * u, "#fff");
    poly([o(p, 60, -170, u), o(p, 100, -170, u), o(p, 135, -270, u), o(p, 105, -272, u)], brown);
    el(o(p, 136, -276, u), 38 * u, 20 * u, brown);
    line(o(p, 125, -290, u), o(p, 105, -370, u), "#d8c8a0", 6 * u);
    line(o(p, 110, -340, u), o(p, 60, -380, u), "#d8c8a0", 5 * u);
    const glow = 0.55 + 0.25 * Math.sin(et * 4 + k);
    circ(o(p, 150, -282, u), 20 * u, `rgba(255,242,102,${glow * 0.5})`);
    circ(o(p, 150, -282, u), 8 * u, "#ffff99");
  }
};
