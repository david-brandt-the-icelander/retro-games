// The shared high-score table (worker/scores.ts) and its API (worker/index.ts). Scores are trusted within
// limits: a ticket per run, used once, and a score the run's time could have earned.
import { test } from "node:test";
import assert from "node:assert/strict";
import worker from "../worker/index";
import { ScoreBook, ScoreTable, cleanName, maxScore, parseSubmission, KEEP, type Storage } from "../worker/scores";

const mapStore = (): Storage & { m: Map<string, unknown> } => {
  const m = new Map<string, unknown>();
  return { m, get: async (k) => m.get(k) as never, put: async (k, v) => { m.set(k, structuredClone(v)) }, delete: async (k) => m.delete(k) };
};
const clock = () => { const c = { t: 1_000_000, now: () => c.t }; return c; };
const sub = (id: string, score: number, file = 1, name = "Jaws") => ({ id, name, score, file });

test("scores: a ticket takes one score, after five seconds, if the time could have earned it", async () => {
  const c = clock(), book = new ScoreBook(mapStore(), c.now);
  const id = await book.issue();
  c.t += 2_000;
  assert.deepEqual(await book.submit(sub(id, 100)), { error: "too soon", status: 422 });
  c.t += 58_000; // a minute in
  assert.deepEqual(await book.submit(sub(id, maxScore(60_000, 1) + 1)), { error: "not a score that run could reach", status: 422 });
  assert.deepEqual(await book.submit(sub(id, 5_000)), { score: 5_000, rank: 1, name: "Jaws" });
  assert.deepEqual(await book.submit(sub(id, 5_000)), { error: "unknown or used run", status: 409 });
  assert.deepEqual(await book.submit(sub("00000000-0000-0000-0000-000000000000", 10)), { error: "unknown or used run", status: 409 });
});

test("scores: a ticket expires after a day", async () => {
  const c = clock(), book = new ScoreBook(mapStore(), c.now);
  const id = await book.issue();
  c.t += 24 * 60 * 60 * 1000 + 1;
  assert.equal(((await book.submit(sub(id, 10))) as { status: number }).status, 409);
});

test("scores: best first, ties oldest first, and only the best hundred kept", async () => {
  const c = clock(), book = new ScoreBook(mapStore(), c.now);
  const play = async (score: number, name: string) => { const id = await book.issue(); c.t += 600_000; return book.submit(sub(id, score, 8, name)); };
  await play(300, "a"); await play(900, "b"); await play(300, "c");
  assert.deepEqual((await book.top(10)).map((r) => r.name), ["b", "a", "c"]);
  for (let i = 0; i < KEEP; i++) await play(1000 + i, `p${i}`);
  assert.equal((await book.top(1000)).length, KEEP);
  assert.equal(((await play(1, "last")) as { rank: number | null }).rank, null);
});

test("scores: names are cleaned; a submission is checked before the table sees it", () => {
  assert.equal(cleanName("  Davíð  Þór!! <b> "), "Davíð Þór b");
  assert.equal(cleanName("Megalodon the Great"), "Megalodon th");
  assert.equal(cleanName("<>!!"), "");
  const id = "12345678-1234-1234-1234-123456789abc";
  assert.equal(parseSubmission({ id, score: 0, file: 1 }), "bad score");
  assert.equal(parseSubmission({ id, score: 10, file: 9 }), "bad file");
  assert.equal(parseSubmission({ id: "x", score: 10, file: 1 }), "bad id");
  assert.deepEqual(parseSubmission({ id, score: 10, file: 2, name: "<>" }), { id, name: "Anonymous", score: 10, file: 2 });
});

// The Worker, with the Durable Object stood in for by ScoreTable over a Map.
const ALICE = "session-alice-xxxxxxxxxxxxxxxxxxxxxxxxxxxx";
const JWKS = JSON.stringify({ keys: [{ kty: "OKP", crv: "Ed25519", kid: "test", x: "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo" }] });
const tableObject = new ScoreTable({ storage: mapStore() });
const env = {
  ASSETS: { fetch: async () => new Response("asset") },
  SCORES: { idFromName: () => "table", get: () => ({ fetch: (r: Request) => tableObject.fetch(r) }) },
  ACCOUNTS: { session: async (v: string, app: string) => (v === ALICE && app === "site" ? { id: "a-1", email: "alice@example.com", roles: ["games:play"] } : null) },
  ACCOUNTS_JWKS: JWKS,
} as never;
const call = (path: string, init: RequestInit = {}) => worker.fetch(new Request("https://icelander.net/games/retro/meg" + path, init), env);
const signedIn = { Cookie: `site_session=${ALICE}` };

test("api: tickets and scores need a sign-in; the table and its page are public", async () => {
  assert.equal((await call("/api/run", { method: "POST" })).status, 401);
  assert.equal((await call("/api/score", { method: "POST", body: "{}" })).status, 401);
  const run = await call("/api/run", { method: "POST", headers: signedIn });
  assert.equal(run.status, 200);
  const { id } = await run.json() as { id: string };
  assert.match(id, /^[0-9a-f-]{36}$/);
  // Too soon for any score: the ticket is checked by the table.
  const early = await call("/api/score", { method: "POST", headers: signedIn, body: JSON.stringify({ id, name: "Alice", score: 50, file: 1 }) });
  assert.equal(early.status, 422);
  assert.equal((await call("/api/score", { method: "POST", headers: signedIn, body: "not json" })).status, 400);
  const scores = await call("/api/scores");
  assert.equal(scores.status, 200);
  assert.deepEqual(await scores.json(), { scores: [] });
  const page = await call("/scores/");
  assert.equal(page.status, 200);
  assert.match(await page.text(), /No score recorded yet/);
  assert.equal((await call("/scores")).status, 301);
});
