// Draws a Game on a canvas, 224 × 256 logical pixels at whole-number scale. Every sprite is built from
// rectangles here: nothing is loaded and nothing is copied from anywhere.
import { H, W, surface, type Platform } from "../engine/levels";
import type { Barrel, Fire, Game, Hero, Spring } from "../engine/game";

type Ctx = CanvasRenderingContext2D;

const C = {
  girder: "#d23a43",
  girderHi: "#ff7a73",
  girderLo: "#7a1b26",
  ladder: "#46d8e6",
  skin: "#f6b98a",
  red: "#e03030",
  blue: "#2f5fe0",
  brown: "#8a4b1b",
  tan: "#d99a5b",
  white: "#f4f4f4",
  yellow: "#ffd84a",
  orange: "#ff8a1f",
  pink: "#ff7ac0",
  steel: "#9aa3b2",
};

const rect = (c: Ctx, color: string, x: number, y: number, w: number, h: number) => {
  c.fillStyle = color;
  c.fillRect(Math.round(x), Math.round(y), w, h);
};

export function text(c: Ctx, s: string, x: number, y: number, color = C.white, align: CanvasTextAlign = "left", size = 8) {
  c.font = `bold ${size}px "Courier New", monospace`;
  c.textAlign = align;
  c.textBaseline = "alphabetic";
  c.fillStyle = color;
  c.fillText(s, Math.round(x), Math.round(y));
}

// ---- the stage ---------------------------------------------------------------------------------------------

function girder(c: Ctx, p: Platform) {
  const hole = (x: number) => ((x - p.x1) % 8) >= 2 && ((x - p.x1) % 8) < 6;
  for (let x = Math.floor(p.x1); x < p.x2; x++) {
    const y = Math.round(surface(p, x + 0.5));
    rect(c, C.girder, x, y, 1, 7);
    rect(c, C.girderHi, x, y, 1, 1);
    rect(c, C.girderLo, x, y + 6, 1, 1);
    if (hole(x)) rect(c, "#000", x, y + 2, 1, 3);
    else if (((x - p.x1) % 8) === 1 || ((x - p.x1) % 8) === 6) rect(c, C.girderLo, x, y + 3, 1, 1);
  }
}

function belt(c: Ctx, p: Platform, frame: number) {
  for (let x = Math.floor(p.x1); x < p.x2; x++) {
    rect(c, "#5a6370", x, p.y1, 1, 6);
    rect(c, C.steel, x, p.y1, 1, 1);
  }
  const off = ((Math.round(frame * p.belt * 1.5) % 8) + 8) % 8;
  for (let x = p.x1 + off; x < p.x2 - 3; x += 8) {
    rect(c, C.yellow, x, p.y1 + 2, 3, 1);
    rect(c, C.yellow, x + (p.belt > 0 ? 2 : 0), p.y1 + 1, 1, 3);
  }
  rect(c, C.orange, p.x1 - 3, p.y1 - 1, 4, 8);
  rect(c, C.orange, p.x2 - 1, p.y1 - 1, 4, 8);
}

function lift(c: Ctx, p: Platform) {
  rect(c, C.yellow, p.x1, p.y1, p.x2 - p.x1, 3);
  rect(c, "#a07a10", p.x1, p.y1 + 3, p.x2 - p.x1, 2);
  rect(c, C.steel, p.x1 + 6, p.y1 - 40, 1, 40);
}

function ladder(c: Ctx, x: number, top: number, bottom: number, broken: boolean) {
  const t = broken ? top + (bottom - top) * 0.45 : top;
  rect(c, C.ladder, x - 3, t, 1, bottom - t);
  rect(c, C.ladder, x + 2, t, 1, bottom - t);
  for (let y = Math.ceil(bottom) - 3; y > t; y -= 4) rect(c, C.ladder, x - 3, y, 6, 1);
}

function oilDrum(c: Ctx, g: Game) {
  const x = g.def.oilX as number;
  const y = surface(g.plat(0), x);
  rect(c, "#2a62c8", x - 8, y - 20, 16, 20);
  rect(c, "#6fa0f0", x - 8, y - 20, 16, 2);
  rect(c, "#17408a", x - 8, y - 2, 16, 2);
  text(c, "OIL", x, y - 8, C.white, "center", 7);
  if (g.thrown > 1 || g.oilFire > 0) flame(c, x, y - 20, g.frame, 1);
}

function flame(c: Ctx, x: number, y: number, frame: number, scale: number) {
  const f = (frame >> 2) & 1;
  const w = [8, 6, 4, 2];
  for (let i = 0; i < 4; i++) {
    const ww = w[i] * scale + (i === 1 && f ? 2 : 0);
    rect(c, i < 2 ? C.orange : C.yellow, x - ww / 2, y - 3 * (i + 1) * scale, ww, 3 * scale);
  }
}

function lady(c: Ctx, g: Game) {
  const d = g.def.lady;
  const x = d.x;
  const y = surface(g.plat(d.plat), x);
  const w = (g.frame >> 4) & 1;
  rect(c, C.pink, x - 4, y - 10, 8, 10);
  rect(c, "#c24a8c", x - 5, y - 3, 10, 3);
  rect(c, C.skin, x - 3, y - 16, 6, 5);
  rect(c, "#7a3a1a", x - 4, y - 18, 8, 3);
  rect(c, "#7a3a1a", x - 4, y - 16, 2, 5);
  rect(c, C.skin, x + 4, y - 14 - (w ? 3 : 0), 2, 5);
  if (g.mode === "play" && ((g.frame >> 5) & 1) === 0) text(c, "HELP!", x + 8, y - 20, C.white, "left", 7);
  if (g.mode === "clear") heart(c, x - 8 + Math.sin(g.modeT / 10) * 2, y - 26 - (g.modeT % 40) / 4);
}

function heart(c: Ctx, x: number, y: number) {
  rect(c, C.red, x, y, 2, 2);
  rect(c, C.red, x + 4, y, 2, 2);
  rect(c, C.red, x, y + 1, 6, 2);
  rect(c, C.red, x + 1, y + 3, 4, 1);
  rect(c, C.red, x + 2, y + 4, 2, 1);
}

function kong(c: Ctx, g: Game) {
  const d = g.def.kong;
  let x = d.x;
  let y = surface(g.plat(d.plat), x);
  if (g.kongFallen) y += Math.min(260, ((g.modeT - 60) * (g.modeT - 60)) / 12);
  const beat = ((g.frame >> 3) & 1) === 1;
  const throwing = g.kongThrow < 24 && g.def.kind !== "rivets";
  rect(c, C.brown, x - 15, y - 24, 30, 20);
  rect(c, C.tan, x - 9, y - 21, 18, 12);
  rect(c, "#5c300f", x - 15, y - 24, 30, 2);
  rect(c, C.brown, x - 10, y - 36, 20, 14);
  rect(c, C.tan, x - 7, y - 31, 14, 9);
  rect(c, "#3a1e08", x - 10, y - 36, 20, 3);
  rect(c, C.white, x - 5, y - 29, 3, 3);
  rect(c, C.white, x + 2, y - 29, 3, 3);
  rect(c, "#000", x - 4 + (throwing ? 1 : 0), y - 28, 1, 2);
  rect(c, "#000", x + 3 + (throwing ? 1 : 0), y - 28, 1, 2);
  rect(c, "#3a1e08", x - 4, y - 25, 8, 2);
  rect(c, C.brown, x - 14, y - 4, 10, 4);
  rect(c, C.brown, x + 4, y - 4, 10, 4);
  if (throwing) {
    rect(c, C.brown, x - 22, y - 24, 8, 6);
    rect(c, C.brown, x + 14, y - 26, 10, 6);
    const barrelY = y - 26;
    if (g.kongThrow < 12 && g.def.kind !== "elevators") rect(c, g.def.kind === "girders" ? "#c27a2f" : C.tan, x + 20, barrelY - 8, 8, 8);
  } else if (beat) {
    rect(c, C.brown, x - 20, y - 18, 7, 7);
    rect(c, C.brown, x + 13, y - 18, 7, 7);
  } else {
    rect(c, C.brown, x - 20, y - 24, 6, 14);
    rect(c, C.brown, x + 14, y - 24, 6, 14);
  }
  x = 0;
}

// ---- things that move --------------------------------------------------------------------------------------

function barrel(c: Ctx, b: Barrel) {
  if (b.kind === "pie") {
    rect(c, "#e0b070", b.x - 5, b.y - 6, 10, 6);
    rect(c, "#b07a3a", b.x - 5, b.y - 2, 10, 2);
    rect(c, "#f9e0a8", b.x - 3, b.y - 6, 6, 1);
    return;
  }
  const body = b.wild ? "#3a78d8" : "#c27a2f";
  const band = b.wild ? "#1c3f87" : "#6b3a10";
  rect(c, body, b.x - 4, b.y - 8, 8, 8);
  rect(c, body, b.x - 5, b.y - 6, 10, 4);
  rect(c, band, b.x - 5, b.y - 5, 10, 1);
  rect(c, band, b.x - 4, b.y - 8, 8, 1);
  rect(c, band, b.x - 4, b.y - 1, 8, 1);
  rect(c, "#ffd9a0", b.x + Math.sin(b.spin) * 2.5 - 1, b.y - 5, 2, 2);
  if (b.mode === "ladder") rect(c, band, b.x - 4, b.y - 4, 8, 1);
}

function fire(c: Ctx, f: Fire, frame: number) {
  const k = (frame >> 3) & 1;
  const x = f.x;
  const y = f.y;
  rect(c, C.orange, x - 4, y - 8, 8, 8);
  rect(c, C.orange, x - 3 - k, y - 11, 2, 3);
  rect(c, C.orange, x + 1 + k, y - 12, 2, 4);
  rect(c, C.yellow, x - 3, y - 6, 6, 5);
  rect(c, "#d03020", x - 4, y - 2, 8, 2);
  rect(c, "#000", x - 2, y - 5, 1, 2);
  rect(c, "#000", x + 1, y - 5, 1, 2);
}

function spring(c: Ctx, s: Spring) {
  rect(c, "#aab4ff", s.x - 4, s.y - 2, 8, 2);
  rect(c, "#6d78e0", s.x - 3, s.y - 4, 6, 2);
  rect(c, "#aab4ff", s.x - 4, s.y - 6, 8, 2);
  rect(c, "#6d78e0", s.x - 3, s.y - 8, 6, 2);
}

function hammerShape(c: Ctx, x: number, y: number, up: boolean, dir: number) {
  if (up) {
    rect(c, "#d9b36a", x - 1, y - 12, 2, 8);
    rect(c, C.red, x - 4 * dir - (dir < 0 ? 4 : 0) + (dir < 0 ? 0 : 0), y - 16, 8, 5);
  } else {
    rect(c, "#d9b36a", x + 2 * dir - (dir < 0 ? 8 : 0), y - 9, 8, 2);
    rect(c, C.red, x + 10 * dir - (dir < 0 ? 5 : 0), y - 12, 5, 8);
  }
}

function hero(c: Ctx, h: Hero, frame: number, dying: boolean) {
  c.save();
  c.translate(Math.round(h.x), Math.round(h.y));
  if (h.state === "dead") {
    const a = Math.min(h.anim, 60);
    c.translate(0, -8);
    c.rotate(a * 0.35);
    c.translate(0, 8);
    if (h.anim > 60) c.rotate(Math.PI / 2);
  }
  if (h.dir < 0) c.scale(-1, 1);
  const step = h.moving ? (h.anim >> 2) & 1 : 0;
  const climbing = h.state === "climb";
  const air = h.state === "air";
  // legs
  if (air) {
    rect(c, C.blue, -4, -4, 3, 4);
    rect(c, C.blue, 2, -4, 3, 3);
    rect(c, "#5a3010", 2, -1, 4, 1);
  } else if (climbing) {
    const k = (h.anim >> 3) & 1;
    rect(c, C.blue, -3, -4 + (k ? 1 : 0), 3, 4);
    rect(c, C.blue, 1, -4 + (k ? 0 : 1), 3, 4);
  } else {
    rect(c, C.blue, -3 + step, -4, 3, 4);
    rect(c, C.blue, 1 - step, -4, 3, 4);
    rect(c, "#5a3010", -3 + step, -1, 4, 1);
    rect(c, "#5a3010", 1 - step, -1, 4, 1);
  }
  // body, arms
  rect(c, C.blue, -4, -9, 8, 5);
  rect(c, C.red, -4, -11, 8, 3);
  rect(c, C.yellow, -2, -8, 1, 1);
  rect(c, C.yellow, 1, -8, 1, 1);
  if (climbing) {
    const k = (h.anim >> 3) & 1;
    rect(c, C.red, -5, -15 + (k ? 0 : 3), 2, 5);
    rect(c, C.red, 3, -15 + (k ? 3 : 0), 2, 5);
  } else if (air) {
    rect(c, C.red, 3, -16, 2, 5);
    rect(c, C.red, -5, -12, 2, 3);
  } else if (h.hammer === 0) {
    rect(c, C.red, -5, -11 + step, 2, 4);
    rect(c, C.red, 3, -11 - step, 2, 4);
  } else rect(c, C.red, 3, -11, 4, 2);
  // head
  rect(c, climbing ? "#7a4a2a" : C.skin, -3, -15, 6, 4);
  if (!climbing) {
    rect(c, "#000", 1, -14, 1, 2);
    rect(c, "#7a3a1a", -3, -12, 6, 1);
  }
  rect(c, C.red, -4, -18, 8, 3);
  if (!climbing) rect(c, C.red, 2, -16, 4, 1);
  c.restore();
  if (h.hammer > 0 && !dying) hammerShape(c, h.x, h.y, (frame >> 3) % 2 === 0, h.dir);
}

// ---- the whole frame ---------------------------------------------------------------------------------------

export function drawStage(c: Ctx, g: Game): void {
  const d = g.def;
  rect(c, "#000", 0, 0, W, H);
  if (d.kind === "rivets") {
    for (const x of [32, 192]) rect(c, "#3a4252", x - 2, 62, 4, 188);
  }
  for (const p of g.platforms) {
    if (p.lift !== 0) lift(c, p);
    else if (p.belt !== 0) belt(c, p, g.frame);
    else girder(c, p);
  }
  for (const l of d.ladders) ladder(c, l.x, l.yTop, l.yBottom, l.broken);
  for (const r of g.rivets) {
    if (r.removed) continue;
    rect(c, C.yellow, r.x - 3, r.y - 6, 6, 6);
    rect(c, "#a07a10", r.x - 3, r.y - 2, 6, 2);
  }
  if (d.oilX !== null) oilDrum(c, g);
  kong(c, g);
  lady(c, g);
  for (const h of g.hammers) if (!h.taken) hammerShape(c, h.x, h.y, true, 1);
  for (const it of g.items) {
    if (it.taken) continue;
    if (it.kind === "hat") {
      rect(c, C.pink, it.x - 5, it.y - 4, 10, 3);
      rect(c, "#c24a8c", it.x - 3, it.y - 8, 6, 4);
    } else if (it.kind === "purse") {
      rect(c, "#2fc08a", it.x - 4, it.y - 7, 8, 7);
      rect(c, "#17805a", it.x - 2, it.y - 9, 4, 2);
    } else {
      rect(c, C.yellow, it.x - 5, it.y - 10, 10, 3);
      rect(c, "#a07a10", it.x, it.y - 7, 1, 7);
    }
  }
  for (const b of g.barrels) barrel(c, b);
  for (const s of g.springs) spring(c, s);
  for (const f of g.fires) fire(c, f, g.frame);
  hero(c, g.hero, g.frame, g.mode === "dying");
  for (const p of g.popups) text(c, p.text, p.x, p.y - p.t / 4, C.white, "center", 7);
  drawHud(c, g);
  if (g.mode === "ready") text(c, "GET READY!", W / 2, 150, C.yellow, "center", 12);
  if (g.mode === "clear") {
    text(c, `${d.meters}m CLEARED`, W / 2, 130, C.yellow, "center", 12);
    text(c, `BONUS ${g.bonus}`, W / 2, 146, C.white, "center", 8);
  }
  if (g.mode === "over") text(c, "GAME OVER", W / 2, 140, C.red, "center", 14);
}

function drawHud(c: Ctx, g: Game) {
  text(c, "SCORE", 8, 10, C.red);
  text(c, String(g.score).padStart(6, "0"), 8, 20);
  text(c, `LEVEL ${String(g.round).padStart(2, "0")}`, 160, 10, C.red);
  text(c, `${g.def.meters}m`, 200, 20, C.ladder);
  const low = g.bonus <= 1000 && ((g.frame >> 4) & 1) === 0;
  text(c, "BONUS", 100, 10, C.red);
  text(c, String(g.bonus).padStart(4, "0"), 100, 20, low ? C.red : C.yellow);
  for (let i = 0; i < Math.min(g.lives, 6); i++) {
    rect(c, C.red, 8 + i * 9, 28, 6, 2);
    rect(c, C.blue, 8 + i * 9, 30, 6, 4);
  }
}

export function drawTitle(c: Ctx, frame: number, high: number, touch: boolean): void {
  rect(c, "#000", 0, 0, W, H);
  const demo = frame / 40;
  for (let i = 0; i < 2; i++) {
    const y = i === 0 ? 96 : 118;
    for (let x = 6; x < 218; x++) rect(c, C.girder, x, Math.round(y + Math.sin(x / 30 + i) * 1.2), 1, 3);
  }
  text(c, "KONG", W / 2, 58, C.red, "center", 30);
  text(c, "CLIMB", W / 2, 84, C.yellow, "center", 24);
  const bx = 30 + ((demo * 20) % 160);
  rect(c, C.brown, bx - 4, 88, 8, 8);
  rect(c, "#ffd9a0", bx - 1, 91, 2, 2);
  text(c, "A 1981 ARCADE CLIMBER, RECREATED", W / 2, 128, C.ladder, "center", 7);
  text(c, "ARROWS / WASD  MOVE & CLIMB", W / 2, 150, C.white, "center", 8);
  text(c, "SPACE / Z      JUMP", W / 2, 162, C.white, "center", 8);
  text(c, "P PAUSE   M SOUND", W / 2, 174, C.white, "center", 8);
  if (((frame >> 5) & 1) === 0) text(c, touch ? "TAP TO START" : "PRESS SPACE TO START", W / 2, 206, C.yellow, "center", 10);
  text(c, `HIGH ${String(high).padStart(6, "0")}`, W / 2, 232, C.red, "center", 8);
}
