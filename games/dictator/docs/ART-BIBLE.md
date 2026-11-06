# Samosa: art bible

Status: draft for owner review · Phase 4 of `create-retro-game` · Owner approval: _pending_

Written by the designer from `RULES.md`, `GDD.md` and the owner's research brief on Nicaraguan history only. No picture, layout, colour scheme, tune or effect here was taken from the original game. §10 lists the original's recognisable screens (from a verbal description supplied for this purpose) and how each of ours differs.

## 1. Identity statement

**The palace runs on paper.** President Ortiga has inherited the palace the Samosa family fled by air, and every ordinary screen of *Samosa* is a document from one of its offices. Each comes with a letterhead and a small seal, and ends in a perforated counterfoil at the foot of the page. The offices' documents:
- a blue-inked ledger with a red margin (the State Treasury)
- a manila State Security file
- a white petition card on a velvet-black wall (the audience hall)
- a cyan agenda (the Directorate)
- a teleprinter tape and a *La Prensa* front page

When things go wrong, the paperwork stops. The screen turns black, a single alarm lamp blinks, and the vanities of every Nicaraguan regime take the stage:
- the medal (a rosette)
- the statue
- the empty balcony with its microphone
- the helicopter kept fuelled on the roof for Miami

**Sound:** a pompous brass-band anthem squeezed through a doorbell, ticking clerks, and a beeper that sulks.

**Influences (none from the original):**
- the history in the research brief: the National Guard's paperwork and rackets, the dynasty's estates and its flight to Miami, the Contra camps across the Honduran mountains, Moscow's crates and Washington's amendments, the canal that was never dug
- government forms and rubber stamps of the 1970s and 1980s
- typed carbon copies, and the tear-off stubs of tickets and receipts
- tabloid front pages and teleprinter tape
- spy-film dossiers
- the flat colours of travel and propaganda posters, kept to the Spectrum's eight

**The visual motif:**
- **Paperwork.** A letterhead band with a seal on row 0, a double rule under it, and the white **counterfoil** footer with a perforated edge and a blinking cursor.
- **Vanity.** Three images recur: the **rosette** medal, the **statue** and the **balcony**. Two more carry the history: the **helicopter** and the northern **ridge** that runs to the Contra camps in Honduras.

**Guard-rails (GDD §4.1).** The satire is aimed at regimes, dynasties, superpowers and their paperwork. It is never aimed at Nicaraguans or Hondurans as peoples, at victims, prisoners or exiles, at the Miskito relocations, or at faith. In the art, that means:
- **No real person drawn:** no likeness of any ruler or family member, and President Ortiga is never shown. No moustache, dark glasses, pink colour scheme or couple portrait that points at a real person.
- **No real flag, coat of arms or party emblem drawn:**
  - no blue–white–blue bands
  - no red-and-black diagonal split
  - no five-volcano triangle
  - no star or hammer-and-sickle
  - real organisations are named only in words
- **No costume, food, dress, accent or landmark** of either country.
- **Everyone stays anonymous:** the statue, the walker and the helicopter's pilot are anonymous silhouettes.

## 2. Hardware frame

These are the template's emulated ZX Spectrum facts (`references/platforms/zx-spectrum.md`, `assets/web-template/src/zx/`). They are free to use and are not the original's expression.
- **Screen:** 256 × 192 pixels = 32 × 24 cells of 8 × 8, inside a border of one colour (a 32-pixel border in the template's canvas). The border is set per screen.
- **Attributes:** one ink and one paper per cell, from the eight colours black, blue, red, magenta, green, cyan, yellow and white. Each cell also has BRIGHT (both ink and paper lighter) and FLASH (ink and paper swap every 320 ms). Every icon below is drawn so that each 8 × 8 cell needs only one ink.
- **Colour levels:** normal 0xD7, BRIGHT 0xFF, black stays black.
- **Font:** the template's own 8 × 8 font (§5).
- **Sound:** one square-wave voice, rests and white-noise bursts, through the template's `Sound.play(notes, volume, stopFirst)` (§9).

## 3. Colour families

Each screen group has one page scheme, one accent and one border. Text pairs are limited to those in §4's contrast table.

| Family | Screens | Paper | Ink | Accent | Border |
|---|---|---|---|---|---|
| **Title** | title | black (night) | white | BRIGHT yellow logo and brass rules; cyan tagline; the balcony's lit doorway in BRIGHT yellow | black |
| **Palace** | howto, about, welcome, rating | blue | white | letterhead band BRIGHT yellow paper / BRIGHT blue ink; yellow for headings and key numbers; cyan for page numbers | blue |
| **Calendar** | month | blue (the wall) | yellow | a white calendar page with a BRIGHT red strip, black ink | blue |
| **Ledger** | treasury, bankrupt, cash-short, swiss, loan-wait, loan-result | white | blue (ink pen) | letterhead band green paper / black ink; a red margin line; red bars and stamp boxes (black on BRIGHT red), green box for good news (black on BRIGHT green) | green (bankrupt: red) |
| **Dossier** | report, report-offer | yellow (manila) | black | letterhead band black paper / yellow ink; red bars for the classified line and the plots | black |
| **Audience** | audience, advice-offer, advice, dialog, must-refuse | black (velvet); dialog is a white sheet with blue ink | white | letterhead band magenta paper / black ink; the petition card white paper / blue ink; the brass door in yellow | magenta |
| **Cabinet** | menu, section, section-used | cyan | black | letterhead band blue paper / white ink; number boxes white on black | blue |
| **Press** | news-alert, news-headline | alert black, headline white | headline black, alert white | the white teleprinter tape; the masthead white on black; the BRIGHT red alarm lamp | white |
| **Alarm** | assassin-attempt, assassin-result, execution, revolt-alarm, escape-ask, help-list, alone, joke, strength, revolt-start, overthrown, crushed | black | white | BRIGHT red for alarm words and the rebels' number; yellow for the door, questions and victory (crushed) | red (crushed: yellow; assassin-result killed and execution: black) |
| **War** | war-threat, invasion, war-result | black | green | BRIGHT green for totals; yellow bugle; BRIGHT red headline on invasion | green (invasion and a lost war: red) |
| **Flight** | heli-escape, heli-fail, mountains, caught, escaped | blue (night sky) | white | black silhouettes (roof, ridge, path); the dawn screen (escaped) turns the sky yellow with black ink | blue (caught: red; escaped: yellow) |
| **Mourning** | funeral | black | white | the green laurel wreath | black |
| **Overlay** | sound | (unchanged) | (unchanged) | BRIGHT white on black, 12 cells of row 0 | (unchanged) |

The counterfoil footer (rows 21–23) is the same on every screen that waits for a key: white paper, black ink.

## 4. BRIGHT and FLASH policy

**BRIGHT is used for:**
- the title logo, the brass rules and the balcony's lit doorway
- the palace letterhead band
- every red or green paper: bars, stamp boxes, result boxes, and the calendar strip. Normal red is too dark behind black text, while BRIGHT red gives 5.3:1.
- red ink, which only ever appears as BRIGHT red on black
- the war totals and the rebels' number
- the rosette, and the crushed statue

Nothing else is BRIGHT. BRIGHT never marks decoration alone.

**FLASH is used for (always the template's 320 ms swap, about 1.6 cycles a second, under 3 Hz):**
- the **footer cursor**: one cell, on every screen that waits for a key, and the only flash on those screens
- the **alarm lamp** (2 × 2 cells) on `news-alert` and `revolt-alarm`
- the **rifle sight** (3 × 3 cells) on `assassin-attempt`

These are the only flashing elements in the game. No heading, word, name, number or background ever flashes. No screen flashes more than 9 cells, and no large red area flashes.

**Text contrast pairs** (WCAG ratio with the template's levels; only these are used for text):

| Pair (ink on paper) | Normal | BRIGHT |
|---|---|---|
| white on black | 14.6 | 21.0 |
| yellow on black | 13.6 | 19.6 |
| cyan on black | 11.7 | 16.7 |
| green on black | 10.7 | 15.3 |
| magenta on black | 4.9 | 6.7 |
| red on black | — (3.9, never used) | 5.3 |
| black on white / yellow / cyan / green | 14.6 / 13.6 / 11.7 / 10.7 | 21.0 / 19.6 / 16.7 / 15.3 |
| black on magenta | 4.9 | 6.7 |
| black on red | — (3.9, never used) | 5.3 |
| blue on white / yellow / cyan | 7.4 / 6.9 / 5.9 | 8.6 / 8.0 / 6.9 |
| white / yellow / cyan on blue | 7.4 / 6.9 / 5.9 | 8.6 / 8.0 / 6.9 |

Never for text: anything on red or magenta except black, normal red ink, magenta or red on white, white on green.

**The border** never flashes and never changes while a screen is up.

## 5. Typography

**The font is the web template's own 8 × 8 character set** (`assets/web-template/src/zx/font.ts`). It was drawn for this project and is not the Sinclair ROM font or the original game's font. Its traits:
- **Strokes:** one pixel wide.
- **Capitals and digits:** sit in pixel rows 1–6 and columns 1–6, except T and Y, which reach column 0.
- **Lower case:** a 5-row x-height, with descenders in row 7.
- **Characters:** ASCII 32–126 plus `£`, `©` and the full block `█`. Every line of final text in `UI-DESIGN.md` was checked against this set.

**Three styles, all from the same glyphs:**
1. **Normal:** one glyph per cell. Sentence case for messages; capitals for letterheads, labels, tables, prompts, headlines and the dossier.
2. **Double size:** each glyph pixel drawn as a 2 × 2 block, so one character fills 2 × 2 cells. Used for big numbers and one-word verdicts: the month, `BANKRUPT`, `REVOLUTION!`, the masthead, the invasion totals and the rating total.
3. **Logo:** the four large letters of §6 (logo-S, -A, -M, -O). They are not a font, and are used only on the title.

There are no inverse-video headings and no underlined text. Emphasis comes from the letterhead band, red bars, boxes and colour (always with words).

## 6. Icon catalogue

Every picture in the game is listed here. Each was **described in words first** (the Description column, written before drawing) and then drawn from that description alone, never from the original's graphics. The grids below are exact:
- `#` is an ink pixel, `.` a paper pixel.
- Each grid is a whole number of 8 × 8 cells, so the implementer can paste it straight into the template's `Painter.icon(col, row, picture, attr)`.
- The picture's top-left pixel goes at the top-left of the region named in `UI-DESIGN.md`.

| id | Description (written first) | Size (cells, w×h) | Ink / paper | Used on |
|---|---|---|---|---|
| `seal` | A round wax seal seen from above: a notched rim, a ring inside it, and a small square boss in the middle. | 1×1 | the letterhead band's ink on its paper | every letterhead (col 1, row 0) |
| `rosette` | A round medal hanging from two ribbon tails: a toothed outer rim, an inner ring, a solid centre boss; the tails hang down and end in a notch. | 2×3 | yellow on blue (welcome); BRIGHT yellow on black (assassin-result, survived); BRIGHT yellow on blue (rating, new best) | welcome, assassin-result, rating |
| `quill` | A feather quill pen lying on a diagonal, the nib at the bottom left, the vanes opening towards the top right. | 2×2 | white on black (advice-offer); blue on white (dialog) | advice-offer, dialog |
| `briefcase` | A banker's briefcase from the front: a handle on top, a flap seam across the middle and a clasp at its centre. | 2×2 | blue on white | swiss |
| `lamp` | A round alarm beacon on a stepped base, with three short rays above it and one to each side. | 2×2 | BRIGHT red on black, FLASH | news-alert, revolt-alarm |
| `smoke` | A small, irregular puff of smoke. | 1×1 | white on blue | heli-fail |
| `walker` | A small figure walking to the right, a suitcase in the trailing hand. | 1×2 | white on black (mountains); black on yellow (escaped) | mountains, escaped |
| `reticle` | A rifle sight: an outer circle, an inner circle and cross-hairs that stop short of the centre. | 3×3 | BRIGHT red on black, FLASH | assassin-attempt |
| `door-ajar` | A tall arched palace double door in a heavy frame on a threshold. The left leaf is shut, with two panels and a handle; the right leaf has swung inwards, leaving a dark gap, and is seen edge-on by the jamb. | 6×6 | yellow on black | audience, escape-ask |
| `door-shut` | The same door with both leaves shut and a heavy bar bolted across them. | 6×6 | yellow on black | must-refuse |
| `coffer` | An iron-strapped strongbox with its lid thrown back: the inside is dark and empty, a lock plate sits on the front, two small feet below. | 4×3 | blue on white | bankrupt, cash-short |
| `folder` | A dossier folder lying flat: a tab at the top left, a flap line across, and a string looped round a button. | 4×3 | black on yellow | report-offer |
| `envelope` | An envelope seen from the back, its pointed flap closed with a round wax seal. | 4×3 | blue on white | loan-wait, loan-result |
| `bugle` | A plain military bugle, mouthpiece on the left and bell on the right, with a tasselled cord hanging below. | 4×2 | yellow on black | war-threat, war-result (won) |
| `fieldgun` | A field gun in side view: a long barrel raised to the upper right, a spoked wheel, the trail resting on the ground to the left. | 4×2 | green on black | invasion |
| `helicopter` | A small helicopter in side view, nose to the right: a rotor blade on a mast, a rounded cabin with a window, a thin tail boom to the left, a skid below. | 4×2 | white on blue | heli-escape, heli-fail |
| `statue` | A generic standing figure in a long coat on a tall plinth, the right arm raised high and forward, the left hanging. The plinth has a blank panel. No face, uniform, cap or insignia: a silhouette of vanity, not of anyone. | 3×5 | white on black (revolt-alarm, revolt-start); BRIGHT yellow on black (crushed) | revolt-alarm, revolt-start, crushed |
| `statue-fallen` | The statue toppled: the same picture turned 90° clockwise, plinth and all. | 5×3 | white on black | overthrown |
| `wreath` | A laurel wreath, open at the top: two branches of paired leaves curving up from a ribbon bow at the bottom. | 4×4 | green on black | funeral |
| `moon` | A crescent moon opening to the right. | 2×2 | white on blue | mountains, caught |
| `ring` | A calendar binding ring: an oval loop with a short stem running down into the page. | 1×1 | white on blue | month |
| `balcony` | The President's empty balcony at night, seen from the front. An elliptical arch over two pilasters frames a lit doorway with drawn-back curtains and a pelmet. In the middle stands an old box microphone on a stand, waiting. Below runs a balustrade of eight vase-shaped balusters between two rails. Nobody is there. | 8×6 | per cell: see the attribute map | title |
| `logo-S`, `logo-A`, `logo-M`, `logo-O` | Heavy block capitals with 3-pixel strokes: S and O rounded at the corners, M and A sharp. Each is drawn on a 12 × 12 grid and shown at **double size** (each `#` a 2 × 2 block), so a letter fills 3 × 3 cells. | 3×3 each | BRIGHT yellow on black | title |

### `seal` (1×1 cells, 8×8 pixels)

```
..####..
.#.##.#.
#.#..#.#
##.##.##
##.##.##
#.#..#.#
.#.##.#.
..####..
```

### `rosette` (2×3 cells, 16×24 pixels)

```
.....#.##.#.....
...##########...
..############..
.###..####..###.
.##.##....##.##.
###.#......#.###
.##.#..##..#.##.
###.#.####.#.###
###.#.####.#.###
.##.#..##..#.##.
###.#......#.###
.##.##....##.##.
.###..####..###.
..############..
...##########...
.....#.##.#.....
....###..###....
....###..###....
...###....###...
...###....###...
...###....###...
..###......###..
..##.#....#.##..
..#...#..#...#..
```

### `quill` (2×2 cells, 16×16 pixels)

```
...........#####
.........##....#
........#.....##
.......#....##.#
......#...##..#.
.....#..##...#..
....#.##....#...
....##.....#....
...#.#...##.....
...#..###.......
..#.##..........
..##............
.##.............
.#..............
#...............
................
```

### `briefcase` (2×2 cells, 16×16 pixels)

```
................
................
......####......
.....#....#.....
.....#....#.....
################
#..............#
#..............#
#......##......#
########..######
#......##......#
#..............#
#..............#
#..............#
################
................
```

### `lamp` (2×2 cells, 16×16 pixels)

```
.#.....#.....#..
..#....#....#...
...#.......#....
................
#.....####.....#
.##..#....#..##.
....#.##...#....
....#.##...#....
....#......#....
....#......#....
...##########...
...#........#...
..############..
..############..
................
................
```

### `smoke` (1×1 cells, 8×8 pixels)

```
...##...
..#..##.
.#.....#
#..#...#
#......#
.#..#.#.
..##.#..
........
```

### `walker` (1×2 cells, 8×16 pixels)

```
....##..
....##..
........
...###..
..#.##..
.#..###.
.#..##.#
.#..##..
###.##..
###.#.#.
###.#.#.
...#...#
...#...#
..#....#
..#.....
........
```

### `reticle` (3×3 cells, 24×24 pixels)

```
...........##...........
........########........
......###..##..###......
.....##....##....##.....
....#......##......#....
...#.......##.......#...
..##.....######.....##..
..#.....##.##.##.....#..
.##....#...##...#....##.
.#....##........##....#.
.#....#..........#....#.
#########..##..#########
#########..##..#########
.#....#..........#....#.
.#....##........##....#.
.##....#...##...#....##.
..#.....##.##.##.....#..
..##.....######.....##..
...#.......##.......#...
....#......##......#....
.....##....##....##.....
......###..##..###......
........########........
...........##...........
```

### `door-ajar` (6×6 cells, 48×48 pixels)

```
.......###............................###.......
......###..............................###......
.....###................................###.....
....###..................................###....
....##...#.............#.############.....##....
...###..#..............#.############.....###...
...##..#...............#.############......##...
..##...#...............#.############.......##..
..##..#................#.############.########..
..##..#................#.############.#....###..
.##..#.................#.############.#....#.##.
.##..#.................#.############.#....#.##.
.##..#.................#.############.#....#.##.
.##..#.................#.############.#....#.##.
.##..#.................#.############.#....#.##.
.##..#.................#.############.#....#.##.
##..#..................#.############.#....#..##
##..#..................#.############.#....#..##
##..#..................#.############.#....#..##
##..#..................#.############.#....#..##
##..#...############...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#.##.#..##
##..#...#..........#...#.############.#.##.#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...############...#.############.#....#..##
##..#...............##.#.############.#....#..##
##..#...............##.#.############.#....#..##
##..#...............##.#.############.#....#..##
##..#...############...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...#..........#...#.############.#....#..##
##..#...############...#.############.#....#..##
##..#..................#.############.#....#..##
##..#..................#.############.#....#..##
##..####################.############.######..##
################################################
################################################
```

### `door-shut` (6×6 cells, 48×48 pixels)

```
.......###............................###.......
......###..............................###......
.....###................................###.....
....###..................................###....
....##...#.............##.............#...##....
...###..#..............##..............#..###...
...##..#...............##...............#..##...
..##...#...............##...............#...##..
..##..#................##................#..##..
..##..#................##................#..##..
.##..#.................##.................#..##.
.##..#.................##.................#..##.
.##..#.................##.................#..##.
.##..#.................##.................#..##.
.##..#.................##.................#..##.
.##..#.................##.................#..##.
##..#..................##..................#..##
##..#..................##..................#..##
##..#..................##..................#..##
##..#..................##..................#..##
##..#...############...##...############...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#####..........#...##...#..........#####..##
##..########################################..##
##..########################################..##
##..########################################..##
##..#####..........#...##...#..........#####..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...############...##...############...#..##
##..#...............##.##.##...............#..##
##..#...............##.##.##...............#..##
##..#...............##.##.##...............#..##
##..#...############...##...############...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...#..........#...##...#..........#...#..##
##..#...############...##...############...#..##
##..#..................##..................#..##
##..#..................##..................#..##
##..########################################..##
################################################
################################################
```

### `coffer` (4×3 cells, 32×24 pixels)

```
................................
.....######################.....
....#......................#....
...#........................#...
..#..........................#..
.#............................#.
.##############################.
.##############################.
.##############################.
.##############################.
.##############################.
.#......#..............#......#.
.#......#..............#......#.
.#......#.....####.....#......#.
.#......#.....####.....#......#.
.#......#.....####.....#......#.
.#......#.....####.....#......#.
.#......#..............#......#.
.#......#..............#......#.
.#......#..............#......#.
.#......#..............#......#.
.##############################.
..###......................###..
................................
```

### `folder` (4×3 cells, 32×24 pixels)

```
................................
..##########....................
.#..........#...................
.#...........################...
.#..........................#...
.##############################.
.#............................#.
.#............................#.
.#.....######......######.....#.
.#....................#.......#.
.#.....................#......#.
.###############################
.#..............##............#.
.#.............#..#...........#.
.#..............##............#.
.#...............#............#.
.#................#...........#.
.#.................#..........#.
.#............................#.
.#............................#.
.#............................#.
.#............................#.
.##############################.
................................
```

### `envelope` (4×3 cells, 32×24 pixels)

```
................................
................................
################################
##............................##
#.#..........................#.#
#..#........................#..#
#...#......................#...#
#....#....................#....#
#.....#..................#.....#
#......#................#......#
#.......#.....####.....#.......#
#........#...######...#........#
#.........#.##.##.##.#.........#
#..........##########..........#
#...........###..###...........#
#............######............#
#....#........####........#....#
#...#......................#...#
#..#........................#..#
#.#..........................#.#
##............................##
################################
................................
................................
```

### `bugle` (4×2 cells, 32×16 pixels)

```
................................
..........................####..
.........................#....#.
##.....................##.....#.
#.#######################.....#.
##.....................##.....#.
.......##############....#....#.
......#..............#....####..
......#..............#..........
.......##############...........
..........#.......#.............
...........#.....#..............
............#...#...............
.............###................
..............#.................
.............###................
```

### `fieldgun` (4×2 cells, 32×16 pixels)

```
................................
...........................####.
........................#####...
.....................#####......
..................#####.........
...............######...........
.............#######............
...........########.............
....#############...............
..###############...............
.##.....######..................
##.....#.####.#.................
#.....#.#....#.#................
......#.#.##.#.#................
.......#.####.#.................
........######..................
```

### `helicopter` (4×2 cells, 32×16 pixels)

```
................................
..######################........
...............##...............
..............####..............
#...........#######.............
##.........#########.##.........
.############.....###..#........
..#.........#.....####.#........
..........###.....#####.........
...........############.........
............##########..........
..............#....#............
..........##############........
................................
................................
................................
```

### `statue` (3×5 cells, 24×40 pixels)

```
....................##..
...................####.
..................###...
.........###.....###....
........#####...###.....
........#####..###......
.........###..###.......
..........#..###........
........#######.........
.......#######..........
......###.###...........
......###.###...........
......##..###...........
......##..###...........
......##.#####..........
.......#.#####..........
.........#####..........
........#######.........
........#######.........
.......#########........
........###.###.........
........###.###.........
........###.###.........
........###.###.........
.......####.####........
.......####.####........
....################....
....################....
.....#............#.....
.....#............#.....
.....#.##########.#.....
.....#.#........#.#.....
.....#.#........#.#.....
.....#.##########.#.....
.....#............#.....
.....#............#.....
...####################.
...####################.
..######################
........................
```

### `statue-fallen` (5×3 cells, 40×24 pixels)

```
........................................
........................................
.#......................................
.###....................................
.###........##..........................
.#############..........................
.###........##...........#####..........
.###..####..####....#...#######.........
.###..#..#..###########.....####..##....
.###..#..#..##############....##.####...
.###..#..#..#########################...
.###..#..#..##......############.####...
.###..#..#..####################..##....
.###..#..#..##############....###.......
.###..#..#..###########........###......
.###..#..#..####....#...........###.....
.###..####..##...................###....
.###........##....................###...
.#############.....................###..
.###........##......................###.
.###.................................###
.###..................................##
.###..................................#.
.#......................................
```

### `wreath` (4×4 cells, 32×32 pixels)

```
................................
................................
................................
......#..................#......
.....###................###.....
.....##..................##.....
...#.####..............####.#...
...#####.###........###.#####...
...##.######........######.##...
...#######............#######...
...###.###............###.###...
.##.#####..............#####.##.
.###.####..............####.###.
..##.####..............####.##..
..##.####..............####.##..
...#.####..............####.#...
.###.####..............####.###.
.#########............#########.
..########............########..
....#.#.###..........###.#.#....
..###.#.###..........###.#.###..
...###########....###########...
....##########....##########....
.........######..######.........
.....######################.....
......#####.########.#####......
.........##############.........
.........#####.##.#####.........
..............#..#..............
.............#....#.............
.............#....#.............
............#......#............
```

### `moon` (2×2 cells, 16×16 pixels)

```
................
.....##.........
...###..........
..####..........
..###...........
.####...........
.####...........
.####...........
.####...........
.#####..........
.#####..........
..#####.........
..#######.......
...##########...
.....######.....
................
```

### `ring` (1×1 cells, 8×8 pixels)

```
..####..
.#....#.
.#....#.
.#....#.
.#....#.
..####..
...##...
...##...
```

### `balcony` (8×6 cells, 64×48 pixels)

```
................................................................
......................####################......................
...............######......................######...............
...........#####................................#####...........
........####........................................####........
......####............................................####......
.....###................................................###.....
....###..................................................###....
..#####.################################################.#####..
..####..################################################..####..
..####..###..........................................###..####..
..####..###..........................................###..####..
..####..###..................######..................###..####..
..####..####.................#....#.................####..####..
..####..####.................######.................####..####..
..####..####.................#....#.................####..####..
..####..####.................######.................####..####..
..####..####.................#....#.................####..####..
..####..#####................######................#####..####..
..####..#####..................##..................#####..####..
..####..##.....................##.....................##..####..
..####..##.....................##.....................##..####..
..####..##.....................##.....................##..####..
..####..######.................##.................######..####..
..####..######.................##.................######..####..
..####..######.................##.................######..####..
..####..######.................##.................######..####..
..####..######.................##.................######..####..
..####..#######................##................#######..####..
..####..#######................##................#######..####..
..####..#######................##................#######..####..
..####..#######................##................#######..####..
################################################################
################################################################
################################################################
..####....####....####....####....####....####....####....####..
..####....####....####....####....####....####....####....####..
...##......##......##......##......##......##......##......##...
...##......##......##......##......##......##......##......##...
...##......##......##......##......##......##......##......##...
..####....####....####....####....####....####....####....####..
..####....####....####....####....####....####....####....####..
..####....####....####....####....####....####....####....####..
...##......##......##......##......##......##......##......##...
...##......##......##......##......##......##......##......##...
################################################################
################################################################
################################################################
```

Attribute map, one letter per cell (columns left to right, rows top to bottom):
- `W` is white ink on black paper, BRIGHT off.
- `Y` is black ink on BRIGHT yellow paper: the lit doorway, where the curtains, pelmet and microphone show as black.

```
WWWWWWWW
WYYYYYYW
WYYYYYYW
WYYYYYYW
WWWWWWWW
WWWWWWWW
```

### The logo letters (12 × 12 each, drawn at double size)

The title spells S A M O S A, with `logo-S` and `logo-A` each used twice. The letters' top-left cells are at row 3 and cols 4, 8, 12, 16, 20, 24, with one empty cell between letters.

`logo-S`

```
..########..
.##########.
###......###
###.........
####........
.#########..
..#########.
........####
.........###
###......###
.##########.
..########..
```

`logo-A`

```
....####....
...######...
..###..###..
.###....###.
###......###
###......###
############
############
###......###
###......###
###......###
###......###
```

`logo-M`

```
###......###
####....####
#####..#####
###.####.###
###..##..###
###......###
###......###
###......###
###......###
###......###
###......###
###......###
```

`logo-O`

```
..########..
.##########.
###......###
###......###
###......###
###......###
###......###
###......###
###......###
###......###
.##########.
..########..
```

### Drawn decorations (not icons)

These are lines and outlines drawn with the template's `plot` in the cell's ink. Pixel coordinates are screen pixels: x from 0 at the left, y from 0 at the top. None is a repeating background; each is a single line, outline or silhouette.

| id | Where | Exact drawing |
|---|---|---|
| double rule | row 1, every letterhead screen | Full-width lines on y = 10 and y = 13 (pixel rows 2 and 5 of row 1). |
| perforation | row 21, every footer | Pixels at y = 171, x = 0, 2, 4 … 254. |
| cursor | footer, row 22 | The font's `█` glyph in one cell, FLASH on. |
| dotted ledger rule | treasury rows 6, 8 | Pixel row 3 of the row, every other pixel, over cols 4–30. |
| sum rule | treasury row 10, swiss row 10, rating row 8 | Pixel rows 2 and 4 of the row, solid, over the region's columns. |
| red margin | ledger screens, rows 2–20 | A vertical line at x = 20, y = 16 … 167, in red ink (those cells are red ink on white paper and hold no text). |
| stamp frame | stamp boxes | A 1-pixel rectangle on the box's outermost pixel ring. |
| coupon outline | welcome V, rows 12–15 × cols 0–31 | The region's outermost pixel ring as a dashed line: 4 pixels on, 4 off, starting at each corner. |
| brass rules | title rows 2 and 6, cols 4–26 | Row 2: y = 22–23; row 6: y = 48–49; x = 32 … 215. |
| facade ledge | title row 16, cols 2–29 | y = 128, x = 16 … 239. |
| underline | cabinet screens, row 4, cols 4–27 | y = 33, x = 32 … 223. |
| calendar page | month, rows 6–15 × cols 8–23 | White paper cells, black ink; a tear line on y = 127, every other pixel, x = 64 … 191. |
| landing pads | heli-escape / heli-fail roof | 1-pixel rectangles (136, 90)–(183, 93) and (104, 90)–(151, 93). |
| invasion divider | invasion rows 8–11 | Two vertical lines, x = 127 and x = 128, y = 64 … 95. |
| sprocket holes | news-alert, rows 9 and 12 (the tape's edges) | 2 × 2-pixel dots at y = 75–76 and y = 99–100, x = 4, 12, 20 … 252. |
| signature line | dialog row 15, cols 6–25 | A 5 × 5 x from (48, 120) to (52, 124) (both diagonals), then a dotted line on y = 126, every other pixel, x = 56 … 207. |
| thin rules | execution row 6, strength row 9, about row 9 | One line on pixel row 4 of the row, over the columns given in `UI-DESIGN.md`. |
| newsprint | news-headline rows 9–19 | One solid line on pixel row 3 of each row (y = 75, 83, … 155). Left column starts at x = 8, with lengths in pixels, top to bottom: 112, 112, 104, 112, 96, 112, 112, 80, 112, 108, 64. Right column starts at x = 136: 112, 100, 112, 112, 112, 88, 112, 112, 104, 112, 72. |
| ridge | mountains, caught, escaped, rows 6–12 | A polyline through (0, 92), (18, 78), (34, 86), (56, 62), (70, 72), (92, 54), (110, 68), (128, 58), (150, 76), (168, 56), (186, 66), (204, 50), (224, 70), (240, 62), (255, 84). For each x, y(x) is the linear interpolation between the two points around it, rounded. Every pixel from y(x) down to y = 103 is ink. Those cells are black ink on the sky's paper (blue, or yellow at dawn). |

## 7. Title concept

**"The balcony is ready."** It is night at the palace the Samosas left in a hurry. The name **SAMOSA** stands once across the top in heavy brass block letters, between two thin brass rules, as if cast on the palace frieze. Below it, a single wry line in cyan, then the picture: the President's **empty balcony**. The doorway is lit and the curtains are drawn back. An old box microphone waits on its stand, and the balustrade runs below. Nobody steps out: the player is the one about to take that place.

- **Layout** (`UI-DESIGN.md` § title):
  - logo on rows 3–5, cols 4–26, between brass rules on rows 2 and 6
  - tagline on row 8
  - balcony on rows 10–15, cols 12–19, with a ledge line on row 16
  - the white counterfoil on rows 21–23 with the keys
- **Colour:** black night, BRIGHT yellow brass, a BRIGHT yellow lit doorway, white stonework, cyan tagline. Border black.
- **Motion:** none. Nothing on the title flashes except the counterfoil's one-cell cursor. The anthem plays once.
- **How it differs from the original's title** (a flashing wallpaper of the title word, with a national flag):
  - the name appears **once**
  - the paper is plain black, not patterned
  - nothing but the cursor flashes
  - there is **no flag**, real or invented, anywhere in the game
- **No loading or publisher screen** imitates the original: the page opens on this title.

## 8. Motion and timing

| Element | Behaviour | Timing | Gameplay (from RULES) or decorative |
|---|---|---|---|
| Timed screens | Move on by themselves; keys are not read | month 1 s, bankrupt 5 s, unaffordable dialog 5 s, cash-short 7 s, must-refuse 5 s, section-used 3 s, loan-wait 1 s, news-alert 6 s, news-headline 2 s, revolt-alarm 5 s, heli-fail 3 s, mountains 4 s, joke 3 s, strength 5 s | Gameplay (RULES §15.5); none shortened |
| Screens timed by their sound | Last exactly as long as their motif (§9), sound on or off | report-offer (unavailable) 2.5 s, assassin-attempt 1.6 s, assassin-result 2.5 / 2 s, war-threat 3.5 s, invasion 4 s, war-result 2.5 s, heli-escape 3 s, execution 3 or 4.5 s, revolt-start 2.5 s, overthrown 2.5 s, caught 3 s, escaped 2.5 s | Gameplay ("its sound", RULES §15.5); the lengths are set here |
| `swiss` | The moved/nothing lines alone, then the treasury lines and footer appear | 2 s, then waits for a key | Gameplay (RULES §15.5) |
| Footer cursor | One cell, FLASH | Template rate, 320 ms per phase | Decorative |
| Alarm lamp, rifle sight | FLASH | 320 ms per phase | Decorative |
| Teleprinter text (news-alert) | Types one character at a time | 60 ms per character | Decorative |
| Helicopter (heli-escape) | Rises one cell row at a time from rows 9–10 to rows 4–5 | Every 0.5 s (6 positions) | Decorative |
| Walker (mountains) | Steps one column right at a time from col 1 to col 29 | Every 140 ms (28 steps) | Decorative |
| Rating lines | Appear one at a time with a tally blip; the footer appears with the last | Every 300 ms | Decorative |
| Sound overlay | Appears on M, then restores the cells | 1.5 s | Decorative (GDD §7) |
| Everything else | Static | — | — |

## 9. Sound palette

**The beeper character.** One square-wave voice, as on the real machine. There is no harmony and no envelope beyond the template's 10 ms release at the end of each note. The sounds are built from three things: pitched notes, 4 ms ticks (clicks), and bursts of white noise. Low pitches buzz; fast alternation of two neighbouring pitches makes a rasp or a wobble. Every melody is newly composed for this game.

### Notation (maps one-to-one onto the template's `Note[]`)
The template plays `Sound.play(notes, volume, stopFirst)` where each note is `[seconds, pitch]`: pitch is semitones from middle C (`261.63 Hz`; fractional values are allowed), `null` is a rest and `"noise"` a noise burst. A recipe is a list of tokens, played in order:

| Token | Meaning | As template notes |
|---|---|---|
| `G4:0.315` | Note G4 for 0.315 s | `[0.315, 7]`. Pitch = 12 × (octave − 4) + C 0, C# 1, D 2, D# 3, E 4, F 5, F# 6, G 7, G# 8, A 9, A# 10, B 11 |
| `-30:0.04` | Note given directly in semitones from middle C | `[0.04, -30]` |
| `R:0.05` | Rest | `[0.05, null]` |
| `X:0.02` | Noise burst | `[0.02, "noise"]` |
| `T` | Tick: the template's `TICK` | `[0.004, 36]` |
| `sweep(f0,f1,ms,step)` | A glide from f0 Hz to f1 Hz | n = round(ms ÷ step) notes of step ms each; note i (0 … n−1) has frequency f0 × (f1 ÷ f0)^(i ÷ (n − 1)) and pitch 12 × log2(f ÷ 261.63) |
| `buzz(a,b,step,ms)` | A rasp or wobble | n = round(ms ÷ step) notes of step ms, alternating pitch a, b, a, b … (semitones from middle C) |
| `pulse(hz,on,off,count)` | A thinning tone | `count` times: a note of `on` ms at `hz`, then a rest of `off` ms |
| `( … )xN` | Repeat | The bracketed tokens N times |

**Playback rules:**
- A screen's motif starts when the screen has been drawn, and stops whatever was playing (`stopFirst` true).
- The key blips (`answer-blip`, `answer-yes`) mix over the current sound (`stopFirst` false).
- With sound off nothing plays, but every screen timed by its sound waits exactly the motif's length below.
- A motif is never cut short by its own screen. It ends when it ends, or when the next screen's motif starts.
- `wait-tick` (GDD §9, optional) is **not used**: there is no setting to turn it on.

### Motifs

| id | Trigger | Mood | Length | Contour (in words) |
|---|---|---|---|---|
| `anthem` | title | pompous, a little off | 7.14 s | a dotted march in G major climbing to D5; a sour C#5 on the way up in bar 2; the last cadence arrives a beat late after a silent beat |
| `welcome-fanfare` | welcome | herald, bright | 1.50 s | four rising notes, the last held: C4 F4 A4 D5 |
| `month-chime` | month | clockwork | 0.50 s | a falling major third, two strikes |
| `ledger` | treasury | counting money | 0.60 s | six quick ticks, then a drawer click (noise and a low note) |
| `report-open` | report | a file slides open | 0.40 s | a short fall from 1200 Hz to 400 Hz, then a click |
| `report-none` | report-offer (unavailable) | shrug | 2.50 s | two flat buzzes, the second lower and longer |
| `bankrupt-slide` | bankrupt | the money drains away | 2.00 s | a long slide from 880 Hz to 110 Hz ending in a low rasp |
| `audience-bell` | audience | someone at the door | 0.80 s | three-note doorbell: down a third, then up a fifth |
| `answer-blip` | any key that answers a prompt | acknowledge | 4 ms | one tick; Y gets a short higher blip instead |
| `answer-yes` | Y at a yes/no prompt | acknowledge yes | 30 ms | a 30 ms blip at C6 |
| `cash-short-raspberry` | cash-short | embarrassment | 1.00 s | a low wobbling buzz between C2 and D2 |
| `refuse-thud` | must-refuse | a door shuts | 0.40 s | a thump of noise and a low C2 |
| `swiss-whistle` | swiss (money moved) | furtive | 1.00 s | four whistled notes, A5 E5 G5 B5, the last held |
| `loan-typewriter` | loan-wait | officials at work | 1.00 s | seven irregular ticks, then a carriage bell |
| `loan-yes` | loan-result (granted) | money arrives | 1.00 s | a quick C-major arpeggio and a till ding on G6 |
| `loan-no` | loan-result (not granted) | rejection | 0.60 s | two falling notes, E4 then A3 |
| `news-teleprinter` | news-alert | breaking news | 6.00 s | a rising-fourth sting, 4.4 s of teleprinter chatter, the sting again |
| `assassin-shot` | assassin-attempt | sudden | 1.60 s | two creeping ticks in silence, then a shot: noise bursts that thin out |
| `assassin-dead` | assassin-result (killed) | death | 2.50 s | a low tone wavering by a semitone, sinking a whole tone halfway |
| `assassin-miss` | assassin-result (survived) | lucky escape | 2.00 s | a ricochet up from 600 Hz to 2400 Hz, then C5 G5, relieved |
| `war-drums` | war-threat | patriotic alarm | 3.50 s | a snare roll, a bugle call that falls then climbs (E5 E5 C5 G4 C5 E5 G5), a shorter roll |
| `war-short` | invasion | the short war | 4.00 s | bursts of noise between falling shell whistles, a rattle of fire, a last long whistle and a blast |
| `war-won` | war-result (won) | victory | 2.50 s | a brass-style call: G4 G4 C5 E5 G5, then E5 and a held G5 |
| `war-lost` | war-result (lost) | defeat | 2.50 s | a slow minor descent A4 G4 F4 E4, the last held |
| `rotor` | heli-escape | the getaway | 3.00 s | rotor clicks speeding up, a climb from 200 Hz to 1600 Hz, then the tone thinning into pulses as it flies off |
| `sputter` | heli-fail; execution with the helicopter heading | the engine dies | 1.50 s | uneven clicks slowing to a stop, then a cough of noise |
| `volley` | execution | the firing squad | 3.00 s | a short drum roll, a pause, three shots close together, silence |
| `revolt-siren` | revolt-alarm | revolution | 5.00 s | two tones a tritone apart, D5 and G#4, alternating every 0.4 s (2.5 changes a second) |
| `heartbeat` | strength | tension | 5.00 s | low double thumps, the gaps between them shrinking |
| `skirmish` | revolt-start | street fighting | 2.50 s | irregular crackle of noise bursts |
| `overthrown-drop` | overthrown | the end | 2.50 s | one long fall from 600 Hz to 60 Hz into silence |
| `crushed-fanfare` | crushed | vindictive triumph | 1.50 s | C5 C5 G5, E5 G5, a held C6 |
| `footsteps` | mountains | the trek | 4.00 s | ten crunching steps, each a 30 ms noise burst, slowing down |
| `caught-jig` | caught | cruelly cheerful | 3.00 s | a jig in D major, six groups of three quick notes, ending on a held D5 |
| `escaped-whistle` | escaped | cheeky relief | 2.50 s | a whistle sliding up from 800 Hz to 1800 Hz, then B5 and a held D6 |
| `funeral` | funeral | mock-solemn state funeral | 12.00 s | two low G2 thumps; the anthem's first bar, slowed and in G minor; one D2; its third bar in minor; a pompous turn; a held G4 and a last G2 |
| `rating-tally` | rating, each line | counting | 30 ms per line | one 30 ms blip per line, a whole tone higher each time: C5, D5, E5, F#5, G#5, A#5, C6 |
| `new-best` | rating (new best) | a record | 1.50 s | a bright run up to C7, a dip to G6, C7 held |

The lengths of the motifs that time a screen are deliberately at or above GDD §9's targets. Where GDD §9 gave a shorter target, the motif is lengthened so that its screen's text can be read:
- `report-none` 2.5 s
- `assassin-shot` 1.6 s
- `assassin-dead` 2.5 s
- `assassin-miss` 2 s
- `war-drums` 3.5 s
- `war-short` 4 s
- `war-won` and `war-lost` 2.5 s
- `rotor` 3 s
- `volley` 3 s
- `skirmish` 2.5 s
- `overthrown-drop` 2.5 s
- `caught-jig` 3 s
- `escaped-whistle` 2.5 s

RULES §15.5 allows lengthening, never shortening.

### Recipes (exact)
Volume is the second argument to `Sound.play`.

**`anthem`** · volume 0.05 · 7.140 s · 25 template notes

```
G4:0.315 G4:0.105 B4:0.315 A4:0.105 G4:0.42 D5:0.42 C5:0.315 B4:0.105 A4:0.315 B4:0.105 C#5:0.42 D5:0.42 E5:0.315 D5:0.105 C5:0.315 B4:0.105 A4:0.21 G4:0.21 F#4:0.42 G4:0.315 A4:0.105 B4:0.315 A4:0.105 R:0.42 G4:0.84
```

**`welcome-fanfare`** · volume 0.05 · 1.500 s · 4 template notes

```
C4:0.25 F4:0.25 A4:0.25 D5:0.75
```

**`month-chime`** · volume 0.05 · 0.500 s · 3 template notes

```
E5:0.2 R:0.05 C5:0.25
```

**`ledger`** · volume 0.05 · 0.600 s · 16 template notes

```
(T R:0.076)x6 X:0.02 R:0.03 C3:0.03 R:0.04
```

**`report-open`** · volume 0.04 · 0.400 s · 33 template notes

```
sweep(1200,400,300,10) R:0.05 T R:0.046
```

**`report-none`** · volume 0.04 · 2.500 s · 152 template notes

```
buzz(-15,-14,10,600) R:0.3 buzz(-20,-19,10,900) R:0.7
```

**`bankrupt-slide`** · volume 0.05 · 2.000 s · 120 template notes

```
sweep(880,110,1600,20) buzz(-36,-35,10,400)
```

**`audience-bell`** · volume 0.05 · 0.800 s · 3 template notes

```
E5:0.2 C5:0.2 G5:0.4
```

**`answer-blip`** · volume 0.03 · 0.004 s · 1 template notes

```
T
```

**`answer-yes`** · volume 0.03 · 0.030 s · 1 template notes

```
C6:0.03
```

**`cash-short-raspberry`** · volume 0.05 · 1.000 s · 50 template notes

```
buzz(-24,-22,20,1000)
```

**`refuse-thud`** · volume 0.05 · 0.400 s · 3 template notes

```
X:0.05 C2:0.15 R:0.2
```

**`swiss-whistle`** · volume 0.04 · 1.000 s · 7 template notes

```
A5:0.15 R:0.05 E5:0.15 R:0.05 G5:0.15 R:0.05 B5:0.4
```

**`loan-typewriter`** · volume 0.05 · 1.000 s · 16 template notes

```
T R:0.07 T R:0.12 T R:0.05 T R:0.09 T R:0.11 T R:0.06 T R:0.1 G6:0.25 R:0.122
```

**`loan-yes`** · volume 0.05 · 1.000 s · 7 template notes

```
C5:0.1 E5:0.1 G5:0.1 C6:0.2 R:0.05 G6:0.35 R:0.1
```

**`loan-no`** · volume 0.05 · 0.600 s · 3 template notes

```
E4:0.25 R:0.05 A3:0.3
```

**`news-teleprinter`** · volume 0.04 · 6.000 s · 207 template notes

```
A5:0.15 D6:0.35 R:0.1 (T R:0.03 T R:0.05 T R:0.02 T R:0.06 T R:0.04)x20 R:0.2 A5:0.15 D6:0.35 R:0.3
```

**`assassin-shot`** · volume 0.06 · 1.600 s · 13 template notes

```
R:0.3 T R:0.4 T R:0.292 X:0.06 R:0.01 X:0.03 R:0.02 X:0.02 R:0.03 X:0.01 R:0.42
```

**`assassin-dead`** · volume 0.05 · 2.500 s · 41 template notes

```
(G2:0.05 F#2:0.05)x10 (F2:0.05 E2:0.05)x10 R:0.5
```

**`assassin-miss`** · volume 0.04 · 2.000 s · 29 template notes

```
sweep(600,2400,250,10) R:0.25 C5:0.2 G5:0.4 R:0.9
```

**`war-drums`** · volume 0.05 · 3.500 s · 69 template notes

```
(X:0.02 R:0.03)x20 E5:0.15 E5:0.15 C5:0.15 G4:0.3 C5:0.15 E5:0.15 G5:0.6 R:0.1 (X:0.02 R:0.03)x10 R:0.25
```

**`war-short`** · volume 0.05 · 4.000 s · 96 template notes

```
X:0.15 sweep(1000,200,300,20) R:0.1 X:0.1 sweep(800,150,300,20) R:0.1 X:0.2 sweep(1200,100,400,20) R:0.2 (X:0.05 R:0.05)x6 sweep(600,80,500,20) R:0.3 X:0.3 R:0.45
```

**`war-won`** · volume 0.05 · 2.500 s · 8 template notes

```
G4:0.2 G4:0.1 C5:0.2 E5:0.2 G5:0.5 E5:0.2 G5:0.6 R:0.5
```

**`war-lost`** · volume 0.05 · 2.500 s · 5 template notes

```
A4:0.4 G4:0.4 F4:0.4 E4:0.8 R:0.5
```

**`rotor`** · volume 0.04 · 3.000 s · 105 template notes

```
T R:0.12 T R:0.1 T R:0.09 T R:0.08 T R:0.07 T R:0.06 T R:0.05 T R:0.045 T R:0.04 T R:0.035 (T R:0.03)x6 sweep(200,1600,800,20) pulse(1600,20,30,8) pulse(1600,10,40,8) R:0.466
```

**`sputter`** · volume 0.05 · 1.500 s · 20 template notes

```
T R:0.04 T R:0.05 T R:0.07 T R:0.06 T R:0.1 T R:0.09 T R:0.14 T R:0.2 X:0.08 R:0.05 X:0.05 R:0.538
```

**`volley`** · volume 0.06 · 3.000 s · 27 template notes

```
(X:0.02 R:0.03)x10 R:0.6 X:0.12 R:0.18 X:0.12 R:0.18 X:0.12 R:1.18
```

**`revolt-siren`** · volume 0.04 · 5.000 s · 25 template notes

```
(D5:0.35 R:0.05 G#4:0.35 R:0.05)x6 R:0.2
```

**`heartbeat`** · volume 0.06 · 5.000 s · 28 template notes

```
-30:0.04 R:0.12 -30:0.04 R:0.8 -30:0.04 R:0.12 -30:0.04 R:0.7 -30:0.04 R:0.12 -30:0.04 R:0.6 -30:0.04 R:0.12 -30:0.04 R:0.5 -30:0.04 R:0.12 -30:0.04 R:0.4 -30:0.04 R:0.12 -30:0.04 R:0.3 -30:0.04 R:0.12 -30:0.04 R:0.3
```

**`skirmish`** · volume 0.05 · 2.500 s · 28 template notes

```
X:0.03 R:0.07 X:0.02 R:0.12 X:0.05 R:0.04 X:0.02 R:0.2 X:0.03 R:0.05 X:0.06 R:0.1 X:0.02 R:0.03 X:0.02 R:0.15 X:0.04 R:0.06 X:0.03 R:0.25 X:0.02 R:0.08 X:0.05 R:0.1 X:0.02 R:0.3 X:0.03 R:0.51
```

**`overthrown-drop`** · volume 0.05 · 2.500 s · 61 template notes

```
sweep(600,60,1500,25) R:1.0
```

**`crushed-fanfare`** · volume 0.05 · 1.500 s · 6 template notes

```
C5:0.15 C5:0.15 G5:0.3 E5:0.15 G5:0.15 C6:0.6
```

**`footsteps`** · volume 0.03 · 4.000 s · 20 template notes

```
X:0.03 R:0.27 X:0.03 R:0.29 X:0.03 R:0.31 X:0.03 R:0.33 X:0.03 R:0.35 X:0.03 R:0.37 X:0.03 R:0.39 X:0.03 R:0.41 X:0.03 R:0.43 X:0.03 R:0.55
```

**`caught-jig`** · volume 0.05 · 3.000 s · 16 template notes

```
D5:0.15 F#5:0.15 A5:0.15 G5:0.15 E5:0.15 C#5:0.15 D5:0.15 A4:0.15 D5:0.15 F#5:0.3 E5:0.15 B5:0.15 A5:0.15 F#5:0.15 D5:0.45 R:0.3
```

**`escaped-whistle`** · volume 0.04 · 2.500 s · 25 template notes

```
sweep(800,1800,400,20) R:0.1 B5:0.15 R:0.05 D6:0.5 R:1.3
```

**`funeral`** · volume 0.05 · 12.000 s · 24 template notes

```
G2:0.25 R:0.25 G2:0.25 R:0.25 G4:0.75 G4:0.25 A#4:0.75 A4:0.25 G4:1.0 D5:1.0 D2:0.5 D#5:0.75 D5:0.25 C5:0.75 A#4:0.25 A4:0.5 G4:0.5 F#4:1.0 G4:0.25 A4:0.125 G4:0.125 F#4:0.25 G4:1.25 G2:0.5
```

**`rating-tally`** · volume 0.03 · 0.030 s · 1 template notes

```
C5:0.03
```

**`new-best`** · volume 0.05 · 1.500 s · 9 template notes

```
C6:0.08 D6:0.08 E6:0.08 G6:0.08 C7:0.3 R:0.1 G6:0.1 C7:0.5 R:0.18
```

**About the anthem and the funeral.**
- `anthem` uses a beat of 0.42 s (4/4, 17 beats including the late cadence). Its four bars, in beats:
  - bar 1: G4 ¾ G4 ¼ B4 ¾ A4 ¼ G4 1 D5 1
  - bar 2: C5 ¾ B4 ¼ A4 ¾ B4 ¼ C#5 1 D5 1 (the sour C#5 is the "slightly off" note)
  - bar 3: E5 ¾ D5 ¼ C5 ¾ B4 ¼ A4 ½ G4 ½ F#4 1
  - bar 4: G4 ¾ A4 ¼ B4 ¾ A4 ¼, a silent beat, then G4 2 (the cadence lands a beat late)
- `funeral` is the GDD's recommended **original mourning motif**: our own anthem turned into its own dirge.
  - It takes bar 1 and bar 3 of the anthem, slowed (0.5 s to the beat) and moved to G minor (B becomes B♭, written A#; E becomes E♭, written D#).
  - It frames them with heavy low G2 and D2 notes, the "repeated bass" a single voice can manage.
  - It ends with a pompous turn (G A G F#) onto a held G.
  - No public-domain funeral march is quoted.
- `rating-tally` is played once per rating line with pitch 12 + 2 × i for the i-th line (0-based): C5, D5, E5, F#5, G#5, A#5, C6.

## 10. Distinctiveness

The left column describes, in words only, the recognisable elements of the original's screens as the verify role described them. It reproduces none of them. The right column is what *Samosa* does instead.

| Original element (described, not reproduced) | How ours differs |
|---|---|
| The audience screen showed a **row of large faction emblems** across the screen, with the requesting faction picked out | **No emblems at all**, for any faction, anywhere. The audience is a single **palace door** centred on a black wall, with a magenta letterhead. The usher's one-line announcement names the faction, and the request sits on a white **petition card**. Factions are only ever named in words. |
| The intelligence report was **columns of faction names with horizontal bar charts** (one colour for popularity, another for strength). Plotters' names flashed, and a flashing letter marked assassins. | A **manila dossier**: yellow paper and black type, with a letterhead and a red classified bar. A plain typed table gives each group's number, name and **two digits** (no bars, no meters, no colour coding). Plots are listed **below** the table as sentences on red bars (`RISE`, `HIRE AN ASSASSIN`). **Nothing on the report flashes**, and no letter marks anything. |
| Many screens had **tiled, repeating-pattern backgrounds** filling the paper | **Every screen has plain, solid paper.** Decoration is a few single lines (rules, a perforation, a margin), outlines and one silhouette. No pattern fills any screen. |
| The title was **the title word repeated as wallpaper, flashing**, with a **national flag** | The name appears **once**, still, in brass block letters over an empty balcony at night. **No flag** of any kind appears in the game. |
| Prompts sat in a **column down one side** | Every prompt sits in **one place**, the white counterfoil across the **bottom** of the page. Choices (menu, section, help list) are numbered lists in the middle of the page. |
| A **footer bar of alternating colours** carried the key prompt | A **single white slip** with a perforated top edge, black text and a one-cell blinking cursor. The same on every screen; never striped. |
| **Lots of flashing headings** | **No heading or text ever flashes.** Each screen has at most one small flashing element: the cursor, the alarm lamp or the rifle sight. |
| A **President portrait** | The President is **never shown**. The balcony stands empty, and a statue appears as a featureless silhouette. |
| A **secret-police face** | No face. The secret police are a letterhead and a tied **dossier folder**. |
| A **band of dollar signs** | No money symbols as decoration. Money is a **ledger page** (blue ink, red margin, ruled lines) and an **empty strongbox**. |
| A **helicopter** | Ours is a small side view taking off from the **palace roof at night**, rising a row at a time beside the text. Grounded, it trails a **puff of smoke**. Drawn from our own description. |
| **Mountains** | One **black ridge silhouette** under a crescent moon, with a tiny walking figure on the path below. The same ridge at **dawn** (yellow sky) for the escape. |
| A **coffin** | No coffin. A green **laurel wreath** on black. |
| The original's tunes and effects | All motifs are new (§9). The funeral is **our own anthem** slowed into G minor, not any traditional march. |

**Would anyone mistake a Samosa screen for the original's?** The layouts, the motif (paperwork and vanity), the colour families and the near-total absence of flashing were all chosen to make the answer no. The phase 7 visual review checks it on the contact sheet.

## 11. Do and don't

**Do:**
- Keep one accent per screen, and use red only as BRIGHT red: as black-on-red bars and boxes, or as red ink on black.
- Put the white counterfoil on every screen that waits for a key, and only there.
- Say everything that matters in words as well as colour.
- Draw every new picture from a written description, in whole cells, with one ink per cell.
- Keep the satire on the office: the letterheads, decrees, medals, statue and balcony.

**Don't:**
- Don't tile or pattern any background.
- Don't flash headings, names, numbers or more than one small element.
- Don't show the President, a face, a flag, a coat of arms, a party symbol or money signs as decoration.
- Don't draw national costume, food or landmarks of Nicaragua or Honduras.
- Don't draw any real flag, party emblem or party colour scheme (blue–white–blue bands, a red-and-black diagonal), or any likeness of a real person.
- Don't make a joke of victims, prisoners, exiles, the Miskito coast or faith, in pictures or words.
- Don't use red or magenta paper behind white or yellow text.
- Don't quote any existing tune, the original's or a well-known march, anthem or bugle call.
