# Designing for the ZX Spectrum look

These are hardware facts: anyone may use them, and they make a remake feel right. What's risky on the Spectrum (the ROM font, the original's UDGs, BEEP tunes, loading and title screens) is covered by `../../zx-spectrum-clean-room/SKILL.md`.

## Display
- 256×192 pixels: a 32×24 grid of 8×8 cells, inside a border of one colour (the border can change per screen).
- **Attributes:** each cell has one ink colour and one paper colour, chosen from 8 (black, blue, red, magenta, green, cyan, yellow, white), plus BRIGHT (lighter) and FLASH (ink and paper swap about every 0.32 s). Two colours per cell is the defining constraint ("attribute clash"). Design icons to sit in whole cells and use one ink per cell.
- **Colour levels:** normal ≈ 0xD7, BRIGHT = 0xFF, and black stays black. In the template the colours are `BLACK, BLUE, RED, MAGENTA, GREEN, CYAN, YELLOW, WHITE` (0–7).
- **Text:** 32 columns, so plan messages to fit; 24 rows. Period games typically printed a message, waited for a key, and cleared the screen.

## Sound
- The beeper is one square-wave channel, played by `BEEP duration, pitch` (pitch in semitones from middle C), plus clicks and noise made by toggling the speaker.
- Effects of the era: rising or falling sweeps, ticks, two-tone alarms and short fanfares. These are generic.
- **Melodies are expression**, so compose your own.

## Input
- **Keyboard:** single key presses (`INKEY$` style), usually lower-case letters and digits. Many games accept *any* key as "next", and only Y as "yes". Keep the original's semantics (RULES' quirks section).
- **Joystick conventions** (Kempston, Sinclair, cursor) are fair game for action titles.

## Timing
- 50 frames per second. `PAUSE n` waits n frames, or less if a key is pressed. FLASH toggles every 16 frames.

## Web adaptation (template defaults)
- The canvas includes a 32-pixel border and is scaled by whole numbers on desktop. It fits the width on phones; in phone landscape the controls sit to the side.
- A touch keypad offers the keys that matter at each prompt, and tapping the screen means "any key".
- Sound is silent until the first key (browser rule), and the M key toggles it.
- The screen's text is mirrored to an `aria-live` region.
