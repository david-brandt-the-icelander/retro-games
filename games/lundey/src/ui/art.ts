// Lundey's cast and pickups, drawn with canvas shapes: no image files. Everything is seen from above and drawn
// facing right around (0, 0); the caller moves and turns the canvas first. Sizes are in screen pixels at scale 1,
// where a tile is 16 across.
import type { HunterKind, Treat } from "../engine/rules";

type Ctx = CanvasRenderingContext2D;

function oval(c: Ctx, x: number, y: number, rx: number, ry: number, fill: string, turn = 0): void {
  c.beginPath();
  c.ellipse(x, y, rx, ry, turn, 0, Math.PI * 2);
  c.fillStyle = fill;
  c.fill();
}

function shape(c: Ctx, fill: string, points: number[]): void {
  c.beginPath();
  c.moveTo(points[0], points[1]);
  for (let i = 2; i < points.length; i += 2) c.lineTo(points[i], points[i + 1]);
  c.closePath();
  c.fillStyle = fill;
  c.fill();
}

/** The puffin: black back and wings, white cheeks, a striped orange beak and orange feet that paddle as it runs. */
export function drawPuffin(c: Ctx, frame: number, moving: boolean): void {
  const step = moving ? Math.sin(frame / 2.2) : 0;
  oval(c, -5.5 + step * 1.6, -2.3, 2, 1.2, "#f47b20");
  oval(c, -5.5 - step * 1.6, 2.3, 2, 1.2, "#f47b20");
  const flap = moving ? 1.6 + Math.abs(step) * 0.9 : 1.6;
  oval(c, -1.5, -4.6, 3.8, flap, "#14161c", -0.25);
  oval(c, -1.5, 4.6, 3.8, flap, "#14161c", 0.25);
  oval(c, -1, 0, 5.8, 4.6, "#1d2028");
  oval(c, -2.4, 0, 2.6, 2, "#2c303b");
  oval(c, 3.4, 0, 3.7, 3.7, "#1d2028");
  oval(c, 4.2, -2, 2.1, 1.5, "#f6f2e6", 0.3);
  oval(c, 4.2, 2, 2.1, 1.5, "#f6f2e6", -0.3);
  oval(c, 4.9, -1.9, 0.62, 0.62, "#14161c");
  oval(c, 4.9, 1.9, 0.62, 0.62, "#14161c");
  shape(c, "#3b4a78", [6.1, -1.9, 7.3, -1.5, 7.3, 1.5, 6.1, 1.9]);
  shape(c, "#f6c445", [7.3, -1.5, 8, -1.2, 8, 1.2, 7.3, 1.5]);
  shape(c, "#ef5b2b", [8, -1.2, 10.4, 0, 8, 1.2]);
}

/** A hunter's colours: its coat, the darker and lighter parts of it, and its eye. */
export interface Coat { main: string; dark: string; light: string; eye: string }
export const COATS: Record<HunterKind, Coat> = {
  fox: { main: "#cf5a2a", dark: "#7a2f16", light: "#f7ead6", eye: "#1a1208" },
  mink: { main: "#5a3f2e", dark: "#33221a", light: "#efe6d6", eye: "#0c0806" },
  skua: { main: "#7b6248", dark: "#4b3a2a", light: "#f3ead8", eye: "#120c06" },
  raven: { main: "#1b1c26", dark: "#0c0c12", light: "#565a70", eye: "#f2f2f2" },
};
/** Every hunter looks the same washed-out blue while the terns mob it. */
export const COWED: Coat = { main: "#8fa9c4", dark: "#5f7893", light: "#e6eef6", eye: "#22303f" };

function drawFox(c: Ctx, k: Coat, frame: number): void {
  const wag = Math.sin(frame / 5) * 1.6, trot = Math.sin(frame / 2.4) * 1.3;
  oval(c, 2.4 + trot, -3.5, 1.5, 1, k.dark);
  oval(c, 2.4 - trot, 3.5, 1.5, 1, k.dark);
  oval(c, -3.8 - trot, -3.4, 1.5, 1, k.dark);
  oval(c, -3.8 + trot, 3.4, 1.5, 1, k.dark);
  c.save();
  c.translate(-6, 0);
  c.rotate(wag * 0.16);
  oval(c, -3.4, 0, 4.4, 2.3, k.main);
  oval(c, -6.6, 0, 1.9, 1.6, k.light);
  c.restore();
  oval(c, -1, 0, 5.8, 3.5, k.main);
  shape(c, k.dark, [3.2, -2.2, 5.6, -5.2, 6.2, -1.8]);
  shape(c, k.dark, [3.2, 2.2, 5.6, 5.2, 6.2, 1.8]);
  oval(c, 4.9, 0, 3.3, 3.1, k.main);
  shape(c, k.light, [6.6, -1.9, 10.6, 0, 6.6, 1.9]);
  oval(c, 10.2, 0, 0.9, 0.8, k.eye);
  oval(c, 6.3, -1.5, 0.6, 0.6, k.eye);
  oval(c, 6.3, 1.5, 0.6, 0.6, k.eye);
}

function drawMink(c: Ctx, k: Coat, frame: number): void {
  const s = Math.sin(frame / 4) * 2.2;
  c.lineCap = "round";
  c.lineJoin = "round";
  c.strokeStyle = k.dark;
  c.lineWidth = 1.8;
  c.beginPath();
  c.moveTo(-8, s);
  c.quadraticCurveTo(-11, s * 0.2, -13.5, -s);
  c.stroke();
  c.strokeStyle = k.main;
  c.lineWidth = 5;
  c.beginPath();
  c.moveTo(-8, s);
  c.bezierCurveTo(-4, s * 1.2, -1, -s, 4.2, 0);
  c.stroke();
  oval(c, 5.6, 0, 2.9, 2.6, k.main);
  oval(c, 4.4, -2.3, 0.9, 0.9, k.dark);
  oval(c, 4.4, 2.3, 0.9, 0.9, k.dark);
  oval(c, 7.9, 0, 1.5, 1.3, k.light);
  oval(c, 9, 0, 0.6, 0.6, k.eye);
  oval(c, 6.6, -1.2, 0.5, 0.5, k.eye);
  oval(c, 6.6, 1.2, 0.5, 0.5, k.eye);
}

function drawSkua(c: Ctx, k: Coat, frame: number): void {
  const beat = Math.sin(frame / 4.5), tip = -1.5 - beat * 2.2, span = 11 - Math.abs(beat) * 1.2;
  for (const side of [-1, 1]) {
    shape(c, k.main, [2.6, side * 1.4, 0.8, side * (span - 3), tip, side * span, tip - 2.4, side * (span - 2.4), -3.4, side * 1.6]);
    shape(c, k.light, [0, side * (span - 3.6), tip - 0.3, side * (span - 1.4), tip - 1.8, side * (span - 3.2)]);
  }
  shape(c, k.dark, [-4.6, -1.8, -9, 0, -4.6, 1.8]);
  oval(c, -0.4, 0, 5.4, 2.6, k.dark);
  oval(c, 4.8, 0, 2.4, 2.2, k.main);
  shape(c, "#2a2f38", [6.6, -1, 9.6, 0, 6.6, 1]);
  oval(c, 5.6, -1.1, 0.5, 0.5, k.eye);
  oval(c, 5.6, 1.1, 0.5, 0.5, k.eye);
}

function drawRaven(c: Ctx, k: Coat, frame: number, diving: boolean): void {
  const beat = Math.sin(frame / 6), fold = diving ? 0.55 : 1 - Math.abs(beat) * 0.12, sweep = diving ? -2.5 : beat * 1.2;
  for (const side of [-1, 1]) {
    const y = (v: number) => side * v * fold;
    shape(c, k.main, [
      2.6, y(1.8), 1.6 + sweep, y(9.4), 0.2 + sweep, y(11), -1 + sweep, y(9.6), -2.2 + sweep, y(10.4),
      -3 + sweep, y(8.6), -4.2 + sweep, y(9), -4.6, y(6.2), -4.4, y(1.8),
    ]);
  }
  shape(c, k.dark, [-4.4, -1.6, -8.8, -2.6, -10, 0, -8.8, 2.6, -4.4, 1.6]);
  oval(c, -0.4, 0, 5.8, 2.9, k.main);
  oval(c, -1.4, 0, 2.6, 1.3, k.light);
  oval(c, 5, 0, 2.7, 2.5, k.main);
  shape(c, k.light, [6.8, -1.3, 10.4, 0, 6.8, 1.3]);
  const eye = diving ? "#ff5a3c" : k.eye;
  oval(c, 5.9, -1.3, 0.55, 0.55, eye);
  oval(c, 5.9, 1.3, 0.55, 0.55, eye);
}

export function drawHunter(c: Ctx, kind: HunterKind, coat: Coat, frame: number, diving = false): void {
  if (kind === "fox") drawFox(c, coat, frame);
  else if (kind === "mink") drawMink(c, coat, frame);
  else if (kind === "skua") drawSkua(c, coat, frame);
  else drawRaven(c, coat, frame, diving);
}

/** A small white tern with a black cap, wings out, for the birds that mob a hunter. */
export function drawTern(c: Ctx, beat: number): void {
  const w = 3.6 - Math.abs(beat) * 1.2;
  shape(c, "#ffffff", [1.2, 0, -0.6, -w, -1.6, -w + 0.6, -0.8, 0, -1.6, w - 0.6, -0.6, w]);
  shape(c, "#e9eef4", [-0.8, -0.5, -3.4, -1, -2.2, 0, -3.4, 1, -0.8, 0.5]);
  oval(c, 1.2, 0, 1.1, 0.9, "#16181d");
  shape(c, "#e2452f", [2.1, -0.35, 3.4, 0, 2.1, 0.35]);
}

/** A sand eel: a sliver of silver that wriggles. */
export function drawEel(c: Ctx, wriggle: number): void {
  c.lineCap = "round";
  c.strokeStyle = "#f1f6fb";
  c.lineWidth = 1.7;
  c.beginPath();
  c.moveTo(-3, wriggle);
  c.quadraticCurveTo(0, -wriggle * 1.6, 3, wriggle * 0.6);
  c.stroke();
  c.strokeStyle = "#8ea4b8";
  c.lineWidth = 0.6;
  c.beginPath();
  c.moveTo(-2.6, wriggle - 0.5);
  c.quadraticCurveTo(0, -wriggle * 1.6 - 0.5, 2.4, wriggle * 0.6 - 0.5);
  c.stroke();
  oval(c, 2.7, wriggle * 0.6, 0.45, 0.45, "#1b2530");
}

/** A tern's feather, standing on its quill with a soft glow that comes and goes. */
export function drawFeather(c: Ctx, frame: number): void {
  const glow = 0.5 + Math.sin(frame / 9) * 0.5;
  oval(c, 0, 0, 6.2 + glow, 6.2 + glow, `rgba(255,255,255,${0.14 + glow * 0.12})`);
  c.save();
  c.rotate(0.5 + Math.sin(frame / 14) * 0.12);
  c.beginPath();
  c.moveTo(0, 6);
  c.bezierCurveTo(-3.6, 2, -3, -4, 0, -6.4);
  c.bezierCurveTo(3, -4, 3.6, 2, 0, 6);
  c.fillStyle = "#ffffff";
  c.fill();
  c.beginPath();
  c.moveTo(0, -6.4);
  c.bezierCurveTo(-2.4, -4.6, 2.4, -4.6, 0, -6.4);
  c.bezierCurveTo(1.8, -5.2, 1.6, -3.6, 0, -3.4);
  c.bezierCurveTo(-1.6, -3.6, -1.8, -5.2, 0, -6.4);
  c.fillStyle = "#2a2f38";
  c.fill();
  c.strokeStyle = "#9aa7b4";
  c.lineWidth = 0.7;
  c.lineCap = "round";
  c.beginPath();
  c.moveTo(0, 7.2);
  c.lineTo(0, -4.6);
  c.stroke();
  c.restore();
}

/** The treats that wash up, one kind for each of the first five burrows. */
export function drawTreat(c: Ctx, treat: Treat): void {
  switch (treat) {
    case "herring":
      shape(c, "#5f86b3", [-7, -2.6, -4.2, 0, -7, 2.6]);
      oval(c, 0.4, 0, 5.4, 2.6, "#7fa6cf");
      oval(c, 0.8, 0.9, 4.6, 1.5, "#e8f1f8");
      oval(c, 3.6, -0.5, 0.7, 0.7, "#10202e");
      return;
    case "crab":
      for (const side of [-1, 1]) {
        c.strokeStyle = "#b5341f";
        c.lineWidth = 1.2;
        c.lineCap = "round";
        for (const x of [-2.6, 0, 2.6]) { c.beginPath(); c.moveTo(x, side * 2.4); c.lineTo(x * 1.5, side * 5.4); c.stroke(); }
        oval(c, 5.4, side * 3.4, 2.1, 1.6, "#d8452c", side * 0.6);
      }
      oval(c, 0, 0, 4.8, 3.5, "#e8573a");
      oval(c, 2.6, -1.3, 0.6, 0.6, "#1a0c08");
      oval(c, 2.6, 1.3, 0.6, 0.6, "#1a0c08");
      return;
    case "mussel":
      c.beginPath();
      c.moveTo(-6, 0);
      c.bezierCurveTo(-3, -5.4, 5, -4.6, 6, 0);
      c.bezierCurveTo(5, 4.6, -3, 5.4, -6, 0);
      c.fillStyle = "#27304a";
      c.fill();
      c.strokeStyle = "#5b6c9c";
      c.lineWidth = 0.7;
      for (const r of [2.2, 3.8]) { c.beginPath(); c.arc(-6, 0, r + 4, -0.5, 0.5); c.stroke(); }
      return;
    case "starfish": {
      c.beginPath();
      for (let i = 0; i < 10; i++) {
        const r = i % 2 ? 2.7 : 6.6, a = (i * Math.PI) / 5 - Math.PI / 2;
        c.lineTo(Math.cos(a) * r, Math.sin(a) * r);
      }
      c.closePath();
      c.fillStyle = "#f08a2c";
      c.fill();
      oval(c, 0, 0, 1.3, 1.3, "#f7b55e");
      return;
    }
    case "pearl":
      c.beginPath();
      c.moveTo(-6.4, 0.6);
      c.bezierCurveTo(-5, 6.2, 5, 6.2, 6.4, 0.6);
      c.closePath();
      c.fillStyle = "#8c6f8e";
      c.fill();
      oval(c, 0, -0.6, 3.5, 3.5, "#fbf7ff");
      oval(c, -1.1, -1.7, 1, 0.8, "#ffffff");
      oval(c, 0.9, 0.5, 1.6, 1.2, "#e3d9f2");
      return;
  }
}
