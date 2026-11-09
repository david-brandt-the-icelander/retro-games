# The station and its safe zone

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

Each system's station turns slowly in orbit. Near it is the safe zone, where pirates calm down, rocks stop coming and the pilot cannot hop. The pilot launches from the station into that zone, flies away until it is gone and the sun is back, and on returning sees it appear again near the planet. This feature places the station on launch and on approach, swaps it with the sun when it leaves, and gives the tick the removal-for-distance test. The mechanics are in [RULES B.9.4](../../../docs/RULES.md#b94-removal-for-distance), [B.10.2](../../../docs/RULES.md#b102-on-launch-from-the-station) and [B.11](../../../docs/RULES.md#b11-the-station-and-its-safe-zone).

## What it does

### Launch

- ✅ `launch` is the launch tunnel's completion ([RULES D.3.4](../../../docs/RULES.md#d34-tunnels-launch-docking-hyperspace)): the flight-state reset (54 draws) with the bubble emptied, a selection from the cursor, the planet in the current system's style a far unit ahead, the station 256 sim units behind facing away, the safe zone, speed 12, legal status OR-ed with the contraband score ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 20) and the front mount active. There is no sun until the station leaves ([RULES B.10.2](../../../docs/RULES.md#b102-on-launch-from-the-station)).

### The station appearing

- ✅ `station_appearance` is step 5 of the tick ([RULES B.3.3](../../../docs/RULES.md#b33-the-tick-logic-flight-mode-and-death-mode-in-dying-form)): on ticks where C mod 32 = 0, outside the Deep, with no station present and a planet in slot 0, the station appears 49152 sim units out along the planet's nose as stored, unless the planet is a far unit away on any axis or that point is 49152 or more out on any axis ([RULES B.11.1](../../../docs/RULES.md#b111-the-station-appears)). It draws nothing.
- ✅ The new station faces the planet (nose = −planet nose), copies the planet's roof and side as stored, so its frame may be mirrored until its first re-orthonormalisation (Q-B9), has AI byte 1 and rolls for ever (roll 0xFF). It takes slot 1 from the sun and the player is in the safe zone.
- ✅ Because planets are never re-normalised, a planet's shrinking nose brings a later station closer to the planet ([RULES B.23 Q-B1](../../../docs/RULES.md#b23-quirks-reproduce-these)).

### Leaving

- ✅ `too_far` is the removal-for-distance test of [RULES B.9.4](../../../docs/RULES.md#b94-removal-for-distance) and C.4 step 8: a non-body object with any coordinate of 57600 sim units or more (coarse value above 224, or a far unit). Bodies never leave.
- ✅ `station_leaves` is the station's removal: slot 1 becomes a new sun at (0, 6 L, 0) with nothing shifted, the safe zone ends, and the missile lock is adjusted as if slot 1 were removed: lost with the target-lost message (M6) when on the station, moved down one when on a later slot even though nothing moved ([RULES B.23 Q-B5](../../../docs/RULES.md#b23-quirks-reproduce-these)). Homing missiles are not retargeted.
- ⚠️ The lead's removal step tests `too_far` for every non-body object; for the station it calls `station_leaves` and processes slot 1, now the sun, again in the same tick (C.17 item 19); for any other object it uses the combat rules' removal with its missile retargeting ([RULES C.7.4](../../../docs/RULES.md#c74-when-ships-leave-the-bubble)).

### The safe zone

- ✅ "In the safe zone" is `Cockpit::station_present`. While it holds, spawning brings only traders ([spawning](../spawning/spawning.md)), the in-system jump is refused ([in-system jump](../in_system_jump/in_system_jump.md)) and the sun check reads 30 ([planet and sun](../planet_and_sun/planet_and_sun.md)) ([RULES B.11.2](../../../docs/RULES.md#b112-what-the-safe-zone-does)).
- ⚠️ Pirates and hunters lose their aggression in the safe zone, and a station shot to 0 energy turns hostile and launches police; those are the combat rules, built with the AI.
- ⚠️ The compass points at the station instead of the planet and the dashboard shows the safe-zone indicator.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The pilot arrives far from the planet | No station until the pilot has flown close enough that the appearance point is within reach | Hop towards the planet | ✅ |
| The missile was locked beyond the station when it left | The lock moves to a different object (Q-B5) | Re-lock | ✅ |

## What it deliberately doesn't do

- No collision with the station's hull outside the docking box ([RULES B.23 Q-B16](../../../docs/RULES.md#b23-quirks-reproduce-these)); docking is the [docking](../docking/docking.md) feature.
- The station can never be destroyed.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`new_station`, `station_appearance`, `too_far`, `station_leaves`, `StationLeft`, `launch`).
- Uses: the bubble, cockpit, flight, pilot, random, ships, space and universe capabilities; the [hyperspace](../hyperspace/hyperspace.md) feature's `Navigation` and `Countdown`, and the [planet and sun](../planet_and_sun/planet_and_sun.md) feature's `new_planet`.
