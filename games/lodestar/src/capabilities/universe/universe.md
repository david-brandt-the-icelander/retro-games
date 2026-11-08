# The universe

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the features and use cases built on it

## What this is for

The pilot lives in eight Reaches of 256 systems each, and needs to know where every system is, what it is like (economy, government, tech level, population and the rest), how far it is and whether a full tank reaches it. This capability works all of that out from the generator of [RULES A.3](../../../docs/RULES.md#a3-galaxies-and-systems) and the GDD's data ([§ 4.2 to § 4.5](../../../docs/GDD.md#42-name-generator-data)), measures distance and range by [RULES A.4](../../../docs/RULES.md#a4-distance-nearest-system-and-fuel), does the pure computations of choosing and reaching a destination in [RULES A.5](../../../docs/RULES.md#a5-hyperspace-target-countdown-and-jump), and gives the charts of [RULES A.6](../../../docs/RULES.md#a6-the-charts-behaviour) their behaviour as functions the picture calls.

## What it does

### Galaxies and systems

- ✅ Every system is made from a generator state of three words; system `n + 1` is system `n` after four advance steps of [RULES A.3.2](../../../docs/RULES.md#a32-the-advance-step), with the sum wrapping at 16 bits.
- ✅ The next Reach's system-0 state is the current one with each of its six bytes rotated left by one bit on its own ([RULES A.3.3](../../../docs/RULES.md#a33-the-galactic-jump-transform)); eight jumps return to Reach 1, and all eight starting states match GDD § 4.2's test vectors.
- ✅ Reach 1 starts from the GDD's state `5D38 3CAC 0E31`, the same as the start pilot's stored galaxy.
- ✅ Each system's position, government, economy (forced away from codes 0, 1, 4 and 5 under governments 0 and 1), tech level, population, productivity and radius follow the formulas of [RULES A.3.4](../../../docs/RULES.md#a34-system-properties), within the ranges given there.
- ✅ System 0 of Reach 1 is at (60, 93): a wealthy farm world under a free charter, tech level 6 as shown, population 3.1 billion, radius 6,460 km, settled by the default settlers (GDD § 4.2).
- ✅ Across all eight Reaches every government has 32 systems, names have 2 to 8 letters (3 to 8 in Reach 1), and 2,047 of the 2,048 systems have a position of their own (GDD § 4.2).
- ✅ Names are built from GDD § 4.2's syllable table by the structure of [RULES A.3.5](../../../docs/RULES.md#a35-name-generation-structure): three or four syllables by bit 6 of `b0`, entry 0 printing nothing but still advancing the private copy. Names are held in capitals.
- ✅ The inhabitants phrase follows [RULES A.3.6](../../../docs/RULES.md#a36-inhabitants-structure) with GDD § 4.5's word lists, in word case with one plural mark and no brackets; the longest phrase in any Reach is 30 characters.
- ✅ Each system gives its galaxy-chart dot width, local-chart disc radius and planet style (A or B, as an object type) by [RULES A.3.7](../../../docs/RULES.md#a37-other-uses-of-a-systems-bytes) and [B.9.2](../../../docs/RULES.md#b92-kinds-of-object).
- ✅ Each system gives the planet's and the sun's arrival positions in sim units by RULES A.3.7, the planet's taking the low bit of legal status from before the arrival halves it.
- ✅ Reach names, the printed economies and the government labels come from GDD § 4.3 and § 4.4.

### Distance, range and selection

- ✅ Distance between two systems is [RULES A.4.1](../../../docs/RULES.md#a41-distance-between-two-systems)'s, in tenths of a light year, including the 16-bit wrap that makes some far-edge systems reachable ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 1).
- ✅ The nearest-system search uses the cheap metric of [RULES A.4.2](../../../docs/RULES.md#a42-nearest-system-to-a-point): ties go to the lower number and nothing under the bound gives system 0.
- ✅ A jump is in range only when `0 < distance ≤ fuel` ([RULES A.4.3](../../../docs/RULES.md#a43-fuel)); from home, ten systems are in range of a full tank, the nearest at 2.0 LY, seven of them factory worlds (GDD § 4.2).
- ✅ A jump takes its distance off the fuel, which never goes below 0 (deliberate difference 6).
- ✅ Selecting from the cursor returns the system nearest the cursor, its position (where the cursor snaps) and its distance from the pilot ([RULES A.5.1](../../../docs/RULES.md#a51-selected-system)).
- ✅ The galactic jump's effect on the universe is [RULES A.5.7](../../../docs/RULES.md#a57-the-galactic-jump) steps 1 to 4: the next Reach, and the system nearest (96, 96) in it as current system, selection and cursor position, with distance 0.
- ✅ A normal jump's random byte means a mis-jump when it is 253 or more, and a mis-jump leaves the pilot at the departure position with the low 5 bits of y flipped ([RULES A.5.5](../../../docs/RULES.md#a55-the-normal-jump)).

### Charts

- ✅ Arrow taps move the cursor one galactic unit (up is −1 in y), each axis refusing a move that would leave 0..255 ([RULES A.6.3](../../../docs/RULES.md#a63-cursor-and-keys-on-a-chart)).
- ✅ Held arrows repeat only when docked, on even ticks, one unit per axis with opposite arrows cancelling: six units a second.
- ✅ The home key puts the cursor on the pilot's position without selecting.
- ✅ The galaxy chart places a system at `(x, y / 2)` and draws the fuel-range circle at radius `fuel >> 2` ([RULES A.6.1](../../../docs/RULES.md#a61-galaxy-chart)); the local chart's circle has radius `fuel` pixels.
- ✅ The local chart shows the systems within `|dx| < 20` and `|dy| < 38` of the pilot, at `(104 + 4dx, 90 + 2dy)`, with signed differences and no wrap at the galaxy's edge ([RULES A.6.2](../../../docs/RULES.md#a62-local-chart), [D.6.7](../../../docs/RULES.md#d67-local-chart)).
- ✅ Local chart labels take their own text row, then the row below, then the row above; a free row above row 3 hides the system, disc and label, and no free row leaves the disc unlabelled (RULES A.14 item 16). From home, this hides system 78.
- ✅ The local chart's cursor cross shows only within `−26 ≤ dx < 38` and `−36 ≤ dy < 38` of the pilot.
- ⚠️ The galaxy chart draws every system as its dot, a large cross (half-size 7) on the pilot's position, a small cross (half-size 4) on the cursor, and a title with the Reach's name and number, from the functions above.
- ⚠️ The local chart draws a large cross (half-size 16) at its centre, each shown system's disc and, on its label row, its name to the disc's right where there is room.
- ⚠️ The show-distance key on a chart selects from the cursor, redraws the chart, then shows the selected system's name and, when it is not 0, its distance.

### Choosing and making a jump

These use the computations above; they belong to the hyperspace feature and the flight use case.

- ⚠️ Selection (RULES A.5.1) happens on the hyperspace key, the show-distance key, opening the system-data screen, every showing of the status screen (including the return after docking or leaving a shop), launching, game start (cursor on the pilot's position) and the galactic jump; moving the cursor alone never selects.
- ⚠️ The hyperspace key and the galaxy-drive key check docking, a running countdown, distance and range or the fitted drive in the order of [RULES A.5.2](../../../docs/RULES.md#a52-the-hyperspace-key-normal-jump) and [A.5.3](../../../docs/RULES.md#a53-the-galaxy-drive-key); the galaxy-drive key removes the drive and clears legal status at the press.
- ⚠️ The countdown of [RULES A.5.4](../../../docs/RULES.md#a54-the-countdown) runs 85 flight ticks, is cancelled by docking and by death (deliberate difference 5), and at 0 performs the normal or galactic jump.
- ⚠️ During a countdown, a new selection replaces the destination only when it is within fuel range; otherwise the old destination and distance stay (deliberate difference 6).
- ⚠️ The normal jump subtracts the destination's distance from fuel, draws the mis-jump byte from the main generator, plays the 16-tick tunnel, then either mis-jumps or arrives at the destination with distance 0 ([RULES A.5.5](../../../docs/RULES.md#a55-the-normal-jump)).
- ⚠️ The common arrival of [RULES A.5.6](../../../docs/RULES.md#a56-the-common-arrival) draws the market byte, rebuilds availability, resets the flight state, halves legal status and places the planet and sun from the positions above, keeping a chart on screen if one was showing (deliberate difference 10).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| A far-edge system is reported a short hop away | The baseline's 16-bit distance wrap, kept on purpose (RULES A.14 item 1) | Nothing; the jump is allowed | ✅ |
| No system is near the cursor by the cheap metric | System 0 is selected (RULES A.14 item 2) | Nothing | ✅ |
| A system disappears from the local chart | Its label row is above the title area (RULES A.14 item 16) | Nothing; it shows on the galaxy chart | ✅ |

## What it deliberately doesn't do

- It never draws a random number: system generation, names, inhabitants, distance, the search and the charts are pure (RULES A.2.3). The jump's draws belong to whoever performs the jump.
- It keeps no state of its own beyond what callers pass in: the pilot's galaxy, position and fuel live in the pilot.
- It does not format numbers for the screen (population in billions, distances with one decimal); the presentation does.

## Where it lives

- Code: [`mod.rs`](mod.rs) re-exports [`galaxy.rs`](galaxy.rs) (`Seed`, `Galaxy`, the nearest-system search), [`system.rs`](system.rs) (`System`, `PlanetStyle`, `Point`), [`names.rs`](names.rs) (the GDD's syllables, word lists and labels; `name`, `inhabitants`), [`navigation.rs`](navigation.rs) (`distance`, `in_range`, `fuel_after_jump`, `Selection`, `select`, `reach_jump`, the mis-jump test and position) and [`chart.rs`](chart.rs) (`ChartCursor`, `Arrow`, `HeldArrows`, the chart geometry and `local_chart`).
- Diagrams: [`.dev/class-diagram.json`](.dev/class-diagram.json).
