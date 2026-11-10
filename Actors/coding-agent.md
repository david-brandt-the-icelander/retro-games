# Coding agent

**Kind:** agent
**Evidence:** `AGENTS.md` (`Agent instructions`: the single set of instructions for every agent working in the repository; work on a branch and open a pull request), `CLAUDE.md`, `.claude/skills/` (the skills an agent uses to make or audit a game), `docs/database-migrations.md` (written to the agent that applies a migration: "stop and ask the owner"), `AGENTS.md` (`LodeStar`: the implementer and spec-and-verify roles)

## What they want from the system

- To get a change checked and onto main through a pull request: [Ship a change to a game](../.github/.dev/use-case.json), `ship-a-change`.
- To apply a game's database migration to production, at the owner's request, without losing a way back: [Migrate a game's database](../docs/.dev/use-case.json), `migrate-a-database`.

## How they reach it

A checkout of the repository: each game's `npm install` and `npm test` (or `cargo test` for LodeStar), the validators in `Meta/`, `git` and `gh` to push a branch and open a pull request, and `wrangler` against the remote databases only when the owner asks.

## Not to be confused with

The [Owner](owner.md), who decides what goes live and merges. The repository does not tell an agent from a person: both open the same pull requests and run the same checks. The difference is in `AGENTS.md`, which tells agents not to deploy or touch the remote databases unless the owner asks.
