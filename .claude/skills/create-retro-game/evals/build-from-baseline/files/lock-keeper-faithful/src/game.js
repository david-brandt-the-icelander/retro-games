import { TEXT, BOATS } from "./data.js";

export const DAYS = 20;

export function newGame(seed) {
  return { day: 1, water: 5, coins: 50, goodwill: 3, rng: seed >>> 0 };
}

export function snapshot(s) {
  return { day: s.day, water: s.water, coins: s.coins, goodwill: s.goodwill, rng: s.rng };
}

// mulberry32, kept in the state so a seed replays the same game.
export function random(s) {
  s.rng = (s.rng + 0x6d2b79f5) >>> 0;
  let t = s.rng;
  t = Math.imul(t ^ (t >>> 15), t | 1);
  t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
  return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
}

// Line 220: b=INT(RND*4)+1, here 0-based.
export const pickBoat = (s) => Math.floor(random(s) * 4);

// Lines 290-300.
export function decide(s, b, key) {
  if (key === "o") {
    s.water -= BOATS[b].water;
    s.coins += BOATS[b].toll;
    s.goodwill += BOATS[b].goodwill;
  } else {
    s.goodwill -= 1;
  }
}

// Lines 310-320: rain one day in three, then the cap.
export function rainfall(s) {
  const wet = Math.floor(random(s) * 3) === 0;
  if (wet) s.water += 2;
  if (s.water > 9) s.water = 9;
  return wet;
}

// Lines 330-360: 0 dry, 1 broke, 2 sacked, 3 retired, -1 carry on.
export function verdict(s) {
  if (s.water < 1) return 0;
  if (s.coins < 0) return 1;
  if (s.goodwill < 1) return 2;
  s.day += 1;
  return s.day > DAYS ? 3 : -1;
}

// One game, from the title screen to the ending. Resolves with the new best.
export async function playGame(io, s, best = 0) {
  if ((await io.show({ kind: "title", lines: TEXT.title })) === "i") {
    await io.show({ kind: "help", lines: TEXT.help });
  }
  for (;;) {
    const b = pickBoat(s);
    const screen = { kind: "day", boat: b, lines: [TEXT.day(s.day), TEXT.status(s), BOATS[b].text, TEXT.prompt] };
    let key = await io.show(screen);
    while (key !== "o" && key !== "k") key = await io.show(screen); // line 280
    decide(s, b, key);
    const wet = rainfall(s);
    const lines = wet ? [TEXT.rain] : [];
    const end = verdict(s);
    if (end >= 0) {
      if (s.day > best) best = s.day;
      await io.show({ kind: "ending", reason: end, rained: wet, lines: [...lines, TEXT.endings[end], TEXT.best(best)] });
      return best;
    }
    await io.show({ kind: "next", rained: wet, lines: [...lines, TEXT.next] });
  }
}
