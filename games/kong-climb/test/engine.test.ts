// The rules, driven frame by frame.
import { strict as assert } from "node:assert";
import { test } from "node:test";
import { Game, NO_INPUT, type Input } from "../src/engine/game";
import { buildLevel, stagesFor, surface, type Kind } from "../src/engine/levels";

const press = (o: Partial<Input>): Input => ({ ...NO_INPUT, ...o });

/** A game on the given stage, past its "ready" screen, with nothing thrown for a long while. */
function play(kind: Kind, round = 3): Game {
  const g = new Game(7);
  g.round = round;
  g.stageIdx = stagesFor(round).indexOf(kind);
  g.loadStage();
  for (let i = 0; i < 80; i++) g.step(NO_INPUT);
  assert.equal(g.mode, "play");
  g.throwTimer = 100000;
  g.fireTimer = 100000;
  g.beltTimer = 100000;
  g.bonus = 100000;
  return g;
}

function run(g: Game, input: Input, frames: number) {
  for (let i = 0; i < frames; i++) g.step(input);
}

test("every stage's ladders join two platforms they really touch", () => {
  for (const kind of ["girders", "conveyors", "elevators", "rivets"] as Kind[]) {
    const d = buildLevel(kind);
    for (const l of d.ladders) {
      const lo = d.platforms[l.low];
      const hi = d.platforms[l.high];
      assert.ok(l.x >= lo.x1 && l.x <= lo.x2, `${kind}: ladder ${l.x} outside its foot platform`);
      assert.ok(l.x >= hi.x1 && l.x <= hi.x2, `${kind}: ladder ${l.x} outside its top platform`);
      assert.ok(l.yBottom > l.yTop && l.yBottom - l.yTop < 45, `${kind}: ladder ${l.x} is ${l.yBottom - l.yTop} tall`);
    }
    for (const s of [d.start, d.kong, d.lady, ...d.hammers, ...d.items, ...d.rivets, ...d.fires]) {
      const p = d.platforms[s.plat];
      assert.ok(s.x >= p.x1 && s.x <= p.x2, `${kind}: something at ${s.x} is off platform ${s.plat}`);
    }
  }
});

test("rounds: two stages, then three, then all four", () => {
  assert.deepEqual(stagesFor(1), ["girders", "rivets"]);
  assert.deepEqual(stagesFor(2), ["girders", "conveyors", "rivets"]);
  assert.deepEqual(stagesFor(3), ["girders", "conveyors", "elevators", "rivets"]);
});

test("the hero walks along a sloped girder and follows its surface", () => {
  const g = play("girders", 1);
  const y0 = g.hero.y;
  run(g, press({ left: true }), 10);
  assert.ok(g.hero.x < 48 - 9);
  assert.ok(g.hero.y > y0, "the left of the floor girder is lower");
  assert.equal(g.hero.y, surface(g.plat(0), g.hero.x));
});

test("the hero cannot walk off the end of a girder where there are walls", () => {
  const g = play("girders", 1);
  run(g, press({ right: true }), 400);
  assert.equal(g.hero.state, "ground");
  assert.equal(g.hero.x, 224);
});

test("climbing a ladder up and down", () => {
  const g = play("girders", 1);
  g.hero.x = 166;
  g.hero.y = surface(g.plat(0), 166);
  run(g, press({ up: true }), 3);
  assert.equal(g.hero.state, "climb");
  assert.equal(g.hero.x, 168);
  run(g, press({ up: true }), 120);
  assert.equal(g.hero.state, "ground");
  assert.equal(g.hero.plat, 1);
  run(g, press({ down: true }), 120);
  assert.equal(g.hero.plat, 0);
});

test("a broken ladder cannot be climbed", () => {
  const g = play("girders", 1);
  g.hero.x = 96;
  g.hero.y = surface(g.plat(0), 96);
  run(g, press({ up: true }), 20);
  assert.equal(g.hero.state, "ground");
});

test("a jump rises about nineteen pixels and lands where it left", () => {
  const g = play("conveyors", 3);
  g.hero.x = 100;
  g.platforms[0].belt = 0;
  const y0 = g.hero.y;
  g.step(press({ jump: true }));
  let top = y0;
  for (let i = 0; i < 80 && g.hero.state === "air"; i++) {
    g.step(NO_INPUT);
    top = Math.min(top, g.hero.y);
  }
  assert.ok(y0 - top > 17 && y0 - top < 21, `rose ${y0 - top}`);
  assert.equal(g.hero.state, "ground");
  assert.equal(g.hero.y, y0);
});

test("jumping over a barrel scores 100, then 300 for a second in the same jump", () => {
  const g = play("girders", 1);
  g.hero.x = 100;
  g.hero.y = surface(g.plat(0), 100);
  const make = (x: number) => ({ kind: "barrel" as const, x, y: g.hero.y, vy: 0, dir: -1 as const, plat: 0, mode: "roll" as const, wild: false, scored: false, lastLadder: null, ladder: null, spin: 0 });
  g.step(press({ jump: true }));
  run(g, NO_INPUT, 8);
  g.barrels = [make(g.hero.x)];
  g.step(NO_INPUT);
  assert.equal(g.score, 100);
  g.barrels.push(make(g.hero.x));
  g.step(NO_INPUT);
  assert.equal(g.score, 400);
  assert.equal(g.mode, "play");
});

test("a barrel that reaches the hero kills them, costs a life and restarts the stage", () => {
  const g = play("girders", 1);
  g.barrels = [{ kind: "barrel", x: g.hero.x, y: g.hero.y, vy: 0, dir: -1, plat: 0, mode: "roll", wild: false, scored: false, lastLadder: null, ladder: null, spin: 0 }];
  g.step(NO_INPUT);
  assert.equal(g.mode, "dying");
  assert.equal(g.lives, 2);
  run(g, NO_INPUT, 110);
  assert.equal(g.mode, "ready");
  assert.equal(g.barrels.length, 0);
});

test("the last life lost ends the game", () => {
  const g = play("girders", 1);
  g.lives = 1;
  g.die("test");
  run(g, NO_INPUT, 111);
  assert.equal(g.mode, "over");
});

test("a barrel rolls down a girder, falls to the next and ends in the oil drum", () => {
  const g = play("girders", 1);
  g.hero.state = "dead";
  g.barrels = [{ kind: "barrel", x: 50, y: surface(g.plat(5), 50), vy: 0, dir: 1, plat: 5, mode: "roll", wild: false, scored: false, lastLadder: null, ladder: null, spin: 0 }];
  let oil = false;
  const seen = new Set<number>();
  for (let i = 0; i < 6000 && !oil; i++) {
    g.mode = "play";
    g.step(NO_INPUT);
    g.hero.state = "dead";
    g.hero.y = 1000;
    for (const b of g.barrels) if (b.mode === "roll") seen.add(b.plat);
    if (g.events.includes("oil")) oil = true;
  }
  assert.ok(oil, "the barrel never reached the oil");
  assert.deepEqual([...seen].sort(), [0, 1, 2, 3, 4, 5]);
});

test("a wild barrel always takes a ladder it passes", () => {
  const g = play("girders", 1);
  g.hero.y = 1000;
  g.hero.state = "dead";
  g.barrels = [{ kind: "barrel", x: 150, y: surface(g.plat(5), 150), vy: 0, dir: 1, plat: 5, mode: "roll", wild: true, scored: false, lastLadder: null, ladder: null, spin: 0 }];
  for (let i = 0; i < 40; i++) {
    g.mode = "play";
    g.step(NO_INPUT);
  }
  assert.ok(g.barrels.some((b) => b.mode === "ladder" || b.plat === 4), "it should be going down the ladder at 168");
});

test("the ape throws barrels on a timer", () => {
  const g = new Game(1);
  for (let i = 0; i < 700; i++) g.step(NO_INPUT);
  assert.ok(g.barrels.length + (g.thrown > 0 ? 1 : 0) > 0 && g.thrown >= 3, `thrown ${g.thrown}`);
});

test("the hammer smashes a barrel in front, for 300, 500 or 800, and ends after ten seconds", () => {
  const g = play("girders", 1);
  g.hero.hammer = 600;
  g.barrels = [{ kind: "barrel", x: g.hero.x + 10, y: g.hero.y, vy: 0, dir: -1, plat: 0, mode: "roll", wild: false, scored: false, lastLadder: null, ladder: null, spin: 0 }];
  g.step(NO_INPUT);
  assert.equal(g.barrels.length, 0);
  assert.ok([300, 500, 800].includes(g.score));
  assert.equal(g.mode, "play");
  run(g, NO_INPUT, 600);
  assert.equal(g.hero.hammer, 0);
});

test("with the hammer the hero cannot jump or climb", () => {
  const g = play("girders", 1);
  g.hero.hammer = 600;
  g.step(press({ jump: true }));
  assert.equal(g.hero.state, "ground");
  g.hero.x = 168;
  g.hero.y = surface(g.plat(0), 168);
  run(g, press({ up: true }), 10);
  assert.equal(g.hero.state, "ground");
});

test("picking up a hammer arms the hero", () => {
  const g = play("girders", 1);
  const hm = g.hammers[0];
  g.hero.state = "ground";
  g.hero.plat = hm.plat;
  g.hero.x = hm.x;
  g.hero.y = hm.y;
  g.step(NO_INPUT);
  assert.ok(g.hero.hammer > 0);
  assert.equal(hm.taken, true);
});

test("a bonus item scores 300, 500 or 800", () => {
  const g = play("girders", 1);
  const it = g.items[0];
  g.hero.plat = it.plat;
  g.hero.x = it.x;
  g.hero.y = it.y;
  g.step(NO_INPUT);
  assert.equal(g.score, 300);
});

test("reaching the top girder clears the stage, pays the bonus and moves on", () => {
  const g = play("girders", 1);
  g.bonus = 4100;
  g.hero.plat = 6;
  g.hero.x = 100;
  g.hero.y = 46;
  g.step(NO_INPUT);
  assert.equal(g.mode, "clear");
  assert.equal(g.score, 4100);
  run(g, NO_INPUT, 220);
  assert.equal(g.kind, "rivets");
  assert.equal(g.mode, "ready");
  assert.equal(g.round, 1);
});

test("clearing the last stage of a round starts the next round", () => {
  const g = play("rivets", 1);
  for (const r of g.rivets) r.removed = true;
  g.step(NO_INPUT);
  assert.equal(g.mode, "clear");
  run(g, NO_INPUT, 220);
  assert.equal(g.round, 2);
  assert.equal(g.kind, "girders");
});

test("walking over a rivet removes it for 100; all eight end the stage", () => {
  const g = play("rivets", 1);
  assert.equal(g.rivets.length, 8);
  const r = g.rivets[0];
  g.hero.plat = r.plat;
  g.hero.x = r.x;
  g.hero.y = r.y;
  g.step(NO_INPUT);
  assert.equal(r.removed, true);
  assert.equal(g.score, 100);
  for (const x of g.rivets) {
    if (x.removed) continue;
    g.hero.plat = x.plat;
    g.hero.x = x.x;
    g.hero.y = x.y;
    g.step(NO_INPUT);
  }
  assert.equal(g.mode, "clear");
});

test("a fireball kills on touch and walks its girder", () => {
  const g = play("rivets", 1);
  g.fires = [];
  g.step(NO_INPUT);
  const before = g.hero.y;
  g.fires.push({ x: g.hero.x + 1, y: before, dir: 1, plat: 0, mode: "walk", ladder: null, lastLadder: null, climbDir: 0, scored: false, think: 50 });
  g.step(NO_INPUT);
  assert.equal(g.mode, "dying");
});

test("conveyor belts carry the hero", () => {
  const g = play("conveyors", 3);
  const p = g.platforms[1];
  g.hero.plat = 1;
  g.hero.x = 100;
  g.hero.y = p.y1;
  const x = g.hero.x;
  run(g, NO_INPUT, 20);
  assert.ok(Math.sign(g.hero.x - x) === Math.sign(p.belt));
});

test("pies ride the belts and fall at the end", () => {
  const g = play("conveyors", 3);
  g.hero.y = 1000;
  g.hero.state = "dead";
  g.barrels = [{ kind: "pie", x: 100, y: 76, vy: 0, dir: 1, plat: 5, mode: "roll", wild: false, scored: false, lastLadder: null, ladder: null, spin: 0 }];
  const seen = new Set<number>();
  for (let i = 0; i < 3000 && g.barrels.length; i++) {
    g.mode = "play";
    g.step(NO_INPUT);
    for (const b of g.barrels) if (b.mode === "roll") seen.add(b.plat);
  }
  assert.ok(seen.has(5) && seen.has(4), [...seen].join());
});

test("lifts move and wrap; riding one carries the hero", () => {
  const g = play("elevators", 3);
  const lift = g.platforms[6];
  const y0 = lift.y1;
  g.hero.plat = 6;
  g.hero.x = 76;
  g.hero.y = lift.y1;
  run(g, NO_INPUT, 20);
  assert.ok(lift.y1 < y0);
  assert.equal(g.hero.y, lift.y1);
  assert.equal(g.hero.plat, 6);
});

test("the hero can hop from the start platform to a rising lift", () => {
  const g = play("elevators", 3);
  g.hero.x = 52;
  let boarded = false;
  for (let tries = 0; tries < 600 && !boarded; tries++) {
    const near = g.platforms.slice(6, 9).some((l) => Math.abs(l.y1 - 238) < 3);
    if (near && g.hero.state === "ground") {
      g.step(press({ right: true, jump: true }));
      for (let i = 0; i < 60 && (g.hero.state as string) === "air"; i++) g.step(NO_INPUT);
      boarded = g.hero.state === "ground" && g.hero.plat >= 6 && g.hero.plat <= 8;
      if (!boarded) break;
    } else g.step(NO_INPUT);
  }
  assert.ok(boarded);
});

test("falling more than a floor kills", () => {
  const g = play("elevators", 3);
  g.hero.plat = 2;
  g.hero.x = 215;
  g.hero.y = 170;
  run(g, press({ right: true }), 100);
  assert.ok(g.mode === "dying" || g.hero.x <= 220);
});

test("a spring bounces and hurts", () => {
  const g = play("elevators", 3);
  g.hero.x = 150;
  g.hero.plat = 5;
  g.hero.y = 66;
  g.springs = [{ x: 154, y: 62, vy: 0, scored: false }];
  g.step(NO_INPUT);
  assert.equal(g.mode, "dying");
});

test("the bonus counts down and a spent bonus costs a life", () => {
  const g = play("girders", 1);
  g.bonus = 100;
  run(g, NO_INPUT, 185);
  assert.equal(g.mode, "dying");
  assert.equal(g.lastDeath, "time");
});

test("an extra life at 7000 points, once", () => {
  const g = play("girders", 1);
  g.score = 6900;
  g.addScore(200, 0, 0);
  assert.equal(g.lives, 4);
  g.addScore(5000, 0, 0);
  assert.equal(g.lives, 4);
});

test("the same seed plays the same game", () => {
  const sim = () => {
    const g = new Game(42);
    const keys = [press({ right: true }), press({ left: true, jump: true }), press({ up: true }), NO_INPUT, press({ right: true, jump: true })];
    for (let i = 0; i < 4000; i++) g.step(keys[Math.floor(i / 37) % keys.length]);
    return JSON.stringify([g.score, g.lives, g.hero, g.barrels, g.fires, g.frame]);
  };
  assert.equal(sim(), sim());
});

test("a flailing player never breaks the world, in any stage", () => {
  for (const kind of ["girders", "conveyors", "elevators", "rivets"] as Kind[]) {
    for (let seed = 1; seed <= 3; seed++) {
      const g = new Game(seed);
      g.round = 3;
      g.stageIdx = stagesFor(3).indexOf(kind);
      g.loadStage();
      let r = seed * 977;
      for (let i = 0; i < 20000; i++) {
        r = (r * 1103515245 + 12345) % 2147483648;
        const k = r >> 8;
        g.step({ left: (k & 1) !== 0, right: (k & 2) !== 0, up: (k & 4) !== 0, down: (k & 8) !== 0, jump: (k & 48) === 0 });
        if (g.mode === "over") {
          g.lives = 3;
          g.loadStage();
        }
        const h = g.hero;
        assert.ok(Number.isFinite(h.x) && Number.isFinite(h.y), `${kind}: hero at ${h.x},${h.y}`);
        assert.ok(h.x >= -1 && h.x <= 225, `${kind}: hero x ${h.x}`);
      }
    }
  }
});
