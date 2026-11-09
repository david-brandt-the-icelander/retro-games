# The escape pod (the lifeboat)

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

When a fight is lost, a pilot with an escape pod abandons ship: the old hull drifts away for eight seconds, then the pilot wakes up docked at the system's station with cash and equipment but no cargo, a clean record and a full tank. In the Deep there is no station to reach, and the pod only delays death. The mechanics are in [RULES B.17](../../../docs/RULES.md#b17-the-escape-pod), [C.10.5](../../../docs/RULES.md#c105-the-players-escape-pod) and [D.3.9](../../../docs/RULES.md#d39-escape-pod).

## What it does

- ✅ `launch_pod` does nothing without a pod fitted.
- ✅ With one, it remembers whether the pilot is in the Deep, empties the bubble, leaves the safe zone and clears the missile lock but not the arming; then adds the abandoned hull, a medium multi-role ship launched straight ahead at (0, −28, 14) with speed 8, pitch counter 0xC2 and AI byte 0, unless the bubble was full; and resets the controls, so the scene rolls at +3/256 rad a tick. The pilot's speed is kept.
- ✅ The hull never collides with the player: `Escape::spares` names its slot on the launch tick, for the contact step to skip ([deliberate difference 7](../../../docs/RULES.md#deliberate-differences-from-the-baseline), [RULES B.23 Q-B2](../../../docs/RULES.md#b23-quirks-reproduce-these)).
- ✅ Each of the 97 escape ticks runs only the hull's own-motion update (its pitch decays from 66 to 0) and the escape countdown; `Escape::tick` says when they are over.
- ✅ `aftermath` resets the flight state (54 draws) with the bubble emptied. From the Deep the player then dies (the death's own 54 draws and wrecks follow). Otherwise the hold is emptied, legal status becomes clean, the pod is used up, the tank is filled (`equipment::escape_pod_rescue`) and the pilot enters the docked state at the current system's station; cash, other equipment, missiles, kills and the market are kept.
- ⚠️ The lead calls `launch_pod` among the queued actions, cancels any prompt, skips the tick's later queued actions and the laser, lets the rest of the tick run on the new bubble (one more rotation step for the hull, recharge, the counters and possibly a periodic spawn) and then sets Escape mode, in which presses are discarded and C, energy and the hyperspace countdown are frozen. Each substep it still moves the bubble by half a step with the kept speed.
- ⚠️ The pod's launch plays the launch sound (S7); the view stays on whichever mount was active ([RULES D.3.9](../../../docs/RULES.md#d39-escape-pod)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The pod is used in the Deep | The hull drifts away, then the death sequence | Jump out of the Deep instead | ✅ |
| The bubble is full at the launch | No hull drifts away; the rescue still comes | Nothing | ✅ |

## What it deliberately doesn't do

- The hull never damages or kills the player (deliberate difference 7).

## Where it lives

- Code: [`mod.rs`](mod.rs) (`Escape`, `launch_pod`, `Aftermath`, `aftermath`).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Uses: the bubble, cockpit, equipment, flight, pilot, random, ships, space and universe capabilities; the [death](../death/death.md), [docking](../docking/docking.md), [hyperspace](../hyperspace/hyperspace.md) and [spawning](../spawning/spawning.md) features.
