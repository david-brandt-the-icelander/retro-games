# retro-games
Recreations of retro-games that I have made with the help of AI

## Games

Each game needs a sign-in with Google or GitHub, icelander.net's one sign-in (the games are part of the site) (icelander.net's login service; the `recreations` repository's `docs/SIGN-IN.md`). Each game's Worker checks it with the shared library in `vendor/icelander-auth/`, which is copied unchanged from the icelander.net repository: don't edit it here. The high-score tables stay public.

| Game | Play | Source |
|---|---|---|
| Rally: table tennis against the computer, or a friend online on their own device, with a high-score table | [icelander.net/games/retro/rally](https://icelander.net/games/retro/rally/) ([high scores](https://icelander.net/games/retro/rally/scores/)) | [games/rally](games/rally) |
| Shatterbelt: an original rock-breaking shooter, alone or online with up to nine pilots each on their own computer, co-op or versus, with a high-score table | [icelander.net/games/retro/shatterbelt](https://icelander.net/games/retro/shatterbelt/) ([high scores](https://icelander.net/games/retro/shatterbelt/scores/)) | [games/shatterbelt](games/shatterbelt) |
| Hivestorm: an arcade shooter for one player, or two online each on their own device, with a high-score table | [icelander.net/games/retro/hivestorm](https://icelander.net/games/retro/hivestorm/) ([high scores](https://icelander.net/games/retro/hivestorm/scores/)) | [games/hivestorm](games/hivestorm) |
| Samosa: a remake of a 1983 ZX Spectrum strategy game | [icelander.net/games/retro/samosa](https://icelander.net/games/retro/samosa/) ([high scores](https://icelander.net/games/retro/samosa/scores/)) | [games/dictator](games/dictator) |
| Gambit: 3D chess made in Godot 4. Invite a friend by email and play with chat and a timed transcript, keep contacts and replay past games, or play Stockfish at eight strengths | [icelander.net/games/retro/chess](https://icelander.net/games/retro/chess/) | [games/chess](games/chess) |

## Deploying

Pushing to `main` deploys each game whose folder changed (`.github/workflows/deploy.yml`): it runs the game's tests, builds it and runs `wrangler deploy`, as the game's own `npm run deploy` does. Gambit also gets Godot 4.7.2 and its web export templates. "Run workflow" on the Deploy workflow in the Actions tab deploys one game, or all of them, by hand. Pull requests test and build the games they change, and check the diagrams, without deploying. The workflows need the repository secret `CLOUDFLARE_API_TOKEN`. Database migrations are applied by hand, and a check holds back any pull request and deploy that changes a database until that is acknowledged: see [docs/database-migrations.md](docs/database-migrations.md).

## Architecture

Each folder with something to say about itself has a `.dev/` directory of JSON: diagrams (component, class, state and deployment) and behavior views drawn from the code, checked by `Meta/Agents/Skills/validate_diagrams.py`, and knowledge files (requirements, decisions, contracts, delivery, runbooks and the like), checked by `Meta/Agents/Knowledge/validate_knowledge.py`. Every game has the full set. They can be browsed at [icelander.net/v1/apps/architecture-browser](https://icelander.net/v1/apps/architecture-browser?url=https://github.com/david-brandt-the-icelander/retro-games). Agents read `AGENTS.md`.

## Agent skills

`.claude/skills/` holds Claude Code skills for turning a faithful clone into a remake that is safe to publish. Each skill keeps the original's rules and mechanics and replaces anything copied as written:

- **[clean-room-rebuild](.claude/skills/clean-room-rebuild/SKILL.md)** works for any platform. It produces a provenance inventory and a clean-room behaviour spec. It rewrites the text, art, maps and code structure, adds new credits, and checks the remake against the original's text with an automated overlap check (`scripts/overlap.py`).
- **[zx-spectrum-clean-room](.claude/skills/zx-spectrum-clean-room/SKILL.md)** adds ZX Spectrum specifics. It recovers the BASIC listing and text from `.tap`/`.tzx`/`.sna` files (`scripts/zx_basic_list.py`), finds the original's character graphics and BEEP tunes inside a remake, even mirrored or transposed (`scripts/zx_assets.py`), points to fan disassemblies, and says what is risky on the Spectrum (character graphics, loading screens, the ROM font, BEEP tunes) and what is free to reuse (the palette, attributes, the 32×24 grid). It uses the general skill for the rest of the workflow.

- **[create-retro-game](.claude/skills/create-retro-game/SKILL.md)** makes a new remake in `games/<slug>/`, from research to release, with an owner approval gate after each phase. The phases are provenance, behaviour spec, game design document, UI wireframes, art bible, UI design, implementation, testing and publishing. It keeps the original's rules and numbers and designs everything else afresh, using the two skills above for provenance and verification. It includes:
  - templates for each design document
  - a wireframe checker (`scripts/wireframe_check.py`)
  - a TypeScript/Cloudflare starter project with an emulated Spectrum display, its own font, keyboard and touch input, beeper sound, a contact-sheet renderer, and tests

The skills reduce risk, but they are not legal advice. Their test cases (`evals/`) use an invented game, so this repository holds no third-party game text.
