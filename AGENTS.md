# Agent instructions

Five browser games, each its own npm project under `games/<slug>/` (Samosa lives in `games/dictator/`, Gambit in `games/chess/`). Four have a pure engine in `src/engine/`, a page in `src/main.ts`, a Cloudflare Worker in `worker/` for the replay-checked high-score table, and tests in `test/`; Gambit is a Godot client in `godot/` with its own Worker in `worker/` for sign-in, games and history. Work inside one game's folder: run `npm install` and `npm test` there. Each game's `README.md` says what its files do and how it deploys. Never deploy, or run `wrangler` against the remote databases, unless the owner asks. A merge to `main` deploys every game it changes (`.github/workflows/deploy.yml`), so merging is deploying. Every change reaches `main` through a pull request: `main` requires the "Database migration" check, so GitHub refuses a direct push to it. Work on a branch, push the branch, and open a pull request.

The games' engines must stay deterministic: the server replays every submitted game. Use only `+ − × ÷` and `Math.sqrt` in engine code, and draw random numbers only through the engine's own seeded generator.

`.claude/skills/` holds the skills for making clean-room remakes (`create-retro-game`, `clean-room-rebuild`, `zx-spectrum-clean-room`). Use them when making or auditing a game.

## Database migrations

Read [`docs/database-migrations.md`](docs/database-migrations.md) before changing a game's database. A game's `worker/schema.sql` describes a fresh database; the live one changes only through files in its `worker/migrations/`. A pull request that changes either fails its "Database migration" check, and the deploy refuses to run, until production's database has been migrated and the pull request's description says so.

## Architecture diagrams

Architecture is documented per folder, as JSON diagrams in `.dev/` directories next to the code, following the skills in `Meta/Agents/Skills/`. Read a folder's diagrams before changing it.

- `describe-component-diagram`: the folder is a cohesive capability, adapter, boundary or subsystem (a game, its `src`, `src/engine`, `src/ui`, `src/zx`, `worker`, or Gambit's `godot`, `godot/scripts`, `godot/chess`, `bridge`, `shared`).
- `describe-class-diagram`: the folder itself declares more than one class.
- `describe-state-diagram`: the folder implements a state machine. One `<Identifier>.state-diagram.json` per machine, named after the class or type it belongs to.
- `describe-deployment-diagram`: the folder holds something independently deployable (each game, with its `wrangler.jsonc`).

Every actor a journey, use case, feature document or diagram names has a file in `Actors/` at the repository root, written with `describe-actor` and linked from whatever names it; delete an actor nothing links to. Update the diagrams and actors in the same commit as the code they describe, and delete a diagram that stops applying. Before finishing, run the validator from the repository root, with the `jsonschema` package installed:

```bash
python3 Meta/Agents/Skills/validate_diagrams.py
```

The skills come from <https://github.com/david-brandt-the-icelander/processes/tree/main/Agents/Skills>. Change them there and copy them here, so there is one version.

## LodeStar

`games/lodestar/` is a clean-room remake made with `create-retro-game`. Implementers read only its `docs/` and the knowledge documents beside its code; only the spec-and-verify role reads the private baseline. Its source is layered as `docs/DESIGN.md` § Project layout describes (use cases → features → capabilities in the `lodestar-core` crate, infrastructure and hosting around them, presentation in Godot), and dependencies point inward only. The sim is deterministic: `f64` with `+ − × ÷` and `sqrt`, plus only the functions `docs/RULES.md` names, and random numbers only from its own seeded generator. Run `cargo test` in `games/lodestar/` before finishing.

LodeStar's feature, use-case and journey documents follow knowledge-driven development: <https://github.com/david-brandt-the-icelander/knowledge-driven-development>, using the `knowledge-driven-development` skill.

- Before changing anything in LodeStar, read the documents beside the code that describe it, and `docs/RULES.md` for exact mechanics. They are your primary guidance, ahead of the prompt, the chat history or any ticket.
- Move the mark in the same commit as the code: what you ship turns its ⚠️ into ✅.
- Write ✅ only after reading the code and seeing its tests pass.
- When a fix has to wait, record the defect as a ❌ in the document that owns the behavior.
- Never write `TODO`, `FIXME`, `HACK` or `XXX`. Write a ⚠️ or ❌ in the owning document instead.

## Sign-in

Every game's Worker checks icelander.net's sign-in (the games are part of the site) with the shared library in `vendor/icelander-auth/`. It is a copy of `packages/icelander-auth/` in the icelander.net repository, and `vendor/icelander-auth/STAMP.json` records each file's hash: change it there and copy it with that repository's `packages/icelander-auth/sync.sh`, never here.
