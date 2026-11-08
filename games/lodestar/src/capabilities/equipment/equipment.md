# Equipment

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

Between runs the pilot spends money on the ship: fuel, missiles, a bigger hold, better lasers and gear that changes how flying and fighting go. This capability owns the twelve items, which a station offers at its tech level, what each costs and what buying it does. The exact mechanics are in [RULES A.12](../../../docs/RULES.md#a12-equipment) and [deliberate difference 12](../../../docs/RULES.md#deliberate-differences-from-the-baseline); the names and prices are the GDD's ([§ 4.8](../../../docs/GDD.md#48-equipment), [§ 5.3](../../../docs/GDD.md#53-equipment-prices-and-the-fuel-price-rules-a12)).

## What it does

- ✅ The twelve items keep RULES' fixed order (fuel, missile, hold extension, E.C.M., pulse laser, beam laser, fuel scoop, escape pod, area blast, energy booster, auto-dock, galaxy drive) with the GDD's names and HUD tags.
- ✅ A system with internal tech level `T` offers the first `min(T + 3, 12)` items ([RULES A.12.2](../../../docs/RULES.md#a122-availability-by-tech-level)), so each item's lowest shown tech level is the GDD's.
- ✅ Every item but fuel has the GDD's fixed price; fuel costs `(70 − fuel) × 3` tenths, recomputed from the current tank, and nothing with a full tank ([RULES A.12.3](../../../docs/RULES.md#a123-prices)).
- ✅ The equipment panel's rows are the offered items with their current prices.
- ✅ Buying checks the full price against cash and refuses with nothing changed when it is short, even when a beam laser would refund a pulse laser ([RULES A.14](../../../docs/RULES.md#a14-quirks-and-edge-cases) item 12).
- ✅ Otherwise the price is taken and the item applied as the table of [RULES A.12.4](../../../docs/RULES.md#a124-the-shop-and-each-items-effect) says; an item at its limit is refused and the price given back, leaving the pilot as it was.
- ✅ Fuel fills the tank and is never refused, even at a price of 0.
- ✅ A missile is added up to four; the hold extension sets the hold to 37 tonnes once; E.C.M., fuel scoop, escape pod, area blast, energy booster, auto-dock and galaxy drive are each fitted once.
- ✅ A laser goes on the mount the pilot chose (Fore, Aft, Port or Starboard); a laser without one of the four mounts is refused before anything changes, after the cash check.
- ✅ A pulse laser needs an empty mount; a beam laser is refused only on a mount that already has a beam, and replacing a pulse laser gives back the pulse laser's price.
- ✅ The panel picks from a list, so an item the system does not offer is refused as leaving the panel would be, and any refusal leaves the shop ready for the next purchase (deliberate difference 12).
- ⚠️ The equipment panel is open only while docked, lists the offered items with their prices, asks for a mount for a laser, shows the not-enough-cash or the item's already-fitted notice on a refusal and stays open, and shows the cash remaining after a purchase.
- ⚠️ Buying fuel also sets the main-loop counter to 0, which has no lasting effect because launching resets it.
- ✅ An escape-pod rescue empties the hold, clears legal status, uses up the pod and fills the tank, keeping cash, kills, missiles and the other equipment ([RULES C.10.5](../../../docs/RULES.md#c105-the-players-escape-pod)).
- ⚠️ The escape pod launches and is watched drifting away as [RULES C.10.5](../../../docs/RULES.md#c105-the-players-escape-pod) says; in mis-jump space the pilot dies instead of being rescued, and otherwise is docked at the current system's station.
- ✅ With the fuel scoop fitted, scooping at the sun adds `⌊speed / 8⌋` to the fuel up to a full tank, and reports that the scooping message shows even when nothing was gained.
- ⚠️ Flight scoops fuel at the sun only on the tick whose 32-tick phase is 20, with no station present and a cabin temperature of at least 224 ([RULES B.15.2](../../../docs/RULES.md#b152-fuel-scooping-from-the-sun)).
- ✅ The energy bank gains 2 at each recharge step with the energy booster, else 1.
- ⚠️ Flight recharges the energy bank every 8th tick, capped at 255 ([RULES C.10.1](../../../docs/RULES.md#c101-levels-and-recharge)).
- ⚠️ The E.C.M., area blast and auto-dock work in flight as RULES C.8, C.9 and B.12.3 say, and the galaxy drive is used up by the galactic jump at the key press ([RULES A.5.3](../../../docs/RULES.md#a53-the-galaxy-drive-key)).
- ✅ Nothing in the shop draws a random number.

## How it fails

| What goes wrong | What the reader sees | What to do | Status |
| --- | --- | --- | --- |
| The price is more than the cash | The not-enough-cash notice; nothing changes | Sell cargo, or choose something cheaper | ⚠️ |
| The item is already fitted or at its limit | The item's name and the already-fitted notice; the money is not taken | Choose another item or another mount | ⚠️ |

## What it deliberately doesn't do

- No number entry, fixed prompt order or one-second waits: the panel replaces them (deliberate difference 12).
- It does not sell equipment back.

## Where it lives

- Code: [`mod.rs`](mod.rs) (`Item`, `Bought`, `Refused` and the operations).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json).
