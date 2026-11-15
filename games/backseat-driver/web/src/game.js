const MAX_STRIKES = 3;
const G = {
  state: "title", score: 0, best: 0, strikes: 0, streak: 0, handled: 0, newBest: false,
  ev: null, opts: [], bag: [], t: 0, signT: 0, reactTime: 6.5, gap: 2, et: 0, hc: 0, dep: 0, swerve: 0,
  good: false, head: "", text: "", timer: 0, line: "Buckle up. I drive great. Ask anyone.", idle: 3,
  mood: "calm", epitaph: "", mph: 45, tgt: 45, vPick: 45, scream: "", rt: 0, speedWarn: 0, scroll: 0, speed: 0.3, anim: 0, lock: 0, shake: 0, flash: 0, flashCol: "200,20,20",
  parts: [], cracks: [], top: [0x5d, 0xb3, 0xf2], bot: [0xcf, 0xea, 0xff], ground: [0x4c, 0x9a, 0x3c],
};
const DEF = { top: [0x5d, 0xb3, 0xf2], bot: [0xcf, 0xea, 0xff], ground: [0x4c, 0x9a, 0x3c] };
const hex3 = (h) => [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)];
const rgb = (c, k) => { k = k === undefined ? 1 : k; return `rgb(${Math.round(c[0] * k)},${Math.round(c[1] * k)},${Math.round(c[2] * k)})`; };
const lighten = (c, k) => c.map((v) => v + (255 - v) * k);
try { G.best = parseInt(localStorage.getItem("bsd-best") || "0", 10) || 0; } catch (e) {}

const bar = document.getElementById("bar");
const btns = Array.from(bar.querySelectorAll("button"));
btns.forEach((b, i) => b.addEventListener("click", () => choose(i)));
function setBar(on) { bar.classList.toggle("off", !on); btns.forEach((b) => (b.disabled = !on)); }
setBar(false);

function start() {
  Object.assign(G, { score: 0, strikes: 0, streak: 0, handled: 0, newBest: false, cracks: [], parts: [], bag: [], ev: null, mood: "calm", gap: 2.5, speed: 0.3, line: pick(IDLE), idle: 4, state: "drive", mph: 45, tgt: 45, scream: "" });
  AU.init();
}
function nextSign() {
  if (!G.bag.length) { G.bag = LIST.map((_, i) => i); for (let i = G.bag.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [G.bag[i], G.bag[j]] = [G.bag[j], G.bag[i]]; } }
  G.ev = LIST[G.bag.pop()];
  G.opts = G.ev.o.map((x, i) => ({ t: x[0], r: x[1], ok: i === 0, v: x[2] }));
  for (let i = G.opts.length - 1; i > 0; i--) { const j = Math.floor(Math.random() * (i + 1)); [G.opts[i], G.opts[j]] = [G.opts[j], G.opts[i]]; }
  btns.forEach((b, i) => (b.innerHTML = `<kbd>${i + 1}</kbd><span></span>`, b.lastChild.textContent = G.opts[i].t));
  Object.assign(G, { t: 0, signT: 0, et: 0, hc: 0, dep: 0, swerve: 0, mood: "calm", line: G.ev.d, state: "sign", mph: G.ev.spd, tgt: G.ev.spd, vPick: G.ev.spd, scream: "", reactTime: Math.max(3.6, 6.8 - 0.2 * G.handled) });
  setBar(true);
  AU.ding(); AU.cue(G.ev.id);
}
function choose(i) { if (G.state === "sign" && i < G.opts.length) resolve(i); }
function burst(x, y, color, n, spd, grav) {
  for (let i = 0; i < n; i++) {
    const a = Math.random() * TAU, v = (0.2 + Math.random() * 0.8) * spd;
    G.parts.push({ x, y, vx: Math.cos(a) * v, vy: Math.sin(a) * v, l: 0.8 + Math.random(), g: grav, c: color, s: 4 + Math.random() * 7 });
  }
}
function resolve(i) {
  setBar(false);
  const ok = i >= 0 && G.opts[i].ok;
  G.good = ok; G.rt = 0;
  G.scream = i >= 0 ? G.opts[i].t : "";
  G.vPick = i >= 0 ? G.opts[i].v : G.ev.spd; G.tgt = G.vPick;
  if (i >= 0) AU.scream();
  if (ok) {
    G.streak++; G.handled++;
    const gain = 100 + Math.floor((1 - G.t) * 100) + G.streak * 10;
    G.score += gain; G.head = "NICE SAVE!   +" + gain; G.text = G.ev.good; G.line = pick(THANKS); G.mood = "happy";
    burst(W / 2, 380, "#ffd21f", 45, 380, 240); AU.good();
  } else {
    G.streak = 0; G.strikes++;
    G.head = i < 0 ? "TOO SLOW!" : "WRONG THING TO SAY!"; G.text = i < 0 ? G.ev.late : G.opts[i].r;
    G.line = pick(BLAME); G.mood = "scared"; G.shake = 28; G.flash = 0.85;
    burst(W / 2, 420, hexc(G.ev.fx), 110, 650, 520);
    const ox = 320 + Math.random() * 660, oy = 150 + Math.random() * 310, segs = [];
    for (let k = 0; k < 7; k++) {
      const a = Math.random() * TAU, ln = 60 + Math.random() * 170, dx = Math.cos(a), dy = Math.sin(a);
      segs.push([[ox, oy], [ox + dx * ln * 0.5 + (Math.random() - 0.5) * 28, oy + dy * ln * 0.5 + (Math.random() - 0.5) * 28], [ox + dx * ln, oy + dy * ln]]);
    }
    G.cracks.push(segs);
    AU.screech(); setTimeout(() => AU.crash(), 800);
  }
  G.timer = 3.6 + G.text.length * 0.03;
  G.state = "result";
}
function gameOver() {
  G.state = "over"; G.lock = 1.3; G.epitaph = pick(EPITAPHS);
  if (G.score > G.best) { G.best = G.score; G.newBest = true; try { localStorage.setItem("bsd-best", String(G.best)); } catch (e) {} }
}
function update(dt) {
  G.anim += dt; G.lock = Math.max(0, G.lock - dt); G.shake = Math.max(0, G.shake - 40 * dt); G.flash = Math.max(0, G.flash - 1.4 * dt);
  const st = G.state;
  if (st === "title" || st === "drive") {
    G.idle -= dt; if (G.idle <= 0) { G.line = pick(IDLE); G.idle = 4.5; }
    G.tgt = 45;
    if (st === "drive") { G.gap -= dt; if (G.gap <= 0) nextSign(); }
  } else if (st === "sign") {
    G.et += dt; G.t = Math.min(1, G.t + dt / G.reactTime); G.signT = G.t; G.hc = G.t; G.dep = G.t * 0.98;
    if (G.t >= 1) resolve(-1);
  } else if (st === "result") {
    G.et += dt; G.timer -= dt; G.rt += dt;
    if (G.good) {
      G.tgt = G.timer > 0.9 ? G.vPick : 45;
      G.hc = Math.min(3, G.hc + dt * 0.55); G.signT += dt * 0.35; G.swerve = moveToward(G.swerve, 1, dt * 1.5);
      if (G.dep < 0.78) G.dep = Math.min(0.78, G.dep + dt * 0.25);
    } else {
      G.tgt = G.rt > 0.9 ? 0 : G.vPick;
      if (G.hc < 1) G.hc = moveToward(G.hc, 1, dt * 2);
      G.dep = moveToward(G.dep, 0.98, dt * 1.6);
    }
    if (G.timer <= 0) {
      if (G.strikes >= MAX_STRIKES) gameOver();
      else Object.assign(G, { ev: null, mood: "calm", gap: 1.4 + Math.random(), line: pick(IDLE), idle: 4, state: "drive" });
    }
  } else G.tgt = 0;
  const acc = st === "result" && !G.good && G.rt > 0.9 ? 160 : G.tgt < G.mph ? 40 : 22;
  G.mph = moveToward(G.mph, G.tgt, acc * dt);
  G.speed = G.mph * 0.00667;
  AU.update(G.mph, dt, st === "drive" || st === "sign" || st === "result");
  if (st === "sign" && G.t > 0.7 && Math.floor(G.t * 20) !== G.tickN) { G.tickN = Math.floor(G.t * 20); if (G.tickN % 2) AU.tick(); }
  G.scroll = fpos(G.scroll + G.speed * dt, 1);
  const tg = G.ev && G.ev.sky ? { top: hex3(G.ev.sky[0]), bot: hex3(G.ev.sky[1]) } : DEF;
  const gr = G.ev && G.ev.gr ? hex3(G.ev.gr) : DEF.ground, k = clamp(dt * 2, 0, 1);
  for (let i = 0; i < 3; i++) { G.top[i] = lerp(G.top[i], tg.top[i], k); G.bot[i] = lerp(G.bot[i], tg.bot[i], k); G.ground[i] = lerp(G.ground[i], gr[i], k); }
  G.parts = G.parts.filter((p) => (p.l -= dt) > 0);
  G.parts.forEach((p) => { p.vy += p.g * dt; p.x += p.vx * dt; p.y += p.vy * dt; });
}
function key(code) {
  if (code === "Digit1" || code === "Numpad1") choose(0);
  else if (code === "Digit2" || code === "Numpad2") choose(1);
  else if (code === "Digit3" || code === "Numpad3") choose(2);
  else if (code === "KeyM") toggleSound();
  else if (code === "Space" || code === "Enter" || code === "KeyR") go();
}
function go() { if (G.state === "title" || (G.state === "over" && G.lock <= 0)) start(); }
addEventListener("keydown", (e) => { if (e.repeat) return; if (["Space", "Enter"].includes(e.code)) e.preventDefault(); key(e.code); });
cv.addEventListener("pointerdown", go);
let last = performance.now();
function frame(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now;
  update(dt); draw(); requestAnimationFrame(frame);
}

const sndBtn = document.getElementById("snd");
function toggleSound() { AU.init(); sndBtn.textContent = AU.toggle() ? "Sound: on" : "Sound: off"; }
sndBtn.addEventListener("click", toggleSound);
document.addEventListener("pointerdown", () => AU.init(), { once: true });
