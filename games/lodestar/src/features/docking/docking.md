# Docking

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

To trade, refit or save, the pilot docks: flies straight at the station's turning slot, matched to its roll, slowly; or presses the auto-dock and is inside at once. This feature says when the slot is reached and whether the approach passes, and does the docking itself. What a failed approach costs the pilot (a bump or death) is the combat rules'. The mechanics are in [RULES B.12](../../../docs/RULES.md#b12-docking) and [D.3.11](../../../docs/RULES.md#d311-docking).

## What it does

- ✅ `docking_contact` is the station's proximity step ([RULES B.3.4](../../../docs/RULES.md#b34-processing-one-object-per-tick) step 6): outside a box of 128 sim units on every axis around the station's centre, or with the station exploding or killed, nothing; inside it the four checks decide `Docks` or `Fails` ([RULES B.12.1](../../../docs/RULES.md#b121-when-docking-is-checked)).
- ✅ `docking_checks_pass` holds the four checks of [RULES B.12.2](../../../docs/RULES.md#b122-the-checks), on the vectors as stored and the player's forward axis whatever mount is active: the station is not hostile (AI bit 7 clear); its nose's z is at most −86/96; the direction to its centre has z at least 89/96; its roof's x is at least 80/96 either way. At the station's exact centre there is no direction, and the third check fails.
- ✅ `auto_dock` succeeds when the auto-dock is fitted, the station is present and it is not hostile; it docks at once from anywhere in the safe zone ([RULES B.12.3](../../../docs/RULES.md#b123-the-auto-dock)).
- ✅ `dock` cancels the hyperspace countdown ([RULES B.12.4](../../../docs/RULES.md#b124-docking-itself)).
- ✅ `finish_docking` is the docking tunnel's completion: the flight-state reset (54 draws) with the bubble emptied, then the docked state. The market does not change.
- ✅ `enter_docked` is entering the docked state ([RULES D.3.2](../../../docs/RULES.md#d32-entering-the-docked-state)), after docking and after the escape pod: the countdown cleared, then the status screen's selection from the cursor.
- ⚠️ On `Fails`, the combat rules kill the player at speed 5 or more, and otherwise set speed 1 and do 5 damage to the shield facing the station, every tick in the box ([RULES C.11](../../../docs/RULES.md#c11-contact-collisions-scooping-and-the-station)).
- ⚠️ On `Docks` or a successful auto-dock, the lead calls `dock`, starts the 16-tick docking tunnel and lets the rest of the tick run, so anything that happens in it still counts ([RULES B.23 Q-B13](../../../docs/RULES.md#b23-quirks-reproduce-these)); after an auto-dock the tick's later queued actions and the laser are skipped. After the tunnel it calls `finish_docking` and sets Docked mode on the status screen.
- ⚠️ The docking tunnel plays the launch sound (S7) and the bay-doors tunnel ([RULES D.11](../../../docs/RULES.md#d11-sound-cues)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The approach is off-line, the slot not level, or the station hostile | `Fails`: a bump at low speed, death at 5 or more | Line up with the slot, match its roll, come in below speed 5 | ✅ |
| The auto-dock is pressed with no station or a hostile one | Nothing happens | Fly to the station, or calm it by leaving | ✅ |

## What it deliberately doesn't do

- No collision with the station's hull outside the docking box ([RULES B.23 Q-B16](../../../docs/RULES.md#b23-quirks-reproduce-these)).
- The auto-dock does not fly the ship in: the baseline is the cassette version, which docks at once ([RULES B.22](../../../docs/RULES.md#b22-baseline-differences-from-the-1984-original-as-relevant-here)).

## Where it lives

- Code: [`mod.rs`](mod.rs) (`DockingContact`, `docking_contact`, `docking_checks_pass`, `auto_dock`, `dock`, `finish_docking`, `enter_docked`).
- Uses: the bubble, cockpit, pilot, random, ships and universe capabilities; the [hyperspace](../hyperspace/hyperspace.md) feature's `Navigation` and `Countdown`.
