# Flight

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

The pilot turns and throttles their ship, and everything in the space around it moves: ships along their noses, planets spinning, the whole scene swinging as the pilot rolls and pitches. The player's ship never moves itself; the universe is carried past it and rotated around it. This capability holds the pilot's attitude and speed, moves and turns every object in the bubble, and straightens their orientation vectors so they stay square. The exact mechanics are in [RULES B.5 to B.8](../../../docs/RULES.md#b5-player-attitude-roll-and-pitch) and the rotation counters and ship speed of [RULES C.1](../../../docs/RULES.md#c1-conventions-used-in-this-section); this document says which of them LodeStar does.

## What it does

### Attitude ([RULES B.5](../../../docs/RULES.md#b5-player-attitude-roll-and-pitch))

- ✅ The roll rate and pitch rate are bytes from 1 to 255 centred on 128; held roll-left, roll-right, climb and dive keys move them by 7 or 14 in that order, capped at 255 and floored at 1 (B.5.2).
- ✅ With auto-centre on, a key that would leave a rate on the far side of the centre from its direction snaps it to 128, so the opposite key first returns a rate to centre (B.5.2).
- ✅ With damping on, the roll rate moves 1 toward the centre twice a tick and the pitch rate once; with it off the rates hold (B.5.3).
- ✅ The roll magnitude (0..31) and pitch magnitude (0..8, never 2) follow the step tables of B.5.3, and give the per-tick roll angle sign(r)·a/256 and pitch angle −sign(p)·b/256 that motion uses from the next substep on.
- ✅ Holding roll-left from the centre raises the roll rate by a net 5 a tick to 253, reaching magnitude 31 after 25 ticks; holding dive raises the pitch rate a net 13 a tick to 254, reaching magnitude 8 after 10 ticks; on release they decay by 2 and 1 a tick.
- ✅ Holding both keys of a pair gives no turn from the centre, with auto-centre on or off (Q-B18).
- ✅ A control reset sets both rates to 128, the roll angle to +3/256 and the pitch angle to 0 until the next angle computation, and keeps the options (B.5.3).
- ✅ Auto-centre and damping are both on when the attitude is made.
- ✅ While dying, the attitude still damps and computes its angles but takes no keys (B.3.3 step 1): the caller passes no held keys.
- ⚠️ The pause menu toggles auto-centre and damping (B.3.2); the flags live on `Attitude`, and the pause menu flips them.
- ⚠️ Held keys are a set updated on key-down and key-up and cleared when the window loses focus, sampled once per tick; one-shot presses ignore auto-repeat and are dispatched on the substep they arrive, with flight actions queued for the next tick logic in order of arrival (B.5.4). The input side of the flight use case builds `HeldControls` from that set.
- ⚠️ The roll and pitch indicators on the dashboard show the rates, magnitudes and signs (B.5.3).

### Speed ([RULES B.6](../../../docs/RULES.md#b6-speed))

- ✅ Each tick, a held speed-up key adds 1 below 40, then a held slow-down key takes 1 above 1, so the keys keep speed in 1..40 and both held change nothing except at the limits.
- ⚠️ A flight-state reset sets speed to 3, a launch to 12, a failed slow docking to 1 and death to 0; the rules that do those set the speed to the named constants here (`RESET_SPEED`, `LAUNCH_SPEED`, `FAILED_DOCKING_SPEED`, `DEATH_SPEED`).

### Motion of objects ([RULES B.7](../../../docs/RULES.md#b7-motion-of-objects))

- ✅ Every substep, each object in the bubble, in slot order, moves along its nose as stored (not re-normalised) by 1.5 × its speed × ½, then the player's roll and pitch rotate its position in the sequence of B.7.2 step 2, then the player's speed carries it ½ × S toward −z.
- ✅ The player's roll and pitch then rotate each of its nose, roof and side vectors in the sequence of B.7.2 step 5.
- ✅ A non-zero pitch counter turns the roof and nose, then a non-zero roll counter turns the roof (as just turned) and side, by the fixed factors 1 − 1/1024 and ±1/32 a substep whatever the magnitude, with the sign bit choosing the direction; a negative pitch counter swings the nose toward the roof (B.7.2 steps 6–7, C.1).
- ✅ The own rotation shrinks a turning pair by about 0.99951 a substep instead of preserving length (Q-B1).
- ✅ Planets and the sun never move along their own nose; the sun's orientation is never changed; planets turn by their counters like ships (B.7.2, B.9.2).
- ✅ Each tick, a non-body object adds its acceleration, read as a signed byte, to its speed, clamps the result to 0..its type's top speed (0 for a type without one), clears the acceleration, and decays each counter's magnitude by 1 keeping its sign unless it is 0 or 127 (B.7.3, C.1).
- ✅ A speed set above the type's top speed lasts only until the object's next per-tick update (Q-B8).
- ✅ Bodies take no per-tick own-motion update (B.9.2).
- ⚠️ The flight tick runs two motion substeps per tick, motion before the tick logic in Flight mode and after it in Death mode and Escape mode, with the per-tick update as step 4 of processing each object (B.3.2, B.3.4); the flight use case calls `move_substep` and `own_motion_tick` in that order.

### Re-orthonormalisation ([RULES B.8](../../../docs/RULES.md#b8-re-orthonormalisation))

- ✅ An object is due on ticks where (C XOR slot) mod 16 = 0, every 16 ticks staggered by slot.
- ✅ Tidying normalises the nose, makes the roof perpendicular to it and normalises it, and sets side to nose × roof (right-handed), leaving any zero-length vector unscaled.
- ✅ Planets and the sun are never tidied, so their spinning vectors keep shrinking (Q-B1).
- ✅ An object that is exploding or killed is not tidied (B.3.4 step 3).
- ✅ The first tidy flips a mirrored frame's side, as the new station's is (Q-B9).

## What it deliberately doesn't do

- It does not decide when a tick or substep runs, nor reset the flight state; the flight use case drives it.
- It does not place, add or remove objects, run the AI or test contact; those rules own their own capabilities and features.
- It draws no random numbers.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`HeldControls`), [`attitude.rs`](attitude.rs) (`Attitude`, `roll_magnitude`, `pitch_magnitude`), [`speed.rs`](speed.rs) (`apply_speed_keys`), [`motion.rs`](motion.rs) (`move_substep`, `move_object`, `own_motion_tick`), [`tidy.rs`](tidy.rs) (`tidy`, `tidy_due`, `tidy_if_due`).
- Built on: the [bubble](../bubble/mod.rs) (`Bubble`, `Object`), [space](../space/mod.rs) (`Vec3`, `SignMagnitude`) and [ships](../ships/mod.rs) (`top_speed`).
- Used by: the [fly in a system](../../use_cases/fly_in_system/fly_in_system.md) use case.
- Diagrams: [`.dev/class-diagram.json`](.dev/class-diagram.json).
