// A D1 database for tests: the same SQL, run by node:sqlite in memory, with worker/schema.sql applied.
import { readFileSync } from "node:fs";
import { DatabaseSync } from "node:sqlite";
import type { D1Database, D1Result, D1Statement } from "../worker/db";

export function fakeD1(): D1Database {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(new URL("../worker/schema.sql", import.meta.url).pathname.replace("/dist-test/", "/"), "utf8"));
  const stmt = (sql: string, args: unknown[] = []): D1Statement => ({
    bind: (...v: unknown[]) => stmt(sql, v),
    first: async <T>() => (db.prepare(sql).get(...(args as never[])) as T | undefined) ?? null,
    all: async <T>() => ({ results: db.prepare(sql).all(...(args as never[])) as T[], meta: { changes: 0 } }) as D1Result<T>,
    run: async () => ({ results: [], meta: { changes: Number(db.prepare(sql).run(...(args as never[])).changes) } }),
  });
  return { prepare: (sql) => stmt(sql), batch: async (s) => { for (const x of s) await x.run(); return []; } };
}
