---
name: create-retro-game
description: Create a publishable web remake of a retro game (ZX Spectrum first; any 8-bit platform) in this repository's games/<slug>/ folder, from research through a game design document, UI wireframes, an art bible, a UI design, implementation and testing, with an owner approval gate after each phase. The remake keeps the original's rules, numbers and feel, and replaces everything copied as written (text, names, screen designs, art, tunes, code structure), using the clean-room-rebuild and zx-spectrum-clean-room skills for provenance and verification. Use it whenever the user wants to make, remake, recreate or redo a retro game for this repo, or asks for a GDD, wireframes, art bible or UI design for one, even if they don't say "skill" or "clean room". Also use it to turn an existing faithful clone into a publishable remake that plays the same.
---

# Create a retro game

The owner makes remakes of 1980s games and publishes them from this repository. Each game lives in `games/<slug>/`, is built as a static web page (TypeScript, Cloudflare), and has to be two things at once:

- **The same game:** identical rules, numbers, turn order, randomness and input quirks. Someone who knew the original should find that every decision plays out the same.
- **A new work:** its own text, names, screen designs, art, sound and code. Nothing that copyright protects in the original is copied (see `../clean-room-rebuild/SKILL.md`, "Why this works").

This skill runs the creative and engineering work in gated phases. The two clean-room skills beside it own the legal side, and this skill calls them at the points shown:

- **`clean-room-rebuild`:** the provenance inventory, the behaviour spec rules, the overlap check and the credits.
- **`zx-spectrum-clean-room`:** for Spectrum originals, tape extraction and the UDG/BEEP asset check.

This reduces legal risk but is not legal advice. Say so once in the final report.

## Starting points

- **From the original:** research it in phase 0, then write the behaviour spec from the reference material.
- **From a faithful baseline:** a faithful clone that already exists (kept in a *private* repo, because it contains the original's text) is the source for the behaviour spec, and later the reference for the parity check. Never copy its files into this repo; it is read only by the spec/verify role.

## Roles: the clean room

Keep two kinds of knowledge apart; this separation is what makes the new work demonstrably independent.

| Role | Reads | Writes |
|---|---|---|
| **Spec and verify** | The original's reference material, the faithful baseline | `docs/RULES.md`; the distinctiveness brief; the parity report; the overlap and asset reports; the guard test's hash list |
| **Designer** | `docs/RULES.md`; the GDD and later design docs; platform hardware facts | GDD, wireframes, art bible, UI design |
| **Implementer** | Only the docs in `docs/` | Code and tests |

When subagents are available, run each role as its own agent and pass only the documents in that table. When working alone, finish and close each role's material before starting the next, and never open the original or the baseline while designing or coding.

Two hand-offs cross the wall, and both carry descriptions, never the original's text:
- **Distinctiveness brief (verify → designer, before phase 3).** A few sentences per recognisable screen of the original, so the designer can design *away* from it: "the report was columns of names with horizontal bar charts; plotters' names flashed". Layouts, motifs and pictures only.
- **Overlap hits (verify → designer, after each design doc).** The file, line and matched phrase for each hit, with the instruction to rewrite the whole message. Never hand over lists of the original's text in advance.

## Layout of a game

```
games/<slug>/
  README.md            how to play, credits line, how to develop and deploy
  docs/
    PROVENANCE.md      clean-room inventory (template: ../clean-room-rebuild/assets/PROVENANCE.template.md)
    RULES.md           behaviour spec (phase 1)
    GDD.md             game design document (phase 2)
    WIREFRAMES.md      screen wireframes and flow (phase 3)
    ART-BIBLE.md       visual and audio identity (phase 4)
    UI-DESIGN.md       cell-exact screen design (phase 5)
    TEST-PLAN.md       what is tested and the results (phase 7)
    contact-sheet.png  every screen state, rendered (phases 5 and 7)
  src/ test/ public/ scripts/  the game, from assets/web-template/
```

Reference material (tapes, listings, manuals, screenshots of the original) is **never** committed. It lives in scratch storage or the private baseline repo.

## Workflow

Work on a branch per phase or milestone, and open one PR per gate. At every gate, stop: show the owner the artefact (with a rendered contact sheet when there is something to see) and wait for approval or changes. Don't run ahead into the next phase on assumptions. Record every owner decision in the GDD's decision log.

- **When the owner says "build it".** If the owner asks for the whole game at once, run the remaining phases back to back, but keep each phase's artefact, checks and commit. Report the gate decisions you made along the way at the end. Public deployment still needs the owner's explicit "publish".
- **Branches.** Start each milestone's branch from `main` after the previous one merged. If you must build on an unmerged branch, branch from it and later *merge* `main` into yours. Never cherry-pick the same commit onto two branches: they conflict at merge time.
- **Playtesting after release.** The owner will play and ask for changes (a darker screen, slower pacing, fewer report offers). Each one is a decision: log it in the GDD, change RULES or UI-DESIGN first, then the code. Add rule changes to RULES' deliberate-differences list, and adapt the parity harness to them rather than dropping parity.

### Phase 0: intake and provenance
1. Identify the original: title, year, platform, publisher, authors, versions. For Spectrum games follow `zx-spectrum-clean-room` step 1 (tape → listing, strings, manual).
2. Start `docs/PROVENANCE.md` from the clean-room template. When rebuilding from a baseline, inventory the baseline (clean-room step 2) so the GDD knows what must change.
3. Note the rights holders (clean-room `references/legal-basis.md`) and whether asking permission is realistic.

**Gate:** the owner sees the inventory, and confirms the slug and the folder.

### Phase 1: behaviour spec (spec role)
Write `docs/RULES.md` as `clean-room-rebuild` step 3 describes:
- every state, rule, formula, probability, threshold and timing, in your own words
- a **quirks** section: input handling (which keys count, case, invalid input), integer truncation, the order of checks, **the order of random draws** (the parity check depends on it), and timed screens
- **message purposes** instead of original text. For each message the original shows: when it appears, what it must tell the player, and its size limits.
- no quotes, no original names, no line numbers, no original data layout
- the **starting value of every state field**, including ones only set later (e.g. a monthly threshold before its first roll)
- for every screen with no decision on it, whether the state changes it reports happen before or after it, where that matters

**Check:** `overlap.py` on `docs/` reports nothing. **Gate:** the owner approves RULES.

### Phase 2: game design document (designer)
Follow `references/gdd.md` and `assets/GDD.template.md`. It decides:
- the identity: three title proposals, a setting, renamed places and factions
- the pillars ("plays the same, looks new" is always one)
- the screen list
- the **text budget** for every message: purpose, maximum columns × lines, tone
- the audio list, platforms and controls, accessibility, scope and non-goals
- risks and a decision log

**Gate:** the owner chooses the title, setting and names. If the owner picks a real setting, follow `references/gdd.md` "Real-world settings".

### Phase 3: UI wireframes (designer)
Follow `references/wireframes.md`. Every screen is drawn as a 32×24 character-cell wireframe (for the Spectrum) with lettered regions and a legend giving each region's purpose and budget, but **no final text**. A flow diagram connects all screens, with inputs and timed transitions. Design new layouts: the art bible's distinctiveness list (phase 4) and the original's screens must not be reproduced.

**Check:** `python3 -I -B scripts/wireframe_check.py docs/WIREFRAMES.md` passes, and every screen in the GDD's list is wireframed. **Gate:** the owner approves.

### Phase 4: art bible (designer)
Follow `references/art-bible.md`:
- the visual identity within the hardware's limits: palette use, colour families per screen group, BRIGHT/FLASH policy, border use
- the font (always our own)
- an icon catalogue, each icon written as a *description* before it is drawn
- the title concept
- the sound palette and motifs (always new melodies)
- a **distinctiveness table** that describes, without reproducing, each recognisable screen of the original and says how ours differs

**Gate:** the owner approves.

### Phase 5: UI design (designer)
Follow `references/ui-design.md` and `assets/UI-DESIGN.template.md`. Turn each wireframe into a cell-exact spec:
- the ink, paper, BRIGHT and FLASH of each region
- the **final text**, written fresh to the budget, never by paraphrasing the original
- states, timings, sounds, keypad offers and screen-reader text
- layouts for desktop, phone portrait and phone landscape

Render a contact sheet: the design prototype or the game itself drawn headlessly (`npm run sheet` in the web template).

**Check:** the designer counts every final text line at its placeholders' worst-case widths (≤ 32 columns, and within its region); the verify role runs `overlap.py` and `zx_assets.py` on `docs/` and feeds hits back. **Gate:** the owner approves the contact sheet.

### Phase 6: implementation (implementer)
Follow `references/implementation.md`. Start from `assets/web-template/`, which provides:
- the emulated display, our own font, keyboard and touch input, beeper-style sound
- headless rendering and CSP headers
- the test set-up

Write:
- a **pure engine** that draws random numbers through one injected RNG, in exactly the order RULES gives
- one **screen interface**, `show(screen) → key`, so the flow runs headless in tests
- screen painters that follow UI-DESIGN

Every rule gets a test as it is written. When there is a baseline, the brief also asks for the parity hook (`snapshot(state)`, raw keys; see `references/implementation.md` and `assets/parity/README.md`).

**Gate:** it builds, the tests pass, and the owner can play it locally or on a preview.

### Phase 7: testing and verification (implementer + verify role)
Follow `references/testing.md` and fill in `assets/TEST-PLAN.template.md`:
1. **Unit and flow tests** for every rule and screen sequence in RULES.
2. **Layout tests:** every screen with worst-case values has no text off the edge, none under the footer and no text/art collisions.
3. **Parity** (verify role, scratch only, with `assets/parity/`), when there is a baseline or a runnable original model:
   - same seeds and inputs for both
   - at least 10,000 games per input policy, including invalid input
   - full state compared after every step
   - every difference is a bug unless RULES documents it as a restored original behaviour or an owner decision
   - what each screen prints (month, money, values) is checked against the state it is shown in
4. **Clean-room checks:** `overlap.py` (with the original's invented names as `--names`) and `zx_assets.py` on the whole game folder must both be clean, apart from accepted entries in PROVENANCE. Generate the guard test's hash list with `scripts/make_guard_hashes.py`, and prove the guard fails on a planted name once.
5. **Browser checks:** Playwright playthroughs on desktop, phone portrait and phone landscape, with no console errors and the CSP checked under `wrangler dev`.
6. **Visual review:** "would anyone mistake this screen for the original's?" must be *no* for every screen on the contact sheet.
7. **Accessibility:** screen-reader text on every screen, keyboard-only play, touch targets of at least 44 px, flashing below 3 Hz.

**Gate:** the owner reviews TEST-PLAN results and the contact sheet.

### Phase 8: publish
- README with how to play and the factual credit line (`clean-room-rebuild` step 8), an About screen with the same line, and the licence/NOTICE check.
- PROVENANCE complete, with the overlap and asset summary lines pasted in.
- Deploy publicly (the template's `wrangler.jsonc`), then check the live page in a browser: the headers, no console errors and the three layouts. If the zone injects Cloudflare Web Analytics, the strict CSP blocks it; report that to the owner rather than loosening the CSP.

**Gate:** the owner gives the go-ahead before anything is deployed publicly.

## Final report (each gate and at the end)
1. What the phase produced, with links, and the contact sheet when there is one.
2. Check results: test counts; overlap and asset summary lines; parity games, steps and differences.
3. **Open decisions** for the owner.
4. At the end: this reduces risk but is not legal advice.

## Bundled files
- `references/gdd.md`, `wireframes.md`, `art-bible.md`, `ui-design.md`, `implementation.md`, `testing.md`: how to do each phase well, with pitfalls.
- `references/platforms/zx-spectrum.md`: Spectrum hardware rules for design (grid, attributes, FLASH, beeper, keyboard).
- `assets/*.template.md`: the documents to copy into `docs/`.
- `assets/web-template/`: the starter project (copy it to `games/<slug>/`).
- `scripts/wireframe_check.py`: validates WIREFRAMES.md (pure Python 3; `--self-test` checks the checker).
- `scripts/make_guard_hashes.py`: writes the guard test's hash list from the reference material (verify role); `assets/web-template/test/guard.test.ts` reads it.
- `assets/parity/`: the parity kit (`parity.ts` and its README): policies that draw only on decision screens, and the comparison with its reordering report.
- `evals/`: `design-invented-game` and `build-from-baseline`, both on invented games.

Run the Python scripts with `python3 -I -B` so they leave no `__pycache__` in the repo.
