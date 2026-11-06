-- D1 schema for Rally's high-score table. Apply with:
--   npx wrangler d1 execute rally-scores --remote --file worker/schema.sql
-- Issued seeds: one per one-player match started in the browser; each can be submitted once.
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  seed INTEGER NOT NULL,
  created INTEGER NOT NULL,
  used INTEGER NOT NULL DEFAULT 0
);
-- Replayed, verified matches: the name the player typed (up to 12 characters), the score the
-- replay computed, the computer's level, and the final points.
CREATE TABLE IF NOT EXISTS scores (
  id TEXT PRIMARY KEY REFERENCES games(id),
  name TEXT NOT NULL,
  score INTEGER NOT NULL,
  level TEXT NOT NULL,
  mine INTEGER NOT NULL,
  theirs INTEGER NOT NULL,
  won INTEGER NOT NULL,
  created INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS scores_by_score ON scores (score DESC, created ASC);
