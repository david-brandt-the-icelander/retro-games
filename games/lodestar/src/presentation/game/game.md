# The game scene and its keys

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), and the engineer who tests the client

## What this is for

`game.tscn` is the main scene. It holds the [bridge's](../bridge/bridge.md) `SimHost` and puts the [space scene](../space/space.md), the [HUD](../hud/hud.md), the tunnels and the [panels](../ui/ui.md) around it, and it turns every key into a press for the sim, depending on the mode, the screen and the pause ([RULES D.4](../../../docs/RULES.md#d4-player-actions), [DESIGN § Keyboard controls](../../../docs/DESIGN.md#keyboard-controls)). Its script runner plays scripted games for screenshots and for the headless smoke test.

## What it does

### Keys (the Modern layout)

- ✅ The input map in `project.godot` holds DESIGN's Modern layout under RULES D.5's action names: `dive` W, `climb` S, `roll_left` A, `roll_right` D, `speed_up` R, `slow_down` F, `fire` Space; `mount_front` … `mount_right` 1–4; `arm_missile` Q, `fire_missile` E, `unarm_missile` Z; `ecm` C; `area_blast` B; `escape_pod` Backspace; `in_system_jump` J; `auto_dock` K; `hyperspace` H and `galaxy_jump` Shift+H; `screen_galaxy` G, `screen_local` L, `screen_system` I, `screen_market` O, `screen_status` V, `screen_inventory` Y; `launch` L; `pause` Esc and P; and the camera's `camera_left` … `camera_down` (arrows), `camera_zoom_in` (= and keypad +), `camera_zoom_out` (- and keypad −), `camera_reset` Home and `camera_mode` \\.
- ✅ The held actions reach the sim through the bridge at every tick; every one-shot key is a press for the next tick, and key repeat is ignored ([RULES D.4.4](../../../docs/RULES.md#d44-key-dispatch-rules)).
- ✅ On the title, keys go to the title's menu.
- ✅ Docked, keys go to the page on show first, then the hub's tabs, then: `pause`, `launch`, the screen keys (which open their tab), and the jump keys, which show the "not while berthed" notice (RULES D.9.2 N3).
- ✅ In flight: `pause` closes an open panel, or pauses on the space view; a screen key opens its panel, or closes it when it is already open; on a chart the arrows, `Enter` and `Home` work the chart; then the mounts, the Reach jump, the jump (which first hands the chart cursor to the sim), and the queued flight actions.
- ✅ The escape pod launches once its key has been held for a second in flight.
- ✅ While paused, keys go to the pause panel only; in the tunnels, death and the escape, the sim takes no keys ([RULES D.2](../../../docs/RULES.md#d2-modes-and-the-state-machine)).
- ✅ The window losing its focus pauses a docked or flying game.
- ✅ The jump's outcome shows as a notice: the destination when the countdown starts (N1), out of range (N2), and the hop's refusal.
- ⚠️ The Classic layout, every action remappable under Options → Controls with conflicts shown, and the bindings saved with the settings ([DESIGN § Keyboard controls](../../../docs/DESIGN.md#keyboard-controls)).
- ⚠️ The escape pod's hold can be set to a toggle (UI-DESIGN § Accessibility).
- ⚠️ The function keys F5–F10 open the screens in the Classic layout.

### Scripted games and the smoke test

- ✅ `godot --path . -- --script=<steps>` plays a scripted game with the sim's clock stopped, so it always plays the same game: steps wait frames, run ticks, press keys through the real input path, hold actions, send commands, save and load, steer at a ship or the planet, check the mode, screen or cash, and save screenshots to `--shots=<folder>`. A failed check prints why and exits with code 1. The steps are listed at the top of [`script_runner.gd`](script_runner.gd).
- ✅ `--script=@smoke`, run headless, plays the title, docking, trading, buying equipment, saving, the launch, flying, firing, the mounts, the missile and E.C.M. keys, a chart, pause and resume, a crash into the planet, death, the return to the title and loading the saved pilot, and checks each.
- ✅ `--script=@shots` takes the screenshots of every screen: title, docked status, market before and after a trade, equipment, the Reach and local charts, system data, the launch tunnel, the flight HUD, a fight, a chart in flight, the countdown, the jump tunnel, the arrival, pause, death and the loaded pilot's hold.
- ✅ `--shot=<png> --frames=<n>` saves one screenshot after n frames and quits.
- ⚠️ The mis-jump into the Deep, docking by flying into the slot, the auto-berth, the nova charge and the lifeboat are exercised by the sim's tests but by no script yet: the start pilot cannot afford their equipment and the mis-jump is a 3-in-256 draw.

## Where it lives

- Code: [`game.tscn`](game.tscn), [`game.gd`](game.gd), [`script_runner.gd`](script_runner.gd); the input map in [`project.godot`](../../../project.godot).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json); the presentation's [component diagram](../.dev/component-diagram.json).
