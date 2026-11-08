# The panels

> Status marks: [knowledge-driven development](https://github.com/david-brandt-the-icelander/knowledge-driven-development)

**Written for:** the [pilot](../../../../../Actors/pilot.md)

## What this is for

Every screen of the game is a plain glass panel driven from the keyboard ([UI-DESIGN § Screens](../../../docs/UI-DESIGN.md#screens), [RULES D.6](../../../docs/RULES.md#d6-screens-required-information-and-accepted-actions)): the title, the docked hub and its pages, the same pages over the flight view, pause and the tunnels. The sim decides which screen shows; a page asks the sim for every change and shows what it says.

## What it does

### The title

- ✅ The title, a strapline and a menu on the right third over the ship turning in front of the star: **Continue** (with the pilot's name) starts the last saved or loaded pilot, the start pilot until one is saved; **Load pilot** lists the saved pilots, takes a typed name (letters and digits, up to seven, as RULES D.6.12 says), loads it and starts, and says why when it cannot; **About** shows the credit line of GDD § 1; **Quit** closes the game. ↑↓ and `Enter` ([RULES D.3.1](../../../docs/RULES.md#d31-title-sequence)).
- ⚠️ **New pilot** starts the start pilot even after another pilot was saved or loaded this session, and **Options** opens the options panel (UI-DESIGN § Options).
- ⚠️ A pilot can be exported to a file and imported from one (DESIGN § In-game UI, Saving).

### The docked hub

- ✅ Docked, one panel on the right with the tabs `01 MARKET`, `02 EQUIP`, `03 GALAXY`, `04 LOCAL`, `05 SYSTEM`, `06 PILOT`, `07 HOLD`, switched with the digits 1–7, `Q`/`E` or `Tab`, and with the flight screen keys; beneath it a bar with the station and system, the Reach, the credits, the hold space left and **Launch** `[L]`. The tab on show is the sim's screen, so docking opens the pilot page as RULES D.3.2 says.
- ✅ **Market**: the 17 goods with unit, price here, what is for sale and what is held, and a ▲ where this economy pays above the scale's middle. ↑↓ pick a row; ←→ set the quantity (`Shift` by 10) and the keypad's digits type it; `B` buys and `N` sells that many. The stepper shows how many can be bought (availability, hold room and cash) and sold; the sim refuses anything else and the page shows the refusal (too many, hold full, no funds) or the trade and the cash left (deliberate difference 12, [RULES A.10](../../../docs/RULES.md#a10-buying-and-selling)).
- ✅ **Equip**: the items this tech level offers, with prices now, a one-line effect and how many are carried or where they are fitted, and the fitted equipment beside them. ↑↓ and `Enter` buy; a laser first asks which mount (←→ or 1–4, `Enter`, `Esc` back). A refusal shows (no funds, already fitted, Darts at maximum) and the page stays open ([RULES A.12](../../../docs/RULES.md#a12-equipment)).
- ✅ **Galaxy**: the Reach chart, with every system at (x, y / 2), tinted farm or factory, the current system's cross and fuel-range circle, the selected system ringed, the cursor, and an info card for the system nearest the cursor (name, distance and whether it is in range, economy, government, tech level). **Local**: the neighbourhood at four pixels a unit with RULES A.6.2's label layout. On both, the arrows move the cursor one unit (`Shift`: eight), held arrows repeat six times a second while docked, a click places it, `Enter` selects and shows the name and distance (RULES D.9.2 N4), `Home` brings the cursor back; moving the cursor selects nothing until something selects ([RULES A.6.3](../../../docs/RULES.md#a63-cursor-and-keys-on-a-chart)).
- ✅ **System**: the selected system's distance (none when 0), economy, government, tech level, population, inhabitants, productivity and radius, a plain turning planet, and two lines written only from the data (GDD § 9.4 `ui.system_blurb`, [RULES D.6.5](../../../docs/RULES.md#d65-system-data-screen)).
- ✅ **Pilot**: name, present and target systems, condition, fuel, cash, legal standing, rank with its chevrons and kills, and the equipment in RULES D.6.2's order; docked, `S` saves under a typed name (letters and digits, up to seven; `Enter` saves, `Esc` cancels) and shows the outcome.
- ✅ **Hold**: fuel, cash, the hold's capacity as a bar, and each goods item carried ([RULES D.6.3](../../../docs/RULES.md#d63-inventory-screen)).
- ⚠️ The hub's background is a lit hangar the pilot can orbit, with fitted equipment shown on the model, and the Equip page's camera moves to where an item fits.
- ⚠️ `Tab` on a chart cycles the systems in range.

### Over the flight view

- ✅ `G`, `L`, `I`, `O`, `V` and `Y` open the Galaxy, Local, System, Prices (the market, read-only), Pilot and Hold pages over the flight view, with the HUD still below and a Danger strip along the top while the condition is red; the same key or `Esc` closes. The sim keeps running.

### Pause, tunnels

- ✅ Pause dims the scene and offers **Resume**, the **Auto-centre** and **Damping** toggles with their states, and **Quit to title**, which asks first; `Esc` or `P` resumes ([RULES D.3.12](../../../docs/RULES.md#d312-pause)).
- ✅ The tunnels clear the view and draw rings rushing outward by RULES D.3.4's visual rule: gold bay rings for the launch and docking, cycling blues for a jump, warm colours for a Reach jump (with its message, deliberate difference 10), and green rings that break off for the mis-jump into the Deep.
- ⚠️ Pause also offers Options and Controls, and the sound and flashing toggles of RULES D.3.12.
- ⚠️ After death, a panel offers **Restart from last save** or **Title** (UI-DESIGN § Death); the sim returns to the title after its 61 ticks today.
- ⚠️ Transitions can be skipped with `Enter` after the first time; panels slide and fade (UI-DESIGN § Tokens, Motion).

## Where it lives

- Code: [`hub.gd`](hub.gd) and its pages [`market_page.gd`](market_page.gd), [`equip_page.gd`](equip_page.gd), [`chart_page.gd`](chart_page.gd), [`system_page.gd`](system_page.gd), [`pilot_page.gd`](pilot_page.gd), [`hold_page.gd`](hold_page.gd); [`title.gd`](title.gd), [`pause_panel.gd`](pause_panel.gd), [`tunnel.gd`](tunnel.gd); the shared look in [`look.gd`](look.gd).
- Diagram: [`.dev/class-diagram.json`](.dev/class-diagram.json); the presentation's [component diagram](../.dev/component-diagram.json).
