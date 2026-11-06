// Draws a Game onto a 224×288 canvas. Reads the game; never changes it.
import { Game } from "../engine/game";
import { H, Kind, POINTS, QUEEN_BONUS, RULES, W } from "../engine/rules";
import { ADVANCE, CELL, COLOURS, KIND_PALETTE, SHIP, Sprite, alienSprite, glyph } from "./art";

type Ctx = CanvasRenderingContext2D;

const spriteCache = new Map<Sprite["rows"], HTMLCanvasElement>();

function spriteCanvas(s: Sprite): HTMLCanvasElement {
  let c = spriteCache.get(s.rows);
  if (c) return c;
  c = document.createElement("canvas");
  c.width = s.rows[0].length;
  c.height = s.rows.length;
  const g = c.getContext("2d")!;
  s.rows.forEach((row, y) => [...row].forEach((ch, x) => {
    if (ch === ".") return;
    g.fillStyle = s.palette[ch];
    g.fillRect(x, y, 1, 1);
  }));
  spriteCache.set(s.rows, c);
  return c;
}

/** Draws a sprite centred on (x, y). */
function drawSprite(ctx: Ctx, s: Sprite, x: number, y: number): void {
  const c = spriteCanvas(s);
  ctx.drawImage(c, Math.round(x - c.width / 2), Math.round(y - c.height / 2));
}

// Alien sprites share pixel rows between kinds, so give each kind+frame its own cached canvas.
const alienCache = new Map<string, HTMLCanvasElement>();
function drawAlien(ctx: Ctx, kind: Kind, frame: number, x: number, y: number): void {
  const key = `${kind}${frame % 2}`;
  let c = alienCache.get(key);
  if (!c) {
    const s = alienSprite(kind, frame);
    c = document.createElement("canvas");
    c.width = s.rows[0].length;
    c.height = s.rows.length;
    const g = c.getContext("2d")!;
    s.rows.forEach((row, ry) => [...row].forEach((ch, rx) => {
      if (ch === ".") return;
      g.fillStyle = s.palette[ch];
      g.fillRect(rx, ry, 1, 1);
    }));
    alienCache.set(key, c);
  }
  ctx.drawImage(c, Math.round(x - c.width / 2), Math.round(y - c.height / 2));
}

export function text(ctx: Ctx, s: string, x: number, y: number, colour: string, scale = 1): void {
  ctx.fillStyle = colour;
  let cx = x;
  for (const ch of s.toUpperCase()) {
    const g = glyph(ch);
    if (g) g.forEach((row, ry) => [...row].forEach((p, rx) => { if (p === "#") ctx.fillRect(cx + rx * scale, y + ry * scale, scale, scale); }));
    cx += ADVANCE * scale;
  }
}

const textWidth = (s: string, scale = 1) => (s.length * ADVANCE - 1) * scale;
const centred = (ctx: Ctx, s: string, y: number, colour: string, scale = 1) => text(ctx, s, Math.round((W - textWidth(s, scale)) / 2), y, colour, scale);

// A slow starfield behind everything.
interface Star { x: number; y: number; speed: number; colour: string; blink: number }
const STAR_COLOURS = ["#ffffff", "#ffe080", "#80c0ff", "#ff8080", "#a0ffa0"];
const stars: Star[] = Array.from({ length: 64 }, (_, i) => ({
  x: (i * 97) % W,
  y: (i * 61) % H,
  speed: 0.15 + ((i * 37) % 7) * 0.06,
  colour: STAR_COLOURS[i % STAR_COLOURS.length],
  blink: (i * 13) % 60,
}));

function drawStars(ctx: Ctx, frame: number, moving: boolean): void {
  for (const s of stars) {
    if (moving) s.y = (s.y + s.speed) % H;
    if ((frame + s.blink) % 60 < 8) continue;
    ctx.fillStyle = s.colour;
    ctx.fillRect(Math.round(s.x), Math.round(s.y), 1, 1);
  }
}

function drawBoom(ctx: Ctx, b: Game["booms"][number]): void {
  const big = b.kind === "player";
  const n = big ? 18 : 10;
  const life = big ? 90 : 30;
  const fade = 1 - b.age / life;
  for (let i = 0; i < n; i++) {
    const ang = (i / n) * Math.PI * 2 + (b.seed % 100) / 50;
    const sp = (big ? 0.55 : 0.6) + ((b.seed + i * 7) % 5) * 0.15;
    const r = b.age * sp;
    ctx.fillStyle = i % 3 === 0 ? "#ffffff" : COLOURS.boom[b.kind];
    ctx.globalAlpha = Math.max(0, fade);
    const size = b.age < 6 ? 2 : 1;
    ctx.fillRect(Math.round(b.x + Math.cos(ang) * r), Math.round(b.y + Math.sin(ang) * r), size, size);
  }
  if (b.age < 4) {
    ctx.fillStyle = "#ffffff";
    ctx.fillRect(Math.round(b.x) - 3, Math.round(b.y) - 3, 7, 7);
  }
  ctx.globalAlpha = 1;
}

function drawHud(ctx: Ctx, game: Game): void {
  const flash = Math.floor(game.frame / 20) % 2 === 0;
  const playing = game.phase !== "attract" && game.phase !== "gameOver";
  const labels = ["1UP", "2UP"];
  for (let i = 0; i < 2; i++) {
    const x = i === 0 ? 10 : W - 10 - textWidth("000000");
    const active = playing && game.current === i;
    const shown = i === 0 || game.numPlayers === 2 || game.phase === "attract";
    if (!shown) continue;
    if (!active || flash) text(ctx, labels[i], x + 6, 2, COLOURS.label);
    const score = game.players[i]?.score ?? 0;
    text(ctx, String(score).padStart(2, "0").padStart(6, " "), x, 11, COLOURS.text);
  }
  centred(ctx, "HIGH SCORE", 2, COLOURS.label);
  centred(ctx, String(game.hiScore).padStart(2, "0").padStart(6, " "), 11, COLOURS.text);

  const p = game.player;
  if (!p || game.phase === "attract") return;
  for (let i = 0; i < Math.min(p.lives - 1, 6); i++) drawSprite(ctx, SHIP, 12 + i * 15, H - 9);
  const cells = Math.min(p.wave, 12);
  for (let i = 0; i < cells; i++) drawSprite(ctx, CELL, W - 8 - i * 6, H - 9);
}

function drawPlay(ctx: Ctx, game: Game): void {
  const flap = Math.floor(game.frame / 16);
  for (const a of game.aliens) {
    if (!a.alive) continue;
    drawAlien(ctx, a.kind, a.mode === "home" ? flap : Math.floor(game.frame / 6), a.x, a.y);
  }
  const py = RULES.player.y;
  const showShip = game.phase === "play" || game.phase === "ready" || game.phase === "waveClear";
  if (showShip) {
    drawSprite(ctx, SHIP, game.playerX, py);
    if (!game.shot) { ctx.fillStyle = COLOURS.shot; ctx.fillRect(Math.round(game.playerX), py - 10, 1, 3); }
  }
  if (game.shot) { ctx.fillStyle = COLOURS.shot; ctx.fillRect(game.shot.x, Math.round(game.shot.y), 1, 4); }
  ctx.fillStyle = COLOURS.bullet;
  for (const b of game.bullets) ctx.fillRect(Math.round(b.x), Math.round(b.y), 2, 4);
  for (const b of game.booms) drawBoom(ctx, b);
  for (const p of game.popups) if (Math.floor(p.age / 6) % 2 === 0) text(ctx, p.text, Math.round(p.x - textWidth(p.text) / 2), Math.round(p.y - 3), COLOURS.accent);
}

function drawAttract(ctx: Ctx, game: Game): void {
  const f = game.frame;
  const title = "HIVESTORM";
  const tx = Math.round((W - textWidth(title, 2)) / 2);
  const hues = ["#ffd040", "#ff9020", "#ff5060", "#e050e0"];
  [...title].forEach((ch, i) => text(ctx, ch, tx + i * ADVANCE * 2, 34, hues[(i + Math.floor(f / 8)) % hues.length], 2));
  centred(ctx, "THE HIVE IS SWARMING", 56, COLOURS.dim);

  centred(ctx, "- POINTS -", 78, COLOURS.label);
  text(ctx, "IN HIVE  DIVING", 86, 92, COLOURS.dim);
  const kinds: Kind[] = ["queen", "guard", "drone", "worker"];
  kinds.forEach((k, i) => {
    const y = 110 + i * 20;
    drawAlien(ctx, k, Math.floor(f / 16), 54, y + 3);
    text(ctx, String(POINTS[k].home).padStart(3), 92, y, COLOURS.text);
    text(ctx, k === "queen" ? `${QUEEN_BONUS[0]}-${QUEEN_BONUS[QUEEN_BONUS.length - 1]}` : String(POINTS[k].diving).padStart(3), 146, y, k === "queen" ? COLOURS.accent : COLOURS.text);
  });
  centred(ctx, `A DIVING QUEEN IS WORTH`, 192, KIND_PALETTE.queen.a);
  centred(ctx, `${QUEEN_BONUS[1]} OR ${QUEEN_BONUS[2]} IF HER GUARDS`, 201, KIND_PALETTE.queen.a);
  centred(ctx, "FALL FIRST", 210, KIND_PALETTE.queen.a);
  centred(ctx, `EXTRA SHIP AT ${RULES.extraLifeAt}`, 226, COLOURS.dim);
  if (Math.floor(f / 30) % 2 === 0) centred(ctx, "PRESS 1 OR 2 PLAYERS", 246, COLOURS.text);
  centred(ctx, "ARROWS MOVE  SPACE FIRES", 262, "#8090a0");
  centred(ctx, "P PAUSE  M SOUND", 272, "#8090a0");
}

export function render(ctx: Ctx, game: Game): void {
  ctx.fillStyle = "#000";
  ctx.fillRect(0, 0, W, H);
  drawStars(ctx, game.frame, !game.paused);
  if (game.phase === "attract") drawAttract(ctx, game);
  else drawPlay(ctx, game);
  drawHud(ctx, game);

  const mid = 150;
  const who = `PLAYER ${game.current + 1}`;
  switch (game.phase) {
    case "ready":
      centred(ctx, who, mid, COLOURS.label);
      centred(ctx, game.player!.wave > 1 ? `WAVE ${game.player!.wave}` : "GET READY", mid + 14, COLOURS.text);
      break;
    case "waveClear":
      centred(ctx, "HIVE CLEARED!", mid, COLOURS.accent);
      if (game.timer < 100) centred(ctx, `WAVE ${game.player!.wave}`, mid + 14, COLOURS.text);
      break;
    case "playerOver":
      centred(ctx, who, mid, COLOURS.label);
      centred(ctx, "GAME OVER", mid + 14, COLOURS.text);
      break;
    case "gameOver":
      centred(ctx, "GAME OVER", mid, COLOURS.label);
      if (game.numPlayers === 2) {
        const [a, b] = game.players.map((p) => p.score);
        centred(ctx, a === b ? "A DRAW!" : `PLAYER ${a > b ? 1 : 2} WINS`, mid + 14, COLOURS.accent);
      }
      break;
  }
  if (game.paused) {
    ctx.fillStyle = "rgba(0,0,0,0.6)";
    ctx.fillRect(0, mid - 6, W, 22);
    centred(ctx, "PAUSED", mid, COLOURS.text);
  }
}

