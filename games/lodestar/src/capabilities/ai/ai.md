# The ship AI

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

The space around the pilot is alive: raiders turn to attack or break away, hurt ships fire missiles or eject, traders fly on until someone shoots them, a station that has been fired on sends out police, missiles chase their targets and alien drones drift when their carrier is gone. This capability decides, every think, what each of those objects does, and launches the ships they put into space. The exact mechanics are in [RULES C.5](../../../docs/RULES.md#c5-the-ship-ai); the role names and stats are the GDD's ([§ 5.5](../../../docs/GDD.md#55-ship-stats-rules-c32)). The player's side of a fight (lasers, missiles, damage, kills) is the [combat capability](../combat/combat.md), which applies what a think returns.

## What it does

### When an object thinks ([RULES C.4](../../../docs/RULES.md#c4-what-happens-to-each-ship-every-frame) step 3, [C.5.1](../../../docs/RULES.md#c51-when-the-ai-runs))

- ✅ An object thinks only when it is not a planet or the sun, is neither killed nor exploding and has its AI bit set; a missile thinks every tick and any other object when ((C XOR slot) AND 7) = 0, so once every 8 ticks staggered by slot (`due`).
- ✅ Objects with the AI bit clear (asteroids, canisters, unguided missiles, passive traders) never think and keep flying with their speed and counters.
- ✅ The AI byte reads as RULES C.3.3 says: bit 7 active, bits 1..6 aggression, bit 0 E.C.M.; for a missile bit 6 hostile and bits 1..5 the target slot. The player's missile's byte is 0x80 OR (target slot mod 32) × 2.

### Special types ([RULES C.5.2](../../../docs/RULES.md#c52-special-types-checked-first-in-this-order))

- ✅ A missile runs the missile AI and nothing else.
- ✅ An escape pod steers toward the unit vector of the planet's position, or along (0, 0, 1) when there is no planet, with pointing value 0 and no change of speed, and draws nothing.
- ✅ A hostile station draws one byte; at 140 or more, and with fewer than 4 police in the bubble, it launches a police interceptor with AI byte 0xF1. It never fires, regenerates or launches missiles.
- ✅ An alien drone with no mothership in the bubble loses its E.C.M. bit and halves its speed every think, drawing nothing, so it coasts to a halt; with a mothership present it fights like any ship.

### Every other ship ([RULES C.5.3](../../../docs/RULES.md#c53-every-other-ship-including-traders-and-drones-that-have-been-angered))

- ✅ While the station is present, a ship of type below 7 other than the police has its AI byte cut to its AI and E.C.M. bits; this is permanent, applies to the alien mothership, and spares police and traders.
- ✅ A ship below its type's energy regains 1 each think, never past the type's energy.
- ✅ The pointing value is P = 36 × (nose · D), with D the unit vector from the player to the ship and the nose as stored.
- ✅ A byte of 250 or more makes the ship draw another byte a and set its roll counter to a OR 104.
- ✅ At or below an eighth of its type's energy a ship draws an escape byte; at 230 or more it goes passive (AI byte 0) and launches an escape pod with AI byte 0xFE, and stops. The alien mothership draws the byte but never ejects.
- ✅ At or below half its type's energy, a ship with missiles left draws a byte b; when (b AND 31) is below its missiles left and no E.C.M. pulse is running, it uses one and launches a missile with AI byte 0xFE, or, for the mothership, a drone with a copy of the mothership's AI byte, and stops. The count drops even when the bubble is full. The incoming-missile message shows only when a missile actually launched.
- ✅ A ship fires only with every |coordinate| below 8192 (coarse below 32, wrapping). P rounded half up to R: at R ≤ −32 its firing flag is set; at R ≤ −35 the shot hits, its acceleration falls by 1 and it stops, drawing nothing more. The hit does laser × 4 + ⌊missiles / 2⌋ from the type's record, whatever missiles it has left.
- ✅ A ship that is not close (coarse z < 3 and (coarse x OR coarse y) < 2 is close) draws a byte, sets its top bit and turns toward the player when that is below its AI byte, else away; a close ship draws nothing and always turns away. Toward steers along −D with −P, away along D with P, adjusting speed.
- ✅ Every draw is made in the order RULES gives, and only when RULES makes it (RULES C.17 item 2).

### Steering ([RULES C.5.4](../../../docs/RULES.md#c54-the-steering-rule))

- ✅ The pitch counter becomes magnitude 3, negative when roof · T ≥ 0.
- ✅ Only when the roll counter's magnitude is below 16, it becomes magnitude 5, negative exactly when "the pitch is negative" differs from "side · T < 0": the baseline's sign, kept by decision 9.
- ✅ When adjusting speed, P ≥ 22 sets acceleration +3, |P| < 18 leaves it, and anything else sets −2 for a missile or −1 for any other ship, using the unrounded P.

### Missiles ([RULES C.5.5](../../../docs/RULES.md#c55-missile-ai-every-frame-for-each-active-missile))

- ✅ While an E.C.M. pulse runs, every thinking missile, either side's, is destroyed.
- ✅ A hostile missile with any coarse coordinate non-zero steers straight at the player with P = 36 (so it accelerates every tick); otherwise it is marked killed and hits the player for 250, on the aft shield when its z < 0. No kill is counted. Because coarse wraps, a missile 65536 or more away can hit for the tick before it is removed (RULES C.17 item 14).
- ✅ The player's missile whose target slot is empty goes unguided (AI byte 0) and draws nothing.
- ✅ Far from its target (any |Δ| of 256 or more) it draws a byte every tick; below 16, with the target fitted with E.C.M., the target starts an E.C.M. pulse and the missile does not steer that tick; otherwise it steers toward the target with P = 36.
- ✅ Close to its target it marks the target killed (unless it is already exploding) and is destroyed; a station in slot 1 is not harmed.
- ✅ A destroyed missile is marked killed and counts as a player kill; within 1 unit of the player on every axis it also hits the player for 80. The hit comes before the kill.

### Becoming angry ([RULES C.5.6](../../../docs/RULES.md#c56-becoming-angry))

- ✅ The station turns hostile and nothing else happens; types 9..13 and bodies ignore it; a trader also turns the station hostile when it is in the bubble; then a ship with AI byte exactly 0 stays passive and any other gets its AI bit, acceleration +2 and pitch counter +4.

### Launching a child ship ([RULES C.5.7](../../../docs/RULES.md#c57-launching-a-child-ship))

- ✅ A child copies its parent's position, orientation, speed and counters, takes its own type's full energy and missiles, and loses roll bit 0; a child of the station starts 192 units along the station's nose at speed 32.
- ✅ A canister child draws a pair (A, X): pitch counter (A × 2) AND 255, speed X AND 15, roll counter 127 with the sign of A's top bit.
- ✅ A full bubble refuses the child silently and any draw made for it stays drawn.

### Missiles after a removal ([RULES C.7.4](../../../docs/RULES.md#c74-when-ships-leave-the-bubble))

- ✅ When the object in slot n leaves the bubble, every active non-hostile missile aimed at slot n goes unguided and one aimed at a later slot is aimed one lower, keeping its other bits; hostile and unguided missiles are untouched (`retarget_missiles`).

### For the picture and the sound

- ⚠️ A ship whose firing flag is set draws its beam from its gun point (the rig's muzzle marker), with any random jitter from the cosmetic generator, and the flag is cleared once drawn ([RULES C.2.4](../../../docs/RULES.md#c24-where-the-baseline-draws-the-main-generator-for-cosmetic-purposes), deliberate difference 3).
- ⚠️ The sounds of [RULES D.11](../../../docs/RULES.md#d11-sound-cues) play from the think's events: the hit tone when an enemy laser hits unless an E.C.M. pulse runs, the launch whoosh with the incoming-missile message, explosion A when a hostile missile reaches the player, and the E.C.M. warble when a missile's target starts its E.C.M.

## What it deliberately doesn't do

- It never changes the pilot: damage and kills come back in a `Thought`, which the combat capability applies (hit first, then the kill). A think draws nothing after the point where it would hurt the player, so this keeps the draw order.
- It does not move objects, tidy them or apply their acceleration; the flight capability does.
- It does not spawn arrivals ([RULES C.16](../../../docs/RULES.md#c16-spawning)).

## Where it lives

- Code: [`mod.rs`](mod.rs) (`think`, `due`, the AI byte helpers, `Thought`, `Hit`), [`steering.rs`](steering.rs) (`pointing`, `steer`), [`ship.rs`](ship.rs) (`think_ship` and the pod, station and drone thinks), [`missile.rs`](missile.rs) (`think_missile`, `retarget_missiles`), [`anger.rs`](anger.rs) (`anger`), [`launch.rs`](launch.rs) (`launch_child`).
- Built on: the [bubble](../bubble/mod.rs), [ships](../ships/mod.rs), [space](../space/mod.rs), the [cockpit](../cockpit/mod.rs) and the main generator in [random](../random/mod.rs).
- Used by: the [combat capability](../combat/combat.md).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
