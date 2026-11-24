# Database migrations

Production's database is migrated **by hand, never by a deploy**. One check makes sure nobody
forgets:

- **The pull request check** "Database migration" (`.github/workflows/migrations.yml`) fails
  when a pull request changes a game's `worker/schema.sql` or `worker/migrations/` and its description does not acknowledge the
  migration. It runs again whenever the description is edited. `main` requires it, so the pull
  request cannot be merged until then.

It runs `.github/scripts/migration-gate.sh`, which also prints the exact command for each
changed file.

**No gate runs before a deploy any more.** The Deploy workflow, which checked every database
change since the last deploy before uploading anything, was removed (2026-11-21). The owner
deploys each game by hand, from their own machine, with `npm run deploy` in the game's folder,
which does not look at the database: the pull request check is the only one.

Each game has its own D1 database, named in its `wrangler.jsonc`:

| Game | Folder | Database |
|---|---|---|
| Gambit | `games/chess` | `chess` |
| Samosa | `games/dictator` | `samosa-scores` |
| Hivestorm | `games/hivestorm` | `hivestorm-scores` |
| Rally | `games/rally` | `rally-scores` |
| Shatterbelt | `games/shatterbelt` | `shatterbelt-scores` |

MEG (`games/meg`) has no D1 database: its high-score table is a Durable Object, created by the migration in its `wrangler.jsonc` when it deploys, so nothing in it is migrated by hand.

A game's `worker/schema.sql` describes a fresh database; the live one changes only through files in that game's `worker/migrations/`. The commands below run in the game's folder.

## Writing a migration

Add a file `games/<game>/worker/migrations/NNNN-what-it-does.sql`, numbered after the last one (start at `0002`, since `schema.sql` is the first), with a comment at the top saying why, as in `games/dictator/worker/migrations/0002-drop-email.sql`. Make the same change in the game's `worker/schema.sql`, so a fresh database ends up the same as the live one.

A migration is applied **before** the pull request is merged, so the code that is live while
it runs is the old code. Write it so that the old code keeps working:

- Adding a table, an index, or a column that is nullable or has a default is safe.
- Removing or renaming something the live code uses is not. Do it in two pull requests: first
  one that stops using it (merge, deploy), then one with the migration that removes it.

Try it on your local copy first, in the game's folder: `npx wrangler d1 execute <database> --local --file worker/migrations/<file>`.

## Applying it to production

Only do this when the owner has asked for the change to go live. Follow every step, in order.

1. **Check that you can reach Cloudflare.** Run `npx wrangler whoami` in the game's folder. It must name the
   account `ab026008f5aa2bef2dca4cfccd0f70ef`. If it does not, or you have no Cloudflare
   credentials, stop and ask the owner. Do not tick the box.
2. **Record a restore point.** Run
   `cd games/<game> && npx wrangler d1 time-travel info <database>` and copy the bookmark it prints into a
   comment on the pull request.
3. **Apply each new migration file once, in filename order:**

   ```bash
   cd games/<game>
   npx wrangler d1 execute <database> --remote -y --file worker/migrations/<file>
   ```

   Never run a file that has already been applied. Never apply a whole `worker/schema.sql` to the live database.
   If a file fails part-way through, stop and tell the owner; do not re-run it.
4. **Check the result.** Look at a table the migration changed:

   ```bash
   cd games/<game> && npx wrangler d1 execute <database> --remote --command "SELECT sql FROM sqlite_master WHERE name = '<table>'"
   ```

5. **Acknowledge it in the pull request's description.** Add this line, filled in:

   ```text
   - [x] Database migration applied to production: <files>, <database>, <date>
   ```

   For example:

   ```bash
   gh pr view <number> --json body --jq .body > /tmp/pr-body.md
   printf '\n- [x] Database migration applied to production: %s, %s, %s\n' "<files>" "<database>" "$(date +%F)" >> /tmp/pr-body.md
   gh pr edit <number> --body-file /tmp/pr-body.md
   ```

   The "Database migration" check runs again and passes.
6. **Merge.** Merging to `main` deploys nothing. The game goes live when it is deployed from
   the owner's machine with `npm run deploy` in its folder.

### When no migration is needed

If the change cannot affect the live database (only comments or whitespace in a schema file,
say), acknowledge that instead, with the reason:

```text
- [x] No database migration is needed: <why>
```

Never use this line to skip a migration that is needed.

## When something went wrong

- **A database change reached `main` unacknowledged** (pushed without a pull request, say).
  Nothing stops the game being deployed without its migration any more. Apply the migration
  (above) before the game is deployed with `npm run deploy`.
- **The migration broke production.** Tell the owner. Restoring the database to the bookmark
  from step 2 (`cd games/<game> && npx wrangler d1 time-travel restore <database> --bookmark=<bookmark>`) undoes
  every write since then, not just the migration, so only the owner decides on it.
