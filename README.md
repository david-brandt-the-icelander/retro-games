# retro-games
Recreations of retro-games that I have made with the help of AI

## Agent skills

`.claude/skills/` holds Claude Code skills for turning a faithful clone into a remake that is safe to publish. Each skill keeps the original's rules and mechanics and replaces anything copied as written:

- **[clean-room-rebuild](.claude/skills/clean-room-rebuild/SKILL.md)** works for any platform. It produces a provenance inventory and a clean-room behaviour spec. It rewrites the text, art, maps and code structure, adds new credits, and checks the remake against the original's text with an automated overlap check (`scripts/overlap.py`).
- **[zx-spectrum-clean-room](.claude/skills/zx-spectrum-clean-room/SKILL.md)** adds ZX Spectrum specifics. It recovers the BASIC listing and text from `.tap`/`.tzx`/`.sna` files (`scripts/zx_basic_list.py`), finds the original's character graphics and BEEP tunes inside a remake, even mirrored or transposed (`scripts/zx_assets.py`), points to fan disassemblies, and says what is risky on the Spectrum (character graphics, loading screens, the ROM font, BEEP tunes) and what is free to reuse (the palette, attributes, the 32×24 grid). It uses the general skill for the rest of the workflow.

The skills reduce risk, but they are not legal advice. Their test cases (`evals/`) use an invented game, so this repository holds no third-party game text.
