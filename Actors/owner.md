# Owner

**Kind:** person in a role
**Evidence:** `AGENTS.md` (`Agent instructions`: never deploy, or run `wrangler` against the remote databases, unless the owner asks; merging is deploying), `docs/database-migrations.md` (`Applying it to production`: only when the owner has asked for the change to go live; `When something went wrong`: only the owner decides on a restore), `.github/workflows/deploy.yml` (`on.workflow_dispatch`, and the `production` environment's reviewer), the `decisions` records whose `waitingOn` is the owner (listed by the explorer's Waiting panel)

## What they want from the system

- To see a change to a game live on icelander.net, after it has been checked: [Ship a change to a game](../.github/.dev/use-case.json), `ship-a-change`.
- To have a game's live database changed only when they ask, and to decide themselves whether to undo it: [Migrate a game's database](../docs/.dev/use-case.json), `migrate-a-database`.
- To answer the questions only they can answer, as open decisions: [the repository's](../.dev/decisions.json), [every game's](../games/.dev/decisions.json), and each game's own `.dev/decisions.json`.

## How they reach it

GitHub: pull requests to merge, Run workflow on the Deploy workflow, and the `production` environment's approval when a reviewer is set. Cloudflare, with the account's credentials, for what the workflows never do (database migrations, secrets).

## Not to be confused with

The [Coding agent](coding-agent.md), which makes and checks changes and applies migrations at the owner's request, and the [Player](player.md): the code knows players by their icelander.net sign-in and the `games:play` role, and knows nothing of the owner, whose authority comes from GitHub and Cloudflare, outside the games.
