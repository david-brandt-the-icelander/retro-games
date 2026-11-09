# The flight HUD

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

Everything the pilot needs in flight, kept to the corners and edges so the ship and its target stay clear ([UI-DESIGN § Flight HUD](../../../docs/UI-DESIGN.md#flight-hud), [RULES D.7](../../../docs/RULES.md#d7-dashboard-hud-indicators), [D.8](../../../docs/RULES.md#d8-scanner-and-compass)). It shows in flight, while dying, in the escape and, with its location and ship status only, in the tunnels.

## What it does

- ✅ Top left: the current system (blank as "—" in the Deep), the target system and its distance in light years, a `SAFE ZONE` badge inside the station's zone, and the countdown figure with where it leads (RULES D.9.2 N5).
- ✅ Top centre: the timed message in capitals, fading as its timer runs out; the energy-low and incoming-missile messages tint Danger ([RULES D.9.1](../../../docs/RULES.md#d91-timed-in-flight-messages)).
- ✅ Bottom centre: the persistent notices (the jump's destination, out of range, not while berthed, the hop's refusal) for a few seconds, cleared by a tunnel or a mount change; and the key hints on the first three launches of a session.
- ✅ Top right: the camera's mode and zoom, fading three seconds after the last camera input.
- ✅ Left edge: the speed tape, 24 ticks and the figure, amber from speed 28 (RULES D.7's danger length).
- ✅ Right edge: the roll and pitch indicators, a notch on a 90° arc.
- ✅ Bottom left: the scanner, a tilted ring with the contacts inside the range RULES D.8 gives (16,384 sim units on each axis), as diamonds dimmer behind, with a chevron for above or below; missiles in their own colours (hostile Danger, the player's Good), the station Gold; the ring tinted by condition; and the heading pip to the station in the safe zone, else the planet, solid ahead and hollow behind; none in the Deep.
- ✅ Beside it: the missile pips, the first showing armed (Amber) or locked (Danger), and the `SCR`, `NOVA` and `BOAT` badges, lit when fitted and amber while working; the lifeboat's badge is the always-visible sign RULES D.7 asks for.
- ✅ Bottom right: the fore and aft shields as the halves of a ring, the four energy banks filling from the first (RULES D.7), hull heat, laser heat, altitude, fuel and the condition's label; shields, banks, heat and fuel flash Danger at RULES D.7's thresholds, 8 ticks on and 8 off ([RULES D.7.2](../../../docs/RULES.md#d72-flashing-rule)).
- ✅ A thin frame round the screen in the condition's colour.
- ✅ The reticle sits where the active mount's axis is 800 m out, or on the ship in its line of fire by the sim's own sights test, with the mount's tag; a ship in the line of fire gets corner brackets, a filled centre and `IN LINE OF FIRE`; while the missile searches an amber arc turns round the reticle, and a locked ship gets a Danger ring ([DESIGN § The camera](../../../docs/DESIGN.md#the-camera), Aiming).
- ✅ While dying: the death notice, an epitaph from the cause, and the pilot's rank and kills (GDD § 9.4 `ui.epitaph`).
- ⚠️ The scanner is a small 3D sphere that turns with the camera, in a `SubViewport` ([DESIGN § HUD](../../../docs/DESIGN.md#hud)).
- ⚠️ Assists: contacts in faction colours, brackets with type and range on every ship in view, edge arrows toward hostiles off screen.
- ⚠️ The flashing can be turned steady (the pause handler's flashing toggle and the warning-pulse option).
- ⚠️ The HUD stays in a 16:9 safe area on ultrawide screens and scales with the UI scale option.

## Where it lives

- Code: [`hud.gd`](hud.gd); its words in [`../text/words.gd`](../text/words.gd) and its look in [`../ui/look.gd`](../ui/look.gd).
- The presentation's [component diagram](../.dev/component-diagram.json).
