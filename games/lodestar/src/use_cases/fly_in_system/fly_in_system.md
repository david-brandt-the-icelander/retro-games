# Fly in a system

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

Once launched, the pilot flies their ship in a star system: turning, changing speed, choosing which laser mount fires, fighting, scooping, docking or jumping away. This use case owns the 12 Hz tick that moves everything, and hands the picture what it needs to draw each frame. The exact mechanics are in [RULES B](../../../docs/RULES.md#b-flight-the-bubble-and-navigation), [C](../../../docs/RULES.md#c-combat-ai-spawning-law-and-ranks) and [D](../../../docs/RULES.md#d-game-modes-controls-screens-messages-sound-cues-and-time); this document says which of them LodeStar does yet.

## What it does

- ✅ The sim advances in whole ticks at 12 a second, whatever the frame rate. A frame longer than a quarter of a second is cut short, so a stall never runs more than three catch-up ticks.
- ✅ Choosing a laser mount (front, rear, left or right) takes effect at the next tick and is reported once, even when the key is tapped between two ticks.
- ⚠️ Each tick runs the steps of RULES B.3 in order, including both half-step motion substeps.
- ⚠️ Held dive, climb and roll keys change the attitude rates with the acceleration, damping and auto-centre of RULES B.5; held speed keys change speed within the range of RULES B.6.
- ⚠️ Every object in the bubble moves and turns by its own motion and by the player's, as RULES B.7 says, and is straightened on the schedule of RULES B.8.
- ⚠️ The bubble holds the planet, the sun or station, and up to eleven other objects, placed and removed as RULES B.9 and B.10 say.
- ⚠️ The station rotates, keeps its safe zone and accepts or refuses docking by the four checks of RULES B.11 and B.12; the auto-dock docks at once when fitted and switched on.
- ⚠️ The in-system jump, altitude, crashing, cabin heat and fuel scooping behave as RULES B.13 to B.15 say.
- ⚠️ The hyperspace countdown, the jump, the galaxy jump and the ambush follow RULES B.16 and A, with the countdown cancelled by death and retargeting range-checked (deliberate differences 5 and 6).
- ⚠️ The escape pod launches as RULES B.17 says, without the abandoned hull ever colliding with the player (deliberate difference 7).
- ⚠️ Lasers fire only from the active mount, and missiles lock along it, with the hit test, heat and damage of RULES C (deliberate differences 1 and 8).
- ⚠️ Ships run their AI, fire, launch missiles and escape pods, explode and drop canisters as RULES C says, and the main loop spawns new arrivals by the rules of RULES C.
- ⚠️ Every random draw the rules make comes from the main generator, in the order RULES gives; everything drawn only for the picture comes from the cosmetic generator (deliberate difference 3).
- ⚠️ The picture draws every object between its previous and current tick positions, interpolated by how far the frame is between ticks, so 12 Hz logic looks smooth at any frame rate.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The game stalls (a breakpoint, a slow disk) | The ship freezes, then catches up with at most three ticks | Nothing; the stall is cut to a quarter of a second | ✅ |

## What it deliberately doesn't do

- The tick never runs at a variable rate, and nothing in the picture writes to the sim.
- The camera is not part of the rules: orbiting or zooming never changes what the sim does.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`TickClock`, `InputRecord`, `FlyInSystem`); the Godot side is `SimHost` in [`src/presentation/bridge`](../../presentation/bridge/src/sim_host.rs).
- Diagrams: [`.dev/class-diagram.json`](.dev/class-diagram.json), and the game's [component diagram](../../../.dev/component-diagram.json).
- Subsystems: the [desktop build](../../hosting/godot/desktop-build.md).
