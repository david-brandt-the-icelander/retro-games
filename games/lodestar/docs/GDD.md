# LodeStar: game design document

Status: draft · Phase 2 of `create-retro-game` · Owner approval: _pending_

This document decides what LodeStar *is*: its name, world, words, numbers and sounds. What the game *does* is in [RULES.md](RULES.md), which wins wherever the two seem to disagree; every value below fills a slot that RULES marks as **data**. The look is in [ART-BIBLE.md](ART-BIBLE.md), the screens in [UI-DESIGN.md](UI-DESIGN.md), the engineering in [DESIGN.md](DESIGN.md).

## Open choices for the owner

These need your taste. Everything else in this document follows from RULES and the design documents, and stands unless you say otherwise.

| # | Choice | Options | Recommendation |
| --- | --- | --- | --- |
| 1 | **Title** | 1. *LodeStar* 2. *Eight Reaches* 3. *Long Haul Dark* | Keep **LodeStar**. It names the one thing every system has (its star) and the thing a pilot steers by. It is a common word, so it is a weak trademark and other products use it; a clearance search is needed before release whichever title wins. |
| 2 | **Which role the LPX-9 Grey Wolf takes** | a. The medium multi-role ship (types 5 and 7, which is also your own hull) b. The police interceptor (type 2) c. A small pirate fighter (types 1 and 3) | **a.** You watch your own ship all game, so it deserves the second real model, and it must not look like the heavy fighter the Cheetah plays, or players mistake pirates for themselves. If its proportions turn out fighter-like rather than hauler-like, use it for **b** and keep the Cheetah stand-in for your ship until a third model exists. |
| 3 | **Tone** | Dry working frontier, or light satire, or grim | **Dry working frontier**: plain, a little weary, never jokey; the voice of a ship's computer that respects you (UI-DESIGN). It suits used machines under one star. |
| 4 | **The captives cargo (goods item 3)** | *Bonded sleepers* (people in stasis sold into indenture), or the softer *Unlicensed passengers* | **Bonded sleepers.** RULES makes item 3 the thing a scooped lifeboat yields, so it has to be people; stasis and indenture say why it is illegal without showing cruelty. Written plainly, never played for laughs. |
| 5 | **Currency** | *Scrip* (SC), or *Tallies* (TL), or *Marks* | **Scrip.** Money issued by the station guilds fits a frontier of company stations. (Marks is rejected because MK reads as a ship's mark number.) |

## 1. Identity

- **Working title:** LodeStar (slug `lodestar`), set by the owner.
- **Title proposals:** 1. **LodeStar** 2. *Eight Reaches* 3. *Long Haul Dark*. The original's title is not offered: this repository is public and the remake must not trade on it.
- **Pitch:** Trade, fight and scrape a living across eight Reaches of space in a worn ship you can always see, under rules that play exactly like a 1984 classic.
- **Credit line** (the owner fills in the placeholders before release; this public file never names the original): "Inspired by *<Title>* (<year>) by <Author>, published by <Publisher>. Independent remake, not affiliated with or endorsed by the original rights holders."

## 2. Pillars

When two pillars conflict, the earlier one wins.

1. **Plays the same, looks new.** Every rule, number, timing and random draw in RULES is kept; every word, name, layout, model and sound is ours. The third-person camera is the one deliberate change to how the game plays.
2. **One star tells the story.** Each system is lit by its star alone, and everything you see of a system (its sun, its planet, its sky) is generated from its data.
3. **Used machines.** Ships, stations and money are old, expensive and worked hard. The voice is dry and practical; nothing is shiny, heroic or cute.
4. **A life measured in dockings.** Saving happens only at a station, and death returns you to your last save, so every launch is a small risk and every safe docking a small relief.
5. **The sim is the authority.** The picture interpolates and decorates; it never decides. That keeps parity provable now and makes multiplayer possible later.

## 3. Same and new

| Kept (functional, from RULES) | Renewed (expression, from this GDD and the design documents) |
| --- | --- |
| Every rule, formula, threshold, timing and probability, and the order of random draws | All text: messages, labels, prompts, the title, the credits |
| The 12 Hz tick with two motion substeps; the flight model, damping and auto-centre | Every proper noun: systems, Reaches, ship types, station, aliens, goods, equipment, ranks, governments, economies, currency |
| 8 galaxies of 256 systems; the generator's mechanics (advance step, four steps per system, byte-rotation galaxy transform, property formulas) | The generator's data: galaxy 0's starting state, the syllable table and the inhabitant word lists |
| The market formulas, availability rules and wrap-around quirks | The 17 goods and their numbers (base price, gradient, quantity, mask, unit) |
| Equipment order, tech gating, effects and refusal rules | Equipment names and prices; the fuel price |
| Thirteen ship roles with their type numbers; the AI, combat, spawning, law and rank rules | Ship names, models and retuned stats |
| Hold sizes 22 and 37, laser power 15, fuel maximum 7.0, starting cash 100.0 | Layouts, HUD, panels, fonts, palette, 3D art, effects, music and sound |
| Input semantics: held versus one-shot actions, tunnels discard keys, mount keys 1–4 | Key bindings (two layouts, both remappable), mouse camera control |
| Saving only while docked, under a name; the accept and reject rules | The save format and its integrity check (decision 12) |
| The eleven deliberate differences listed in RULES | The source code and its layered structure |

## 4. Setting and names

### 4.1 The world

**The Reaches.** People live scattered across eight Reaches, star clusters joined by old jump lanes that no one living remembers building. A pilot's ship is the most valuable thing they will ever own, usually bought second-hand, patched, and sold on again when they die or retire. Every inhabited system keeps one **Spindle**: a drum-and-ring station turning slowly in orbit, where ships berth, cargo changes hands and the station guilds issue **scrip**, the only money anyone accepts.

**Work.** Farm worlds ship grain, livestock and timber; factory worlds ship medicine, robotics and drive parts; everyone trades salvage. Pilots haul cargo between them, hunt raiders for the bounty boards, or carry what the law forbids. The law is the station's: an offence is logged when you launch, and patrol Mastiffs are sent after pilots with bad records.

**The Hush.** Between the stars, a jump sometimes drops out early into the **Deep**, a starless dark where the Hush wait: seamless curved ships that leak light from their seams and never speak. No one knows what they want. Their small craft, Hush motes, can be scooped when their carrier is gone, and the glass inside them sells well.

**Tone.** Dry, plain and a little weary. The game does not lecture, joke or celebrate; it reports. One exception, from UI-DESIGN: a kill may get an exclamation mark.

**Terms used throughout.** The player is a **pilot** (never any other title). A galaxy is a **Reach**; the galaxy chart is the **Reach chart**. The ordinary hyperspace jump is a **jump**; the in-system jump is a **hop**; the galaxy jump is a **Reach jump**; mis-jump space is **the Deep**. Distances stay in light years (LY).

### 4.2 Name generator data

**Syllable table** (RULES A.3.5). Entry 0 prints nothing. Entries 7, 15 and 25 have one letter (the implementation stores a filler in the second position, never printed). The table is our own; the verify role checks it against the original's table before the gate, and any shared group is replaced.

| Index | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Letters | (none) | KA | LO | VI | NE | SE | BO | O | MI | DA | RU | EL | HA | NO | PA | I |

| Index | 16 | 17 | 18 | 19 | 20 | 21 | 22 | 23 | 24 | 25 | 26 | 27 | 28 | 29 | 30 | 31 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Letters | YA | TO | FE | UN | KE | MO | IR | SA | VO | E | NI | HE | DU | LI | OS | TU |

Mostly consonant-vowel groups, with three vowels and five vowel-consonant groups for endings, so names alternate sounds and read aloud easily. Earlier drafts had `NU` and `TA`; they were swapped for `NE` and `TU` because they could spell unwanted English words.

**Starting state** (RULES A.3.1), galaxy 0, system 0: **`w0 = 0x5D38`, `w1 = 0x3CAC`, `w2 = 0x0E31`**.

It was chosen by search, with our own implementation of RULES A.3, for these properties:

- every Reach has all eight governments, 32 systems each;
- in Reach 1 every name has 3 to 8 letters; across all eight Reaches every name has 2 to 8 letters (2 letters only in Reaches 7 and 8), within UI-DESIGN's 12-character budget;
- 2,047 of the 2,048 systems have a position of their own (one pair shares a point in Reach 6, where the lower number wins the nearest-system search, as RULES says);
- no generated name contains any word on a short list of offensive or loaded words;
- system 0 makes a good first home (below).

System-0 states of every Reach, as test vectors for the galaxy transform (RULES A.3.3):

| Reach | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `w0 w1 w2` | `5D38 3CAC 0E31` | `BA70 7859 1C62` | `75E0 F0B2 38C4` | `EAC1 E165 7089` | `D583 C3CA E013` | `AB07 8795 C126` | `570E 0F2B 834C` | `AE1C 1E56 0798` |

**Starting system rule.** The start pilot is docked at **system 0 of Reach 1**: position `(b3, b1)` of the starting state, which is (60, 93). By the formulas of RULES A.3.4 it is a wealthy farm world (economy 5) under a free charter (government 5), tech level 6 as shown, population 3.1 billion, radius 6,460 km, settled by the default settlers. Ten systems lie within a full tank (7.0 LY), the nearest at 2.0 LY, and seven of the ten are factory worlds, so the first trades are easy to find. The generated name follows from the table and is not chosen separately.

### 4.3 Reaches

Each Reach takes its sky hue from ART-BIBLE § Space, in the same order. The chart title shows the name and the number.

| Reach (internal galaxy) | 1 (0) | 2 (1) | 3 (2) | 4 (3) | 5 (4) | 6 (5) | 7 (6) | 8 (7) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Name | Amber Reach | Rose Reach | Teal Reach | Violet Reach | Gilt Reach | Jade Reach | Rust Reach | Steel Reach |

### 4.4 Economies and governments

**Economy** (RULES A.3.4 and D.10): a prosperity word plus a type, printed as *<prosperity> <type> world*, or *Mixed, <type>-led* for codes 3 and 4. Codes 0–3 are the factory (industrial) end, 4–7 the farm (agricultural) end.

| Code | Prosperity word | Type | Printed |
| --- | --- | --- | --- |
| 0 | Wealthy | factory | Wealthy factory world |
| 1 | Working | factory | Working factory world |
| 2 | Lean | factory | Lean factory world |
| 3 | Mixed | factory | Mixed, factory-led |
| 4 | Mixed | farm | Mixed, farm-led |
| 5 | Wealthy | farm | Wealthy farm world |
| 6 | Working | farm | Working farm world |
| 7 | Lean | farm | Lean farm world |

**Government** (0 most lawless, 7 most orderly; RULES A.3.4 and C.16.3):

| Code | Label | Meaning in the fiction |
| --- | --- | --- |
| 0 | Lawless | No authority at all; raiders come and go |
| 1 | Raider haven | Run by whoever has the most guns |
| 2 | Contested | Several factions claim it; none holds it |
| 3 | Militia rule | Armed volunteers keep a rough order |
| 4 | Kin councils | Old families govern by custom |
| 5 | Free charter | Self-governing under a written charter |
| 6 | Assembly | Elected representatives, regular patrols |
| 7 | Protectorate | Guarded by a stronger neighbour; heavily patrolled |

### 4.5 Inhabitants

Structure per RULES A.3.6. The data screen prints the phrase in brackets, in word case, with one plural mark.

| List | Entries (index 0 first) |
| --- | --- |
| Default settlers (bit 7 of `b4` clear) | Settler families |
| S, size (3) | Towering, Wiry, Stunted |
| C, colour (6) | Ochre, Slate, Rust, Ivory, Teal, Violet |
| K, body (6) | Scaled, Plated, Downy, Tusked, Spined, Webbed |
| N, creature (8, printed plural) | Otter, Badger, Squid, Snail, Stag, Eel, Hound, Bat |

The longest phrase, such as *(Towering Violet Plated Badgers)*, is 30 characters, 32 with brackets. Example: *(Wiry Ochre Webbed Bats)*.

### 4.6 Ships and other objects

The type numbers and roles are RULES'. Names follow the owner's existing models: a registry code plus an animal, never a reptile or bird of prey. Alien craft take no animal names.

| Type | Role (RULES) | Name | Model now (recommended) |
| --- | --- | --- | --- |
| 1 | Small pirate fighter A | RTK-2 **Stoat** | Cheetah stand-in, rust tint |
| 2 | Police interceptor | MDN-6 **Mastiff** | Cheetah stand-in, police beacons (or the Grey Wolf, if choice 2 goes to b) |
| 3 | Small pirate fighter B | JRV-3 **Jackal** | Cheetah stand-in, rust tint |
| 4 | Heavy fighter (lone hunter) | ACNX-7 **Cheetah** | **Cheetah** (its own model) |
| 5 | Medium multi-role ship, hunter variant | LPX-9 **Grey Wolf**, hunter fit | **Grey Wolf** (choice 2a) |
| 6 | Alien mothership | **Hush carrier** | Cheetah stand-in, alien tint; the first new model worth making |
| 7 | Medium multi-role ship, trader variant; the player's hull | LPX-9 **Grey Wolf**, hauler fit | **Grey Wolf** (choice 2a) |
| 8 | Station | **Spindle** station | Simple dedicated model (drum and ring) |
| 9 | Missile | **Dart** missile | Simple dedicated model |
| 10 | Asteroid | Asteroid | Simple dedicated model |
| 11 | Cargo canister | Cargo crate | Simple dedicated model |
| 12 | Alien drone | **Hush mote** | Simple dedicated model, alien tint |
| 13 | Escape pod | **Lifeboat** | Simple dedicated model |

If the Grey Wolf is not used for types 5 and 7, those types keep the name *Grey Wolf* only if the owner wants the name without the model; otherwise the fallback name is OXN-4 **Ox**, hauler and hunter fit.

### 4.7 Goods, units and the law

Units are labels only (RULES A.11.2): **t** (tonnes) for items 0–12, which take hold space; **kg** or **g** for items 13–16, which take none. Items 3 and 6 are seriously illegal and item 10 mildly illegal, by position (RULES A.9.6). Items 0–7 are what a scooped crate can hold; a scooped lifeboat gives item 3; a scooped Hush mote gives item 16.

| Item | Name | Unit | Law | Made at | What it is |
| --- | --- | --- | --- | --- | --- |
| 0 | Grain | t | legal | farm worlds | Bulk food staple |
| 1 | Fibre | t | legal | farm worlds | Plant fibre for cloth and rope |
| 2 | Fertiliser | t | legal | factory worlds | Chemical feed that farm worlds import |
| 3 | Bonded sleepers | t | **serious** | farm worlds | People in stasis sold into indenture; also the occupant of a scooped lifeboat |
| 4 | Livestock | t | legal | farm worlds | Live animals in pens |
| 5 | Medicines | t | legal | factory worlds | Drugs and medical supplies |
| 6 | Lotus resin | t | **serious** | farm worlds | A banned sedative resin, smoked or chewed |
| 7 | Robotics | t | legal | factory worlds | Industrial and farm robots |
| 8 | Drive parts | t | legal | factory worlds | Engine and drive spares, the trade of used machines |
| 9 | Hull plating | t | legal | factory worlds | Armour and hull plate |
| 10 | Jammer kits | t | **mild** | factory worlds | Signal jammers, banned near stations |
| 11 | Hardwood | t | legal | farm worlds | Slow-grown timber, prized and pricey |
| 12 | Salvage | t | legal | everywhere | Scrap from old hulls |
| 13 | Iridium | kg | legal | everywhere | Precious metal; a store of value |
| 14 | Isotope vials | g | legal | factory worlds | Medical and research isotopes |
| 15 | Black pearls | g | legal | farm worlds | Gems from ocean worlds |
| 16 | Hush glass | kg | legal | (never on sale) | Glass from a Hush mote; sells best at factory worlds |

### 4.8 Equipment

Names for RULES' functional items (A.12.1), in the fixed order. Mount names and laser types are here too.

| Item | Function (RULES) | Name | HUD tag |
| --- | --- | --- | --- |
| 0 | Fuel | Tank refill | |
| 1 | Missile | Dart missile | |
| 2 | Hold extension | Cargo sponsons | |
| 3 | E.C.M. unit | Scrambler unit | `SCR` |
| 4 | Pulse laser | Repeater laser | |
| 5 | Beam laser | Lance laser | |
| 6 | Fuel scoop | Corona scoop | |
| 7 | Escape pod | Lifeboat | `BOAT` (always visible while fitted, RULES D.7) |
| 8 | Area blast | Nova charge | `NOVA` |
| 9 | Energy booster | Booster cells | |
| 10 | Auto-dock | Auto-berth | |
| 11 | Galaxy drive | Reach drive | |

Mounts (RULES A.7.1, keys 1–4): **Fore** `FWD`, **Aft** `AFT`, **Port** `PORT`, **Starboard** `STBD`. Laser types on the status screen: **Repeater** (pulse), **Lance** (beam).

### 4.9 Ranks, legal standing and condition

| Rank (RULES C.14) | Kills | Title |
| --- | --- | --- |
| 0 | 0–7 | Unblooded |
| 1 | 8–15 | Blooded |
| 2 | 16–31 | Scrapper |
| 3 | 32–63 | Brawler |
| 4 | 64–127 | Gunhand |
| 5 | 128–511 | Sharpshooter |
| 6 | 512–2,559 | Veteran |
| 7 | 2,560–6,399 | Ace |
| 8 | 6,400 or more | Living legend |

| Legal status (RULES C.15.1) | Value | Label | Icon (ART-BIBLE) |
| --- | --- | --- | --- |
| clean | 0 | Good standing | filled shield |
| offender | 1–49 | On notice | hatched shield |
| fugitive | 50+ | Outlawed | empty shield |

| Condition code (RULES D.6.2) | Meaning | Label | Colour (UI-DESIGN) |
| --- | --- | --- | --- |
| 0 | docked | Berthed | Gold |
| 1 | safe: nothing but planet, sun or station, asteroids | Quiet | Focus |
| 2 | caution: others present, energy ≥ 128 | Contact | Amber |
| 3 | danger: others present, energy < 128 | Danger | Danger |

### 4.10 Other names

| Role | Name | Notes |
| --- | --- | --- |
| The player | Pilot | The default name is **DRIFTER** (7 characters, RULES A.7.1) |
| Station | Spindle | Printed as *<system> Spindle* where space allows |
| Alien faction | The Hush | Carrier and mote as above |
| Mis-jump space | The Deep | The current-system name prints blank there (RULES D.3.8) |
| Currency | scrip, abbreviation **SC** | One decimal place, e.g. `1,240.5 SC`; productivity in *M SC* (millions) |
| Distance and fuel | light years, **LY** | One decimal place |
| Galaxy | Reach, numbered 1–8 | Names in § 4.3 |

## 5. New data values

Every value here is RULES **data**. The data-swapped parity baseline gets exactly these values.

### 5.1 Market (RULES A.9)

Price per unit is `4 × ((R & M) + B ± E·|F|)` tenths of a scrip, wrapping mod 256 before the ×4; availability is `((R & M) + Q ∓ E·|F|)` with the 128 and 63 rules. `R` is the market byte, `E` the economy 0–7.

| Item | Name | Unit | Base price `B` | Gradient `F` | Base quantity `Q` | Mask `M` |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | Grain | t | 30 | −3 | 12 | `0x03` |
| 1 | Fibre | t | 30 | −2 | 20 | `0x06` |
| 2 | Fertiliser | t | 34 | +3 | 30 | `0x03` |
| 3 | Bonded sleepers | t | 48 | −4 | 236 | `0x1E` |
| 4 | Livestock | t | 58 | −6 | 6 | `0x07` |
| 5 | Medicines | t | 120 | +6 | 44 | `0x0C` |
| 6 | Lotus resin | t | 180 | −14 | 188 | `0x1C` |
| 7 | Robotics | t | 132 | +10 | 46 | `0x0F` |
| 8 | Drive parts | t | 88 | +7 | 34 | `0x0F` |
| 9 | Hull plating | t | 64 | +2 | 28 | `0x0F` |
| 10 | Jammer kits | t | 100 | +11 | 40 | `0x0E` |
| 11 | Hardwood | t | 150 | −7 | 216 | `0x0F` |
| 12 | Salvage | t | 36 | +1 | 50 | `0x05` |
| 13 | Iridium | kg | 108 | +1 | 30 | `0x0F` |
| 14 | Isotope vials | g | 164 | +3 | 24 | `0x0F` |
| 15 | Black pearls | g | 66 | −2 | 16 | `0x1F` |
| 16 | Hush glass | kg | 140 | −9 | 0 | `0x0F` |

What these give, checked for every `R` (0–255) at both ends of the economy scale (prices in scrip):

| Item | Price at a wealthy factory world (E 0) | Price at a lean farm world (E 7) | Gap from end to end | Availability E 0 → E 7 |
| --- | --- | --- | --- | --- |
| Grain | 12.0–13.2 | 3.6–4.8 | 8.4 | 12–15 → 33–36 |
| Fibre | 12.0–14.4 | 6.4–8.8 | 5.6 | 20–26 → 34–40 |
| Fertiliser | 13.6–14.8 | 22.0–23.2 | 8.4 | 30–33 → 9–12 |
| Bonded sleepers | 19.2–31.2 | 8.0–20.0 | 11.2 | 0–10 → 8–38 |
| Livestock | 23.2–26.0 | 6.4–9.2 | 16.8 | 6–13 → 48–55 |
| Medicines | 48.0–52.8 | 64.8–69.6 | 16.8 | 44–56 → 2–14 |
| Lotus resin | 72.0–83.2 | 32.8–44.0 | 39.2 | none until E 3 → 30–58 |
| Robotics | 52.8–58.8 | 80.8–86.8 | 28.0 | 46–61 → none |
| Drive parts | 35.2–41.2 | 54.8–60.8 | 19.6 | 34–49 → none |
| Hull plating | 25.6–31.6 | 31.2–37.2 | 5.6 | 28–43 → 14–29 |
| Jammer kits | 40.0–45.6 | 70.8–76.4 | 30.8 | 40–54 → none |
| Hardwood | 60.0–66.0 | 40.4–46.4 | 19.6 | none until E 4 → 9–24 |
| Salvage | 14.4–16.4 | 17.2–19.2 | 2.8 | 50–55 → 43–48 |
| Iridium | 43.2–49.2 | 46.0–52.0 | 2.8 | 30–45 → 23–38 |
| Isotope vials | 65.6–71.6 | 74.0–80.0 | 8.4 | 24–39 → 3–18 |
| Black pearls | 26.4–38.8 | 20.8–33.2 | 5.6 | 16–47 → 30–61 |
| Hush glass | 56.0–62.0 | 30.8–36.8 | 25.2 | never on sale |

No price wraps round for any `R` and `E`, and no availability lands in the 64–127 band that RULES' 6-bit cut would fold back; the quirks stay in the rules but our data does not lean on them.

**Balance, and why.** The formulas make profit come from carrying a good from the end of the economy scale where it is cheap to the end where it is dear; the gap per unit is `2.8 × |F|` scrip from one end to the other, blurred by the per-visit fluctuation `R & M`. The table is built in tiers so that progression feels as it does in the rules' own economy:

- **First trips (100 SC, 22 t hold).** Grain, livestock and fibre are cheap at farm worlds and dear at factory worlds; fertiliser runs the other way. A first hold of grain from the starting farm world costs about 6 SC a tonne and sells for 10–13 SC at the factory worlds 3.6 to 5.2 light years away: the hundred scrip buys about 16 t, which nearly doubles your money per run, in tens of scrip, not hundreds.
- **Middle trade.** Medicines, drive parts and robotics are made at factory worlds and wanted at farm worlds, with gaps of 17–28 SC a tonne; a full hold of robotics costs over 1,100 SC, so you reach it only after a few runs. Hardwood and livestock fill the other direction, so a round trip pays both ways.
- **Contraband pays most.** Lotus resin has the widest gap of any legal or illegal tonne (39 SC) and jammer kits beat robotics (31 against 28 SC) while costing less, so crime is tempting. Bonded sleepers pay modestly but count double towards your record, as resin does; jammers count once. The fluctuation masks of the contraband are wider, so their prices swing more from visit to visit.
- **Hold-free goods.** Iridium, isotopes and pearls take no hold space, so they are limited only by availability and cash. They keep small gradients (2.8–8.4 SC) and modest stocks, so they are a place to park money and catch a good fluctuation, not a way round the hold.
- **Noise and drift.** Fluctuation masks use different bits of the market byte (`0x03`, `0x06`, `0x0C`, `0x1C`, `0x1E` and others), so items do not all rise and fall together on one visit. Staples move a little; high-value goods and contraband move a lot.
- **Hush glass** turns a fight in the Deep, or a scooped mote, into 30–60 SC a kilogram, best sold at a factory world.

### 5.2 Starting market (RULES A.9.7)

Owner decision: computed from the formula. The start pilot carries market byte `R = 0` and the availability list the formula gives for the starting system (economy 5):

| Item | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 | 14 | 15 | 16 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Available | 27 | 30 | 15 | 0 | 36 | 14 | 2 | 0 | 0 | 18 | 0 | 0 | 45 | 25 | 9 | 26 | 0 |
| Price (SC) | 6.0 | 8.0 | 19.6 | 11.2 | 11.2 | 60.0 | 44.0 | 72.8 | 49.2 | 29.6 | 62.0 | 46.0 | 16.4 | 45.2 | 71.6 | 22.4 | 38.0 |

Both rows are test vectors for the implementation. (Two tonnes of lotus resin are on sale on day one: an early temptation, on purpose.)

### 5.3 Equipment prices and the fuel price (RULES A.12)

Tech gating is a rule: a system with internal tech level `T` offers the first `min(T + 3, 12)` items, so each item's lowest shown tech level follows from its position. Prices are ours.

| Item | Name | Price (tenths) | Price (SC) | Offered from shown tech level |
| --- | --- | --- | --- | --- |
| 0 | Tank refill | `(70 − fuel) × 3` | up to 21.0 | 1 (always) |
| 1 | Dart missile | 350 | 35.0 | 1 (always) |
| 2 | Cargo sponsons | 3,600 | 360.0 | 1 (always) |
| 3 | Scrambler unit | 5,600 | 560.0 | 2 |
| 4 | Repeater laser | 3,200 | 320.0 | 3 |
| 5 | Lance laser | 9,600 | 960.0 | 4 |
| 6 | Corona scoop | 4,800 | 480.0 | 5 |
| 7 | Lifeboat | 8,800 | 880.0 | 6 |
| 8 | Nova charge | 7,600 | 760.0 | 7 |
| 9 | Booster cells | 13,600 | 1,360.0 | 8 |
| 10 | Auto-berth | 12,400 | 1,240.0 | 9 |
| 11 | Reach drive | 45,000 | 4,500.0 | 10 |

- **Fuel price:** 3 tenths of a scrip per tenth of a light year, so a full 7.0 LY tank costs 21.0 SC. Fuel is a real cost on the first runs and negligible later, as in the rules' own balance.
- A lance laser replacing a repeater refunds the repeater's 320.0 (RULES A.12.3), so the upgrade costs 640.0 net.
- The order of purchase this pricing suggests: missiles and sponsons first (cheap safety and +15 t), then the scrambler, corona scoop and lifeboat, then the lance laser, then the expensive conveniences; the Reach drive is a deliberate goal.

### 5.4 The start pilot (RULES A.7.1)

| Field | Start value |
| --- | --- |
| Name | DRIFTER |
| Position | (60, 93): system 0 of Reach 1 (§ 4.2) |
| Galaxy state and number | `5D38 3CAC 0E31`, Reach 1 (internal 0) |
| Cash | 1,000 tenths (100.0 SC), RULES' value kept |
| Fuel | 70 (7.0 LY, full) |
| Lasers | Repeater on Fore; none on Aft, Port, Starboard |
| Hold | 22 t, empty |
| Missiles | 3 Darts |
| Other equipment | none |
| Legal status, kills | 0, 0 |
| Market byte and availability | `R = 0` and the list in § 5.2 |

### 5.5 Ship stats (RULES C.3.2)

One record per type. Damage per enemy hit is `laser × 4 + floor(missiles / 2)` (RULES C.5.3). Bounties are in tenths of a scrip. Hit size is the square of the sights radius in sim units; the radius in metres is at 0.2 m per unit.

| Type | Name | Canisters | Hit size (radius) | Bounty | Energy | Top speed | Laser | Missiles | Damage per hit |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | Stoat | 1 | 2,500 (50; 10.0 m) | 60 (6.0 SC) | 64 | 36 | 3 | 0 | 12 |
| 2 | Mastiff | 0 | 4,096 (64; 12.8 m) | 0 | 120 | 34 | 3 | 2 | 13 |
| 3 | Jackal | 0 | 3,600 (60; 12.0 m) | 120 (12.0 SC) | 96 | 31 | 2 | 1 | 8 |
| 4 | Cheetah | 7 | 9,216 (96; 19.2 m) | 240 (24.0 SC) | 230 | 22 | 4 | 4 | 18 |
| 5 | Grey Wolf, hunter fit | 3 | 6,724 (82; 16.4 m) | 0 | 160 | 26 | 2 | 2 | 9 |
| 6 | Hush carrier | 0 | 10,816 (104; 20.8 m) | 450 (45.0 SC) | 250 | 33 | 3 | 5 (motes) | 14 |
| 7 | Grey Wolf, hauler fit | 3 | 6,724 (82; 16.4 m) | 0 | 160 | 26 | 2 | 2 | 9 |
| 8 | Spindle station | 0 | 22,500 (150; 30.0 m) | 0 | 220 | 0 | 0 | 0 | — |
| 9 | Dart missile | 0 | 1,024 (32; 6.4 m) | 0 | 4 | 42 | 0 | 0 | (250 on impact, a rule) |
| 10 | Asteroid | 0 | 5,776 (76; 15.2 m) | 8 (0.8 SC) | 72 | 24 | 0 | 0 | — |
| 11 | Cargo crate | 0 | 484 (22; 4.4 m) | 0 | 24 | 12 | 0 | 0 | — |
| 12 | Hush mote | 0 | 1,296 (36; 7.2 m) | 40 (4.0 SC) | 28 | 32 | 1 | 0 | 4 |
| 13 | Lifeboat | 0 | 324 (18; 3.6 m) | 0 | 16 | 6 | 0 | 0 | — |

**Presentation-only fields.** RULES C.3.2 also lists gun point, explosion points, dot distance, normal scale and the model. They feed the original's line renderer only; since decision 1 moved every cosmetic draw to the cosmetic generator, none of them reaches the sim or the main generator. In LodeStar the gun point is the rig's `muzzle_N` marker, explosion points become the debris chunks of ART-BIBLE § Effects, dot distance becomes the model's far LOD (an impostor beyond 6,000 m), normal scale does not exist, and the model is the one in § 4.6. The parity baseline may keep whatever it has for them.

**Relationships kept** (RULES C.3.2 and C.5):

- Canister counts are 0, 1, 3 or 7 (`2ⁿ − 1`), so the mask on a random byte spreads evenly; types above 7 have 0.
- Bounty is 0 for the police (2) and the traders (7). Type 5 uses the same record and model as type 7, as RULES states, so a hunter-fit Grey Wolf pays no bounty either.
- The station's top speed is 0. The Dart's top speed (42, so 63 units a tick) is above the player's 40 × 2/3. Police (34) outrun traders (26). The lifeboat (6) is the slowest thing that moves.
- The Dart's hit size (1,024) is above 784, so the own-missile quirk (RULES C.17 item 6) stays live, as in the baseline: a careless shot can still hit your own Dart in its first moments.
- All lasers are within 0–31 and all missile counts within 0–7.

**Each change and its intent.**

| Type | Intent |
| --- | --- |
| Stoat | Fast, fragile, stings: the quickest raider, dies to five shots, hits harder than its size; sometimes drops a crate, so the first kills pay a little. |
| Mastiff | The patrol dog: faster than any trader, sturdy, carries two Darts; never worth fighting for money (no bounty). |
| Jackal | The middle raider: tougher than a Stoat, slower, one Dart, a softer gun; worth twice a Stoat's bounty. |
| Cheetah | A slow, heavily armed heavy fighter: big target, tough, the hardest hitter in human space, four Darts (matching the model's four bays and visible missiles), and up to seven crates when it dies. Running away from it works; trading shots does not. |
| Grey Wolf | The everyday working hull: middling in everything, two Darts, up to three crates when a hauler is shot down. |
| Hush carrier | Big, tough and fast for its size, launches up to five motes when hurt; the richest bounty, which the Deep never pays (RULES C.16.6). |
| Spindle station | Energy only matters for being reduced to 0; it never moves, fires or launches Darts. |
| Dart missile | Fast enough to catch anything, dies to one laser hit. |
| Asteroid | Slower than before so rocks are easier to avoid and to shoot; a token bounty. |
| Cargo crate | Drifts slowly so scooping is a skill, not a chase. |
| Hush mote | A weak gun and little energy; dangerous only in numbers. |
| Lifeboat | Very slow and small: catchable, but hard to hit. |

**Model scale.** DESIGN's per-role target boxes predate these stats. In the art phase each model is scaled so that its cross-section seen along the mount axis is about the hit radius above (a hit in the sim should look like a hit), and DESIGN § Ships is updated to match.

## 6. Player experience

- **Who:** desktop players who like systemic games with long-term goals: fans of the 1984 game who want it with a modern face, and newcomers to space trading who want something smaller and sharper than a modern simulation.
- **On what:** a Windows, macOS or Linux computer, keyboard and mouse, 1280×720 or larger.
- **How long:** sessions of 20–60 minutes, a game of many sessions. A run between two dockings takes 2–10 minutes.
- **The arc of a session:** docked in a hangar, you study the market and the chart, buy a hold, launch into the safe zone, fly clear of the station and jump. The countdown is the tense part: seven seconds in which anything can arrive. In the new system you hop towards the planet, fight or flee whatever spawns, find the Spindle, line up with its slot and dock. Profit, a save, an upgrade, and again.
- **Why play again:** money and equipment grow; the rank ladder runs from Unblooded to Living legend; eight Reaches wait behind the Reach drive; the law follows choices about contraband and police; and death, which sends you back to your last save, keeps every flight worth caring about.

## 7. Core loop

A player's-eye summary; RULES is the authority and nothing here adds a rule.

1. **Docked** (RULES D.3.3): look at the market, the Reach and local charts, system data and your status; buy and sell goods (A.10); buy equipment (A.12); save (A.8). The market byte stays the same until you next arrive somewhere by jump (A.9.2).
2. **Launch** (D.3.5): the launch tunnel, then flight with the Spindle behind you, inside the safe zone (B.11). Any contraband aboard is added to your record as you leave (C.15.2).
3. **Fly** (B.5–B.7, D.3.6): roll, pitch and speed; pick the active mount 1–4 and fire its laser; arm, lock and fire Darts; scrambler, nova charge and lifeboat when fitted (C.6–C.10). Leave the safe zone before jumping.
4. **Jump** (A.5, B.16): select a system within fuel range on a chart, start the 85-tick countdown, survive it, ride the tunnel. Three times in 256 the jump drops into the Deep and the Hush (B.16.5). Arrival draws a new market and halves your record (A.5.6).
5. **Approach** (B.13–B.15): hop towards the planet when nothing else is near, skim a star with a corona scoop for fuel, scoop crates and lifeboats from below, fight what the periodic spawn brings (C.16).
6. **Dock** (B.12): match the Spindle's slot by hand, or use the auto-berth; the docking tunnel; back to step 1.
7. **Die** (D.3.10): crash, burn, misjudge a docking or run out of energy, and the game returns to the title with your last saved pilot.

Long loops: kills raise your rank (C.14); legal standing falls only by jumping, a Reach jump or a lifeboat rescue (C.15); the Reach drive moves you to the next Reach (A.5.7).

## 8. Screen list

From UI-DESIGN. The wireframe phase covers exactly this list. *Extra* marks what the remake adds beyond RULES' screens (D.6).

| id | Purpose | Reached from | RULES mode / screen, or extra |
| --- | --- | --- | --- |
| `title` | Title flyby and menu: New pilot, Continue, Load pilot, Options, About | start-up; death; Quit to title | Title (D.3.1, D.6.8) |
| `load` | Pick or type a saved pilot's name; import from file | title | Name prompt (D.6.12) |
| `about` | Credit line, licences, how to play | title | extra |
| `options` | Graphics, Audio, Controls (rebinding), Camera, Interface; also RULES' pause toggles (auto-centre, damping, warning pulse) | title; pause | extra (pause toggles are D.3.12) |
| `pause` | Resume, Options, Controls, Quit to title (confirm) | `Esc`/`P` in flight or docked | Pause (D.3.12) |
| `flight` | The 3D scene and the HUD | launch; arrival | Space view (D.6.1), HUD (D.7, D.8) |
| `hub.market` | Buy and sell goods | docking; title | Buy, sell, market (D.6.4, D.6.9, D.6.10) |
| `hub.equip` | Buy equipment; the mount picker for lasers | hub | Equip (D.6.11) |
| `hub.galaxy` | The Reach chart | hub; `G` in flight | Galaxy chart (A.6.1, D.6.6) |
| `hub.local` | The local chart | hub; `L` in flight | Local chart (A.6.2, D.6.7) |
| `hub.system` | System data with the rendered planet | hub; `I` in flight | System data (D.6.5) |
| `hub.pilot` | Status, equipment, save | hub; `V` in flight; entering the docked state | Status (D.6.2); save (A.8.2) |
| `hub.hold` | Fuel, cash and cargo | hub; `Y` in flight; after buying | Inventory (D.6.3) |
| `flight.prices` | Market prices, read-only, over the flight view | `O` in flight | Market (D.6.4) |
| `save` | Name a save (docked only) | `hub.pilot` | Name prompt (D.6.12) |
| `tunnel.launch` | Bay tunnel, 16 ticks | Launch | Tunnel (D.3.4) |
| `tunnel.dock` | Bay doors close, 16 ticks | docking | Tunnel (D.3.4) |
| `tunnel.jump` | Star tunnel, 16 ticks | countdown ends | Tunnel (D.3.4) |
| `tunnel.ambush` | Green-tinted tunnel breaking off into the Deep | mis-jump | Tunnel, then ambush (D.3.8) |
| `escape` | The lifeboat launches; your old hull drifts away, 97 ticks | lifeboat used | Escape (D.3.9) |
| `death` | The explosion, 61 ticks, then the epitaph panel | death | Death (D.3.10, D.6.14); epitaph is extra |
| `focus-lost` | Paused card when the window loses focus | any | extra |

## 9. Text budget

Final words come in the UI-design phase, written fresh to these budgets and checked with `overlap.py`. The RULES budget is the target; *LodeStar max* is the hard limit its layout allows. Placeholders are in braces. Tone is UI-DESIGN's voice unless noted: terse, plain, a little dry.

### 9.1 In-flight messages (the ticker; RULES D.9.1)

| id | RULES | When | Conveys | Budget (RULES / max) | Placeholders | Tone |
| --- | --- | --- | --- | --- | --- | --- |
| `msg.scoop_fuel` | M1 | each scoop check while skimming a star with the corona scoop | fuel is being drawn in, even if none was gained | 16 / 40 | | matter-of-fact |
| `msg.energy_low` | M2 | energy < 50, every 32 ticks | energy banks nearly empty; act now | 14 / 40 | | urgent (Danger tint) |
| `msg.kill_milestone` | M3 | every 256th kill | grudging respect for a long record | 20 / 40 | | dry praise, may use `!` |
| `msg.missile_in` | M4 | a ship launches a Dart at you | a missile is coming at you | 18 / 40 | | urgent (Danger tint) |
| `msg.missile_jammed` | M5 | fire with a full bubble | the Dart could not launch; lock kept | 16 / 40 | | flat |
| `msg.target_lost` | M6 | the locked target leaves | the lock is gone | 14 / 40 | | flat |
| `msg.reach_jump` | M7 | a Reach jump starts | you are leaving this Reach (now shown, decision 11) | 22 / 40 | | quiet gravity |
| `msg.bounty` | M8 | a bounty is paid | the new cash total | 14 / 40 | `{cash}` (9 incl. one decimal) + ` SC` | flat |
| `msg.scooped` | M9 | something is scooped into the hold | what you gained | 14 / 40 | `{goods}` | flat |
| `msg.cargo_lost` | M10 | damage destroys a cargo stack | which cargo was destroyed | 22 / 40 | `{goods}` + suffix | flat, bad news |
| `msg.equipment_lost` | M11 | damage destroys equipment | which equipment was destroyed | 24 / 40 | `{equipment}` + suffix | flat, bad news |

### 9.2 Notices and prompts (RULES D.9.2, A.13, B.21)

| id | RULES | When | Conveys | Budget (RULES / max) | Placeholders | Tone |
| --- | --- | --- | --- | --- | --- | --- |
| `note.jump_target` | N1 | a jump countdown starts | where you are jumping to | 22 incl. an 8-letter name / 40 | `{system}` | flat |
| `note.out_of_range` | N2 | target beyond fuel | the target is too far for your fuel | 18 / 40 | | flat |
| `note.docked` | N3 | jump key while docked | you cannot jump while berthed | 10 / 24 | | flat |
| `note.distance` | N4 | distance key on a chart | the selected system and its distance (distance omitted if 0) | 24 / 40 | `{system}`, `{ly}` | flat |
| `note.countdown` | N5 | countdown running | seconds-like count 15 → 1 | 5 | `{n}` | figure only |
| `note.death` | N6 | death sequence | the end of this pilot | 10 / 16 | | quiet, final |
| `title.banner` | N7 | title | the game's title | 24 | | — |
| `title.credit` | N8, N11 | About; title footer | the credit line of § 1, shortened for the footer | 30 for the footer; full line on About | | factual |
| `title.menu` | N9, N10 | title | New pilot, Continue, Load pilot, Options, About | 14 per item | | plain |
| `prompt.name` | N12 | save or load | type a pilot name (7 letters or digits) | 22 | | plain |
| `prompt.quantity` | N13 | buying | how many of this item | 28 incl. name / 40 | `{goods}`, `{unit}` | plain |
| `err.too_many` | N14 | more than available | not that many on sale | 10 / 20 | | flat |
| `err.no_room` | N15 | no hold space | the hold cannot take it | 10 / 20 | | flat |
| `err.no_cash` | N16 | not enough cash | you cannot afford it | 8 / 20 | | flat |
| `note.cash_left` | N17 | after a purchase | cash remaining | 20 / 30 | `{cash}` | flat |
| `prompt.sell` | N18 | selling, per held item | sell the whole stack? | 12 / 24 | | plain |
| `prompt.item` | N19 | equip shop | choose an item | 8 / 24 | | plain |
| `err.fitted` | N20 | refused purchase | this item is already fitted, or the rack is full | 24 incl. name / 40 | `{equipment}` | flat |
| `prompt.mount` | N21 | buying a laser | which mount | 12 per line | mount names | plain |
| `note.galaxy_title` | A.13 | Reach chart open | the Reach's name and number | 20 / 30 | `{reach}`, `{n}` | label |
| `note.local_title` | A.13 | local chart open | the local chart's title | 20 / 30 | | label |

### 9.3 Labels and lists

| id | Holds | Budget | Source |
| --- | --- | --- | --- |
| `label.goods[0..16]` | goods names | 18 | § 4.7 |
| `label.unit[t, kg, g]` | units | 2 | § 4.7 |
| `label.equipment[0..11]` | equipment names | 18 (shop line), 22 (panel) | § 4.8 |
| `label.mount[0..3]`, `label.mount_tag[0..3]` | mount names, HUD tags | 9; 4 | § 4.8 |
| `label.laser[pulse, beam]` | laser types | 8 | § 4.8 |
| `label.economy[0..7]` | economy lines | 24 | § 4.4 |
| `label.government[0..7]` | government labels | 14 | § 4.4 |
| `label.inhabitants` | the five lists | 32 for the whole phrase with brackets | § 4.5 |
| `label.rank[0..8]` | rank titles | 14 | § 4.9 |
| `label.legal[0..2]` | legal labels | 14 | § 4.9 |
| `label.condition[0..3]` | condition labels | 8 | § 4.9 |
| `label.ship[1..13]` | ship names for assist brackets | 14 | § 4.6 |
| `label.reach[0..7]` | Reach names | 12 | § 4.3 |
| `label.data[...]` | system data labels: distance, economy, government, tech level, population, inhabitants, productivity, radius, with units | label + value within 40 | RULES A.13, D.6.5 |
| `label.market_headings` | item, price, available, in hold | 30 | RULES A.13 |

### 9.4 Text the remake adds

| id | When | Conveys | Budget | Placeholders | Tone |
| --- | --- | --- | --- | --- | --- |
| `ui.system_blurb` | system data panel | two lines composed only from the system's data (economy, government, tech, inhabitants); no new rule | 2 × 70 | the data fields | travel-guide dry |
| `ui.equip_effect[0..11]` | equip panel | what each item does, from RULES' effect | 60 | | plain |
| `ui.epitaph` | death panel | how you died, from the cause (crash, star, docking, fire, the Deep, lifeboat in the Deep) | 60 | `{cause}`, `{rank}`, `{kills}` | quiet, a little wry |
| `ui.key_hints` | first three launches | mount, target and fire keys | 60 | key names | plain |
| `ui.lifeboat_badge` | while a lifeboat is fitted | the always-visible indicator RULES D.7 requires | 4 | | badge |
| `ui.option.*` | options | settings names, including the three pause toggles | 24 each | | plain |

## 10. Audio

All new: synthesised or recorded for LodeStar, no melody associated with the original or its genre (ART-BIBLE § Sound palette). The *RULES cue* column keeps every trigger of RULES D.11; one cue may play different sounds by context, but it always plays when RULES says.

| id | RULES cue | Trigger | Purpose / mood | Length | Character |
| --- | --- | --- | --- | --- | --- |
| `sfx.laser.own` | S1 | your laser fires | your shot | 0.15 s; lance: loop while firing | bright filtered zap, quick pitch drop; lance a steady buzz |
| `sfx.laser.hostile` | (with S2) | an enemy beam is drawn | someone is shooting | 0.2 s | lower and harsher, panned from the shooter |
| `sfx.hit.shield` | S2 | an enemy laser hits you (silent while a scrambler pulse runs) | your shield took it | 0.2 s | glassy ping, higher fore than aft |
| `sfx.hit.hull` | S3 | damage reaches energy; collision; scoop refused; Dart hits you; death | it got through | 0.5 s | dull metallic thunk with crackle |
| `sfx.explode` | S4 | death; your laser hits a ship (quieter); a kill (quieter) | something broke | 1.5 s | sub-bass thump, crackling tail, debris ticks |
| `sfx.beep` | S5 | lock-on; option toggles; each shop pause | acknowledged | 0.1 s | short high tone |
| `sfx.refuse` | S6 | unarm; hop refused | no | 0.25 s | short low tone |
| `sfx.launch` | S7 | launch and dock tunnels; your Dart fired; incoming Dart; lifeboat | movement through the bay or out of a tube | 1–2 s | air whoosh; bay doors clank for Darts |
| `sfx.jump` | S8 | jump or Reach-jump tunnel starts | leaving the system | 2 s | long rising drone cut to silence on arrival |
| `sfx.scrambler` | S9, S10 | a scrambler pulse starts / ends | jamming in progress | loop | rising electronic sweep into a warble; stops at S10 |
| `sfx.engine` | — | always in flight | your ship is alive | loop | low hum and soft harmonic; pitch with speed |
| `sfx.lock_tone` | — | a Dart is seeking or locked | missile state | loop | tone that quickens as it closes |
| `amb.hangar` | — | docked | safety | loop | muffled machines, ventilation hum |
| `ui.move`, `ui.confirm`, `ui.deny` | — | panel navigation | UI feedback | ≤ 0.2 s | soft click; two-note gold chime; muted buzz |
| `mus.title` | — | title and hangar | arrival, calm | 2–3 min loop | slow ambient pad motif |
| `mus.danger` | — | condition Danger | pressure | loop | low pulse that rises with Danger; otherwise no music in flight |

## 11. Platforms and controls

- **Platforms:** Windows (x86-64), macOS (universal), Linux (x86-64); desktop builds from Godot 4.7 with godot-rust. Offline; no account. No web build, no phones, no touch, no gamepad in the first release (the action layer allows one later).
- **Display:** 1280×720 minimum, designed at 1920×1080, scaled to the window height; ultrawide keeps the HUD in a 16:9 safe area.
- **Controls:** keyboard and mouse, two built-in layouts (Modern, the default; Classic, on the 1984 machine's key positions), every action remappable (DESIGN § Keyboard controls). RULES' structure is kept: held controls (pitch, roll, speed, fire) are sampled once per tick; one-shot actions are queued for the next tick and never lost; key repeat is ignored; tunnels, death and the lifeboat sequence discard input; losing window focus releases held keys and pauses.

| Action | Modern | Classic |
| --- | --- | --- |
| Dive / climb | `W` / `S` | `S` / `X` |
| Roll left / right | `A` / `D` | `,` / `.` |
| Faster / slower | `R` / `F` | `Space` / `/` |
| Fire the active mount | `Space` | `A` |
| Active mount Fore / Aft / Port / Starboard | `1`–`4` | `1`–`4` |
| Target / fire / unarm Dart | `Q` / `E` / `Z` | `T` / `M` / `U` |
| Scrambler, nova charge | `C`, `B` | `E`, `Tab` |
| Lifeboat | hold `Backspace` 1 s (or toggle, Options) | same |
| Hop, auto-berth | `J`, `K` | `J`, `C` |
| Jump / Reach jump | `H` / `Shift`+`H` | `H` / `Shift`+`H` |
| Reach chart, local chart, system, prices, pilot, hold | `G` `L` `I` `O` `V` `Y` | `5` `6` `7` `8` `9` `0` (also `F5`–`F10`) |
| Chart cursor, distance, home | arrows, `Enter`, `Home` | same |
| Camera orbit, zoom, reset, mode | arrows or right-drag; `+`/`−` or wheel; `Home`; `\` | arrows or right-drag; `[`/`]` or wheel; `Home`; `\` |
| Pause | `Esc` or `P` | `P` or `Esc` |

## 12. Accessibility

- **Flashing:** nothing faster than 3 Hz; the nova charge's whiteout fades in over 80 ms; RULES' danger-bar flash (8 ticks on, 8 off, about 0.75 Hz) is a pulse that the warning-pulse option turns steady.
- **Colour never alone:** hostile marks are broken brackets, police strobes blink in pairs, warnings add a pulse and an icon, legal standing has three icon shapes, conditions have words as well as tints. A colour-blind option adds letters to scanner contacts and swaps the green/red laser pair for cyan/orange.
- **Contrast:** text at least 4.5:1 against glass over the sun's halo; gold labels at least 3:1.
- **Timing:** nothing in the docked state is timed except RULES' one-second shop pause; the sim freezes on pause and on focus loss; the lifeboat hold can be a toggle; tunnels can be skipped visually (`Enter`) after the first time without changing tick timing.
- **Sound:** no information is carried by sound alone; every sound with a meaning (lock-on, incoming Dart, hits, scrambler) has a visible counterpart on the HUD or the ticker.
- **Motion:** a reduced-motion option cuts transitions, camera shake and lens ghosts.
- **Scale:** UI scale up to 150%; HUD figures never below 14 px at 100%.
- **Screen readers:** panels expose the selected row and the latest ticker message where Godot's accessibility support allows; until then, an optional text-to-speech voice reads them.

## 13. Scope and non-goals

**In scope:** everything in RULES, at parity; the screens of § 8; the Cheetah and Grey Wolf models plus simple models for the station, Dart, crate, asteroid, lifeboat and mote; a Hush carrier model before release; saves with export and import.

**Not in scope:**

- **No web build and no phones or touch.** Desktop only (owner decision).
- **No rule changes** beyond RULES' deliberate differences. Ideas that would change rules (heat damage, asteroid fragments, partial sales, a fixed planet-vector drift, the AI's roll sign) are open questions for play-testing, logged in RULES first if ever adopted.
- **No new content the rules lack:** no missions, no extra ship types, no military or mining lasers, no generated planet stories beyond `ui.system_blurb`, which only rephrases the data.
- **No difficulty modes, no autosave, no saving in flight.**
- **Multiplayer is later,** through the hybrid design: the same Rust sim as an authoritative headless server, the client predicting with its own copy. Nothing in the single-player game may assume the sim lives beside the picture.

## 14. Risks

| Risk | Likelihood | Mitigation |
| --- | --- | --- |
| A generated system name happens to match one of the original's | Medium: 2,048 short names from two-letter groups | The verify role runs `overlap.py` with the original's names as `--names` over a dump of all 2,048 names; any hit is fixed by a different starting state, not by hand-editing |
| An invented name echoes the original or another space game (ships, goods, governments, ranks) | Low | Names were built from new themes (mammal registries, frontier guild money, the Hush); the verify role's overlap check and guard test cover them; the owner reviews this list |
| The title *LodeStar* is a common word and used by other products | High | Treat it as a working title until a trademark search; two alternatives are ready |
| Contraband themes (bonded sleepers, lotus resin) read as glorifying trafficking or drugs | Medium | Plain, unglamorous wording; no jokes; the law punishes them; the owner decides (choice 4) |
| UI-DESIGN's market stepper and equip panel differ from RULES' prompt flows (A.10, D.6.9–D.6.13): number-entry quirks, whole-stack selling, the item-by-item buy order | High: a design gap now | Before wireframes, the owner decides: either the sim commands keep RULES' validations and the stepper is a recorded deliberate difference in RULES, or the panels drive the prompt flows. Selling stays whole-stack either way unless RULES changes |
| The third-person camera makes fights easier (you see behind you) | Medium | Rules unchanged; play-test, then decide; any retune is logged here and in RULES |
| The new stats or market make the game easier or harder than intended | Medium | Values were checked against the formulas (§ 5); play-testing may retune data only, logged in this decision log, and the parity baseline gets the same data |
| One shared point in Reach 6 hides a system from the chart search | Low impact | RULES' tie rule decides; accepted as data |
| Parity drift between the TypeScript baseline and the Rust sim | Medium | Data-swapped traces with a per-tick hash; stop at the first difference (DESIGN § Testing) |

## 15. Decision log

| Date | Decision | By |
| --- | --- | --- |
| 8 Nov 2026 | Working title **LodeStar**, slug `lodestar`; the GDD phase confirms the title | Owner |
| 8 Nov 2026 | The galaxy, market, ship stats, text and names are all new before the first push; the repository is public, builds private until release | Owner |
| 8 Nov 2026 | Third-person, EVE-style orbit camera with a limited zoom (1.5×–5× ship length), space-anchored by default; four mounts, the player picks the active one | Owner |
| 8 Nov 2026 | The ACNX-7 Cheetah takes the heavy fighter role and stands in for every other ship until more models exist | Owner |
| 8 Nov 2026 | The sim in **Rust**, presented through **Godot 4** with **godot-rust** | Owner |
| 8 Nov 2026 | **Desktop only** (Windows, macOS, Linux); the web build removed from scope | Owner |
| 8 Nov 2026 | **Hybrid**: single-player embeds the sim; a later multiplayer server runs the same sim as the authority | Owner |
| 8 Nov 2026 | Source **layered** after the diagrams essay (use cases → features → capabilities, with infrastructure, presentation and hosting around them) | Owner |
| 8 Nov 2026 | RULES approved, with the spec's recommendation on all twelve decisions (below) | Owner |
| 8 Nov 2026 | RULES 1: a separate cosmetic random generator; the main generator keeps the 54 and 9 view-independent stardust draws as discarded draws | Owner |
| 8 Nov 2026 | RULES 2: keep the galaxy generator's mechanics with a new starting state and new syllables | Owner |
| 8 Nov 2026 | RULES 3: dying cancels a running hyperspace countdown | Owner |
| 8 Nov 2026 | RULES 4: retargeting during a countdown is range-checked; fuel never goes negative | Owner |
| 8 Nov 2026 | RULES 5: the escape pod launches safely (the abandoned hull is left out of collisions on the launch tick) | Owner |
| 8 Nov 2026 | RULES 6: the missile lock uses the active mount's axis | Owner |
| 8 Nov 2026 | RULES 7: firing and locking need the flight scene; not with a panel open | Owner |
| 8 Nov 2026 | RULES 8: keep the planet-vector shrink for parity; revisit in play-testing | Owner |
| 8 Nov 2026 | RULES 9: keep the AI's roll-steering sign for parity; revisit in play-testing | Owner |
| 8 Nov 2026 | RULES 10: hold sizes (22 and 37) and laser power stay rules; the fuel price is data | Owner |
| 8 Nov 2026 | RULES 11: visual-only defects are done properly (beam lines, the Reach-jump message, a chart kept across a jump, condition labels in order) | Owner |
| 8 Nov 2026 | RULES 12: saves in a LodeStar format with the baseline's accept and reject behaviour | Owner |
| 8 Nov 2026 | The starting market is computed from the formula, not stored | Owner |
| _pending_ | Title; the Grey Wolf's role; tone; the captives cargo; currency (Open choices) | Owner |
| _pending_ | This GDD's names and data (§ 4, § 5) | Owner |
| _pending_ | Market stepper versus RULES' prompt flows (Risks) | Owner |
