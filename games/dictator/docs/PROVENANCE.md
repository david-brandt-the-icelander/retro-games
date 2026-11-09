# Provenance

Remake of: *Dictator* (1983, ZX Spectrum 48K) by Don Priestley (design and programming), published by DK'Tronics.

**Starting point:** a faithful baseline, the owner's own TypeScript recreation. It lives in the private repository `david-brandt-the-icelander/recreations` (`zxspectrum/dictator`), because it contains the original's text and data. It is read only by the spec/verify role, and none of its files are copied here.

**Reference material** (kept outside this repository, in the private repo's `zxspectrum/dictator/original/`):
- the tape image, from Spectrum Computing (entry 1388, `https://spectrumcomputing.co.uk/pub/sinclair/games/d/Dictator.tap.zip`)
- its BASIC program, decoded with `zx-spectrum-clean-room/scripts/zx_basic_list.py`. The tape holds only BASIC: no machine-code text blocks.
- the instructions as plain text, from gamesdatabase.org

**Rights holders:**
- The program's own credit screen names the author and the publisher, with the year 1983.
- DK'Tronics was dissolved (1993). Its rights may have passed to a buyer, back to the author, or to the Crown as *bona vacantia*.
- Don Priestley died in 2024; rights he held pass to his estate.
- **Asking the estate** for permission to publish a free remake is realistic and worth considering (open decision below).

Verdicts: **keep** (functional, not protected) · **replace** (copied expression) · **decide** (needs the owner).

## Inventory of the baseline

| # | Item | Where in the baseline | Origin | Category | Verdict | Action for the remake |
|---|---|---|---|---|---|---|
| 1 | Rules, turn order, formulas, probabilities, thresholds, quirks | engine | Original behaviour, own code | function | **keep** | Restated in `docs/RULES.md` (phase 1). The new engine is built from it. |
| 2 | Balance numbers for the 24 requests, 19 decisions, 6 news items | data module | Original numbers, stored in the original's own letter encoding and row layout | data | **keep** the numbers, **replace** the layout | Restated as tables in our own layout (RULES §17). The new code uses its own structures. |
| 3 | Request, decision and news texts (49) | data module | Original, verbatim | text | **replace** | New wording written from the topics and the GDD's budgets |
| 4 | All other screen messages (about 50): welcome, reports, bankruptcy, cash notes, loans, war, revolution, escape, rating | screen painters | Original, verbatim or near | text | **replace** | New wording, written to the GDD's budgets (RULES §16 gives the purposes) |
| 5 | How-to-play pages | extras | Paraphrase of the original manual | text | **replace** | Written fresh from RULES |
| 6 | Invented names: the player's country and its adjective, the neighbouring country and its people | everywhere | Original | names | **replace** | New names chosen in the GDD; the mapping is kept in the private repo only |
| 7 | Generic group names (army, peasants, landowners, guerrillas, secret police) and the two real superpowers | everywhere | Generic words and real-world entities | names | **keep** (GDD may restyle) | — |
| 8 | Title *Dictator* | title, page title | Original title; a common word | branding | **replace** | The remake is titled *Samosa* |
| 9 | Intro credit screen imitating the original's (author, publisher lettering, year) | extras | Original branding | branding | **replace** | Removed; an About screen and README carry the factual credit line |
| 10 | Screen layouts and colour schemes copied from the original:<br>• the request screen's row of icons<br>• the intelligence report's columns<br>• the tiled backgrounds<br>• the title wallpaper and flag<br>• the advice prompt column<br>• the alternating footer bar<br>• the flashing elements | screen painters | Original screen designs | art / layout | **replace** | New layouts (wireframes) and look (art bible). The flashing *behaviour* that carries gameplay information (plot markers) is kept as information, not as the same design. |
| 11 | Pixel art: group emblems, police face, dollar band, President portrait, helicopter, mountains, coffin | art module | Own work, drawn for the baseline | art | **replace** (by design choice) | Redrawn per the new art bible, so the remake's look is fully its own; reuse only if the art bible adopts it |
| 12 | Funeral-march tune data, the long low death beep, the revolution alarm pattern, the footer ticks and answer beeps | sound | Original tune data and effect patterns | audio | **replace** | New motifs (art bible). The funeral may use a *new arrangement* of the public-domain theme, or a different motif. |
| 13 | Title anthem and other effects | sound | Own work | audio | **keep or replace** | Art bible decides |
| 14 | 8×8 font | platform layer | Own work, not the ROM font | font | **keep** | Already in the `create-retro-game` web template |
| 15 | Display, input and sound engines | platform layer | Own work | code | **keep** | Already in the web template, cleaned of original material |
| 16 | Engine and flow code | engine | Own code, but its structure follows the original program's order, and its comments cite original line numbers | code | **replace** | New engine by the implementer role from RULES only. Behavioural order is kept; the code is not. |
| 17 | Rules document of the baseline | docs | Quotes original text and line numbers | docs | **replace** | `docs/RULES.md` written clean (no quotes or names); the old one stays private |
| 18 | Tests and fixtures | tests | Assert original strings | tests | **replace** | New tests on new strings; a guard test stores hashes of the original strings and fails if any reappears |

## Overlap check

Run against the original's listing and manual, with its four invented names as `--names`:

```
overlap: 0 original strings, 0 shared 5-word passages, 0 name hits in 0 files (reference: 338 strings, 2109 n-grams)
assets: 0 glyph matches, 0 tune runs, 0 transposed runs (reference: 0 glyphs, 9 notes)
```

Scope: the whole of `games/dictator/` (code, page, tests and docs) at the end of phase 7. Along the way the check caught and the team rewrote: one GDD purpose line, six UI-design phrases, one README sentence and one code comment. A guard test (`test/guard.test.ts`) keeps hashes of the original's strings and fails if any reappears.

Parity with the baseline: 30,000 games, 0 differences (docs/TEST-PLAN.md).

Owner's deliberate choice (2026-11-06): the State Security report shows values as bars, as the original's report did. Only the idea of a bar for a 0–9 value is shared: the colours (cyan and magenta), positions, digits beside the bars, letterhead and the absence of flashing are Samosa's own.

Accepted leftovers: the factual credit line ("Inspired by *Dictator* (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders.") on the About screen and in the README.

## Decisions

- [x] **Title:** *Samosa*.
- [x] **New names:** the player's country is Nicaragua and the neighbour Honduras (real places, replacing the original's invented names), with real organisations and pun-named ruling families (GDD §4).
- [x] **The newsflash money quirk:** switched off.
- [x] **Case of the Y key:** both cases.
- [x] **Permission:** not requested (owner decision); the remake relies on the clean-room work.
- [x] **Public address:** `icelander.net/games/retro/samosa` (first `/retro-games/samosa`, which now redirects).
