// The high-score server: a game is scored only by replaying it from its seed and recorded controls.
import assert from "node:assert/strict";
import { test } from "node:test";
import { Game, Input, NO_INPUT } from "../src/engine/game";
import { MAX_FRAMES, Recorder, fromBits, replay, toBits } from "../src/engine/replay";
import { RULES } from "../src/engine/rules";
import { dcos, dsin } from "../src/engine/trig";
import { glyph } from "../src/ui/art";
import worker, { Env } from "../worker/index";
import { scoresPage } from "../worker/scores-page";
import { cleanName } from "../worker/scores";

/** Plays a whole game with a simple bot, the way the page does: the seed is set before 1 or 2 is pressed. */
function playRecorded(seed: number, players: 1 | 2) {
  const g = new Game(12345); // the title screen's own seed must not matter
  for (let i = 0; i < 77; i++) g.step(NO_INPUT); // some time on the title screen first
  g.nextSeed = seed;
  const rec = new Recorder();
  let t = 0;
  for (;;) {
    const input: Input = { ...NO_INPUT };
    if (t === 0) input[players === 1 ? "start1" : "start2"] = true;
    else {
      const targets = g.aliens.filter((a) => a.alive);
      const danger = g.bullets.find((b) => b.y > RULES.player.y - 40 && Math.abs(b.x - g.playerX) < 10);
      const tx = danger ? g.playerX + (danger.x < g.playerX ? 20 : -20) : targets.length ? targets[(t >> 7) % targets.length].x : 112;
      input.left = tx < g.playerX - 2;
      input.right = tx > g.playerX + 2;
      input.fire = t % 3 !== 0;
      input.pause = t % 997 === 0 || t % 997 === 30; // pause now and then, as a player might
    }
    t++;
    g.step(input);
    rec.push(input);
    if (g.phase === "gameOver") break;
  }
  return { runs: rec.runs, frames: rec.frames, scores: g.players.map((p) => ({ score: p.score, wave: p.wave })) };
}

test("our sine and cosine agree with Math's to 1e-6", () => {
  for (let x = -50; x <= 50; x += 0.0137) {
    assert.ok(Math.abs(dsin(x) - Math.sin(x)) < 1e-6, `sin ${x}`);
    assert.ok(Math.abs(dcos(x) - Math.cos(x)) < 1e-6, `cos ${x}`);
  }
});

test("inputs pack into bits and back", () => {
  for (let b = 0; b < 64; b++) assert.equal(toBits(fromBits(b)), b);
  const r = new Recorder();
  for (const i of [NO_INPUT, NO_INPUT, { ...NO_INPUT, fire: true }, NO_INPUT]) r.push(i);
  assert.deepEqual(r.runs, [0, 2, 4, 1, 0, 1]);
  assert.equal(r.frames, 4);
});

test("a replay from the seed and the controls gives the same scores, for one and two players", () => {
  for (let seed = 1; seed <= 12; seed++) {
    const players = seed % 2 === 0 ? 2 : 1;
    const game = playRecorded(seed * 7919, players);
    assert.deepEqual(replay(seed * 7919, game.runs), { players, scores: game.scores, frames: game.frames }, `seed ${seed}`);
  }
});

test("a replay is refused unless the controls play exactly one whole game", () => {
  const game = playRecorded(42, 1);
  const runs = game.runs;
  const short = runs[runs.length - 1] > 1 ? [...runs.slice(0, -1), runs[runs.length - 1] - 1] : runs.slice(0, -2);
  assert.equal(replay(42, short), null, "one frame short");
  assert.equal(replay(42, [...runs, 0, 1]), null, "a frame left over");
  assert.equal(replay(42, [0, 1, ...runs]), null, "does not start a game on its first frame");
  assert.equal(replay(42, []), null);
  assert.equal(replay(42, "nonsense"), null);
  assert.equal(replay(42, [4, 1.5]), null, "counts are whole numbers");
  assert.equal(replay(42, [64, 1]), null, "only known buttons");
  assert.equal(replay(42, [8, 1, 0, MAX_FRAMES]), null, "no longer than the limit");
});

test("a name is cleaned to what the game's font can draw, up to 12 characters", () => {
  assert.equal(cleanName("Davíð Brandt"), "David Brandt");
  assert.equal(cleanName("Þórður"), "Thordur");
  assert.equal(cleanName("Ace <b>"), "Ace b");
  for (const empty of ["", "   ", "!!!", 42, undefined]) assert.equal(cleanName(empty), "");
  for (const raw of ["Davíð", "Ærnöld Þrándur", "x".repeat(300), "a\u0000b\n<c>&d", "O'Neil-Smith_2"]) {
    for (const ch of cleanName(raw).toUpperCase()) assert.ok(glyph(ch), `${raw}: no glyph for ${ch}`);
  }
});

test("the high-score web page lists the scores, escapes names, and carries the site's footer", async () => {
  const html = await scoresPage([{ name: "ace", score: 12000, wave: 5, players: 1 }, { name: "<b>x</b>", score: 70, wave: 1, players: 2 }]).text();
  assert.match(html, /<td>1<\/td><td>ace<\/td><td class="num">12000<\/td><td class="num">5<\/td><td>1 player<\/td>/);
  assert.match(html, /&lt;b&gt;x&lt;\/b&gt;/);
  assert.doesNotMatch(html, /<b>x<\/b>/);
  assert.match(html, /<a href="https:\/\/icelander\.net\/trains">Trains of thought<\/a> · <a href="\/">Games<\/a>/);
  assert.match(await scoresPage([]).text(), /No score recorded yet/);
});

// A stand-in for D1 that understands exactly the statements worker/index.ts uses.
function fakeEnv(): Env & { rows: { games: Map<string, { seed: number; created: number; used: number }>; scores: Record<string, unknown>[] } } {
  const games = new Map<string, { seed: number; created: number; used: number }>();
  const scores: Record<string, unknown>[] = [];
  const DB = {
    prepare(sql: string) {
      let args: unknown[] = [];
      const st = {
        bind(...v: unknown[]) { args = v; return st; },
        async first<T>() {
          if (sql.startsWith("SELECT seed")) return (games.get(args[0] as string) ?? null) as T;
          if (sql.startsWith("SELECT COUNT")) return { n: scores.filter((s) => (s.score as number) > (args[0] as number)).length } as T;
          throw new Error(sql);
        },
        async all<T>() {
          const sorted = [...scores].sort((a, b) => (b.score as number) - (a.score as number) || (a.created as number) - (b.created as number));
          return { results: sorted.slice(0, args[0] as number) as T[], meta: { changes: 0 } };
        },
        async run() {
          if (sql.startsWith("DELETE")) return { results: [], meta: { changes: 0 } };
          if (sql.startsWith("INSERT INTO games")) { games.set(args[0] as string, { seed: args[1] as number, created: args[2] as number, used: 0 }); return { results: [], meta: { changes: 1 } }; }
          if (sql.startsWith("UPDATE games")) {
            const g = games.get(args[0] as string);
            if (!g || g.used) return { results: [], meta: { changes: 0 } };
            g.used = 1;
            return { results: [], meta: { changes: 1 } };
          }
          if (sql.startsWith("INSERT INTO scores")) {
            const [game, player, name, score, wave, players, created] = args;
            scores.push({ game, player, name, score, wave, players, created });
            return { results: [], meta: { changes: 1 } };
          }
          throw new Error(sql);
        },
      };
      return st;
    },
  };
  // A player signed in through the login service (test/sign-in.test.ts covers signing in).
  const ACCOUNTS = { session: async () => ({ id: "a-1", email: "alice@example.com", roles: ["games:play"] }) };
  const ACCOUNTS_JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
  return { DB: DB as never, ASSETS: { fetch: async () => new Response("asset") }, ACCOUNTS: ACCOUNTS as never, ACCOUNTS_JWKS, rows: { games, scores } };
}

const API = "https://games.icelander.net/retro/hivestorm/api";
const post = (env: Env, path: string, body: unknown) =>
  worker.fetch(new Request(`${API}/${path}`, { method: "POST", body: JSON.stringify(body), headers: { Cookie: SIGNED_IN } }), env);
const SIGNED_IN = "games_session=session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";

test("the API issues a seed, scores a replayed two-player game once, and lists it", async () => {
  const env = fakeEnv();
  const { id, seed } = (await (await post(env, "game", {})).json()) as { id: string; seed: number };
  const game = playRecorded(seed, 2);
  const res = await post(env, "score", { id, runs: game.runs, names: ["Ace", null] });
  assert.equal(res.status, 200);
  const { entries } = (await res.json()) as { entries: { player: number; name: string; score: number; rank: number }[] };
  assert.deepEqual(entries.map((e) => [e.player, e.name, e.score, e.rank]), [[1, "Ace", game.scores[0].score, 1]], "only the player who gave a name");
  assert.equal((await post(env, "score", { id, runs: game.runs, names: ["Ace", null] })).status, 409, "each game once");
  const table = (await (await worker.fetch(new Request(`${API}/scores`), env)).json()) as { scores: { name: string; score: number; players: number }[] };
  assert.deepEqual(table.scores.map((s) => [s.name, s.score, s.players]), [["Ace", game.scores[0].score, 2]]);
  const page = await (await worker.fetch(new Request("https://games.icelander.net/retro/hivestorm/scores/"), env)).text();
  assert.match(page, /<td>Ace<\/td>/);
});

test("the API refuses made-up controls, wrong player counts and bad names, and keeps the seed usable", async () => {
  const env = fakeEnv();
  const { id, seed } = (await (await post(env, "game", {})).json()) as { id: string; seed: number };
  const game = playRecorded(seed, 1);
  assert.equal((await post(env, "score", { id, runs: [8, 1, 4, 100], names: ["Ace"] })).status, 422);
  assert.equal((await post(env, "score", { id, runs: game.runs, names: ["Ace", "Bee"] })).status, 422, "a one-player game has one name");
  assert.equal((await post(env, "score", { id, runs: game.runs, names: ["!!!"] })).status, 400);
  assert.equal((await post(env, "score", { id, runs: game.runs, names: [null] })).status, 400, "somebody must enter");
  assert.equal((await post(env, "score", { id: "nope", runs: game.runs, names: ["Ace"] })).status, 409);
  assert.equal(env.rows.scores.length, 0);
  assert.equal((await post(env, "score", { id, runs: game.runs, names: ["Ace"] })).status, 200, "the real game still counts");
  assert.equal((await worker.fetch(new Request("https://games.icelander.net/retro/hivestorm/", { headers: { Cookie: SIGNED_IN } }), env)).status, 200, "the page is the static game");
});
