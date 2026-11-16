// MEG's shared high-score table. The game cannot be replayed on the server (its simulation is not
// deterministic), so a score is trusted from the browser, within limits the server can check:
// each run has a ticket issued by the server when it starts, a ticket is used once, and the score
// must be one the time since the ticket could have earned. The owner chose this
// (games/meg/.dev/decisions.json, trusted-scores); a cheater can still fake a plausible score.

export const PATH = "/games/retro/meg";
export const BASE = `${PATH}/api`;
export const SCORES_PAGE = `${PATH}/scores`;
/** The table the game shows. */
export const TABLE_SIZE = 10;
/** The public page. */
export const PAGE_SIZE = 25;
/** How many scores are kept. */
export const KEEP = 100;
export const NAME_MAX = 12;
/** A run shorter than this can't have scored. */
export const MIN_RUN_MS = 5_000;
export const RUN_LIFETIME_MS = 24 * 60 * 60 * 1000;
/** The most points a second of play can earn, generously: whale bites, swimmers and sabotage back to back. */
export const POINTS_PER_SECOND = 150;
export const MAX_BODY = 2_000;

export const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json", "Cache-Control": "no-store" } });

/** A name as the table shows it: letters and digits of any alphabet, spaces and . ' _ -, at most 12 characters. */
export function cleanName(raw: unknown): string {
  if (typeof raw !== "string") return "";
  const kept = raw.slice(0, 200).normalize("NFC").replace(/[^\p{L}\p{N} .'_-]/gu, "").replace(/\s+/g, " ").trim();
  const name = [...kept].slice(0, NAME_MAX).join("").trim();
  return /[\p{L}\p{N}]/u.test(name) ? name : "";
}

/** The clear bonuses a run that reached file `file` could have earned: 500 × the file number + up to 1,000 for strength, for every file up to it. */
export const bonusUpTo = (file: number) => 250 * file * (file + 1) + 1000 * file;

/** The most a run that lasted `ms` and reached file `file` could score. */
export const maxScore = (ms: number, file: number) => Math.floor((ms / 1000) * POINTS_PER_SECOND) + bonusUpTo(file);

export interface Submission { id: string; name: string; score: number; file: number }

/** The submission, or why it is refused. */
export function parseSubmission(body: unknown): Submission | string {
  if (!body || typeof body !== "object") return "bad request";
  const b = body as Record<string, unknown>;
  if (typeof b.id !== "string" || !/^[0-9a-f-]{36}$/.test(b.id)) return "bad id";
  if (!Number.isInteger(b.score) || (b.score as number) < 1 || (b.score as number) > 10_000_000) return "bad score";
  if (!Number.isInteger(b.file) || (b.file as number) < 1 || (b.file as number) > 8) return "bad file";
  return { id: b.id, name: cleanName(b.name) || "Anonymous", score: b.score as number, file: b.file as number };
}

export interface Row { name: string; score: number; file: number; created: number }

/** The storage a Durable Object gives (its key-value API). */
export interface Storage {
  get<T>(key: string): Promise<T | undefined>;
  put(key: string, value: unknown): Promise<void>;
  delete(key: string): Promise<boolean>;
}
interface Run { started: number }

/** The table's logic, kept apart from the Durable Object so it can be tested with a Map. */
export class ScoreBook {
  constructor(private store: Storage, private now: () => number = Date.now) {}

  async issue(): Promise<string> {
    const id = crypto.randomUUID();
    await this.store.put(`run:${id}`, { started: this.now() } satisfies Run);
    return id;
  }

  async submit(sub: Submission): Promise<{ score: number; rank: number | null; name: string } | { error: string; status: number }> {
    const run = await this.store.get<Run>(`run:${sub.id}`);
    const age = run ? this.now() - run.started : -1;
    if (!run || age > RUN_LIFETIME_MS) return { error: "unknown or used run", status: 409 };
    if (age < MIN_RUN_MS) return { error: "too soon", status: 422 };
    if (sub.score > maxScore(age, sub.file)) return { error: "not a score that run could reach", status: 422 };
    await this.store.delete(`run:${sub.id}`);
    const rows = (await this.store.get<Row[]>("top")) ?? [];
    const row: Row = { name: sub.name, score: sub.score, file: sub.file, created: this.now() };
    // Ties list oldest first, so the new row goes after every row scoring as much.
    let at = rows.findIndex((r) => r.score < row.score);
    if (at < 0) at = rows.length;
    rows.splice(at, 0, row);
    await this.store.put("top", rows.slice(0, KEEP));
    return { score: row.score, rank: at < KEEP ? at + 1 : null, name: row.name };
  }

  async top(n: number): Promise<Row[]> {
    return ((await this.store.get<Row[]>("top")) ?? []).slice(0, n);
  }
}

/** The one Durable Object that holds the table; requests reach it from the Worker. */
export class ScoreTable {
  private book: ScoreBook;
  constructor(state: { storage: Storage }) { this.book = new ScoreBook(state.storage); }
  async fetch(req: Request): Promise<Response> {
    const route = `${req.method} ${new URL(req.url).pathname}`;
    if (route === "POST /run") return json({ id: await this.book.issue() });
    if (route === "POST /score") {
      const r = await this.book.submit(await req.json() as Submission);
      return "error" in r ? json({ error: r.error }, r.status) : json(r);
    }
    if (route === "GET /top") return json({ scores: await this.book.top(Number(new URL(req.url).searchParams.get("n")) || TABLE_SIZE) });
    return json({ error: "not found" }, 404);
  }
}
