# The words

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md), and the writer who checks the game's text

## What this is for

Every word the presentation shows lives in one table, [`words.gd`](words.gd), so it can be checked in one place for overlap with the original ([DESIGN § In-game UI](../../../docs/DESIGN.md#in-game-ui), Build). The GDD's data the sim already holds (goods, equipment, systems, economies, governments, inhabitants, the Reaches) is read from the sim through the bridge instead and is not repeated here.

## What it does

- ✅ The GDD's names: the title, the ranks, legal standings, condition labels, ship names, mount tags and the credit line ([GDD § 1](../../../docs/GDD.md#1-identity), [§ 4](../../../docs/GDD.md#4-setting-and-names)).
- ✅ The timed messages M1–M11 and the notices N1–N6 written fresh to RULES D.9's purposes and the GDD § 9 budgets, in UI-DESIGN's voice (terse, plain, a little dry; an exclamation mark only for the kill milestone), with the energy-low and incoming-missile messages marked urgent ([RULES D.9](../../../docs/RULES.md#d9-messages)).
- ✅ The remake's own text of GDD § 9.4: the equipment effects (60 characters at most), the epitaphs by cause of death, the system description made only from the data, and the key hints.
- ✅ Numbers as UI-DESIGN asks: scrip with one decimal and thousands separators (`1,240.5`), light years and population with one decimal, and system names in word case (RULES D.10).
- ⚠️ The table is checked with `overlap.py` from `clean-room-rebuild` before every push, with the original's names as `--names` ([DESIGN § Testing](../../../docs/DESIGN.md#testing)).
- ⚠️ The menus' option names (`ui.option.*`) and the focus-lost card's words.

## Where it lives

- Code: [`words.gd`](words.gd), used by the [HUD](../hud/hud.md) and the [panels](../ui/ui.md).
