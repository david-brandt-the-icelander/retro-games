---
name: zx-spectrum-clean-room
description: ZX Spectrum add-on to the clean-room-rebuild skill. Use it when a remake, clone or port of a ZX Spectrum (Sinclair, 16K/48K/128K) game needs to be made safe to publish without infringing the original, or when the user wants to inspect what a Spectrum game's tape contains. It recovers the original's BASIC listing and text from .tap/.tzx/.sna files to use as the comparison reference, finds fan disassemblies for machine-code games, and covers what is risky (UDG graphics, loading screens, the ROM font, BEEP tunes, title and credit screens) and what is free to reuse (the palette, attributes, the 32×24 grid, the beeper) on the Spectrum. Use it whenever the user mentions a Spectrum, Speccy, Sinclair BASIC, a .tap/.tzx file, World of Spectrum or Spectrum Computing together with a remake, even if they don't mention copyright.
---

# Clean-room rebuild: ZX Spectrum

This skill adds Spectrum-specific steps to the general **clean-room-rebuild** workflow. Load that skill too (it sits beside this one at `../clean-room-rebuild/SKILL.md`) and follow its workflow; use this one where it says **[Spectrum]** below. The general skill owns the legal reasoning, the provenance inventory, the clean-room spec, the overlap check (`../clean-room-rebuild/scripts/overlap.py`) and the final report.

The short version of the general rule, so you can work even if only this skill is loaded: keep rules, mechanics and numbers; replace anything copied as written — the original text word for word; graphics, sprites and music; level layouts and maps; a line-by-line translation of the original code (a derivative work); and the original title screen and publisher branding.

## [Spectrum] Step 1 — get the original as a reference

You need the original's text to check the remake against. Keep everything you download in a scratch directory **outside** the user's repo: it is the comparison reference and must never be published.

1. Find the game on Spectrum Computing (`https://spectrumcomputing.co.uk/entry/<id>/`, search by title). Note the publisher, authors, year, re-releases and the "Availability" field. Availability only says whether the site may host the file; it is not permission to remake.
2. Download a tape image (`.tap` preferred, `.tzx` fine) and unzip it:
   ```bash
   curl -sSLO "https://spectrumcomputing.co.uk/pub/sinclair/games/<letter>/<File>.tap.zip"
   unzip -o <File>.tap.zip -d original-tape
   ```
3. Look at what is on the tape:
   ```bash
   python3 -I -B <this-skill>/scripts/zx_basic_list.py original-tape/<FILE>.TAP --blocks > original.bas
   ```
   - **BASIC games** (most strategy, management and adventure games of 1982–84): this prints the whole program — the tape *is* the source. It also handles programs saved as a memory dump (`SAVE "x" CODE 23552,n` or from 22528 with the screen), and `.sna` snapshots.
   - **Machine-code blocks**: a tape often mixes a BASIC program with `CODE` blocks that hold the messages, graphics or the whole game. Always run `--strings` once to see what text is inside them; it finds printable runs, including the common bit‑7‑terminated strings. Save the text as a reference with `--text > original-strings.txt`. For fully machine-code games also look for a fan disassembly (see `references/sources.md`); disassemblies give you every message as `DEFM` lines.
4. Get the manual/inlay text too (Spectrum Computing entry, gamesdatabase.org, archive.org scans) and save it as plain text. Remakes often copy the instructions into a "How to play" screen.
5. Record the copyright line from the program itself (often in a `REM` or `PRINT` near the start, e.g. `REM © …` or `PRINT "Copyright …"`) and from the manual in PROVENANCE.md: it's the best starting point for finding the rights holder.

## [Spectrum] Step 2 — inventory: what's risky and what's free on the Spectrum

Add these to the general skill's inventory.

**Replace (expression):**
- Every `PRINT`, `INPUT` prompt and `DATA` string in the listing, and the manual text.
- **UDGs** (user-defined graphics, `{UDG-A}`…`{UDG-U}` in the listing, usually POKEd from `DATA` or loaded as `CODE` at `USR "a"`) and any sprite data. Redraw from a description.
- The **loading screen** (`SCREEN$` block) and the title/credit screen, including its layout and colour scheme.
- **Tunes**: `BEEP duration,pitch` sequences, `DATA` tables of pitches, and AY music on 128K versions. A melody is protected even when re-rendered with a different sound.
- Map/level `DATA` (room layouts, grids drawn with block graphics `{GFX-n}`).
- The **Sinclair ROM font**: don't ship it or trace it; draw your own 8×8 font.
- Distinctive invented names (countries, factions, characters) and the title, if it's distinctive.

Check graphics and tunes mechanically. Text checks can't see them:

```bash
python3 -I -B <this-skill>/scripts/zx_assets.py original.bas <repo-dir>
```

It reads the UDG bytes from the listing's `DATA` lines and the tune from its `BEEP` statements and `DATA` duration/pitch pairs. It then reports any original 8‑byte graphic in the remake, as numbers, hex or binary, or drawn as `"..XXXX.."` rows, including mirrored or inverted copies. It also reports any run of 6 or more original notes, including runs interleaved with durations or transposed to another key. A tune moved up an octave is still the same tune.

**Its blind spot: tunes in a custom encoding.** Some games keep a tune in strings (for example a letter or a digit per note, decoded by the program at run time) instead of `BEEP` literals or numeric `DATA`. `zx_assets.py` can't see those, and it reports `0 notes` or a suspiciously small count. When it does, read the listing for the routine that plays the tune, decode the notes by hand into `BEEP d,p` lines in a scratch file, and pass that file as an extra reference. Never commit the decoded tune.

Run the scripts with `python3 -I -B` so they leave no `__pycache__` behind in the repository.

Fonts: if the remake has an 8×8 font, find out where it came from. A comment like "dumped from the ROM", the address 15616 (`0x3D00`), or a glyph table that matches an emulator's font means it is the Sinclair ROM font: replace it with your own.

**Keep (hardware facts and functionality):**
- The 15-colour palette, INK/PAPER/BRIGHT/FLASH attributes and attribute clash; the 256×192 display, 32×24 grid of 8×8 cells, the border.
- The beeper as a sound technology (square waves, clicks), keyboard controls, Kempston/Sinclair joystick conventions, the general "stripy border while loading" aesthetic.
- Every rule, formula, probability and numeric threshold in the program — restated in your own spec and code structure.

## [Spectrum] Step 3 — spec from the listing, not code from the listing

Sinclair BASIC ports are especially prone to line-by-line translation: functions named after line numbers, `GO TO`-shaped control flow, single-letter variables (`a$`, `g`, `r`), and identical ordering of unrelated `LET`s. Read the listing to write the behaviour spec (general skill, step 3) — note formulas like `INT (RND*(g/3+.4))` as maths, not code — then implement from the spec in your own structure.

Watch for behaviour that comes from how BASIC works: `INKEY$`/`INPUT` matching only lowercase, any key press counting as a turn, integer truncation from `INT`, the order of `IF` checks, `RND` granularity. These are gameplay, so **keep them as the original has them**. Write them into the spec's quirks section and cover them in the parity check. If one looks like it should change, for example accepting uppercase keys, offer it as an open decision and don't change it yourself.

## [Spectrum] Step 4 — rebuild the presentation

- Recreate the *hardware* look freely (palette, cells, attribute clash, FLASH), but design new screens: new title card, new layout, new colours per screen, new UDG art drawn from written descriptions.
- New tunes and effects: compose new short BEEP-style melodies, or use generic effects (a rising sweep, a click).
- Your own 8×8 font. Matching the *style* (thin strokes, 8×8 cells) is fine; matching glyphs pixel for pixel is not.

## [Spectrum] Step 5 — verify

Run the general skill's overlap check with the extracted listing, the text from code blocks and the manual as references, plus the invented names. Then run the asset check:

```bash
python3 -I -B <clean-room-rebuild>/scripts/overlap.py original.bas original-strings.txt manual.txt <repo-dir> --names <Name1> <Name2>
python3 -I -B <this-skill>/scripts/zx_assets.py original.bas <repo-dir>
```

Both must come back clean, apart from the factual credit line, before you finish.

BASIC listings split messages across several `PRINT` items (`PRINT "You have ";m;" men"`), so short fragments under three words won't be flagged on their own. Skim the listing's `PRINT` lines against the remake's screens as well. Expect the credit line you added on purpose ("Inspired by *Title* by *Author*") to show up as name hits; record it as accepted in PROVENANCE.md.

## [Spectrum] Rights holders

See `references/sources.md` for where to look. Common patterns:
- **Individuals named in the copyright line** (`© K. J. Toms 1982`, `© Richard Shepherd 1982`): often still own it or their estates do. Asking permission is realistic.
- **Publishers that folded** (DK'Tronics dissolved 1993, Richard Shepherd Software ~1985, Imagine 1984): rights went to buyers, back to authors by contract, or to the Crown as *bona vacantia* (UK). Unclear ≠ free.
- **Catalogues still owned and exploited**: Ultimate (Microsoft/Rare), Ocean (Atari), Codemasters, Elite/Frontier games. High risk.
- **Licensed games** (film, TV, comic and book tie-ins) carry a second owner. High risk.

## Bundled files

- `scripts/zx_basic_list.py` — lists BASIC programs in `.tap`, `.tzx` and `.sna` images. `--blocks` shows the tape structure, `--strings` shows the text in non-BASIC blocks with offsets, and `--text` prints just that text, ready to use as an overlap reference.
- `scripts/zx_assets.py` — finds the original's UDG graphics and BEEP tunes in a remake (exact, mirrored, inverted, interleaved or transposed).
- `references/sources.md` — where to find Spectrum originals, manuals and fan disassemblies.
