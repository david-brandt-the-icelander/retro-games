# Samosa: UI design

Status: draft for owner review · Phase 5 of `create-retro-game` · Contact sheet: `docs/contact-sheet.png` (to be rendered by the implementer with `npm run sheet`) · Owner approval: _pending_

This document turns every wireframe in `WIREFRAMES.md` into an exact specification and contains **all of the game's final text**. It follows `ART-BIBLE.md` for colour, icons, motion and sound, and `GDD.md` §8 for the text budgets. The implementer builds from this document, the art bible and RULES alone; anything not written here is not on screen.

Written by the designer from `RULES.md` and `GDD.md` only. No text here is taken or adapted from the original game.

## Global patterns

### The page
Every screen starts with a CLS in its page colours (each screen gives *Page (CLS)*), then sets its border, then draws its regions. BRIGHT is off unless a region says otherwise. Cells not covered by a region or decoration keep the page colours and stay empty.

### The letterhead (rows 0–1)
On the palace, ledger, dossier, audience and cabinet screens:
- **Row 0, the band:** all 32 cells in the family's band colours (each screen's `L` row gives them).
  - Col 1: the `seal` icon.
  - Cols 3–18: the office's name in capitals, left-aligned from col 3. Every name is ≤ 16 characters.
  - Cols 19–31: empty band. The sound overlay uses cols 20–31, so it never hides text.
- **Row 1, the double rule:** two 1-pixel lines on pixel rows 2 and 5 of the row, across all 256 pixels, drawn in the page ink on the page paper.

The office names, by screen:

| Office (final text) | Screens |
|---|---|
| `"HOW TO RULE"` | howto |
| `"ABOUT SAMOSA"` | about |
| `"THE PALACE"` | welcome |
| `"STATE TREASURY"` | treasury, bankrupt, cash-short |
| `"STATE SECURITY"` | report, report-offer |
| `"AUDIENCE HALL"` | audience, must-refuse |
| `"PRIVATE COUNSEL"` | advice-offer, advice |
| `"FOR SIGNATURE"` | dialog |
| `"THE DIRECTORATE"` | menu, section, section-used |
| `"OFFSHORE DESK"` | swiss |
| `"FOREIGN MINISTRY"` | loan-wait, loan-result |
| `"FINAL RECKONING"` | rating |

The letterheads are short labels the GDD's §8.1 table does not list. They add a little text (12 labels, ≤ 16 columns each), carry the art bible's "palace paperwork" motif, and can be dropped without changing any layout if the owner prefers.

Screens without a letterhead are the title, `month` (a calendar), the press screens, and every crisis, war, flight and ending screen. They are interruptions, not paperwork, and fill the whole screen.

### Every screen waits for a key (owner decision, 2026-11-06)
This overrides every *Timing* line below that says a screen moves on by itself, lasts as long as its sound, or has "no footer":
1. The screen draws in full, running its animation steps and its sound, as specified.
2. It stays at least as long as its old timing (the stated seconds, or its motif's length). Keys pressed during that time are ignored.
3. Then the footer counterfoil appears with the any-key prompt (`"PRESS A KEY OR TAP TO GO ON"`) and its cursor, and the screen waits for a key. The touch keypad offers [NEXT], and a tap on the screen counts.

Where a formerly timed screen draws anything in rows 21–23, move that content up or trim it so that the footer fits; the layout tests must stay clean (no text or art under the footer). The unaffordable decision dialog and the unavailable report offer get the any-key footer too. The screen-reader text adds "Press any key." at the end.

### The footer counterfoil (rows 21–23): "waiting for a key"
Every screen that waits for a key (which is now every screen) has the same footer: a tear-off slip at the foot of the page.
- **Rows 21–23:** white paper, black ink, BRIGHT off, on every screen and in every colour family.
- **Row 21, the perforation:** one pixel line on pixel row 3 of the row, with every other pixel set (x = 0, 2, 4, …, 254), in black.
- **Row 22, the prompt:** centred, starting at column floor((32 − length) ÷ 2). Every footer prompt is ≤ 28 characters.
- **The cursor:** one cell holding the full-block glyph `█`, black ink on white paper with **FLASH on**. It sits one blank cell after the prompt's last character, at column start + length + 1, which is ≤ 31 for a 28-character prompt. It is the only flashing element on any screen that has a footer.
- **Row 23:** empty, except on the title, which uses it for its second line of keys. The title's cursor follows row 22.

The prompts (final text):

| id (GDD §8.1) | Text | Used on |
|---|---|---|
| `prompt-any` | `"PRESS A KEY OR TAP TO GO ON"` | welcome, treasury, report, audience, advice, swiss (after 2 s), loan-result, alone, funeral, rating |
| `prompt-yes` | `"Y = YES   ANY OTHER KEY = NO"` | report-offer (available), advice-offer, dialog (affordable), escape-ask, crushed |
| menu | `"PRESS 1-5, OR ANY OTHER KEY"` | menu |
| section | `"NUMBER: CHOOSE  OTHER: BACK"` | section |
| `help-ask` | `"PRESS 1-6 TO ASK FOR HELP"` | help-list |
| howto | `"ANY KEY: NEXT PAGE"` (pages 1–5), `"ANY KEY: BACK TO THE TITLE"` (page 6) | howto |
| about | `"ANY KEY: BACK TO THE TITLE"` | about |
| `title-keys` | row 22 `"ANY KEY: TAKE POWER"`, row 23 `"H HOW TO PLAY  A ABOUT  M SOUND"` | title |

### Red bars and stamp boxes
- **Red bar:** a single row of black ink on BRIGHT red paper, with no frame. Text sits inside it from the bar's first text column. Used for the report's classified line, the report's plot lines and the treasury's debt warning.
- **Stamp box:** a multi-row rectangle of cells, black ink on BRIGHT red paper (BRIGHT green for good news), with a 1-pixel **frame** on the outermost pixel ring of the box: the top pixel row of its first row, the bottom pixel row of its last row, the leftmost pixel column of its first column and the rightmost of its last column. Text is centred between its second and second-last columns, so the frame never touches a glyph. Used on bankrupt, must-refuse, section-used, loan-result and war-result.
- Contrast: black on BRIGHT red is 5.3:1 and black on BRIGHT green is 15.3:1. Every bar and box also says its meaning in words.

### Double-size text
Some lines are drawn at **double size**: the template's own 8×8 glyph, with each glyph pixel drawn as a 2×2 block, so one character fills 2×2 cells. A double-size string of n characters takes 2n columns and 2 rows. It is centred like normal text: start column floor((region width − 2n) ÷ 2) + the region's first column. Used for the month number and its strip, `BANKRUPT`, the newspaper masthead, `REVOLUTION!`, the invasion totals and the rating total. The text mirror records these strings as ordinary text.

### Typing effect
On `news-alert` only: the tape's text appears one character every 60 ms, in reading order. Nothing else types.

### Timed screens and keys
A screen that moves on by itself (GDD §7 pacing other than *key*) **reads no key**. Keys pressed during it are discarded, and it is not shortened (RULES §15.5: the time may be lengthened, never shortened). M still toggles sound. The `swiss` screen reads no key for its first 2 s.

### Keypad offers (touch)
The keypad shows exactly the buttons listed under each screen's *Keypad offers*. The general rules:

| Prompt kind | Buttons (label → key sent) |
|---|---|
| Any key | `NEXT` → Enter (the template's neutral "any key") |
| Yes / no | `YES` → `y`, `NO` → `n` |
| Menu | `1` … `5` → the digit, `NO DECISION` → Enter |
| Section | one button per listed option, labelled with its number → the digit; `BACK` → Enter |
| Help list | `1` … `6` → the digit (all six) |
| Title | `PLAY` → Enter, `HOW TO` → `h`, `ABOUT` → `a` |
| Timed screens | no buttons |

- Tapping the screen counts as any key, as in the template, everywhere except the help list. There a tap is ignored, so a stray tap can't choose a helper.
- The sound button (`SOUND: ON (M)` / `SOUND: OFF (M)`, the template's) is always shown under the keypad.
- Buttons are at least 44 × 44 CSS pixels.

### The sound overlay (`sound`)
M (or the sound button) toggles sound on every screen, including timed ones and the title. The key never reaches the game.
- **Drawing:** the 12 cells of row 0, cols 20–31, show `"SOUND: {state}"` from col 21, in BRIGHT white ink on black paper. `{state}` is `ON` or `OFF`.
- **Saving what was there:** before drawing, the pixels, attributes and characters of those 12 cells are saved. After 1.5 s they are restored, unless the screen has been redrawn since (a CLS happened). In that case nothing is restored, because the new screen already owns the cells.
- **Pressing M again within the 1.5 s** redraws the overlay with the new state and restarts the 1.5 s, keeping the first saved copy.
- **Screen reader:** a polite announcement, `Sound on.` or `Sound off.`

## Placeholders and number formats

### Placeholders
Every `{name}` in final text is filled by the game. The *worst case* column is the width used when counting every line in this document. Names are counted at their real lengths (GDD §4.2), and numbers at GDD §8.3's reserves.

| Placeholder | Filled with | Format | Worst case (columns) |
|---|---|---|---|
| `{amount}`, `{costs}`, `{swiss}`, `{before}` | Money in thousands of dollars | Money format (below). On `dialog`, `{amount}` is the size of the change without a sign | 12 |
| `{price}` | The report's price, 1 | Money format: `$1,000` | 12 reserved (6 used) |
| `{month}`, `{months}` | The month number; months ruled | Plain integer, no separators | 3 |
| `{pop}`, `{str}` | A popularity or strength, 0–9; on `rating`, `{pop}` is the sum of all eight popularities, 0–72 | Plain digits | 2 |
| `{revstr}` | This month's revolution strength, 10–12 | Plain digits | 2 |
| `{change}` | A non-zero change, −9 to +9 | Sign always shown: `+4`, `-3` (hyphen-minus) | 2 |
| `{hstr}` | The helper's strength, 0–9 | Plain digits | 2 |
| `{pstr}` | The President's strength, 0 upward | Plain integer | 3 |
| `{ours}`, `{theirs}`, `{combined}`, `{rebels}` | Sums of strengths | Plain integer | 3 |
| `{total}`, `{best}`, `{points}` | Rating points | Plain integer, no separators | 5 |
| `{faction}` | A domestic faction's label | `ARMY`, `PEASANTS`, `SAMOSAS` | 8 |
| `{group}`, `{ally}`, `{helper}` | Any group's label | The labels below | 11 |
| `{power}` / `{Power}` | A superpower in a sentence | `Moscow` (the East), `Washington` (the West); already capitalised, so `{Power}` is the same word | 10 |
| `{neighbour}` | The bordering state | `Honduras` (`HONDURAS` in headlines) | 8 |
| `{country}` | The player's country | `Nicaragua` (not used in any final text: the texts name it outright) | 9 |
| `{crop}` | The export crop | `coffee` (`COFFEE` in headlines) | 6 |
| `{allyNo}`, `{n}` | A group number 1–6; a section or option number 1–6 | One digit | 1 |
| `{page}`, `{pages}` | How-to page, of 6 | One digit | 1 |
| `{state}` | Sound state | `ON`, `OFF` | 3 |
| `{section}` | The section's theme, as on `menu` | The five texts on `menu` | 26 |
| `{item}` | What could not be paid for | A decision's label; for a request, the dialog's own line `Petition of the {faction}` | 28 |

### Group labels
Groups are always named on screen by the GDD §4.2 labels, in capitals, so the eye finds them in prose and tables alike. The longest is `SEC. POLICE` (11). In fixed prose the full names are used (the Samosas, State Security, Moscow, Washington). The screen reader always says the spoken name.

| # | Label (on screen) | Spoken |
|---|---|---|
| 1 | `ARMY` | the Army |
| 2 | `PEASANTS` | the Peasants |
| 3 | `SAMOSAS` | the Samosa family |
| 4 | `CONTRAS` | the Contras |
| 5 | `HONDURAS` | Honduras |
| 6 | `SEC. POLICE` | State Security |
| 7 | `EAST` | Moscow and Havana |
| 8 | `WEST` | Washington |

The President is always "President Ortiga" or "Ortiga" (6), never with a first name, a gender or a spouse.

### Money
Money is held in whole thousands of dollars (RULES §2). To show a value *v*:
- *v* = 0 shows as `$0`.
- Otherwise: a minus sign if *v* < 0, then `$`, then |*v*| with a comma every three digits, then `,000`.
- Examples: 1000 → `$1,000,000`; 60 → `$60,000`; 469 → `$469,000`; 1 → `$1,000`; −119 → `-$119,000`; 12345 → `$12,345,000`.
- The longest value (12 columns) is `-$12,345,000`.

Where a money line has a label on the left (the ledger lines on `treasury`, `swiss` and `rating`), the amount is **right-aligned** to the region's last column, with spaces between label and amount. Debt therefore always shows a minus sign *and* a worded warning: never colour alone.

### Plurals
No line puts a number before a noun that would need a plural, so no singular variants are needed ("Months in power: 1." reads correctly).

## Screens

One entry per screen in GDD §7 order. Cells are given as rows × columns, 0-based (row 0 at the top, column 0 at the left), inclusive. Colours: black, blue, red, magenta, green, cyan, yellow, white (the template's 0–7). A region's ink/paper apply to every cell in it unless its content says otherwise. Text in quoted code spans is final and exact, including spaces and punctuation; *italic labels* name the variant or the row and are not shown. Every text line was counted with each placeholder at its worst-case width (§ Placeholders).

### title

- **Wireframe:** WIREFRAMES.md § title (GDD #1; engine kind: extra (the flow starts here))
- **Colour family:** Title · **Border:** black · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| T | rows 3–5 × cols 4–26 | yellow | black | yes | no | left | icon `logo-S, logo-A, logo-M, logo-O, logo-S, logo-A` (letters at cols 4, 8, 12, 16, 20, 24; each 12×12 picture drawn at double size) |
| G | row 8 × cols 0–31 | cyan | black | no | no | centre | `"New dynasty. Same old palace."` |
| B | rows 10–15 × cols 12–19 | white | black | no | no | left | icon `balcony` (attribute map in the art bible: interior cells black ink on BRIGHT yellow paper) |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | *row 22:* `"ANY KEY: TAKE POWER"`<br>*row 23:* `"H HOW TO PLAY  A ABOUT  M SOUND"`<br>*Note:* title variant: two lines; the cursor follows row 22 only |

- **Decoration (`#`):** row 2 × cols 4–26: brass rule: a 2-pixel line on pixel rows 6–7 of row 2, BRIGHT yellow; row 6 × cols 4–26: brass rule: a 2-pixel line on pixel rows 0–1 of row 6, BRIGHT yellow; row 16 × cols 2–29: facade ledge: a 1-pixel line on pixel row 0 of row 16, white.
- **States:** No animation. The logo and tagline never flash.
- **Input:** Any key except H, A and M starts the game (to `welcome`). H opens `howto`, A opens `about`. M toggles sound and stays here. **Keypad offers:** [PLAY] sends any key · [HOW TO] sends H · [ABOUT] sends A.
- **Timing:** Waits for a key.
- **Sound:** `anthem` once each time the title appears from the start of the page or after a game (not when returning from `howto` or `about`). On the very first visit audio is still locked, so it starts the first time audio unlocks while the title is up (M or the sound button).
- **Screen-reader text** (polite): Samosa. New dynasty. Same old palace. A picture of an empty palace balcony with a microphone. Press any key to take power, H for how to play, A for about, M for sound.

### howto

- **Wireframe:** WIREFRAMES.md § howto (GDD #2; engine kind: extra)
- **Colour family:** Palace · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | blue | yellow | yes | no | left | icon `seal` |
| L | row 0 × cols 3–18 | blue | yellow | yes | no | left | `"HOW TO RULE"` |
| P | rows 3–18 × cols 1–30 | white | blue | no | no | left | the page's lines from § How to play (rows 3–18, one line per row, line 1 in yellow) |
| N | row 19 × cols 18–30 | cyan | blue | no | no | right | `"PAGE {page} OF {pages}"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | *pages 1–5:* `"ANY KEY: NEXT PAGE"`<br>*page 6:* `"ANY KEY: BACK TO THE TITLE"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper; row 0 × cols 19–31: letterhead band: yellow paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **States:** Six pages; the page text changes, nothing else.
- **Input:** Any key except M turns the page; after page 6, back to `title`. No key goes back a page (one key per prompt). **Keypad offers:** [NEXT].
- **Timing:** Waits for a key on each page.
- **Sound:** None.
- **Screen-reader text** (polite): How to rule, page {page} of {pages}. Then the page's lines in order, with blank lines dropped. Press any key for the next page (or, on page 6: to go back to the title).

### about

- **Wireframe:** WIREFRAMES.md § about (GDD #3; engine kind: extra)
- **Colour family:** Palace · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | blue | yellow | yes | no | left | icon `seal` |
| L | row 0 × cols 3–18 | blue | yellow | yes | no | left | `"ABOUT SAMOSA"` |
| C | rows 3–7 × cols 0–31 | yellow | blue | no | no | centre | *row 3:* `"Inspired by Dictator (1983) by"`<br>*row 4:* `"Don Priestley, published by"`<br>*row 5:* `"DK'Tronics. Independent remake,"`<br>*row 6:* `"not affiliated with or endorsed"`<br>*row 7:* `"by the original rights holders."` |
| M | rows 11–16 × cols 0–31 | white | blue | no | no | centre | *row 11:* `"Remade by David Brandt, 2026."`<br>*row 12:* `"A caricature of Nicaraguan"`<br>*row 13:* `"history, not a record. No real"`<br>*row 14:* `"person is portrayed. MPL-2.0."`<br>*row 15:* `"github.com/david-brandt-the-"`<br>*row 16:* `"icelander/retro-games"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"ANY KEY: BACK TO THE TITLE"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper; row 0 × cols 19–31: letterhead band: yellow paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 9 × cols 8–23: short rule: 1-pixel line on pixel row 4 of row 9, cyan.
- **Input:** Any key except M returns to `title`. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): About Samosa. Inspired by Dictator (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders. Remade by David Brandt, 2026. A caricature of Nicaraguan history, not a record. No real person is portrayed. Licence MPL-2.0. Source code at github.com/david-brandt-the-icelander/retro-games. Press any key to go back to the title.

### sound

- **Wireframe:** WIREFRAMES.md § sound (GDD #4; engine kind: extra (overlay))
- **Colour family:** Overlay · **Border:** (unchanged) · **Page (CLS):** none: drawn over the current screen without a CLS

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| O | row 0 × cols 20–31 | white | black | yes | no | left | `"SOUND: {state}"` |
- **States:** {state} is ON or OFF.
- **Input:** M (or the sound button) toggles sound; the overlay shows the new state. M never reaches the game. **Keypad offers:** None of its own (the separate sound button stays visible on every screen).
- **Timing:** Shown for 1.5 s, then the 12 cells are restored. A second M within 1.5 s redraws it with the new state and restarts the 1.5 s.
- **Sound:** None (sound on: the next motif plays as normal; sound off: whatever is playing stops at once).
- **Screen-reader text** (polite): Polite announcement only: 'Sound on.' or 'Sound off.' The screen's own text is not re-read.

### welcome

- **Wireframe:** WIREFRAMES.md § welcome (GDD #5; engine kind: welcome)
- **Colour family:** Palace · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | blue | yellow | yes | no | left | icon `seal` |
| L | row 0 × cols 3–18 | blue | yellow | yes | no | left | `"THE PALACE"` |
| R | rows 3–5 × cols 15–16 | yellow | blue | yes | no | left | icon `rosette` |
| W | rows 8–10 × cols 1–30 | white | blue | no | no | centre | *best L1:* `"Back again, President Ortiga?"`<br>*best L2:* `"Record to beat: {best} points."`<br>*best L3:* `"History expects little of you."`<br>*first L1:* `"The palace is yours, Ortiga."`<br>*first L2:* `"The Samosas left in a hurry."`<br>*first L3:* `"Do try to leave more slowly."` |
| V | rows 12–15 × cols 0–31 | blue | white | no | no | centre | *row 13:* `"The first ledger and the first"`<br>*row 14:* `"State Security file are free."` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper; row 0 × cols 19–31: letterhead band: yellow paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **States:** Variant *best* when a best rating is stored (any number, including 0); variant *first* when none is stored or storage is unavailable. Line 2 of W is yellow; lines 1 and 3 white.
- **Input:** Any key except M continues to the first `treasury`. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** `welcome-fanfare`.
- **Screen-reader text** (polite): The Palace. Back again, President Ortiga? Record to beat: {best} points. History expects little of you. (Or: The palace is yours, Ortiga. The Samosas left in a hurry. Do try to leave more slowly.) Voucher: the first ledger and the first State Security file are free. Press any key.

### month

- **Wireframe:** WIREFRAMES.md § month (GDD #6; engine kind: month)
- **Colour family:** Calendar · **Border:** blue · **Page (CLS):** yellow ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| H | rows 4–5 × cols 8–23 | black | red | yes | no | centre | *rows 4–5:* `"MONTH"` (double size) |
| N | rows 8–11 × cols 10–21 | black | white | no | no | centre | *rows 9–10:* `"{month}"` (double size) |
| S | row 18 × cols 0–31 | yellow | blue | no | no | centre | `"of the eternal revolution"` |
| r | row 3 × col 11 | white | blue | no | no | left | icon `ring` |
| q | row 3 × col 20 | white | blue | no | no | left | icon `ring` |

- **Decoration (`#`):** rows 6–7 × cols 8–23: calendar page: white paper, black ink, no text; rows 8–11 × cols 8–9 and rows 8–11 × cols 22–23: calendar page; rows 12–15 × cols 8–23: calendar page; a 1-pixel tear line on pixel row 7 of row 15, every other pixel.
- **Input:** None: no key is read (M still toggles sound). **Keypad offers:** None.
- **Timing:** 1 s, then on by itself. Keys do not shorten it.
- **Sound:** `month-chime`.
- **Screen-reader text** (polite): Month {month} of the eternal revolution.

### treasury

- **Wireframe:** WIREFRAMES.md § treasury (GDD #7; engine kind: treasury)
- **Colour family:** Ledger · **Border:** green · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"STATE TREASURY"` |
| B | rows 4–5 × cols 4–30 | blue | white | no | no | left | *credit L1 (row 4):* `"Treasury holds {amount}"`<br>*credit L2 (row 5):* `"Solvent, for the moment."`<br>*debt L1 (row 4):* `"Treasury holds {amount}"`<br>*debt L2 (row 5, red bar):* `"IN DEBT! CREDITORS CIRCLE."`<br>*Note:* debt row 5 is a bar: black ink on BRIGHT red paper across cols 4–30, no frame |
| C | row 7 × cols 4–30 | blue | white | no | no | left | `"Monthly costs {costs}"` |
| W | row 9 × cols 4–30 | blue | white | no | no | left | `"Swiss nest egg {swiss}"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white; row 6 × cols 4–30: dotted ledger rule: pixel row 3, every other pixel, blue; row 8 × cols 4–30: dotted ledger rule; row 10 × cols 4–30: double rule (sum line): pixel rows 2 and 4, blue.
- **States:** Credit variant when the treasury is 0 or more; debt variant when below 0 (the amount then carries its minus sign). Row 9 is empty while the Swiss balance is 0. Amounts: § Number formats.
- **Input:** Any key except M continues. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** `ledger`.
- **Screen-reader text** (polite): State Treasury. The treasury holds {amount}. (Credit: Solvent, for the moment. Debt: In debt! Creditors circle.) Monthly costs {costs}. (If any: Swiss nest egg {swiss}.) Press any key.

### report

- **Wireframe:** WIREFRAMES.md § report (GDD #8; engine kind: report (flag: first / bought / final))
- **Colour family:** Dossier · **Border:** black · **Page (CLS):** white ink on black paper, BRIGHT off (the dark file; owner decision 2026-11-06)

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | white | black | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | white | black | no | no | left | `"STATE SECURITY"` |
| T | rows 2–3 × cols 0–31 | white | black | no | no | left | *row 2 (red bar):* `"TOP SECRET: BURN AFTER READING"`<br>*L2 bought:* `"File for month {month}"`<br>*L2 first:* `"Opening file, on the house"`<br>*L2 final:* `"FINAL FILE, FOR THE ARCHIVE"`<br>*Note:* row 2 is a bar: black ink on BRIGHT red paper across cols 0–31, text from col 1; row 3 white on black from col 1 |
| H | row 5 × cols 1–30 | yellow | black | yes | no | left | `"No GROUP         POP.  STR."`<br>'No' at cols 1–2, 'GROUP' at cols 4–8, 'POP.' at cols 18–21, 'STR.' at cols 24–27 |
| G | rows 6–13 × cols 1–30 | white | black | no | no | left | columns: group number at col 1; label at cols 4–14 (left); popularity digit at col 19; strength digit at col 25 ('-' for groups 7 and 8)<br>*example, row 6:* `"1  ARMY           7     6"`<br>*example, row 11:* `"6  SEC. POLICE    9     9"`<br>*example, row 13:* `"8  WEST           7     -"` |
| P | rows 15–17 × cols 0–31 | black | red | yes | no | left | *revolution:* `"{faction} RISE +{allyNo} {ally}"`<br>*assassination:* `"{faction} HIRE AN ASSASSIN"`<br>*none (white on black):* `"No plots uncovered. Yet."` |
| O | rows 19–20 × cols 1–30 | white | black | no | no | left | *row 19:* `"Your bodyguard strength: {pstr}"`<br>*row 20:* `"A revolt needs strength {revstr}"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper (a manila tab); row 0 × cols 19–31: letterhead band: yellow paper (a manila tab) (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **States:** Plot lines: each is a bar (black ink on BRIGHT red paper across cols 0–31, text from col 1) and carries the words RISE or ASSASSIN, so colour is never the only signal. Nothing on this screen flashes. The first report always shows the no-plots line. A strength of 7 or 8 (EAST, WEST) shows '-'.
- **Input:** Any key except M continues. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** `report-open`.
- **Screen-reader text** (polite): State Security file, top secret, for month {month} (or: the opening file / the final file). Then one line per group: 'Army: popularity 6, strength 6.' ... 'Moscow and Havana: popularity 7.' Then each plot as a sentence: 'Plot: the Army plans a revolution with group 4, the Contras.' / 'Plot: the Peasants plan to have you assassinated.' (or: 'No plots uncovered.') Then: 'Bodyguard strength {pstr}. A revolt needs strength {revstr}.' Press any key.

### report-offer

- **Wireframe:** WIREFRAMES.md § report-offer (GDD #9; engine kind: reportOffer (available / unavailable))
- **Colour family:** Dossier · **Border:** black · **Page (CLS):** white ink on black paper, BRIGHT off (the dark file; owner decision 2026-11-06)

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | white | black | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | white | black | no | no | left | `"STATE SECURITY"` |
| F | rows 3–5 × cols 14–17 | white | black | no | no | left | icon `folder` |
| Q | rows 8–9 × cols 1–30 | white | black | no | no | centre | *available L1:* `"Psst. The latest file on who"`<br>*available L2:* `"plots what? Only {price}."`<br>*unavailable L1:* `"No dossier this time, sorry."` |
| R | rows 11–13 × cols 1–30 | white | black | no | no | centre | *police popularity:* `"Police loyalty too low: {pop}"`<br>*police strength:* `"Police too weak: strength {str}"`<br>*treasury:* `"Treasury cannot pay for it."` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | *available only:* `"Y = YES   ANY OTHER KEY = NO"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper (a manila tab); row 0 × cols 19–31: letterhead band: yellow paper (a manila tab) (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **States:** *Available*: Q shows the offer, R is empty, the footer asks yes/no. *Unavailable*: Q row 8 shows the shrug, R lists only the failing reasons with no gaps between them, and there is no footer (rows 21–23 stay black page).
- **Input:** Available: Y or y buys (to `report`); any other key except M skips. Unavailable: no key is read. **Keypad offers:** Available: [YES] sends y · [NO] sends n. Unavailable: none.
- **Timing:** Available: waits for a key. Unavailable: as long as `report-none` (2.5 s); keys do not shorten it.
- **Sound:** Available: none. Unavailable: `report-none`.
- **Screen-reader text** (polite): State Security. Available: 'Psst. The latest file on who plots what? Only $1,000. Press Y for yes, any other key for no.' Unavailable: 'No dossier this time, sorry.' then each reason as written.

### bankrupt

- **Wireframe:** WIREFRAMES.md § bankrupt (GDD #10; engine kind: bankrupt)
- **Colour family:** Ledger (alarm) · **Border:** red · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"STATE TREASURY"` |
| S | rows 3–4 × cols 7–24 | black | red | yes | no | centre | *rows 3–4:* `"BANKRUPT"` (double size) |
| B | rows 7–11 × cols 4–30 | blue | white | no | no | left | *row 7:* `"Nobody is paid. It shows:"`<br>*row 8:* `"ARMY popularity -1"`<br>*row 9:* `"SEC. POLICE popularity -1"`<br>*row 10:* `"SEC. POLICE strength -1"`<br>*row 11:* `"Your bodyguard -1"` |
| X | rows 14–16 × cols 14–17 | blue | white | no | no | left | icon `coffer` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white.
- **Input:** None (M still toggles sound). **Keypad offers:** None.
- **Timing:** 5 s, then on by itself.
- **Sound:** `bankrupt-slide`.
- **Screen-reader text** (assertive): Assertive: Bankrupt! Nobody is paid. It shows: Army popularity minus 1. State Security popularity minus 1. State Security strength minus 1. Your bodyguard minus 1.

### audience

- **Wireframe:** WIREFRAMES.md § audience (GDD #11; engine kind: audience)
- **Colour family:** Audience · **Border:** magenta · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | magenta | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | magenta | no | no | left | `"AUDIENCE HALL"` |
| D | rows 3–8 × cols 13–18 | yellow | black | no | no | left | icon `door-ajar` |
| F | row 10 × cols 0–31 | white | black | no | no | centre | `"Announcing: the {faction}!"` |
| P | rows 12–15 × cols 0–31 | blue | white | no | no | centre | request text R1–R24, line 1 on row 13, line 2 on row 14 (§ Requests) |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: magenta paper; row 0 × cols 19–31: letterhead band: magenta paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 9 × cols 13–18: carpet runner from the door: magenta paper, no ink.
- **Input:** Any key except M continues to `advice-offer`. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** `audience-bell`.
- **Screen-reader text** (polite): Audience hall. Announcing: the Army! (faction as words). The petition: then the two lines of the request. Press any key.

### advice-offer

- **Wireframe:** WIREFRAMES.md § advice-offer (GDD #12; engine kind: adviceOffer)
- **Colour family:** Audience · **Border:** magenta · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | magenta | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | magenta | no | no | left | `"PRIVATE COUNSEL"` |
| Q | rows 5–6 × cols 15–16 | white | black | no | no | left | icon `quill` |
| A | row 9 × cols 0–31 | white | black | no | no | centre | `"A word of counsel, President?"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"Y = YES   ANY OTHER KEY = NO"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: magenta paper; row 0 × cols 19–31: letterhead band: magenta paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **Input:** Y or y: to `advice`. Any other key except M: straight to `dialog`. **Keypad offers:** [YES] sends y · [NO] sends n.
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): Private counsel. A word of counsel, President? Press Y for yes, any other key for no.

### advice

- **Wireframe:** WIREFRAMES.md § advice (GDD #13; engine kind: advice)
- **Colour family:** Audience · **Border:** magenta · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | magenta | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | magenta | no | no | left | `"PRIVATE COUNSEL"` |
| W | rows 2–3 × cols 0–31 | blue | white | no | no | centre | request text R1–R24 or decision text (§ Decision texts) |
| A | rows 5–18 × cols 0–31 | white | black | no | no | left | *row format:* `"=> {group} popularity {change}"`<br>columns: marker '=>' cols 0–1 (requester's popularity line only, in yellow); group name cols 3–13; the word 'popularity' or 'strength' cols 15–24; change right-aligned in cols 26–27; positive changes green, negative BRIGHT red; sign always shown |
| N | row 20 × cols 0–31 | yellow | black | no | no | left | `"=> marks the petitioners"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: magenta paper; row 0 × cols 19–31: letterhead band: magenta paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **States:** Requests: the requester's own popularity line has the marker, its whole line is yellow except the change digits, and row 20 explains the marker. Decisions: no marker, row 20 empty. A request or decision with no changes cannot occur (every item changes something); if it did, A would be empty.
- **Input:** Any key except M continues to `dialog`. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): Private counsel. Then the request or decision text. Then each change as a sentence, e.g. 'Army popularity plus 4. This is the petitioners' own line.' 'Peasants strength minus 2.' Press any key.

### dialog

- **Wireframe:** WIREFRAMES.md § dialog (GDD #14; engine kind: dialog (affordable / unaffordable))
- **Colour family:** Audience (document) · **Border:** magenta · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | magenta | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | magenta | no | no | left | `"FOR SIGNATURE"` |
| F | row 3 × cols 1–30 | blue | white | no | no | centre | *request:* `"Petition of the {faction}"`<br>*decision:* `"By decree of President Ortiga"` |
| W | rows 5–6 × cols 1–30 | blue | white | no | no | centre | request text or decision text |
| M | rows 10–11 × cols 0–31 | blue | white | no | no | centre | *one-off, money in:* `"Paid in at once: {amount}"`<br>*one-off, money out:* `"Paid out at once: {amount}"`<br>*monthly, costs rise:* `"Costs rise {amount} a month"`<br>*monthly, costs fall:* `"Costs fall {amount} a month"`<br>*nothing either way:* `"Free of charge. Splendid."` |
| Q | rows 14–15 × cols 3–4 | blue | white | no | no | left | icon `quill` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | *affordable only:* `"Y = YES   ANY OTHER KEY = NO"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: magenta paper; row 0 × cols 19–31: letterhead band: magenta paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 8 × cols 1–30: rule: 1-pixel line on pixel row 4, blue; row 15 × cols 6–25: signature line: dotted pixel row 6 (every other pixel) with a small x of 5×5 pixels at its left end, blue.
- **States:** Money lines fill from row 10: the one-off line first (if the one-off change is not 0), then the monthly line (if the monthly change is not 0); if both are 0, the free line alone on row 10. *Affordable*: footer with the yes/no prompt. *Unaffordable*: no footer (rows 21–23 stay white page) and the screen moves on after 5 s. {amount} here is always the size of the change without a sign; the words say which way it goes.
- **Input:** Affordable: Y or y grants the request / takes the decision; any other key except M refuses (request) or goes back to `menu` (decision). Unaffordable: no key is read. **Keypad offers:** Affordable: [YES] sends y · [NO] sends n. Unaffordable: none.
- **Timing:** Affordable: waits for a key. Unaffordable: 5 s.
- **Sound:** None.
- **Screen-reader text** (polite): For signature. Petition of the Army (or: by decree of President Ortiga). Then the text. Then the money lines as written ('Paid out at once: $100,000. Costs rise $8,000 a month.'). Affordable: 'Press Y for yes, any other key for no.' Unaffordable: 'There is no money to cover this.' (spoken only, announced politely).

### cash-short

- **Wireframe:** WIREFRAMES.md § cash-short (GDD #15; engine kind: cashShort)
- **Colour family:** Ledger · **Border:** green · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"STATE TREASURY"` |
| I | row 4 × cols 4–31 | blue | white | no | no | left | `"{item}"` |
| C | rows 6–7 × cols 4–31 | blue | white | no | no | left | *row 6:* `"The vaults echo. There is no"`<br>*row 7:* `"money for that, not a cent."` |
| H | rows 9–10 × cols 4–31 | blue | white | no | no | left | `"Ask {power} for a loan?"` |
| X | rows 13–15 × cols 14–17 | blue | white | no | no | left | icon `coffer` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white.
- **States:** H shows two lines (both loans available), one, or none. {item}: § Placeholders.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 7 s.
- **Sound:** `cash-short-raspberry`.
- **Screen-reader text** (polite): State treasury. {item}. The vaults echo. There is no money for that, not a cent. (Each hint: Ask Moscow for a loan? Ask Washington for a loan?)

### must-refuse

- **Wireframe:** WIREFRAMES.md § must-refuse (GDD #16; engine kind: mustRefuse)
- **Colour family:** Audience · **Border:** magenta · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | magenta | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | magenta | no | no | left | `"AUDIENCE HALL"` |
| D | rows 3–8 × cols 13–18 | yellow | black | no | no | left | icon `door-shut` |
| S | rows 10–13 × cols 1–30 | black | red | yes | no | centre | *row 11:* `"The treasury cannot stretch"`<br>*row 12:* `"that far. The answer is no."` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: magenta paper; row 0 × cols 19–31: letterhead band: magenta paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 5 s.
- **Sound:** `refuse-thud`.
- **Screen-reader text** (polite): Audience hall. The treasury cannot stretch that far. The answer is no.

### menu

- **Wireframe:** WIREFRAMES.md § menu (GDD #17; engine kind: menu)
- **Colour family:** Cabinet · **Border:** blue · **Page (CLS):** black ink on cyan paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | white | blue | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | white | blue | no | no | left | `"THE DIRECTORATE"` |
| T | row 3 × cols 0–31 | black | cyan | no | no | centre | `"Your decision for month {month}"` |
| N | rows 6–14 × cols 1–3 | white | black | no | no | left | digits 1–5 |
| S | rows 6–14 × cols 5–31 | black | cyan | no | no | left | *row 6:* `"Reward a single group"`<br>*row 8:* `"Gifts for the whole nation"`<br>*row 10:* `"Look after number one"`<br>*row 12:* `"Find money, somehow"`<br>*row 14:* `"Make a group stronger"` |
| O | row 17 × cols 0–31 | black | cyan | no | no | centre | `"Any other key: skip this month"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS 1-5, OR ANY OTHER KEY"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: blue paper; row 0 × cols 19–31: letterhead band: blue paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 4 × cols 4–27: underline: 1-pixel line on pixel row 1, black.
- **States:** All five sections always show, even when one is used up (pressing it leads to `section-used`).
- **Input:** 1–5 open that section (or `section-used`). Any other key except M: no decision this month (to `report-offer`). **Keypad offers:** [1] [2] [3] [4] [5] send the digits · [NO DECISION] sends a neutral key.
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): The Directorate. Your decision for month {month}. 1, Reward a single group. 2, Gifts for the whole nation. 3, Look after number one. 4, Find money, somehow. 5, Make a group stronger. Any other key: skip this month.

### section

- **Wireframe:** WIREFRAMES.md § section (GDD #18; engine kind: section)
- **Colour family:** Cabinet · **Border:** blue · **Page (CLS):** black ink on cyan paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | white | blue | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | white | blue | no | no | left | `"THE DIRECTORATE"` |
| T | row 3 × cols 0–31 | black | cyan | no | no | centre | `"{n}. {section}"` |
| N | rows 6–16 × cols 1–3 | white | black | no | no | left | the option's fixed number within its section |
| O | rows 6–16 × cols 5–31 | black | cyan | no | no | left | decision labels (§ Decision labels) for the options not yet used |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"NUMBER: CHOOSE  OTHER: BACK"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: blue paper; row 0 × cols 19–31: letterhead band: blue paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 4 × cols 4–27: underline: 1-pixel line on pixel row 1, black.
- **States:** Options keep their position numbers: option k is on row 4 + 2k. A used option leaves its row empty (no box, no label) and the others do not move. Section 1 has 6 options (rows 6–16), section 2 has 3, section 3 has 4, section 4 has 3, section 5 has 3.
- **Input:** The number of a listed option chooses it. Any other key except M, including a used or unlisted number, goes back to `menu`. **Keypad offers:** One button per listed option, labelled with its number · [BACK] sends a neutral key.
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): The Directorate, section {n}: {section}. Then each listed option with its number: '1, Promote the army chief.' Press a number to choose, any other key to go back.

### section-used

- **Wireframe:** WIREFRAMES.md § section-used (GDD #19; engine kind: sectionUsed)
- **Colour family:** Cabinet · **Border:** blue · **Page (CLS):** black ink on cyan paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | white | blue | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | white | blue | no | no | left | `"THE DIRECTORATE"` |
| T | row 3 × cols 0–31 | black | cyan | no | no | centre | `"{n}. {section}"` |
| U | rows 8–11 × cols 1–30 | black | red | yes | no | centre | *row 9:* `"This section is all used up."`<br>*row 10:* `"Your past self was thorough."` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: blue paper; row 0 × cols 19–31: letterhead band: blue paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 4 × cols 4–27: underline.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 3 s.
- **Sound:** None.
- **Screen-reader text** (polite): Section {n}: {section}. This section is all used up. Your past self was thorough.

### swiss

- **Wireframe:** WIREFRAMES.md § swiss (GDD #20; engine kind: swiss)
- **Colour family:** Ledger · **Border:** green · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"OFFSHORE DESK"` |
| M | rows 3–5 × cols 4–30 | blue | white | no | no | left | *row 3, both:* `"Treasury was {before}"`<br>*moved row 4:* `"Slipped away: {amount}"`<br>*moved row 5:* `"Nobody saw a thing."`<br>*nothing row 4:* `"Not a dollar to spare."`<br>*nothing row 5:* `"The briefcase stays empty."` |
| C | rows 7–8 × cols 15–16 | blue | white | no | no | left | icon `briefcase` |
| B | rows 12–15 × cols 4–30 | blue | white | no | no | left | rows 12–13: the treasury balance lines (credit or debt variant); row 14: monthly costs; row 15: the Swiss line (it is above 0 whenever money moved) |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | *after 2 s:* `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white; row 10 × cols 4–30: double rule: pixel rows 2 and 4, blue.
- **States:** First 2 s: M and C only. Then B and the footer appear together.
- **Input:** No key is read for the first 2 s; then any key except M continues. **Keypad offers:** None for 2 s, then [NEXT].
- **Timing:** 2 s, then waits for a key.
- **Sound:** Money moved: `swiss-whistle`. Nothing moved: none.
- **Screen-reader text** (polite): Offshore desk. Treasury was {before}. Slipped away: {amount}. Nobody saw a thing. (Or: Not a dollar to spare. The briefcase stays empty.) After 2 s, the treasury lines as on the treasury screen, then: Press any key.

### loan-wait

- **Wireframe:** WIREFRAMES.md § loan-wait (GDD #21; engine kind: loanWait)
- **Colour family:** Ledger · **Border:** green · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"FOREIGN MINISTRY"` |
| E | rows 5–7 × cols 14–17 | blue | white | no | no | left | icon `envelope` |
| W | rows 10–11 × cols 4–30 | blue | white | no | no | centre | *row 10:* `"Your letter to {power}"`<br>*row 11:* `"is being considered."` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 1 s.
- **Sound:** `loan-typewriter`.
- **Screen-reader text** (polite): Foreign Ministry. Your letter to Moscow (or Washington) is being considered.

### loan-result

- **Wireframe:** WIREFRAMES.md § loan-result (GDD #22; engine kind: loanResult (early / no more / refused / granted))
- **Colour family:** Ledger · **Border:** green · **Page (CLS):** blue ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | black | green | no | no | left | icon `seal` |
| L | row 0 × cols 3–18 | black | green | no | no | left | `"FOREIGN MINISTRY"` |
| E | rows 3–5 × cols 14–17 | blue | white | no | no | left | icon `envelope` |
| R | rows 8–12 × cols 1–30 | black | red | yes | no | centre | *early L1:* `"{Power} says: too soon."`<br>*early L2:* `"Come back when your regime"`<br>*early L3:* `"has lasted a little longer."`<br>*no more L1:* `"{Power}: one loan only."`<br>*no more L2:* `"You have had yours."`<br>*no more L3:* `"Final answer."`<br>*refused, East L1:* `"With fraternal regret, the"`<br>*refused, East L2:* `"Central Committee finds no"`<br>*refused, East L3:* `"spare roubles. Next plan?"`<br>*refused, West L1:* `"Congress has passed an"`<br>*refused, West L2:* `"amendment forbidding it."`<br>*refused, West L3:* `"Have a nice day."`<br>*granted L1:* `"{Power} sighs: fine."`<br>*granted L2:* `"{amount} is on its way."`<br>*granted L3:* `"It will not forget this."` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: green paper; row 0 × cols 19–31: letterhead band: green paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; rows 2–20 × col 2: red margin line: a 1-pixel vertical line at pixel x = 20 (col 2), red ink on white.
- **States:** Granted: box black ink on BRIGHT green paper. Every other result: black ink on BRIGHT red paper. The words say the outcome either way.
- **Input:** Any key except M continues to `treasury`. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** Granted: `loan-yes`. Otherwise: `loan-no`.
- **Screen-reader text** (polite): Foreign Ministry. Then the three lines of the reply. Press any key.

### news-alert

- **Wireframe:** WIREFRAMES.md § news-alert (GDD #23; engine kind: newsAlert)
- **Colour family:** Press · **Border:** white · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| F | rows 4–5 × cols 15–16 | red | black | yes | yes | left | icon `lamp` |
| A | rows 9–12 × cols 0–31 | black | white | no | no | left | *row 10:* `"STOP PRESS! STOP PRESS!"`<br>*row 11:* `"NEWS IS COMING DOWN THE WIRE"` |

- **Decoration (`#`):** row 9 × cols 0–31: (inside A) sprocket holes: 2×2-pixel dots on pixel rows 3–4 every 8 pixels, black.
- **States:** The tape text types itself: one character every 60 ms from the start of row 10, then row 11 (about 3.1 s for both lines); it then stays until the 6 s are up.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 6 s.
- **Sound:** `news-teleprinter`.
- **Screen-reader text** (assertive): Assertive: Stop press! News is coming down the wire.

### news-headline

- **Wireframe:** WIREFRAMES.md § news-headline (GDD #24; engine kind: newsHeadline)
- **Colour family:** Press · **Border:** white · **Page (CLS):** black ink on white paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| M | rows 0–1 × cols 0–31 | white | black | no | no | centre | *rows 0–1:* `"LA PRENSA"` (double size) |
| H | rows 5–7 × cols 1–30 | black | white | no | no | centre | headline N1–N6 (§ Headlines) |

- **Decoration (`#`):** row 2 × cols 0–31: heavy rule: pixel rows 1–3, black; rows 9–19 × cols 1–14: left column of 'print': 1-pixel lines on pixel row 3 of each row; lengths in the art bible; rows 9–19 × cols 17–30: right column of 'print', same.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 2 s.
- **Sound:** None.
- **Screen-reader text** (polite): La Prensa. Then the headline, as a sentence.

### assassin-attempt

- **Wireframe:** WIREFRAMES.md § assassin-attempt (GDD #25; engine kind: assassinAttempt)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| X | rows 4–6 × cols 14–16 | red | black | yes | yes | left | icon `reticle` |
| A | rows 10–11 × cols 0–31 | white | black | no | no | centre | *row 10:* `"CRACK! An assassin, paid by"`<br>*row 11:* `"the {faction}, takes aim!"` |
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `assassin-shot` (1.6 s).
- **Sound:** `assassin-shot`.
- **Screen-reader text** (assertive): Assertive: Crack! An assassin, paid by the Army, takes aim!

### assassin-result

- **Wireframe:** WIREFRAMES.md § assassin-result (GDD #26; engine kind: assassinResult (killed / survived))
- **Colour family:** Alarm · **Border:** black / red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| R | rows 4–6 × cols 15–16 | yellow | black | yes | no | left | icon `rosette` |
| T | rows 10–11 × cols 0–31 | white | black | no | no | centre | *killed L1:* `"President Ortiga is dead."`<br>*killed L2:* `"The palace falls silent."`<br>*survived L1:* `"Missed! The bullet bounced off"`<br>*survived L2:* `"a medal. Ortiga lives on!"` |
- **States:** Killed: border black, no icon. Survived: border red, rosette shown.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as its sound: `assassin-dead` 2.5 s, `assassin-miss` 2.0 s.
- **Sound:** Killed: `assassin-dead`. Survived: `assassin-miss`.
- **Screen-reader text** (assertive): Assertive: President Ortiga is dead. The palace falls silent. (Or: Missed! The bullet bounced off a medal. Ortiga lives on!)

### war-threat

- **Wireframe:** WIREFRAMES.md § war-threat (GDD #27; engine kind: warThreat)
- **Colour family:** War · **Border:** green · **Page (CLS):** green ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| B | rows 3–4 × cols 14–17 | yellow | black | no | no | left | icon `bugle` |
| W | rows 8–11 × cols 0–31 | green | black | no | no | centre | *row 8:* `"{neighbour} threatens war!"`<br>*row 9:* `"Fear unites the nation."`<br>*row 10:* `"Army, Peasants, Samosas and"`<br>*row 11:* `"State Security: popularity +1."` |
- **States:** Row 8 in BRIGHT green.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `war-drums` (3.5 s).
- **Sound:** `war-drums`.
- **Screen-reader text** (assertive): Assertive: Honduras threatens war! Fear unites the nation. Army, Peasants, Samosas and State Security: popularity plus 1.

### invasion

- **Wireframe:** WIREFRAMES.md § invasion (GDD #28; engine kind: invasion)
- **Colour family:** War · **Border:** red · **Page (CLS):** green ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| T | row 2 × cols 0–31 | red | black | yes | no | centre | `"War! {neighbour} invades!"` |
| G | rows 4–5 × cols 14–17 | green | black | no | no | left | icon `fieldgun` |
| U | rows 8–11 × cols 1–14 | green | black | no | no | centre | *row 8:* `"OUR FORCES"`<br>*rows 10–11:* `"{ours}"` (double size) |
| V | rows 8–11 × cols 17–30 | green | black | no | no | centre | *row 8:* `"THEIR FORCES"`<br>*rows 10–11:* `"{theirs}"` (double size) |
| B | row 14 × cols 0–31 | white | black | no | no | centre | `"The guns begin to roar..."` |

- **Decoration (`#`):** rows 8–11 × cols 15–16: a 2-pixel vertical divider at pixel x = 127–128, green.
- **States:** Both totals in BRIGHT green.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `war-short` (4 s).
- **Sound:** `war-short`.
- **Screen-reader text** (assertive): Assertive: War! Honduras invades! Our forces {ours}. Their forces {theirs}. The guns begin to roar.

### war-result

- **Wireframe:** WIREFRAMES.md § war-result (GDD #29; engine kind: warResult (won / lost))
- **Colour family:** War · **Border:** green / red · **Page (CLS):** green ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| I | rows 3–4 × cols 14–17 | yellow | black | no | no | left | icon `bugle` |
| S | rows 8–11 × cols 1–30 | black | green | yes | no | centre | *won L1:* `"{neighbour} is beaten back!"`<br>*won L2:* `"Its army is no more."`<br>*lost L1:* `"{neighbour} wins the war."`<br>*lost L2:* `"The capital has fallen."` |
- **States:** Won: border green, box black on BRIGHT green, bugle shown. Lost: border red, box black on BRIGHT red, no icon.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as its sound (2.5 s).
- **Sound:** Won: `war-won`. Lost: `war-lost`.
- **Screen-reader text** (assertive): Assertive: Honduras is beaten back! Its army is no more. (Or: Honduras wins the war. The capital has fallen.)

### heli-escape

- **Wireframe:** WIREFRAMES.md § heli-escape (GDD #30; engine kind: heliEscape)
- **Colour family:** Flight · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| H | rows 4–10 × cols 18–21 | white | blue | no | no | left | icon `helicopter` |
| T | rows 15–17 × cols 0–31 | white | blue | no | no | centre | *row 15:* `"Up, up and away! Ortiga leaves"`<br>*row 16:* `"by helicopter for Miami, with"`<br>*row 17:* `"the Swiss bank details."` |

- **Decoration (`#`):** rows 11–12 × cols 12–27: the palace roof: black paper; a 1-pixel white landing-pad outline from pixel (136, 90) to (183, 93), under the helicopter; row 13 × cols 0–31: night ground: black paper.
- **States:** Six positions: rows 9–10 at 0 s, 8–9 at 0.5 s, 7–8 at 1.0 s, 6–7 at 1.5 s, 5–6 at 2.0 s, 4–5 at 2.5 s, held until the screen ends at 3 s. Each step restores the sky (blue paper, no ink) in the cells it leaves.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `rotor` (3 s).
- **Sound:** `rotor`.
- **Screen-reader text** (polite): A helicopter lifts off the palace roof. Up, up and away! Ortiga leaves by helicopter for Miami, with the Swiss bank details.

### execution

- **Wireframe:** WIREFRAMES.md § execution (GDD #31; engine kind: execution (heading: helicopter failed / neighbour won))
- **Colour family:** Alarm · **Border:** black · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| H | row 4 × cols 0–31 | red | black | yes | no | centre | *helicopter failed:* `"The helicopter will not start."`<br>*neighbour won:* `"{neighbour} takes the palace."` |
| E | rows 9–11 × cols 0–31 | white | black | no | no | centre | *row 9:* `"Condemned as a traitor"`<br>*row 10:* `"by a court of one afternoon."`<br>*row 11:* `"Shot at dawn."` |

- **Decoration (`#`):** row 6 × cols 8–23: thin rule: 1-pixel line on pixel row 4, white.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as its sound: 4.5 s with the helicopter heading (`sputter` then `volley`), 3 s otherwise (`volley`).
- **Sound:** Helicopter heading: `sputter`, then `volley`. Neighbour heading: `volley`.
- **Screen-reader text** (assertive): Assertive: The helicopter will not start. (Or: Honduras takes the palace.) Condemned as a traitor by a court of one afternoon. Shot at dawn.

### revolt-alarm

- **Wireframe:** WIREFRAMES.md § revolt-alarm (GDD #32; engine kind: revoltAlarm)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| F | rows 3–4 × cols 15–16 | red | black | yes | yes | left | icon `lamp` |
| A | rows 7–8 × cols 0–31 | red | black | yes | no | centre | *rows 7–8:* `"REVOLUTION!"` (double size) |
| S | row 11 × cols 0–31 | white | black | no | no | centre | `"The streets are full of rebels."` |
| X | rows 14–18 × cols 14–16 | white | black | no | no | left | icon `statue` |
- **Input:** None. **Keypad offers:** None.
- **Timing:** 5 s.
- **Sound:** `revolt-siren`.
- **Screen-reader text** (assertive): Assertive: Revolution! The streets are full of rebels.

### escape-ask

- **Wireframe:** WIREFRAMES.md § escape-ask (GDD #33; engine kind: escapeAsk)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| D | rows 3–8 × cols 13–18 | yellow | black | no | no | left | icon `door-ajar` |
| Q | rows 11–12 × cols 0–31 | white | black | no | no | centre | *row 11:* `"The mob is at the gates."`<br>*row 12:* `"Slip away while you still can?"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"Y = YES   ANY OTHER KEY = NO"` |
- **Input:** Y or y: escape. Any other key except M: stay and fight (to `help-list`). **Keypad offers:** [YES] sends y · [NO] sends n.
- **Timing:** Waits for a key.
- **Sound:** None (the siren has ended).
- **Screen-reader text** (polite): The mob is at the gates. Slip away while you still can? Press Y for yes, any other key for no.

### help-list

- **Wireframe:** WIREFRAMES.md § help-list (GDD #34; engine kind: helpList)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| H | rows 2–4 × cols 0–31 | white | black | no | no | centre | *row 2:* `"{faction} have risen, joined by"`<br>*row 3:* `"{ally}. Their strength: {combined}"`<br>*row 4 (yellow):* `"Who will stand by you?"` |
| N | rows 7–17 × cols 9–11 | black | white | no | no | left | the group's number |
| G | rows 7–17 × cols 13–24 | white | black | no | no | left | `"{group}"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS 1-6 TO ASK FOR HELP"` |
- **States:** Only groups whose popularity is above the threshold get a box and a name; the other rows stay empty. This screen is never shown with nobody listed: in that case the engine emits `alone` instead (RULES §13.4).
- **Input:** 1–6 only. A listed number: that group helps (to `strength`). An unlisted number: `joke`. Every other key, and a tap on the screen, is ignored. **Keypad offers:** [1] [2] [3] [4] [5] [6] (all six; an unlisted number is a legal, foolish choice).
- **Timing:** Waits for 1–6.
- **Sound:** None.
- **Screen-reader text** (assertive): The Army have risen, joined by the Contras. Their strength: 14. Who will stand by you? Then each listed group with its number: '2, Peasants.' Press 1 to 6 to ask for help.

### alone

- **Wireframe:** WIREFRAMES.md § alone (GDD #35; engine kind: alone)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| H | rows 2–3 × cols 0–31 | white | black | no | no | centre | *row 2:* `"{faction} have risen, joined by"`<br>*row 3:* `"{ally}. Their strength: {combined}"` |
| A | rows 9–11 × cols 0–31 | yellow | black | no | no | centre | *row 9:* `"Nobody will lift a finger."`<br>*row 10:* `"You face the rebels alone,"`<br>*row 11:* `"with only your bodyguard."` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |
- **States:** Shown instead of `help-list` when no group can be asked for help (RULES §13.4); there is no numbered list and no 1–6 prompt.
- **Input:** Any key except M: the fight goes ahead without a helper (to `strength`). **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** None.
- **Screen-reader text** (polite): Assertive: The Army have risen, joined by the Contras. Their strength: 14. Nobody will lift a finger. You face the rebels alone, with only your bodyguard. Press any key.

### joke

- **Wireframe:** WIREFRAMES.md § joke (GDD #36; engine kind: joke)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| J | rows 9–11 × cols 0–31 | white | black | no | no | centre | *row 9:* `"{group}? They despise you!"`<br>*row 10:* `"Even the guards are laughing."`<br>*row 11:* `"There is nothing for it: run!"` |
- **Input:** None. **Keypad offers:** None.
- **Timing:** 3 s.
- **Sound:** None.
- **Screen-reader text** (polite): The Contras? They despise you! Even the guards are laughing. There is nothing for it: run!

### strength

- **Wireframe:** WIREFRAMES.md § strength (GDD #37; engine kind: strength)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| S | rows 7–8 × cols 6–25 | white | black | no | no | left | *row 7:* `"Your bodyguard {pstr}"`<br>*row 8, helper:* `"{helper} {hstr}"`<br>*row 8, alone:* `"No helper 0"` |
| R | row 10 × cols 6–25 | red | black | yes | no | left | `"Rebels {rebels}"` |
| B | row 14 × cols 0–31 | yellow | black | no | no | centre | `"Who will blink first?"` |

- **Decoration (`#`):** row 9 × cols 6–25: rule: 1-pixel line on pixel row 4, white.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 5 s.
- **Sound:** `heartbeat`.
- **Screen-reader text** (polite): Your bodyguard {pstr}. {helper} {hstr} (or: no helper). Rebels {rebels}. Who will blink first?

### revolt-start

- **Wireframe:** WIREFRAMES.md § revolt-start (GDD #38; engine kind: revoltStart)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| X | rows 3–7 × cols 14–16 | white | black | no | no | left | icon `statue` |
| T | rows 11–12 × cols 0–31 | white | black | no | no | centre | *row 11:* `"The fighting has begun!"`<br>*row 12:* `"Shots ring out in the square."` |
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `skirmish` (2.5 s).
- **Sound:** `skirmish`.
- **Screen-reader text** (assertive): Assertive: The fighting has begun! Shots ring out in the square.

### overthrown

- **Wireframe:** WIREFRAMES.md § overthrown (GDD #39; engine kind: overthrown)
- **Colour family:** Alarm · **Border:** red · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| X | rows 4–6 × cols 13–17 | white | black | no | no | left | icon `statue-fallen` |
| T | rows 10–12 × cols 0–31 | white | black | no | no | centre | *row 10:* `"The palace has fallen."`<br>*row 11:* `"President Ortiga is dragged"`<br>*row 12:* `"out and shot. The statue too."` |
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `overthrown-drop` (2.5 s).
- **Sound:** `overthrown-drop`.
- **Screen-reader text** (assertive): Assertive: The palace has fallen. President Ortiga is dragged out and shot. The statue too.

### crushed

- **Wireframe:** WIREFRAMES.md § crushed (GDD #40; engine kind: crushed)
- **Colour family:** Alarm (victory) · **Border:** yellow · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| X | rows 3–7 × cols 14–16 | yellow | black | yes | no | left | icon `statue` |
| C | rows 10–11 × cols 0–31 | yellow | black | no | no | centre | *row 10:* `"The revolt is crushed!"`<br>*row 11:* `"Order, of a sort, returns."` |
| P | row 14 × cols 0–31 | white | black | no | no | centre | `"Punish the ringleaders?"` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"Y = YES   ANY OTHER KEY = NO"` |
- **Input:** Y or y punishes; any other key except M does not. Either way on to `report-offer`. **Keypad offers:** [YES] sends y · [NO] sends n.
- **Timing:** Waits for a key.
- **Sound:** `crushed-fanfare`.
- **Screen-reader text** (polite): The revolt is crushed! Order, of a sort, returns. Punish the ringleaders? Press Y for yes, any other key for no.

### heli-fail

- **Wireframe:** WIREFRAMES.md § heli-fail (GDD #41; engine kind: heliFail)
- **Colour family:** Flight · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| P | row 7 × col 17 | white | blue | no | no | left | icon `smoke` |
| H | rows 9–10 × cols 14–17 | white | blue | no | no | left | icon `helicopter` |
| T | rows 15–17 × cols 0–31 | white | blue | no | no | centre | *row 15:* `"The engine coughs twice and"`<br>*row 16:* `"dies. The pilot shrugs."`<br>*row 17:* `"It will have to be on foot."` |

- **Decoration (`#`):** rows 11–12 × cols 10–25: the palace roof: black paper; a 1-pixel white landing-pad outline from pixel (104, 90) to (151, 93), under the helicopter; row 13 × cols 0–31: night ground: black paper.
- **Input:** None. **Keypad offers:** None.
- **Timing:** 3 s.
- **Sound:** `sputter`.
- **Screen-reader text** (polite): The helicopter sits on the roof, smoking. The engine coughs twice and dies. The pilot shrugs. It will have to be on foot.

### mountains

- **Wireframe:** WIREFRAMES.md § mountains (GDD #42; engine kind: mountains)
- **Colour family:** Flight · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| O | rows 2–3 × cols 26–27 | white | blue | no | no | left | icon `moon` |
| W | rows 13–14 × cols 0–31 | white | black | no | no | left | icon `walker` |
| T | rows 17–19 × cols 0–31 | white | blue | no | no | centre | *row 17:* `"On foot, by night, over the"`<br>*row 18:* `"northern mountains towards"`<br>*row 19:* `"{neighbour}. Contra country."` |

- **Decoration (`#`):** rows 6–12 × cols 0–31: the northern mountains: a black silhouette below the ridge line in the art bible, on the sky paper.
- **States:** The walker starts at col 1 and moves one column right every 140 ms (28 steps, 3.92 s).
- **Input:** None. **Keypad offers:** None.
- **Timing:** 4 s.
- **Sound:** `footsteps`.
- **Screen-reader text** (polite): A small figure walks over the mountains by moonlight. On foot, by night, over the northern mountains towards Honduras. Contra country.

### caught

- **Wireframe:** WIREFRAMES.md § caught (GDD #43; engine kind: caught)
- **Colour family:** Flight · **Border:** red · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| O | rows 2–3 × cols 26–27 | white | blue | no | no | left | icon `moon` |
| T | rows 17–19 × cols 0–31 | white | blue | no | no | centre | *row 17:* `"Caught! The Contras cheer,"`<br>*row 18:* `"dance a little, and settle the"`<br>*row 19:* `"matter on the spot."` |

- **Decoration (`#`):** rows 6–12 × cols 0–31: the northern mountains: a black silhouette below the ridge line in the art bible, on the sky paper; rows 13–14 × cols 0–31: the path: black ground, empty.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `caught-jig` (3 s).
- **Sound:** `caught-jig`.
- **Screen-reader text** (assertive): Assertive: Caught! The Contras cheer, dance a little, and settle the matter on the spot.

### escaped

- **Wireframe:** WIREFRAMES.md § escaped (GDD #44; engine kind: escaped)
- **Colour family:** Flight (dawn) · **Border:** yellow · **Page (CLS):** black ink on yellow paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| W | rows 13–14 × cols 26–29 | black | yellow | no | no | left | icon `walker` |
| T | rows 17–19 × cols 0–31 | black | yellow | no | no | centre | *row 17:* `"They missed! By dawn the"`<br>*row 18:* `"President is safe across the"`<br>*row 19:* `"border in {neighbour}."` |

- **Decoration (`#`):** rows 6–12 × cols 0–31: the northern mountains, same ridge, black on yellow (dawn); rows 13–14 × cols 0–25: the path: yellow paper, no ink.
- **Input:** None. **Keypad offers:** None.
- **Timing:** As long as `escaped-whistle` (2.5 s).
- **Sound:** `escaped-whistle`.
- **Screen-reader text** (polite): Dawn over the mountains. They missed! By dawn the President is safe across the border in Honduras.

### funeral

- **Wireframe:** WIREFRAMES.md § funeral (GDD #45; engine kind: funeral)
- **Colour family:** Mourning · **Border:** black · **Page (CLS):** white ink on black paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| W | rows 2–5 × cols 14–17 | green | black | no | no | left | icon `wreath` |
| F | rows 8–11 × cols 0–31 | white | black | no | no | centre | *row 8:* `"The nation mourns, officially."`<br>*row 9:* `"Flags at half mast, by order."`<br>*row 10:* `"A wreath from a grateful state."`<br>*row 11:* `"Months in power: {months}."` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |
- **Input:** Any key except M continues to `rating`. Keys are read from the moment the screen appears; the tune keeps playing to its end unless the next screen's sound replaces it. **Keypad offers:** [NEXT].
- **Timing:** Waits for a key.
- **Sound:** `funeral`.
- **Screen-reader text** (polite): A laurel wreath. The nation mourns, officially. Flags at half mast, by order. A wreath from a grateful state. Months in power: {months}. Press any key.

### rating

- **Wireframe:** WIREFRAMES.md § rating (GDD #46; engine kind: rating)
- **Colour family:** Palace · **Border:** blue · **Page (CLS):** white ink on blue paper, BRIGHT off

| Region | Cells | Ink | Paper | BRIGHT | FLASH | Align | Content (final text, or icon id) |
|---|---|---|---|---|---|---|---|
| s | row 0 × col 1 | blue | yellow | yes | no | left | icon `seal` |
| L | row 0 × cols 3–18 | blue | yellow | yes | no | left | `"FINAL RECKONING"` |
| R | rows 4–7 × cols 2–29 | white | blue | no | no | left | *row 4:* `"Popularity, all groups {pop}"`<br>*row 5:* `"Months ruled {months} x 3 {points}"`<br>*row 6, alive:* `"Survival bonus {points}"`<br>*row 7, alive:* `"Swiss {swiss}/10 {points}"` |
| T | rows 10–11 × cols 2–29 | yellow | blue | no | no | centre | *rows 10–11:* `"TOTAL {total}"` (double size) |
| B | rows 14–15 × cols 0–31 | white | blue | no | no | centre | *row 14:* `"Best so far: {best}"`<br>*row 15, new best:* `"A new record! Statues ordered."` |
| M | rows 17–19 × cols 15–16 | yellow | blue | yes | no | left | icon `rosette` |
| K | rows 21–23 × cols 0–31 | black | white | no | no | centre | `"PRESS A KEY OR TAP TO GO ON"` |

- **Decoration (`#`):** row 0 × col 0 and row 0 × col 2: letterhead band: yellow paper; row 0 × cols 19–31: letterhead band: yellow paper (cols 20–31 also carry the sound overlay when shown); row 1 × cols 0–31: double rule: pixel rows 2 and 5 of row 1, all 256 pixels, in the page ink; row 8 × cols 2–29: sum rule: pixel rows 2 and 4, white.
- **States:** Lines appear one at a time, 300 ms apart, each with a tally tick: row 4, row 5, (alive: rows 6, 7), then the total, then row 14, then (new best) row 15 and the rosette. Dead: rows 6–7 stay empty. 'New best' means this total is above the stored best (or there was none). The footer appears with the last line; keys are read only from then.
- **Input:** Any key except M continues to the final `report`. **Keypad offers:** [NEXT] (after the last line).
- **Timing:** Waits for a key once all lines are shown (at most 2.4 s after the screen appears).
- **Sound:** `rating-tally` per line; `new-best` after row 15 when there is a new best.
- **Screen-reader text** (polite): Final reckoning. Popularity, all groups: {pop}. Months ruled {months}, times 3: {points}. (Alive: Survival bonus 10. Swiss {swiss}, divided by 10: {points}.) Total {total}. Best so far {best}. (A new record! Statues ordered.) Press any key.

## Data texts (RULES §17)

The topic column restates RULES §17 so the reviewer can see each text covers it; it is not shown. Line 1 and line 2 are shown on consecutive rows, each centred in its region (30 columns wide on `audience`, `advice` and `dialog`).

### Requests (R1–R24)

Shown on `audience` (petition card), `advice` and `dialog`. The faction is announced separately, so each text is in the faction's own voice: the Army barks, the Peasants petition, and the Samosa family expects, as old money does. `{neighbour}` is filled with `Honduras`. The *anchor* column names the bit of Nicaraguan history each text caricatures (from the research brief); it is not shown, and the requester, effects and money are unchanged from RULES §17.

| id | From | Topic (not shown) | Anchor (not shown) | Line 1 (≤ 30) | Line 2 (≤ 30) |
|---|---|---|---|---|---|
| R1 | Army | make military service compulsory | the 1983 Patriotic Military Service and the mothers' protests | `"Patriotic Military Service for"` | `"every boy. Mothers will cope."` |
| R2 | Army | seize farmland as army training grounds | estates acquired by offers owners dared not refuse | `"We need a firing range. That"` | `"coffee farm looks suitable."` |
| R3 | Army | a campaign against rebel camps at home | the hunts in the northern mountains, Las Segovias | `"Contras in the Segovias again."` | `"Fund a sweep of the hills!"` |
| R4 | Army | a cross-border raid on rebel camps in the Neighbour | Operation Danto (1988) into the Las Vegas salient | `"The Contras hide in {neighbour}."` | `"Let us cross over and raid!"` |
| R5 | Army | dismiss the head of the secret police | the army's rivalry with the security apparatus | `"State Security keeps files on"` | `"our generals. Sack its chief!"` |
| R6 | Army | send home the East's military advisers | the Cuban advisers: 200 admitted, about 3,000 estimated | `"Havana says 200 advisers. We"` | `"count 3,000. Send them home!"` |
| R7 | Army | a pay rise for the soldiers | the National Guard's vice economy of gambling dens | `"Raise our pay, and the boys"` | `"may even close the casinos."` |
| R8 | Army | new weapons and ammunition | the Mi-24 deliveries and the 1984 MiG scare | `"Moscow sent helicopters. Now"` | `"we want the MiGs. And bullets."` |
| R9 | Peasants | end forced recruitment into the army | the press gangs of the 1980s draft, repealed in 1990 | `"Press gangs take our sons from"` | `"the fields. Kindly stop them."` |
| R10 | Peasants | a higher legal minimum wage | cotton pickers on the Pacific plain, coffee pickers in Matagalpa | `"We pick the cotton and coffee"` | `"for pennies. A fairer wage?"` |
| R11 | Peasants | curb the secret police | the Sandinista Defence Committees and their ration cards | `"The block wardens count our"` | `"beans. Please call them off."` |
| R12 | Peasants | bar migrant labour from the Neighbour | the shared Gulf of Fonseca (the brief's suggested re-flavour; the migrant-labour anchor is unverified) | `"Boats from {neighbour} fish our"` | `"share of the gulf. Stop them."` |
| R13 | Peasants | free schooling for every child | the 1980 Literacy Crusade and its brigadistas | `"Send the literacy brigades"` | `"again. Every child, a reader!"` |
| R14 | Peasants | the right to form trade unions | unions suppressed under the dynasty, watched after it | `"Let the farm workers' union"` | `"meet with no informer present."` |
| R15 | Peasants | release their jailed leader | prisoner releases of 1978; written earnestly, with no joke | `"Our union leader sits in jail"` | `"for speaking up. Release them!"` |
| R16 | Peasants | a state lottery | the Guard's illegal gambling dens (garitos) | `"The Guard ran the numbers. Let"` | `"the people run a lottery now!"` |
| R17 | Samosas | keep the army off their estates | the Guard's looting after the 1972 earthquake | `"Soldiers keep 'requisitioning'"` | `"our cattle. Keep them out."` |
| R18 | Samosas | a lower legal minimum wage | the cotton growers' pesticide bills | `"Pesticides cost a fortune. So"` | `"wages must fall. Naturally."` |
| R19 | Samosas | seize companies owned by the West | Standard Fruit; the family's stake in the airline it shared with Pan Am | `"Seize the American fruit firm"` | `"and hand it to the family."` |
| R20 | Samosas | a tariff on goods from the Neighbour | the 1999 35% tariff on Honduran goods over the sea treaty | `"A 35% tariff on {neighbour}!"` | `"Sovereignty, and our profits."` |
| R21 | Samosas | a smaller secret police budget | business leaders' dislike of informers in the factories | `"State Security has informers"` | `"in our mills. Cut its budget."` |
| R22 | Samosas | lower taxes on land | the dynasty's quarter of the farmland | `"Land tax hurts the biggest"` | `"landowner most. That is us."` |
| R23 | Samosas | lend soldiers to the estates as farm labour | forced labour on the 19th-century coffee estates; the joke is on the family | `"Lend us soldiers to pick the"` | `"coffee. Unpaid, as before."` |
| R24 | Samosas | a large irrigation scheme | the 2013 canal concession, never dug, revoked in 2024 | `"Dig us a grand canal. It can"` | `"water our estates on the way."` |

### Decision labels (D1–D19)

Shown on `section` after the option's number box, and as `{item}` on `cash-short`. ≤ 27 columns.

| id | Section | Option no. | Topic (not shown) | Anchor (not shown) | Label |
|---|---|---|---|---|---|
| D1 | 1 | 1 | promote the army commander to deputy head of state | the Guard chief who seized power in 1936 | `"Make the general my deputy"` |
| D2 | 1 | 2 | free health clinics for workers | Cuban doctors in the 1980s | `"Cuban doctors for clinics"` |
| D3 | 1 | 3 | regional authority for the landowners | the power-sharing pacts of 1950, 1971 and 1999 | `"A pact with the Samosas"` |
| D4 | 1 | 4 | sell Western-made weapons to the Neighbour | Iran-Contra's arms-for-cash circuit | `"Resell arms to {neighbour}"` |
| D5 | 1 | 5 | sell mining concessions to Western companies | gold, today's top export | `"Gold mines for Washington"` |
| D6 | 1 | 6 | lease a naval base to the East | the 1914 canal treaty's naval-base option, reversed; Russian port decrees | `"A naval base for Moscow"` |
| D7 | 2 | 1 | a general tax cut | pre-election largesse in every era | `"Tax cuts all round"` |
| D8 | 2 | 2 | a large publicity campaign | the giant metal 'Trees of Life' on Managua's boulevards | `"Giant metal trees"` |
| D9 | 2 | 3 | strip the secret police of all its powers | the 1990 dissolution of the security service | `"Disband State Security"` |
| D10 | 3 | 1 | give the secret police sweeping new powers | the 2025 'voluntary police' | `"Volunteer masked police"` |
| D11 | 3 | 2 | enlarge the President's bodyguard (repeatable) | the family's elite infantry school (EEBI) | `"More palace guards"` |
| D12 | 3 | 3 | buy a helicopter for escaping | the July 1979 flight to Miami | `"A helicopter, fuelled"` |
| D13 | 3 | 4 | move half the treasury to a Swiss account (repeatable) | the Miami mansion held through an island company | `"Half to my Swiss account"` |
| D14 | 4 | 1 | ask the East for a loan (special) | Soviet-bloc aid | `"Ask Moscow for a loan"` |
| D15 | 4 | 2 | ask the West for aid (special) | earthquake and post-1990 aid; refusal in the style of the Boland Amendment | `"Ask Washington for aid"` |
| D16 | 4 | 3 | seize businesses owned by the Neighbour | the tariff war, escalated; the confiscation habit | `"Seize {neighbour}'s firms"` |
| D17 | 5 | 1 | heavy guns for the army | Soviet T-55 tanks and BM-21 rocket launchers | `"Soviet tanks for the army"` |
| D18 | 5 | 2 | freedom of movement for the peasants | lifting the war-zone controls in the northern mountains | `"Open the northern roads"` |
| D19 | 5 | 3 | a private militia for the landowners | estate guards and the ex-Guard origins of the Contras | `"A Samosa family militia"` |

### Decision texts (16: D1–D12, D16–D19)

Shown on `advice` and `dialog`, in President Ortiga's own grand voice. D13, D14 and D15 have no text: they never show advice or a dialog (RULES §9.2). D11's text says it can be repeated.

| id | Line 1 (≤ 30) | Line 2 (≤ 30) |
|---|---|---|
| D1 | `"The army chief shall be my"` | `"deputy. That never ends badly."` |
| D2 | `"Havana's doctors will staff"` | `"free clinics for the workers."` |
| D3 | `"The Samosas may rule their"` | `"provinces; we split the rest."` |
| D4 | `"Sell Washington's gifts to"` | `"{neighbour}, with a mark-up."` |
| D5 | `"Western miners may dig our"` | `"gold. We keep the receipts."` |
| D6 | `"Moscow may moor its fleet in"` | `"the gulf. For a modest rent."` |
| D7 | `"Taxes cut for everyone, just"` | `"before the vote. Coincidence."` |
| D8 | `"Plant giant metal trees down"` | `"every boulevard. Very modern."` |
| D9 | `"State Security is dissolved."` | `"Its files go to the bonfire."` |
| D10 | `"Masked volunteers join State"` | `"Security. What could go wrong?"` |
| D11 | `"Train more guards, loyal to me"` | `"alone. (Can be repeated.)"` |
| D12 | `"A helicopter on the roof, kept"` | `"fuelled. Miami is not far."` |
| D16 | `"Every Honduran business here"` | `"now belongs to the state."` |
| D17 | `"T-55 tanks and rocket trucks"` | `"for the army, gift-wrapped."` |
| D18 | `"Peasants may travel the north"` | `"freely. So may the Contras."` |
| D19 | `"The Samosas may arm their"` | `"estate guards. What a relief."` |

### Headlines (N1–N6)

Shown on `news-headline`, rows 5–7, centred, in capitals, under the La Prensa masthead. Placeholders are filled and then **upper-cased**: `{crop}` becomes `COFFEE`, `{neighbour}` becomes `HONDURAS`.

| id | Topic (not shown) | Anchor (not shown) | Row 5 (≤ 30) | Row 6 (≤ 30) | Row 7 (≤ 30) |
|---|---|---|---|---|---|
| N1 | the President mislays the secret police's files | the 1986 cargo plane whose papers exposed a covert network | `"STATE SECURITY FILES FOUND"` | `"IN A CRASHED CARGO PLANE"` | `"CONTRAS READ THEM FIRST"` |
| N2 | a foreign revolutionary state arms and trains the rebels | Iran-Contra: a revolutionary state's arms money reaching the rebels | `"IRAN ARMS-DEAL CASH FLOWS"` | `"TO THE CONTRAS. WASHINGTON"` | `"'SHOCKED, SIMPLY SHOCKED'"` |
| N3 | an explosion wrecks an army barracks | a barracks, no casualty count (the brief's advice) | `"BLAST FLATTENS ARMY BARRACKS"` | `"SOLDIERS SLEEP IN THE PARK"` | `"POLICE: 'NOT US, HONEST'"` |
| N4 | the price of the country's export crop collapses | coffee, the export crop for a century | `"{crop} PRICE CRASHES"` | `"SAMOSAS AND {neighbour}"` | `"COUNT THE COST"` |
| N5 | an earthquake strikes the Neighbour | the 1972 earthquake, inverted; the family's paving-stone monopoly | `"EARTHQUAKE HITS {neighbour}"` | `"SAMOSAS SELL THEM PAVING"` | `"STONES AT TRIPLE PRICE"` |
| N6 | an epidemic among the peasants | pesticide poisoning in the cotton belt; the joke is on the estates | `"CROP-SPRAY SICKNESS SWEEPS"` | `"THE COTTON BELT; CLINICS FULL"` | `"ESTATES DENY EVERYTHING"` |

## How to play (the `howto` pages)

Six pages, shown on `howto` rows 3–18 at cols 1–30, one line per row, left-aligned, white on blue; the first line of each page is yellow. Empty lines are blank rows. Page numbers on row 19: `"PAGE {page} OF {pages}"` with `{pages}` = 6. Each page covers only what RULES says the player can see (the threshold's values are never given).

**Page 1**

| Row | Text |
|---|---|
| 3 | `"You are President Ortiga of"` |
| 4 | `"Nicaragua. The Samosas ruled"` |
| 5 | `"before you; they left by air."` |
| 6 | *(blank)* |
| 7 | `"Every month a group of the"` |
| 8 | `"nation wants something, and"` |
| 9 | `"every refusal makes enemies."` |
| 10 | *(blank)* |
| 11 | `"There is no winning. A reign"` |
| 12 | `"ends when you are killed or"` |
| 13 | `"when you flee the country."` |
| 14 | *(blank)* |
| 15 | `"Then you are scored: on how"` |
| 16 | `"popular you were, how long you"` |
| 17 | `"lasted and, if you got out"` |
| 18 | `"alive, what you took with you."` |

**Page 2**

| Row | Text |
|---|---|
| 3 | `"Eight groups watch you:"` |
| 4 | `"1 ARMY        5 HONDURAS"` |
| 5 | `"2 PEASANTS    6 SEC. POLICE"` |
| 6 | `"3 SAMOSAS     7 EAST"` |
| 7 | `"4 CONTRAS     8 WEST"` |
| 8 | `"EAST: Moscow and Havana."` |
| 9 | `"WEST: Washington and its CIA."` |
| 10 | `"SEC. POLICE: State Security."` |
| 11 | *(blank)* |
| 12 | `"POP. 0-9: how much they like"` |
| 13 | `"you. STR. 0-9: how strong they"` |
| 14 | `"are (EAST and WEST: none)."` |
| 15 | `"A group whose POP. sinks to a"` |
| 16 | `"secret line, which moves each"` |
| 17 | `"month, turns on you. CONTRAS"` |
| 18 | `"always do."` |

**Page 3**

| Row | Text |
|---|---|
| 3 | `"A month in the palace:"` |
| 4 | `"1 The treasury pays the"` |
| 5 | `"  monthly costs. In debt, the"` |
| 6 | `"  army, police and your guard"` |
| 7 | `"  lose heart instead."` |
| 8 | `"2 A group asks a favour. Ask"` |
| 9 | `"  your adviser, then grant it"` |
| 10 | `"  or refuse. Refusing costs"` |
| 11 | `"  what it would have gained."` |
| 12 | `"  Too poor? You must refuse."` |
| 13 | `"3 Assassins strike; Honduras"` |
| 14 | `"  may threaten or invade."` |
| 15 | `"4 You make one decision."` |
| 16 | `"5 News, perhaps a revolution."` |

**Page 4**

| Row | Text |
|---|---|
| 3 | `"Each month you may take one"` |
| 4 | `"decision from five sections,"` |
| 5 | `"or none at all."` |
| 6 | *(blank)* |
| 7 | `"Most can be taken only once."` |
| 8 | `"More guards and the Swiss"` |
| 9 | `"account can be used again."` |
| 10 | *(blank)* |
| 11 | `"Moscow and Washington each"` |
| 12 | `"lend once, if they like you"` |
| 13 | `"and you have ruled long"` |
| 14 | `"enough. Money sent to Swiss"` |
| 15 | `"banks is yours, if you live."` |
| 16 | *(blank)* |
| 17 | `"A helicopter may fly you out."` |
| 18 | `"It starts two times in three."` |

**Page 5**

| Row | Text |
|---|---|
| 3 | `"State Security sells its files"` |
| 4 | `"for $1,000, if it is loyal,"` |
| 5 | `"strong, and you can pay."` |
| 6 | *(blank)* |
| 7 | `"A file shows every group's"` |
| 8 | `"POP. and STR., and any plots:"` |
| 9 | `"RISE +n: plans to revolt with"` |
| 10 | `"group n. HIRE AN ASSASSIN:"` |
| 11 | `"plans to have you shot."` |
| 12 | *(blank)* |
| 13 | `"A revolt needs its two groups'"` |
| 14 | `"strengths to reach the figure"` |
| 15 | `"in the file. Loyal or strong"` |
| 16 | `"police foil most assassins."` |

**Page 6**

| Row | Text |
|---|---|
| 3 | `"When revolution comes, run or"` |
| 4 | `"fight. To fight, call on a"` |
| 5 | `"group that still likes you."` |
| 6 | `"Crush the revolt and you may"` |
| 7 | `"punish its leaders."` |
| 8 | *(blank)* |
| 9 | `"Run by helicopter, if you have"` |
| 10 | `"one, or on foot over the"` |
| 11 | `"mountains to Honduras. More"` |
| 12 | `"CONTRAS there, less chance."` |
| 13 | *(blank)* |
| 14 | `"SCORE: total popularity, plus"` |
| 15 | `"3 a month ruled. Alive? Plus"` |
| 16 | `"10, and 1 for every $10,000"` |
| 17 | `"in Switzerland."` |
| 18 | `"M turns sound on and off."` |

## Message index (GDD §8.1 → screen.region)

Every message in GDD §8.1 and §8.2, and where its final text is in this document.

| GDD id | Screen.region |
|---|---|
| `prompt-any` | footer (§ Global patterns) |
| `prompt-yes` | footer |
| `title-name` | title.T (logo) and its spoken name |
| `title-tagline` | title.G |
| `title-keys` | title.K |
| `howto-page` | howto.P (§ How to play), howto.N |
| `about-credit` | about.C |
| `about-remake` | about.M |
| `sound-state` | sound.O |
| `welcome-best` | welcome.W (best) |
| `welcome-first` | welcome.W (first) |
| `welcome-free` | welcome.V |
| `month` | month.H, month.N, month.S |
| `treasury-balance` | treasury.B (and swiss.B) |
| `treasury-costs` | treasury.C |
| `treasury-swiss` | treasury.W |
| `report-title` | report.T |
| `report-table` | report.H, report.G |
| `report-plot-revolt` | report.P (revolution) |
| `report-plot-assassin` | report.P (assassination) |
| `report-odds` | report.O |
| `offer-ask` | report-offer.Q (available) |
| `offer-none` | report-offer.Q (unavailable) |
| `offer-reason-pop / -str / -cash` | report-offer.R |
| `bankrupt` | bankrupt.S, bankrupt.B |
| `audience-from` | audience.F |
| `advice-ask` | advice-offer.A |
| `advice-line` | advice.A, advice.N |
| `dialog-from` | dialog.F |
| `dialog-once` | dialog.M (one-off) |
| `dialog-monthly` | dialog.M (monthly) |
| `dialog-free` | dialog.M (free) |
| `cash-short` | cash-short.I, cash-short.C |
| `cash-hint` | cash-short.H |
| `must-refuse` | must-refuse.S |
| `menu-title` | menu.T |
| `menu-section` | menu.S |
| `menu-none` | menu.O (and the menu footer) |
| `section-title` | section.T, section-used.T |
| `section-used` | section-used.U |
| `swiss-moved` | swiss.M (moved) |
| `swiss-nothing` | swiss.M (nothing) |
| `loan-wait` | loan-wait.W |
| `loan-early / -nomore / -refused-east / -refused-west / -granted` | loan-result.R |
| `news-alert` | news-alert.A |
| `assassin-attempt` | assassin-attempt.A |
| `assassin-killed / -survived` | assassin-result.T |
| `war-threat` | war-threat.W |
| `invasion` | invasion.T, .U, .V, .B |
| `war-won / war-lost` | war-result.S |
| `heli-escape` | heli-escape.T |
| `execution-heading` | execution.H |
| `execution` | execution.E |
| `revolt-alarm` | revolt-alarm.A, .S |
| `escape-ask` | escape-ask.Q |
| `help-rebels` | help-list.H, alone.H |
| `help-option` | help-list.G |
| `help-ask` | help-list.K |
| `alone` | alone.A |
| `joke` | joke.J |
| `strength` | strength.S, .R, .B |
| `revolt-start` | revolt-start.T |
| `overthrown` | overthrown.T |
| `crushed` | crushed.C |
| `punish-ask` | crushed.P |
| `heli-fail` | heli-fail.T |
| `mountains` | mountains.T |
| `caught` | caught.T |
| `escaped` | escaped.T |
| `funeral` | funeral.F |
| `rating-pop / -months / -alive` | rating.R |
| `rating-total` | rating.T |
| `rating-best` | rating.B |
| `request-text, decision-label, decision-text, headline` | § Data texts |

Texts added by this design that GDD §8.1 does not list:
- the 12 letterhead office names (§ The letterhead)
- the report's no-plots line
- the dialog's decision header `"By decree of the President"`
- the advice key line
- the column labels and captions on `report`, `invasion` and `rating`
- the month's ceremonial line
- the newspaper masthead (`LA PRENSA`, the real paper, named under GDD §4.1)

All are within 32 columns and checked like the rest.

## Responsive layouts

The template's display and input layers do the work; this section fixes what each layout shows.

| Layout | When | Screen | Keypad | Sound button |
|---|---|---|---|---|
| **Desktop** | A fine pointer that can hover (`(hover: hover) and (pointer: fine)`) | The 320×256 canvas (screen plus a 32-pixel border on every side), scaled by the largest whole number that fits, centred | Hidden; the keyboard is used | Under the screen |
| **Phone portrait** | Every other device, unless it is in landscape (next row) | Fits the width less a 16 px gutter each side; the template's fit uses the exact scale below 2× | Under the screen, centred, wrapping onto a second row when needed (the 6 help numbers fit one row at 44 px each) | Under the keypad |
| **Phone landscape** | `(orientation: landscape) and (max-height: 520px)` | Fits the height | Beside the screen, on the right, two buttons wide; buttons stack top to bottom in the order listed | Under the keypad |

Applying to every layout:
- The keypad never covers the screen.
- The border colour fills the canvas's border area only. The page around the canvas stays the template's dark grey (`#111`).
- Nothing is drawn outside the 32×24 grid except the border colour.

## Accessibility

- **Contrast.** Text uses only these ink/paper pairs, all at least 4.5:1 with the template's colour levels (0xD7 normal, 0xFF BRIGHT):
  - normal: white/black 14.6, yellow/black 13.6, cyan/black 11.7, green/black 10.7, black/white 14.6, black/yellow 13.6, black/cyan 11.7, blue/white 7.4, white/blue 7.4, yellow/blue 6.9, cyan/blue 5.9, black/magenta 4.9
  - BRIGHT: black/red 5.3, black/green 15.3, red/black 5.3, white/black 21, yellow/blue 8.0, blue/yellow 8.0
  - Red ink appears only as BRIGHT red on black, so never as normal red, and never on blue or white. Pictures may use any pair; none carries information that is not also in text.
- **Flashing.** FLASH is the Spectrum's own rate: the template swaps every 320 ms, about 1.6 cycles a second, which is under 3 Hz.
  - Screens that wait for a key: only the 1-cell footer cursor flashes.
  - Timed screens: only these flash: the alarm `lamp` (2×2 cells) on `news-alert` and `revolt-alarm`, and the `reticle` (3×3 cells) on `assassin-attempt`.
  - No heading or text ever flashes.
- **Live regions.** The template's `aria-live="polite"` region carries each screen's *screen-reader text*. Screens marked *assertive* also send that text to a second, visually hidden `aria-live="assertive"` region. The implementer adds that region to `index.html`.
  - The text mirror uses the screen-reader text written here, **not** `textRows()`. Double-size text, the report table and icons would read badly from the raw cells.
  - Values in braces are filled in. Groups are spoken by their full names.
  - Each screen's text ends with its keys.
- **Nothing by colour or sound alone.**
  - Plots, debt and refusals all say so in words.
  - The requester's advice line has a `=>` marker and an explanatory line.
  - Every sound has an on-screen message, and the game plays the same muted.
- **Keyboard only.** Every screen, including the title, how-to pages and About, works from the keyboard. No screen needs a pointer.

## Text check

Every final-text line in this document was counted by script:
- Each `{placeholder}` was replaced by its worst-case width (§ Placeholders).
- Each line was checked against its region's text width: the region's width, or the narrower inner width of a card, box or footer, as stated under each screen.
- Every line was also checked against 32 columns, and against the template font's character set: ASCII 32–126, `£`, `©`, `█`.

Result: no line exceeds its region or 32 columns, and every character is in the font. The figures are in the PR description.
