# Death

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), through the tick in the [fly-in-a-system use case](../../use_cases/fly_in_system/fly_in_system.md)

## What this is for

Crash, burn, misjudge a docking or run out of energy, and the ship is gone: a few wrecks tumble where it was, the game-over notice shows for five seconds, and the game returns to the title with the last saved pilot. The mechanics are in [RULES B.18](../../../docs/RULES.md#b18-death-flight-related-parts), [C.10.4](../../../docs/RULES.md#c104-the-players-death) and [D.3.10](../../../docs/RULES.md#d310-death).

## What it does

- ✅ `die` cancels a running hyperspace countdown, so no jump can rescue a dead pilot ([deliberate difference 5](../../../docs/RULES.md#deliberate-differences-from-the-baseline), [RULES B.23 Q-B3](../../../docs/RULES.md#b23-quirks-reproduce-these), A.14 item 4).
- ✅ It keeps a quarter of the speed, resets the flight state (54 draws) with the bubble emptied, sets the speed to that quarter, the front mount and C = 255.
- ✅ It adds four wreck canisters, each from the hostile template's returned pair `(a, x)`: at x₀ = (a ÷ 4) AND 63, y = x₀ XOR 42, z = x₀ OR 80, roll x AND 0x8F, pitch (x ÷ 2) AND 0x87, AI 0, nose (0, 0, 1), side (−1, 0, 0), roof (0, 1, 0), speed twice the quarter; one more byte, when odd, marks a wreck killed so it explodes ([RULES C.10.4](../../../docs/RULES.md#c104-the-players-death)). From the starting generator state the wrecks are at (44, 6, 124), (18, 56, 82), (53, 31, 117) and (40, 2, 120), and only the last explodes.
- ✅ Then the speed is 0 and `Dying` counts the 61 dying ticks; it records the cause for the epitaph and whether the pilot died in the Deep.
- ✅ `return_to_title` cancels the countdown and puts a copy of the last saved or loaded pilot in play; nothing of the dead pilot is kept (`Pilots::on_death`, [RULES A.7.3](../../../docs/RULES.md#a73-two-copies)).
- ⚠️ The lead calls `die` only when not already dying, clears held keys and queued presses, sets Death mode, and if the death came in the middle of the per-object loop carries on over the wrecks from the next slot ([RULES B.23 Q-B14](../../../docs/RULES.md#b23-quirks-reproduce-these)). Each Death-mode tick runs the dying tick logic (no player controls or actions, no periodic spawning) before the half-step moves, then `Dying::tick`; when it returns true the lead calls `return_to_title` and starts the title.
- ⚠️ Death plays the two explosion sounds (S3 and S4) and shows the space view without sights, with the game-over notice near its centre ([RULES D.6.14](../../../docs/RULES.md#d614-death-and-tunnel-screens)); the death panel's epitaph names the `Cause`.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The pilot never saved | Death returns to the start pilot | Save when docked | ✅ |

## What it deliberately doesn't do

- The countdown does not survive death (deliberate difference 5).
- It does not decide when the player dies: the planet and sun checks, docking, damage and the escape pod in the Deep do, and pass their `Cause`.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`Cause`, `Dying`, `die`, `return_to_title`).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Uses: the bubble, cockpit, random, ships and space capabilities; the [spawning](../spawning/spawning.md) feature's `hostile_template`, the [hyperspace](../hyperspace/hyperspace.md) feature's `Countdown`, and the [saving](../saving/saving.md) feature's `Pilots`.
