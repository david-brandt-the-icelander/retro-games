-- D1 schema for the chess Worker. Apply with:
--   npx wrangler d1 execute chess --remote --file worker/schema.sql
-- (and with --local for `wrangler dev`). Every statement is safe to run again.

-- One row per person who has signed in. Google and GitHub accounts with the same verified email are one user.
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  picture TEXT,                     -- profile picture URL from Google or GitHub
  created INTEGER NOT NULL,
  last_seen INTEGER NOT NULL
);

-- Signed-in browsers. Only a hash of the cookie's token is stored.
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL REFERENCES users(id),
  created INTEGER NOT NULL,
  expires INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS sessions_by_user ON sessions (user_id);

-- Challenges are addressed to an email, whether or not anyone has signed in with it yet.
CREATE TABLE IF NOT EXISTS challenges (
  id TEXT PRIMARY KEY,
  from_user TEXT NOT NULL REFERENCES users(id),
  to_email TEXT NOT NULL,
  color TEXT NOT NULL,              -- the challenger's colour: white, black or random
  status TEXT NOT NULL,             -- open, accepted, declined, cancelled
  game_id TEXT,
  created INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS challenges_to ON challenges (to_email, status);
CREATE INDEX IF NOT EXISTS challenges_from ON challenges (from_user, status);

-- Games with friends (kind online) and against the computer (kind computer, one side's user is NULL).
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  level INTEGER,
  white_user TEXT REFERENCES users(id),
  black_user TEXT REFERENCES users(id),
  moves TEXT NOT NULL DEFAULT '',   -- UCI moves separated by spaces
  result TEXT NOT NULL DEFAULT '*',
  reason TEXT,
  draw_offer TEXT,
  created INTEGER NOT NULL,
  updated INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS games_white ON games (white_user, updated);
CREATE INDEX IF NOT EXISTS games_black ON games (black_user, updated);

-- Everything that happens in a game, in order: the moves and the chat, offers and the result, each
-- with its time. This is the game's transcript, shown during play and in the history.
CREATE TABLE IF NOT EXISTS game_events (
  game_id TEXT NOT NULL REFERENCES games(id),
  seq INTEGER NOT NULL,
  at INTEGER NOT NULL,              -- milliseconds since 1970
  kind TEXT NOT NULL,               -- start, move, chat, draw-offer, draw-decline, resign, end
  side TEXT,                        -- white or black: who did it (none for start and end)
  text TEXT,                        -- the move in UCI, the chat message, or the result and reason
  PRIMARY KEY (game_id, seq)
);

-- Each user's contacts: everyone they have played against online.
CREATE TABLE IF NOT EXISTS contacts (
  owner_id TEXT NOT NULL REFERENCES users(id),
  email TEXT NOT NULL,
  name TEXT,
  created INTEGER NOT NULL,
  PRIMARY KEY (owner_id, email)
);
