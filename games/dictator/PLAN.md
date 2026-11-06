# Dictator remake: plan

A clean-room remake of a 1983 ZX Spectrum strategy game. It plays exactly like the original but shares none of its protected expression: text, names, screen designs, art, tunes or code. It is also the first game made with the **`create-retro-game`** skill (to be added in `.claude/skills/`). Building it will shape the skill.

Status: **M1–M8 done for the game** (M1 still waits for the owner's Access setup). **M9, skill v1, is done**. *Samosa* is published at `icelander.net/games/retro/samosa`, listed on `icelander.net/games`. The owner chose its title, a Nicaragua/Honduras setting with real organisations and pun-named ruling families, and asked for it to be built and published.

This repository is public, so this plan describes the original without quoting it. The original's names and wording appear only in the private faithful copy and its provenance notes.

## 1. Decisions (from the owner)

| # | Decision |
|---|---|
| 1 | The faithful recreation lives in the private repo `david-brandt-the-icelander/recreations`, under `zxspectrum/dictator`. |
| 2 | It is served only to the owner, behind a sign-in (now an emailed link). It was first planned at `icelander.net/retro-games/dictator`; it now lives at `icelander.net/games/recreations/zxspectrum/dictator` (first `/recreations/zxspectrum/dictator`), served by the `recreations` repository's shared Worker. |
| 3 | Its public copies are taken down, and the old repository's history is purged (see §2: to be re-confirmed). |
| 4 | Its working branch moved straight into `recreations`. |
| 5 | The skill is named `create-retro-game`; the remake lives in `games/dictator/` in this repository. |

## 2. Milestone 1: the faithful version, private

| Step | State |
|---|---|
| Source moved, with its 11-commit history, to `recreations/zxspectrum/dictator` | **Done**: draft PR `recreations#1` |
| Served privately | **Superseded.** The per-game Worker is replaced by the shared `recreations` Worker, which checks the Access login itself and serves every game under `icelander.net/recreations/<platform>/<game>`. `recreations#1` is merged with it. |
| Deploy guard: `npm run deploy` refuses unless an anonymous request is redirected to the Cloudflare Access login | **Done**; refuses today, as intended |
| Public deployment on `workers.dev` deleted | **Done**: returns 404 |
| `dictator/` removed from the old repository | **Done as a PR** (`padresmurfa/y#62`), awaiting merge |
| **Cloudflare Access**: enable Zero Trust, add the OAuth login method, create the Access application for the path, allow only the owner | **Owner action.** Access isn't enabled on the account, and the API can't enable it. Steps are in the faithful copy's README. |
| Deploy behind Access | After the step above: `npm run deploy` |
| Purge the old repository's history | **To re-confirm.** That repository turned out to be *private*, not public as first reported, so the faithful version was never publicly visible there. A purge rewrites `main` and every branch and force-pushes them, which is destructive and breaks existing clones. |

## 3. The skill: `create-retro-game`

**Purpose.** It takes a retro game from research to a publishable web remake that **plays the same and looks new**. It runs the design and build phases below, each ending at a gate where the owner approves the artefact. It delegates the legal side to the existing skills:

- **`clean-room-rebuild`:** provenance inventory, clean-room behaviour spec, overlap check, credits.
- **`zx-spectrum-clean-room`:** tape extraction, the UDG and BEEP asset check, Spectrum risk lists.

There are two starting points: from the original (research first), or from an existing faithful clone used as the behaviour baseline, as with Dictator.

### Layout (mirrors the existing skills)
```
.claude/skills/create-retro-game/
  SKILL.md                     workflow, phases, gates, clean-room roles
  references/
    gdd.md                     what a remake's game design document must decide
    wireframes.md              32×24 text-wireframe notation; screen-flow state machine
    art-bible.md               a visual and audio identity within hardware limits, distinct from the original
    ui-design.md               wireframe → cell-exact spec: colours, FLASH states, text budgets, timing,
                               responsive layouts, accessibility
    implementation.md          pure engine + one screen IO interface + platform layer; seeded RNG drawn
                               in spec order, so parity checks are possible
    testing.md                 test pyramid, parity harness, overlap/asset checks, playthroughs, visual review
    platforms/zx-spectrum.md   grid, attributes, FLASH, beeper; points to zx-spectrum-clean-room
  assets/
    GDD.template.md  WIREFRAMES.template.md  ART-BIBLE.template.md
    UI-DESIGN.template.md  TEST-PLAN.template.md
    web-template/              TypeScript + esbuild + Cloudflare static assets starter: emulated Spectrum
                               display, own 8×8 font, keyboard/touch input, BEEP sound, CSP headers,
                               node:test setup
  scripts/
    wireframe_check.py         every wireframe is 32×24, its legend is complete, and every screen is in the flow
    contact_sheet.mjs          renders every screen state headlessly to a PNG sheet for review
  evals/
    design-invented-game/      invented original: the design documents exist, validate, and contain no original text
    build-from-baseline/       small faithful clone: the rebuild passes the parity, overlap and asset checks
```
The evals use an invented game, as the existing skills' evals do, so this repository holds no third-party game text.

### Phases and gates
| # | Phase | Artefact | Gate |
|---|---|---|---|
| 0 | Intake and provenance | `docs/PROVENANCE.md`; references kept outside the repo | Inventory complete (clean-room skills, steps 1–2) |
| 1 | Behaviour spec | `docs/RULES.md`: every rule, number, random draw and quirk, in our own words | Written by a *spec agent*; quotes nothing; owner approves |
| 2 | Game design document | `docs/GDD.md`: pillars, title and setting proposals, renames, screen list, a text budget per message (purpose + length), audio list, platforms, accessibility, scope | Owner chooses the title, setting and names |
| 3 | UI wireframes | `docs/WIREFRAMES.md`: every screen as a 32×24 grid of labelled regions, inputs, timed screens, flow diagram | `wireframe_check.py` passes; owner approves |
| 4 | Art bible | `docs/ART-BIBLE.md`: palette use, per-screen colour families, FLASH/BRIGHT policy, font, a catalogue of icons described in words, title concept, sound palette and motifs, do/don't list | Owner approves |
| 5 | UI design | `docs/UI-DESIGN.md` + contact sheet: cell-exact colours, final text written to budget, states, timings, sounds, desktop/portrait/landscape, keypad, screen-reader text | Owner approves |
| 6 | Implementation | The game | The *implementer agent* reads only phases 1–5, never the original or the faithful copy; all unit tests pass |
| 7 | Testing and verification | Tests, parity report, overlap/asset reports, playthrough evidence | 0 unexplained parity differences; overlap and asset checks clean except accepted entries; browser and visual review pass |
| 8 | Publish | README credit, About screen, licence/NOTICE, deployment | Provenance complete; owner gives the go-ahead |

## 4. Dictator through the skill

**Baseline:** the faithful copy in `recreations`, pinned to a commit. Its engine is driven by the parity harness, which lives in scratch storage and is never committed.

**What gets replaced** (details in the private provenance notes):
- All on-screen text: the 24 requests, 19 decisions, 6 news headlines, roughly 50 other messages, and the how-to-play pages.
- The invented country, people and neighbour names. Generic group words (army, peasants, landowners, guerillas, secret police, the two superpowers) stay.
- The title: owner's choice, between keeping the common word or one of three proposals.
- The original-style credit screen. It is replaced by an About screen and the README line "Inspired by *Dictator* (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders."
- Every screen layout that recreates the original's distinctive designs, including the request screen's icon row, the intelligence report's column layout, the tiled backgrounds, the title wallpaper and the alternating prompt bar. New layouts come from the art bible.
- All tunes and effect patterns that come from the original: new motifs.
- The engine's code and comments that follow the original program's structure: a new engine from the clean spec.
- The data tables, which today mirror the original's encoding: restated in our own structure with the same numbers.
- Tests that assert original strings. A guard test will store *hashes* of the original strings and fail if any reappears.

**What is kept:** every rule, formula, probability and threshold; the order of checks and random draws; the input quirks. The one original quirk (a news event repeating the money of the last-costed item) stays as an open decision.

**Verification:**
- **Parity:** at least 10,000 games per input policy, same seeds and same inputs, full game state compared after every screen. Screen *kinds and order* must match; only wording and look differ.
- **Text and assets:** `clean-room-rebuild/scripts/overlap.py` against the original's listing and manual (with its invented names), and `zx-spectrum-clean-room/scripts/zx_assets.py`, both clean.
- **In the browser:** Playwright playthroughs on desktop, phone portrait and phone landscape.
- **Visual review:** "would anyone mistake this for the original?" must be *no*.
- **Accessibility:** a dedicated pass.

## 5. Milestones (one PR each)

| # | Milestone | Waits for |
|---|---|---|
| M1 | Faithful version private | Owner: Cloudflare Access; re-confirm the purge |
| M2 | `create-retro-game` skill v0: SKILL.md, references, templates, web template | — |
| M3 | Phases 0–1: provenance and behaviour spec | M2 |
| M4 | Phase 2: GDD (title, setting, names chosen) | M3 |
| M5 | Phases 3–4: wireframes and art bible | M4 |
| M6 | Phase 5: UI design and contact sheets | M5 |
| M7 | Phases 6–7: implementation, parity, verification | M6 |
| M8 | Phase 8: publish | M7 |
| M9 | Skill v1: lessons from Dictator; the two evals | M8 |

### What M9 changed in the skill
- **Clean-room hand-offs:** a distinctiveness brief from the verify role to the designer; overlap hits fed back by location, never lists of original text.
- **Gates:** how to run the phases back to back when the owner says "build it"; branch from `main` per milestone and never cherry-pick across branches; playtest changes become logged decisions.
- **RULES:** starting values for every state field, and the before/after timing of state changes around screens with no decision.
- **Real-world settings** (GDD reference): named organisations allowed, real people only under pun names, no jokes about victims, research with sources, map a real group onto an existing faction.
- **Implementation:** the parity hook (`snapshot`, raw keys, every screen through `show`); screens print the state they are shown in.
- **Parity kit** (`assets/parity/`): policies that draw only on decision screens, the comparison with its reordering report, and checks of displayed values.
- **Guard test:** `scripts/make_guard_hashes.py` and the template's `test/guard.test.ts`.
- **Browser and publish:** measuring touch targets (the sound button was 32 px); Cloudflare Web Analytics injection blocked by the CSP.
- **Other fixes:** the zx_assets blind spot for tunes in a custom encoding; scripts run with `python3 -I -B`, and caches are ignored.
- **Evals:** `design-invented-game` and `build-from-baseline`.

This reduces legal risk but is not legal advice. The publisher was dissolved and the author has died; asking his estate for permission is worth considering alongside the clean-room work.
