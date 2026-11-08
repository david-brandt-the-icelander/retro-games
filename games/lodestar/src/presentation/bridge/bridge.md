# The presentation bridge

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the engineer who builds the Godot scenes, and through them the [pilot](../../../../../Actors/pilot.md)

## What this is for

The scenes never touch the rules. `SimHost` is their one door into the sim ([DESIGN § Architecture](../../../docs/DESIGN.md#architecture)): it runs the [fly-in-a-system](../../use_cases/fly_in_system/fly_in_system.md) game at 12 Hz under Godot's frame loop, turns the scenes' presses and Godot's held input actions into the tick's input record, and hands back snapshots and events as Godot types. `views.rs` works every readout out in plain Rust, so it is tested without Godot; `sim_host.rs` only converts.

## What it does

### The clock and the input

- ✅ Each frame the host adds the frame's time to the sim's tick clock and runs as many ticks as it allows; `alpha()` says how far the frame is between the last tick and the next ([RULES D.1](../../../docs/RULES.md#d1-time-base-12-hz-logic-with-two-motion-substeps)).
- ✅ At every tick it samples the held flight actions from Godot's input map: `dive`, `climb`, `roll_left`, `roll_right`, `speed_up`, `slow_down` and `fire` ([RULES D.4.1](../../../docs/RULES.md#d41-held-controls-sampled-once-per-tick-in-flight-logic)).
- ✅ Every one-shot press the scenes send between two ticks is queued and reaches the next tick in the order sent, so a tap is never lost: `press(name)` for the actions without an argument, `press_mount`, `show_screen`, `move_cursor`, `buy`, `sell` and `equip`. An unknown name or an out-of-range argument is dropped.
- ✅ Power-on shows the title; nothing starts until the pilot chooses to ([RULES D.3.1](../../../docs/RULES.md#d31-title-sequence)).
- ✅ `set_running(false)` stops the clock and `advance(n)` runs n ticks at once, so a script plays the same game every time.

### Saving

- ✅ `save_pilot(name)` saves while docked and answers `saved`, `not_docked` or `no_name`; `load_pilot(name)` loads on the title and answers an empty string, `not_title`, `not_found` or `rejected`; `pilot_names()` lists the saved pilots. The records are files under `user://pilots/`, through the [infrastructure crate](../../infrastructure/infrastructure.md) ([RULES A.8](../../../docs/RULES.md#a8-saving-and-loading)).
- ⚠️ A save whose file cannot be written answers `not_written`, so the pilot page can say so; the saving feature's store trait has no way to report it yet.

### What the scenes read

- ✅ The mode (`title`, `docked`, `tunnel_launch`, `tunnel_dock`, `tunnel_jump`, `tunnel_misjump`, `tunnel_galactic`, `flight`, `dying`, `escape`), the tunnel's step or the ticks a death or an escape has left, the cause of death, the screen and the pause flag.
- ✅ The cockpit: shields, energy, the temperatures, altitude, speed, the roll and pitch angles and rates, the two pause options, the active mount, the missile's arming and lock, the E.C.M. and area-blast timers, the safe-zone and Deep flags, the timed message as an id and its one data field, the condition code and the countdown with where it leads.
- ✅ The condition code follows [RULES D.6.2](../../../docs/RULES.md#d62-status-screen): 0 docked, 1 when the bubble's entries − 2 − asteroids ≤ 0, else 2 or 3 by energy.
- ✅ The pilot: name, cash and fuel in tenths, legal standing and its label index, rank, kills, missiles, the hold and what is in it, the laser on each mount, the fitted equipment, and the equipment lines of the status screen in RULES D.6.2's order.
- ✅ Navigation: the current system's name (blank in the Deep), the current and the selected system with their data, and the chart cursor; the system nearest any chart point without selecting it; the 256 systems of the galaxy; and the local chart with RULES A.6.2's layout, worked out by the sim ([RULES A.6](../../../docs/RULES.md#a6-the-charts-behaviour)).
- ✅ The market panel's 17 rows (price, availability, cargo, the stepper's limits and whether this economy pays above the middle) and the equipment panel's rows at the current tech level, matching the GDD's start market and prices ([GDD § 5.2](../../../docs/GDD.md#52-starting-market-rules-a97)).
- ✅ The bubble's objects in slot order: kind, position in metres in Godot's axes (x right, y up, the sim's forward z as −Z, 0.2 m a unit), a basis built from nose and roof, and the flags the picture uses: exploding and its cloud counter, killed, firing, in the active mount's line of fire by the sim's own sights test, missile-locked, and a hostile missile.
- ✅ Positions and orientations are interpolated `alpha` of the way from the previous tick to the last; an object whose slot changed kind, and every object on a tick that changed the mode, is drawn where it is without interpolation.
- ⚠️ An object that moved down a slot because an earlier one left the bubble is interpolated from its own previous position, not from the departed object's.

### Signals

- ✅ `ticked(tick)` after every tick; `mount_selected(mount)` when the active mount changes; and `sim_event(kind, data)` for every event of the tick in order: `mode`, `paused`, `hyperspace` (with its result and the system), `galaxy_drive`, `laser_fired`, `laser_hit`, `missile_armed`, `missile_unarmed`, `missile_locked`, `missile_fired`, `ecm_started`, `ecm_stopped`, `area_blast`, `in_system_jump`, `damaged`, `exploded`, `scooped`, `bought`, `sold` and `equipped` with their results and refusals.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The library was not rebuilt after a change | Godot reports a missing method or the old behaviour | `cargo build -p lodestar-godot` | ✅ |
| `user://pilots/` cannot be written | Saving reports `saved` but no file appears; the save in play is kept | Free the disk or fix the folder's permissions, then save again | ✅ |

## Where it lives

- Code: [`src/sim_host.rs`](src/sim_host.rs) (`SimHost`), [`src/views.rs`](src/views.rs) (the readouts, with their tests).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json); the presentation's [component diagram](../.dev/component-diagram.json).
