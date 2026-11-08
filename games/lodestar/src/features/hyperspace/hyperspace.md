# Hyperspace

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

The pilot picks a system on a chart, presses the jump key, survives the 85-tick countdown and rides the tunnel to a new system, a new market and new dangers; three times in 256 the jump drops into the Deep among the aliens instead. A galaxy drive, used once, carries the pilot to the next Reach. The [universe capability](../../capabilities/universe/universe.md) does the pure computations (distance, range, selection, the Reach jump, the mis-jump test); this feature holds the state between them, the cursor, the selection, the current system and the countdown, and makes the draws in RULES' order. The mechanics are in [RULES A.5](../../../docs/RULES.md#a5-hyperspace-target-countdown-and-jump), [B.16](../../../docs/RULES.md#b16-hyperspace) and [C.16.6](../../../docs/RULES.md#c166-the-alien-group-and-mis-jump-space).

## What it does

### Selecting

- ✅ `Navigation` keeps the chart cursor, the selected system with the distance measured when it was selected, and the current system's number. A mis-jump moves the pilot and leaves the current system as it was, which is why the current system is kept apart from the pilot's position ([RULES A.5.5](../../../docs/RULES.md#a55-the-normal-jump)).
- ✅ At game start or after loading, `Navigation::start` puts the cursor on the pilot's position, selects from there and makes that system current ([RULES A.5.1](../../../docs/RULES.md#a51-selected-system)).
- ✅ `Navigation::select` is the one selection: the system nearest the cursor, measured from the pilot, with the cursor snapped onto it. The hyperspace key, launch and entering the docked state call it here; the lead calls it for the show-distance key, the system-data screen and every showing of the status screen.
- ✅ During a normal countdown a new selection becomes the destination only when it is in fuel range; otherwise the countdown keeps its destination and distance, while the chart still shows the new selection ([deliberate difference 6](../../../docs/RULES.md#deliberate-differences-from-the-baseline), [RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 3, [B.23 Q-B4](../../../docs/RULES.md#b23-quirks-reproduce-these)).
- ✅ Retargeting to the current system (distance 0) counts as out of range, because `universe::in_range` needs `0 < distance ≤ fuel` ([RULES A.4.3](../../../docs/RULES.md#a43-fuel)). The baseline's zero-cost jump home with a new market cannot happen.

### The keys

- ✅ The hyperspace key checks, in order, docked, a countdown already running, then selects, then distance 0 (ignored silently), then distance beyond the fuel; otherwise the countdown starts ([RULES A.5.2](../../../docs/RULES.md#a52-the-hyperspace-key-normal-jump), [D.14](../../../docs/RULES.md#d14-quirks-and-edge-cases-baseline-behaviour-that-parity-depends-on) item 8). `HyperspaceKey` says which, with the selection where one was made.
- ✅ A distance equal to the fuel is in range; one more is not.
- ✅ The galaxy-drive key checks docked, a countdown running and the drive fitted; then at once removes the drive, clears legal status and starts a galactic countdown ([RULES A.5.3](../../../docs/RULES.md#a53-the-galaxy-drive-key), A.14 item 5). A second drive bought meanwhile is kept when the key is ignored.

### The countdown

- ✅ `Countdown` starts both its values at 15; each flight tick the inner value falls, and every time it reaches 0 it goes back to 5 and the shown value falls, so the jump comes on the 85th tick counting the key's own ([RULES A.5.4](../../../docs/RULES.md#a54-the-countdown), [B.16.2](../../../docs/RULES.md#b162-the-countdown)). `Countdown::tick` returns the destination on that tick.
- ✅ `Countdown::cancel` clears both values. Docking, entering the docked state, death ([deliberate difference 5](../../../docs/RULES.md#deliberate-differences-from-the-baseline)) and the return to the title cancel it; the flight-state reset does not.
- ⚠️ The lead keeps the countdown beside the cockpit, ticks it at step 11 of the flight logic ([RULES D.3.6](../../../docs/RULES.md#d36-flight-mode-the-per-tick-flight-logic)) in Flight mode only (not docked, not in a tunnel, not in the escape drift, and never in Death mode, where it is already cancelled), and on the jump tick calls `jump`.

### The jump and the arrival

- ✅ A normal jump takes the destination's distance off the fuel, never below 0, then draws one byte; 253 or more is a mis-jump ([RULES A.5.5](../../../docs/RULES.md#a55-the-normal-jump), [B.16.3](../../../docs/RULES.md#b163-the-jump)).
- ✅ A galactic jump moves the pilot to the system nearest (96, 96) in the next Reach, makes it current and selected with distance 0 and the cursor on it, uses no fuel, draws nothing and sets the galactic-jump message ([RULES A.5.7](../../../docs/RULES.md#a57-the-galactic-jump)).
- ✅ After the tunnel, a normal arrival moves the pilot to the destination, makes it current, sets the selected distance and the spawn delay to 0, then does the common arrival.
- ✅ The common arrival draws the market byte and rebuilds availability (`market::draw_and_arrive`), resets the flight state (54 draws) with the bubble emptied, halves legal status and places the planet and sun with the bit shifted out ([RULES A.5.6](../../../docs/RULES.md#a56-the-common-arrival), [B.16.4](../../../docs/RULES.md#b164-arrival)).
- ✅ A galactic arrival keeps the spawn delay ([RULES B.23 Q-B12](../../../docs/RULES.md#b23-quirks-reproduce-these)), and its galactic-jump message is cleared by the reset (Q-B10).
- ✅ A mis-jump arrival resets the flight state (54 draws), enters the Deep, flips the low 5 bits of the pilot's y, keeps the current system, its market, the stale selection and the spawn delay, adds alien groups until four motherships are present (stopping if an add fails), and takes the 9 stardust draws and discards them: 4 motherships and 4 drones at the four template corners ([RULES B.16.5](../../../docs/RULES.md#b165-mis-jump-arrival-the-ambush), C.16.6, [deliberate difference 3](../../../docs/RULES.md#deliberate-differences-from-the-baseline)).
- ✅ Every arrival makes the front mount active, as the baseline forces the front view ([RULES D.3.7](../../../docs/RULES.md#d37-hyperspace-the-action-the-countdown-and-the-jump)).
- ⚠️ The lead runs the 16-tick hyperspace tunnel between `jump` and `arrive`, with no game logic and every press discarded ([RULES D.3.4](../../../docs/RULES.md#d34-tunnels-launch-docking-hyperspace), A.14 item 18), then sets Flight mode.

### For the presentation

- ⚠️ The countdown's shown value (15 to 1) is drawn top-left on every screen while it runs, except in tunnels (N5).
- ⚠️ The hyperspace key's results show the docked notice (N3), the out-of-range line (N2) or the destination line with the system's name (N1) on the bottom line, which stays until a view change, a tunnel or a reset clears it; after a selection a chart on screen is redrawn.
- ⚠️ The galactic-jump message (M7) shows during the tunnel, which the baseline never manages ([deliberate difference 10](../../../docs/RULES.md#deliberate-differences-from-the-baseline)); the sim leaves it to the arrival's reset to clear, so it never holds back a bounty after arrival.
- ⚠️ A chart open when the tunnel starts is open again on arrival (deliberate difference 10).
- ⚠️ The hyperspace sound (S8) starts each hyperspace tunnel ([RULES D.11](../../../docs/RULES.md#d11-sound-cues)); the tunnel into the Deep is the GDD's green-tinted one.
- ⚠️ Stardust is picture only ([RULES B.19](../../../docs/RULES.md#b19-stardust)): 18 particles (3 in the Deep), moved each substep in the notional view of the active mount and respawned from the cosmetic generator. The main generator takes only the flight-state reset's 54 draws (`Cockpit::reset`) and the ambush's 9, and discards them ([deliberate difference 3](../../../docs/RULES.md#deliberate-differences-from-the-baseline)).
- ⚠️ In the Deep the current system's name prints blank ([RULES D.3.8](../../../docs/RULES.md#d38-the-ambush-state-mis-jump)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The pilot retargets a running countdown to a system beyond the fuel | The chart shows the new system; the jump still goes to the old one | Pick a system within range, or let the jump finish | ✅ |
| The jump mis-jumps (3 in 256) | Four alien motherships and their drones around the pilot, no planet, no station | Fight, or jump again from the Deep (an ordinary jump, which can mis-jump back) | ✅ |
| The pilot dies during a countdown | The countdown stops; no jump rescues the dead pilot | Nothing; deliberate difference 5 | ✅ |

## What it deliberately doesn't do

- It never lets fuel go below 0 or lets a retarget skip the range check (deliberate difference 6).
- It does not build the tunnel or the mode machine; it returns `Tunnel` and `Arrived` for the lead to act on.
- It draws nothing for stardust beyond the 9 discarded ambush draws; the flight-state reset's 54 are the cockpit's ([RULES B.19](../../../docs/RULES.md#b19-stardust)).

## Where it lives

- Code: [`mod.rs`](mod.rs) re-exports [`navigation.rs`](navigation.rs) (`Navigation`, `galaxy`), [`countdown.rs`](countdown.rs) (`Countdown`, `Destination`) and [`jump.rs`](jump.rs) (`press_hyperspace`, `press_galaxy_drive`, `jump`, `arrive`, `HyperspaceKey`, `GalaxyDriveKey`, `Tunnel`, `Arrived`).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Uses: the [universe](../../capabilities/universe/universe.md) and [market](../../capabilities/market/market.md) capabilities, the [planet and sun](../planet_and_sun/planet_and_sun.md) and [spawning](../spawning/spawning.md) features.
