# The planet and the sun

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

Every system has a planet ahead of the arriving pilot and a sun behind. Flying too low crashes into the planet; flying too near the sun burns the pilot up, but skimming it with a fuel scoop fills the tank. This feature places the two bodies on arrival and runs the altitude and sun checks the tick makes every 32 ticks. The mechanics are in [RULES B.10.1](../../../docs/RULES.md#b101-on-arrival-in-a-system-ordinary-or-galaxy-jump), [B.14](../../../docs/RULES.md#b14-altitude-and-crashing-into-the-planet) and [B.15](../../../docs/RULES.md#b15-the-sun-cabin-heat-and-fuel-scooping).

## What it does

### Placing the bodies

- ✅ `place_on_arrival` puts the planet in slot 0 and the sun in slot 1 at the positions the system gives, the planet's taking bit 0 of legal status from before the arrival halves it ([RULES B.10.1](../../../docs/RULES.md#b101-on-arrival-in-a-system-ordinary-or-galaxy-jump), [A.3.7](../../../docs/RULES.md#a37-other-uses-of-a-systems-bytes)). At home the planet is at (−2 L, −2 L, 5 L), or (3 L, 3 L, 6 L) with that bit set, and the sun at (2 L + 512, 0, −5 L).
- ✅ The planet is in the system's style and spins for ever about both axes (`new_planet`, both counters 127, positive); the sun keeps the default orientation and counters 0 ([RULES B.9.2](../../../docs/RULES.md#b92-kinds-of-object)).

### The checks

- ✅ `planet_and_sun_checks` is step 6 of the tick ([RULES B.3.3](../../../docs/RULES.md#b33-the-tick-logic-flight-mode-and-death-mode-in-dying-form)): outside the Deep, at C mod 32 = 10 the altitude check and at C mod 32 = 20 the sun check. `BodyCheck::Crashed` or `Burned` means the player dies and the tick ends at once, with no chores and no countdown ([RULES B.23 Q-B11](../../../docs/RULES.md#b23-quirks-reproduce-these)); the lead calls [death](../death/death.md).
- ✅ The altitude check first shows the low-energy warning (M2) when energy is below 50.
- ✅ Altitude is 255 unless the planet in slot 0 is within a far unit on every axis and its coarse squared distance over 256 is at most 255; then 37 or less of it is inside the planet (a crash), and otherwise the altitude is the square root of 256 times the excess plus the fine value of the planet's **x** coordinate, capped at 255 ([RULES B.14](../../../docs/RULES.md#b14-altitude-and-crashing-into-the-planet), Q-B6). Altitude 0 is a crash, which needs that fine value to be 0.
- ✅ Cabin temperature is 30 in the safe zone or with the sun a far unit or more away on any axis, 31 when the sun is within that box but its coarse squared distance over 256 is above 255, and otherwise 285 minus that value; above 255 the sun burns the player up ([RULES B.15.1](../../../docs/RULES.md#b151-cabin-temperature), Q-B7).
- ✅ At 224 or more with the fuel scoop fitted, fuel rises by ⌊speed / 8⌋ up to a full tank (`equipment::scoop_sun_fuel`) and the fuel-scooping message (M1) shows, even when nothing was gained ([RULES B.15.2](../../../docs/RULES.md#b152-fuel-scooping-from-the-sun), [A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 15).
- ✅ Neither check draws a random number.

### For the presentation

- ⚠️ The dashboard shows altitude as ⌊altitude / 16⌋ and cabin temperature as ⌊temperature / 16⌋ ([RULES D.7](../../../docs/RULES.md#d7-dashboard-hud-indicators)).
- ⚠️ The fuel-scooping and low-energy messages play no sound, as in the baseline ([RULES D.14](../../../docs/RULES.md#d14-quirks-and-edge-cases-baseline-behaviour-that-parity-depends-on) item 17).
- ⚠️ The sun's ragged edge is drawn from the cosmetic generator, never the main one ([RULES B.4.4](../../../docs/RULES.md#b44-render-time-draws-needed-for-parity), [deliberate difference 3](../../../docs/RULES.md#deliberate-differences-from-the-baseline)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The pilot dives into the planet | Death, at the next check (up to 32 ticks late) | Watch the altitude bar | ✅ |
| The pilot flies into the sun's heat | Death when the temperature would pass 255 | Watch the temperature bar; scoop at its edge | ✅ |

## What it deliberately doesn't do

- No gradual heat damage: the baseline has none ([RULES B open question 4](../../../docs/RULES.md#open-questions-section-b)).
- It does not scoop objects; that is the combat rules' contact step ([RULES B.15.3](../../../docs/RULES.md#b153-scooping-objects), [C.11](../../../docs/RULES.md#c11-contact-collisions-scooping-and-the-station)).

## Where it lives

- Code: [`mod.rs`](mod.rs) (`new_planet`, `place_on_arrival`, `BodyCheck`, `planet_and_sun_checks`, `altitude_check`, `sun_check`).
- Uses: the bubble, cockpit, equipment, pilot, ships, space and universe capabilities.
