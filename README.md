# retro-games
Recreations of retro-games that I have made with the help of AI

## Games

| Game | Play | Source |
|---|---|---|
| Rally: table tennis for one or two players, on one device or online, with a high-score table | [icelander.net/games/retro/rally](https://icelander.net/games/retro/rally/) ([high scores](https://icelander.net/games/retro/rally/scores/)) | [games/rally](games/rally) |
| Shatterbelt: an original rock-breaking shooter for 1 to 9 players on one screen or online, co-op or versus, with a high-score table | [icelander.net/games/retro/shatterbelt](https://icelander.net/games/retro/shatterbelt/) ([high scores](https://icelander.net/games/retro/shatterbelt/scores/)) | [games/shatterbelt](games/shatterbelt) |
| Hivestorm: an arcade shooter for one or two players, on one device or online, with a high-score table | [icelander.net/games/retro/hivestorm](https://icelander.net/games/retro/hivestorm/) ([high scores](https://icelander.net/games/retro/hivestorm/scores/)) | [games/hivestorm](games/hivestorm) |
| Samosa: a remake of a 1983 ZX Spectrum strategy game | [icelander.net/games/retro/samosa](https://icelander.net/games/retro/samosa/) ([high scores](https://icelander.net/games/retro/samosa/scores/)) | [games/dictator](games/dictator) |

## Agent skills

`.claude/skills/` holds Claude Code skills for turning a faithful clone into a remake that is safe to publish. Each skill keeps the original's rules and mechanics and replaces anything copied as written:

- **[clean-room-rebuild](.claude/skills/clean-room-rebuild/SKILL.md)** works for any platform. It produces a provenance inventory and a clean-room behaviour spec. It rewrites the text, art, maps and code structure, adds new credits, and checks the remake against the original's text with an automated overlap check (`scripts/overlap.py`).
- **[zx-spectrum-clean-room](.claude/skills/zx-spectrum-clean-room/SKILL.md)** adds ZX Spectrum specifics. It recovers the BASIC listing and text from `.tap`/`.tzx`/`.sna` files (`scripts/zx_basic_list.py`), finds the original's character graphics and BEEP tunes inside a remake, even mirrored or transposed (`scripts/zx_assets.py`), points to fan disassemblies, and says what is risky on the Spectrum (character graphics, loading screens, the ROM font, BEEP tunes) and what is free to reuse (the palette, attributes, the 32×24 grid). It uses the general skill for the rest of the workflow.

- **[create-retro-game](.claude/skills/create-retro-game/SKILL.md)** makes a new remake in `games/<slug>/`, from research to release, with an owner approval gate after each phase. The phases are provenance, behaviour spec, game design document, UI wireframes, art bible, UI design, implementation, testing and publishing. It keeps the original's rules and numbers and designs everything else afresh, using the two skills above for provenance and verification. It includes:
  - templates for each design document
  - a wireframe checker (`scripts/wireframe_check.py`)
  - a TypeScript/Cloudflare starter project with an emulated Spectrum display, its own font, keyboard and touch input, beeper sound, a contact-sheet renderer, and tests

The skills reduce risk, but they are not legal advice. Their test cases (`evals/`) use an invented game, so this repository holds no third-party game text.
