function drawWorld() {
  const g = ctx.createLinearGradient(0, 0, 0, HORIZON);
  g.addColorStop(0, rgb(G.top)); g.addColorStop(1, rgb(G.bot));
  ctx.fillStyle = g; ctx.fillRect(0, 0, W, HORIZON);
  const night = Math.max(...G.top) / 255 < 0.35;
  circ([980, 120], 46, night ? "#e8ecff" : "rgba(255,242,179,0.9)");
  const hill = rgb(G.ground, 0.75);
  circ([220, HORIZON + 30], 170, hill); circ([760, HORIZON + 60], 220, rgb(lighten(G.ground.map((v) => v * 0.75), 0.05)));
  circ([1120, HORIZON + 30], 150, hill);
  rect(0, HORIZON, W, H - HORIZON, rgb(G.ground));
  const ext = (H - HORIZON) / (ROAD_B - HORIZON);
  poly([[W / 2 - 2, HORIZON], [W / 2 + 2, HORIZON], [W / 2 + 575 * ext, H], [W / 2 - 575 * ext, H]], "#3b3b42");
  line([W / 2 - 1, HORIZON], [W / 2 - 520 * ext, H], "#ebebeb", 6);
  line([W / 2 + 1, HORIZON], [W / 2 + 520 * ext, H], "#ebebeb", 6);
  for (let i = 0; i < 10; i++) {
    const d = fpos(G.scroll + i / 10, 1), s0 = scaleOf(d), s1 = scaleOf(Math.min(d + 0.045, 1));
    poly([P(-14, s0), P(14, s0), P(14, s1), P(-14, s1)], "#e8e8e8");
  }
  const items = [];
  for (const side of [-1, 1]) for (let i = 0; i < 7; i++) items.push([fpos(G.scroll + i / 7 + (side > 0 ? 0.07 : 0), 1), side, i]);
  items.sort((a, b) => a[0] - b[0]);
  const fol = rgb(G.ground, 0.6), fol2 = rgb(lighten(G.ground.map((v) => v * 0.6), 0.12));
  for (const it of items) {
    const s = scaleOf(it[0]), b = P(it[1] * (720 + (it[2] % 3) * 90), s);
    rect(b[0] - 14 * s, b[1] - 150 * s, 28 * s, 150 * s, "#5a3d24");
    circ([b[0], b[1] - 210 * s], 90 * s, fol); circ([b[0] - 30 * s, b[1] - 230 * s], 55 * s, fol2);
  }
}
function drawEvent() {
  const ev = G.ev, sH = scaleOf(clamp(G.dep, 0, 1)), bad = G.state === "result" && !G.good;
  HAZ[ev.id](sH, G.hc, G.et, bad, G.swerve);
  if (G.signT < 1.2) {
    const ss = scaleOf(G.signT), gp = P(640, ss), top = o(gp, 0, -330, ss);
    line(gp, top, "#9a9aa2", Math.max(2, 10 * ss));
    signPlate(ev.shape, top, 150 * ss, hexc(ev.c), hexc(ev.ink), ev.glyph);
  }
}
function drawDriver() {
  const skin = "#e0b090", ink = "#2a1a1a", hp = [255, 425 + Math.sin(G.anim * 2) * 2];
  poly([[120, 600], [140, 520], [200, 478], [310, 478], [370, 520], [390, 600]], "#5a4a8a");
  rc([255, 468], 30, 26, skin);
  circ(hp, 46, skin); circ(o(hp, -46, 6, 1), 9, skin); circ(o(hp, 46, 6, 1), 9, skin);
  el(o(hp, 0, -26, 1), 50, 28, "#3a2a1a");
  if (G.mood === "scared") {
    [-18, 18].forEach((sx) => { circ(o(hp, sx, -5, 1), 11, "#fff"); circ(o(hp, sx + Math.sin(G.anim * 30) * 2, -5, 1), 3.5, "#000"); });
    line(o(hp, -30, -22, 1), o(hp, -8, -28, 1), ink, 3); line(o(hp, 30, -22, 1), o(hp, 8, -28, 1), ink, 3);
    el(o(hp, 0, 26, 1), 11, 15, "#3a1010");
  } else {
    rc(o(hp, 0, -4, 1), 80, 15, "#0c0c10");
    if (G.mood === "happy") arc(o(hp, 0, 18, 1), 15, 0.2, Math.PI - 0.2, ink, 3);
    else line(o(hp, -12, 26, 1), o(hp, 12, 26, 1), ink, 3);
  }
  arc([255, 612], 94, Math.PI, TAU, "#1d1d22", 14);
  circ([165, 585], 15, skin); circ([345, 585], 15, skin);
  if (G.line && G.state !== "over") {
    const h = bubble(24, 150, G.line, 232, "#fff8e0", "#222", 18), by = 150 + h;
    poly([[80, by - 3], [140, by - 3], [205, 372]], "#fff8e0");
    line([80, by - 3], [205, 372], "#222", 3); line([140, by - 3], [205, 372], "#222", 3);
  }
}
function drawCabin() {
  const dark = "#17171c";
  rect(-20, -23, W + 40, 54, dark);
  poly([[-20, -20], [110, -20], [40, ROAD_B], [-20, ROAD_B]], dark);
  poly([[W + 20, -20], [W - 110, -20], [W - 40, ROAD_B], [W + 20, ROAD_B]], dark);
  rc([W / 2, 66], 220, 58, "#0f0f13"); rc([W / 2, 66], 206, 46, "#2d4054");
  line([W / 2 - 60, 84], [W / 2 + 60, 54], "rgba(230,230,230,0.5)", 3);
  G.cracks.forEach((segs) => segs.forEach((sg) => {
    ctx.strokeStyle = "rgba(255,255,255,0.75)"; ctx.lineWidth = 2;
    ctx.beginPath(); ctx.moveTo(sg[0][0], sg[0][1]); ctx.lineTo(sg[1][0], sg[1][1]); ctx.lineTo(sg[2][0], sg[2][1]); ctx.stroke();
  }));
  drawDriver();
  rc([W / 2, 660], W + 40, 130, "#23232b");
  line([0, ROAD_B], [W, ROAD_B], "#3d3d4a", 4);
}
function drawHud() {
  if (G.state === "title") return;
  txt("SCORE", 22, 34, 16, "#cfd8ff"); txt(String(G.score), 22, 66, 30, "#fff");
  txt("BEST " + G.best, 22, 90, 16, "#cfd8ff");
  if (G.streak >= 2) txt("STREAK x" + G.streak, 22, 114, 18, "#ffd21f");
  txt("STRIKES", W - 20, 30, 16, "#ffd0d0", "right");
  for (let i = 0; i < MAX_STRIKES; i++) {
    const cx = W - 36 - i * 44, used = MAX_STRIKES - 1 - i < G.strikes;
    circ([cx, 62], 17, used ? "#d62828" : "rgba(0,0,0,0.5)"); arc([cx, 62], 17, 0, TAU, "#fff", 2);
    if (used) { line([cx - 8, 54], [cx + 8, 70], "#fff", 4); line([cx + 8, 54], [cx - 8, 70], "#fff", 4); }
  }
  const ev = G.ev;
  if (!ev) return;
  panel(290, 10, 700, 114, "rgba(13,13,26,0.86)", "#e8e8f0");
  signPlate(ev.shape, [352, 64], 62, hexc(ev.c), hexc(ev.ink), ev.glyph);
  txt(ev.name, 412, 44, 26, "#ffd21f");
  mtxt(ev.scene, 412, 72, 560, 17, "#fff", "left", false);
  if (G.state === "sign") {
    rect(300, 108, 680, 8, "rgba(0,0,0,0.6)");
    const c = G.t; rect(300, 108, 680 * (1 - G.t), 8, `rgb(${Math.round(lerp(74, 232, c))},${Math.round(lerp(194, 69, c))},${Math.round(lerp(107, 60, c))})`);
  } else if (G.state === "result") {
    const hgt = wrap(G.text, 660, 21, false).length * 21 * 1.28;
    panel(290, 134, 700, hgt + 76, G.good ? "rgba(20,107,51,0.95)" : "rgba(140,18,18,0.95)", "#fff");
    txt(G.head, 312, 174, 32, "#fff");
    mtxt(G.text, 312, 206, 660, 21, "#fff", "left", false);
  }
}
function drawOverlays() {
  const blink = G.anim % 1.2 < 0.8;
  if (G.state === "title") {
    rect(0, 0, W, H, "rgba(0,0,0,0.62)");
    txt("BACKSEAT DRIVER", W / 2, 190, 84, "#ffd21f", "center");
    txt("You are the front-seat passenger. The driver is... confident.", W / 2, 244, 26, "#fff", "center");
    ["Signs and hazards are coming. Read them. Say the right thing. Fast.", "Press 1 / 2 / 3, or tap a button, to speak to the driver.",
      "Say nothing, or the wrong thing, and the sign takes its revenge.", "Three strikes and the car is totaled. (Dark humor. You were warned.)"]
      .forEach((l, i) => txt(l, W / 2, 330 + i * 36, 22, "#cfd8ff", "center"));
    if (blink) txt("PRESS SPACE OR CLICK TO START", W / 2, 560, 34, "#4ac26b", "center");
  } else if (G.state === "over") {
    rect(0, 0, W, H, "rgba(64,0,0,0.78)");
    txt("TOTALED", W / 2, 180, 110, "#ff4a3a", "center");
    txt("Score: " + G.score, W / 2, 250, 38, "#fff", "center");
    txt(G.newBest ? "NEW BEST!" : "Best: " + G.best, W / 2, 295, 26, "#ffd21f", "center");
    mtxt(G.epitaph, W / 2, 380, 800, 26, "#ffe0d8", "center");
    if (G.lock <= 0 && blink) txt("PRESS SPACE OR CLICK TO RIDE AGAIN", W / 2, 560, 32, "#4ac26b", "center");
  }
}
function draw() {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.clearRect(0, 0, W, H);
  const s = G.shake > 0.5 ? [(Math.random() * 2 - 1) * G.shake, (Math.random() * 2 - 1) * G.shake] : [0, 0];
  ctx.save(); ctx.translate(s[0], s[1]);
  drawWorld();
  if (G.ev) drawEvent();
  drawCabin();
  ctx.restore();
  G.parts.forEach((p) => { ctx.globalAlpha = clamp(p.l, 0, 1); rect(p.x - p.s / 2, p.y - p.s / 2, p.s, p.s, p.c); });
  ctx.globalAlpha = 1;
  drawHud();
  if (G.flash > 0) rect(0, 0, W, H, `rgba(${G.flashCol},${G.flash * 0.5})`);
  drawOverlays();
}
requestAnimationFrame(frame);
