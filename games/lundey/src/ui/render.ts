// Draws the game: the island and its burrow (kept as a picture until the burrow or the screen size changes), the
// eels, feathers and treat, the puffin and the hunters, the score line and the words over the top of it all.
import { Game, Hunter, position } from "../engine/game";
import { DEN_TILES, DOOR_TILE, GATE_TILE, Maze, neighbour, tileAt, tileX, tileY } from "../engine/maze";
import { CAUGHT_STEPS, COLS, Dir, HunterKind, KINDS, MOB_WARNING, PATH, ROWS, RIGHT, DOWN, TREATS, UNIT, mobSteps, treatFor } from "../engine/rules";
import { COATS, COWED, drawEel, drawFeather, drawHunter, drawPuffin, drawTern, drawTreat } from "./art";

/** A tile's width on the screen at scale 1, the height of the score line above the island and of the line below it. */
export const TILE = 16;
export const TOP = 26;
export const BOTTOM = 26;
export const W = COLS * TILE;
export const H = TOP + ROWS * TILE + BOTTOM;

type Ctx = CanvasRenderingContext2D;

/** The island's colours, a different season on each burrow. */
interface Season { name: string; sea: string; turf: string; shade: string; tuft: string; flower: string; earth: string; sand: string; grit: string }
const SEASONS: Season[] = [
  { name: "SUMMER TURF", sea: "#12395a", turf: "#3a8a42", shade: "#2f7437", tuft: "#57a85c", flower: "#f6e05a", earth: "#4a2f1a", sand: "#dcbb80", grit: "#c4a064" },
  { name: "SEA PINKS", sea: "#143f5e", turf: "#3f8a5c", shade: "#33724b", tuft: "#5faa78", flower: "#ff9ab8", earth: "#463020", sand: "#e0c48e", grit: "#c9aa70" },
  { name: "AUTUMN HEATH", sea: "#1b3550", turf: "#8f6f2c", shade: "#775a22", tuft: "#b08c3e", flower: "#d9552b", earth: "#3d2616", sand: "#e2c792", grit: "#c8aa72" },
  { name: "FIRST FROST", sea: "#16324a", turf: "#7da0a6", shade: "#67898f", tuft: "#a9c8cc", flower: "#ffffff", earth: "#2d3a45", sand: "#bccace", grit: "#9eafb5" },
  { name: "MIDNIGHT SUN", sea: "#2a2148", turf: "#5d4474", shade: "#4c3760", tuft: "#7d6094", flower: "#ffb955", earth: "#2a1a33", sand: "#e4b98e", grit: "#c99b70" },
];
export const seasonOf = (level: number): Season => SEASONS[(level - 1) % SEASONS.length];

const ANGLE = [-Math.PI / 2, 0, Math.PI / 2, Math.PI];
const FONT = 'ui-monospace, "SF Mono", Menlo, Consolas, "Liberation Mono", monospace';
const NAMES: Record<HunterKind, [string, string]> = {
  fox: ["REFUR THE FOX", "follows your scent"],
  mink: ["MINKUR THE MINK", "takes the shortest way"],
  skua: ["SKÚMUR THE SKUA", "waits at your next meal"],
  raven: ["HRAFN THE RAVEN", "dives when it sees you"],
};

/** A number that looks random but is always the same for the same tile. */
const speck = (x: number, y: number, n: number): number => {
  let h = Math.imul(x + 11, 73856093) ^ Math.imul(y + 7, 19349663) ^ Math.imul(n + 3, 83492791);
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
};

const cx = (tile: number): number => tileX(tile) * TILE + TILE / 2;
const cy = (tile: number): number => TOP + tileY(tile) * TILE + TILE / 2;

function text(c: Ctx, s: string, x: number, y: number, size: number, fill: string, align: CanvasTextAlign = "center", edge = "rgba(8,14,24,.85)"): void {
  c.font = `bold ${size}px ${FONT}`;
  c.textAlign = align;
  c.textBaseline = "middle";
  c.lineJoin = "round";
  c.lineWidth = Math.max(2, size / 4);
  c.strokeStyle = edge;
  c.strokeText(s, x, y);
  c.fillStyle = fill;
  c.fillText(s, x, y);
}

function panel(c: Ctx, x: number, y: number, w: number, h: number, fill = "rgba(10,18,30,.82)"): void {
  c.beginPath();
  c.roundRect(x, y, w, h, 6);
  c.fillStyle = fill;
  c.fill();
}

/** The island with its tunnels and den, without anything that moves. */
function drawIsland(c: Ctx, maze: Maze, s: Season, bright: boolean): void {
  c.fillStyle = s.sea;
  c.fillRect(0, 0, W, H);
  // Surf, then the turf.
  c.beginPath();
  c.roundRect(1, TOP + 1, W - 2, ROWS * TILE - 2, 12);
  c.fillStyle = "rgba(255,255,255,.22)";
  c.fill();
  c.beginPath();
  c.roundRect(3, TOP + 3, W - 6, ROWS * TILE - 6, 10);
  c.fillStyle = bright ? s.tuft : s.turf;
  c.fill();
  c.save();
  c.clip();
  for (let y = 0; y < ROWS; y++) for (let x = 0; x < COLS; x++) {
    if (maze.tiles[tileAt(x, y)] === PATH) continue;
    const px = x * TILE, py = TOP + y * TILE;
    if (speck(x, y, 0) < 0.5) { c.fillStyle = s.shade; c.fillRect(px + speck(x, y, 1) * 8, py + speck(x, y, 2) * 8, 6, 5); }
    const kind = speck(x, y, 3), tx = px + 3 + speck(x, y, 4) * 10, ty = py + 5 + speck(x, y, 5) * 8;
    if (kind < 0.32) {
      c.strokeStyle = s.tuft;
      c.lineWidth = 1;
      c.lineCap = "round";
      c.beginPath();
      c.moveTo(tx - 1.6, ty); c.lineTo(tx - 2.4, ty - 3);
      c.moveTo(tx, ty); c.lineTo(tx, ty - 3.8);
      c.moveTo(tx + 1.6, ty); c.lineTo(tx + 2.4, ty - 3);
      c.stroke();
    } else if (kind < 0.42) {
      c.fillStyle = s.flower;
      c.beginPath();
      c.arc(tx, ty - 2, 1.2, 0, Math.PI * 2);
      c.fill();
    }
  }
  c.restore();

  // The tunnels: every pair of neighbouring tunnel tiles joined by a thick round line, earth under sand.
  const lines = (width: number, colour: string) => {
    c.strokeStyle = colour;
    c.lineWidth = width;
    c.lineCap = "round";
    c.beginPath();
    for (let i = 0; i < maze.tiles.length; i++) {
      if (maze.tiles[i] !== PATH) continue;
      c.moveTo(cx(i), cy(i));
      c.lineTo(cx(i), cy(i));
      for (const d of [RIGHT, DOWN] as Dir[]) {
        const n = neighbour(i, d);
        if (n < 0 || maze.tiles[n] !== PATH) continue;
        const wraps = d === RIGHT && tileX(n) === 0;
        c.moveTo(cx(i), cy(i));
        c.lineTo(wraps ? W + TILE : cx(n), cy(n));
        if (wraps) { c.moveTo(-TILE, cy(n)); c.lineTo(cx(n), cy(n)); }
      }
    }
    c.stroke();
  };
  lines(15.5, s.earth);
  lines(12.5, s.sand);
  for (let i = 0; i < maze.tiles.length; i++) {
    if (maze.tiles[i] !== PATH) continue;
    const x = tileX(i), y = tileY(i);
    if (speck(x, y, 6) < 0.45) {
      c.fillStyle = s.grit;
      c.beginPath();
      c.arc(cx(i) - 3.5 + speck(x, y, 7) * 7, cy(i) - 3.5 + speck(x, y, 8) * 7, 0.8, 0, Math.PI * 2);
      c.fill();
    }
  }

  // The den: a hollow under a slab of rock, with a doorway of driftwood on top.
  const left = cx(DEN_TILES[0]) - TILE / 2 - 3, top = cy(DEN_TILES[0]) - TILE / 2 - 1;
  c.beginPath();
  c.roundRect(left - 2, top - 2, TILE * 3 + 10, TILE + 6, 7);
  c.fillStyle = "#565c68";
  c.fill();
  c.beginPath();
  c.roundRect(left + 1, top + 1, TILE * 3 + 4, TILE, 5);
  c.fillStyle = "#1c2029";
  c.fill();
  c.fillStyle = "#1c2029";
  c.fillRect(cx(DOOR_TILE) - 5.5, cy(GATE_TILE) + 5, 11, cy(DEN_TILES[1]) - cy(GATE_TILE) - 8);
  c.strokeStyle = "#b9a184";
  c.lineWidth = 2;
  c.lineCap = "round";
  for (const dy of [-3, 1.5]) {
    c.beginPath();
    c.moveTo(cx(DOOR_TILE) - 6.5, cy(DOOR_TILE) + dy);
    c.lineTo(cx(DOOR_TILE) + 6.5, cy(DOOR_TILE) + dy + 0.6);
    c.stroke();
  }
}

/** Draws something at a place on the island and again on the far side when it is in the tunnel off the edge. */
function across(x: number, draw: (px: number) => void): void {
  const px = (x / UNIT) * TILE + TILE / 2;
  draw(px);
  if (px < TILE) draw(px + W);
  else if (px > W - TILE) draw(px - W);
}

export class Renderer {
  private island: HTMLCanvasElement | null = null;
  private key = "";

  constructor(private c: Ctx) {}

  draw(g: Game, scale: number): void {
    const c = this.c;
    c.setTransform(scale, 0, 0, scale, 0, 0);
    const season = seasonOf(g.level);
    const flash = g.phase === "cleared" && Math.floor(g.timer / 12) % 2 === 1;
    this.background(g.maze, season, flash, scale);

    // What lies in the tunnels.
    for (let i = 0; i < g.eels.length; i++) {
      if (g.eels[i]) {
        c.save();
        c.translate(cx(i), cy(i));
        c.rotate((tileX(i) + tileY(i)) % 2 ? 0.5 : -0.4);
        drawEel(c, Math.sin(g.frame / 9 + i) * 0.9);
        c.restore();
      } else if (g.feathers[i]) {
        c.save();
        c.translate(cx(i), cy(i));
        drawFeather(c, g.frame);
        c.restore();
      }
    }
    if (g.treat && (g.treat.steps > 120 || Math.floor(g.treat.steps / 8) % 2 === 0)) {
      c.save();
      c.translate(cx(g.treat.tile), cy(g.treat.tile));
      drawTreat(c, TREATS[treatFor(g.level)]);
      c.restore();
    }

    if (g.phase !== "attract" && g.phase !== "over") {
      for (const h of g.hunters) if (g.phase !== "caught" || g.timer > CAUGHT_STEPS - 40) this.hunter(g, h);
      this.puffin(g);
    }
    for (const p of g.popups) {
      const rise = (1 - p.steps / 60) * 8;
      text(c, String(p.points), Math.min(W - 16, Math.max(16, (p.x / UNIT) * TILE + TILE / 2)), TOP + (p.y / UNIT) * TILE + TILE / 2 - 6 - rise, 9, "#fff6b0");
    }

    this.scoreLine(g, season);
    this.words(g);
  }

  private background(maze: Maze, season: Season, flash: boolean, scale: number): void {
    const key = `${maze.seed}:${season.name}:${flash}:${scale}`;
    if (!this.island || this.key !== key) {
      this.island ??= document.createElement("canvas");
      this.island.width = Math.round(W * scale);
      this.island.height = Math.round(H * scale);
      const ic = this.island.getContext("2d")!;
      ic.setTransform(scale, 0, 0, scale, 0, 0);
      drawIsland(ic, maze, season, flash);
      this.key = key;
    }
    this.c.drawImage(this.island, 0, 0, W, H);
  }

  private puffin(g: Game): void {
    const c = this.c, p = g.puffin, at = position(p);
    across(at.x, (px) => {
      c.save();
      c.translate(px, TOP + (at.y / UNIT) * TILE + TILE / 2);
      if (g.phase === "caught") {
        // Caught: the puffin spins away in a puff of feathers.
        const left = Math.max(0, g.timer - 20) / (CAUGHT_STEPS - 20), gone = 1 - left;
        for (let i = 0; i < 7; i++) {
          const a = (i / 7) * Math.PI * 2 + 0.4, r = gone * 15;
          c.fillStyle = `rgba(255,255,255,${left * 0.9})`;
          c.beginPath();
          c.ellipse(Math.cos(a) * r, Math.sin(a) * r, 2.2, 0.9, a, 0, Math.PI * 2);
          c.fill();
        }
        c.rotate(ANGLE[p.dir] + gone * 9);
        c.scale(left, left);
      } else {
        c.rotate(ANGLE[p.dir]);
      }
      drawPuffin(c, g.frame, p.moving && g.phase === "play");
      c.restore();
    });
  }

  private hunter(g: Game, h: Hunter): void {
    const c = this.c, at = position(h);
    const warning = h.state === "mobbed" && g.mob < MOB_WARNING && Math.floor(g.mob / 8) % 2 === 0;
    const coat = h.state === "mobbed" && !warning ? COWED : COATS[h.kind];
    const flies = h.kind === "skua" || h.kind === "raven";
    across(at.x, (px) => {
      const py = TOP + (at.y / UNIT) * TILE + TILE / 2 + (h.state === "den" ? Math.sin(g.frame / 11 + px) * 1.2 : 0);
      c.save();
      c.translate(px, py);
      if (h.state === "routed") { c.globalAlpha = 0.45; c.scale(0.8, 0.8); }
      if (flies && h.state !== "den") {
        c.fillStyle = "rgba(0,0,0,.22)";
        c.beginPath();
        c.ellipse(2.5, 3.5, 6, 4, 0, 0, Math.PI * 2);
        c.fill();
      }
      c.save();
      c.rotate(ANGLE[h.dir]);
      drawHunter(c, h.kind, coat, g.phase === "play" ? g.frame : 0, h.dive > 0);
      c.restore();
      if (h.state === "mobbed") {
        // Two terns wheel round a mobbed hunter.
        for (let i = 0; i < 2; i++) {
          const a = g.frame / 7 + i * Math.PI + px;
          c.save();
          c.translate(Math.cos(a) * 9.5, Math.sin(a) * 8);
          c.rotate(a + Math.PI / 2);
          drawTern(c, Math.sin(g.frame / 2.5 + i));
          c.restore();
        }
      }
      c.restore();
    });
  }

  private scoreLine(g: Game, season: Season): void {
    const c = this.c;
    text(c, "SCORE", 6, 8, 7, "#9fc3dc", "left");
    text(c, String(g.demo ? 0 : g.score).padStart(5, "0"), 6, 18, 11, "#ffffff", "left");
    text(c, "BEST", W / 2, 8, 7, "#9fc3dc");
    text(c, String(g.best).padStart(5, "0"), W / 2, 18, 11, "#ffe27a");
    text(c, "BURROW", W - 6, 8, 7, "#9fc3dc", "right");
    text(c, String(g.level), W - 6, 18, 11, "#ffffff", "right");

    const y = TOP + ROWS * TILE + BOTTOM / 2;
    if (g.phase !== "attract" && !g.demo) {
      const spare = g.phase === "caught" || g.phase === "over" ? g.lives : g.lives - 1;
      for (let i = 0; i < spare; i++) {
        c.save();
        c.translate(14 + i * 20, y);
        drawPuffin(c, 0, false);
        c.restore();
      }
    }
    if (g.mob > 0 && g.phase === "play") {
      // How much longer the terns stay.
      const full = mobSteps(g.level), w = 90;
      panel(c, W / 2 - w / 2 - 2, y - 5, w + 4, 10, "rgba(10,18,30,.7)");
      c.fillStyle = g.mob < MOB_WARNING && Math.floor(g.mob / 8) % 2 ? "#ff8a6a" : "#ffffff";
      c.fillRect(W / 2 - w / 2, y - 3, (w * g.mob) / full, 6);
    } else if (g.phase !== "attract") {
      text(c, season.name, W / 2, y, 7, "#9fc3dc");
    }
    c.save();
    c.translate(W - 16, y);
    drawTreat(c, TREATS[treatFor(g.level)]);
    c.restore();
  }

  private words(g: Game): void {
    const c = this.c, mid = TOP + (ROWS * TILE) / 2, blink = Math.floor(g.frame / 30) % 2 === 0;
    if (g.phase === "attract") return this.title(g);
    if (g.demo) {
      panel(c, W / 2 - 92, TOP + ROWS * TILE - 46, 184, 34);
      text(c, "DEMO", W / 2, TOP + ROWS * TILE - 36, 9, "#ffe27a");
      if (blink) text(c, "PRESS ENTER OR TAP TO PLAY", W / 2, TOP + ROWS * TILE - 22, 8, "#ffffff");
      return;
    }
    if (g.paused) {
      panel(c, W / 2 - 60, mid - 20, 120, 40);
      text(c, "PAUSED", W / 2, mid - 5, 14, "#ffffff");
      text(c, "P TO CARRY ON", W / 2, mid + 10, 7, "#9fc3dc");
    } else if (g.phase === "ready") {
      panel(c, W / 2 - 54, cy(tileAt(10, 15)) - 17, 108, 34);
      text(c, `BURROW ${g.level}`, W / 2, cy(tileAt(10, 15)) - 7, 8, "#9fc3dc");
      text(c, "READY!", W / 2, cy(tileAt(10, 15)) + 6, 13, "#ffe27a");
    } else if (g.phase === "cleared") {
      panel(c, W / 2 - 78, mid - 20, 156, 40);
      text(c, "BURROW CLEARED", W / 2, mid - 5, 13, "#ffe27a");
      text(c, g.clean ? "NOT A FEATHER LOST: +500" : "ON TO THE NEXT", W / 2, mid + 10, 7, "#ffffff");
    } else if (g.phase === "over") {
      panel(c, W / 2 - 80, mid - 30, 160, 60);
      text(c, "GAME OVER", W / 2, mid - 13, 16, "#ff8a6a");
      text(c, `SCORE ${g.score}`, W / 2, mid + 4, 9, "#ffffff");
      if (blink) text(c, "ENTER OR TAP TO PLAY AGAIN", W / 2, mid + 18, 7, "#9fc3dc");
    }
  }

  /** The title screen: the name, who hunts you and how, and what the feather does. */
  private title(g: Game): void {
    const c = this.c;
    panel(c, 14, TOP + 10, W - 28, ROWS * TILE - 20, "rgba(9,17,29,.9)");
    c.save();
    c.translate(W / 2 - 86, TOP + 43);
    c.scale(2.2, 2.2);
    drawPuffin(c, g.frame, true);
    c.restore();
    text(c, "LUNDEY", W / 2 + 18, TOP + 40, 34, "#ffe27a", "center", "#b3401f");
    text(c, "A PUFFIN, A BURROW AND FOUR HUNTERS", W / 2, TOP + 70, 7.5, "#9fc3dc");

    let y = TOP + 98;
    c.save();
    c.translate(42, y);
    drawEel(c, Math.sin(g.frame / 9) * 0.9);
    c.restore();
    text(c, "GATHER EVERY SAND EEL IN THE BURROW", 62, y, 7.5, "#ffffff", "left");
    y += 26;
    KINDS.forEach((kind, i) => {
      c.save();
      c.translate(42, y);
      c.scale(1.25, 1.25);
      drawHunter(c, kind, COATS[kind], g.frame + i * 20);
      c.restore();
      text(c, NAMES[kind][0], 66, y - 5, 8.5, "#ffe27a", "left");
      text(c, NAMES[kind][1], 66, y + 6, 7.5, "#ffffff", "left");
      y += 32;
    });
    c.save();
    c.translate(42, y);
    drawFeather(c, g.frame);
    c.restore();
    text(c, "A TERN'S FEATHER", 66, y - 5, 8.5, "#ffe27a", "left");
    text(c, "the terns mob them: give chase!", 66, y + 6, 7.5, "#ffffff", "left");
    y += 30;
    text(c, "ARROWS OR WASD · SWIPE · GAMEPAD", W / 2, y, 7, "#9fc3dc");
    if (Math.floor(g.frame / 30) % 2 === 0) text(c, "PRESS ENTER OR TAP TO PLAY", W / 2, y + 22, 10, "#ffffff");
    text(c, "P PAUSE · M SOUND", W / 2, y + 40, 7, "#9fc3dc");
  }
}
