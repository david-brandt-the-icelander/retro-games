# The space scene and the orbit camera

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

The pilot always sees their own ship ([DESIGN § The camera](../../../docs/DESIGN.md#the-camera)). This scene draws it at the origin under an orbit camera and draws every object of the sim's bubble where the sim puts it, smoothly between the 12 Hz ticks. The looks are plain for now: function first, as the working base asks ([DESIGN § Milestones](../../../docs/DESIGN.md#milestones)).

## What it does

### The picture

- ✅ Every object of the bubble is drawn at the bridge's interpolated position and orientation, so 12 Hz logic looks smooth at any frame rate; nothing here writes to the sim.
- ✅ Every ship type is a Cheetah stand-in, about three times its GDD hit radius long, tinted by role as the art bible gives: pirates rust, police grey, the Hush olive; its exhaust is blue for traders and hunters, orange for pirates, white for police and green for the Hush ([ART-BIBLE](../../../docs/ART-BIBLE.md)). The player's hull is a stand-in 49 m long.
- ✅ The station is a drum and ring with its glowing slot on the face its nose points out of, long along its roof, so the slot's roll shows how to line up ([RULES B.12.2](../../../docs/RULES.md#b122-the-checks)); missiles, asteroids, cargo crates and lifeboats are simple shapes.
- ✅ The planet (a ringed one for the second style) and the sun are spheres at their true size (planet radius 24,576 sim units); beyond 2 km they are drawn nearer and smaller by the same factor, so their angular size is exact.
- ✅ The sky and the sun's light turn with the universe in flight, so the stars hold still in space; the sun's light follows the sun while it is in the bubble.
- ✅ Stardust streams past with the ship's speed and swings with its roll and pitch.
- ✅ The player's laser draws a beam from the ship along the active mount to the ship in its line of fire, or into the distance; a ship firing at the player draws a hostile beam toward the ship. Beams last until the next tick, as the laser lines do ([RULES D.4.1](../../../docs/RULES.md#d41-held-controls-sampled-once-per-tick-in-flight-logic)).
- ✅ An exploding object hides and a fireball grows and fades with the sim's cloud counter ([RULES C.12](../../../docs/RULES.md#c12-explosions-and-what-they-leave)); while dying, the player's own ship does the same over the death's 61 ticks; in the escape, the player is the lifeboat and the abandoned hull drifts away.
- ✅ Docked, the ship sits on a pad in a dim hangar, to the left of the hub's panel; on the title it turns slowly with its engines lit.
- ⚠️ The planet's surface, clouds and night lights, the sun's granulation and corona, the glare, the station's model and guide lights, the missile and canister models, debris, the E.C.M. shell and the area blast's whiteout follow [DESIGN § Other objects in space](../../../docs/DESIGN.md#other-objects-in-space) and the art bible.
- ⚠️ Ships animate from what the sim knows ([DESIGN § Animation](../../../docs/DESIGN.md#animation)): turrets traverse toward the player, bays open on a missile launch, brakes extend when slowing, running lights follow energy, shield hits shimmer. Only turret deployment while firing is built.
- ⚠️ Sounds play on RULES D.11's cues with the GDD § 10 sounds.

### The camera

- ✅ The camera orbits the ship between 1.5 and 5 ship lengths, 2.5 by default, with a 60° field of view; the arrows and a right-drag orbit it, `=`/`-` and the wheel zoom it.
- ✅ Space-anchored (the default): it turns with the universe by the sim's own roll and pitch rotation, so the ship swings under a steady camera.
- ✅ Follow (`\`): it eases back behind the active mount 1.5 s after the last camera input.
- ✅ `Home`, and every change of mount, put it behind the active mount.
- ✅ When the station or a ship comes between it and the ship, it pulls in until it is clear.
- ⚠️ Camera mode and default zoom are options and are saved.

## Where it lives

- Code: [`space.gd`](space.gd), [`orbit_camera.gd`](orbit_camera.gd), the shaders [`starfield.gdshader`](starfield.gdshader) and [`exhaust.gdshader`](exhaust.gdshader); the ship rig in [`../ships/`](../ships/).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json); the presentation's [component diagram](../.dev/component-diagram.json).
