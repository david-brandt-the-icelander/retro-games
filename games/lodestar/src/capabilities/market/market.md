# The market and the hold

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

A pilot makes a living by buying goods where they are cheap and selling them where they are dear, so every system's market must price its 17 goods from the system's economy and a per-visit fluctuation, and the ship's hold must decide what fits. This capability owns those rules: the goods table, prices, availability, the market byte and hold space. The exact mechanics are in [RULES A.9](../../../docs/RULES.md#a9-the-market) and [A.11](../../../docs/RULES.md#a11-the-hold); the goods' names, units and numbers are the GDD's ([§ 4.7](../../../docs/GDD.md#47-goods-units-and-the-law), [§ 5.1](../../../docs/GDD.md#51-market-rules-a9)). Buying and selling at the market panel are the [trading feature](../../features/trading/trading.md).

## What it does

- ✅ The goods table holds the GDD's 17 items in their fixed order, each with its name, unit, base price, gradient, base quantity and fluctuation mask.
- ✅ An item's price is the formula of [RULES A.9.3](../../../docs/RULES.md#a93-price), in tenths of a credit, wrapping mod 256 in both directions before the ×4, with the gradient's magnitude taken mod 32 and its sign choosing the direction.
- ✅ An item's availability is the formula of [RULES A.9.4](../../../docs/RULES.md#a94-availability): 128..255 counts as none, the result is cut to 6 bits, and the special item (16) is never on sale.
- ✅ The GDD's ranges of price and availability at economies 0 and 7, over every market byte, come out exactly as [GDD § 5.1](../../../docs/GDD.md#51-market-rules-a9) lists them.
- ✅ The market never looks a system up: callers pass the system's economy (0..7) as a number.
- ✅ Arriving in a system stores the market byte and rebuilds all 17 availabilities from the economy and that byte ([RULES A.5.6](../../../docs/RULES.md#a56-the-common-arrival) steps 1 and 2); the drawing form takes exactly one byte from the main generator.
- ⚠️ The jump calls the drawing arrival on every arrival after the tunnel (a normal or galaxy jump, not a mis-jump), before the flight-state reset's draws, and docking, launching or re-docking never change the market byte ([RULES A.9.2](../../../docs/RULES.md#a92-the-market-byte)).
- ✅ The new game's market is market byte 0 and the availability the formula gives for the starting system's economy; for economy 5 both the availability and the prices are [GDD § 5.2](../../../docs/GDD.md#52-starting-market-rules-a97)'s lists.
- ⚠️ Starting a new game sets the start pilot's market from the starting system's economy, as the universe computes it.
- ✅ Items 0..12 take hold space and items 13..16 never do; there is room for `n` more of an item exactly as [RULES A.11.1](../../../docs/RULES.md#a111-hold-space) says, and the room left never goes below zero.
- ✅ No more than 255 of one item can be held, because the pilot's record keeps one byte per item; a gain or purchase past that is refused as no room. Only the hold-free items 13..16 can reach it.
- ✅ A unit gained in flight is added only when there is room; otherwise nothing is added and the caller plays the no-room sound ([RULES A.11.3](../../../docs/RULES.md#a113-gaining-and-losing-cargo-in-flight-summary-detail-elsewhere)).
- ✅ A scooped canister draws one byte first and gives item `byte & 7`, whether or not the hold has room ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 14).
- ⚠️ Flight scoops a canister, alien drone (item 16) or escape pod (item 3) only with the fuel scoop fitted and the object below the ship, destroys the object either way, and shows the item's name when it is gained ([RULES B.15.3](../../../docs/RULES.md#b153-scooping-objects)).
- ✅ Losing a stack sets that item's cargo to 0 and says whether there was any to lose, which is when the loss notice shows; emptying the hold sets every item to 0.
- ⚠️ Damage that reaches the energy banks picks the stack to lose from the drawn pair as [RULES C.10.3](../../../docs/RULES.md#c103-equipment-and-cargo-loss) says.
- ✅ Items 3 and 6 are the seriously illegal goods and item 10 the mildly illegal one, matching the pilot's contraband value ([RULES A.9.6](../../../docs/RULES.md#a96-items-named-by-number)).
- ✅ Nothing in the market or the hold draws a random number except arrival and a scooped canister.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| A scooped item does not fit | The no-room sound; the object is gone and nothing is added | Make room in the hold, or fit the hold extension | ✅ |
| 255 of a hold-free item are already held | The item cannot be bought or scooped | Sell some first | ✅ |

## What it deliberately doesn't do

- It does not know systems, names or the galaxy: the economy is a parameter.
- It does not decide when to scoop or when damage strikes; flight and combat call it.
- It has no spread: buying and selling use the same price.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`Goods`, `Unit`, `TABLE`, `Scooped` and the operations).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Used by: the [trading feature](../../features/trading/trading.md).
