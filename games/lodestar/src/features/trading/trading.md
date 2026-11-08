# Trading at the market

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

Docked at a station, the pilot buys goods to carry and sells what is in the hold. LodeStar does this in a market panel: pick any item, in any order, set a quantity with a stepper, and press Buy or Sell ([deliberate difference 12](../../../docs/RULES.md#deliberate-differences-from-the-baseline)). Prices, availability and hold space are the [market capability](../../capabilities/market/market.md)'s; this feature is the purchase and the sale.

## What it does

- ✅ The stepper's largest buy is the smallest of the item's availability, the room left in the hold for it ([RULES A.11.1](../../../docs/RULES.md#a111-hold-space)) and the whole units the cash pays for at the current price.
- ✅ A buy of `q` units takes `q × price` from cash, adds `q` to the cargo and takes `q` from availability, which is step 6 of [RULES A.10.2](../../../docs/RULES.md#a102-buying-docked-only) for `q`.
- ✅ A buy above the limit is refused with nothing changed, naming the first limit it breaks in the order availability, hold room, cash.
- ✅ Goods 13..16 take no hold space, so their buys are limited only by availability and cash ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 10), and by the 255 the pilot's record can hold of one item.
- ✅ The special item (16) is never on sale but can be sold.
- ✅ The stepper's largest sale is the cargo held of the item; a sale of `q` units adds `q × price` to cash and takes `q` from the cargo, so partial sales are allowed.
- ✅ Selling never restores availability ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 7), and buying and selling use the same price.
- ✅ Buying or selling 0 changes nothing.
- ✅ Prices use the economy and market byte the caller passes, which are the current system's economy and the pilot's stored market byte ([RULES A.9.2](../../../docs/RULES.md#a92-the-market-byte)).
- ✅ Nothing in buying or selling draws a random number.
- ⚠️ The market panel lists all 17 items with their price (one decimal) and unit, and the availability with its unit or a dash when none, as [RULES A.9.5](../../../docs/RULES.md#a95-the-market-screen) says; in flight it is view-only and shows the current system's stored market.
- ⚠️ Buy and Sell are offered only while docked, and the stepper never offers more than the largest buy or sale, so a refused quantity never reaches the sim.
- ⚠️ The inventory panel shows fuel and cash with one decimal, the hold extension when the hold is 26 tonnes or more, and every item held with its quantity and unit ([RULES A.10.4](../../../docs/RULES.md#a104-inventory-screen)).

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| More than the market has | The stepper stops at the availability | Buy what there is, or come back after the next jump | ⚠️ |
| The hold is full | The stepper stops at the room left | Sell cargo or fit the hold extension | ⚠️ |
| Not enough cash | The stepper stops at the whole units the cash pays for | Sell cargo first | ⚠️ |

## What it deliberately doesn't do

- No number entry, fixed item order or one-second waits: the panel replaces the baseline's prompts (deliberate difference 12).
- No price spread and no restocking by selling.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`Trade`, `BuyRefused`, `SellRefused`, `max_buy`, `buy`, `max_sell`, `sell`).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
- Capabilities: the [market and the hold](../../capabilities/market/market.md).
