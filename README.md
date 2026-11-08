# retro-games
Recreations of retro-games that I have made with the help of AI

## Games

| Game | Play | Source |
|---|---|---|
| Rally: table tennis against the computer, or a friend online on their own device, with a high-score table | [games.icelander.net/retro/rally](https://games.icelander.net/retro/rally/) ([high scores](https://games.icelander.net/retro/rally/scores/)) | [games/rally](games/rally) |
| Shatterbelt: an original rock-breaking shooter, alone or online with up to nine pilots each on their own computer, co-op or versus, with a high-score table | [games.icelander.net/retro/shatterbelt](https://games.icelander.net/retro/shatterbelt/) ([high scores](https://games.icelander.net/retro/shatterbelt/scores/)) | [games/shatterbelt](games/shatterbelt) |
| Hivestorm: an arcade shooter for one player, or two online each on their own device, with a high-score table | [games.icelander.net/retro/hivestorm](https://games.icelander.net/retro/hivestorm/) ([high scores](https://games.icelander.net/retro/hivestorm/scores/)) | [games/hivestorm](games/hivestorm) |
| Samosa: a remake of a 1983 ZX Spectrum strategy game | [games.icelander.net/retro/samosa](https://games.icelander.net/retro/samosa/) ([high scores](https://games.icelander.net/retro/samosa/scores/)) | [games/dictator](games/dictator) |
| Gambit: 3D chess made in Godot 4. Invite a friend by email (Google or GitHub sign-in) and play with chat and a timed transcript, keep contacts and replay past games, or play Stockfish at eight strengths (not yet deployed) | games.icelander.net/retro/chess | [games/chess](games/chess) |

## Architecture

Each folder with something architectural to say has a `.dev/` directory of JSON diagrams (component, class, state and deployment), drawn from the code and checked by `Meta/Agents/Skills/validate_diagrams.py`. They can be browsed at [icelander.net/v1/apps/architecture-browser](https://icelander.net/v1/apps/architecture-browser?url=https://github.com/david-brandt-the-icelander/retro-games). Agents read `AGENTS.md`.

## Agent skills

`.claude/skills/` holds Claude Code skills for turning a faithful clone into a remake that is safe to publish. Each skill keeps the original's rules and mechanics and replaces anything copied as written:

- **[clean-room-rebuild](.claude/skills/clean-room-rebuild/SKILL.md)** works for any platform. It produces a provenance inventory and a clean-room behaviour spec. It rewrites the text, art, maps and code structure, adds new credits, and checks the remake against the original's text with an automated overlap check (`scripts/overlap.py`).
- **[zx-spectrum-clean-room](.claude/skills/zx-spectrum-clean-room/SKILL.md)** adds ZX Spectrum specifics. It recovers the BASIC listing and text from `.tap`/`.tzx`/`.sna` files (`scripts/zx_basic_list.py`), finds the original's character graphics and BEEP tunes inside a remake, even mirrored or transposed (`scripts/zx_assets.py`), points to fan disassemblies, and says what is risky on the Spectrum (character graphics, loading screens, the ROM font, BEEP tunes) and what is free to reuse (the palette, attributes, the 32×24 grid). It uses the general skill for the rest of the workflow.

- **[create-retro-game](.claude/skills/create-retro-game/SKILL.md)** makes a new remake in `games/<slug>/`, from research to release, with an owner approval gate after each phase. The phases are provenance, behaviour spec, game design document, UI wireframes, art bible, UI design, implementation, testing and publishing. It keeps the original's rules and numbers and designs everything else afresh, using the two skills above for provenance and verification. It includes:
  - templates for each design document
  - a wireframe checker (`scripts/wireframe_check.py`)
  - a TypeScript/Cloudflare starter project with an emulated Spectrum display, its own font, keyboard and touch input, beeper sound, a contact-sheet renderer, and tests

The skills reduce risk, but they are not legal advice. Their test cases (`evals/`) use an invented game, so this repository holds no third-party game text.
