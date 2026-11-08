# Agent instructions

Five browser games, each its own npm project under `games/<slug>/` (Samosa lives in `games/dictator/`, Gambit in `games/chess/`). Four have a pure engine in `src/engine/`, a page in `src/main.ts`, a Cloudflare Worker in `worker/` for the replay-checked high-score table, and tests in `test/`; Gambit is a Godot client in `godot/` with its own Worker in `worker/` for sign-in, games and history. Work inside one game's folder: run `npm install` and `npm test` there. Each game's `README.md` says what its files do and how it deploys. Never deploy, or run `wrangler` against the remote databases, unless the owner asks.

The games' engines must stay deterministic: the server replays every submitted game. Use only `+ − × ÷` and `Math.sqrt` in engine code, and draw random numbers only through the engine's own seeded generator.

`.claude/skills/` holds the skills for making clean-room remakes (`create-retro-game`, `clean-room-rebuild`, `zx-spectrum-clean-room`). Use them when making or auditing a game.

## Architecture diagrams

Architecture is documented per folder, as JSON diagrams in `.dev/` directories next to the code, following the skills in `Meta/Agents/Skills/`. Read a folder's diagrams before changing it.

- `describe-component-diagram`: the folder is a cohesive capability, adapter, boundary or subsystem (a game, its `src`, `src/engine`, `src/ui`, `src/zx`, `worker`, or Gambit's `godot`, `godot/scripts`, `godot/chess`, `bridge`, `shared`).
- `describe-class-diagram`: the folder itself declares more than one class.
- `describe-state-diagram`: the folder implements a state machine. One `<Identifier>.state-diagram.json` per machine, named after the class or type it belongs to.
- `describe-deployment-diagram`: the folder holds something independently deployable (each game, with its `wrangler.jsonc`).

Update the diagrams in the same commit as the code they describe, and delete one that stops applying. Before finishing, run the validator from the repository root, with the `jsonschema` package installed:

```bash
python3 Meta/Agents/Skills/validate_diagrams.py
```

The skills come from <https://github.com/david-brandt-the-icelander/processes/tree/main/Agents/Skills>.
