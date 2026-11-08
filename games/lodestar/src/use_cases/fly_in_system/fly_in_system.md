# Fly in a system

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

The pilot flies their ship from station to station: launching, turning, changing speed, choosing which laser mount fires, fighting, scooping, docking or jumping away, and trading while docked. This use case owns the 12 Hz tick, the game's modes around flight (title, docked, the tunnels, flight, death and the escape pod), and the order in which every rule runs. The rules themselves live in the capabilities and features it calls; each has its own document. The exact mechanics are in [RULES B](../../../docs/RULES.md#b-flight-the-bubble-and-navigation), [C](../../../docs/RULES.md#c-combat-ai-spawning-law-and-ranks) and [D](../../../docs/RULES.md#d-game-modes-controls-screens-messages-sound-cues-and-time).

## What it does

### Time

- ✅ The sim advances in whole ticks at 12 a second, whatever the frame rate. A frame longer than a quarter of a second is cut short, so a stall never runs more than three catch-up ticks.
- ✅ Each tick is two substeps, counted by a substep counter that keeps counting while paused; the even one is the logic substep ([RULES D.1](../../../docs/RULES.md#d1-time-base-12-hz-logic-with-two-motion-substeps)). In flight both substeps move everything by half a step before the logic; while dying the logic runs first ([RULES B.3.2](../../../docs/RULES.md#b32-what-one-substep-does-by-mode)).
- ✅ The presses of a tick are dispatched in its first substep, so a queued flight action reaches that same tick's logic, and a tunnel started by a key draws its first step in the same tick.

### Modes ([RULES D.2](../../../docs/RULES.md#d2-modes-and-the-state-machine), [state diagram](.dev/Mode.state-diagram.json))

- ✅ Power-on shows the title. Only the first press in a substep answers it; the start press makes the playing pilot a copy of the last saved or loaded one, resets the flight state (54 discarded draws) and docks at the system nearest the pilot's position, on the status screen ([RULES D.3.1](../../../docs/RULES.md#d31-title-sequence)).
- ✅ Loading a pilot on the title and saving while docked go through the [saving feature](../../features/saving/saving.md), with the store passed in by the host.
- ✅ Docked: launch starts the launch tunnel; buying and selling go through the [trading feature](../../features/trading/trading.md) at the current system's economy; equipment is bought from the list the system's tech level offers; the docked chores cool the laser and count down the main counter and the message ([RULES D.3.3](../../../docs/RULES.md#d33-docked-mode)).
- ✅ Every tunnel lasts 16 steps, one per logic substep after the one that started it; its completion launches ([station](../../features/station/station.md)), finishes docking ([docking](../../features/docking/docking.md)) or arrives ([hyperspace](../../features/hyperspace/hyperspace.md)) ([RULES D.3.4](../../../docs/RULES.md#d34-tunnels-launch-docking-hyperspace)).
- ✅ Death starts only once, drops held and queued input, shows the front of the space view, runs 61 ticks of dying flight logic and returns to the title, where the saved pilot is restored ([death](../../features/death/death.md), [RULES D.3.10](../../../docs/RULES.md#d310-death)).
- ✅ The escape pod switches to the escape mode for 97 ticks of drift, then docks the rescued pilot, or kills a pilot who used it in the Deep ([escape pod](../../features/escape_pod/escape_pod.md), [RULES D.3.9](../../../docs/RULES.md#d39-escape-pod)).
- ✅ Pause stops all motion, logic, counters and timers; while paused, presses go to the pause handler: resume, the auto-centre and damping toggles, and quit, which resets the flight state and returns to the title ([RULES D.3.12](../../../docs/RULES.md#d312-pause)).
- ✅ The hyperspace and galaxy-drive keys act at once, docked or flying, and report their outcome ([RULES D.3.7](../../../docs/RULES.md#d37-hyperspace-the-action-the-countdown-and-the-jump)).
- ✅ The system-data and status screens, and moving the chart cursor, select the system nearest the cursor, which may retarget a running countdown within range (deliberate difference 6).
- ✅ The active mount changes on a mount press, takes effect in that tick and is reported once.

### The flight tick ([RULES D.3.6](../../../docs/RULES.md#d36-flight-mode-the-per-tick-flight-logic), [B.3.3](../../../docs/RULES.md#b33-the-tick-logic-flight-mode-and-death-mode-in-dying-form))

- ✅ The eleven steps run in RULES' order: attitude; player actions; the slot loop; area blast and recharge; the station appearing; the planet and sun checks; laser and E.C.M. bookkeeping; the message timer; the main counter and periodic spawning; laser heat; the hyperspace countdown.
- ✅ Player actions: the speed keys, then each queued action in the order pressed (unarm, arm, fire missile, area blast, escape pod, in-system jump, E.C.M., auto-dock), then the lasers if held and the space view shows. The escape pod and a successful auto-dock end the step at once.
- ✅ The slot loop processes every object in slot order with the eight steps of [RULES C.4](../../../docs/RULES.md#c4-what-happens-to-each-ship-every-frame), calling the [combat](../../capabilities/combat/combat.md) and [flight](../../capabilities/flight/flight.md) capabilities; a slot whose object left is processed again, so objects added during the loop are processed in the same tick.
- ✅ An object too far away leaves the bubble and missiles and the lock follow it; the station leaving is replaced by the sun in its slot ([RULES B.9.4](../../../docs/RULES.md#b94-removal-for-distance)).
- ✅ The station's docking box runs the docking checks: a pass docks, and the rest of the tick still runs (Q-B13); a fail bumps or kills the player.
- ✅ A death part-way through the loop carries on from the next slot over the wreckage (Q-B14); a crash or burn in step 6 ends the tick.
- ✅ The same inputs always give the same game: two runs of 3,000 ticks with the same held keys end in identical states.
- ✅ A 40,000-tick game with every kind of press passes through flight, the tunnels, docking, the escape pod and death without a panic (debug builds check every overflow).
- ⚠️ The hyperspace countdown ticks only in Flight and Death modes, so a countdown cannot jump on the tick an escape pod is launched. The baseline would still run it that tick; RULES does not say what then happens, and this edge case is not covered by a test.
- ⚠️ The title ship's approach and spin, the chart cursor's held movement, and the display frame counter are presentation, not sim; the presentation builds them ([RULES D.3.1](../../../docs/RULES.md#d31-title-sequence), [D.3.3](../../../docs/RULES.md#d33-docked-mode)).
- ⚠️ Name entry on the title, prompts that capture the keyboard and the shop confirmation pause belong to the panels; the sim takes a loaded name and finished purchases instead (deliberate difference 12).
- ✅ Power-on takes the 54 stardust draws of the first fill from the main generator and discards them, before the title ([RULES A.2.1](../../../docs/RULES.md#a21-state)); buying fuel while docked sets the main counter to 0 ([RULES A.12.4](../../../docs/RULES.md#a124-the-shop-and-each-items-effect)).
- ✅ Parity: 37 scripted and autopiloted scenarios, 354,807 ticks in all (the longest 101,069), replayed through this tick and through the baseline with LodeStar's data and deliberate differences patched in, match bit for bit on every tick: the random stream, the player's state, the pilot and every object in the bubble. The harness holds the baseline, so by the clean-room rule it runs only outside the repository, in the spec-and-verify role's workspace (8 November 2026).
- ⚠️ The parity harness's scenarios have not reached the station leaving while the missile lock is on a slot above 1 (Q-B5), or the pause misalignment of Q-B15, which this tick's interface cannot produce; scooping, an AI escape pod and a manual docking were each reached only once.

### What the picture reads

- ✅ After each tick the presentation reads the mode, the screen, the pilot, the cockpit, the bubble, the navigation and the countdown, and receives the tick's events in order: mode changes, keys' outcomes, laser fire and hits, missile and E.C.M. events, damage, explosions with their bounty, scooping and trades.
- ⚠️ The picture draws every object between its previous and current tick positions, interpolated by how far the frame is between ticks, so 12 Hz logic looks smooth at any frame rate.
- ⚠️ Until the title and docked panels exist, the Godot host starts a game and launches straight away.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The game stalls (a breakpoint, a slow disk) | The ship freezes, then catches up with at most three ticks | Nothing; the stall is cut to a quarter of a second | ✅ |
| A press arrives in a mode that doesn't accept it (buying in flight, launching in flight) | Nothing happens | Nothing; the press is dropped | ✅ |
| Loading a pilot fails (missing or damaged record) | The title carries on with the last saved pilot | The load's error is returned to the host to show | ✅ |

## What it deliberately doesn't do

- The tick never runs at a variable rate, and nothing in the picture writes to the sim except through presses and the load and save calls.
- The camera is not part of the rules: orbiting or zooming never changes what the sim does.
- Sounds are not played by the sim; the events and the RULES sound cues tell the presentation when.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`TickClock`, `InputRecord`, `Press`, `Screen`, `Mode`, `Event`, `FlyInSystem` and its substeps and mode machine), [`tick.rs`](tick.rs) (the flight tick), [`tests.rs`](tests.rs); the Godot side is `SimHost` in [`src/presentation/bridge`](../../presentation/bridge/src/sim_host.rs).
- Diagrams: [`.dev/class-diagram.json`](.dev/class-diagram.json), [`.dev/Mode.state-diagram.json`](.dev/Mode.state-diagram.json), and the game's [component diagram](../../../.dev/component-diagram.json).
- Subsystems: the [desktop build](../../hosting/godot/desktop-build.md).
