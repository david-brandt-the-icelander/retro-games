-- After Gambit moved to icelander.net's login service (README, "Sign-in"): its own sessions are no longer used.
--   npx wrangler d1 execute chess --remote --file worker/retire-sessions.sql
DROP TABLE IF EXISTS sessions;
