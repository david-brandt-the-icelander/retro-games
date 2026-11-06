-- 2026-11-06: the table asks for a name, not an email (owner decision). Removes the column
-- from a database created with the first schema. Apply once, before deploying the Worker that
-- no longer writes it:
--   npx wrangler d1 execute samosa-scores --remote --file worker/migrations/0002-drop-email.sql
ALTER TABLE scores DROP COLUMN email;
