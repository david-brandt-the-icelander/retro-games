# The art bible

The art bible gives the remake its own look and sound, so that every screen is recognisably *this* game and never a copy of the original. It is written before any pixel is drawn or note is chosen, and the UI design and implementation follow it.

## Sections

1. **Identity statement:** two or three sentences on the visual and sonic personality, e.g. "a damp, lamp-lit logbook: deep blues, one warm accent, terse type, a foghorn motif". Name influences that aren't the original: period posters, newsprint, other media.
2. **Hardware frame:** what the platform allows. On the Spectrum: 15 colours, one ink and one paper per 8×8 cell, BRIGHT and FLASH per cell, a border colour, a 32×24 text grid (see `platforms/zx-spectrum.md`). These are free to use; they aren't the original's expression.
3. **Colour families:** group the screens (e.g. *night*, *reports*, *crisis*, *endings*) and give each group a paper/ink scheme, an accent and a border colour. Choose them fresh; if the original was known for a scheme on a screen, pick something else for ours.
4. **BRIGHT and FLASH policy:** what earns BRIGHT (e.g. numbers that matter) and what earns FLASH. Keep flashing for real urgency, never more than one flashing region per screen except a deliberate alarm, and always under 3 flashes per second (the Spectrum's own rate is about 1.6 Hz).
5. **Typography:** our own 8×8 font. Note its traits (stroke weight, cap height, descenders) and any second style (e.g. inverse video for headers). Never use or trace the ROM font, or the original game's font.
6. **Icon catalogue:** one row per graphic:

   | id | Description (written first) | Size (cells) | Ink/paper | Used on |
   |---|---|---|---|---|
   | lamp | A lighthouse lamp seen from the side, rays to the right | 2×2 | yellow on blue | night |

   Draw each icon from its description, never from the original's sprites. Store them as `#`/`.` text pictures (8 or 16 pixels per cell edge) in the code, so `zx_assets.py` can check them.
7. **Title concept:** a new title-screen composition: logo treatment, central image, colour, motion. Don't echo the original's title or loading screen.
8. **Motion and timing:** which screens animate, flash or move on by themselves, and for how long. Timings that are gameplay (from RULES) are kept; decorative ones are ours.
9. **Sound palette:**
   - the beeper character (square waves, clicks, noise)
   - a motif list: id, trigger, mood, length, and the pitch contour described in words
   - original melodies only. Public-domain classics (a funeral march, an anthem) may be quoted *only* in a new arrangement written for this game, never transcribed from the original's version.
10. **Distinctiveness table:** list each recognisable screen or effect of the original, *described in words, not reproduced*. Next to it, say how ours differs in layout, colour and motion:

    | Original element (description) | Ours |
    |---|---|
    | A report screen with two bar charts either side of a list of names | A single ranked list with dot meters under each name, on a different colour family |

    This table guards against the *Tetris v Xio* risk: same play, not the same screenshot.
11. **Do and don't:** short rules for anyone drawing later, e.g. "do keep one accent per screen", "don't tile backgrounds with text".

## Review questions
- Would a screenshot of any screen be mistaken for the original? (It must not.)
- Is every icon and motif described before being made?
- Do the colour families give each screen group a distinct, consistent feel?
- Is every flashing element justified and under 3 Hz?
