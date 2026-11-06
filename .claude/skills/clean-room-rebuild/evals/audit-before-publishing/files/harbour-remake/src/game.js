import { EVENTS, ENDINGS, PORT, TITLE, MAP } from "./data.js";

// Line-for-line port of BASIC lines 100-360.
export function newGame() {
  return { gold: 100, crew: 12, day: 1, rep: 5, over: null };
}

export function titleScreen() {
  // Same layout as the original: rows 3, 6, 8, 12.
  return [[3, 8, TITLE[0]], [6, 4, TITLE[1]], [8, 6, TITLE[2]], [12, 3, TITLE[3]]];
}

export function line200(state, rnd) {
  const lines = [];
  lines.push("Day " + state.day + " in the port of " + PORT);
  lines.push("The harbour bell tolls. A ship drops anchor.");
  const s = Math.floor(rnd * 4) + 1; // line 230
  const ev = EVENTS[s - 1];          // lines 240-270
  lines.push(ev.text);
  lines.push("Accept (Y/N)?");        // line 280
  return { lines, s, g: ev.gold, r: ev.rep };
}

export function line300(state, ev, answer) {
  let g = ev.g, r = ev.r;
  if (answer === "n") { r = -r; g = 0; }      // line 300
  state.gold = state.gold + g;                 // line 310
  state.rep = state.rep + r;
  if (state.gold < 0) { state.over = ENDINGS.ruined; return state; }     // GO TO 800
  if (state.rep < 1) { state.over = ENDINGS.deposed; return state; }     // GO TO 810
  if (state.rep > 14) { state.over = ENDINGS.promoted; return state; }   // GO TO 820
  state.day = state.day + 1;
  if (state.day > 30) { state.over = ENDINGS.survived; }                // GO TO 830
  return state;
}

export function harbourMap() { return MAP; }
