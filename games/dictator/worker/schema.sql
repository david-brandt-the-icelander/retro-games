-- D1 schema for the high-score table. Apply with:
--   npx wrangler d1 execute samosa-scores --remote --file worker/schema.sql
-- Issued seeds: one per reign started in the browser; each can be submitted once.
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  seed INTEGER NOT NULL,
  created INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
);
-- Replayed, verified reigns. `email` is private and never returned by the API; `name` is
-- the part before the @, which is all the table shows.
CREATE TABLE IF NOT EXISTS scores (
  id TEXT PRIMARY KEY REFERENCES games(id),
  email TEXT NOT NULL,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  months INTEGER NOT NULL,
  alive INTEGER NOT NULL,
  created INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS scores_by_score ON scores (score DESC, created ASC);
