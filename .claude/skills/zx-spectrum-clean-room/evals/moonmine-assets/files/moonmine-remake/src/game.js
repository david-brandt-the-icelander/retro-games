import { MESSAGES } from "./messages.js";

// Port of BASIC lines 100-310. rnd() stands in for RND.
export function newGame(rnd) {
  return { x: 1, y: 1, f: 40, gx: Math.floor(rnd() * 8) + 1, gy: Math.floor(rnd() * 8) + 1, sc: 0, msg: MESSAGES[0], over: null };
}

export function line210(s, k, rnd) {
  s.msg = null;
  if (k === "q" && s.y > 1) s.y = s.y - 1; // 220
  if (k === "a" && s.y < 8) s.y = s.y + 1; // 230
  if (k === "o" && s.x > 1) s.x = s.x - 1; // 240
  if (k === "p" && s.x < 8) s.x = s.x + 1; // 250
  s.f = s.f - 1; // 260
  if (s.x === s.gx && s.y === s.gy) { // 270
    s.msg = MESSAGES[2]; s.sc = s.sc + 10; s.f = s.f + 5;
    s.gx = Math.floor(rnd() * 8) + 1; s.gy = Math.floor(rnd() * 8) + 1;
  }
  if (rnd() < 0.05) { s.over = MESSAGES[3]; return s; } // 280: GO SUB 9000: STOP
  if (s.f < 1) { s.over = MESSAGES[1]; return s; }      // 290
  if (s.sc >= 50) { s.over = MESSAGES[4]; }             // 300
  return s;                                             // 310: GO TO 200
}
