# LodeStar: rules

Behaviour spec, 8 November 2026, phase 1 of `create-retro-game`. **Approved by the owner on 8 November 2026**, with the spec's recommendation taken on all twelve decisions below.

This document says what LodeStar does, tick by tick, so that it can be implemented in Rust without anyone looking at another game. It was written by the spec-and-verify role from the private faithful recreation that serves as the baseline, in our own words. It holds no original text, names, galaxy data, market data, ship geometry or code structure: messages appear as purpose, trigger and length budget; the galaxy generator and the market appear as structure, for the GDD to fill with new values; ship types appear by neutral role. The mechanics and their numbers (rates, thresholds, timings, probabilities, formulas, wrap-around and rounding behaviour, and the order of random draws) are kept exactly, because they are the game.

The implementer reads this document, the GDD and the design documents, and nothing else of the baseline. Parity tests compare the Rust sim against a data-swapped copy of the baseline, patched with the same deliberate differences, so where the baseline behaves oddly this document says so in the quirks of each section. Where a decision below changes a rule, a **LodeStar** note at that rule says how; the note wins over the baseline description around it.

## Conventions

- **Time.** The logic runs at 12 ticks a second. Where motion is split into two half-steps per tick, section B says so.
- **Units.** Positions are in sim units; LodeStar draws one sim unit as 0.2 m. Angles are in radians unless a section gives fixed-point units.
- **Bytes and words.** "Byte" means an integer 0..255 and "word" 0..65535; arithmetic on them wraps unless a rule says it saturates. Each section states its rounding.
- **Ship types** are numbered 1..13 and named by role: small pirate fighter A (1), police interceptor (2), small pirate fighter B (3), heavy fighter (4), medium multi-role ship, hunter variant (5), alien mothership (6), medium multi-role ship, trader variant (7, also the player's own hull), station (8), missile (9), asteroid (10), cargo canister (11), alien drone (12), escape pod (13).
- **Equipment** is named by function: fuel, missile, hold extension, E.C.M. unit, lasers (pulse and beam), fuel scoop, escape pod, area blast, energy booster, auto-dock, galaxy drive. The GDD gives each its LodeStar name.
- **Goods** are items 0..16 and **ranks** 0..8; the GDD names them.
- **Legal status** is clean, offender or fugitive, as values of one byte (section C).
- **Rule or data.** A number described as a rule is kept. One described as data (galaxy state, name syllables, market values, prices, ship stats, starting market) is chosen anew in the GDD, and the data-swapped baseline gets the same new values for parity.

## Deliberate differences from the baseline

1. **Camera and mounts.** A third-person orbit camera replaces the cockpit views. The four laser mounts (front, rear, left, right) remain; the player chooses the active mount (1–4), lasers fire only from it, and wherever the baseline depends on which view is on screen, LodeStar uses the active mount instead (B.20, C).
2. **Names, text, galaxy and market data** are new and come from the GDD. Nothing in the rules below depends on a particular name or value of that data.
3. **Cosmetic randomness has its own generator.** Stardust, the sun's edge, enemy beam lines and every other draw made only for the picture (B.4.4, C.2.4) come from a separate cosmetic generator, never from the main one. The main generator still takes the view-independent stardust draws on a flight-state reset (54) and on an ambush arrival (9), and discards them, so the logic stream keeps its length. The parity baseline is patched the same way.
4. **Galaxy generator.** LodeStar keeps the generator's mechanics (the advance step, four steps per system, the galaxy rotation and the property formulas of A.3) with a new starting state and new name syllables from the GDD.
5. **A countdown ends at death.** Dying cancels a running hyperspace countdown (A.14 item 4, Q-B3).
6. **Retargeting during a countdown is range-checked.** Selecting a new system while counting down changes the destination only if it is within fuel range; otherwise the countdown keeps its old destination and distance. Fuel can never go negative (A.14 item 3, Q-B4).
7. **The escape pod launches safely.** The abandoned hull takes no part in collision tests on the tick the pod launches, so launching the pod never damages the player (Q-B2).
8. **Missile lock uses the active mount's axis**, as the lasers do (C).
9. **Firing and locking need the flight scene.** With a chart, status, market or inventory panel open over the flight view, laser and missile input is ignored, as in the baseline (C).
10. **Visual defects are done properly.** Beam lasers draw their lines, the galaxy-jump message shows, a chart open before a jump stays open after it, and the status screen's condition labels are in the right order (D.14). None of these touch the logic.
11. **Saves** keep the baseline's accept and reject behaviour in a LodeStar format of its own (A.12).
12. **Panels replace the shop prompts** (decided 8 November 2026, after the UI design). In the market panel The pilot picks any goods item in any order and sets a quantity with a stepper; Buy takes that quantity and Sell sells that quantity, so partial sales are allowed. Prices, availability, hold space and cash work exactly as A.9 to A.11 say:
    - **Buy** accepts a quantity from 0 to the smallest of the item's availability, the room left in the hold for it (A.11.1), and the whole units the pilot's cash pays for at the current price; anything larger is refused before it reaches the sim. A buy of q units does exactly what step 6 of A.10.2 does for q.
    - **Sell** accepts a quantity from 0 to the cargo held of that item and adds quantity × current price to cash; selling still never restores availability.
    - Nothing in buying or selling draws a random number, so parity is unaffected; the parity harness drives these commands instead of the prompts' keys.
    - **The equipment panel** lists the offered items (A.12.2) with their prices; the pilot picks one and confirms to buy it, and leaving the panel takes the place of an abort, 0 or too-big entry. Everything after the choice works exactly as A.12.4 says: the cash check, the at-limit refusal and refund, each item's effect, the mount choice for lasers and the pulse-laser refund. A refused or unaffordable item shows its notice and the panel stays open rather than returning to the status screen; that changes only what is on screen.
    - Nothing in the equipment shop draws a random number either, and the parity harness drives its commands the same way.
    - The prompt-only behaviour of A.10.1 to A.10.3, D.6.9 to D.6.11 and D.6.13 (the 12-key number entry and its quirks, the fixed item order, the notices' one-second waits, leaving the shop after each refusal) does not apply in LodeStar.

Kept as the baseline does them, for parity, and to revisit in play-testing: planet vectors are never re-normalised (Q-B1), the AI's roll-steering sign (C), hold sizes 22 and 37 tonnes and laser power as rules, with the fuel price as data (A open 6).

## Decisions (approved 8 November 2026)

The four sections each end with their open questions. These twelve change behaviour or parity; the owner took the recommendation on all of them, and the deliberate differences above record the result.

| # | Question | Where | Decision |
| --- | --- | --- | --- |
| 1 | **Cosmetic random draws.** The baseline draws stardust, the sun's edge and enemy beams from the same generator as the game logic, and those draws depend on which view is on screen, which an orbit camera cannot reproduce. | B.20, C open 1, D open 1–2 | Give LodeStar a separate cosmetic generator. Run parity against a baseline patched the same way. Keep the 54 and 9 view-independent stardust draws on a reset and an ambush as discarded draws. |
| 2 | **Galaxy generator.** Keep the baseline's generator mechanics (advance step, four steps per system, the galaxy rotation) with new starting state and syllables, or invent a new algorithm that keeps only the property formulas? | A open 1 | Keep the mechanics with new state and syllables. Every system, name and position still changes, and system data stays testable by parity. |
| 3 | **Hyperspace countdown survives death**, so a player can die and still jump away alive. | A open 3, B open 5, D open 3 | Fix: cancel the countdown at death, and record it as a deliberate difference. |
| 4 | **Changing the target during a countdown** skips the range check, so fuel can go negative. | A open 4, B open 5 | Fix: recheck range, keep the old target if the new one is out of range, and record it. |
| 5 | **Escape-pod collision.** The abandoned hull appears inside the collision box, so launching the pod can damage or kill the player. | B open 5 | Fix, and record it. |
| 6 | **Missile lock axis.** | C open 2 | Lock along the active mount, like the lasers. |
| 7 | **Combat while a chart is open.** The baseline accepts laser and missile input only in the flight view; LodeStar shows charts as overlays during flight. | C open 3 | Keep the baseline rule: firing and locking need the flight view. |
| 8 | **Planet vectors shrink** about 0.1% a tick because planets are never re-normalised, which moves the station's spawn point over time. | B open 1 | Keep for parity now; revisit in play-testing. |
| 9 | **Roll steering sign** in the AI looks inverted; ships still converge, but slowly. | C open 4 | Keep for parity; revisit in play-testing. |
| 10 | **Fuel rate, hold sizes, laser power:** rules or ship stats for the GDD? | A open 6 | Hold sizes and laser power stay rules; the fuel price is data. |
| 11 | **Visual-only defects:** invisible beam-laser lines, an invisible galaxy-jump message, the chart not kept across a jump, two condition labels swapped. | D open 4–5, D.14 | Do these properly. They don't affect logic, so they stay outside parity. |
| 12 | **Save format:** compatible with the baseline's records, or only the same accept and reject behaviour? | A open 8 | Same behaviour, a format of our own. |

The quirks in each section that are not listed here are kept as described. The open-questions lists at the end of each section are kept as the record of what was asked; the decisions above settle the ones listed here.


## A. Universe, pilot and trade

This section covers the galaxies and their systems, the distance and fuel rules, choosing a
hyperspace target and making the jump, the two charts, the pilot's saved state, the market,
the cargo hold and the equipment shop. It describes the baseline's behaviour. Where a value is
**data** (the designer picks new values) this is said; every other number here is a **rule** and
must be kept exactly.

### A.1 Conventions

- **Byte** means an unsigned 8-bit value, 0..255. "mod 256" or "low byte" means keep the low 8
  bits (two's-complement wrap for negative intermediates). A **word** is an unsigned 16-bit value.
- `hi(w)` = `floor(w / 256)`, `lo(w)` = `w mod 256`. `a & b`, `a | b`, `a ^ b` are bitwise
  AND, OR, XOR; `a >> n` is a logical right shift.
- **Money** is held as an integer number of **tenths of a credit** and shown with one decimal
  place (internal 1000 is shown as 100.0).
- **Fuel and distance** are held as integers in **tenths of a light year** and shown with one
  decimal place. (The new game may rename the unit; the integer values are the rules.)
- **Galactic coordinates** are bytes: x 0..255 and y 0..255.
- **Logic ticks** run at 12 Hz. "Frame" below means one logic tick. The baseline draws the screen
  twice per tick; that matters only for random draws made while drawing (A.2.4).
- Goods items are numbered 0..16 and equipment items 0..11. The numbering is structural: some
  rules name items by number (A.9.6).

### A.2 The random number generator

#### A.2.1 State

One shared generator serves the whole game (flight, combat, rendering, and the draws in this
section). Its state is four bytes `p0, m0, p1, m1` and a carry bit `k`. At program start the
state is `p0 = 0x12, m0 = 0x34, p1 = 0x56, m1 = 0x78, k = 0`. Nothing reseeds it during play
(tests may set the four bytes).

#### A.2.2 One draw

A draw returns a pair `(A, X)`:

1. `t = (2·p0 + k) mod 256` (shift `p0` left by one, bringing the old carry in at the bottom).
2. `c = 1` if `p0 ≥ 128` (the bit shifted out), else `0`.
3. `u = t + p1 + c`. Set `c = 1` if `u > 255`, else `0`. Set `p0 = u mod 256` and `p1 = t`.
4. `X = m0`.
5. `v = X + m1 + c`. Set `k = 1` if `v > 255`, else `0`. Set `m0 = v mod 256` and `m1 = X`.
6. Return `A = m0` (the new byte) and `X` (the previous value of `m0`).

So the carry left by one draw feeds the next draw. A second entry, the **carry-cleared draw**,
first sets `k = 0` and then does the same steps; it is used only where stated (by the ship
spawning helper in another section).

"A random byte" in this document means `A` of one ordinary draw. "Chance n/256" means one draw
with `A < n`.

#### A.2.3 Draws made by the parts in this section

| When | Draws | Use |
|---|---|---|
| A normal (non-galactic) hyperspace countdown reaches 0 | 1 byte | mis-jump if `A ≥ 253` (chance 3/256) |
| Arrival in a system after the tunnel (normal or galactic jump, not a mis-jump) | 1 byte, **then** the flight-state reset's draws | the byte becomes the market byte (A.9.2); the reset then rebuilds the space dust (3 draws per dust particle, 18 particles; see the flight section) |
| A cargo canister is scooped (A.11.3) | 1 byte | goods item = `A & 7` (drawn before the hold-space check) |

System generation, names, inhabitants, distances, the nearest-system search, the charts, the
market screens, buying, selling, the equipment shop and saving draw **no** random numbers. (The
local chart draws small discs whose radius is 2 or 3; the disc routine only randomises edges for
radius 16 and above, so it draws nothing here.)

#### A.2.4 Note on rendering draws

Ship, planet and sun drawing in the space view take random bytes every redraw (other sections).
Because the generator is shared, the number of redraws between two game events changes which
values the market byte and mis-jump test receive. Exact parity therefore needs the rendering
draws reproduced too (see the rendering section).

### A.3 Galaxies and systems

#### A.3.1 Structure

There are **8 galaxies**, numbered 0..7 internally (shown as 1..8), each with **256 systems**
numbered 0..255. Every system is defined entirely by a **generator state** of three words
`w0, w1, w2`, written below as six bytes:

| Byte | Meaning |
|---|---|
| `b0` | `lo(w0)` |
| `b1` | `hi(w0)` |
| `b2` | `lo(w1)` |
| `b3` | `hi(w1)` |
| `b4` | `lo(w2)` |
| `b5` | `hi(w2)` |

The state of system 0 of galaxy 0 is **data** (three words chosen by the designer). Every other
state is derived from it by the two transforms below. The pilot's save holds the current
galaxy's system-0 state (A.7).

#### A.3.2 The advance step

One **advance step** replaces `(w0, w1, w2)` with `(w1, w2, (w0 + w1 + w2) mod 65536)`. The
addition is a true 16-bit addition (carries pass from low byte to high byte).

The state of system `n + 1` is the state of system `n` after **four** advance steps. So system
`n` of a galaxy is system 0's state advanced `4n` times. After system 255, a 256th group of four
steps is never needed (searches stop at 256).

The name generator (A.3.5) also uses single advance steps, on a private copy.

#### A.3.3 The galactic jump transform

The next galaxy's system-0 state is the current one with **each of the six bytes rotated left by
one bit, independently** (`b ← ((b << 1) | (b >> 7)) mod 256`). Bits do not move between bytes.
Eight transforms restore the original state, so galaxy 7 leads back to galaxy 0. The galaxy
number is kept separately (`(g + 1) mod 8`) and is used only for display.

#### A.3.4 System properties

All properties are computed from the system's six bytes, in this order (later lines use earlier
results):

| Property | Formula | Range |
|---|---|---|
| Position x | `b3` | 0..255 |
| Position y | `b1` | 0..255 |
| Government `G` | `(b2 >> 3) & 7` | 0..7 |
| Economy `E` | `b1 & 7`; then if `G < 2`, `E ← E | 2` | 0..7 |
| Tech level `T` | `(E ^ 7) + (b3 & 3) + (G >> 1) + (G & 1)` | 0..14 (shown as `T + 1`, 1..15) |
| Population `P` | `4T + E + G + 1` | 8..64 (shown as `P / 10` with one decimal, in billions) |
| Productivity | `((E ^ 7) + 3) × (G + 4) × P × 8` | 768..56320 (shown as millions of credits) |
| Mean radius | `((b5 & 15) + 11) × 256 + b3` | 2816..6911 (shown in km) |
| Inhabitants | see A.3.6 | |

Meaning of the codes (the designer names them):

- **Economy** `E`: `E & 4` = 0 for the industrial kinds (0..3), 4 for the agricultural kinds
  (4..7). Prosperity: `E` = 0 or 5 is the richest kind, 1 or 6 middling, 2 or 7 poorest, and 3
  or 4 are the "mostly" kinds (no prosperity word). The market uses `E` directly as a number
  (A.9): low `E` is the industrial end, high `E` the agricultural end. Governments 0 and 1 can
  never have economy 0, 1, 4 or 5 (their bit 1 is forced on).
- **Government** `G`: 0 is the most lawless, 7 the most orderly. (Other sections use `G` for
  pirate and police numbers.)
- `(G >> 1) + (G & 1)` is `G / 2` rounded up.

The baseline's ranges above were checked over all possible values of the inputs.

#### A.3.5 Name generation (structure)

The name uses a **syllable table** of 32 entries (**data**, replaced by the designer). Entry 0
means "no letters" and is never printed. Each other entry holds one or two letters (the baseline
marks a one-letter entry with a filler character in the second position, which is never
printed).

1. Copy the system's state (the system itself is not changed).
2. The syllable count is 4 if bit 6 of `b0` is set (`b0 & 0x40`), else 3.
3. For each syllable: let `i = b5 & 31` of the copy; if `i ≠ 0`, append entry `i`'s letters;
   then apply **one** advance step to the copy (the step happens for every syllable, including
   skipped ones).

So a name has 0..8 letters. (With the baseline's data every name has at least 2.) Names are
stored in capitals; printing rules (all capitals, or first letter capital and the rest small) are
in the text section.

#### A.3.6 Inhabitants (structure)

The inhabitants line uses four word lists (**data**): list S (3 size words), list C (6 colour
words), list K (6 skin or body words) and list N (8 creature words, printed as plurals).

1. If bit 7 of `b4` is clear, the inhabitants are the default settlers (one fixed label).
2. Otherwise build up to four words, in this order:
   1. `a = b5 >> 2` (0..63).
   2. `s = a & 7`; if `s < 3`, add S[s].
   3. `c = a >> 3` (0..7); if `c < 6`, add C[c].
   4. `k = (b3 ^ b1) & 7`; if `k < 6`, add K[k].
   5. `n = ((b5 & 3) + k) & 7`; always add N[n] in the plural.
   The words are joined by single spaces.

The data screen prints the phrase in brackets.

#### A.3.7 Other uses of a system's bytes

- **Galaxy chart dot size**: a system is drawn as a 2-pixel dot if bit 7 of `b4` is clear
  (the same bit that marks the default settlers), else as a 1-pixel dot. (The baseline tests
  `(b4 | 0x50) < 144`, which is the same thing.)
- **Local chart disc size**: radius `(b5 & 1) + 2` pixels.
- **Arrival scene** (positions in sim units; the rest is in the flight section). On arrival the
  pilot's legal-status value `L` is halved (A.5.6); let `c0` be its low bit before halving.
  - Planet: `a = (b1 & 7) + 6 + c0`; `odd = a & 1`; `a ← a >> 1`. The planet's z is
    `a × 65536`; its x and y are both `(a >> 1) × 65536`, negated if `odd = 1`.
  - Sun: z is `−(((b3 & 7) | 1) × 65536)`; x is `v × 65536 + v × 256` with `v = b5 & 3`; y is 0.
  - Planet style: one of two looks, chosen by bit 1 of the tech level `T`.

#### A.3.8 What is data and what is rule here

- **Data (designer)**: galaxy 0's system-0 state (three words); the syllable table; the
  inhabitant word lists; all display names for economies, governments and units.
- **Rules (keep)**: the advance step and the four-steps-per-system spacing; the byte-rotation
  galaxy transform; which bytes and bits feed each property and every formula in A.3.4; the
  syllable-count bit and the 5-bit syllable index; the inhabitant selection logic.
- The brief says the new game's galaxy generator is new. If the designer replaces the bit
  selections or the advance step, the property formulas, ranges and the dependence of tech level,
  population and productivity on economy and government must stay as in A.3.4, or market and
  spawning balance changes. See the open questions.

### A.4 Distance, nearest system and fuel

#### A.4.1 Distance between two systems

For systems at `(x0, y0)` and `(x1, y1)`:

1. `dx = |x1 − x0|` (0..255).
2. `dy = |y1 − y0| >> 1` (0..127): the vertical axis counts half.
3. `q = dx² + dy²`, then keep only the low 16 bits: `q ← q mod 65536`.
4. `r = floor(sqrt(q))` (integer square root).
5. Distance = `(4r) mod 65536`, in tenths of a light year.

So distances are always multiples of 4 (0.4 light year steps). Step 3's wrap is a quirk (A.14).

#### A.4.2 Nearest system to a point

Given a point `(x, y)` in the current galaxy:

1. Start at system 0 with `best = 127` and `answer = system 0`.
2. For each system 0..255 in order: `d = (|sx − x| >> 1) + (|sy − y| >> 1)` (each half rounded
   down before adding). If `d < best`, set `best = d` and `answer` = this system.
3. The answer is the first system with the smallest `d`. If no system has `d < 127`, the answer is
   system 0.

This cheap metric is used only for the search; the reported distance always uses A.4.1.

#### A.4.3 Fuel

- Fuel ranges over 0..70 tenths of a light year (maximum 7.0). The maximum, 70, is a rule.
- A hyperspace jump is allowed only if `0 < distance ≤ fuel`, where distance is A.4.1 from the
  pilot's current position to the selected system.
- The jump uses fuel equal to the distance, subtracted when the countdown ends (A.5.4).
- Refuelling at a station fills the tank to 70 (A.12).
- Fuel scooping at the sun (with fuel scoop fitted) adds fuel in flight (A.12.4).
- After using the escape pod, fuel is set to 70 (A.12.4).
- The galactic jump uses no fuel.

### A.5 Hyperspace: target, countdown and jump

#### A.5.1 Selected system

The game keeps a **cursor** point (two bytes) and a **selected system** with its distance from
the pilot. **Selecting** means:

1. Find the nearest system to the cursor (A.4.2).
2. Make it the selected system and move the cursor exactly onto it.
3. Compute the selected distance from the pilot's current position (A.4.1).

Selection happens when the pilot presses the hyperspace key, presses the show-distance key on a
chart, opens the system-data screen, and whenever the status screen is shown (including the
automatic return to it after docking or leaving a shop), and when launching from the station. It also happens at game start (with the cursor at the pilot's position) and during the
galactic jump. Merely moving the cursor does not select.

#### A.5.2 The hyperspace key (normal jump)

Checked in this order:

1. If docked: show the "docked" notice at the bottom of the screen; nothing else.
2. If a countdown is already running: ignore the key.
3. Select from the cursor (A.5.1). If a chart is showing, redraw it.
4. If the selected distance is 0 (the selected system is where the pilot is): ignore, silently.
5. If the selected distance is greater than the fuel: show the out-of-range notice at the bottom
   of the space view; nothing else.
6. Otherwise show the the destination announcement line at the bottom of the space view and start the
   countdown.

#### A.5.3 The galaxy drive key

Checked in this order:

1. If docked: show the "docked" notice; nothing else.
2. If a countdown is already running: ignore.
3. If the galaxy drive is not fitted: ignore, silently.
4. Otherwise, **at once**: remove the galaxy drive from the pilot's equipment, set legal
   status to 0 (clean), and start the countdown in galactic mode.

#### A.5.4 The countdown

- It has a shown value and an internal frame counter. Starting sets both to 15.
- Once per **flight** logic tick (not while docked, not during a tunnel): decrement the internal
  counter; if it is still above 0, stop. Otherwise set the internal counter to 5 and decrement
  the shown value; if the shown value reaches 0, perform the jump.
- So the jump happens 15 + 14 × 5 = **85 ticks** after the key (about 7.1 s). The shown value is
  printed in the top-left corner of the view while it is non-zero.
- Docking (manual or by auto-dock) and entering the station cancel the countdown (both
  values set to 0).
- The countdown is also ticked during the death sequence (see A.14).

#### A.5.5 The normal jump

When the shown value reaches 0 (normal mode):

1. Subtract the **current** selected distance from fuel (no new range check; see A.14).
2. Draw one random byte; mis-jump if it is ≥ 253.
3. Play the hyperspace tunnel: 16 logic ticks during which no game logic runs and key presses are
   discarded.
4. After the tunnel:
   - **Mis-jump**: the pilot does not reach the target. The current position becomes
     `(x, y ^ 0x1F)` where `(x, y)` is the departure system's position; the "current system"
     data stays the departure system's; the selected system and stored selected distance are not
     updated. No market byte is drawn. The rest (the hostile aliens, the sparse dust) is in the
     combat and flight sections. The escape pod cannot save the pilot here (A.12.4).
   - **Arrival**: the current position becomes the selected system's position, the current
     system data become the selected system's, the extra-ship spawn delay is reset to 0 (flight
     section), the selected distance becomes 0, then the common arrival (A.5.6).

#### A.5.6 The common arrival

Used by the normal arrival and the galactic jump:

1. Draw one random byte: the new **market byte** (A.9.2).
2. Recompute all 17 availabilities from the current economy and the market byte (A.9.3).
3. Reset the flight state (fresh shields, energy, dust and an empty local space; flight section).
4. Halve legal status: remember its low bit `c0`, then `L ← L >> 1`.
5. Place the planet and sun using the system bytes and `c0` (A.3.7).
6. The pilot is in flight. If a chart was showing when the tunnel started, the same chart is
   redrawn; otherwise the front view is shown.

#### A.5.7 The galactic jump

When the shown value reaches 0 (galactic mode):

1. Galaxy number `← (g + 1) mod 8`.
2. Apply the galactic transform (A.3.3) to the stored system-0 state.
3. Put the cursor at **(96, 96)** and select (A.5.1): the system nearest to (96, 96) in the new
   galaxy.
4. That system becomes the current system and position; the selected distance is set to 0.
5. Show the in-flight "galactic jump" message (the normal message time, flight section).
6. Play the hyperspace tunnel (16 ticks), then the common arrival (A.5.6).

There is no mis-jump test and no fuel use.

### A.6 The charts (behaviour)

Two chart screens show the current galaxy. Both can be opened docked or in flight. Layout
(positions on screen, line widths, title position) is the designer's; the behaviour below is the
rule.

#### A.6.1 Galaxy chart

- Shows all 256 systems at `(x, y / 2)` in chart space (the vertical axis is halved, matching the
  distance metric).
- Each system is a dot, 2 pixels wide or 1 by A.3.7.
- The pilot's current position has a large cross (half-size 7) and a **fuel-range circle** of
  radius `fuel >> 2` chart units, centred on it.
- The cursor has a small cross (half-size 4).
- The title shows the galaxy number (1..8).

#### A.6.2 Local chart

- Centred on the pilot's current position, drawn at a fixed screen point with a large cross
  (half-size 16).
- Scale: one galactic x unit is 4 pixels; one galactic y unit is 2 pixels (so a halved y unit is
  also 4 pixels).
- The fuel-range circle has radius `fuel` pixels (the same circle as on the galaxy chart,
  scaled by 4).
- Systems are shown if `|dx| < 20` and `|dy| < 38` (galactic units, from the pilot's position;
  signed differences, no wrap-around at the galaxy edge). Each is a disc (radius by A.3.7) with
  its name to its right where there is room.
- **Label placement** (8-pixel text rows): the system's row is `screen y >> 3`. Try that row,
  then the row below, then the row above; use the first not yet used by a label. A label row must
  be 3 or more (below the title). If a free row is found but it is less than 3, **neither the
  label nor the disc** is drawn. If no free row is found, the disc is drawn without a label.
- The cursor's small cross (half-size 8) is drawn only when `−26 ≤ cursor x − pilot x < 38` and
  `−36 ≤ cursor y − pilot y < 38`.

#### A.6.3 Cursor and keys on a chart

- **Arrow taps** move the cursor by 1 galactic unit in x (left/right) or y (up = −1, down = +1)
  and redraw the chart. Each axis is moved only if the new value stays within 0..255; otherwise
  that axis does not move.
- **Arrow held, docked**: in addition to the tap, every docked logic tick whose tick count is
  even moves the cursor by 1 on each held axis (left and right held together cancel). So a held
  key moves 6 units per second docked.
- **Arrow held, in flight**: no repeat; only taps move the cursor.
- **Home key**: put the cursor on the pilot's current position and redraw. This does not select.
- **Show-distance key** (charts only): select from the cursor (A.5.1), redraw, then show the
  selected system's name and, if non-zero, its distance.
- **Hyperspace key**: as A.5.2 (selection, then redraw).
- Moving the cursor alone never changes the selected system; the next selection does.

### A.7 The pilot's state

#### A.7.1 Fields

| Field | Type and range | Start value | Rule or data |
|---|---|---|---|
| Name | 1..7 characters A–Z, 0–9 | a default name | data |
| Position x, y | bytes | the starting system's position | data (choose the starting system) |
| Galaxy system-0 state | six bytes | galaxy 0's state | data |
| Galaxy number | 0..7 | 0 | rule |
| Cash | integer tenths of a credit (no upper limit in the baseline) | 1000 (100.0) | rule (the designer may keep it) |
| Fuel | 0..70 tenths of a light year | 70 (full) | rule |
| Laser on each mount | four bytes: 0 none, 15 pulse, 143 beam | pulse on mount 0, others none | rule |
| Hold capacity | tonnes | 22 | rule (player ship stat, see A.11) |
| Cargo | 17 integers, one per goods item | all 0 | rule |
| E.C.M. unit | yes/no | no | rule |
| Fuel scoop | yes/no | no | rule |
| Area blast | yes/no | no | rule |
| Energy booster | yes/no | no | rule |
| Auto-dock | yes/no | no | rule |
| Galaxy drive | yes/no | no | rule |
| Escape pod | yes/no | no | rule |
| Missiles | 0..4 | 3 | rule |
| Legal status | byte: 0 clean, 1..49 offender, 50+ fugitive | 0 | rule |
| Availability | 17 integers, 0..63 | a stored list for the starting system | data (see A.9.7) |
| Market byte | byte | 0 | data (with the availability list) |
| Kills | word (wraps at 65536) | 0 | rule |

Mount numbers in the baseline: 0 front, 1 rear, 2 left, 3 right. (LodeStar labels mounts 1..4
and fires only from the active mount; the stored data are the same four values.)

Laser values: bits 0..6 are the laser's power (15 for both kinds); bit 7 set marks the beam
(continuous) laser. The combat section says how they fire.

#### A.7.2 Derived values

- **Combat rank** 0..8 from kills `n`:
  - If `n < 256`: let `a = (n mod 256) >> 2`; the rank is the number of binary digits of `a`
    minus 1, with `a = 0` giving 0. That is: 0..7 → 0, 8..15 → 1, 16..31 → 2, 32..63 → 3,
    64..127 → 4, 128..255 → 5.
  - Otherwise, with `h = n >> 8`: `h = 1` → 5, `2 ≤ h ≤ 9` → 6, `10 ≤ h ≤ 24` → 7, `h ≥ 25` → 8.
- **Legal label**: 0 clean, 1..49 offender, ≥ 50 fugitive.
- **Contraband value** = `((cargo[3] + cargo[6]) × 2 + cargo[10]) mod 256`. On every launch from
  the station, legal status `← L | contraband` (bitwise OR, not addition). The legal section uses
  this.
- The status screen lists the hold extension as fitted when hold capacity ≥ 26.

#### A.7.3 Two copies

The game holds the **playing** pilot and the **saved** pilot (the last one saved or loaded; at
power-on, the start pilot). Death returns to the title and the playing pilot becomes a copy of
the saved one.

### A.8 Saving and loading

#### A.8.1 What is saved

Every field of A.7.1, plus an integrity check value. Flight state (shields, energy, position in
local space, missile lock, countdown, the cursor, the selected system) is not saved. A pilot can
only be saved while docked, so the saved position is always a system's position.

#### A.8.2 Saving

1. Allowed only while docked (the save key does nothing in flight).
2. Ask for a name: letters and digits are accepted (stored in capitals) up to 7 characters;
   delete removes the last character; enter finishes; escape cancels (empty name); all other
   keys are ignored.
3. If the name is empty, nothing is saved. Otherwise the playing pilot's name becomes it, the
   saved pilot becomes a copy of the playing pilot, and the copy is written to browser storage
   under that name. (The baseline also records the name as "last used", but never reads it back.)
4. Return to the docked status screen.

#### A.8.3 Loading (title screen)

1. The first title screen asks whether to load a pilot; the "yes" key goes to the name prompt
   (A.8.2 rules); any other key skips loading.
2. An empty name means "the saved pilot's own name".
3. Read storage under that name. The record is accepted only if it parses, its galaxy state has 6
   bytes, its cargo list has 17 entries, and its check value matches. Fields missing from the
   record take start values before the check is computed. A rejected record changes nothing.
4. If accepted, it becomes the saved pilot.
5. The playing pilot becomes a copy of the saved pilot. A second title screen waits for any key.
6. Select the system nearest to the pilot's position (this also puts the cursor there); it
   becomes the current system; the selected distance is 0; show the docked status screen.

The stored galaxy state is used as saved; it is not rebuilt from the galaxy number.

#### A.8.4 The integrity check (baseline)

The baseline's own check (not the 1984 one): list the fields as bytes in this order: x, y, the 6
galaxy bytes, cash as 4 bytes low first, fuel, galaxy number, the 4 laser bytes, hold capacity,
the 17 cargo values, then E.C.M. (255/0), fuel scoop (255/0), area blast (127/0), energy unit
(1/0), auto-dock (255/0), galaxy drive (255/0), escape pod (255/0), missiles,
legal status, the 17 availabilities, the market byte, kills low byte, kills high byte. Start with
`acc = ` the list length and carry 0, then for each byte `v` from the **last to the first**:
`s = acc + v + carry`; `carry = 1` if `s > 255` else 0; `acc = (s mod 256) ^ v`. The final `acc`
is the check value. The new game may use any integrity check with the same accept/reject effect.

### A.9 The market

#### A.9.1 Item table (structure; values are data)

There are 17 goods items. Each has:

| Field | Meaning | Range |
|---|---|---|
| Base price `B` | price byte before economy and fluctuation | 0..255 |
| Economy factor `F` | signed; its magnitude `|F|` is used mod 32 (0..31) | sign and 0..31 |
| Unit | tonnes, kilograms or grams | display only (see A.11.1) |
| Base quantity `Q` | availability before economy and fluctuation | 0..255 |
| Fluctuation mask `M` | which bits of the market byte affect this item | byte |

The sign of `F` decides the direction: a positive factor makes the item dearer and scarcer as `E`
rises (toward the agricultural end), so it suits items made in industrial systems; a negative
factor makes it cheaper and more plentiful as `E` rises.

Item 16 is the special goods item (from the alien drone): it is never on sale, though it can be scooped and sold.

#### A.9.2 The market byte

One random byte, drawn on each arrival in a system (A.5.6) and stored with the pilot. Docking,
launching and re-docking at the same station do not change it. Prices for buying and selling
always use the current system's economy and the stored market byte.

#### A.9.3 Price

For item `i` with economy `E` and market byte `R`:

1. `a = (R & M) + B`.
2. `e = E × (|F| mod 32)`.
3. `a ← a + e` if `F ≥ 0`, else `a ← a − e`.
4. `a ← a mod 256` (wraps both ways).
5. **Price = 4a** tenths of a credit (per unit of the item's unit).

So prices are multiples of 0.4 credits. Buying and selling use the same price (no spread).

#### A.9.4 Availability

Computed for all 17 items on arrival (and stored):

1. Item 16: 0.
2. Otherwise `a = (R & M) + Q`; `e = E × (|F| mod 32)`; `a ← a − e` if `F ≥ 0`, else `a + e`.
3. `a ← a mod 256`. If `a ≥ 128` (bit 7 set), `a = 0`.
4. Availability `= a & 63` (0..63).

Because the same masked bits of `R` are added to both price and quantity, an item that is dearer
on a visit is also more plentiful.

Buying reduces availability by the amount bought. Selling does **not** increase it. Availability
is only rebuilt on the next arrival.

#### A.9.5 The market screen

Lists all 17 items with price (one decimal) and unit, and availability with unit, or a dash when
availability is 0. It can be viewed docked or in flight; in flight it shows the current system's
stored market.

#### A.9.6 Items named by number

- Items 3 and 6: the two seriously illegal goods (count double in the contraband value).
- Item 10: the mildly illegal goods (counts once).
- Item 3 is also what a scooped escape pod gives; items 0..7 are what a scooped canister can give
  (A.11.3).
- Items 13..16 take no hold space (A.11.1); the designer should give 13..15 the small units
  (kilograms or grams) so this reads sensibly.
- Item 16: the special goods (never on sale; given by scooping the alien drone).

#### A.9.7 Starting market

The start pilot carries a stored availability list and a market byte of 0. In the baseline the
stored list is **not** what the formula gives for the starting system with byte 0 (it is a stored
table). The designer should either compute the list from the formula with the new data and the
chosen start byte, or supply a list; prices on the first visit come from the start byte.

### A.10 Buying and selling

#### A.10.1 Number entry (used by buying and by the equipment shop)

> **LodeStar:** neither the market nor the equipment shop uses number entry; their panels choose the item and quantity (deliberate difference 12).

Reads a whole number up to a maximum `max`:

1. `r = 0`. Read up to **12 keys** in total (every key read counts, including ignored ones).
2. For each key:
   - Pointer taps, arrows, shift, control, alt, caps lock and tab: ignored (but counted).
   - Enter, space, delete (backspace) or escape: stop; the result is `r`.
   - A digit `d`: if `r ≥ 26`, stop with the result `r` (the digit is discarded). Otherwise
     `r ← 10r + d`; if `r > max`, stop at once with **too big** (the digit is not shown);
     otherwise show the digit.
   - Any other key (a letter, a symbol, a function key, a control combination): **abort**.
3. After 12 keys, the result is `r`.

Delete does not delete; it finishes.

#### A.10.2 Buying (docked only)

> **LodeStar:** buying is done from the market panel, in any order and any quantity the stepper allows; the purchase itself is step 6 below (deliberate difference 12).

The buy screen goes through items 0..16 in order. For each item it shows that item's row (A.9.5);
if the item's availability is greater than 0 it then asks for a quantity:

1. Prompt with the item's name and unit; read a number with `max` = the item's availability.
2. **Abort** → show the inventory screen; the buying session ends (later items are skipped).
3. **Too big** → show the bad-quantity notice, beep, wait 1 second, ask again for the same item.
4. If there is no room in the hold for that quantity (A.11.1) → show the hold-full notice, beep,
   wait 1 second, ask again.
5. If quantity × price > cash → show the not-enough-cash notice, beep, wait 1 second, ask again.
6. Otherwise: cash −= quantity × price; cargo += quantity; availability −= quantity. If the
   quantity was more than 0, show the cash remaining, beep, and wait 1 second.
7. Go on to the next item.

Entering 0 (or just enter) buys nothing and moves on. After item 16, show the inventory screen.

#### A.10.3 Selling (docked only)

> **LodeStar:** selling is done from the market panel, and any quantity up to the cargo held may be sold (deliberate difference 12).

The sell screen goes through items 0..16 in order, skipping items with no cargo. For each it shows
the name and quantity and asks yes or no with a single key:

- The "yes" key (either case): cash += quantity × current price (A.9.3); cargo for that item = 0.
  The whole stack is sold; partial sales are not possible.
- Any other key (including a pointer tap): keep it.

After the last item: beep, wait 1 second, show the inventory screen.

#### A.10.4 Inventory screen

Shows fuel (one decimal), cash (one decimal), the hold extension if fitted (hold capacity ≥ 26),
and every goods item with a non-zero quantity and its unit. Available docked or in flight.

### A.11 The hold

#### A.11.1 Hold space

There is room for `n` more of item `i` if:

- `i ≥ 13`: always (items 13..16 take no space, whatever their unit).
- Otherwise: `(cargo[0] + … + cargo[12]) + n ≤ hold capacity`.

Hold capacity is 22 tonnes, or 37 with the hold extension. These are the player ship's cargo
figures; the designer may retune them as ship stats, but they act as rules for parity, and the
display threshold (≥ 26 means "bay fitted") must sit between the two values.

#### A.11.2 Units

Tonnes, kilograms and grams are labels only: quantities are plain integers. There is no
conversion between units, and only the item number decides hold use (A.11.1).

#### A.11.3 Gaining and losing cargo in flight (summary; detail elsewhere)

- **Scooping** (needs fuel scoop; the object must be below the ship when it touches, see the
  flight section): a cargo canister gives item `(random byte) & 7`; the alien drone gives item 16;
  an escape pod gives item 3. If there is no room for 1 more, a sound plays and nothing is added,
  but the object is still destroyed. The random byte for a canister is drawn before the room
  check. A message names the item gained.
- **Damage** may destroy a whole cargo stack or a piece of equipment (combat section).
- **Escape pod** use empties the hold (A.12.4).

### A.12 Equipment

#### A.12.1 The list

Twelve items, numbered 0..11 in this fixed order: fuel, missile, hold extension, E.C.M. unit,
laser of the pulse type, laser of the beam type, fuel scoop, escape pod, area blast, energy booster, auto-dock
, galaxy drive.

#### A.12.2 Availability by tech level

At a system with tech level `T` (0..14 internal), the shop offers items `0 .. min(T + 3, 12) − 1`:
the first `min(T + 3, 12)` items. Fuel, missiles and the hold extension are always offered; all
twelve are offered from `T = 9` (shown 10) upward. This is a rule.

#### A.12.3 Prices

- Each item except fuel has a fixed price in tenths of a credit (**data**).
- Fuel's price is `(70 − fuel) × f` tenths of a credit, where `f` is the fuel rate (**data**; the
  baseline uses a small whole number per tenth of a light year). With a full tank the price is 0.
- The beam laser's refund for a replaced pulse laser equals the pulse laser's price.

#### A.12.4 The shop and each item's effect

> **LodeStar:** the item is picked from the equipment panel's list instead of by number; steps 2 to 5, the table and the mount choice apply unchanged, and the panel stays open after a refusal (deliberate difference 12).

The shop (docked only) lists the offered items numbered from 1, each with its price (fuel's price
recomputed from the current fuel), and asks for a number with `max` = the number of items offered.

1. **Abort, 0, or too big** → leave the shop to the docked status screen.
2. Item = number − 1. If its price > cash → show the not-enough-cash notice, beep, wait 1 second,
   leave to the status screen.
3. Otherwise take the price from cash, then apply the item:

| Item | If already at its limit | Effect |
|---|---|---|
| Fuel | never refused (price may be 0) | fuel = 70; also resets the main-loop counter to 0 (no lasting effect, since launch resets it) |
| Missile | missiles ≥ 4 | missiles + 1 (maximum 4) |
| Hold extension | capacity already 37 | capacity = 37 |
| E.C.M. unit | already fitted | fitted (used in flight; combat section) |
| Pulse laser | the chosen mount has **any** laser | ask for a mount (below); that mount = pulse (15) |
| Beam laser | the chosen mount already has a beam | ask for a mount; if it has a pulse laser, refund the pulse price; that mount = beam (143) |
| Fuel scoop | already fitted | fitted: allows scooping objects (A.11.3) and fuel from the sun (below) |
| Escape pod | already fitted | fitted (below) |
| Area blast | already fitted | fitted: one use, destroys ships nearby (combat section) |
| Energy booster | already fitted | fitted: the energy bank recharges 2 units instead of 1 at each recharge step (every 8th tick; flight section) |
| Auto-dock | already fitted | fitted: in flight, its key docks at once when the station is present and not hostile (flight section) |
| Galaxy drive | already fitted | fitted: one galactic jump (A.5.3, A.5.7); used up by the jump |

4. **Refused** (the at-limit notice): give the price back, show the item's name with the
   the already-fitted notice notice, beep, wait 1 second, leave to the status screen.
5. **Bought**: show the cash remaining, beep, wait 1 second, then show the shop again (so several
   items can be bought in a row).

**Choosing a mount** (lasers only, after the price has been taken): the four mounts are listed and
the shop waits for a mount key; only the four mount keys are accepted, every other key is ignored.
The baseline uses keys 0..3 for front, rear, left, right; LodeStar uses 1..4 to match its mount
numbers.

**Fuel scooping at the sun** (flight; heat detail in the flight section): on the tick where the
32-tick cycle phase is 20, if the station is not present and the cabin temperature just computed
from the sun's nearness is ≥ 224, and fuel scoop are fitted, fuel `← min(70, fuel + floor(speed /
8))` and the scooping message is shown (even when the gain is 0).

**Escape pod** (flight): the pod launches; after the pod sequence, if the pilot was in mis-jump
space, the pilot dies. Otherwise: cargo all 0, legal status 0, escape pod removed, fuel 70, and
the pilot is docked at the current system's station with the same cash and other equipment.

### A.13 Messages and notices in this section

Wording is the designer's. Budgets are in characters on a 32-column screen.

| Purpose | When | Budget |
|---|---|---|
| Docked notice | hyperspace or galactic key pressed while docked | 10 |
| Jump target line (the destination announcement plus name) | normal countdown starts | 24 including the name (names up to 8) |
| Out-of-range notice | target farther than fuel | 18 |
| Galactic jump message | galactic countdown ends | 20 |
| Countdown number | while a countdown runs | 2 digits |
| Galaxy chart title with galaxy number | chart open | 20 |
| Local chart title | chart open | 20 |
| Selected name and distance lines | show-distance key | name 8; distance line 24 |
| Data screen labels: distance, economy, government, tech level, population (+ "billion"), inhabitants (in brackets), productivity (+ millions of credits), radius (+ km) | data screen | each label + value within 30 |
| Market headings (item, price, quantity) | market and buy screens | 30 |
| Quantity prompt (item name, unit) | buying | 30 |
| Bad quantity, hold full, not enough cash | buying / shop errors | 10 each |
| Cash remaining | after a purchase | 24 |
| Sell prompt (yes/no) | selling | 14 after the name and quantity |
| Equipment shop title and item lines (number, name, price) | shop | item name 18 |
| Choose-a-mount prompt and the four mount names | laser purchase | prompt 10, names 8 |
| the already-fitted notice notice after an item name | refused purchase | 10 |
| Fuel and cash lines | inventory, status | 24 each |
| Name prompt | save or load | 20 |
| Load-a-pilot question (yes/no) | first title screen | 30 |
| Scooped item name, scooping fuel | in flight | 16 |

### A.14 Quirks and edge cases

1. **Distance wrap.** `dx² + dy²` is cut to 16 bits before the square root. When it is 65536 or
   more the distance comes out far too small. Example: `dx = 255`, `dy = 23` gives 65554 → 18 →
   root 4 → distance 16 (1.6 light years), which is in range. A system on the far edge of the
   galaxy can therefore be reachable. Keep this.
2. **Nearest-system fallback.** If no system is within the cheap metric's starting bound (127),
   the search returns system 0. Ties go to the lower system number.
3. **Retargeting during a countdown.** The hyperspace key is ignored while counting down, but the
   show-distance key, the data screen and the status screen still select a new system from the
   cursor. When the countdown ends the jump goes to the **newly** selected system and subtracts
   its distance with **no range check**, so fuel can go negative; if the new selection is the
   current system (distance 0), the jump still happens, uses no fuel and draws a new market byte.
   **LodeStar:** the new selection replaces the destination only when it is within fuel range; otherwise the old destination and distance stay (deliberate difference 6).
4. **Countdown during death.** The countdown keeps ticking during the death sequence, so a jump
   can begin during it (the baseline then shows the tunnel; see the open questions).
   **LodeStar:** dying cancels the countdown (deliberate difference 5).
5. **Galactic key clears legal status at the key press**, not at arrival, and consumes the drive
   even though the jump happens 85 ticks later.
6. **Mis-jump position.** The position's y has its low 5 bits flipped; the stale selected
   distance is kept until the next selection, which measures from the new point.
7. **Market byte persists.** Leaving and re-docking without a jump keeps the same prices and the
   depleted availability. Selling never restores availability.
8. **Price wrap.** The price byte wraps mod 256 in both directions (a very cheap or very dear item
   can wrap round).
9. **Availability treats 128..255 as negative** and gives 0, even when the true sum was a large
   positive number. The result is then cut to 6 bits (0..63), so 64..127 become 0..63.
10. **Hold space by item number.** Items 13..16 take no space, whatever unit the designer gives
    them. A buy of these is limited only by availability and cash.
11. **Number entry.** At most 12 keys; delete ends rather than deletes; a third digit is refused
    once the value is 26 or more (so no value above 259 can be typed); any letter aborts the
    whole buy session, not just the item; a too-big digit is never shown.
12. **Equipment refund paths.** The price is taken first and given back on refusal, so the cash
    check uses the full price even when the beam laser would get a pulse refund.
13. **Fuel purchase on a full tank** costs 0 and still shows the bought sequence.
14. **Scooping with a full hold** still destroys the object and still draws the random byte for a
    canister.
15. **Fuel scooping message** shows even when `floor(speed / 8) = 0`.
16. **Chart label rule** can hide a system entirely when its label row would be above the title
    area (A.6.2).
17. **Held arrows repeat only when docked**, on even ticks, on top of the tap's own move.
18. **Keys during a tunnel** are discarded.
19. **Save list uses the name as the key**: saving under an existing name replaces it.
20. **Legal status at launch** is OR-ed with the contraband value, so it can only gain bits.

## Open questions (section A)

1. **Generator replacement.** The brief makes the galaxy generator new. Should LodeStar keep the
   advance step, four steps per system and the byte-rotation galaxy transform (and only replace
   galaxy 0's state and the word tables), or invent a new generator that only keeps the property
   formulas of A.3.4? Parity tests of system data need the former.
2. **Distance wrap (A.14.1).** The baseline cuts the sum of squares to 16 bits on purpose. I could
   not confirm from the baseline alone whether the 1984 game behaves the same; the rule here
   follows the baseline.
3. **Countdown during death (A.14.4).** The baseline ticks the countdown in the death sequence; a
   jump that fires then switches to the tunnel. This looks unintended. Keep it, or stop the
   countdown at death?
4. **Retargeting during the countdown (A.14.3)** allows negative fuel. Keep for parity, or clamp?
5. **Starting availability (A.9.7).** The baseline's stored list does not match the formula. Should
   the new start list be computed from the formula, or stored as data?
6. **Fuel rate, hold sizes and laser power.** Treated here as data (fuel rate) and as rules with
   designer override (22 and 37 tonnes, laser power 15 with bit 7 for the beam). Brief rule 3
   could also read these as player-ship stats for the designer to retune. Confirm.
7. **Chart cursor repeat in flight.** The baseline does not repeat held arrow keys in flight (taps
   only). Is that intended?
8. **Save format.** Is compatibility with the baseline's saved records required, or only the same
   accept/reject behaviour?

## B. Flight, the bubble and navigation

This section specifies how the player's ship flies, how every other object in the local space
around it moves, how objects enter and leave that space, and how the player travels between and
within star systems. It describes the baseline's behaviour (the private TypeScript recreation),
which is what LodeStar's parity tests compare against. Where the baseline differs from the 1984
original, the difference is noted.

### B.1 Notation and units

- **Sim unit**: the basic length unit of the simulation (LodeStar maps 1 sim unit = 0.2 m).
  Positions are stored as floating-point numbers of sim units.
- **Coarse unit** (written **K**): 256 sim units. **Far unit** (written **L**): 65536 sim units.
- For a coordinate *v*, |v|ᵢ means ⌊|v|⌋ (the integer magnitude). Its **coarse value** is
  c(v) = (|v|ᵢ div 256) mod 256, and its **fine value** is f(v) = |v|ᵢ mod 256. Many rules
  compare coarse values; where a rule says "within one far unit" it means |v| < 65536.
- **Tick**: one logic step, at 12 Hz. **Substep**: half a tick; the simulation runs 24 substeps per
  second (see B.2).
- **Byte**: an integer 0..255. "mod 256" wrap is stated where it happens.
- **Sign-magnitude counter**: a byte whose bit 7 is a sign (1 = negative) and bits 0..6 a
  magnitude 0..127.
- Angles are in radians. The player's turning rates are small fixed-point values *n*/256 rad.

### B.2 Coordinate system

The simulation is player-centred. The player's ship is always at the origin and never rotates;
instead, the whole universe is moved and rotated around it.

| Axis | Direction (as the player sees it from the cockpit, looking forward) |
|---|---|
| +x | to the right |
| +y | up |
| +z | forward (straight ahead) |

Every object has a position (x, y, z) relative to the player and three orientation vectors, each
nominally of unit length and mutually perpendicular:

- **nose**: the direction the object points (it travels along it);
- **roof**: the object's "up";
- **side**: the object's "right" (for most objects; see quirk Q-B9).

The default orientation (used whenever an object is created without one being given) is
nose = (0, 0, −1) (pointing straight at the player), roof = (0, 1, 0), side = (1, 0, 0).

Screen projection constants matter for random-number parity (B.4.4): the baseline's flight scene
is 256 × 192 pixels with its centre at (128, 96); a point (x, y, z) with z > 0 projects to
screen (128 + 256·x/z, 96 − 256·y/z).

### B.3 Timing: ticks, substeps and modes

#### B.3.1 The clock

The game advances in **substeps** at a fixed 24 per second (one every 1000/24 ≈ 41.67 ms of wall
time). Wall time is accumulated, with at most 250 ms added per display refresh and at most 4
substeps run per display refresh; extra backlog is carried, not dropped. A global substep counter
increases by 1 at the start of every substep in every mode (including while paused). A substep is
a **logic substep** when this counter is even after the increase; one tick = one ordinary substep
followed by one logic substep. Everything described as "per tick" happens on logic substeps.

#### B.3.2 What one substep does, by mode

At the start of every substep, all one-shot key presses collected since the previous substep are
taken from the input queue. Then:

| Mode | Order of work in the substep |
|---|---|
| Paused | Feed each press to the pause menu (unpause, sound on/off, toggle auto-centre, toggle damping, toggle bar flashing, quit to title). Redraw the current scene (no motion, no logic). |
| Tunnel (launch, docking or hyperspace tunnel) | Presses are discarded. On a logic substep: draw the next tunnel ring step; after the 16th step, run the transition's continuation. Redraw the dashboard only. A tunnel lasts 16 ticks. |
| Death | Presses are discarded. On a logic substep: run the tick logic in "dying" form (B.3.3), then decrement the death timer; when it reaches 0, return to the title and end the substep. Then move everything by half a tick (B.7). Redraw. |
| Escape (escape-pod drift) | Presses are discarded. On a logic substep: run the per-tick own-motion update (B.7.3) on the abandoned hull only, then decrement the escape timer; when it reaches 0, run the aftermath (B.17) and end the substep. Then move everything by half a tick. Redraw. |
| Flight | Dispatch each press (B.5.4). Move everything by half a tick (B.7). On a logic substep, run the tick logic (B.3.3). Redraw. |
| Docked | Dispatch each press. On a logic substep, run the docked chores (main counter C decrements mod 256, laser temperature cools by 1 if above 0, the message timer counts down, the chart cursor moves every other tick). Redraw. |

Note the different order in Death mode (logic before motion) compared with Flight mode (motion
before logic). Movement is always applied before redrawing.

#### B.3.3 The tick logic (Flight mode, and Death mode in "dying" form)

The main counter **C** is a byte. It is set to 0 whenever the flight state is reset, and is
decremented by 1 (mod 256) once per tick. Several actions are scheduled on its value; the value
used is always the one **before** this tick's decrement.

Each tick, in this exact order:

1. **Attitude controls** (B.5): apply the held roll and pitch keys (none while dying), damp, and
   compute the roll and pitch angles used by motion from the next substep on.
2. **Player actions** (skipped while dying): clear "laser power fired this tick"; apply the held
   speed keys (B.6); handle each queued one-shot flight action in the order pressed (unarm
   missile, target missile, fire missile, area blast, escape pod, in-system jump, E.C.M.,
   auto-dock). The escape pod and a successful docking-computer request end this step at
   once: later queued actions are discarded and the lasers are not fired this tick. Otherwise,
   finally, fire the lasers if held (combat section).
3. **Per-object loop**: for slot = 0, 1, 2, … while an object exists in that slot, process the
   object (B.3.4). If processing removed the object, the same slot number is processed again (the
   next object has shifted down into it).
4. **Energy**: count down the energy-bomb flash; if C mod 8 = 0, recharge shields and energy
   (combat section).
5. **Station appearance** (B.11.1): if not in the mis-jump zone, C mod 32 = 0 and no station is
   present.
6. **Planet and sun checks** (not in the mis-jump zone): if C mod 32 = 10, the low-energy warning
   and the altitude check (B.14); else if C mod 32 = 20, the sun-heat check and fuel scooping
   (B.15). A crash or burn here kills the player and **ends the tick immediately** (steps 7–8 do
   not run).
7. **Laser and E.C.M. bookkeeping** (combat section).
8. **Chores**: count down the in-flight message timer (the message clears when it reaches 0);
   C ← (C − 1) mod 256; if C = 0 now and not dying, run periodic spawning (B.10.8); laser
   temperature cools by 1 if above 0; advance the hyperspace countdown (B.16.2).

So C cycles 0 → 255 → 254 → … → 1 → 0. After a reset (C = 0) the first periodic spawn happens on
the 256th tick, then every 256 ticks (≈ 21.3 s).

#### B.3.4 Processing one object (per tick)

For the object in slot *s*, in this order (the flight-relevant steps are detailed here; combat
steps are specified in the combat section):

1. Energy-bomb kill (combat).
2. If killed but not yet exploding: start the explosion (draws 4 random bytes, B.4.3).
3. If neither exploding nor killed:
   - if the object is not a planet or sun and (C XOR s) mod 16 = 0: re-orthonormalise it (B.8);
   - if it is not a planet or sun, its AI is on, and it is a missile or (C XOR s) mod 8 = 0: run
     its AI (combat section). If the player died during the AI, stop processing this object.
4. Per-tick own-motion update (B.7.3) — this runs for every non-body object, including exploding
   and killed ones.
5. Explosion progress; when the cloud is spent, mark the object killed (combat).
6. Proximity: docking, scooping or collision (B.12, B.15.3, combat).
7. Missile lock and laser hits, only while the flight scene is displayed (combat).
8. Removal: an exploded object is removed (combat: bounty, legal effects); an object that is too
   far away is removed (B.9.4).

If the player dies during the loop, the loop carries on over the new death-scene object list from
the next slot number (see Q-B14).

### B.4 The random number generator

#### B.4.1 Algorithm

There is **one shared generator** for all game logic, effects and some rendering. Its state is
four bytes r0, r1, r2, r3 and a carry bit K. Initial state: r0 = 0x12, r1 = 0x34, r2 = 0x56,
r3 = 0x78, K = 0. It is never reseeded during play (tests may seed it).

One **draw** produces a pair (A, X):

1. f = ((r0 · 2) + K) mod 256; c₁ = bit 7 of the old r0.
2. t = f + r2 + c₁; c₂ = 1 if t > 255 else 0.
3. r0 ← t mod 256; r2 ← f.
4. X = the old r1.
5. m = r1 + r3 + c₂; K ← 1 if m > 255 else 0.
6. r3 ← the old r1; r1 ← m mod 256.
7. A = the new r1.

A **cleared draw** sets K = 0 first, then draws. A **byte** is the A of an ordinary draw. "Chance
n/256" means a byte < n. Several rules use both A and X of one draw, and one rule uses K after a
draw (B.10.8); all must be reproduced exactly.

#### B.4.2 Draws in this section, in the order they happen

| Event | Draws |
|---|---|
| Flight-state reset (on launch, docking, hyperspace arrival, mis-jump arrival, escape aftermath, death) | Stardust refill: 18 particles × 3 draws = 54 (B.19.1) |
| Hyperspace countdown ends, ordinary jump | 1 byte: mis-jump test (B.16.3) |
| Arrival in a system (ordinary or galactic) | 1 byte for the market (market section), **then** the 54 stardust draws of the reset |
| Mis-jump arrival | 54 (reset), then 4 × 2 (encounter templates, B.10.3), then 3 × 3 = 9 (stardust refill to 3 particles) |
| Death | 54 (reset), then for each of 4 debris canisters: 2 (template) + 1 (explode-or-not) |
| Scooping a canister | 1 byte (which goods item) |
| Periodic spawn | see B.10.8 |
| Stardust respawn (each substep, flight scene displayed) | 3, 4 or 8 per respawned particle (B.19) |
| Sun drawing (each redraw of the flight scene) | 1 byte per screen row of the sun's disc when its radius ≥ 16 px (B.4.4) |

#### B.4.3 Draws owned by other sections (listed so the order is complete)

Laser fire (2 bytes per shot: sight jitter x then y), explosion start (4 bytes, which seed a
separate private generator of the same algorithm with carry-in fixed at 0, used only to scatter
the explosion cloud), loot canisters when the player's laser kills a ship (1 draw, then 1 draw
per canister spawned), damage that reaches the energy banks (1 draw for possible loss of cargo or
equipment), the AI's draws, an enemy laser beam being drawn (1 byte, B.4.4).

#### B.4.4 Render-time draws (needed for parity)

> **LodeStar:** these draws come from the separate cosmetic generator (deliberate difference 3); the main generator never sees them. They are described so the parity baseline can be patched to match.

The baseline draws random numbers while drawing the flight scene, so the number of draws depends
on what is on screen. To stay in step, LodeStar must count these draws exactly as the baseline
would, using the baseline's notional view (B.20) and projection, even if its own camera shows
something else. The flight scene is redrawn every substep in Flight, Death, Escape, and while
paused in flight with the flight scene displayed. Objects are visited in slot order:

- **Sun**: transform its position into the notional view. If z ≤ 0 or z ≥ 48·L: no draws. Project
  its centre; if the centre is 1024 px or more from the screen centre on either axis: no draws.
  Radius r = 24576·256 / z pixels. If r < 16: no draws. Otherwise one byte is drawn for each
  integer row y from max(0, ⌈cy − r⌉) to min(191, ⌊cy + r⌋) inclusive (none if that range is
  empty). (The byte jitters the half-width of that row by (byte AND m) − ⌊m/2⌋ with m = 7 for
  r ≥ 96, 3 for r ≥ 40, 1 for r ≥ 16.)
- **A ship flagged as firing at the player** (combat): one byte if all hold: its position in the
  notional view has z > 0, ⌊z/256⌋ < 192, |x| < z and |y| < z; it is not exploding; it is not
  far enough to be drawn as a dot (combat/visual section); and its gun vertex is in front of the
  player (transformed z > 0). If it reaches the gun-vertex test the firing flag is then cleared
  whether or not a byte was drawn; if it fails an earlier test the flag stays set.
- Planets, the system charts and the title screen draw nothing.

### B.5 Player attitude: roll and pitch

#### B.5.1 State

Two **rates**, roll rate R and pitch rate P, integers 1..255 with centre 128. Two option flags,
both on by default and toggled from the pause menu: **auto-centre** and **damping**.

#### B.5.2 Key input (step 1 of each tick)

Held keys are sampled once per tick. In this order:

1. Roll-left held: R ← raise(R, 7).
2. Roll-right held: R ← lower(R, 7).
3. Climb held: P ← lower(P, 14).
4. Dive held: P ← raise(P, 14).

where

- raise(v, n): v + n, capped at 255; then, if auto-centre is on and the result is below 128, it
  becomes 128.
- lower(v, n): v − n, floored at 1; then, if auto-centre is on and the result is above 128, it
  becomes 128.

So with auto-centre on, a press of the opposite key first snaps a rate back to centre; holding
both keys of a pair cancels out from centre.

#### B.5.3 Damping and the angles

1. If damping is on, R moves 1 toward 128, **twice** (so up to 2 per tick); otherwise unchanged.
2. r = R − 128 (−127..127). a = ⌊|r| / 4⌋; if a < 8 then a ← ⌊a / 2⌋. The **roll magnitude** is
   a (0..31). The per-tick roll angle is ρ = sign(r)·a / 256 rad.
3. If damping is on, P moves 1 toward 128 (once); otherwise unchanged.
4. p = P − 128. b = ⌊(|p| + 4) / 16⌋; if b < 3 then b ← ⌊b / 2⌋. The **pitch magnitude** is b
   (0..8). The per-tick pitch angle is φ = −sign(p)·b / 256 rad (a dive, p > 0, gives φ < 0).

Resulting steps: roll magnitude takes the values 0, 1, 2, 3 for |r| = 0–7, 8–15, 16–23, 24–31, then
jumps to 8 at |r| = 32 and rises by 1 per 4 of |r| to 31. Pitch magnitude is 0 for |p| ≤ 27, 1 for
28–43, then 3 for 44–59 and +1 per 16 up to 8 (the value 2 never occurs).

With both flags on and a key held from centre: R rises by a net 5 per tick until it reaches 253
(255 cap, then −2), so the roll magnitude reaches 31 after 25 ticks; P rises by a net 13 per tick
to 254, pitch magnitude 8 after 10 ticks. On release, R decays by 2 and P by 1 per tick.

A **control reset** (on every flight-state reset, at the title, and at the escape pod) sets
R = P = 128 and sets the roll angle to **+3/256** and the pitch angle to 0 until the next angle
computation. Displays of the roll and pitch indicators use R and P and the magnitudes and signs.

#### B.5.4 One-shot key dispatch

Held keys (speed up, slow down, roll left/right, climb, dive, fire, chart cursor) are a set
updated on key-down and key-up; losing window focus clears the set. One-shot presses ignore key
auto-repeat. In Flight and Docked modes each press is dispatched on the substep it arrives:

- pause; screen-selection keys; hyperspace and galaxy jump; chart keys — act at once;
- the flight actions listed in B.3.3 step 2 (only while not docked) are queued and acted on in the
  next tick logic, in order of arrival.

### B.6 Speed

The player's speed S is an integer. Each tick (step 2): if speed-up is held and S < 40, S ← S + 1;
then if slow-down is held and S > 1, S ← S − 1. So the keys keep S in 1..40 and change it by at
most 1 per tick (both held: no change except at the limits).

Speed is set to: 3 by every flight-state reset; 12 on launch; 1 by a failed slow docking (B.12.2);
0 during death. Hyperspace arrival therefore starts at speed 3. S is the distance in sim units the
player moves forward per tick.

### B.7 Motion of objects

#### B.7.1 Per-object motion state

| Field | Meaning |
|---|---|
| speed | own speed, 0..(the type's top speed); integer |
| acceleration | a one-off byte, read as a signed byte (128..255 mean −128..−1), applied and cleared each tick |
| roll counter, pitch counter | sign-magnitude bytes. Any non-zero magnitude makes the object turn by a fixed rate; magnitude 127 means "turn forever"; otherwise the magnitude counts down by 1 per tick to 0 |

The turn rate does **not** depend on the magnitude: any non-zero counter turns the object by
1/16 rad per tick about the relevant axis.

#### B.7.2 Per-substep movement (every substep with motion, h = 1/2)

Let ρ and φ be the player's current roll and pitch angles (B.5.3) and S the player's speed. For
each object in slot order:

1. **Own translation** (not for planets or the sun): position += nose · (1.5 · speed · h). (The
   nose vector is used as stored, not re-normalised.)
2. **Player rotation of the position** with ρ' = ρ·h, φ' = φ·h, applied in sequence (each line
   uses the values just computed):
   - k = y − ρ'·x
   - z ← z + φ'·k
   - y ← k − φ'·z
   - x ← x + ρ'·y
3. **Player translation**: z ← z − S·h.
4. If the object is the sun, stop here (its orientation is never changed).
5. **Player rotation of each orientation vector** (nose, roof, side), each in sequence:
   - y ← y − ρ'·x
   - x ← x + ρ'·y
   - y ← y − φ'·z
   - z ← z + φ'·y
6. **Own pitch**, if the pitch counter's magnitude is non-zero: rotate the pair (a = roof,
   b = nose) with σ = −1 if the counter's sign bit is set, else +1:
   - a' = a·(1 − h/512) + σ·(h/16)·b
   - b' = b·(1 − h/512) − σ·(h/16)·a (using the old a)
7. **Own roll**, if the roll counter's magnitude is non-zero: the same rotation on the pair
   (a = roof, b = side), using the roof just produced by step 6 and the roll counter's sign.

Planets go through steps 2, 3 and 5–7 (they spin; see B.9.2). With h = 1/2 the own-rotation
factors are 1 − 1/1024 and 1/32. These are not length-preserving (see Q-B1). Over a tick an
object therefore moves 1.5·speed sim units along its nose, and the universe rotates by about ρ
(roll) and φ (pitch).

#### B.7.3 Per-tick own-motion update (step 4 of B.3.4)

For every object that is not a planet or the sun:

1. speed ← speed + signed(acceleration); clamp to 0..(the type's top speed); acceleration ← 0.
   (A type with no top speed defined clamps to 0.) The clamp applies to every speed set
   elsewhere, so speeds above the type's top speed (from spawning rules) last at most until the
   next tick.
2. Pitch counter, then roll counter: if the magnitude is neither 0 nor 127, decrease it by 1,
   keeping the sign.

### B.8 Re-orthonormalisation

For each non-body object that is neither exploding nor killed, on ticks where
(C XOR slot) mod 16 = 0 (so every 16 ticks, staggered by slot), before its AI:

1. nose ← nose / |nose|.
2. roof ← roof − (roof · nose)·nose, then roof ← roof / |roof|.
3. side ← nose × roof (right-handed cross product:
   (n_y r_z − n_z r_y, n_z r_x − n_x r_z, n_x r_y − n_y r_x)).

A zero-length vector is left unscaled. Planets and the sun are **never** re-orthonormalised
(Q-B1). The baseline's vectors are floating point, so there is no rounding drift beyond the
non-length-preserving rotation; the original used fixed-point vectors on the same schedule.

### B.9 The bubble

#### B.9.1 Slots

The bubble holds at most **13** objects in an ordered list of slots 0..12. Outside the mis-jump
zone:

- slot 0 is the planet;
- slot 1 is either the sun or the station (never both; the station replaces the sun when it
  appears, and the sun replaces the station when it leaves);
- slots 2.. hold everything else, in the order added.

Adding an object appends it after the last occupied slot; if 13 slots are full the object is
silently not added (callers that care, e.g. the player's missile launch, react to that). Removing
an object closes the gap: all later objects shift down one slot (except the station, B.9.4). A
count of objects of each type is kept for the rules that ask "how many of type T are present".

In the mis-jump zone there is no planet, sun or station: slots 0.. hold only ships, and rules
that look for "the planet" or "the station" find none.

#### B.9.2 Kinds of object

Type numbers are part of the rules (several rules compare them numerically). Role names are
neutral; the designer names and retunes each type.

| Type | Role | Notes for this section |
|---|---|---|
| 1 | small pirate fighter A | |
| 2 | police interceptor | |
| 3 | small pirate fighter B | |
| 4 | heavy fighter | |
| 5 | bounty hunter (same hull model as the player's ship) | |
| 6 | alien mothership | |
| 7 | medium multi-role ship (same hull model as the player's ship) | also the abandoned hull at the escape pod |
| 8 | the station | top speed 0; cannot be destroyed |
| 9 | missile | never collides with the player through proximity |
| 10 | rock (asteroid) | |
| 11 | cargo canister | scoopable |
| 12 | alien drone | scoopable |
| 13 | escape pod | scoopable |
| 128 | planet, style A | style chosen by bit 1 of the system's tech level: set → style B |
| 129 | sun | |
| 130 | planet, style B | |

"Bodies" are types ≥ 128 (planets and the sun). Bodies never translate on their own, never take
the per-tick update of B.7.3, are never re-orthonormalised and are never removed for distance.
Planets are created with both counters at magnitude 127, positive, so they spin continuously at
1/16 rad per tick about both their pitch and roll axes. The sun is created with counters 0 and is
never rotated.

#### B.9.3 Object creation

A new object of a type starts with the type's energy and missile load (combat section), the
default orientation, speed 0, acceleration 0, counters 0 and AI byte 0, unless the creating rule
sets them. Many rules create an object from a **template**: they copy the template's position,
orientation, AI byte, speed and both counters into a fresh object of the wanted type.

#### B.9.4 Removal for distance

At the end of its processing each tick, a non-body object is removed if any coordinate has
|v| ≥ 65536 or a coarse value c(v) > 224 (that is, |v| ≥ 57600 on any axis).

When the removed object is **the station**, it is not shifted out; instead slot 1 is replaced by a
new sun placed at (0, 6·L, 0) relative to the player (default orientation, counters 0), the
station count drops, and the player is no longer in the safe zone. The per-object loop then
processes slot 1 (now the sun) in the same tick.

On any other removal, the player's own homing missiles in flight are retargeted: a missile aimed
at a later slot has its target slot reduced by 1; one aimed at the removed slot loses its AI (goes
dumb). The player's missile lock is then adjusted: lost (with the "target lost" message, combat
section) if it was on the removed slot, decremented if it was on a later slot. This lock
adjustment also runs after the station's replacement, where no shift happened (Q-B5).

### B.10 Placement of new objects

#### B.10.1 On arrival in a system (ordinary or galaxy jump)

The bubble is emptied, then:

- **Planet** (slot 0): let P (0..7), S (0..7) and X (0..3) be three small per-system values from
  the system generator (designer's job; in the baseline each is the low bits of one byte of the
  system's generator state). Let q = P + 6 + g, where g is bit 0 of the player's legal-status
  byte **before** it is halved on arrival (legal section). Let odd = q mod 2, n = ⌊q/2⌋ (3..7),
  m = ⌊n/2⌋ (1..3). Planet position: z = n·L; x = y = m·L, both negated if odd = 1. Default
  orientation, both counters 127.
- **Sun** (slot 1): z = −(S OR 1)·L (that is −1, −3, −5 or −7 L, behind the player); x = X·L + X·256;
  y = 0. Default orientation, counters 0.
- No station. Speed 3 (from the reset).

#### B.10.2 On launch from the station

The bubble is emptied, then: planet (style by tech level) at (0, 0, L), default orientation,
counters 127; the station at (0, 0, −256), i.e. 256 sim units behind the player, created as in
B.11.1 but with nose = (0, 0, 1), roof (0, 1, 0), side (1, 0, 0). The player is in the safe zone.
Speed 12. There is no sun until the station is removed for distance.

#### B.10.3 The encounter template

Used for police, pirates, hunters, alien motherships and death debris. Two draws:

1. Ordinary draw (A₁, X₁): position x = +8192 if bit 7 of A₁ is clear, else −8192; y = +8192 if bit
   7 of X₁ is clear, else −8192; z = +8192 (32 K ahead). AI byte = 0xC0 (AI on, aggression 32)
   OR 1 if X₁ ≥ 245 (E.C.M. fitted). Default orientation, speed 0.
2. Cleared draw (A₂, X₂): returned to the caller, which uses it next.

#### B.10.4 The alien mothership pair

Make a template (B.10.3), set its AI byte to 0xFF, add an alien mothership from it, then add an
alien drone from the same template (same position, AI byte 0xFF). Either add may fail if the
bubble is full.

#### B.10.5 Launch straight ahead

Used for the player's missiles and the abandoned hull at the escape pod: position (0, −28, 14)
(just below and ahead of the player), nose (0, 0, 1) (pointing away), side (−1, 0, 0), roof
(0, 1, 0); AI byte = 0x80 OR (target slot mod 32)·2; speed = (2 × player speed) mod 256 (then
clamped by B.7.3).

#### B.10.6 Children of a ship

Combat section (police leaving the station, loot canisters, enemy missiles, escape pods,
drones). Flight-relevant placement: a child copies its parent's position, orientation, speed and
counters; a child of the station is moved 192 sim units out along the station's nose and gets
speed 32; the child's roll counter has bit 0 cleared.

#### B.10.7 Death debris

See B.18.

#### B.10.8 Periodic spawning (when C reaches 0)

Specified fully here because it consumes the shared generator in a fixed order; the combat
section owns the meaning of the hostile choices. Not while dying. In the mis-jump zone: nothing
(no draws).

1. Ordinary draw → A₁. If A₁ < 35 and fewer than 3 rocks are present: **benign spawn**:
   1. Start a blank object at z = 9728 (38 K).
   2. Ordinary draw → (A₂, X₂), and note the carry K after it. x = (A₂ AND 127) + 512·K, negated
      if bit 7 of A₂ is set. y = X₂ AND 127, negated if bit 7 of X₂ is set.
   3. Ordinary draw → (A₃, X₃).
   4. If bit 6 of A₃ is set: add a **medium multi-role ship** with AI byte = ⌊A₃/2⌋ (so its AI is off, its
      E.C.M. bit is bit 1 of A₃), roll counter = ⌊A₃/2⌋, speed = (A₃ AND 31) OR 16. Done.
   5. Otherwise roll counter = A₃ OR 0x6F. If the station is present, stop (nothing spawns, no
      more draws). If bit 7 of A₃ is set, pitch counter = X₃ OR 0x7F; else speed =
      (X₃ AND 31) OR 16.
   6. Ordinary draw → A₄. Add a **rock** if A₄ ≥ 5, else a **cargo canister** (AI byte 0).
2. Otherwise: **hostile spawn**:
   1. If the station is present: stop (no draws).
   2. b = (2 × contraband score) mod 256 (legal section); if any police are present,
      b ← b OR legal-status byte.
   3. Template T₁ (B.10.3) → (a, x). If a < b, add a police interceptor from T₁.
   4. If any police are present now: stop.
   5. Extra-encounter delay E: E ← E − 1; if E ≥ 0, stop. Else E ← 0.
   6. Ordinary draw → A. If the system's government value G ≠ 0: stop if A ≥ 90; stop if
      (A AND 7) < G.
   7. Template T₂ → (a₂, x₂).
   8. If a₂ ≥ 200: a pirate pack: n = a₂ AND 3; E ← n; repeat n + 1 times: ordinary draw → Aₜ;
      add a ship of type (Aₜ AND 3) OR 1 (small pirate fighter A or B) from T₂. Stop.
   9. Else E ← E + 1; type = (a₂ AND 3) + 3. If that is the alien mothership: draw a byte; if
      ≥ 200, add a mothership pair (B.10.4, two more draws). Stop. Otherwise add that type from
      T₂ with AI byte 0xC0 OR (1 if x₂ ≥ 200).

E is set to 0 on ordinary arrival and by the in-system jump; it is not reset by a galactic
arrival (Q-B12). All ships of one spawn share one position.

### B.11 The station and its safe zone

#### B.11.1 The station appears

On ticks where C mod 32 = 0, outside the mis-jump zone, with no station present and a planet in
slot 0:

1. If any planet coordinate has |v| ≥ 65536: no station.
2. Candidate point Q = planet position + 49152 · planet nose (49152 = 2 × the planet's radius
   of 24576 sim units, along the planet's nose vector as stored).
3. If any |Qᵢ| ≥ 49152: no station.
4. Otherwise create the station at Q with nose = −(planet nose), roof = planet roof, side =
   planet side (copied as stored), AI byte 1 (E.C.M. fitted, AI off, friendly), pitch counter 0,
   roll counter 0xFF (magnitude 127, negative: it rolls continuously at 1/16 rad per tick and the
   counter never decays). It replaces the sun in slot 1 (the sun is discarded) and the player is
   in the safe zone.

Because the planet spins, the candidate point sweeps around the planet; the station appears on
the first 32-tick check at which the point is close enough. The station's slot faces the planet.

#### B.11.2 What the safe zone does

"In the safe zone" means "the station occupies slot 1". While it does:

- periodic spawning adds no hostiles and no rocks or canisters; only medium multi-role ships (B.10.8);
- pirates and hunters lose their aggression (combat section);
- the in-system jump is refused (B.13);
- the sun-heat check does not run and cabin temperature reads 30 (B.15);
- the compass points at the station instead of the planet; the dashboard shows a safe-zone
  indicator.

The player leaves the safe zone when the station is removed for distance (any axis ≥ 57600 sim
units, B.9.4). The station is otherwise permanent: it cannot be destroyed (lasers that take its
energy to 0 only make it hostile; the area blast skips it; a missile aimed at it is destroyed
harmlessly). A hostile station launches police (combat section).

### B.12 Docking

#### B.12.1 When docking is checked

During the station's processing each tick (B.3.4 step 6), if it is neither exploding nor killed
and all three of its coordinates have |v|ᵢ < 128 (the player is within a 128-sim-unit box around
the station's centre). There is no other collision between the player and the station's hull.

#### B.12.2 The checks

All four must hold for a successful docking (with unit vectors expressed in the original's
fixed-point scale where 96 = 1.0):

| # | Condition | Threshold | Meaning |
|---|---|---|---|
| 1 | the station is not hostile | AI bit 7 clear | |
| 2 | station nose z-component ≤ −86/96 (−0.8958) | within ≈ 26.4° | the slot faces the player |
| 3 | z-component of the unit vector from the player to the station's centre ≥ 89/96 (0.9271) | within ≈ 22.0° | the station is nearly dead ahead |
| 4 | \|station roof x-component\| ≥ 80/96 (0.8333) | within ≈ 33.6° of the player's ±x axis | the rolling slot is aligned with the player's wings |

The vectors are used as stored (tidied at most 16 ticks earlier). The test uses the player's
forward axis regardless of which view or mount is active.

Outcomes, in order:

1. All pass: dock (B.12.4). No further checks.
2. Any fail and S ≥ 5: the player dies.
3. Any fail and S < 5: S ← 1, and the player takes 5 damage (to the aft shield if the station's
   centre has z < 0, else the forward shield; overflow to energy as in the combat section). This
   repeats every tick the player stays in the box.

#### B.12.3 The auto-dock

The docking-computer action succeeds if the equipment is fitted, the station is present and it is
not hostile. It docks **instantly** (B.12.4) from anywhere in the safe zone, with no flight to the
station; otherwise the action does nothing. On success the rest of that tick's queued actions and
the laser are skipped, but the rest of the tick logic still runs (Q-B13).

#### B.12.4 Docking itself

The hyperspace countdown is cancelled; the launch-style tunnel runs (16 ticks); then the flight
state is reset (54 draws) and the player is docked, shown the status screen. Docking does not
change the market.

### B.13 In-system jump

On the in-system-jump action:

1. Let N = (objects in the bubble) − 2 − (rocks + escape pods + cargo canisters). If N > 0 (any
   other ship, missile or drone present), or the station is present, or the player is in the
   mis-jump zone: refuse with the long "no" beep. Nothing else happens.
2. For the planet, then the sun: if its z ≥ 0 and max(|x|, |y|, |z|) < 2·L: refuse (beep). A body
   behind the player (z < 0) never blocks.
3. Otherwise: planet z ← z − L and sun z ← z − L (the player leaps one far unit forward; other
   objects are not moved and so travel with the player); C ← 1; E ← 0; the flight scene is
   (re)selected for the current view, which also clears the bottom-line text and resets on-screen
   flags. No fuel or energy cost; no limit on repeats.

Because C is now 1 and the tick's chores decrement it, periodic spawning runs at the end of **the
same tick**, and the next tick has C = 0 (energy recharge and a station-appearance check).

### B.14 Altitude and crashing into the planet

On ticks where C mod 32 = 10 (outside the mis-jump zone):

1. If energy < 50, show the low-energy warning message (budget 16 characters).
2. Altitude ← 255.
3. If there is a planet and all of |x|, |y|, |z| < 65536:
   1. s = ⌊(c(x)² + c(y)² + c(z)²) / 256⌋ (coarse values).
   2. If s ≤ 255:
      - a = s − 37. If a < 0, the player dies (crashed).
      - alt = ⌊√(256·a + f(x))⌋ (f(x) is the fine value of the planet's **x** coordinate, see
        Q-B6). If alt = 0, the player dies.
      - Otherwise altitude ← min(255, alt).

The crash threshold corresponds to a centre distance of about 97 K (≈ 24 900 sim units), just
outside the planet's drawn radius of 96 K. Altitude is only updated, and crashes only detected,
every 32 ticks. The dashboard altitude bar shows ⌊altitude/16⌋.

### B.15 The sun: cabin heat and fuel scooping

#### B.15.1 Cabin temperature

On ticks where C mod 32 = 20 (outside the mis-jump zone):

1. Cabin temperature T ← 30.
2. If the station is **not** present, there is a sun, and all its |coordinates| < 65536:
   1. s = c(x)² + c(y)² + c(z)².
   2. If ⌊s/256⌋ > 255: T ← 31.
   3. Else T ← 255 − ⌊s/256⌋ + 30. If T > 255 (⌊s/256⌋ < 30), the player dies (burned up) and the
      tick ends.

So T rises from 30 to 255 as the sun gets closer; burning happens at a centre distance of about
87.6 K. The dashboard bar shows ⌊T/16⌋. There is no other heat damage in the baseline (Q-B7).

#### B.15.2 Fuel scooping from the sun

In the same check, after setting T: if T ≥ 224 (⌊s/256⌋ ≤ 61) and fuel scoop are fitted:
fuel ← min(70, fuel + ⌊S/8⌋), and the fuel-scooping message is shown (budget 16 characters; shown
even when nothing is gained). Fuel is in tenths of a light year (70 = full tank). Scooping needs
S ≥ 8 to gain anything and yields at most 5 units per 32 ticks at S = 40.

#### B.15.3 Scooping objects

In the proximity step (B.3.4 step 6), for a non-station object that is neither exploding nor
killed and is not a missile, with all |v|ᵢ < 64: if its type is ≥ 11 (canister, alien drone,
escape pod), fuel scoop are fitted **and** its y < 0 (it is below the player), it is scooped:

- canister: goods item = (byte AND 7) (one draw; items 0..7);
- alien drone: the alien-artefacts goods item (item 16);
- escape pod: the captives goods item (item 3).

If the hold has room (items 13 and above take no space), that item's count rises by 1 and the
item's name is shown as a message; otherwise a "no room" sound plays. Either way the object is
marked killed. Any other object in that box (including a canister when not scooped) is a
collision (combat section).

### B.16 Hyperspace

#### B.16.1 Starting a jump

The hyperspace action works in flight on any screen (while docked it shows a short "not while
docked" message instead). If a countdown is already running it does nothing.

- **Ordinary jump**: the system nearest the chart cursor is selected and its distance computed
  (navigation/galaxy section); a chart on screen is redrawn. If the distance is 0: nothing. If the
  distance > fuel: show the out-of-range line at the bottom of the scene (budget 20 characters);
  no countdown. Otherwise show the destination line (purpose: the destination announcement; budget
  32 characters including the name) and start the countdown.
- **Galactic jump**: requires the galaxy drive; it is consumed at once, the legal status
  is cleared to clean at once, and the countdown starts.

#### B.16.2 The countdown

Two counters: inner I and shown D. Start: I = 15, D = 15. Each tick (chores step), if D ≠ 0:
I ← I − 1; if I > 0 nothing more; else I ← 5, D ← D − 1, and if D = 0 the jump happens. So D shows
15 for 15 ticks, then each of 14..1 for 5 ticks; the jump happens 85 ticks (≈ 7.1 s) after the
key. D is displayed. The countdown runs in Flight and Death modes (Q-B3), pauses during tunnels
and the escape drift, and is cancelled only by docking or a return to the title.

#### B.16.3 The jump

- **Galactic**: the galaxy number advances by 1 (mod 8) and the galaxy generator moves to the
  next galaxy (galaxy section). The cursor is set to (96, 96), the system nearest to it is
  selected, and the player is placed at that system (distance 0). No fuel is used; no mis-jump is
  possible. A galactic-jump message is set, but is cleared on arrival before it can be seen
  (Q-B10). Hyperspace tunnel, then arrival (B.16.4).
- **Ordinary**: fuel ← fuel − (current distance to the selected system). Then draw a byte: if it
  is ≥ 253 (chance 3/256) the jump will mis-jump. Hyperspace tunnel (16 ticks), then either
  mis-jump arrival (B.16.5) or: the selected system becomes the current one (the player's galaxy
  coordinates become the system's), E ← 0, and arrival (B.16.4).

#### B.16.4 Arrival

1. Draw the market byte and regenerate the market (market section).
2. Reset the flight state (54 draws; speed 3; full shields and energy; cabin temperature 30;
   altitude 255; C = 0; message cleared; controls reset; bubble emptied; not in the safe zone; not
   in the mis-jump zone).
3. Halve the legal-status byte (legal section), keeping the bit shifted out as g.
4. Place the planet and sun (B.10.1).
5. Flight mode, front view (always; see Q-B10).

#### B.16.5 Mis-jump arrival (the ambush)

1. Reset the flight state (54 draws).
2. Enter the mis-jump zone. The player's galaxy coordinates are not moved to the destination;
   instead the y coordinate is XORed with 31. The current system's data and the market are
   unchanged; fuel has been spent.
3. While fewer than 4 alien motherships are present, add a mothership pair (B.10.4); stop early if
   an add fails. This normally gives 4 motherships and 4 drones in slots 0..7, each pair at one of
   the four template corners (±8192, ±8192, 8192).
4. Refill the stardust with 3 particles (9 draws).
5. Flight mode, front view.

In the zone: no planet, sun or station; no altitude, heat or scooping checks; no periodic
spawning; no station appearance; the in-system jump is refused; no bounties are paid (combat).
The player leaves by hyperspace (an ordinary jump from the modified coordinates, which can
mis-jump again and XOR y back) or galaxy jump. Using the escape pod here is fatal (B.17).

### B.17 The escape pod

On the escape-pod action, if a pod is fitted:

1. Remember whether the player is in the mis-jump zone. Cancel any pending prompts.
2. Empty the bubble and leave the safe zone; clear the missile lock (the "armed" state is not
   cleared).
3. Add the abandoned hull: a medium multi-role ship launched straight ahead (B.10.5) at the player's
   position offsets (0, −28, 14), then set its speed to 8, pitch counter 0xC2 (negative, magnitude
   66, decays to 0 after 66 ticks) and AI byte 0. (If the bubble was already full before step 2,
   no hull appears.)
4. Escape mode for 97 ticks (≈ 8.1 s). The controls are reset, so the scene rolls at a constant
   +3/256 rad per tick; the player's speed S stays at its value at launch. Each tick only the
   hull's own-motion update and its countdown run (C, energy and the hyperspace countdown are
   frozen).
5. The rest of the tick in which the pod was launched still runs (Q-B2).
6. When the 97 ticks are over: reset the flight state (54 draws). If the player was in the
   mis-jump zone, the player dies (death sequence, then the title with the last saved game).
   Otherwise: all cargo is lost, legal status becomes clean, the pod is used up, fuel is set to 70
   (full), and the player is docked at the current system's station (status screen). Cash,
   equipment, missiles and the market are kept.

### B.18 Death (flight-related parts)

When the player dies (crash, burn, failed fast docking, damage):

1. Remember k = ⌊S/4⌋. Reset the flight state (54 draws), then S ← k. Front view. C ← 255. Held
   keys and queued presses are cleared.
2. Four debris canisters: for each, make a template (2 draws, B.10.3) and take (A₂, X₂); position
   x = ⌊A₂/4⌋ AND 63, y = x XOR 42, z = x OR 80; roll counter = X₂ AND 0x8F; pitch counter =
   ⌊X₂/2⌋ AND 0x87; AI byte 0; nose (0, 0, 1), side (−1, 0, 0), roof (0, 1, 0); speed =
   (2k) mod 256; then draw a byte: if bit 0 is set the canister is marked killed (it explodes).
   Add it.
3. S ← 0. Death mode for 61 ticks (≈ 5.1 s), showing a game-over label (budget 10 characters).
   The tick logic runs in dying form (no keys, no player actions, no periodic spawning); then the
   title sequence restarts with the last saved game.

### B.19 Stardust

Stardust is visual, but it consumes the shared generator, so it must be simulated exactly.

#### B.19.1 Particles

Up to 18 particles (3 in the mis-jump zone), each (x, y, z). A **fresh** particle takes three
ordinary draws, A then X′ then Y′ (the A of each): x = (X′ − 128)·256, y = (Y′ − 128)·256, and
z = (A OR 8)·256 when refilling the whole cloud, or (A OR 144)·256 when respawning one particle.
Refilling (every flight-state reset; 3 particles at mis-jump arrival) creates fresh particles in
order. Dust moves only while the flight scene is displayed, once per substep, after the objects;
it uses ρ' = ρ·h, φ' = φ·h and s' = S·h, and the notional view v (B.20). Each line uses the
values just computed.

#### B.19.2 Front (v = 0) and rear (v = 1) views

Let e = +1 for front, −1 for rear.

1. z ← z − 64·s'·e.
2. q = min(255, 64·s' / max(1, z/256)).
3. y ← y + (y/256)·q·e; x ← x + (x/256)·q·e.
4. y ← y + e·ρ'·x; x ← x − e·ρ'·y.
5. x ← x + 2·(e·φ'·y/256)²/256; y ← y − e·φ'·65536.
6. Respawn if z ≤ 256, z ≥ 65280, |x| ≥ 32870.4 (120·256·1.07) or |y| ≥ 30720:
   - front: replace with a fresh particle (3 draws);
   - rear: make a fresh particle (3 draws) and set its z = (byte AND 127)·256 + 4096 (1 draw);
     then, if the old particle's z was ≥ 65280, replace it instead with another fresh particle
     (3 draws) whose z = 4096 + (byte AND 15)·256 (1 draw).

#### B.19.3 Left (v = 2) and right (v = 3) views

Let e = +1 for left, −1 for right.

1. q = min(255, 64·s' / max(1, z/256)).
2. x ← x + e·256·q.
3. x ← x + φ'·y; y ← y − φ'·x.
4. x ← x − ρ'·(x/256)·(y/256); y ← y + ρ'·(y/256)² + 256·ρ'.
5. Respawn if |x| ≥ 30720 or |y| ≥ 30720: a fresh particle (3 draws) with x = −e·30208.

z does not change in the side views. On switching from one view to a different one while the
flight scene is displayed, every particle's x and y are swapped.

### B.20 Views, mounts and the notional view

The baseline has four cockpit views (front, rear, left, right) selected by keys. The current view
selects which laser mount fires, the frame used for the crosshair test, the stardust behaviour,
and which objects are on screen (which affects render-time draws). A view switch also clears every
object's on-screen, on-scanner and firing flags.

**LodeStar difference (deliberate):** a third-person orbit camera replaces the cockpit views. The
four laser mounts remain; the player chooses the active mount 1–4 (front, rear, left, right), and
lasers fire only from that mount. For the rules, LodeStar keeps a **notional view** equal to the
active mount: selecting a mount does everything a view switch does in the baseline (flag clearing,
stardust x/y swap), and the crosshair test, stardust simulation and render-time draw counts
(B.4.4) use the notional view. "The flight scene is displayed" means the in-flight scene is on
screen rather than a chart, status, market or inventory screen. In the notional view frame, a
point (x, y, z) becomes: front (x, y, z); rear (−x, y, −z); left (z, y, −x); right (−z, y, x).

### B.21 Messages in this section

| Purpose | When | Budget |
|---|---|---|
| Low-energy warning | C mod 32 = 10, energy < 50 | 16 chars |
| Fuel scooping from the sun | each scooping check while T ≥ 224 with scoops | 16 chars |
| Scooped item name | an object is scooped with room in the hold | 16 chars |
| Hyperspace destination | ordinary jump accepted | 32 chars incl. system name |
| Out of hyperspace range | distance > fuel | 20 chars |
| Galactic jump | galactic countdown ends (never actually visible, Q-B10) | 20 chars |
| Cannot jump while docked | hyperspace action while docked | 24 chars |
| Game over | death sequence | 10 chars |

In-flight messages show for 22 ticks at the bottom of the flight scene; a new message replaces the
current one. The destination and out-of-range lines stay until the screen is changed or cleared.

### B.22 Baseline differences from the 1984 original (as relevant here)

- The original's main loop ran at roughly 10–12 iterations per second with one movement step; the
  baseline runs logic at exactly 12 Hz with two half-size movement substeps per tick, so the
  own-rotation step uses h/16 and 1 − h/512 per substep (Q-B1).
- Positions and orientation vectors are floating point (the original used 8/16/24-bit fixed
  point), so there is no rounding drift; objects are still re-orthonormalised on the original's
  16-tick schedule.
- The baseline is the cassette version: the auto-dock docks instantly.

### B.23 Quirks (reproduce these)

- **Q-B1 Non-length-preserving own rotation.** With h = 1/2 the own pitch/roll step scales a
  rotating pair's length by √((1 − 1/1024)² + (1/32)²) ≈ 0.99951 per substep (the original's
  full-step form is length-preserving). Ships are re-normalised every 16 ticks, so they shrink by
  up to ≈ 1.5% between corrections. Planets are never re-normalised and spin about two axes, so
  their orientation vectors keep shrinking (about 0.1% per tick; roughly halving per minute). The
  station's appearance point (B.11.1) uses the planet's nose as stored, so the longer the player
  stays in a system, the closer to the planet's centre a newly appearing station is placed, and
  the new station's vectors are copies of the shrunken planet vectors until its first
  re-normalisation.
- **Q-B2 Escape-pod tick remainder.** The pod is launched during the player-actions step; the rest
  of that tick still runs on the new bubble. The abandoned hull at (0, −28, 14) is inside the
  64-unit collision box, is not a missile and is not scoopable, so it is marked killed and the
  player takes collision damage of 128 + ⌊hull energy/2⌋ to the forward shield (hull z > 0). If
  this overflows into energy it can trigger the equipment-loss draw and even kill the player
  (aborting the escape). The killed hull is never processed again in escape mode, so it keeps
  drifting and is drawn normally. If the player's missile was armed, the hull may become the lock.
  Periodic spawning and the hyperspace countdown also get one more tick here.
  **LodeStar:** the abandoned hull is left out of collision tests on the launch tick, so none of this damage happens (deliberate difference 7).
- **Q-B3 Countdown survives death.** Dying does not cancel a running hyperspace countdown, and the
  countdown keeps ticking in Death mode. If it completes during the 61 death ticks, the jump
  happens: the death sequence is abandoned, the hyperspace tunnel runs and the player arrives
  alive, with the reset's full shields and energy.
  **LodeStar:** dying cancels the countdown (deliberate difference 5).
- **Q-B4 Re-targeting a running jump.** The status screen, the system-data screen and the
  chart's show-distance key each re-select the system nearest the cursor and recompute the
  distance. Doing this during a countdown changes the destination and the fuel cost with **no
  range check** (fuel can go negative) and no update of the destination line; selecting the
  current system makes a zero-cost jump to it (with a new market).
  **LodeStar:** range-checked, as deliberate difference 6 says.
- **Q-B5 Station removal adjusts the missile lock.** When the station leaves (B.9.4) no slots
  shift, yet the player's missile lock on a slot above 1 is decremented, so it moves to a
  different object. Homing missiles are not retargeted in this case.
- **Q-B6 Altitude uses the planet's x fine value.** The square root adds f(x) of the planet's x
  coordinate, not a fine part of the distance. Death by altitude 0 needs a = 0 and f(x) = 0.
- **Q-B7 Temperature readings.** Cabin temperature is 30 in the safe zone or when the sun is a far
  unit or more away on any axis, but 31 when the sun is within that box yet far. It is only
  updated every 32 ticks and is not touched in the mis-jump zone.
- **Q-B8 Speed limits.** Keys keep S ≥ 1; S = 0 only during death. A spawned speed above the
  type's top speed lasts until that object's next per-tick update.
- **Q-B9 Station is mirrored until re-normalised.** The station is created with nose (0, 0, 1) (or
  minus the planet's nose) but side copied unchanged, giving a left-handed frame; the first
  re-normalisation replaces side with nose × roof, flipping it. Rendering uses the side vector;
  docking checks do not.
- **Q-B10 Arrival always shows the front view.** Arrival intends to keep a chart on screen if one
  was showing, but the tunnel has already replaced the screen, so the flight scene (front view) is
  always shown. The galactic-jump message is cleared by the arrival reset before it is drawn.
- **Q-B11 Check order inside a tick.** Planet and sun deaths end the tick at once (no chores, no
  countdown); a failed fast docking or collision death does not (the per-object loop continues).
- **Q-B12 Extra-encounter delay.** E is reset by ordinary arrival and the in-system jump, but not by
  galactic arrival or mis-jump arrival.
- **Q-B13 Docking mid-tick.** After a successful docking (by proximity or computer) the rest of the
  tick still runs (other objects, spawning, chores) while the tunnel starts; anything that happens
  (bounties, kills, scooping, damage, even death) still takes effect.
- **Q-B14 Death mid-loop.** If the player dies during the per-object loop, the bubble is replaced
  by the death debris and the loop continues from the next slot number over that new list.
- **Q-B15 Pause and RNG.** While paused, the flight scene is still redrawn every substep, so a
  large sun on screen keeps consuming random bytes. The substep counter keeps counting while
  paused, so resuming can give one or zero motion substeps before the next logic substep instead of
  two.
- **Q-B16 Hull collisions.** There is no player–station hull collision except the 128-unit docking
  box; the player can fly through the station's outer hull.
- **Q-B17 In-system jump leaves companions.** Rocks, canisters and escape pods in the bubble are not
  moved by the jump and stay at the same position relative to the player.
- **Q-B18 Both opposing keys.** From centre with auto-centre on, holding both roll keys (or both
  pitch keys) gives no turn; with auto-centre off they also cancel (+7 −7, +14 −14) before damping.

## Open questions (section B)

1. **Planet orientation decay (Q-B1).** The baseline never re-normalises planets and its half-step
   rotation shrinks vectors. Whether the original re-normalised planets, and whether planets
   really spin at 1/16 rad per tick about two axes in the original, could not be confirmed from the
   baseline. Parity requires the baseline behaviour; the designer may want to decide whether
   LodeStar keeps it.
2. **Notional view for RNG parity (B.20).** Render-time and stardust draws depend on the baseline's
   cockpit view. This draft proposes a notional view equal to the active mount; the parity test
   harness must agree on this mapping (or compare RNG-independent behaviour only).
3. **In-system jump blocking test.** The baseline treats a body as blocking when z ≥ 0 and all
   |coordinates| < 2·L. The original may have tested the sign bytes in a way that also let negative
   x or y unblock the jump; the baseline's absolute-value form is specified here.
4. **Heat damage.** The baseline has no gradual damage from cabin heat (only death above 255).
   Whether the original drained energy at high cabin temperature is not settled here.
5. **Escape-pod collision (Q-B2), countdown through death (Q-B3) and jump re-targeting (Q-B4)**
   look unintended. They are specified because parity compares against the baseline; the designer
   may choose to fix them and record that as a deliberate difference.
6. **Message budgets** in B.21 are proposals sized to the 32-column flight scene, not measured from
   the baseline's text.

## C. Combat, AI, spawning, law and ranks

This section describes the rules for fighting, how non-player ships behave, how ships enter the local
space around the player, the legal system and combat rank. Everything here runs inside the 12 Hz logic
frame described in the flight section. Unless stated otherwise, "per frame" means once per 12 Hz logic
frame. All numbers are exact and are part of the rules.

### C.1 Conventions used in this section

**Coordinates.** The player's ship sits at the origin. +z points straight ahead out of the front mount,
+y up, +x right. Positions of other objects are in sim units, held as real numbers (the baseline uses
floating point for positions and orientation vectors). Every object has three unit orientation vectors:
*nose* (its forward direction), *roof* (its up direction) and *side*. A newly created ship's default
orientation is nose = (0, 0, −1) (pointing at the player), roof = (0, 1, 0), side = (1, 0, 0). Because
side is computed as nose × roof when vectors are re-orthonormalised, *side* points to the ship's own
left-hand side when the roof is up.

**Coarse magnitude.** Many tests look at a coordinate in units of 256 sim units. Define, for any
coordinate value v:

- fine(v) = floor(|v|) mod 256 (the low 8 bits of the integer magnitude),
- coarse(v) = floor(floor(|v|) / 256) mod 256 (the next 8 bits),
- far(v) is true when |v| ≥ 65 536.

Note that coarse() wraps: coarse(65 536) = 0. Where a rule says "coarse(x) = 0" it means exactly this
wrapped value, and the rule states separately whether far() is also checked. (In practice no non-planet
object survives with |coordinate| ≥ 57 600, see C.12, so the wrap matters only within the frame in which
something crosses that limit.)

**Rotation counters.** Each ship has a *pitch counter* and a *roll counter*, each an 8-bit
sign-and-magnitude value: bit 7 is the sign (set = "negative"), bits 0–6 the magnitude 0–127. Magnitude
0 means no rotation. Each motion substep with a non-zero magnitude rotates the ship by a fixed small
angle, independent of the magnitude (see the flight section for the step formula). With sign factor
s = −1 when the sign bit is set and +1 when it is clear, and k = dt/16, d = 1 − dt/512 (dt = 0.5 per
substep):

- pitch: roof ← roof·d + s·k·nose; nose ← nose·d − s·k·roof (both using the old values). A negative
  pitch counter therefore swings the nose towards the roof ("pull up").
- roll: roof ← roof·d + s·k·side; side ← side·d − s·k·roof. A negative roll counter swings the roof
  towards −side.

Once per frame (after the AI, see C.4) each counter whose magnitude is neither 0 nor 127 has its
magnitude reduced by 1, keeping its sign. A magnitude of 127 never decays (permanent spin).

**Ship speed.** A ship's *speed* (0–255, capped at its type's maximum) moves it 1.5 × speed sim units
per frame along its nose. The player's own speed (1–40) moves the whole universe 1 × speed sim units per
frame towards −z. Each ship also has a one-frame *acceleration* byte, read as a signed 8-bit value
(so 255 = −1, 254 = −2); once per frame it is added to the speed, the result is clamped to
[0, type maximum] and the acceleration is reset to 0.

**The frame counter.** A single 8-bit frame counter F counts down by 1 at the end of every flight
frame, wrapping 0 → 255. Every rule below that says "when F …" uses the value F has during the frame,
before that frame's decrement. Resetting the flight state sets F = 0, so the first flight frame runs with
F = 0 and ends with F = 255.

**The message timer.** A short in-flight message is shown by setting a message timer M = 22. M counts
down by 1 at the end of each flight frame (and each docked frame) and the message disappears when M
reaches 0. Several rules below are suppressed while M > 0.

**The local bubble.** Objects near the player live in an ordered list of at most 13 slots. In a normal
system slot 0 holds the planet and slot 1 holds the sun or, inside the safe zone, the station, leaving
11 slots for ships. Adding a ship appends it to the end of the list; if all 13 slots are full the add
fails silently (but any random numbers already drawn for it stay drawn). Removing a ship shifts every
later ship down one slot. A per-type count of ships in the bubble is kept (incremented on add,
decremented on removal) and used by several rules.

### C.2 The random number generator

#### C.2.1 The main generator

There is one main generator, shared by game logic and (in the baseline) some cosmetic drawing. Its state
is four bytes s0, s1, s2, s3 and a carry bit k. At game start s0 = 0x12, s1 = 0x34, s2 = 0x56,
s3 = 0x78, k = 0. (Tests may reseed s0..s3 directly; reseeding does not touch k.)

One **draw** does the following, all arithmetic on bytes:

1. t = ((s0 · 2) + k) mod 256; c = top bit of the old s0 (1 if s0 ≥ 128).
2. u = t + s2 + c. c = 1 if u > 255, else 0. New s0 = u mod 256. New s2 = t.
3. p = old s1. v = s1 + s3 + c. New k = 1 if v > 255, else 0. New s1 = v mod 256. New s3 = p.
4. The draw returns the pair (A, X) = (new s1, p).

So A is the new random byte and X is the previous value of s1, which (unless the generator was reseeded
in between) equals the A returned by the immediately preceding draw. Many rules use both halves of the
pair; this correlation is part of the rules and must be reproduced.

A **carry-cleared draw** sets k = 0 first and then performs a normal draw.

"Draw a byte" means perform a draw and use only A. "Draw a pair" means use both A and X.

#### C.2.2 The explosion-cloud generator (cosmetic)

Each exploding ship owns a private four-byte generator seeded from four main-generator bytes when its
explosion starts (C.12). It uses the same steps as the main generator except that the carry into step 1
is always 0 and no carry is kept between draws. It is re-seeded from the ship's four stored bytes every
time the cloud is drawn, so the cloud's particle pattern is stable. It never affects game logic.

#### C.2.3 Where the main generator is drawn by game logic

The exact draws are given with each rule. In summary, within one flight frame they happen in this order:

1. Firing the player's laser: 2 bytes (C.6.2).
2. For each slot in order, while processing that ship (C.4): 4 bytes if its explosion starts this frame;
   the AI's draws (C.5); 1 pair for the equipment-loss check whenever damage reaches the player's energy
   without killing (C.10.3); 1 byte when scooping a canister (C.11); when the player's laser destroys a
   ship of types 1–7, 1 pair for the canister roll plus 1 pair per canister actually created (C.12).
3. At the end of the frame, if the frame counter has just reached 0: the spawning draws (C.16).

Draws outside the flight frame that this section relies on: the player's death (C.10.4), the mis-jump
arrival (C.16.6), and every reset of the flight state, which regenerates the 18 stardust particles with
3 draws each (54 draws) — the flight section owns that rule but it changes the sequence seen here.

#### C.2.4 Where the baseline draws the main generator for cosmetic purposes

> **LodeStar:** every draw listed here comes from the separate cosmetic generator (deliberate difference 3).

The baseline also takes bytes from the main generator while drawing, which shifts every later logic
draw:

- moving stardust: each particle that leaves the view is regenerated with 3 draws, plus 1 more byte in
  the rear and side views for its depth (every motion substep while the flight view is showing);
- drawing the sun: 1 byte per screen row of the sun's disc when its screen radius is 16 or more;
- drawing an enemy laser beam: 1 byte for the beam's end point, once for each ship flagged as firing
  that is drawn in the current view (the firing flag is cleared after it is drawn).

LodeStar's orbit camera cannot reproduce these view-dependent draws. See the open questions.

### C.3 Ship roles and their stat fields

#### C.3.1 The thirteen ship types

Type numbers matter: several rules compare them (see the right-hand column). The designer gives each
type new art and stats but keeps the numbering and roles.

| Type | Role in this document | Rules that select by type number |
|---|---|---|
| 1 | small pirate fighter A | pirate packs; pacified in the safe zone (types < 7 except 2) |
| 2 | the police interceptor | police spawning; never pacified; killing one is an offence |
| 3 | small pirate fighter B | pirate packs and lone hunters |
| 4 | the heavy fighter (lone hunter) | lone hunters |
| 5 | the medium multi-role ship, hunter variant | lone hunters; same stats and model as type 7 |
| 6 | the alien mothership | lone-spawn slot "3" plus extra roll; launches drones instead of missiles; never ejects |
| 7 | the medium multi-role ship, trader variant | peaceful traders; hitting one angers the station. The player's own ship uses this model in the title and escape sequences |
| 8 | the station | docking, launching police; cannot be destroyed |
| 9 | the missile | missile AI; never collides |
| 10 | the asteroid | benign spawns; capped at 3 |
| 11 | the cargo canister | scoopable (types ≥ 11) |
| 12 | the alien drone | scoopable; drifts when no mothership is present |
| 13 | the escape pod | scoopable; heads for the planet |

Comparisons used by the rules: types 1–7 drop canisters and count as kills when shot down; types above
8 (9–13) ignore being angered; types 11–13 are scoopable; types 1, 3, 4, 5, 6 are pacified in the safe
zone; type 9 never takes part in collisions.

#### C.3.2 Stat fields (one record per type)

| Field | What it does | Range and relationships that matter |
|---|---|---|
| canisters | maximum cargo canisters dropped when the player's laser destroys the ship. It is used as a **bit mask** on a random byte (C.12), so values of the form 2ⁿ − 1 give an even spread from 0 | 0–7 in practice; unused for types above 7 |
| hit size | the square of the radius (in sim units) of the circle around the mount axis inside which the ship counts as in the sights (C.6.3) and can be locked by a missile | 16-bit value; if the missile's hit size is ≥ 784 the player's own missile is in the sights for its first moment of flight (see quirks) |
| gun point | which model point enemy laser beams are drawn from | cosmetic |
| explosion points | how many model points seed the explosion cloud | cosmetic |
| bounty | credit paid when the ship's explosion finishes, in tenths of a credit | 0 for the police and for traders; a canister or escape pod may have 0 |
| dot distance | beyond this coarse distance the ship is drawn as a dot | cosmetic |
| energy | starting and maximum energy (hit points). A ship regenerates 1 energy each time its AI runs. Half and one eighth of it (integer halving) are AI thresholds | 1–255. The station's value only matters for being reduced to 0 |
| speed | maximum speed | the station's must be 0. The missile's must exceed the player's top speed of 40 × (2/3) so it can catch targets; police should outrun traders; the escape pod is slow |
| normal scale | face-normal scaling for drawing | cosmetic |
| laser | laser power of the ship's gun | 0–31. Damage per enemy hit is floor((laser × 8 + missiles) / 2) = laser × 4 + floor(missiles / 2), with *missiles* taken from this record, not from what the ship has left |
| missiles | starting missile count; for the alien mothership, the number of drones it can launch | 0–7 (only 3 bits are kept: the count stored on the ship is this value AND 7). The station's value is never used for launching |
| model | vertices, edges, faces | designer's art; not part of the rules |

#### C.3.3 Per-ship state used by these rules

- **energy**, starting at the type's energy.
- **missiles left**, 0–7, starting at the type's missiles AND 7.
- **AI byte** (8 bits): bit 7 = AI active (the ship runs its AI); bits 1–6 = aggression 0–63; bit 0 =
  fitted with E.C.M. For a missile instead: bit 7 = active, bit 6 = hostile to the player, bits 1–5 =
  the slot number of its target. An AI byte of exactly 0 has a special meaning: the ship ignores being
  angered (C.5.6).
- **status flags**: killed, exploding, firing (cosmetic: draw a beam this frame), on screen, on scanner.
- speed, acceleration, pitch and roll counters (C.1), and the explosion cloud counter and seeds (C.12).

### C.4 What happens to each ship every frame

Motion is applied first, before the logic frame, in two substeps (flight section). Then, inside the
logic frame, after the player's keys have been read (C.6, C.7, C.8, C.9), every slot is processed in
order 0, 1, 2, …, up to the current length of the list. A ship added during the loop (a canister, a
missile, a pod, a launched police ship) is appended and is processed later in the same loop. When a
ship is removed, the loop processes the same slot number again, which now holds the next ship.

For each ship (planets and the sun skip the steps marked *ship only*):

1. **Area blast** (ship only): if the bomb is active (C.9) and the ship is not the station and is
   neither killed nor exploding, mark it killed and count a kill (C.13).
2. **Explosion start** (ship only): if the ship is marked killed but is not yet exploding, its explosion
   begins (C.12). This clears the killed flag.
3. **Tidy and AI** (ship only, skipped if killed or exploding):
   - if ((F XOR slot) AND 15) = 0, re-orthonormalise its orientation vectors (flight section);
   - if its AI is active and either it is a missile or ((F XOR slot) AND 7) = 0, run its AI (C.5).
     Ordinary ships therefore think once every 8 frames, staggered by slot; missiles think every frame.
     If the player died during the AI, stop processing this ship.
4. **Once-per-frame motion bookkeeping** (ship only): apply the acceleration to the speed and decay the
   rotation counters (C.1).
5. **Explosion progress**: if exploding, advance the cloud (C.12); when it is spent, mark the ship
   killed.
6. **Contact** (ship only, skipped if killed or exploding): see C.11.
7. **Sights** (ship only, only while the flight view is showing, skipped if exploding but not if
   merely marked killed): if the ship is
   in the active mount's sights (C.6.3), first the missile lock (C.7.1), then the laser hit (C.6.4).
8. **Removal**:
   - if the ship is both killed and exploding (its explosion has finished): if it is a police
     interceptor, set bit 6 of the player's legal status (legal status OR 64); pay its bounty (C.13);
     remove it.
   - otherwise, if any |coordinate| ≥ 57 600 (coarse > 224) or any far() is true, remove it silently.
     Removing the station replaces it with the sun (flight section) and leaves the safe zone.
   - after any removal, fix up missile targets (C.7.4).

### C.5 The ship AI

#### C.5.1 When the AI runs

Only for ships with AI bit 7 set, under the schedule in C.4 step 3. Ships without AI simply keep moving
with their current speed and rotation counters.

#### C.5.2 Special types (checked first, in this order)

1. **Missile**: run the missile AI (C.5.5) and stop.
2. **Escape pod**: steer (C.5.4) towards the direction from the player to the planet (the unit vector of
   the planet's position); if there is no planet, towards (0, 0, 1). The steer uses a pointing value of
   0 and does **not** adjust speed. Stop.
3. **Station** (only active when the station is hostile, i.e. its AI bit is set): draw a byte; if it is
   < 140, stop. Otherwise, if fewer than 4 police interceptors are in the bubble, launch one (C.5.7)
   with AI byte 0xF1 (active, aggression 56, E.C.M. fitted). Stop. Net chance of a launch attempt per
   station think: 116/256. The station never fires, never regenerates and never launches missiles.
4. **Alien drone with no alien mothership in the bubble**: clear its E.C.M. bit, halve its speed
   (integer), stop. Repeated every think, so it coasts to a halt.

#### C.5.3 Every other ship (including traders and drones that have been angered)

1. **Safe-zone pacification**: if the type is below 7 and not the police interceptor, and the station is
   present, AND the AI byte with 0x81 (aggression becomes 0, AI and E.C.M. bits kept). This is permanent:
   the aggression does not come back when the ship leaves the safe zone.
2. **Regeneration**: if energy < the type's energy, add 1.
3. **Pointing value**: let D be the unit vector from the player to the ship, and
   P = 36 × (nose · D). P is a real number in [−36, 36]; −36 means the ship's nose points straight at
   the player.
4. **Random roll**: draw a byte. If it is ≥ 250 (6 in 256), draw another byte a and set the roll counter
   to a OR 104 (magnitude ≥ 104, sign from a's top bit).
5. **Low energy** (only if energy ≤ floor(type energy / 2)):
   1. If energy ≤ floor(type energy / 8): draw a byte; if it is ≥ 230 (26 in 256) and the ship is not
      the alien mothership, set its AI byte to 0, launch an escape pod (C.5.7) with AI byte 0xFE, and
      stop. (The byte is drawn even for the mothership.)
   2. If missiles left ≠ 0: draw a byte b; if (b AND 31) < missiles left and no E.C.M. pulse is active
      (C.8), reduce missiles left by 1, then: the mothership launches an alien drone whose AI byte is a
      copy of the mothership's; any other type launches a missile with AI byte 0xFE (active, hostile,
      target bits 31, no E.C.M. bit) and, if the launch succeeded, the player gets the missile-alert
      warning (message about 16 characters, launch sound). Stop. The count is reduced even if the
      bubble was full and nothing was launched. (The byte is drawn only when missiles left ≠ 0.)
6. **Lasers**: only if every |coordinate| of the ship is below 8192 (coarse(x), coarse(y), coarse(z)
   all < 32, wrapped as in C.1). Let R = P rounded to the nearest integer with halves rounded up
   (towards +∞), so R ≤ −32 exactly when P < −31.5 and R ≤ −35 exactly when P < −34.5.
   - If R ≤ −32, set the ship's firing flag (a beam is drawn from its gun point).
   - If R ≤ −35, the shot hits: the player takes damage floor((laser × 8 + type missiles) / 2) from
     this ship (C.10.2), the ship's acceleration byte is decreased by 1 (wrapping, so normally it
     becomes −1), the hit sound plays unless an E.C.M. pulse is active, and stop.
7. **Choose a heading**. The ship is *close* when |z| < 768 and |x| < 512 and |y| < 512 (by
   coarse(z) < 3 and (coarse(x) OR coarse(y)) < 2). If it is not close, draw a byte, set its top bit
   (giving 128–255) and compare with the AI byte: if the result is less than the AI byte, the ship turns
   **towards** the player. Since the AI bit is set, the chance is (aggression × 2 + E.C.M. bit) / 128.
   A close ship never draws and always turns away.
   - Towards: target direction T = −D, and P is negated.
   - Away: T = D.
   Then steer towards T with pointing value P and speed adjustment on (C.5.4).

#### C.5.4 The steering rule

Given a target direction T (unit vector), a pointing value P and whether to adjust speed:

1. Pitch: set the pitch counter to magnitude 3, sign negative when roof · T ≥ 0, positive otherwise
   (the nose swings towards the target's up/down side).
2. Roll: only if the roll counter's current magnitude is below 16. Let q = (pitch counter is negative)
   and r = (side · T < 0). Set the roll counter to magnitude 5, negative exactly when q ≠ r.
   (This is the baseline's sign; see the open questions.)
3. Speed, if adjusting: if P ≥ 22, set acceleration +3. Otherwise, if |P| < 18, leave it. Otherwise set
   acceleration −2 for a missile, −1 for any other ship. P here is the unrounded value.

With these rules, a ship heading the way its nose already points speeds up, one pointing well away from
its chosen heading brakes.

#### C.5.5 Missile AI (every frame for each active missile)

1. If an E.C.M. pulse is active, the missile is destroyed (step 6), whoever owns it.
2. **Hostile missile** (bit 6 set):
   - if any of |x|, |y|, |z| ≥ 256 (any coarse ≠ 0): steer towards the unit vector of −position (straight
     at the player) with P = 36 and speed adjustment on (so it accelerates +3 every frame up to its
     type's top speed). Stop.
   - otherwise it hits: mark it killed, play the explosion sound, the player takes 250 damage (C.10.2;
     aft shield if the missile's z < 0). No kill is counted.
3. **Player's missile**: look up the ship in its target slot. If the slot is empty, set the missile's
   AI byte to 0 (it flies on straight, unguided, and can no longer be destroyed by E.C.M.) and stop.
4. Let Δ = missile position − target position. The missile is *close* when |Δx|, |Δy|, |Δz| are all
   below 256.
   - Not close: draw a byte; if it is < 16 and the target has E.C.M. fitted, the target fires its
     E.C.M. (C.8) and stop — the pulse destroys this missile on the next frame. (The byte is drawn every
     frame whether or not the target has E.C.M.) Otherwise steer towards −Δ/|Δ| with P = 36 and speed
     adjustment on. Stop.
   - Close: if the target is in slot 1 and is the station, the missile is destroyed harmlessly (step 6).
     Otherwise, unless the target is already exploding, mark the target killed; then destroy the
     missile (step 6). A missile kills its target outright whatever its energy; no canisters are
     dropped for a missile kill.
5. (Missiles never take part in collisions, C.11.)
6. **Destroying a missile**: if all of |x|, |y|, |z| < 1 the player takes 80 damage (aft shield if
   z < 0); count a kill (C.13), and mark the missile killed (it then explodes, C.12).

Every missile destroyed this way counts as a player kill, including enemy missiles destroyed by an
E.C.M. pulse and the player's own missile whether it hit or was destroyed by E.C.M..

#### C.5.6 Becoming angry

When the player's laser hits a ship, or the player fires a missile at it:

1. The station: set its AI bit (it becomes hostile). Done.
2. Types 9–13: nothing happens.
3. A trader (type 7): the station, if present, becomes hostile; continue.
4. If the ship's AI byte is exactly 0, nothing more happens (ships that launched an escape pod, and
   canisters, stay passive).
5. Otherwise set the AI bit, set acceleration +2 and set the pitch counter to +4.

#### C.5.7 Launching a child ship

A child ship (police from the station, an escape pod, a missile, a drone, a canister) starts as a copy
of its parent's position, orientation, speed and rotation counters, then:

- from the station: speed 32, moved 192 sim units along the station's nose;
- AI byte set as stated by the rule that launches it;
- roll counter AND 0xFE;
- a canister additionally draws a pair (A, X): pitch counter = (A × 2) AND 255, speed = X AND 15, roll
  counter = 127 with the sign of A's top bit (a permanent spin);
- the child is added to the bubble; if the bubble is full, the launch fails.

Children start at the type's full energy and with the type's missiles.

#### C.5.8 Behaviour by role (consequences of the rules above)

- **Traders** spawn with AI off and fly straight with their spawn roll. Once angered they fight with the
  aggression they were born with (always ≥ 16) and are not pacified in the safe zone.
- **Pirates and lone hunters** spawn with aggression 32 (50% chance to turn towards the player at each
  far think). In the safe zone their aggression is cleared permanently.
- **Police interceptors** from open space have aggression 32; those launched by a hostile station have
  aggression 56 and E.C.M. They behave exactly like pirates but are never pacified.
- **The alien mothership** spawns with AI byte 0xFF (aggression 63, E.C.M.), launches its drones when
  hurt, and never ejects. **Alien drones** fight like ships while any mothership exists, then drift.
- **The asteroid** and **canisters** have no AI and never act.
- **Escape pods** head for the planet and never speed up or slow down.

### C.6 The player's lasers

#### C.6.1 Mounts and laser types

The player's ship has four mounts: front, rear, left and right. Each holds nothing, a pulse laser or a
beam laser. Both laser types do **15 damage** per hit. The pulse laser can fire every second frame, the
beam laser every frame (below).

**Deliberate difference.** In the baseline the laser that fires is the one on the mount whose view is
on screen. In LodeStar the player selects the active mount (1 = front, 2 = rear, 3 = left, 4 = right)
and lasers fire only from that mount; the orbit camera does not change which mount fires. Every rule
below that the baseline ties to "the current view" uses the active mount instead.

#### C.6.2 Firing

The current shot's damage is reset to 0 at the start of each frame's key handling. The laser fires this
frame when all of these hold: the laser cooldown is 0, the fire control is held, the laser heat is
below 242, the active mount has a laser, and the flight view is showing (not a chart or status screen).
When it fires:

1. the shot's damage for this frame becomes 15; the laser sound plays;
2. draw two bytes for the cosmetic beam convergence point (x then y, each = centre − 4 + (byte AND 7));
   these draws must be kept for parity even if LodeStar draws its beams differently;
3. laser heat increases by 8, capped at 255;
4. the player's energy is drained by 1 (energy never falls below 1 this way);
5. the laser cooldown becomes 10 for a pulse laser, 0 for a beam laser.

At the end of every flight frame the cooldown decreases by 5 (not below 0), so a pulse laser fires on
every second frame while the trigger is held. Laser heat decreases by 1 at the end of every frame, in
flight and while docked. Overheating does no damage; it only stops firing until the heat falls below
242. (Cosmetic: the beam lines are erased at the end of a frame when the cooldown is below 8, so in the
baseline a beam laser's lines are never visible on a rendered frame.)

#### C.6.3 The sights test

A ship is in the sights of a mount when it is not exploding and, after turning its position into that
mount's frame (forward axis z′, lateral axes x′, y′):

| Mount | x′ | y′ | z′ |
|---|---|---|---|
| front | x | y | z |
| rear | −x | y | −z |
| left | z | y | −x |
| right | −z | y | x |

1. z′ > 0 (strictly in front of the mount; there is no range limit), and
2. |x′| < 256 and |y′| < 256, and
3. floor(|x′|)² + floor(|y′|)² ≤ the ship's hit size.

Geometrically this is an infinitely long cylinder of radius √(hit size) around the mount axis, also
clipped to a 512 × 512 square cross-section. Planets and the sun are never tested. The station can be
in the sights.

#### C.6.4 A laser hit

For every ship in the sights while the shot's damage is non-zero (so one shot hits **every** ship in the
cylinder in the same frame):

1. play the laser-impact sound; subtract 15 from the ship's energy;
2. if its energy is now ≤ 0: set it to 0; then
   - the station is not destroyed: it becomes hostile;
   - any other ship is marked killed; if its type is 1–7, draw a pair and, if A's top bit is set, create
     (A AND canisters) canisters as children (C.5.7, each drawing its own pair), then count a kill
     (C.13). Types 9–13 shot down give no kill and no canisters;
3. in every case (killed or not) the ship becomes angry (C.5.6).

### C.7 The player's missiles

#### C.7.1 Targeting and lock

The player carries 0–4 missiles. The controls are: *target* (arm), *unarm*, *fire*.

- **Target**: if no missile is locked and at least one missile is carried, the missile becomes armed
  (searching).
- While armed, the first ship in slot order that passes the sights test (C.6.3) of the active mount
  during the slot loop is locked: a beep plays, the lock records its slot number, armed is cleared. Any
  non-planet object can be locked, including the station, canisters and missiles.
- **Unarm**: if at least one missile is carried, clear both the lock and the armed state; long beep.

#### C.7.2 Firing

**Fire** does nothing unless a target is locked. Otherwise a missile is created at (0, −28, 14), with
nose (0, 0, 1), side (−1, 0, 0), roof (0, 1, 0), speed (2 × player's speed) AND 255, and AI byte
0x80 OR (target slot × 2) (active, not hostile, no E.C.M.). If the bubble is full, the launch-failed
message (about 14 characters) appears and nothing else changes. Otherwise the target becomes angry
(C.5.6), the lock is cleared, the missile count drops by 1, and the launch sound plays.

#### C.7.3 Guidance

See C.5.5. The missile steers every frame with P = 36, so its acceleration is +3 every frame until it
reaches its type's top speed (the launch speed may exceed it and is clamped at that frame's motion
bookkeeping).

#### C.7.4 When ships leave the bubble

When the ship in slot n is removed:

- every active, non-hostile missile targeting slot n loses its guidance (AI byte 0); one targeting a
  higher slot has its target slot reduced by 1 (keeping the other AI bits);
- if the player's lock was on slot n, the lock and armed state are cleared and a lock-dropped message
  (about 11 characters) appears; a lock on a higher slot moves down by 1.

### C.8 E.C.M.

There is one E.C.M. pulse timer for the whole bubble, plus a flag for "the player's own E.C.M. is on".

- **Player's E.C.M.**: if fitted and the timer is 0, set the player flag and start a pulse.
- **Starting a pulse** (player or a missile's target, C.5.5): timer = 32; E.C.M.-on sound. A pulse
  started while one is running restarts the timer at 32 and does not change the player flag.
- At the end of every flight frame: if the player flag is set, drain 1 energy; if that would take
  energy below 1 (energy was already 1), the pulse stops at once. Then, if the timer is > 0, decrease it;
  when it reaches 0 the pulse stops.
- **Stopping**: timer = 0, player flag cleared, E.C.M.-off sound.
- A pulse is *active* while the timer is > 0. Started during key handling, it is active for 32 frames
  of AI (that frame and the next 31), and the player's E.C.M. drains 32 energy.

While a pulse is active: every active missile (both sides) is destroyed when its AI runs (C.5.5); no
ship launches a missile or drone (C.5.3 step 5.2); the enemy-laser hit sound is suppressed. Missiles
whose AI byte is 0 (unguided) are not affected.

### C.9 The area blast

If fitted, triggering it removes it from the ship and makes the bomb active for 4 frames: the frame in
which it is triggered and the next three. While active, every ship processed in the slot loop that is
not the station, not killed and not exploding is killed and counted as a kill (C.4 step 1). This
includes police, missiles, canisters, asteroids, pods and drones, and ships that arrive during those
frames. The screen flashes while it is active (cosmetic). No canisters are dropped. The bomb's counter
is decreased after the slot loop.

### C.10 Shields, energy, damage and death

#### C.10.1 Levels and recharge

The player has a fore shield, an aft shield and an energy bank, each 0–255, all set to 255 when the
flight state is reset. When (F AND 7) = 0:

1. if energy ≥ 128 (checked once): if the aft shield < 255, raise it by 1 and drain 1 energy; then, if
   the fore shield < 255, raise it by 1 and drain 1 energy;
2. energy increases by 1, or by 2 with the energy booster, capped at 255.

Draining energy reduces it by 1 but never below 1. A low-energy warning (flight section) appears at a
fixed phase when energy < 50.

#### C.10.2 Applying damage

Damage of size n from an attacker:

1. The aft shield takes it if the attacker's z < 0, otherwise the fore shield.
2. If that shield ≥ n, subtract n and stop.
3. Otherwise n is reduced by the shield's value, the shield becomes 0, and energy is reduced by the
   remainder.
4. If energy ≤ 0, set it to 0 and the player dies (C.10.4).
5. Otherwise play the crunch sound and run the equipment-loss check (C.10.3).

Damage sources: enemy laser (C.5.3), hostile missile 250, missile destroyed next to the player 80,
collision 128 + floor(ship energy / 2), hitting the station badly 5.

#### C.10.3 Equipment and cargo loss

Draw a pair (A, X). Stop if A's top bit is set (half the time), if X ≥ 22, or if a message is showing
(M > 0). Otherwise:

- X = 0–16: if the hold has any of goods item X, set that item's amount to 0 and show the
  loss notice (item name plus about 10 characters);
- X = 17–21: E.C.M. unit, fuel scoop, area blast, energy booster, auto-dock
  respectively: if fitted, remove it and show the loss notice.

Remember that X is the generator's previous output (C.2.1).

#### C.10.4 The player's death

When energy reaches 0 from damage (or by the other fatal causes in the flight section):

1. play the death sounds; cancel any waiting prompt;
2. keep s = floor(player speed / 4); reset the flight state (this empties the bubble and makes 54
   stardust draws); set the player's speed to s; switch to the forward view; F = 255; clear input;
3. create 4 wreck canisters, each: perform the hostile template procedure (C.16.4, two draws) and take
   its returned pair (a, x); position x₀ = (a ÷ 4) AND 63, y = x₀ XOR 0x2A, z = x₀ OR 0x50; roll counter
   = x AND 0x8F, pitch counter = (x ÷ 2) AND 0x87; AI byte 0; nose (0, 0, 1), side (−1, 0, 0), roof
   (0, 1, 0); speed (2 × s) AND 255; draw a byte and if it is odd mark the canister killed (it explodes);
   add it;
4. set the player's speed to 0; run 61 more frames (round(5.1 × 12)) of flight processing with keys
   ignored and spawning suppressed; then return to the title and restore the last saved or loaded
   commander. An end-of-game banner (about 9 characters) is shown in the view.

If the player dies while the slot loop is running, the loop carries on from the next slot number over
the new bubble (the wreck canisters), and the rest of the frame runs.

#### C.10.5 The player's escape pod

If fitted, triggering it ends key handling for that frame and:

1. a copy of the player's ship model is placed at (0, −28, 14) facing away (as a missile launch); the
   bubble is emptied and the safe zone left; the missile lock is cleared;
2. the copy is re-added with speed 8, pitch counter 194 (negative, magnitude 66) and AI byte 0, and is
   watched drifting away for 97 frames (only it moves; no other rules run);
3. then the flight state is reset; if the player was in mis-jump space, the player **dies** instead
   (C.10.4); otherwise the hold is emptied, legal status becomes 0, the pod is used up, fuel becomes
   full (70 tenths), and the player is docked at the current system's station. Cash, kills, missiles
   and other equipment are kept.

### C.11 Contact: collisions, scooping and the station

For a ship that is not killed, not exploding and not a planet, and whose |x|, |y|, |z| are all < 256:

1. If all three (floored) are < 128:
   - the station: run the docking test (flight section). If it fails: if the player's speed ≥ 5 the
     player dies; otherwise the player's speed becomes 1 and the player takes 5 damage from the station.
     A hostile station always fails the test.
   - any other ship, if all three are < 64 and it is not a missile:
     - if its type is 11–13, fuel scoop are fitted and its y < 0 (below the player): scoop it — a
       canister gives goods item (byte AND 7) (one byte drawn), a drone gives goods item 16, a pod gives
       goods item 3; if there is no room (only items 0–12 take hold space) a crunch sound plays and
       nothing is gained; otherwise the item goes up by 1 and its name is shown. The object is marked
       killed either way.
     - otherwise it is a collision: mark the ship killed and the player takes 128 + floor(its energy / 2)
       damage from it; if the player survives, the crunch sound plays.

Collisions and scooping do not count kills. A scooped or rammed object then explodes like any killed
ship and pays its bounty when the explosion ends (C.12, C.13).

### C.12 Explosions and what they leave

1. **Start** (the first time a killed, non-exploding ship is processed): keep only its low six status
   bits (this clears the killed and firing flags) and set exploding; acceleration 0; pitch counter 0;
   cloud counter 18; draw four bytes as the cloud seeds.
2. An exploding ship keeps moving with its speed and roll, but runs no AI, cannot be hit or locked and
   does not collide.
3. **Each frame**: cloud counter + 4. When it exceeds 255 the ship is marked killed and is removed in
   the same frame with its bounty (C.4 step 8). Counting the start frame, an explosion lasts 60 frames
   (counter 22, 26, … 254, then 258).
4. **Remains**: canisters are created only at the moment the player's laser destroys a type 1–7 ship
   (C.6.4): a pair (A, X) is drawn; if A's top bit is set, (A AND canisters) canisters are launched from
   the ship's current place. Each canister draws its own pair for its spin and speed (C.5.7). The
   baseline has no asteroid fragments: a destroyed asteroid leaves nothing.
5. The cloud's look (cosmetic): its size grows with the counter and shrinks with distance; particles are
   scattered around the first *explosion points* of the model using the ship's private generator.

### C.13 Kills, bounties and credits

- **Counting a kill**: the 16-bit kill tally increases by 1 (wrapping 65 535 → 0) and the kill sound
  plays. When the low 8 bits of the tally become 0 (every 256 kills), a congratulation message (about 18
  characters) appears.
- Kills are counted for: laser kills of types 1–7, every ship caught by the area blast, and every
  missile destroyed (C.5.5 step 6). A missile kill counts the missile, not its target.
- **Bounty**: when a killed ship's explosion finishes, if no message is showing (M = 0) and the player is
  not in mis-jump space, the ship's bounty (tenths of a credit) is added to the player's cash; if the
  bounty is non-zero the cash-balance message (the cash to one decimal place, about 13 characters)
  appears for 22 frames. Because that message sets M, any other bounty that comes due while it shows is
  **lost**, including others finishing in the same frame.
- Ships removed for distance, or still exploding when the bubble is cleared, pay nothing.

### C.14 Combat rank

Rank is a function of the kill tally K (0–65 535):

| Rank | Kills |
|---|---|
| 0 | 0–7 |
| 1 | 8–15 |
| 2 | 16–31 |
| 3 | 32–63 |
| 4 | 64–127 |
| 5 | 128–511 |
| 6 | 512–2 559 |
| 7 | 2 560–6 399 |
| 8 | 6 400 or more |

Equivalently: if K < 256, rank = (number of binary digits of floor((K AND 255) / 4)) − 1, with 0 counting
as one digit; else with H = floor(K / 256): rank 8 if H ≥ 25, 7 if H ≥ 10, 6 if H ≥ 2, else 5. The rank
names are the designer's.

### C.15 Legal status and police

#### C.15.1 The value

Legal status L is a byte 0–255. Shown as: clean when L = 0, offender when 1 ≤ L ≤ 49, fugitive when
L ≥ 50.

Contraband value C = ((amount of goods item 3 + amount of goods item 6) × 2 + amount of goods item 10)
AND 255. (Items 3, 6 and 10 are the designer's illegal goods, two weighted double.)

#### C.15.2 How L changes

| Event | Effect |
|---|---|
| launching from the station | L ← L OR C (bitwise) |
| a police interceptor's explosion finishes (however it was killed) | L ← L OR 64 |
| arriving by a normal hyperspace jump | L ← floor(L / 2); the bit shifted out (L AND 1, before halving) is also passed to the arrival layout, where it adds 1 to the planet's placement value (flight section) |
| a mis-jump arrival | no change |
| starting a galaxy drive jump | L ← 0 (the arrival then halves 0) |
| a successful escape pod | L ← 0 |

There is no other decay. Shooting or angering police has no direct effect; only the end of a police
explosion does.

#### C.15.3 How police respond

Police appear only through the spawning rule (C.16.3) and from a hostile station (C.5.2). Once in the
bubble they attack like any hostile ship, whatever L is. A station becomes hostile when the player's
laser hits it, a missile is fired at it, or a trader is hit or targeted while the station is present.
A hostile station cannot be docked with (by hand or by the auto-dock) and keeps launching police
until it leaves the bubble; a newly created station is friendly again.

### C.16 Spawning

#### C.16.1 When

The spawning event runs at the end of a flight frame when the frame counter F has just been decremented
to 0, i.e. once every 256 frames (about 21.3 s), and never during the death sequence. The in-system jump
sets F = 1, so the event runs at the end of that same frame. Nothing spawns in mis-jump space (no draws
are made).

The spawn delay D is a signed counter, set to 0 on arrival in a system and on an in-system jump.

#### C.16.2 The event

1. Draw a byte a. If a < 35 and fewer than 3 asteroids are in the bubble, do the **benign spawn**
   (C.16.5). Otherwise do the **hostile spawn** (C.16.3).

#### C.16.3 The hostile spawn

1. If the station is present, stop.
2. Let B = (C × 2) AND 255. If any police interceptor is in the bubble, B ← B OR L.
3. Perform the hostile template procedure (C.16.4) → template and pair (a, x). If a < B, add a police
   interceptor made from the template.
4. If any police interceptor is in the bubble now, stop.
5. D ← D − 1. If D ≥ 0, stop. Set D = 0.
6. Draw a byte g. If the current system's government type (0–7) is not 0: stop if g ≥ 90, and stop if
   (g AND 7) < government. Government 0 always continues.
7. Perform the hostile template procedure → template and pair (a, x).
8. If a ≥ 200: a **pirate pack**. n = a AND 3; D = n; for each of n + 1 ships draw a byte t and add a
   ship of type (t AND 3) OR 1 (pirate fighter A or B, evenly) made from the same template (all at the
   same place). Stop.
9. Otherwise D ← D + 1, the type is (a AND 3) + 3, and the AI byte is 0xC0, plus the E.C.M. bit if
   x ≥ 200.
   - Type 6 (the alien mothership): draw a byte; if it is ≥ 200, perform the alien group spawn
     (C.16.6). Stop.
   - Types 3, 4, 5: add one ship of that type made from the template, with that AI byte.

The resulting chance that step 6 continues, per government type, out of 256:

| Government | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|---|
| continues | 256 | 78 | 66 | 55 | 44 | 33 | 22 | 11 |

After a pack of n + 1 ships, the next n events skip hostile spawns at step 5; after a lone ship (or a
failed alien roll) the next event skips. Police spawning (steps 2–4) is not affected by D.

#### C.16.4 The hostile template procedure

1. Draw a pair (a, x).
2. Template position: x = 8192 × (−1 if a's top bit is set, else +1); y = 8192 × (−1 if x's top bit is
   set, else +1); z = 8192. Default orientation (nose at the player), speed 0, counters 0.
3. Template AI byte: 0xC0 (active, aggression 32), plus the E.C.M. bit if x ≥ 245.
4. Perform a carry-cleared draw and return its pair (a′, x′) to the caller as "(a, x)".

Note that the returned x′ is the a of step 1. A ship "made from the template" copies its position,
orientation, AI byte, speed and counters, and gets its type's energy and missiles.

#### C.16.5 The benign spawn

1. Start a template at z = 9728 (38 × 256) with AI byte 0, speed 0 and default orientation.
2. Draw a pair (p, q) and note the generator's carry k after it. x = ±((p AND 127) + 512·k), negative
   when p's top bit is set; y = ±(q AND 127), negative when q's top bit is set. (Because q is the
   previous output, which here is the event's byte a < 35, y is always 0–34 in practice.)
3. Draw a pair (b, b′).
4. If b AND 64 ≠ 0: a **trader** (type 7) from the template with AI byte b ÷ 2 (integer; AI off, E.C.M.
   when b's bit 1 is set, aggression (b ÷ 4) AND 63, always ≥ 16), roll counter b ÷ 2 (positive,
   magnitude 32–127) and speed (b AND 31) OR 16. Add it. Stop.
5. Otherwise set the template's roll counter to b OR 0x6F.
6. If the station is present, stop (nothing spawns; the draws are spent).
7. If b's top bit is set, pitch counter = b′ OR 0x7F (a permanent spin, sign from b′'s top bit; speed
   stays 0); otherwise speed = (b′ AND 31) OR 16.
8. Draw a byte c. Add an asteroid if c ≥ 5, otherwise a cargo canister. (Both have no AI and head
   towards the player along the default nose.)

#### C.16.6 The alien group, and mis-jump space

**Alien group spawn**: perform the hostile template procedure, set the template's AI byte to 0xFF, then
add an alien mothership and then an alien drone, both made from the template.

**Mis-jump arrival** (the jump itself is in the flight section): reset the flight state (54 stardust
draws, empty bubble, no planet, sun or station), mark the player as in mis-jump space, flip the low five
bits of the player's galactic y coordinate (y XOR 0x1F), then repeat the alien group spawn while there
are at most 3 motherships (stopping early if an add fails), which gives 4 motherships and 4 drones;
then regenerate the stardust with 3 particles (9 draws). In mis-jump space nothing else spawns,
no bounties are paid, and kills still count.

#### C.16.7 The station appearing

Every 32 frames (when (F AND 31) = 0), outside mis-jump space and while no station is present, the
station is placed if the player is near the planet. The flight section gives the geometry; it makes no
random draws.

#### C.16.8 Caps

| Cap | Value |
|---|---|
| ships in the bubble (including planet and sun or station) | 13 slots |
| asteroids, for the benign spawn to happen at all | fewer than 3 |
| police launched by a hostile station | fewer than 4 in the bubble |
| police from open space | one per event, and only if none is present after the attempt does anything else spawn |
| motherships in mis-jump space | 4 |
| player missiles | 4 |

### C.17 Quirks and edge cases

1. **Generator pair correlation.** X is always the previous output. Rules that use X (equipment loss,
   template signs and E.C.M., benign y, lone-hunter E.C.M.) depend on the preceding draw.
2. **Draw order is short-circuit.** In the AI's low-energy step, the escape byte is drawn only when
   energy ≤ one eighth, and the missile byte only when missiles left ≠ 0. The heading byte is drawn
   only when the ship is not close. A player missile draws its E.C.M. byte every frame it is not close,
   even if the target has no E.C.M.
3. **Rounding of P** for the laser test rounds halves towards +∞ (−34.5 → −34). The speed rule uses
   the unrounded P.
4. **Enemy damage uses the record's missiles,** not the ship's remaining missiles.
5. **One shot hits everything in line.** The laser damages every ship in the sights in the same frame.
6. **Own missile in the sights.** The player's missile starts at (0, −28, 14), inside the front sights
   whenever the missile type's hit size is ≥ 784; a laser shot (or an armed lock) in the next frames can
   hit (or lock) the player's own missile.
7. **Missile kills count the missile.** Destroying any missile counts as a kill, so E.C.M.-ing enemy
   missiles raises rank.
8. **Bounties need a quiet message line.** Any message showing at the moment an explosion ends forfeits
   that bounty. The bomb usually pays only one bounty.
9. **Shot-down light objects.** Shooting a missile, asteroid, canister, drone or pod gives no kill and no
   canisters, but pays its bounty when the explosion ends.
10. **Scooped or rammed objects explode** (in the baseline) and pay their bounty.
11. **Pacification is permanent** and happens only while the station is present; it applies to the alien
    mothership too, but not to police or traders.
12. **Failed launches.** An enemy's missile count drops even when the bubble is full; the player's does
    not (the launch-failed message appears instead).
13. **Station hit to 0 energy** stays at 0 and becomes hostile; it is never destroyed by laser. A missile
    reaching the station in slot 1 is destroyed harmlessly (and counts as a kill).
14. **Coarse wrap.** coarse() ignores bits above 16, so a value ≥ 65 536 can look "near" to the AI laser
    and missile tests for the frame before it is removed.
15. **Benign x offset.** The benign spawn adds 512 to |x| when the generator's carry is set after the
    position draw.
16. **Player death mid-loop**: see C.10.4.
17. **Escape in mis-jump space kills the player.**
18. **Kill tally wraps** at 65 536, back to rank 0.
19. **Removal re-processing.** When the station is removed for distance, the sun takes its slot and is
    processed in the same frame.
20. **Killed but not yet exploding.** A ship marked killed earlier in its own processing (by a
    collision in step 6) can still be hit by the laser in step 7 of the same frame; if that takes its
    energy to 0 it counts a kill and may drop canisters.
21. **Destroyed-missile damage** applies only when the missile is within 1 sim unit on all three axes,
    which practically never happens.

### C.18 Deliberate differences recorded for this section

- Lasers fire, and the sights test and missile lock are evaluated, on the active mount (1–4) chosen by
  the player, not on the mount whose view is on screen (C.6.1). The orbit camera does not affect any
  combat rule. Everything about which shield takes damage is relative to the player's ship (attacker
  z < 0 = aft), not the camera.
- Names, text, ship art and ship stats are new (designer's job); the type numbering, roles and every
  number in this section are kept.

### Notes on where the baseline differs from the 1984 original

- The baseline runs logic at 12 Hz with two motion substeps per frame; the pulse laser's cooldown is
  counted in frames (−5 per frame) rather than by the original's faster interrupt.
- Positions and orientation vectors are real numbers rather than 8/16-bit values.
- The original's destroyed-missile proximity test looks only at the low 8 bits of each coordinate;
  the baseline requires each |coordinate| < 1 (C.5.5 step 6). Follow the baseline.
- The baseline's roll steering sign was chosen to make its own missile test pass (see the open
  questions).

## Open questions (section C)

1. **Cosmetic draws on the shared generator.** The baseline takes main-generator bytes while drawing
   stardust, the sun's edge and enemy laser beams (C.2.4). These depend on which view is on screen and
   on screen-space geometry, so an orbit camera cannot reproduce them. Recommendation: LodeStar moves
   all cosmetic randomness to its own generator, and parity tests compare logic only with the baseline's
   cosmetic draws disabled, or with a baseline harness that stubs them out. The stardust regeneration
   on a flight-state reset (54 draws) and on a mis-jump (9) is not view-dependent, so it can be kept as
   54 and 9 "discarded" draws. The coordinator should decide.
2. **Missile lock axis.** The baseline locks on whatever is in the sights of the view on screen. I have
   assumed LodeStar locks on the active mount's axis, consistent with the laser rule. Confirm.
3. **Flight-view gating.** In the baseline lasers and locks work only while the flight view is on
   screen (not on charts). If LodeStar shows charts as overlays during flight, it must decide whether
   combat input still works.
4. **Roll steering sign.** By my reading of the rotation rules, the baseline's roll choice turns the
   roof away from the target's sideways component (a quick simulation shows ships still converge on a
   target, but more slowly than with the opposite sign). The baseline comment says the sign was picked
   to make a test pass. Parity requires the baseline's sign; flag it if the designer wants the original
   behaviour instead.
5. **Asteroid fragments.** The task mentions fragments, but this version has no fragment type; a
   destroyed asteroid leaves nothing. If LodeStar wants fragments, that is a new feature, not parity.
6. **Scooped objects explode.** In the baseline a scooped canister, drone or pod is marked killed and
   then plays a full explosion and pays its bounty. I did not confirm whether the 1984 original removed
   scooped objects silently. Parity follows the baseline.
7. **Type 4's role name.** Settled: type 4 is the heavy fighter in every section, since in this version it only ever spawns as a lone hunter.
8. **Death mid-loop.** When the player dies during the slot loop, the baseline keeps looping over the
   new bubble (the wreck canisters) from the next slot number, and the rest of that frame (recharge,
   counters) still runs. This is reproducible but probably not intended; keep it for parity.

## D. Game modes, controls, screens, messages, sound cues and time

This section describes the game's overall state machine, everything the player can do and when,
what each screen must show, every message, the dashboard, the scanner and compass, the sound
cues, pausing, saving, and the timing of all of these. Numbers given here are rules and must be
reproduced exactly. Wording, layout, fonts and colours of screens are the designer's; only the
information content, triggers, timings and length budgets are fixed.

Terms used throughout:

- **tick**: one 12 Hz logic step (1/12 s). All durations in this section are in ticks unless
  stated otherwise.
- **substep**: half a tick. Each tick is made of two substeps, A then B (see D.1).
- **main counter**: an 8-bit counter that decreases by 1 (wrapping 0 -> 255) once per tick, in
  flight and while docked. Many periodic checks are keyed to its low bits ("phase").
- **message timer**: the countdown that controls how long the current in-flight message is
  shown.
- **bubble**: the list of objects around the player (planet, sun or station, ships, debris), at
  most 13 entries; the planet is always entry 0 when present and the station or sun is entry 1.
- **current system**: the system the player is at. **Selected system**: the system the chart
  cursor last snapped to; it is the hyperspace destination.

---

### D.1 Time base: 12 Hz logic with two motion substeps

The original's main loop ran at roughly 10-12 frames per second. The baseline fixes the logic at
exactly 12 ticks per second and splits each tick into two substeps, moving everything by half a
step and redrawing after each, so motion looks smoother. This is a deliberate difference of the
baseline from the 1984 original, and parity depends on it.

Per substep the driver does, in this order:

1. Advance a substep counter (starts at 0; the first substep after start-up is number 1). A
   substep whose new count is even is a **logic substep** (substep B); an odd one is substep A.
   So substep A always precedes substep B within a tick, and the first substep ever run is an A.
2. Take every key press queued since the previous substep (one-shot presses, in arrival order).
3. If paused: hand each press to the pause handler (D.3.12), redraw, and stop here.
4. Otherwise run the branch for the current mode (D.2). In the ordinary docked/flight branch:
   1. Dispatch each press (to a waiting prompt, to a prompt's queue, or to the game's key
      handler; see D.4.4).
   2. In flight: move every object and the dust by half a step using the player's current roll
      angle, pitch angle and speed (the values computed by the most recent tick's logic).
   3. On a logic substep: in flight run the full flight logic (D.3.6); when docked run the docked
      chores (D.3.3).
   4. On a logic substep: increase the **display frame counter** by 1 (used only for flashing
      indicators and the held chart cursor). This counter only advances in the docked and flight
      modes.
   5. Redraw.

Consequences that matter for parity:

- In flight, motion happens before logic in substep B, and in substep A motion happens with no
  logic at all. The angles and speed used for both half-moves of tick N are those set by the
  logic of tick N-1.
- In the death sequence the order is reversed: the (dying) flight logic runs first, then the
  half-move (D.3.10).
- One-shot flight actions (D.4.2, "queued" actions) pressed in substep A wait until the logic of
  substep B of the same tick; those pressed in substep B are processed in that same substep's
  logic, because key dispatch precedes logic.
- Screen-changing actions (views, charts, status screens, launch, hyperspace key) take effect in
  the substep in which they are dispatched.
- Held controls (roll, pitch, speed, fire) are sampled only inside the tick logic.

Real-time pacing in the baseline: substeps are scheduled at 24 per second (1000/24 ms each)
against a time accumulator; the elapsed time added per display frame is capped at 250 ms and at
most 4 substeps run per display frame, so a slow host slows the game rather than skipping logic.
The screen is presented after the substeps of a display frame. A headless implementation steps
substeps directly.

Exception to tick-based timing: the shop confirmation pause (D.6.11) is a wall-clock 1000 ms
delay in the baseline (equivalent to 12 ticks); the game keeps ticking during it.

---

### D.2 Modes and the state machine

The game is always in exactly one mode. Pause is a flag layered on top of the docked and flight
modes. While docked, a modal prompt ("capture") can own the keyboard.

| Mode | What runs each tick | Player input |
|---|---|---|
| Title | the title ship animation only | the first press answers the prompt; all others in that substep are discarded |
| Docked | docked chores (D.3.3) | full docked action set; or, while a prompt captures the keyboard, everything goes to the prompt |
| Tunnel | one tunnel step per tick (launch, docking or hyperspace) | none: all presses are discarded; held keys are ignored |
| Flight (normal space, or the ambush state) | half-moves every substep, full flight logic on each tick | full flight action set |
| Death | dying flight logic (no player controls) then half-move | none: input is cleared at death, later presses are discarded |
| Escape | the abandoned ship drifts; nothing else | none: presses are discarded |

Transitions:

| From | Trigger | To | Timing |
|---|---|---|---|
| (start-up) | page load | Title, load prompt | immediately |
| Title, load prompt | the "yes" answer | Name entry (Docked mode with capture) | immediately |
| Title, load prompt | any other key | Title, start prompt | immediately |
| Name entry | confirm or cancel | Title, start prompt | after the name is processed (D.12) |
| Title, start prompt | any key | Docked, status screen | immediately |
| Docked | launch action | Tunnel (launch) -> Flight | 16 tunnel steps (D.3.4) |
| Flight | docking succeeds (contact or auto-dock) | Tunnel (docking) -> Docked, status screen | 16 tunnel steps |
| Flight | hyperspace countdown expires | Tunnel (hyperspace) -> Flight in the new system, or the ambush state | 16 tunnel steps |
| Flight | escape pod used | Escape -> Docked (or Death if used in the ambush state) | 97 ticks |
| Flight | death cause (D.3.10) | Death -> Title | 61 ticks |
| Docked or Flight | pause action | same mode, paused | immediately |
| Paused | resume | same mode, unpaused | immediately |
| Paused | quit | Title (load prompt), flows cancelled | immediately |

Every transition into Title cancels any prompt flow in progress (prompt flows check a flow
generation number and abandon themselves when it has changed).

---

### D.3 Each mode in detail

#### D.3.1 Title sequence

Two title screens are shown in turn. Each shows a rotating ship model approaching the camera,
the game's title banner, an optional credits line (toggled from the pause handler; not
reachable on the title itself), a prompt line, and a copyright/credits line. The dashboard frame
is drawn with nothing on the scanner, no compass and no bulbs.

1. **Load prompt** (first ship model: the player's ship type, also flown by traders). The prompt
   asks whether to load a saved commander, with a yes/no answer.
   - The first press in a substep is the answer; a pointer/touch press counts as a space. The
     answer "yes" (baseline: the Y key) starts name entry; any other key skips loading.
2. **Name entry** (only after "yes"): the game switches to Docked mode with the keyboard
   captured, clears the view and shows the name prompt (D.6.12). On confirm, the stored
   commander under the typed name is looked up; an empty name means "the name of the last saved
   or loaded commander". If a record exists and passes its integrity check, it becomes the
   "last saved or loaded commander". Otherwise nothing changes and no message is shown.
3. The commander being played becomes a fresh copy of the last saved or loaded commander (the
   default commander if none). Flight controls and the whole flight state are reset (D.3.13).
4. **Start prompt** (second ship model: a pirate fighter type). The prompt invites the player to
   press fire or space; in fact any key (or a pointer press) continues.
5. The current system becomes the system nearest to the commander's stored galactic
   coordinates (the chart cursor snaps to it, the selected system is the same, distance 0, the
   extra-vessel spawn delay is set to 0), the bubble is emptied, and the player is docked
   (D.3.3) on the status screen.

Title ship animation, per substep (both substeps):

- The ship starts at distance 96 x 256 sim units straight ahead, centred, with its roll and
  pitch counters both set to the "rotate continuously" value 127 (see the ship-motion section),
  and the player's roll rate reset to its centre value with the roll angle reset to +3/256.
- Each substep: if its distance is at least 512 sim units, reduce it by 256. Then move it as a
  normal object would be moved for half a step with roll angle 3/256, pitch angle 0 and player
  speed 0. Then clamp its distance to at least 384 and force its sideways and vertical position
  to 0.
- On logic substeps only: apply the ship's own rotation step (its roll and pitch counters), and
  every 16th tick (when the substep count / 2 is a multiple of 16) re-orthonormalise its
  orientation.
- So the ship approaches from 96 x 256 to 256 sim units in 95 substeps (47.5 ticks) and then
  stays at the near limit, rotating.
- There is no time-out: each title screen waits for a key indefinitely.

#### D.3.2 Entering the docked state

Whenever the player becomes docked (after the title, after docking, after the escape pod):

1. Docked flag on, mode Docked.
2. The hyperspace countdown is cleared (both its internal step and its displayed value).
3. The status screen is shown, which first re-selects the system nearest the chart cursor
   (snapping the cursor) before drawing.

#### D.3.3 Docked mode

Docked chores, once per tick:

1. Laser temperature decreases by 1 if above 0.
2. The main counter decreases by 1 (wrapping).
3. If the long-range or local chart is showing and the display frame counter is even,
   the held chart-cursor directions are applied (at most one step in x and one in y), and the
   chart is redrawn if the cursor moved. (So holding a cursor direction moves it 6 times a second
   while docked.)
4. If the message timer is above 0, decrease it; when it reaches 0 the message is cleared.

Nothing else runs: no energy recharge, no spawning, no countdown. While docked the bubble is
empty, the station-present bulb is off, and the compass is blank.

#### D.3.4 Tunnels (launch, docking, hyperspace)

A tunnel plays one of two animations: the launch/docking tunnel (concentric polygonal rings) or
the hyperspace tunnel (concentric round rings in cycling colours). Rules:

1. Starting a tunnel plays the launch sound (launch and docking) or the hyperspace sound, sets
   the mode to Tunnel, clears the bottom line of the space view (D.6.1), clears the space view,
   and resets the tunnel step to 0.
2. On each later logic substep, one tunnel step is drawn and the step count increases; after the
   16th step (step index 15) the tunnel's completion action runs in that same substep.
3. The first step is drawn on the next logic substep after the one in which the tunnel was
   started. A tunnel started from substep A (e.g. a launch key pressed in substep A) therefore
   draws its first step in substep B of the same tick; one started from substep B (anything
   started by tick logic, such as docking, the hyperspace jump, or a key pressed in substep B)
   draws its first step on the next tick.
4. During the tunnel only the dashboard is redrawn (with live values); no overlays (countdown,
   messages) are drawn; all presses are discarded.

Visual rule (for the designer's own animation, not a parity item): step k draws rings whose
radius starts at 8 + (k mod 8) and doubles until it passes 160 (view half-width units); the
hyperspace version colours ring i with colour (i + k) mod 4 of a 4-colour cycle.

Launch completion action:

1. Reset the flight state (D.3.13).
2. Re-select the system nearest the chart cursor (snap the cursor; recompute the distance from
   the current system).
3. Create the launch scene: the planet straight ahead at 65536 sim units and the station 256 sim
   units behind (details in the flight section); the station-present flag is set.
4. Speed is set to 12.
5. The legal status is combined (bitwise OR) with the hold's contraband score (see the legal
   section).
6. Docked flag off, mode Flight, and the front view (active mount 1 in LodeStar) is shown,
   forced (even if already showing).

Docking completion action: reset the flight state, then enter the docked state (D.3.2).

#### D.3.5 Launch (docked -> flight)

The launch action is accepted whenever docked and the keyboard is not captured, from any docked
screen. It immediately starts the launch tunnel (D.3.4). The docked flag stays on until the
tunnel completes.

#### D.3.6 Flight mode: the per-tick flight logic

This section is the frame of the flight logic; the bodies of most steps belong to other sections
(flight, combat, spawning, legal). The order is part of the rules.

1. Roll and pitch: apply the held roll-left, roll-right, climb and dive controls to the roll and
   pitch rates, then damp them and convert them to the roll and pitch angles (flight section).
   While dying, the controls are treated as not held.
2. The laser power for this tick is set to 0. Then, unless dying, process the player's flight
   actions (D.4.2) in this order: speed up/slow down (held), each queued one-shot action in press
   order, then the laser (held).
3. Process every bubble entry in order (combat/flight sections), including laser hits and
   missile lock-on, which only happen while the space view is showing (D.6.1).
4. Area blast timer: if above 0, decrease by 1. Then, if the main counter's low 3 bits are 0
   (once every 8 ticks): if energy is at least 128, each shield below 255 gains 1 and costs 1
   energy (aft shield first, then forward); then energy gains 1 (2 with the energy booster),
   capped at 255.
5. If not in the ambush state, and the main counter's low 5 bits are 0, and no station is
   present: try to place the station near the planet (flight section).
6. If not in the ambush state, at main-counter phase (low 5 bits) 10: energy-low warning check
   (D.9) and the planet altitude / crash check; at phase 20: cabin temperature from the sun,
   sun death, and fuel scooping with its message (D.9).
7. Laser lines and recharge: if laser lines are showing and the laser recharge counter is below
   8, hide them; if the recharge counter is above 0, reduce it by 5 (floor 0). If the player's
   own E.C.M. is on, drain 1 energy; if that drain hit the floor, switch the E.C.M. off. If the
   E.C.M. timer is above 0, decrease it; on reaching 0 switch the E.C.M. off.
8. If the message timer is above 0, decrease it; on reaching 0 clear the message.
9. Decrease the main counter by 1 (wrapping). If it is now 0 and the player is not dying, run
   the spawning logic (spawning section).
10. Laser temperature decreases by 1 if above 0.
11. Advance the hyperspace countdown (D.3.7). This also runs while dying (see D.14).

What depends on the screen showing while in flight:

- Everything above runs on every screen (charts, status, market, etc.): ships move and fight,
  the countdown runs, energy recharges.
- Only on the space view: the laser can fire, laser hits are tested, the missile can lock on,
  and the dust moves. On other screens the view is not redrawn (only the overlays and the
  dashboard update).

#### D.3.7 Hyperspace: the action, the countdown and the jump

Hyperspace action (normal jump):

1. If docked: show the docked notice on the bottom rows (D.9) and do nothing else.
2. If a countdown is already showing (displayed value non-zero): ignore.
3. Re-select the system nearest the chart cursor (snap the cursor, recompute the distance). If a
   chart is showing, redraw it.
4. If the distance is 0 (the cursor is on the current system): do nothing.
5. If the distance exceeds the fuel: show the out-of-range line at the bottom of the space view
   (D.9); no countdown.
6. Otherwise show the destination line (purpose: "jump to <selected system name>") at the bottom
   of the space view and start the countdown.

Galaxy jump action:

1. If docked: the docked notice, as above. 2. If a countdown is showing: ignore. 3. If the
   galaxy drive is not fitted: ignore silently. 4. Otherwise: the hyperdrive is removed
   from the commander immediately, the legal status is set to 0 (clean) immediately, and the
   countdown starts (flagged as galactic). No bottom line is shown.

Countdown (two values: an internal step counter and the displayed value):

- Start: internal = 15, displayed = 15.
- Each flight tick (step 11 of D.3.6): if displayed is 0, nothing. Otherwise decrease internal;
  if it is still above 0, stop. Otherwise set internal to 5 and decrease displayed; if displayed
  reaches 0, the jump happens now.
- So, counting the tick in which the key was pressed as tick 1 (the key is dispatched before
  that tick's logic, so that tick already decrements), the displayed value goes 15 -> 14 in tick
  15, then drops by 1 every 5 ticks, and the jump happens in tick 85 (about 7.1 s).
- The displayed value (1-15) is drawn as an overlay, right-aligned in a 5-character field, at the
  top-left of every screen except during tunnels (including the charts and status screens, and
  also the title if a countdown was left running; see D.14).
- The countdown cannot be cancelled by the player. Docking and entering the docked state clear it. The
  flight-state reset does not clear it.
- The destination is not fixed when the countdown starts: anything that re-selects the system
  nearest the cursor during the countdown (system data screen, status screen, the distance key)
  changes the destination and the distance that will be charged (D.14).

The jump, normal:

1. Fuel decreases by the current distance to the selected system (no clamp; see D.14).
2. Draw one random byte; if it is 253 or more, this jump is a mis-jump into the ambush state
   (probability 3/256).
3. Start the hyperspace tunnel. On completion: the ambush arrival (D.3.8) if it was a mis-jump;
   otherwise the selected system becomes the current one (the commander's galactic coordinates
   become the selected system's, the extra-vessel spawn delay is set to 0, distance to the
   selected system becomes 0), then the common arrival (below).

The jump, galactic:

1. The galaxy number increases by 1, wrapping 7 -> 0, and the galaxy seeds are transformed
   (galaxy section).
2. The chart cursor is set to (96, 96) and the system nearest that point in the new galaxy
   becomes both the selected and the current system; the commander's coordinates become its
   coordinates; the distance becomes 0.
3. The galactic-jump message is set (D.9) - it is cleared again by the arrival's flight-state
   reset before it can be seen (D.14).
4. Start the hyperspace tunnel; on completion, the common arrival. No fuel is used and there is
   no mis-jump roll.

Common arrival (in this order, including its random draws):

1. Draw one random byte: the market's per-visit random value; recompute the market availability
   from the current system's economy and that value (trade section).
2. Reset the flight state (D.3.13).
3. The legal status is halved (shift right by 1); the bit shifted out is passed to the solar
   system set-up (legal section / flight section).
4. Set up the planet and sun for the current system (flight section).
5. Docked flag off, mode Flight, front view forced. (The baseline intends to keep a chart on
   screen if one was showing before the jump, but the screen kind is always "tunnel" at this
   point, so the front view is always shown; see D.14.)

#### D.3.8 The ambush state (mis-jump)

On a mis-jump the player arrives in empty interstellar space under attack:

1. Reset the flight state (D.3.13).
2. Set the ambush flag.
3. The commander's galactic y coordinate is XORed with 31 (0x1F); x is unchanged. The current
   system is NOT changed (it stays the departure system; its name is shown as blank wherever the
   current system's name is printed), and no new market is generated. Fuel has already been
   charged.
4. Docked flag off, mode Flight.
5. While the bubble holds 3 or fewer alien motherships: spawn one alien mothership with one
   alien drone (spawning section, 2 random draws per pair); stop early if the bubble had no room.
   This normally gives 4 motherships and 4 drones.
6. Reset the dust to 3 particles (3 random draws per particle, 9 in total).
7. Front view, forced.

While the ambush flag is set:

- There is no planet, sun or station: no station placement, no altitude or sun checks, no
  energy-low warning (it lives in the same phase-gated step), and no compass.
- The spawning logic does nothing.
- The in-system jump is refused.
- Kills pay no bounty.
- Using the escape pod leads to death (D.3.9).
- The current system name is empty in text.
- The only exits are a hyperspace jump (from the modified coordinates) or death. The ambush flag
  is cleared by the next flight-state reset.

#### D.3.9 Escape pod

Accepted in flight (not dying) if an escape pod is fitted. In the tick it is used:

1. Any prompt flow is cancelled.
2. A copy of the player's ship type is created just ahead of the player (the same placement as
   a launched missile: see the combat section) if the bubble has room; then the bubble is
   emptied (station-present flag off) and the missile lock is cleared.
3. If the copy was created, it is put back as the only bubble entry, with speed 8, pitch counter
   194 and no AI.
4. The space view stays on whichever view was showing; mode Escape; the escape timer is set to
   97; flight controls reset (roll angle +3/256, pitch 0); the launch sound plays.
5. The rest of that tick's flight logic still runs (no further one-shot actions or laser that
   tick; ship processing, recharge, counters and possibly spawning continue on the new bubble;
   see D.14).

Each later tick: apply the abandoned ship's own rotation step and decrease the timer; each
substep moves the bubble by half a step with the player's speed unchanged from the moment of
ejection and the reset controls. When the timer reaches 0 (97 ticks, about 8.1 s), the mode
becomes Docked and:

1. Reset the flight state.
2. If the pod was used in the ambush state: the player dies (D.3.10) instead of docking.
3. Otherwise: the hold is emptied, legal status becomes 0, the escape pod is removed, fuel is set
   to the maximum (70), and the player enters the docked state (D.3.2) at the current system's station.
   Cash, equipment, missiles, kills and the market are kept.

#### D.3.10 Death

Causes (details in their own sections): energy falls to 0 or below from damage; the planet
altitude check finds the player inside the planet or at altitude 0; the cabin temperature from
the sun would exceed 255; hitting the station while not aligned at speed 5 or more; using the
escape pod in the ambush state.

When death starts (ignored if already dying):

1. Play the two explosion sounds (D.11).
2. Cancel any prompt flow.
3. Remember one quarter of the current speed (integer shift right by 2).
4. Reset the flight state (D.3.13), then set speed to the remembered quarter.
5. Space view, front view (view 0), mode Death; the main counter is set to 255; all held and
   queued input is cleared.
6. Create four cargo canisters as debris, each in turn: draw a random pair to make a spawn
   template (2 draws, see the spawning section's template), take the template's first byte `a`
   and second byte `x`; position x = (a >> 2) AND 63, y = that XOR 42, z = that OR 80 (sim
   units, all positive, i.e. just ahead); roll counter = x AND 0x8F; pitch counter = (x >> 1) AND
   0x87; no AI; orientation set to the standard (nose forward, side pointing left, roof up);
   speed = (2 x remembered quarter) AND 255. Then draw one more random byte; if it is odd the
   canister is flagged as killed (it explodes). Add it to the bubble.
7. Set speed to 0.
8. Set the death timer to 61 ticks (5.1 s at 12 Hz, rounded).

Each later tick (in the logic substep): run the flight logic as "dying" (no player controls, no
player actions, no spawning when the main counter wraps to 0; everything else runs, so remaining
ships keep acting and the hyperspace countdown keeps running), then decrease the death timer; if
it reaches 0, start the title sequence (D.3.1) immediately. Then (both substeps) move everything
by half a step and redraw. The space view is drawn without the laser sights, and the death
notice is printed near the middle of the view after the redraw of each logic substep only.

After death the commander is replaced by the last saved or loaded commander (or the default one)
when the title sequence reaches step 3. Nothing about the dead commander is kept.

#### D.3.11 Docking

Docking happens either when the station touches the player and the alignment test passes, or
instantly with the auto-dock (D.4.2). The alignment test, the failure damage and the
fatal-speed rule are in the flight section (the baseline: the station must not be hostile, its
nose must face the player within the documented tolerance, the player must be heading at it,
and its slot must be horizontal enough; failing that, at speed 5 or more the player dies,
otherwise speed is set to 1 and the player takes 5 damage).

On docking: the countdown is cleared, then the docking tunnel starts (launch sound); on
completion the flight state is reset and the player enters the docked state. Docking does not generate a
new market (only a hyperspace arrival does).

#### D.3.12 Pause

The pause action is accepted in Docked and Flight modes when the keyboard is not captured by a
prompt. It is not available on the title (a press there answers the prompt), during tunnels,
death or the escape sequence, or in shops and name entry.

While paused:

- No simulation runs at all: no motion, no logic, no counters, no timers. Held keys are recorded
  but unused. The screen keeps being redrawn every substep (see D.13 about the random draws this
  causes in the baseline).
- There is no on-screen pause indicator in the baseline (LodeStar may add one).
- Each press goes to the pause handler, which accepts these actions:

| Pause action | Effect | Sound |
|---|---|---|
| resume (baseline accepts two different keys for this) | unpause | none |
| sound off | mute all sound (not persisted) | none |
| sound on | unmute (not persisted) | none |
| toggle auto-recentre | flips the roll/pitch auto-recentre setting (flight section; default on) | beep (if unmuted) |
| toggle keyboard damping | flips the rate damping setting (flight section; default on) | beep |
| toggle flashing indicators | flips flashing of dashboard danger colours (default on) | beep |
| toggle credits line | shows/hides the credits line on the title screens (default off) | beep |
| quit | unpause, cancel prompt flows, reset the flight state, restart the title sequence | none |

All other presses are ignored. The toggles are not saved.

#### D.3.13 Flight-state reset

Used at launch, docking, arrival, ambush arrival, death, after the escape pod, after choosing a
commander on the title, and on quit. It sets:

- energy, forward shield and aft shield to 255;
- the dust to 18 particles, generated fresh (3 random draws per particle, 54 draws in total, in
  particle order; see D.13);
- missile lock cleared and not armed;
- roll and pitch rates to their centre value, roll angle +3/256, pitch angle 0;
- main counter 0; speed 3;
- E.C.M. off (own flag and timer 0) and its sound stopped;
- bubble emptied, station-present flag off, ambush flag off;
- area blast timer 0;
- laser recharge counter 0, laser power 0, laser lines hidden;
- cabin temperature 30, laser temperature 0, altitude 255;
- message timer 0, message cleared;
- bottom line of the space view cleared.

It does NOT clear the hyperspace countdown.

---

### D.4 Player actions

#### D.4.1 Held controls (sampled once per tick in flight logic)

| Action | Allowed | Effect per tick |
|---|---|---|
| roll left / roll right | flight, not dying | change the roll rate (flight section) |
| climb / dive | flight, not dying | change the pitch rate (flight section) |
| speed up | flight, not dying | +1 if speed < 40 |
| slow down | flight, not dying | -1 if speed > 1 (applied after speed up, so holding both gives no change unless at a limit) |
| fire laser | flight, not dying, space view showing | see below |
| chart cursor left/right/up/down | docked only, a chart showing | one step per even display frame (D.3.3); in flight the held state has no effect, only individual presses move the cursor (D.4.3) |

Firing the laser, checked after all one-shot actions of the tick:

1. Requires: the laser recharge counter is 0, the fire control is held, laser temperature is
   below 242, the active mount has a laser, and the space view is showing.
2. The laser power for this tick = the mount's laser power value with its top bit removed (the
   top bit marks the continuous "beam" type).
3. Play the laser sound.
4. Show the laser lines; the lines' convergence point is jittered: draw a random byte for x and
   then one for y; each offset is (byte AND 7) - 4 pixels from the view centre (range -4..+3).
5. Laser temperature +8, capped at 255.
6. Drain 1 energy (energy never drops below 1 by drains; see the combat section).
7. Laser recharge counter = 0 for the beam type, 10 for the pulse type.

With step 7 of D.3.6 this makes the pulse laser fire on every second tick while held (6 shots
per second), with its lines visible for the tick in which it fired; the beam laser fires every
tick (see D.14 about its lines).

#### D.4.2 One-shot flight actions (queued until the tick logic)

These are only accepted in flight (not docked). A press during substep A waits for substep B's
logic. Each is processed in press order within step 2 of D.3.6.

| Action | Accepted when | Effect | Sound |
|---|---|---|---|
| unarm missile | at least one missile carried | lock cleared, not armed (even if it was neither) | long beep |
| arm missile (target) | no lock held and at least one missile carried | armed: the next ship to pass through the sights while the space view is showing becomes the lock target | none now; beep on lock-on |
| fire missile | a lock is held | launch our missile at the target (combat section). If the bubble is full: the "missile jammed" message, and the lock is kept. Otherwise the target turns hostile, the lock is cleared, missiles -1 | launch sound (on success) |
| area blast | bomb fitted | bomb removed; bomb timer = 4 (every non-station, non-planet, non-sun object that is not already exploding is destroyed during the next 4 ship-processing passes, each counting as a kill; combat section) | the kill sound per destroyed object |
| escape pod | pod fitted | D.3.9; the remaining queued actions and the laser are skipped this tick | launch sound |
| in-system jump | see below | | |
| E.C.M. | E.C.M. fitted and the E.C.M. timer is 0 (no E.C.M., ours or a ship's, running) | own E.C.M. on; timer = 32 ticks; drains 1 energy per tick while on (D.3.6 step 7) | E.C.M. on sound; off sound when it ends |
| auto-dock | auto-dock fitted, a station present and the station not hostile | dock immediately (D.3.11); remaining actions and the laser skipped this tick | launch sound (tunnel) |

In-system jump. Refused (long beep, nothing else) if any of:

1. the bubble holds anything other than the planet, the sun/station, asteroids, escape pods and
   cargo canisters (computed as: entries - 2 - asteroids - escape pods - canisters > 0);
2. a station is present;
3. the ambush flag is set;
4. the planet exists, is ahead or level (its z >= 0), and its largest absolute coordinate is
   below 2 x 65536 sim units;
5. the same test for the sun.

Otherwise: the planet's and the sun's z coordinates each decrease by 65536 sim units (the player
moves 65536 towards them), the main counter is set to 1 (so the spawning logic runs at the end
of this very tick), the extra-vessel spawn delay is set to 0, and the current view is redrawn
(forced). No sound plays on success.

#### D.4.3 One-shot actions handled immediately (at dispatch, any substep)

| Action | Docked | Flight |
|---|---|---|
| launch / front view (mount 1) | launch (D.3.5) | show the front view (LodeStar: make mount 1 active) |
| buy cargo / rear view (mount 2) | open the buy screen | rear view (mount 2) |
| sell cargo / left view (mount 3) | open the sell screen | left view (mount 3) |
| equip ship / right view (mount 4) | open the equip screen | right view (mount 4) |
| galaxy chart | show | show |
| local chart | show | show |
| system data | re-select nearest to cursor, then show | same |
| market prices (current system) | show | show (view only) |
| status | re-select nearest to cursor, then show | same |
| inventory | show | show |
| hyperspace | docked notice | D.3.7 |
| galaxy jump | docked notice | D.3.7 |
| distance (charts only) | re-select nearest to cursor, redraw chart, print name and distance on the bottom rows | same |
| home cursor (charts only) | cursor to the current system's coordinates (no re-selection), redraw chart | same |
| chart cursor step (charts only) | move the cursor 1 in that direction, redraw chart | same |
| save commander | name prompt then save (D.12) | ignored |
| pause | D.3.12 | D.3.12 |

View/mount switching rule (baseline): if the space view is already showing on the requested view
and the switch is not forced, nothing happens. If the space view is showing on a different view,
the dust particles swap their x and y (a visual effect). Then the requested view becomes current,
the space view is shown, the bottom line (hyperspace text) is cleared, and every object's
"on-screen", "on-scanner" and "firing" flags are cleared. Coming from a non-space screen there is
no dust swap.

Cursor movement: each axis moves independently; a move is rejected on an axis if it would leave
0..255. A press moves 1; in the baseline a key that is still held on the next even display frame
also moves via the held rule (docked only), so a single press can move 2.

LodeStar deliberate difference: the camera is a third-person orbit camera; the four laser mounts
remain, and the player selects the active mount (1-4) instead of switching views. Everything the
baseline ties to "the current view" (which mount fires, the sights test for laser hits and
missile lock-on in that mount's direction, which mount the dust/sights refer to) is tied to the
active mount. Selecting the already-active mount does nothing; selecting another mount clears the
objects' on-screen/on-scanner/firing flags and the bottom line as above.

#### D.4.4 Key dispatch rules

1. Pointer/touch presses on the canvas are ignored by the game except on the title screens,
   where they count as a space.
2. While a prompt captures the keyboard (name entry, buy, sell, equip), every press goes to the
   prompt: to the waiting prompt if it is waiting, otherwise into the prompt's queue (consumed in
   order by its next waits). Function keys, the pause key and everything else lose their normal
   meaning during capture.
3. Otherwise: the pause key; then the ten screen keys (D.5; digits also work as screen keys
   outside prompts); then, in flight, the queued flight actions; then save, hyperspace, galactic
   hyperspace, distance, home, cursor steps. Unknown keys are ignored.
4. A key's auto-repeat does not generate further one-shot presses; held controls use the key's
   down/up state. Losing window focus releases all held controls.
5. The galaxy jump action is the hyperspace key with the control modifier.
6. Key presses with the command/meta or alt modifiers are ignored entirely.

---

### D.5 Baseline key mapping (as action names only)

The baseline uses the original machine's layout: ten red function keys for the screen keys, with
the digits 1-9 and 0 as alternatives for the ten function keys outside prompts. The mapping, by
function-key number (1-10):

| Function key | Docked | Flight |
|---|---|---|
| 1 | launch | front view |
| 2 | buy cargo | rear view |
| 3 | sell cargo | left view |
| 4 | equip ship | right view |
| 5 | galaxy chart | galaxy chart |
| 6 | local chart | local chart |
| 7 | system data | system data |
| 8 | market prices | market prices |
| 9 | status | status |
| 10 | inventory | inventory |

Other actions each have their own single key: dive, climb, roll left, roll right, speed up, slow
down, fire, arm missile, fire missile, unarm missile, E.C.M., area blast, escape pod, in-system
jump, auto-dock, hyperspace, galaxy jump (hyperspace + control), chart cursor in
four directions, distance, home cursor, save commander, pause; and the pause-handler actions of
D.3.12. The touch layout offers a subset (the six held flight controls, fire, arm, fire missile,
E.C.M., jump, auto-dock, the ten screen keys, hyperspace and confirm). LodeStar chooses its
own keys; the only structural requirement is that one physical binding may mean different actions
docked and in flight, as above, or LodeStar may use separate bindings.

---

### D.6 Screens: required information and accepted actions

Screens are drawn once when opened (and redrawn when their content changes), except the space
view and the title, which are redrawn every substep. The text grid of the baseline is 32 columns
by 24 rows over the view, with the dashboard below; text wraps from column 31 to column 1 of the
next row. Length budgets below assume a 32-column line unless LodeStar's own layout allows more.

Overlays on every screen except tunnels: the hyperspace countdown value (D.3.7) and, except on
the title, the in-flight message (D.9). The dashboard (D.7) is always drawn.

#### D.6.1 Space view (flight, death, escape)

Must present:

- the 3D scene (planet, sun, station, ships, debris, explosions, dust);
- which view (LodeStar: which mount) is active, as a short label (budget: 12 characters);
- the laser sights, only if the active mount has a laser and the player is not dying;
- the laser lines while showing (D.4.1);
- enemy laser beams from firing ships;
- the in-flight message line (D.9);
- the bottom line, used only for the hyperspace destination or the out-of-range notice; it stays
  until cleared by a view change, a tunnel, or a flight-state reset.

Accepts all flight actions.

#### D.6.2 Status screen

Shown on entering the docked state and on request (docked or flight). Opening it re-selects the system
nearest the cursor. Must present, in this order:

1. the commander's name;
2. the current system's name (blank in the ambush state);
3. the selected (hyperspace) system's name;
4. condition: code 0 docked; 1 when the bubble holds nothing except the planet, the sun/station
   and asteroids (computed as entries - 2 - asteroids <= 0; note the station, canisters and pods
   count, so being near the station is never code 1); otherwise 2 if energy >= 128, else 3. The
   label for each code is the designer's (see D.14 about the baseline's labels);
5. fuel (light years, one decimal) and cash (credits, one decimal);
6. legal status label: clean (0), offender (1-49), fugitive (50 or more);
7. rank label 0..8 from the kill count (combat/rank section);
8. an equipment heading followed by one line per fitted item, in this order: hold extension
   (shown if capacity >= 26), fuel scoop, E.C.M., area blast, energy booster, auto-dock
   , galaxy drive; then for each mount 1..4 that has a laser: the mount's name and
   the laser type (pulse or beam). Missiles and the escape pod are not listed.

#### D.6.3 Inventory screen

Fuel and cash (as in the status screen), the hold extension line if capacity >= 26, then one
line per goods item with a non-zero quantity: item name, quantity (up to 3 digits), and the
item's unit (2-character budget). Also the screen the buy flow returns to.

#### D.6.4 Market screen

Title with the current system's name. Column headings (item, price, quantity). For each of the 17
goods items in index order: name, price for this visit (credits, one decimal, up to 5
characters), unit, and either the available quantity with unit or a "none available" mark when 0.
View only.

#### D.6.5 System data screen

For the selected system (after re-selecting the nearest to the cursor):

1. title including the selected system's name;
2. distance from the current system in light years with one decimal (line omitted when 0);
3. economy description composed from two labels: a prosperity label and a type label (D.10);
4. government label (8 types, galaxy section);
5. tech level, displayed as the internal tech level + 1;
6. population with one decimal and a unit word (billions in the original's terms);
7. the species description in parentheses, made plural (D.10);
8. productivity (up to 5 digits) with a currency-in-millions unit;
9. average radius (up to 5 digits) with a distance unit.

There are no generated planet descriptions in this version.

#### D.6.6 Galaxy chart

1. title with the galaxy number 1..8;
2. the whole galaxy: x drawn at scale 1, y at scale 1/2 (coordinates 0..255 by 0..127 plot area);
3. every one of the 256 systems as a dot; dots are two pixels wide when a per-system size value
   from the seeds is small (galaxy section), else one;
4. a large cross on the current system and a circle around it showing the fuel range (radius =
   fuel / 4 in chart pixels, integer);
5. a small cross on the chart cursor.

#### D.6.7 Local chart

1. title;
2. a window centred on the current system: a system at galactic offset (dx, dy) from it is drawn
   at chart point (104 + 4dx, 90 + 2dy) if |dx| < 20 and |dy| < 38;
3. a large cross on the current system and a fuel-range circle of radius = fuel (in chart
   pixels);
4. the cursor cross, only when the cursor is within -26 <= dx < 38 and -36 <= dy < 38 of the
   current system;
5. each system in the window as a small disc of radius 2 or 3 (from one seed bit) with its name
   label, placed on its own text row if that row is free, else the row below, else the row
   above; labels may not use rows 0-2. If a free row was found but it is above row 3, neither the
   label nor the disc is drawn; if no row was free, the disc is drawn without a label.

#### D.6.8 Title screens

D.3.1. Must present: the title banner, the optional credits line, the prompt (load question or
start invitation), the copyright/credits line, the rotating ship.

#### D.6.9 Buy screen (docked, captures the keyboard)

1. Show the column headings, then go through the 17 goods items in index order, adding each row
   (as on the market screen) as it is reached.
2. For an item with availability 0: no prompt; continue.
3. For an item with availability > 0: clear the bottom rows and prompt for a quantity of this
   item, naming the item and its unit. Read a number (D.6.13) with the maximum = availability.
   - Abort (a non-digit key that is not a terminator or an ignored key): show the inventory
     screen and end the flow.
   - Too big: the "quantity" error (D.9), beep, 1 s pause, prompt again for the same item.
   - Not enough hold space for the quantity (trade section): the "cargo space" error, beep,
     pause, prompt again.
   - Cost (quantity x price) above cash: the "cash" error, beep, pause, prompt again.
   - Otherwise: pay, add to the hold, reduce availability; if the quantity was above 0, show the
     remaining cash, beep and pause. Continue with the next item (a quantity of 0 just moves on).
4. After the last item: show the inventory screen.

#### D.6.10 Sell screen (docked, captures the keyboard)

1. A heading, then for each goods item held (quantity > 0), in index order: the item's name,
   quantity and unit, then a yes/no sell question.
2. Wait for one key. "Yes" (baseline: the Y key) echoes a yes mark and sells the whole quantity at
   this visit's price; any other key echoes a no mark and keeps it.
3. After the last held item (or immediately if nothing is held): beep, 1 s pause, inventory
   screen.

#### D.6.11 Equip screen (docked, captures the keyboard)

Repeats until the player leaves:

1. Title; then the items on sale for the current system's tech level (count = min(tech level +
   3, 12), equipment section), each with its number 1..count, name and price (credits, one
   decimal). The fuel item's price is (70 - fuel) x the per-0.1-light-year fuel price.
2. Prompt for an item number; read a number with maximum = count.
3. Abort, 0, or too big: enter the docked state (status screen) and end.
4. If the price exceeds cash: the "cash" error, beep, 1 s pause, enter the docked state, end.
5. Pay. Then per item:
   - fuel: fuel = 70, and the main counter is set to 0 (baseline side effect; harmless while
     docked);
   - missile: if 4 are carried, refund and show the "already have all" notice; else +1;
   - hold extension: if already fitted, refund and show the already-fitted notice; else fit;
   - E.C.M., fuel scoop, escape pod, area blast, energy booster, auto-dock, galactic
     hyperdrive: if already fitted, refund and the already-fitted notice; else fit;
   - pulse laser or beam laser: show the four mounts numbered 0-3 with their names and ask which
     mount; only the keys 0-3 are accepted (anything else re-asks). Pulse: refuse (refund, "already
     fitted") if that mount has any laser. Beam: refuse if that mount already has a beam; if it
     has a pulse laser, the pulse laser's price is refunded on top and the mount gets the beam.
     (LodeStar shows mounts 1-4 to match its mount selection; the stored index stays 0-3.)
   - Every the already-fitted notice refusal: notice, beep, 1 s pause, enter the docked state, end.
6. Success: show the remaining cash, beep, 1 s pause, redraw the shop and prompt again.

Buying fuel at full tanks costs 0 and succeeds.

The 1 s pause ("beep pause") is a beep followed by a 1000 ms wall-clock wait in the baseline;
keys pressed meanwhile are queued for the prompt. LodeStar may implement it as 12 ticks.

#### D.6.12 Name prompt (title load, and save)

Clears the view and asks for the commander's name. Accepts:

- letters and digits, converted to capitals, up to 7 characters (further characters ignored),
  each echoed;
- delete-last-character (erases the last echoed character);
- confirm: returns the typed name (possibly empty);
- cancel: returns an empty name.

All other keys are ignored.

#### D.6.13 Number entry (shops)

> **LodeStar:** not used; the market and equipment panels replace it (deliberate difference 12).

1. Start with value r = 0. Read up to 12 key presses in total (every press, including ignored
   ones, counts towards the 12); after the 12th the entry ends with the current value.
2. Pointer presses, cursor keys and bare modifier/lock keys (shift, control, alt, caps lock,
   tab) are ignored.
3. Confirm, space, delete and cancel end the entry with the current value.
4. Any other non-digit aborts the whole flow (including function keys and letters).
5. A digit: if r >= 26 the entry ends immediately with r and the digit is discarded (this keeps
   the value within one byte). Otherwise r = 10r + digit; if r now exceeds the maximum, the entry
   ends at once as "too big" (the digit is not echoed); otherwise the digit is echoed.
6. Returned: the value and whether it exceeds the maximum.

#### D.6.14 Death and tunnel screens

Death: the space view (front) without sights, with the death notice near the centre (D.9).
Tunnel: the tunnel animation over a cleared view; the dashboard stays live.

---

### D.7 Dashboard (HUD) indicators

The HUD must expose these values; the baseline draws each bar as 0-15 segments. "Danger" bars are
drawn in the danger colour, which flashes when flashing is enabled (D.7.2).

| Indicator | Source value | Bar length (0-15 segments) | Danger when |
|---|---|---|---|
| forward shield | 0-255 | value >> 4 | length < 3 (value < 48) |
| aft shield | 0-255 | value >> 4 | length < 3 |
| fuel | 0-70 tenths of a light year | value >> 2, capped at 15 | length < 3 (value < 12) |
| cabin temperature | 0-255 | value >> 4 | length >= 11 (value >= 176) |
| laser temperature | 0-255 | value >> 4 | length >= 11 |
| altitude | 0-255 (255 = far from planet) | value >> 4 | never (the threshold of 240 cannot be reached by a 0-15 length) |
| speed | 1-40 | value >> 1, capped at 15 | length >= 14 (speed >= 28) |
| energy banks (4) | energy 0-255 | e = energy >> 2 (0-63) shared across 4 banks of 16: the bottom bank fills first, then the next up; each bank's bar = min(15, its share) | a bank's length < 3 (a bank with 0 draws nothing) |
| roll indicator | roll angle magnitude 0-31 with sign | marker position 8 + s x (magnitude >> 2), s = +1 when rolling right | - |
| pitch indicator | pitch angle magnitude 0-8 with sign | marker position 8 + s x (magnitude - 1) when magnitude > 0, else 8; s = +1 for climbing (positive pitch angle) | - |
| missiles | 0-4 carried | one block per missile; the leftmost block shows the state: locked (danger colour), armed (warning colour), else normal | - |
| station bulb | station present (inside the station's safe zone) | on/off | - |
| E.C.M. bulb | E.C.M. timer > 0 (ours or a ship's) | on/off | - |
| compass | D.8 | | |

Escape-pod indicator: while an escape pod is fitted, the baseline presents the whole screen with
a shifted palette (the warning colour shown as white, the normal colour as cyan). LodeStar must
show "escape pod fitted" in some always-visible way.

#### D.7.1 Values while not in flight

Docked: all values as they stand (energy and shields full after the reset), bulbs off, no
compass, empty scanner. Title: the frame only with empty scanner, no bulbs, no compass.

#### D.7.2 Flashing rule

When flashing is enabled (default), a danger bar is shown in its normal colour instead of the
danger colour whenever bit 3 of the display frame counter is set: 8 ticks danger colour, 8 ticks
normal, repeating (period 16 ticks). The display frame counter only advances in docked and flight
modes, so the flash freezes during tunnels, death, escape and pause. When flashing is disabled,
danger bars are steadily in the danger colour.

---

### D.8 Scanner and compass

Scanner (3D radar). For each bubble entry that is not the planet or sun, not flagged killed and
not exploding:

1. Skip it if any coordinate's absolute value is >= 65536, or if any of |x| >> 8, |y| >> 8,
   |z| >> 8 is >= 64. So the scanner range is a cube of half-width 64 x 256 = 16384 sim units on
   each axis (integer truncation of |coordinate| / 256).
2. Horizontal position: centre + sign(x) x (|x| >> 8) pixels (1 pixel per 256 sim units,
   +-63).
3. Base point (the object's position on the scanner plane): centre - round(sign(z) x
   (|z| >> 8) / 4) (1 pixel per 1024 sim units; ahead is up).
4. Blip: base - round(sign(y) x (|y| >> 8) / 2) (1 pixel per 512 sim units; above is up),
   clamped to the scanner's vertical extent.
5. Draw a stick from the base point to the blip and a 2-pixel blip. Missiles (ours and hostile)
   use a distinct colour; everything else, including the station, the common colour.

Compass. Target: the station if present, else the planet; no compass if neither exists (docked,
title, or the ambush state).
The direction to the target is normalised; the dot is placed at the compass centre + (round(9.6
x dx), -round(9.6 x dy)) pixels; it is shown one way (bigger, warning colour) when the target is
ahead (dz >= 0) and another (smaller, normal colour) when behind.

---

### D.9 Messages

All wording is the designer's. Budgets are maximum characters on one line.

#### D.9.1 Timed in-flight messages

Mechanism: setting a message replaces any current one and sets the message timer to 22. The
timer decreases once per tick (flight or docked). The message is drawn in capitals on the
message line of the view on every redraw while the timer is above 0 (and not on the title). A
message set during tick N's logic is visible from the redraw after that logic through the redraw
of substep A of tick N+21: 21 ticks (42 substeps, 1.75 s). Two kinds of event refuse to set a
message while another is showing (timer > 0): the bounty and the damage-loss events.

| # | Purpose | Trigger | Notes | Budget |
|---|---|---|---|---|
| M1 | fuel scooping in progress | flight, not ambush, main-counter phase 20, no station present, cabin temperature >= 224 and fuel scoop fitted | fuel gains floor(speed / 8) tenths, capped at 70, before the message; shown even if nothing was gained; repeats every 32 ticks while the condition holds. The original also beeps (embedded beep code); the baseline is silent | 16 |
| M2 | energy low | flight, not ambush, phase 10, energy < 50 | repeats every 32 ticks; original beeps, baseline silent | 14 |
| M3 | kill milestone praise | after a kill, if the kill count's low byte becomes 0 (every 256 kills) | | 20 |
| M4 | incoming missile warning | a ship launches a missile at the player | with the launch sound | 18 |
| M5 | missile jammed | fire missile with no room in the bubble | lock kept | 16 |
| M6 | missile target lost | the locked target leaves the bubble (removed) | lock and arming cleared | 14 |
| M7 | galactic jump notice | the galactic jump starts | never visible in the baseline (cleared by the arrival reset, and overlays are not drawn in the tunnel) | 22 |
| M8 | bounty paid: shows the new cash total | a destroyed ship with a bounty is removed, only if no message is showing and not in the ambush state | if a message is showing, the bounty is not paid at all (D.14). The text is the cash figure (9 characters with one decimal) plus the currency suffix | 14 |
| M9 | scooped item | a canister, alien drone or escape pod is scooped into the hold | shows the goods item's name only (item chosen by the scoop rule, combat section) | 14 |
| M10 | cargo lost | damage reached the energy banks and the loss roll chose a goods item the player holds | the item's name plus a "destroyed" suffix | 22 |
| M11 | equipment lost | as M10, the roll chose fitted equipment (E.C.M., fuel scoop, area blast, energy booster, auto-dock) | equipment name plus the "destroyed" suffix | 24 |

#### D.9.2 Persistent notices and prompts

| # | Purpose | Trigger | Where / how long | Budget |
|---|---|---|---|---|
| N1 | hyperspace destination (the destination announcement) | successful hyperspace action | bottom line of the space view until cleared (D.6.1) | 22 incl. an 8-char name |
| N2 | out of range | hyperspace action with distance > fuel | as N1 | 18 |
| N3 | already docked | hyperspace action while docked | bottom rows of the current screen until it is redrawn | 10 |
| N4 | distance readout | distance action on a chart | bottom rows: the selected name, then distance (one decimal) and unit, omitted if 0 | 24 |
| N5 | countdown | countdown running | 5-character field, top-left | 5 |
| N6 | death notice | death sequence | near the view centre | 16 |
| N7 | title banner | title | top of view | 24 |
| N8 | credits line | title, when toggled on | under the banner | 30 |
| N9 | load question (yes/no) | title 1 | prompt line | 30 |
| N10 | start invitation | title 2 | prompt line | 30 |
| N11 | copyright/credits | both titles | bottom line | 30 |
| N12 | name question | name entry | top of view, followed by up to 7 typed characters | 22 |
| N13 | quantity question naming the item and unit | buy flow | bottom rows | 28 incl. item name |
| N14 | quantity too big | buy | after the typed number | 10 |
| N15 | no hold space | buy | after the number | 10 |
| N16 | not enough cash | buy, equip | after the number | 8 |
| N17 | cash remaining | after a purchase | after the number | 20 |
| N18 | sell question (yes/no) | sell, per item | after the item line | 12 |
| N19 | item number question | equip | bottom rows | 8 |
| N20 | already fitted / already have all | equip | after the number | 24 incl. item name |
| N21 | mount question and mount list | equip, laser | four mount lines and the question | 12 per line |

---

### D.10 Text system and generated text

The baseline stores all text as recursive tokens and prints through a case-mode engine. LodeStar
may store text any way; it must provide the following behaviours:

1. Two case modes: all capitals; and sentence/word case, where the first letter of each word is
   a capital and the following letters of the word are lower case. In word case, any character
   below 'A' in the character set (space, digits, punctuation) ends a word, so the next letter is
   a capital. Names of systems pass through the case rules (so they appear in word case on
   charts and status screens and in capitals in messages).
2. Embedded data fields: the cash (right-aligned in 9 characters with one decimal, then the
   currency suffix and a new line); the galaxy number 1..8 (right-aligned, 3 wide); the current
   system's name (empty in the ambush state); the selected system's name; the commander's name
   (printed as typed); a fuel-and-cash block (fuel right-aligned 3 wide with one decimal and a
   light-years unit, new line, then the cash field).
3. Layout codes: new line (to column 1 of the next row), line feed (down one row, same column),
   tab to column 21 followed by a colon (used for "label: value" columns), and a beep code (the
   original sounded the beep each time such a message was printed; the baseline's printer
   ignores it, see D.14).
4. Number formatting: a value is floored and clamped to >= 0, optionally given a decimal point
   before its last digit (values below 10 get a leading 0, e.g. 5 -> 0.5), then right-aligned to
   a field width.

Generated text (structure only):

- System names: from the galaxy generator (galaxy section).
- Economy description: economy code e in 0..7 maps to (prosperity label, type label):
  prosperity label = "middle" when e is 3 or 4, otherwise label number (e if e < 3, else e - 5),
  i.e. 0 high, 1 middling, 2 low; type label = "industrial type" if e < 4, else "agricultural
  type". So e 0..2 are high/middling/low industrial, 3 is mostly-industrial, 4 mostly-
  agricultural, 5..7 high/middling/low agricultural. (Four prosperity words: three levels plus
  the "mostly" word used for 3 and 4.)
- Species description: built by the galaxy section from the system seeds; on the data screen it
  is converted to capitals (then printed through the case rules), any trailing plural letter is
  removed and the plural letter appended, so it always ends in exactly one plural mark; it is
  enclosed in parentheses.
- Government, rank, legal status and condition labels: fixed label lists indexed by code.
- Equipment names, laser type names, mount names, goods names, units: fixed lists (designer).

---

### D.11 Sound cues

Ten sound effects. Durations in the baseline are in twentieths of a second; the sounds
themselves are the designer's. "Quieter" levels reduce volume (0 = full, 20 = silent, linear).

| Cue | Kind | Played when |
|---|---|---|
| S1 laser | short noise burst with falling pitch | the player's laser fires |
| S2 hit | short tone | an enemy laser hits the player, unless an E.C.M. is running (then silent) |
| S3 explosion A | noise with decay | the player takes damage that reaches the energy banks without dying; a collision (after the damage, if survived); scoop refused because the hold is full; a hostile missile explodes on the player; death (with S4) |
| S4 explosion B | noise burst | death (with S3); the player's laser hits a ship (quieter level 8); a kill (quieter level 4) |
| S5 beep | very short high tone | missile lock-on; pause-handler toggles; each shop beep pause |
| S6 long beep | short low tone | unarm missile; in-system jump refused |
| S7 launch | noise whoosh | launch tunnel; docking tunnel; the player's missile fired; incoming missile; escape pod |
| S8 hyperspace | rising/falling tone | hyperspace tunnel start (normal and galactic) |
| S9 E.C.M. on | continuous warbling tone | any E.C.M. starts (the player's or a ship's) |
| S10 E.C.M. off | stops S9 | the E.C.M. ends (timer runs out, or the player's E.C.M. drained the energy to its floor); also on any flight-state reset |

Rules:

- Muted (from the pause handler or the page's sound button) means nothing plays; the page button
  also stops S9 and saves the setting (D.12).
- Browsers start audio only after the first user input; this is a platform detail.

---

### D.12 What is saved and when

Commander record (saved only by the docked save action, under a name the player types; nothing
is saved automatically, and nothing in flight can be saved):

- name (up to 7 capitals/digits);
- galactic coordinates of the current system (x, y);
- the galaxy seeds and the galaxy number 0..7;
- cash (tenths of a credit);
- fuel (tenths of a light year, 0..70);
- laser on each of the 4 mounts (none / pulse / beam);
- hold capacity;
- quantity of each of the 17 goods items;
- fitted flags: E.C.M., fuel scoop, area blast, energy booster, auto-dock, galactic
  hyperdrive, escape pod;
- missiles carried 0..4;
- legal status (0..255);
- this visit's market availability for each of the 17 items, and this visit's market random value;
- kill count (16 bits).

Plus an integrity check value over the record; a record that fails the check (or is malformed)
is treated as absent. The check algorithm is LodeStar's choice.

Save action flow: name prompt (D.6.12); if the game is still docked afterwards and the name is not
empty, the commander's name becomes the typed name, the record is stored under that name, and it
becomes the "last saved or loaded commander" (what death and quit return to); an empty name or
cancel saves nothing. Either way the player is then put back in the docked state (status screen). The
baseline also stores the last-used name separately but never reads it.

Load: only from the title's load question (D.3.1).

Not saved: in-flight state (it does not exist while docked), the selected system and cursor (on
load the current system and selection are re-derived from the saved coordinates), the pause
toggles. The sound mute setting is saved by the page's sound button only (not by the pause
handler's sound keys).

The "last saved or loaded commander" lives only in memory; on a fresh start it is the default
commander (commander section).

---

### D.13 Random-number consumption in these flows

The game uses one shared 8-bit generator (combat/spawning sections define it). The draws made by
the flows in this section, in order:

| Flow | Draws |
|---|---|
| flight-state reset | 54 (dust: 18 particles x 3) |
| launch completion | reset (54); no other draws in this section |
| common arrival | 1 (market value), then reset (54), then the solar set-up's draws (flight section) |
| normal jump start | 1 (mis-jump roll), before the tunnel |
| ambush arrival | reset (54), then 2 per mothership+drone pair, then 9 (3 dust particles) |
| death | reset (54), then for each of 4 canisters: 2 (template) + 1 (explode roll) |
| laser shot | 2 (jitter x, then y), inside the player-action step |
| escape completion | reset (54) |
| docking completion | reset (54) |
| title (after commander chosen) | reset (54) |
| pause quit | reset (54), and later the title's reset |

Rendering in the baseline also draws from the same generator: the sun's ragged edge (one draw per
drawn scanline of a sun of on-screen radius >= 16 pixels), each firing ship's beam end point (one
draw per firing ship drawn), and dust particles that leave the view and are recreated (3 or more
draws each). These happen on every redraw, i.e. every substep, including while paused. LodeStar's
third-person renderer cannot reproduce them; see the open questions.

---

### D.14 Quirks and edge cases (baseline behaviour that parity depends on)

Input:

1. One-shot flight actions are queued and processed only in the tick logic; screen keys act at
   once in either substep (D.1).
2. During tunnels, death and the escape sequence every press is thrown away; nothing is buffered
   for afterwards.
3. While a prompt captures the keyboard, function keys and the pause key are just keys for that
   prompt: in number entry they abort the flow, in the sell question they mean "no", in name
   entry they are ignored.
4. On the title, only the first press of a substep is used; a pointer press counts as a space.
5. Held chart-cursor movement only works docked; in flight each press moves the cursor once.
6. A single cursor press can move the cursor twice when docked (press, plus held movement on the
   next even display frame).
7. Number entry counts ignored keys towards its 12-press limit, ends silently on a digit when the
   value is already 26 or more, and ends immediately as "too big" on the digit that exceeds the
   maximum.

Check order:

8. Hyperspace action: docked, then countdown running, then (galactic) hyperdrive fitted, then
   re-select, then distance 0, then range. The galaxy drive and legal status are consumed
   at the key press, not at the jump.
9. The destination and the fuel charge are read at the moment of the jump. Re-selecting during
   the countdown (system data screen, status screen, distance key) retargets the jump, even to a
   system beyond the fuel range; fuel is then charged without a range check and can become
   negative (it then displays as 0.0 and its bar is empty). Re-selecting the current system makes
   the jump cost 0 and arrive back at the same system with a new market.
10. Bounty: if any message is showing when a bountied ship's explosion finishes, no bounty is
    paid (the money is lost, not deferred). No bounty in the ambush state.
11. Cargo/equipment loss messages are likewise suppressed, and the loss itself does not happen,
    while a message is showing (combat section).
12. The status condition counts the station, canisters and escape pods as "ships", and assumes
    two fixed entries (planet and sun/station); in the ambush state, which has neither, the
    count is 2 too high.
13. The in-system jump uses the same "minus 2" count.

Timing and state:

14. The flight-state reset does not clear the hyperspace countdown, and the dying flight logic
    keeps advancing it. If the player dies during a countdown and the countdown expires within
    the 61-tick death sequence, the jump happens: the hyperspace tunnel starts, and on arrival the
    player is alive in the destination system with full energy and shields (the death timer is
    abandoned). If the death sequence ends first, the title screen shows the leftover countdown
    value until the player is docked.
15. On arrival the baseline means to keep a chart on screen if one was showing, but the check
    sees the tunnel screen, so the front view is always shown.
16. The galactic jump's message is never visible.
17. The fuel-scoop and energy-low messages contain a beep in the original; the baseline plays no
    sound for them.
18. The beam laser's lines are hidden in the same tick they are drawn (recharge counter 0 is below
    8), so in the baseline the beam laser never shows laser lines, although it fires, sounds and
    heats every tick. The pulse laser's lines show for the tick it fires.
19. The area blast has no visual flash in the baseline (only kills and sounds).
20. After the escape pod is used, the rest of that tick's flight logic still runs on the new
    one-entry bubble (one extra rotation step for the abandoned ship; energy/shield recharge;
    the main counter; and if the counter reaches 0, the spawning logic may add ships to the escape
    scene).
21. After death is triggered mid-way through ship processing, the processing loop continues over
    the new bubble (the debris) from the same slot index, so some debris may be processed in the
    death tick.
22. Using the escape pod in the ambush state kills the player after the 97-tick escape sequence.
23. The ambush arrival changes only the y coordinate (XOR 31); the departure system stays
    "current" (its market too), but its name is blanked.
24. Buying fuel sets the main counter to 0.
25. In the death sequence the death notice is drawn only after logic-substep redraws, so it
    flickers at the substep rate in the baseline. Not a parity item.
26. Static screens are not cleared when a message expires, so on the charts, status and market
    screens the baseline leaves the message's text visible until the screen is redrawn. LodeStar
    should hide expired messages; this is not a parity item.
27. The baseline's status screen labels condition codes 2 and 3 the wrong way round (code 2,
    energy healthy, gets the label the original used for the worst condition, and code 3 the
    middle one). Parity compares the code; LodeStar labels code 1 safe, 2 caution, 3 danger.
28. The baseline's cargo/equipment loss message appends the wrong text item (the name of goods
    item 13 instead of the "destroyed" suffix). Parity compares the event, not the text.
29. Integer behaviour: the main counter wraps 0 -> 255; the kill count wraps at 65536; the galaxy
    number wraps 7 -> 0; canister speeds at death are taken AND 255.

Differences between the baseline and the 1984 original that parity depends on (from the
baseline's README and code): logic at a fixed 12 Hz with two motion substeps and a redraw after
each; the pulse laser's recharge counted in ticks (5 per tick) instead of at the original's 50 Hz
interrupt; floating-point positions and orientations (no rounding drift) with re-orthonormalising
on the original schedule; a browser save under a typed name instead of a tape; the pause
function and its toggles are reachable in the baseline through its own pause key. The
cassette-version scope applies: no missions, no generated planet descriptions, no extra ship
types and no military/mining lasers.

---

### D.15 Deliberate differences in LodeStar (this section)

1. Third-person orbit camera; the player selects the active laser mount 1-4 instead of switching
   views; only the active mount fires; the space view is always visible, so there is no need to
   switch views to see. All rules tied to "current view" apply to the active mount (D.4.3).
2. All names, text, titles, credits and prompts are new; message wording is the designer's
   within the budgets of D.9.

---

## Open questions (section D)

1. **Render-time random draws.** The baseline's renderer draws from the shared game generator
   (sun edge, firing beams, dust recreation) on every substep, even while paused, which shifts
   every later game-logic draw. LodeStar's renderer is different and cannot match. Either the
   parity harness must run the baseline with rendering's draws moved to a separate generator, or
   parity tests must avoid scenes with a visible sun, firing ships and dust recreation. Which
   does the project choose? (Recommendation: separate generator in both, and a patched baseline
   for the parity reference.)
2. **Dust in a third-person camera.** The flight-state reset consumes 54 draws for the dust (9
   for the ambush). LodeStar should keep these draws, even if its dust is drawn differently, to
   stay in step; confirm.
3. **Countdown surviving death (D.14 item 14).** It is unclear whether the 1984 original behaves
   this way or whether this is a baseline defect. Parity follows the baseline unless the owner
   decides otherwise.
4. **Beam laser lines (D.14 item 18)** and **the galactic jump message (item 16)** look like
   baseline defects; LodeStar may show beam visuals and the jump message without affecting
   logic. Confirm that these are visual-only and outside parity.
5. **Arrival screen (item 15).** Should LodeStar keep a chart on screen across a jump, as the
   baseline intends, or always show the space view, as the baseline does? Visual only.
6. **Shop pause duration.** The baseline uses 1000 ms of wall-clock time; does the parity harness
   need it as exactly 12 ticks (keys typed meanwhile are queued either way)?
7. **Missile-block colours and the escape-pod palette shift** are presentation; LodeStar needs a
   clear owned-pod indicator, but its form is open.
8. **Pause handler resume keys.** The baseline accepts two keys for resume and uses the caps-lock
   key for the damping toggle; LodeStar should pick its own bindings.
