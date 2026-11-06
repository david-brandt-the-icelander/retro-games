-- D1 schema for the high-score table. Apply with:
--   npx wrangler d1 execute shatterbelt-scores --remote --file worker/schema.sql
-- Issued seeds: one per game started in the browser; each can be submitted once.
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  seed INTEGER NOT NULL,
  created INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
);
-- Replayed, verified scores: one row per player who entered initials. No personal data.
CREATE TABLE IF NOT EXISTS scores (
  id TEXT PRIMARY KEY,
  game TEXT NOT NULL REFERENCES games(id),
  player INTEGER NOT NULL,
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  wave INTEGER NOT NULL,
  mode TEXT NOT NULL,
  players INTEGER NOT NULL,
  created INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS scores_by_score ON scores (score DESC, created ASC);
