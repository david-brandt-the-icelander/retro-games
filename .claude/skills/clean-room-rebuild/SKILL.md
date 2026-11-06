---
name: clean-room-rebuild
description: Rebuild a cloned retro game (on any platform — home computer, console, arcade or PC) so it keeps the original's rules and mechanics but no longer copies its protected expression — original text, graphics, sprites, music, level maps, title screen and branding, or code translated line by line. Produces a provenance inventory, a clean-room behaviour spec, rewritten text and assets, new credits, and an automated text-overlap check against the original. Use this whenever the user wants to publish, open-source, release or "make legal" a remake, clone, port or recreation of an old game, asks whether their clone infringes, mentions copyright or abandonware for a remake, or says things like "clean-room my remake", "make this clone non-infringing" or "get the game ready to publish" — even if they don't say "clean room". For ZX Spectrum games, also use the zx-spectrum-clean-room skill, which adds tape extraction and Spectrum-specific checks.
---

# Clean-room rebuild of a cloned game

The user makes faithful remakes of old games and publishes them open source. A faithful remake usually starts by copying a lot: the original's messages, screens, data tables, sometimes its code structure. This skill turns such a clone into something publishable: it **keeps what copyright does not protect** (rules, mechanics, numbers, feel) and **replaces what it does** (expression).

This is risk reduction, not legal advice. Say so once in the final report, and suggest a lawyer if the user plans to sell the game.

## Why this works (read once, then apply)

- Copyright protects expression, not ideas, rules, game mechanics or what a program does. Leading cases: *Nova Productions v Mazooma* [2007] EWCA Civ 219 (UK); *SAS Institute v World Programming* C‑406/10 (EU, 2012).
- Nothing from the 1980s is out of copyright. UK: author's life + 70 years; US: 95 years from publication for company works. "Abandonware" and "the publisher went bust" are not defences — a dissolved UK company's copyrights usually pass to the Crown (bona vacantia) or to whoever bought them.
- US caution, *Tetris Holding v Xio* (2012): copying the overall look very closely can infringe even when each element was redrawn. Aim for "plays the same", not "indistinguishable screenshot".

More detail and how to find rights holders: `references/legal-basis.md`.

### The risky parts are anything copied as written

* the original text, word for word
* graphics, sprites and music
* level layouts and maps
* a line-by-line translation of the original code, which counts as a derivative work
* the original title screen and publisher branding

Also risky, and easy to miss: manual / instruction text (often pasted into a "How to play" screen); distinctive invented names (characters, countries, factions) and anything that works as a trademark; sound effects; fonts taken from a ROM or the game; box art, cassette inlays, scans and screenshots committed to the repo; code comments, docs and test fixtures that quote the original.

### Safe to keep

Rules, turn structure, win/lose conditions, formulas, probabilities, timings and numeric balance tables (these are functionality — restate them in your own structure and naming rather than copying the original's data layout byte for byte); generic genre vocabulary ("army", "peasants", "fire", "board"); the platform's hardware facts, such as its palette, resolution, character grid, sprite limits and sound-chip character.

## Workflow

Work on a new git branch. Before changing anything, copy the clone as it stands to a scratch directory outside the repo: it is the behaviour baseline for the parity check in step 9. Make progress visible: after each step, write down what you found or changed in `docs/PROVENANCE.md` (template: `assets/PROVENANCE.template.md`).

**Gameplay must stay identical, quirks included.** Input handling (which keys or answers are accepted, case sensitivity, what happens on invalid input), rounding and integer truncation, the order of checks, timing and randomness are all gameplay. Don't drop features or "improve" anything on the way through, however harmless it looks. If the clone already differs from the original, the original wins: restore it and say so. If you think a change would be better, leave the original behaviour in place and offer the change as an open decision.

**Only asked to check, not to change?** Do steps 1, 2 and 11 (inventory and overlap check) and report what is risky, what is fine and what the fix would involve. Don't modify any files.

### 1. Gather inputs

Find or ask for: the clone's path; the original's title, year, platform, publisher and author(s); the reference material that was used or is available (BASIC listing, fan disassembly, manual, screenshots, other ports). `references/finding-originals.md` lists where to look. If a platform add-on skill exists for the original's platform (e.g. **zx-spectrum-clean-room** for the ZX Spectrum), use it now: it knows how to get the original's text out of that platform's files and what is risky or free there. Keep downloaded originals in a scratch directory **outside** the repo — they are the comparison reference, never part of the published game.

### 2. Inventory

Walk the whole clone — source, data files, assets, docs, tests, README, build output that is committed — and fill in the provenance table: one row per item with origin (original / own work / third‑party + licence), category (text, art, audio, level, code, branding, data, docs), verdict (**keep** as functional / **replace** / **decide**) and action. Grep for the original title, author, publisher, "copyright", "©" and a few distinctive original phrases; they reveal copied material quickly.

### 3. Clean-room behaviour spec

If there is no behaviour spec yet, write one (e.g. `docs/RULES.md`) describing *what the game does* in your own words: states, turn order, every rule, every formula and number. It must contain no original text (describe a message's purpose and length budget instead of quoting it) and no original code.

Give quirks their own section in the spec: input handling, invalid-input behaviour, rounding, and check order. They are the details a rewrite loses most easily.

From here on, implement only from the spec. If subagents are available, separate the roles: one agent reads the original and writes or checks the spec; the agent that writes code reads only the spec. This "clean room" separation is what makes the new code demonstrably independent; when working alone, at least close the original before writing each module.

If an existing spec quotes the original, rewrite those passages as descriptions.

### 4. Text

Rewrite every player-facing string from scratch so it does the same job: same meaning, same constraints (e.g. 32 columns, same number of lines, same placeholder values), new wording. Don't paraphrase sentence by sentence — decide what the message must tell the player, then write it as you would have. Keep the tone (satirical, terse, pompous…) if it suits the game; tone is not protected, specific wording is.

Rename distinctive invented proper nouns: places, factions, characters, items. Keep generic words. List **every** rename in the open-decisions list as "old → new", with alternatives when the name is central to the game. The user should never find a renamed place they weren't told about.

### 5. Graphics, fonts and audio

Redraw or recompose from a written description of each element's purpose ("a tank seen from the side, 2×2 cells, facing right"), never by tracing, recolouring or editing the original. Draw your own font (don't ship a ROM font). Procedural generation is fine. Delete committed screenshots, inlays and scans of the original.

### 6. Levels and maps

Design new layouts that exercise the same mechanics and difficulty curve. Don't adapt the original maps or room sequences. Procedurally generated levels with similar parameters are fine.

### 7. Code

Check whether any module was ported from the original line by line or routine by routine — tell-tale signs are original variable names, `GOTO`-shaped control flow, line-number comments, magic memory addresses, and identical ordering of unrelated steps. Restructure those from the spec with your own design, names and control flow, keeping behaviour identical (the tests are your safety net).

### 8. Title, credits and branding

Remove the original's credit screen, copyright line, publisher logo and the original's distinctive title-screen layout. Propose three new titles; keep the original title only if the user confirms it is a generic word and they accept the risk. Add one plain credit line to the README and an in-game About screen:

> Inspired by *Title* (year) by Author, published by Publisher. This is an independent remake, not affiliated with or endorsed by the original rights holders.

Factual attribution like this is fine — it's reproducing their branding that isn't.

### 9. Tests and behaviour parity

Update fixtures and assertions that use original strings or data so they use the new ones. Add a test that fails if any string from the old text table reappears, if that's cheap; store hashes rather than the text so the test file doesn't republish it. All tests must pass before you finish.

Then prove the rebuild plays the same. Write a small parity script in your scratch directory, never in the repo. It drives the baseline copy from the start of the workflow and the new code with the same random numbers and the same inputs, for thousands of games, and compares the full game state after every step. Include invalid and edge-case inputs, such as wrong case, empty or out-of-range answers, and values at each threshold. Every difference is a bug, unless it is a deliberate fix that restores the original's behaviour; explain each of those in the report.

### 10. Licence

The repo's licence can only cover the user's own work. Check that nothing third-party remains; if something does (an MIT-licensed helper, a CC font), list it in a `NOTICE` file with its licence.

### 11. Verify with the overlap check

Run the bundled checker against the original's text:

```bash
python3 -I -B <skill-dir>/scripts/overlap.py <reference> <repo-dir> [--names NAME ...] [--ngram 5]
```

- `<reference>` is the original listing, disassembly or manual text (one or more files). The script pulls quoted strings out of BASIC listings and `DEFM`/`DB` lines out of disassemblies; other files are read as prose.
- `--names` takes distinctive single words (invented names) to look for, since one-word matches are otherwise ignored as too generic.
- It reports every original string and every shared 5-word run still present, with file and line, and exits non-zero while anything remains.

Iterate until it reports nothing except generic phrases you can justify ("press any key to continue"). Record accepted leftovers in PROVENANCE.md with the reason. Also eyeball the result: run or screenshot the game and ask "would someone mistake this for a screenshot of the original?"

### 12. Report

Finish with:
1. What changed, per category (text, art, audio, levels, code, branding, docs, tests, licence).
2. The overlap-check result (paste the summary line) and the parity result (games and steps compared, differences found).
3. **Open decisions** for the user: title, renamed proper nouns, anything marked *decide*, and whether to seek permission from the rights holder (see `references/legal-basis.md`).
4. One line: this reduces risk but is not legal advice.

## Bundled files

- `scripts/overlap.py` — text-overlap checker (step 11). Pure Python 3, no dependencies.
- `references/legal-basis.md` — the legal reasoning in more depth, grey areas, and how to find and approach rights holders.
- `references/finding-originals.md` — where to find an original's listing, disassembly, manual and credits on any platform, and how to turn them into overlap-check references.
- `assets/PROVENANCE.template.md` — the provenance table to copy into the clone.
