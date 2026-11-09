# Spawning

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

Space around the pilot fills up by itself: every 21 seconds or so a trader, a rock or a canister drifts in, or the police come for a pilot with contraband or a record, or pirates, hunters or aliens arrive, as the system's government allows. This feature places those arrivals and the other new objects whose placement the rules fix (the hostile template, the alien group, a launch straight ahead, a ship's children), drawing from the main generator in exactly RULES' order. The mechanics are in [RULES B.10.3 to B.10.8](../../../docs/RULES.md#b103-the-encounter-template) and [C.16](../../../docs/RULES.md#c16-spawning).

## What it does

### Placements

- ✅ `hostile_template` is the hostile template procedure: one ordinary draw places a template at (±8192, ±8192, 8192) by the top bits of its two bytes, with AI byte 0xC0 and the E.C.M. bit when the second byte is 245 or more, then a carry-cleared draw is returned to the caller ([RULES C.16.4](../../../docs/RULES.md#c164-the-hostile-template-procedure), [B.10.3](../../../docs/RULES.md#b103-the-encounter-template)). Spawning, the alien group and the [death](../death/death.md) wrecks use it.
- ✅ `Template::make` gives a fresh object the template's position, orientation, AI byte, speed and counters, with its type's own energy and missiles ([RULES B.9.3](../../../docs/RULES.md#b93-object-creation)).
- ✅ `alien_group` is a hostile template with AI byte 0xFF, then an alien mothership and an alien drone from it; it reports a full bubble, and its draws are spent either way ([RULES B.10.4](../../../docs/RULES.md#b104-the-alien-mothership-pair), [C.16.6](../../../docs/RULES.md#c166-the-alien-group-and-mis-jump-space)).
- ✅ `launch_straight_ahead` places an object at (0, −28, 14) facing away, with AI byte 0x80 OR (target slot mod 32) × 2 and speed (2 × player speed) mod 256, which the next own-motion update clamps ([RULES B.10.5](../../../docs/RULES.md#b105-launch-straight-ahead)). The escape pod's hull uses it; the player's missiles can.
- ✅ `child_of` places a ship's child: the parent's position, orientation, speed and counters with bit 0 of the roll cleared; from the station, 192 sim units along its nose as stored, at speed 32 ([RULES B.10.6](../../../docs/RULES.md#b106-children-of-a-ship)). The AI byte and a canister's own spin and speed draw are the launching rule's ([RULES C.5.7](../../../docs/RULES.md#c57-launching-a-child-ship)), built with combat.

### The periodic spawn

- ✅ `periodic_spawn` is the event the tick runs when the main counter has just reached 0 and the player is not dying ([RULES B.3.3](../../../docs/RULES.md#b33-the-tick-logic-flight-mode-and-death-mode-in-dying-form) step 8, [C.16.1](../../../docs/RULES.md#c161-when)). In mis-jump space it does nothing and draws nothing.
- ✅ One byte decides: below 35 with fewer than 3 asteroids present, the benign spawn; otherwise the hostile spawn ([RULES C.16.2](../../../docs/RULES.md#c162-the-event)).
- ✅ The benign spawn places a template 38 K ahead; its x takes 512 more when the position draw leaves the generator's carry set ([RULES C.17](../../../docs/RULES.md#c17-quirks-and-edge-cases) item 15), and its y is the event's own byte. Bit 6 of the next byte gives a trader with that byte's half as AI byte and roll and a speed of at least 16; otherwise, outside the safe zone, a rock spinning for ever or a moving one, or, when a last byte is below 5, a canister ([RULES C.16.5](../../../docs/RULES.md#c165-the-benign-spawn)).
- ✅ In the safe zone only traders come: the benign spawn stops after its third draw, and the hostile spawn stops before drawing ([RULES B.11.2](../../../docs/RULES.md#b112-what-the-safe-zone-does)).
- ✅ The hostile spawn brings a police interceptor when the police template's byte is below twice the contraband score, OR-ed with legal status when police are already present; any police present stop the rest ([RULES C.16.3](../../../docs/RULES.md#c163-the-hostile-spawn) steps 2 to 4).
- ✅ The spawn delay `SpawnDelay` holds back the next hostile ships: it counts down first and lets a spawn through only when it goes below 0. A pack of n + 1 pirates sets it to n; a lone ship or a failed alien roll adds 1.
- ✅ Outside government 0 a byte stops the spawn when 90 or more or when its low three bits are below the government, giving 256, 78, 66, 55, 44, 33, 22 and 11 chances in 256 for governments 0 to 7.
- ✅ A second template's byte of 200 or more brings a pirate pack of (byte AND 3) + 1 small fighters, each A or B by one byte, all at one place; otherwise a lone small fighter B, heavy fighter or hunter with AI byte 0xC0 and the E.C.M. bit when the template's second byte is 200 or more, or, for type 6, the alien group on a further byte of 200 or more.
- ✅ Adds to a full bubble fail silently and their draws stay drawn ([RULES C.16.8](../../../docs/RULES.md#c168-caps)).
- ⚠️ The lead keeps `SpawnDelay` beside the cockpit and calls `periodic_spawn` only when `Cockpit::count_down_counter` returns true and the player is not dying. Ordinary arrival and the in-system jump set the delay to 0; galactic and mis-jump arrivals keep it ([RULES B.23 Q-B12](../../../docs/RULES.md#b23-quirks-reproduce-these)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The bubble is full when a spawn comes | Nothing new appears; the draws are spent | Nothing; the next event tries again | ✅ |

## What it deliberately doesn't do

- It does not run the arrivals' AI, missiles, police from the station or loot canisters; those are the combat rules ([RULES C.5](../../../docs/RULES.md#c5-the-ship-ai) to C.15), which use these placements.
- It never draws a number for the picture.

## Where it lives

- Code: [`mod.rs`](mod.rs) re-exports [`template.rs`](template.rs) (`Template`, `hostile_template`, `alien_group`, `launch_straight_ahead`, `child_of`) and [`periodic.rs`](periodic.rs) (`SpawnDelay`, `periodic_spawn`).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Uses: the bubble, cockpit, pilot, random, ships and space capabilities. The main generator's `carry` was added for the benign spawn's x offset.
