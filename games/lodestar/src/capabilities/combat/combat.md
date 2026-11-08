# Combat

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

A pilot fights to survive and for bounties: lasers from the chosen mount, missiles that lock and chase, an E.C.M. that clears incoming missiles, an area blast for emergencies, shields that soak hits until the energy bank takes them, cargo and equipment lost to damage, wreckage that explodes and pays, and a record the police care about. This capability holds those rules and the combat steps of each object's processing in the tick. The exact mechanics are in [RULES C.4](../../../docs/RULES.md#c4-what-happens-to-each-ship-every-frame) and [C.6 to C.15](../../../docs/RULES.md#c6-the-players-lasers); the ship AI it runs is the [AI capability](../ai/ai.md).

## What it does

### The slot loop's combat steps ([RULES C.4](../../../docs/RULES.md#c4-what-happens-to-each-ship-every-frame), [B.3.4](../../../docs/RULES.md#b34-processing-one-object-per-tick))

One function per step, for the flight tick to call on each slot in order:

| Step | Function | What the caller does with the result |
| --- | --- | --- |
| 1 area blast | `area_blast_step` | nothing |
| 2 explosion start | `explosion_start_step` | nothing |
| 3 tidy, then AI | flight's `tidy_if_due`, then `ai_step` | on `player_died()`, run the death and stop processing this object |
| 4 motion bookkeeping | flight's `own_motion_tick` | — |
| 5 explosion progress | `explosion_progress_step` | nothing |
| 6 contact | `contact` | `DockingBox`: run the docking test, and `failed_docking` if it fails; `Collided(Died)`: run the death |
| 7 sights | `sights_step(…, flight_view)` | nothing |
| 8 removal | `removal_step` | `Some`: process the same slot again; `None`: run the removal for distance, which calls `fix_up_after_removal` (or, for the station's replacement by the sun, `fix_up_lock`) |

- ✅ Step 1: while the area blast is active, a ship that is not the station and neither killed nor exploding is marked killed and a kill counted; planets and the sun are skipped.
- ✅ Step 2: a killed ship that is not yet exploding starts its explosion; bodies never do.
- ✅ Step 3: an object thinks when the AI's `due` says so, using the cockpit's counter as C; the think's hit on the player is applied, then a destroyed missile's kill is counted, and the step reports whether the player died.
- ✅ Step 5: an exploding object's cloud advances, and when it is spent the object is marked killed.
- ✅ Step 7: only while the flight view shows, a ship in the active mount's sights is first locked by an armed missile, then hit by this tick's shot; one shot hits every ship in line in the same tick ([RULES C.17](../../../docs/RULES.md#c17-quirks-and-edge-cases) item 5).
- ✅ Step 8: an object both killed and exploding is removed: a police interceptor sets legal status bit 6, its bounty is paid by the message rule, it leaves the bubble, the player's missiles in flight are retargeted and the lock follows, showing the target-lost message when the lock was on it.
- ⚠️ The flight tick calls these steps in this order for every slot, processes the same slot again after a removal, and, when the player dies mid-loop, carries on from the next slot over the new bubble of wreck canisters ([RULES C.10.4](../../../docs/RULES.md#c104-the-players-death), C.17 item 16).
- ⚠️ The flight tick's key handling calls `start_key_handling` first, then the queued actions (`unarm_missile`, `arm_missile`, `fire_missile`, `trigger_area_blast`, the escape pod, the in-system jump, `fire_ecm`, the auto-dock) in press order, then `fire_lasers` with the held fire control and whether the flight view shows; after the slot loop `count_down_area_blast` then the recharge; in step 7 of the tick `laser_and_ecm_bookkeeping`; and in the chores the cockpit's `cool_laser` ([RULES D.3.6](../../../docs/RULES.md#d36-flight-mode-the-per-tick-flight-logic)).

### Lasers ([RULES C.6](../../../docs/RULES.md#c6-the-players-lasers))

- ✅ The shot's damage is 0 at the start of key handling. The laser fires when the cooldown is 0, fire is held, the heat is below 242, the active mount has a laser and the flight view shows (deliberate differences 1 and 9).
- ✅ A shot sets the shot damage to the laser's power (15 for both types, the beam's top bit dropped), draws two bytes for the beam's convergence point (x then y, each (byte AND 7) − 4), adds 8 heat, drains 1 energy (never below 1) and sets the cooldown to 10 for a pulse laser and 0 for a beam laser.
- ✅ The cooldown falls by 5 at the end of every flight tick, so a held pulse laser fires every second tick and a beam laser every tick.
- ✅ An object is in a mount's sights when it is not a planet, the sun or exploding, and in the mount's frame (front (x, y, z), rear (−x, y, −z), left (z, y, −x), right (−z, y, x)) z′ > 0, |x′| and |y′| are below 256 and ⌊|x′|⌋² + ⌊|y′|⌋² is at most its hit size; there is no range limit, and a merely killed ship still counts.
- ✅ The player's own missile starts in the front sights, since the missile's hit size is at least 784 ([RULES C.17](../../../docs/RULES.md#c17-quirks-and-edge-cases) item 6).
- ✅ A hit takes the shot's damage off the ship's energy; at 0 the station turns hostile without being destroyed, and any other ship is marked killed; a ship of types 1..7 then draws a pair and, when A's top bit is set, launches (A AND its canisters) canisters, each drawing its own pair, and counts a kill; types 9..13 give neither. Every hit angers the ship.
- ✅ A ship already marked killed but not yet exploding can be hit again, and reaching 0 again counts another kill (C.17 item 20).
- ✅ Canister launches that find the bubble full fail silently, and their pairs are still drawn.

### Missiles ([RULES C.7](../../../docs/RULES.md#c7-the-players-missiles))

- ✅ Target arms the missile when no lock is held and a missile is carried; unarm, with a missile carried, clears the lock and the arming.
- ✅ While armed, the first object in slot order in the active mount's sights during the slot loop is locked and arming ends (deliberate difference 8); planets and the sun never lock.
- ✅ Fire does nothing without a lock; otherwise a missile is added at (0, −28, 14), nose (0, 0, 1), side (−1, 0, 0), roof (0, 1, 0), speed (2 × the player's speed) AND 255, AI byte 0x80 OR (target × 2), then the target is angered, the lock cleared and one missile used.
- ✅ With the bubble full, fire shows the jammed message and changes nothing else; the lock and the missile count stay.
- ✅ A removal retargets the player's missiles in flight and moves or drops the lock, showing the target-lost message when the lock was on the removed object; the station's replacement by the sun moves only the lock ([RULES B.9.4](../../../docs/RULES.md#b94-removal-for-distance), Q-B5).

### E.C.M. and the area blast ([RULES C.8](../../../docs/RULES.md#c8-ecm), [C.9](../../../docs/RULES.md#c9-the-area-blast))

- ✅ The E.C.M. action starts the player's own 32-tick pulse when the unit is fitted and no pulse, the player's or a ship's, is running.
- ✅ At the end of every flight tick the player's own E.C.M. drains 1 energy and stops at once when the energy was already 1; then a running pulse counts down and stops at 0. A pulse started in key handling is active for 32 ticks of AI and costs the player 32 energy; a ship's pulse costs nothing.
- ✅ The area blast, if fitted, is used up and stays active for the tick it is triggered and the next three; its counter falls after the slot loop.

### Damage ([RULES C.10.2](../../../docs/RULES.md#c102-applying-damage), [C.10.3](../../../docs/RULES.md#c103-equipment-and-cargo-loss))

- ✅ The aft shield takes a hit from an attacker with z < 0, the fore shield anything else; what the shield cannot hold empties it and comes off the energy bank; at 0 energy the player dies and the result says so.
- ✅ Damage that reaches the energy bank without killing draws a pair (A, X), even while a message shows; nothing is lost when A's top bit is set, X ≥ 22 or a message is showing; otherwise X 0..16 empties that goods stack if any is held and X 17..21 removes the E.C.M., fuel scoop, area blast, energy booster or auto-dock if fitted, each with its loss message.
- ⚠️ When `take_damage`, `contact`, `failed_docking` or `ai_step` report a death, the caller runs the death of [RULES C.10.4](../../../docs/RULES.md#c104-the-players-death); the escape pod is [RULES C.10.5](../../../docs/RULES.md#c105-the-players-escape-pod).

### Contact ([RULES C.11](../../../docs/RULES.md#c11-contact-collisions-scooping-and-the-station))

- ✅ Only a ship that is not killed, not exploding and not a body, with every |coordinate| below 128, can touch; the station then reports the docking box and is not otherwise touched.
- ✅ Within 64 on every axis, any other ship that is not a missile is marked killed: scooped when it is a canister, drone or pod, the fuel scoop is fitted and it is below the player (y < 0) — a canister draws one byte for item (byte AND 7), a drone gives item 16, a pod item 3, its name shows when there was room — otherwise rammed, the player taking 128 + ⌊its energy / 2⌋. Neither counts a kill; both objects then explode and pay their bounty like any killed ship.
- ✅ A failed docking test kills the player at speed 5 or more; below it the speed becomes 1 and the player takes 5 from the station's side.

### Explosions ([RULES C.12](../../../docs/RULES.md#c12-explosions-and-what-they-leave))

- ✅ An explosion starts by clearing the killed and firing flags, setting exploding, zeroing the acceleration and pitch counter, setting the cloud counter to 18 and drawing four bytes as the cloud's seeds; the ship keeps its speed and roll.
- ✅ The cloud counter grows by 4 a tick; past 255 the ship is marked killed, so an explosion lasts 60 ticks counting the start.
- ⚠️ The picture draws the cloud growing with the counter and shrinking with distance, its particles scattered from the ship's private explosion generator seeded from the four stored bytes (the main generator's steps with no carry kept, [RULES C.2.2](../../../docs/RULES.md#c22-the-explosion-cloud-generator-cosmetic)), so it never touches the main generator.

### Kills, bounties and the law ([RULES C.13](../../../docs/RULES.md#c13-kills-bounties-and-credits), [C.15](../../../docs/RULES.md#c15-legal-status-and-police))

- ✅ A kill adds 1 to the 16-bit tally, wrapping to 0 (and rank 0) after 65535, and every 256th kill shows the praise message.
- ✅ A finished explosion pays its bounty only when no message shows and the player is not in mis-jump space; a non-zero bounty shows the new cash, so any other bounty coming due while it shows, even in the same tick, is lost; a zero bounty shows nothing.
- ✅ Launching sets L ← L OR the contraband value; a finished police explosion sets L OR 64; a normal arrival halves L and returns the bit shifted out; starting a galaxy-drive jump clears L (the escape pod's clearing is `equipment::escape_pod_rescue`).
- ⚠️ The launch calls `on_launch`, a normal hyperspace arrival calls `on_hyperspace_arrival` and passes the returned bit to the planet's placement ([RULES B.10.1](../../../docs/RULES.md#b101-on-arrival-in-a-system-ordinary-or-galaxy-jump)), a mis-jump arrival calls nothing, and starting a galaxy-drive jump calls `on_galaxy_jump`.
- ✅ Police respond as [RULES C.15.3](../../../docs/RULES.md#c153-how-police-respond) says through the AI: a station angered by a laser hit, a missile, or a trader hit or targeted while it is present launches police while it stays in the bubble.
- ⚠️ A hostile station cannot be docked with by hand or by the auto-dock, and a newly created station is friendly (AI byte 1); the docking test and the station's creation hold these.

### For the picture and the sound

- ⚠️ The sounds of [RULES D.11](../../../docs/RULES.md#d11-sound-cues) play on these results: laser (a `Shot`), explosion B quietly on a laser hit and on a kill, explosion A on damage that reaches the energy bank, on a collision survived and on a refused scoop, the beep on a lock, the long beep on unarm, the launch whoosh on a fired missile, the E.C.M. warble on a pulse starting and its end when `laser_and_ecm_bookkeeping` reports the pulse stopped.
- ⚠️ The picture draws the player's laser lines toward the shot's jittered convergence point for both laser types (deliberate difference 10) and shows the area blast's flash while it is active.
- ⚠️ The presentation words the timed messages this capability shows (praise, jammed, target lost, bounty, scooped, cargo lost, equipment lost) within the budgets of [RULES D.9.1](../../../docs/RULES.md#d91-timed-in-flight-messages).

## What it deliberately doesn't do

- It does not run the tick or the slot loop, decide what is on screen, run the player's death, the escape pod, the docking test, removal for distance or spawning: it returns what the flight tick must act on.
- It never uses the camera: every combat rule uses the active mount, and the shield hit depends only on the attacker's z relative to the player's ship.

## Where it lives

- Code: [`mod.rs`](mod.rs), [`steps.rs`](steps.rs) (the C.4 steps), [`lasers.rs`](lasers.rs), [`missiles.rs`](missiles.rs), [`countermeasures.rs`](countermeasures.rs) (E.C.M., area blast, end-of-tick bookkeeping), [`damage.rs`](damage.rs), [`contact.rs`](contact.rs), [`explosion.rs`](explosion.rs), [`kills.rs`](kills.rs) (kills, bounties, legal status).
- Built on: the [AI capability](../ai/ai.md), the [bubble](../bubble/mod.rs), the [cockpit](../cockpit/mod.rs), the [pilot](../pilot/mod.rs), the [market](../market/market.md) (scooping and losing stacks), [ships](../ships/mod.rs) and the main generator in [random](../random/mod.rs).
- Used by: the [fly in a system](../../use_cases/fly_in_system/fly_in_system.md) use case.
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
