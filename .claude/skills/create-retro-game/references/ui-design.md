# UI design

The UI design turns each wireframe into an exact specification that an implementer can build without guessing, and writes the game's final text. It follows the wireframes (layout), the art bible (look and sound) and the GDD (text budgets).

## Per screen
For every screen in WIREFRAMES.md (template: `assets/UI-DESIGN.template.md`):

- **Regions:**
  - one row per wireframe region, giving its cells (rows and columns)
  - ink, paper, BRIGHT and FLASH
  - alignment
  - the **final text**, or the icon id from the art bible
- **Text:**
  - written fresh to the GDD budget, in the game's voice, with placeholders in braces
  - count the characters: the budget is a hard limit on a 32-column screen
  - the layout tests will fail on any overflow
- **States:** what changes when, e.g. a plotting group's name flashes, or a number turns red when negative.
- **Input:** the keys that answer (keep the original's key semantics from RULES), and what the touch keypad offers.
- **Timing:** whether the screen waits for a key or moves on by itself, and when (RULES gives the gameplay timings).
- **Sound:** the motif id from the art bible.
- **Screen-reader text:** what a blind player hears, usually the screen's text in reading order, plus the choices.

## Global patterns
- **Footer prompt:** one design for "waiting for a key", and one for yes/no and numbered choices.
- **Responsive layouts:**
  - Desktop: integer scaling, keyboard only.
  - Phone portrait: the screen fills the width, and the keypad sits under it.
  - Phone landscape: the keypad sits beside the screen.
  The template's display and input layers do this; the design says what each screen's keypad offers.
- **Accessibility:** contrast (no ink and paper of similar brightness), flash rate, touch targets of at least 44 px, no information carried by colour or sound alone.

## Writing the text
1. Read the purpose and budget in the GDD. Don't reread the original, and don't work from memory of it.
2. Write the line the way this game's voice would say it.
3. Check its length, and that it carries every fact in the purpose.
4. Run `overlap.py` on `docs/` once all the text exists. Fix any hit by rewriting the whole message, not by swapping a word.

## Contact sheet
Render every screen in every state (worst-case values, flashing on and off) into one PNG for review:
- **Before the code exists:** draw the screens with the template's painter in a throwaway prototype.
- **After:** run `npm run sheet` in the game, which renders the game's own screens headlessly.

Attach it to the UI-design PR. The owner approves the look from it.
