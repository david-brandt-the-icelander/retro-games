# Dictator remake (working title): game design document

Status: draft · Phase 2 of `create-retro-game` · written by the designer from `docs/RULES.md` · Owner approval: _pending_

This document decides what the remake *is*: its name, its world, its voice, its screens and its sounds. `RULES.md` decides what it *does*, and nothing here changes a rule. Where this document mentions a number, a draw or an order, RULES is the authority.

It contains no text from the original game and none of its invented names. Any old → new name mapping is kept in the private repository only, never here.

## 1. Identity

- **Working title:** *Dictator remake* (until the owner chooses).
- **Title proposals**, each with a one-line pitch:

| # | Title | Pitch |
|---|---|---|
| 1 | ***President for Life*** | You've promised to rule forever; the army, the peasants, the landowners and the treasury have other plans. |
| 2 | ***Tinpot*** | A pocket-sized autocracy with an empty treasury, three restless factions and a helicopter on the roof, if you can afford one. |
| 3 | ***One More Month*** | Grant, refuse, bribe and borrow your way through another month in the palace; the only prize is a better score at your funeral. |
| — | *Dictator* (the original's title) | Possible if the owner accepts the risk. It is a common English word, so it is a weak mark, but it is still the name most associated with the 1983 game, so it signals "the same game" more strongly than anything else, and invites confusion with the original's rights holders. |

  My recommendation is ***Tinpot***: it is short (6 letters, fits large lettering in 32 columns), it names the satire's target exactly, and it is not a word anyone would expect to own. *President for Life* is the stronger pitch but the more likely to collide with other games and books; check before choosing (see §13).
- **Credit line** (fixed, used as written in the README and the About screen):
  "Inspired by *Dictator* (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders."

## 2. Pillars

1. **Plays the same, looks new.** Every rule, number, check order, random draw and input quirk in RULES is kept exactly; every word, name, screen, picture and sound is our own. When the two pull apart, the rules win and the look gives way.
2. **Satire of tin-pot autocracy.** The joke is always on the President and the regime: the vanity, the greed, the paranoia, the helicopter on the roof. Never on a people, a region or a culture. Deadpan official voice; the humour comes from the gap between the pomp and the panic.
3. **Short, repeatable sessions.** A reign lasts 5–20 minutes and usually ends badly. Every screen should be quick to read and quick to answer, so the next attempt starts within seconds.
4. **The Spectrum feel.** A 32×24 grid of 8×8 cells, two colours per cell, a coloured border, beeper sound, one key per prompt. Constraints are the style; we don't sneak in modern effects.

## 3. Same and new

This is the contract the later phases check against.

| Kept (functional, from RULES) | Renewed (expression, ours) |
|---|---|
| The eight groups, their order, their starting popularity and strength (RULES §1) | All on-screen text: about 75 messages, the 24 requests, 19 decisions and 6 headlines, the how-to-play pages |
| The treasury, costs, Swiss account, bodyguard strength, helicopter and loans (§2) | The player's country, its adjective, the bordering state and its people, the export crop, in-world nicknames (§4 below) |
| The monthly thresholds and their hidden/shown status (§3) | The title (§1) and the title screen |
| The month's 15 steps in their order, and the plot checks between them (§4) | Every screen layout (wireframes, phase 3); none recreates the original's designs |
| Accounts, plots, reports, audience, decisions, assassination, war, news, revolution, escape, rating: every rule and formula (§5–§14) | Colours per screen, icons, portraits and all pixel art (art bible, phase 4) |
| All data numbers in RULES §17 and their order | All tunes and effect patterns (§9 below); the funeral music |
| The random generator, its seeding and the exact order of draws (§15.4) | The font (our own, from the web template) |
| Input semantics: one key per prompt, only Y means yes, any other key means no or next, 1–5 menu, 1–6 help with other keys ignored (§15.1) | The code: a new engine written from RULES only |
| Integer arithmetic, clamping, ≤/≥ comparisons and the −1/0/+1 swings (§15.2) | The About screen, which replaces any credit screen; there is **no** intro screen imitating a publisher credit |
| Pacing: which screens wait for a key and the minimum time of each timed screen (§15.5); we may lengthen, never shorten | The how-to-play pages, written fresh from RULES |
| The quirks: the newsflash repeats the last costed item's money (§9.4, an open decision); a request can be skipped when the used marks reset (§8.1); unlimited bodyguards; the unreachable "no more loans" result still has its message | Touch keypad, responsive layouts, screen-reader text, sound toggle (additions that don't change the game) |
| The platform's hardware look: 32×24 cells, 8 colours + BRIGHT, FLASH, border, beeper | |
| Generic words: the President, the Army, the Peasants, the Landowners, the Guerrillas, the Secret Police, the East, the West | (Settings may add nicknames in flavour text, but the group labels on screen stay generic, see §4) |

## 4. Setting and names

### 4.1 Ground rules for every setting

- All places are **fictional**. No real country's name, and no name built to sound like one.
- **No ethnic or racial caricature.** No costume, accent, food or dress code that points at a real people or region. The satire targets the President, the palace and the system: medals, statues, balconies, paperwork, the Swiss account.
- **The group labels stay generic on screen** (Army, Peasants, Landowners, Guerrillas, Secret Police, plus the Neighbour's name and the two powers), because the reports, the advice lines and the help list must stay readable at a glance. A setting may give the guerrillas or the police a nickname in headlines and flavour text only.
- **The President** is "the President" in every setting, without a personal name or a gender. A setting may add an honorific for flavour.
- The geography has to fit RULES: a coast (D6 leases a naval base), farmland and estates (R2, R23, R24 irrigation), a land border with the Neighbour across **mountains** (§13.3 escape on foot), migrant labour and trade across that border (R12, R20, D16), and one export crop (N4).
- Names should be short: the longest name in a set should fit comfortably in a 32-column line next to a number.

### 4.2 Setting A: Splendoria, the vanity republic *(recommended)*

A small, warm, coastal republic with a mountain range along its border, whose President has renamed the country, the capital, the airport and the national bird after the regime's own magnificence. Statues outnumber schools. Across the mountains lives a calm, sensible neighbour that wants nothing to do with any of it.

| Role | Name | Notes |
|---|---|---|
| The player's country | **Splendoria** (10) | Officially "the Eternal Republic of Splendoria". The name is the joke: a regime that named a country after its own splendour. |
| Its adjective / people | **Splendorian** (11) | "the Splendorian Army", "Splendorian vanilla" |
| The bordering state | **Modestia** (8) | A quiet, tidy republic over the mountains. The name flatters it, not mocks it. |
| Its people / adjective | **Modestians** / **Modestian** (10 / 9) | |
| The export crop (N4) | **vanilla** | The nation's one export is, fittingly, plain vanilla. |
| The two superpowers | **the East** and **the West** | Generic real-world Cold War terms, kept as RULES uses them. |
| The guerrillas | **the guerrillas** (generic) | Headline nickname: *the Hill Front*. |
| The secret police | **the Secret Police** (generic) | Flavour nickname: *the Ministry of Gratitude*. |
| The President's honorific | *His or Her Splendour* | Flavour only. |

### 4.3 Setting B: Brinmoor, the island under the rain

A cold, windswept island in an invented northern sea, split down the middle by a ridge of bare mountains. The western half is Brinmoor, ruled from a damp palace by a President with a very dry sense of entitlement; the eastern half is Wyndle. The tone is dour and deadpan: ration books, fog, brass bands playing in the drizzle. The two superpowers are fictional blocs, which keeps real-world politics at arm's length.

| Role | Name | Notes |
|---|---|---|
| The player's country | **Brinmoor** (8) | "the People's Republic of Brinmoor" |
| Its adjective / people | **Brinmoorish** / **Brinmoorers** (11 / 11) | |
| The bordering state | **Wyndle** (6) | The other half of the island, beyond the ridge. |
| Its people / adjective | **Wyndlers** / **Wyndlish** (8 / 8) | |
| The export crop (N4) | **kelp** | Harvested from the shore and sold abroad as fertiliser and food thickener. "The kelp price collapses" is suitably grim. |
| The two superpowers | **the Plan** (the East's role) and **the Market** (the West's role) | Fictional blocs, named for how they run things. R6 becomes "the Plan's advisers", D4 "Market-made weapons", D14 "ask the Plan for a loan", D15 "ask the Market for aid". The refusal styles (RULES §16) write themselves: five-year officialese and a banker's brush-off. |
| The guerrillas | **the guerrillas** (generic) | Headline nickname: *the Ridge Bands*. |
| The secret police | **the Secret Police** (generic) | Flavour nickname: *the Weather Office*, because it watches everything. |
| The President's honorific | *the Lord President* | Flavour only. |

### 4.4 Setting C: Philatelia, the postage-stamp state

A tiny coastal republic whose main source of foreign money, apart from its crop, is selling beautiful postage stamps to collectors abroad. Every stamp carries the President's portrait. Across the mountains lies Perforia, a rival stamp-issuing state. The visual hook is strong (screens as stamps, sheets and postmarks), and the satire is the regime's obsession with its own image.

| Role | Name | Notes |
|---|---|---|
| The player's country | **Philatelia** (10) | "the Commemorative Republic of Philatelia" |
| Its adjective / people | **Philatelic** / **Philatelians** (10 / 12) | "the Philatelic Army" is the joke. |
| The bordering state | **Perforia** (8) | The rival stamp state across the mountains. |
| Its people / adjective | **Perforians** / **Perforian** (10 / 9) | |
| The export crop (N4) | **gumbark** | An invented tree whose sap becomes the glue on the back of stamps. |
| The two superpowers | **the East** and **the West** | Generic real-world Cold War terms. |
| The guerrillas | **the guerrillas** (generic) | Headline nickname: *the Unfranked*. |
| The secret police | **the Secret Police** (generic) | Flavour nickname: *the Sorting Office*. |
| The President's honorific | *the Postmaster-President* | Flavour only. |

### 4.5 Recommendation: Setting A, Splendoria

- **The satire lands on the regime.** The country's very name is the dictator's vanity, so every screen that names it is a small joke at the palace's expense. The neighbour's name is a compliment, so the player is never invited to sneer at another people.
- **It ports the topics without friction.** RULES' 49 topics already speak of the East and the West, Western companies and the East's advisers; Splendoria keeps those generic terms, so the request and decision texts need no extra invention, and the player's real-world intuitions about the two powers still work.
- **The geography fits every rule:** coast for the naval base, estates and irrigation, a mountain border for the escape on foot, and one crop to collapse.
- **The names are short** and read well in 32 columns.
- **It is not tied to a real region.** The names are built from English words with a Latin ending, and the art bible should keep costume and scenery generic (operetta uniforms, palms and statues are fine; anything pointing at a real culture is not).

Setting B is the best choice if the owner wants to keep real-world superpowers out entirely. Setting C has the strongest visual identity and could be reconsidered at the art-bible stage as a *look* (stamps, postmarks) for Splendoria.

## 5. Player experience

- **Who:** people who remember the 1983 game and want to play it again, and newcomers who like short, darkly funny strategy games. No prior knowledge needed; the how-to-play pages explain everything RULES says the player can see.
- **On what:** desktop browsers with a keyboard, and phones in portrait or landscape with a touch keypad. One hand on a phone is enough.
- **How long:** a session is one reign, 5–20 minutes. Most reigns end in disaster: shot by an assassin, overthrown, executed after a war, caught on the mountain path. A few end with a helicopter lifting off and a fat Swiss account.
- **The arc of a session:**
  1. *Confidence:* a full treasury, everyone moderately content, free reports.
  2. *Juggling:* every month a faction wants something, and every refusal makes an enemy. The treasury drains; the reports start to show plots.
  3. *Paranoia:* the player buys reports, pays for bodyguards, eyes the helicopter, starts skimming to Switzerland.
  4. *Crisis:* an alarm, a question (run or fight?), a desperate look at who might still help.
  5. *Verdict:* a funeral or an escape, then the rating, and the best score to beat.
- **Why play again:** the score. The rating rewards popularity, months survived and, if you get out alive, money in the bank, so there are different strategies to try (the popular ruler, the long survivor, the thief with a helicopter). The best rating is shown on the welcome screen of the next game.

## 6. Core loop

In the player's words, one month goes like this (RULES §4 is the authority):

1. **A new month begins.** Behind the scenes the month's mood is rolled (§3). The month number shows briefly.
2. **The books are checked** (§5). If the treasury is in debt, the army and police lose heart and the President's guard thins; otherwise the running costs are paid.
3. **An audience** (§8). One faction comes with a request. You may ask for advice (what it would do to everyone), then grant it or refuse it. If you can't afford it, you must refuse. Refusing offends the faction.
4. **Dangers** (§10, §11). An assassin may strike. The Neighbour may threaten war, or invade.
5. **Your own move** (§9). Choose one presidential decision from five sections, or none: favour a group, favour everyone, protect yourself (secret police, bodyguards, a helicopter, a Swiss account), raise money (loans, seizures), or strengthen a group.
6. **News** (§12). Sometimes a headline shakes things up.
7. **Revolution?** (§13). If a faction has an ally strong enough, it rises. Flee, or fight with whatever help you can find.
8. **Throughout:** the intelligence reports (§7), offered several times a month for a small fee, are your only view of who is plotting.

The game ends only with death or escape (§14), followed by the rating.

## 7. Screen list

Every screen the player can see. The wireframes phase must draw exactly this list. **Engine kind** is the proposed name of the screen kind the engine emits through `show(screen) → key` (the implementer may rename it, but not merge or split screens without updating this list); **extra** marks screens the remake adds that the engine never emits. **Pacing** is from RULES §15.5: *key* means it waits for a key; a time means it moves on by itself after at least that long.

| # | id | Purpose | Reached from | Engine kind / extra | Pacing |
|---|---|---|---|---|---|
| 1 | `title` | The game's name, its pitch line, and the keys for how to play, About and sound | Page load; after the final report | extra (the flow's start) | key |
| 2 | `howto` | How to play, in several pages, written from RULES | `title` (H) | extra | key per page; returns to `title` |
| 3 | `about` | The credit line, the remake's own credits, licence and source link | `title` (A) | extra | key; returns to `title` |
| 4 | `sound` | A small on-screen indicator that sound is on or off; not a full screen | M on any screen; the touch sound button | extra (overlay) | none (fades after about 1.5 s; the game screen underneath is unchanged) |
| 5 | `welcome` | Best rating so far and an encouragement; the first reports are free | `title` | `welcome` | key |
| 6 | `month` | The month number | Start of each month (§4 step 2) | `month` | 1 s |
| 7 | `treasury` | Balance (credit or debt), monthly costs, Swiss balance once above 0 | After `welcome`; after the audience; after a decision, the Swiss transfer or a loan result | `treasury` | key |
| 8 | `report` | The intelligence report: month, every group's popularity and strength, plots, the President's strength, the revolution strength | A *yes* at an available `report-offer`; free after the first `treasury`; free as the *final* report after `rating` | `report` (flag: first / bought / final) | key |
| 9 | `report-offer` | Ask whether to buy a report for 1 (a thousand); or say none is available, with every failing reason | §4 steps 4, 10, 12, 13; after a crushed revolt | `reportOffer` (variants: available / unavailable) | available: key · unavailable: its sound |
| 10 | `bankrupt` | The treasury is empty; who loses what | §5, when the treasury is negative | `bankrupt` | 5 s |
| 11 | `audience` | Which faction has come, and what it asks for | §4 step 5 | `audience` | key |
| 12 | `advice-offer` | Ask whether to see advice | After `audience`; after choosing a normal decision option | `adviceOffer` | key |
| 13 | `advice` | The request or option, and each non-zero popularity and strength change, the requester's line marked | *Yes* at `advice-offer` | `advice` | key |
| 14 | `dialog` | Who asks (for requests) and what; the money, one-off and monthly, or that it costs nothing; a yes prompt if affordable | After `advice-offer` / `advice` | `dialog` (variants: affordable / unaffordable) | affordable: key · unaffordable: 5 s, no prompt |
| 15 | `cash-short` | The item; the money isn't there; a hint for each loan not yet granted | After an unaffordable `dialog` | `cashShort` | 7 s |
| 16 | `must-refuse` | Funds are insufficient, so the request is refused | After `cash-short` for a request | `mustRefuse` | 5 s |
| 17 | `menu` | The five decision sections; any other key means no decision | §4 step 11; back from a section or a declined dialog | `menu` | key |
| 18 | `section` | A section's available options with their fixed numbers | 1–5 at `menu` | `section` | key |
| 19 | `section-used` | Every option in this section has been used | 1–5 at `menu`, when all are used | `sectionUsed` | 3 s |
| 20 | `swiss` | Treasury before, amount moved (or nothing moved), then the treasury lines | D13 | `swiss` | 2 s, then the treasury lines appear and it waits for a key |
| 21 | `loan-wait` | An application to the East or the West is being considered | D14, D15 | `loanWait` | 1 s |
| 22 | `loan-result` | Too early; no more; refused (in that power's style); or granted with the amount | After `loan-wait` | `loanResult` | key |
| 23 | `news-alert` | Breaking news is coming | §12, when news happens | `newsAlert` | 6 s |
| 24 | `news-headline` | The headline | After `news-alert` | `newsHeadline` | 2 s |
| 25 | `assassin-attempt` | An assassin from a named faction strikes | §10, when an attempt is made | `assassinAttempt` | its sound |
| 26 | `assassin-result` | Killed, or survived | After `assassin-attempt` | `assassinResult` (killed / survived) | its sound |
| 27 | `war-threat` | The Neighbour threatens war; the home groups rally | §11, hostile, no invasion | `warThreat` | its sound |
| 28 | `invasion` | Both sides' strengths; a short war | §11, hostile, invasion | `invasion` | its sound (the short war) |
| 29 | `war-result` | The country won, or lost | After `invasion` | `warResult` (won / lost) | its sound |
| 30 | `heli-escape` | The President got away by helicopter | Lost war with a working helicopter; escape by helicopter after a revolt | `heliEscape` | its sound |
| 31 | `execution` | Condemned as a traitor and shot. Its heading says the helicopter failed, or else that the Neighbour won (one screen, RULES §11) | Lost war without a helicopter, or the helicopter failed | `execution` | its sound, then the funeral |
| 32 | `revolt-alarm` | A revolution has broken out | §13.2 | `revoltAlarm` | 5 s |
| 33 | `escape-ask` | Attempt to escape? | After `revolt-alarm` | `escapeAsk` | key |
| 34 | `help-list` | Who has risen with whom, their combined strength, and who can be asked for help, numbered 1–6 | Any key but Y at `escape-ask` | `helpList` | key (1–6 only) |
| 35 | `alone` | No one will help; the fight goes ahead anyway | `help-list` with nobody listed | `alone` | key |
| 36 | `joke` | The chosen group is absurd as a helper; the President must flee on foot (an owned helicopter is not tried, RULES §13.4) | An unlisted number at `help-list` | `joke` | 3 s |
| 37 | `strength` | The President's, the helper's and the rebels' strengths | After a helper is chosen, or after `alone` | `strength` | 5 s |
| 38 | `revolt-start` | The fighting begins | After `strength` | `revoltStart` | its sound |
| 39 | `overthrown` | Overthrown and killed | Revolt not crushed | `overthrown` | its sound, then the funeral |
| 40 | `crushed` | The revolt is crushed; ask whether to punish the rebels | Revolt crushed | `crushed` | key (the punish question) |
| 41 | `heli-fail` | The helicopter's engine dies; the President must go on foot | Y at `escape-ask` with a helicopter that fails | `heliFail` | 3 s |
| 42 | `mountains` | The trek over the mountains to the Neighbour | Escape on foot (no helicopter, after `heli-fail`, or after `joke`) | `mountains` | 4 s |
| 43 | `caught` | The guerrillas caught the President, and celebrate | After `mountains`, caught | `caught` | its sound, then the funeral |
| 44 | `escaped` | The guerrillas missed; the President is over the border | After `mountains`, not caught | `escaped` | its sound |
| 45 | `funeral` | Mourning, and how long the rule lasted | After any death screen (`assassin-result` killed, `execution`, `overthrown`, `caught`) | `funeral` | key (a remake addition, RULES §15.5) |
| 46 | `rating` | The score, line by line; the best so far | After `funeral`, `heli-escape` or `escaped` | `rating` | key |

**46 screens**: 42 engine screens and 4 extras. The final intelligence report is the `report` screen with its *final* flag, not a separate screen. There is no intro or publisher-credit screen.

## 8. Text budget

Budgets are **columns × lines**. The screen is 32 columns, so no line is longer than 32. The wireframes may tighten a budget, never loosen it. Placeholders are filled by the game; their worst-case widths are in §8.3. Do not write the final words here: the UI design phase writes them to fit.

### 8.1 Messages

| id | When | Conveys (facts and feeling) | Budget | Placeholders | Tone |
|---|---|---|---|---|---|
| `prompt-any` | Footer of every screen that waits for any key | Press a key (or tap) to go on | 32×1 | — | Neutral, brief |
| `prompt-yes` | Footer of every yes/no question | Y means yes; any other key means no | 32×1 | — | Neutral, brief |
| `title-name` | `title` | The chosen title, in large letters; its text alternative | 32×3 (large) | — | Grand, poster-like |
| `title-tagline` | `title` | One-line satirical pitch | 32×1 | — | Wry |
| `title-keys` | `title` | Any key starts; H for how to play; A for About; M for sound | 32×2 | — | Plain |
| `howto-page` | `howto`, one row per page (4–6 pages) | The goal (survive, score), the month, requests and advice, decisions, reports and plots, revolution and escape, the rating; no rule beyond RULES | 32×18 per page | `{page}`, `{pages}` | Friendly, plain, a little dry |
| `about-credit` | `about` | The factual credit line, verbatim from §1 | 32×5 (wrapped) | — | Factual (fixed text) |
| `about-remake` | `about` | Who made the remake, the licence, where the source lives | 32×6 | — | Factual |
| `sound-state` | `sound` overlay | Sound is now on, or off | 12×1 | `{state}` | Terse |
| `welcome-best` | `welcome`, a best rating exists | The best so far, and a dare to beat it | 32×3 | `{best}` | Pompous welcome with a sneer |
| `welcome-first` | `welcome`, no best yet | A first reign; good luck, you'll need it | 32×3 | — | Pompous welcome, ominous |
| `welcome-free` | `welcome` | The first treasury and intelligence reports are on the house | 32×2 | — | Official, generous for once |
| `month` | `month` | Which month of the reign this is | 32×2 | `{month}` | Calendar-like, ceremonial |
| `treasury-balance` | `treasury` | The balance, as credit, or as debt (two variants) | 32×2 | `{amount}` | Accountant's ledger; debt reads as alarming |
| `treasury-costs` | `treasury` | The monthly running costs | 32×1 | `{costs}` | Ledger |
| `treasury-swiss` | `treasury`, Swiss balance above 0 | What is safely abroad | 32×1 | `{swiss}` | Ledger, with a wink |
| `report-title` | `report` | Top secret; the month, or *final* on the last one; *free* on the first | 32×2 | `{month}` | Classified dossier |
| `report-table` | `report` | Heading and one row per group: name, popularity 0–9, strength 0–9 (groups 1–6 only) | 32×10 | `{group}`, `{pop}`, `{str}` | Dossier, tabular |
| `report-plot-revolt` | `report`, a faction plans a revolution | That faction plots a revolution with its ally (named and numbered) | 32×1 per faction | `{faction}`, `{ally}`, `{allyNo}` | Dossier, urgent (also marked in text, not only by FLASH or colour) |
| `report-plot-assassin` | `report`, a faction plans an assassination | That faction plots to kill the President | 32×1 per faction | `{faction}` | Dossier, urgent |
| `report-odds` | `report` | The President's strength (bodyguard) and this month's revolution strength | 32×2 | `{pstr}`, `{revstr}` | Dossier |
| `offer-ask` | `report-offer`, available | Buy a report for a thousand dollars? | 32×2 | `{price}` | Oily informer |
| `offer-none` | `report-offer`, unavailable | No report can be had this time | 32×1 | — | Shrugging |
| `offer-reason-pop` | `report-offer`, unavailable, police popularity too low | The police are too disloyal, with their popularity | 32×1 | `{pop}` | Deadpan |
| `offer-reason-str` | `report-offer`, unavailable, police strength too low | The police are too weak, with their strength | 32×1 | `{str}` | Deadpan |
| `offer-reason-cash` | `report-offer`, unavailable, treasury not positive | The treasury can't pay for it | 32×1 | — | Deadpan |
| `bankrupt` | `bankrupt` | The treasury is empty: the army's and the police's goodwill, the police's strength and the President's own guard each drop | 32×6 | — | Grim bulletin, mild panic |
| `audience-from` | `audience` | Which faction has come to the palace | 32×1 | `{faction}` | Court usher announcing |
| `advice-ask` | `advice-offer` | Would the President like advice? | 32×1 | — | Discreet adviser |
| `advice-line` | `advice`, one per non-zero change | A group, popularity or strength, and the change; the requester's own popularity line marked (by a symbol and by wording, not by colour only) | 32×1 each, up to 14 lines | `{group}`, `{change}` | Adviser's crib sheet |
| `dialog-from` | `dialog` for a request | Which faction asks | 32×1 | `{faction}` | Formal |
| `dialog-once` | `dialog`, one-off money | It adds this much to, or takes this much from, the treasury (two variants) | 32×1 | `{amount}` | Formal, ledger |
| `dialog-monthly` | `dialog`, monthly change | The running costs go up, or down, by this much a month (two variants) | 32×1 | `{amount}` | Formal, ledger |
| `dialog-free` | `dialog`, no money either way | None of it costs anything | 32×1 | — | Formal, pleased |
| `cash-short` | `cash-short` | This item cannot be paid for: the money isn't in the treasury | 32×3 | `{item}` | Embarrassed civil servant |
| `cash-hint` | `cash-short`, once per loan not yet granted | Try asking the East (or the West) | 32×1 each | `{power}` | Helpful, faintly desperate |
| `must-refuse` | `must-refuse` | The funds are insufficient, so the answer must be no | 32×2 | — | Mild humiliation |
| `menu-title` | `menu` | The President's decision for this month | 32×1 | `{month}` | Ceremonial |
| `menu-section` | `menu`, one per section (5) | The section's theme: favour one group; favour everyone; improve your odds; raise money; strengthen a group | 28×1 each (after the number) | `{n}` | Official agenda |
| `menu-none` | `menu` | Any other key: no decision this month | 32×1 | — | Plain |
| `section-title` | `section` | Which section this is | 32×1 | `{section}` | Official agenda |
| `section-used` | `section-used` | Nothing left in this section | 32×2 | — | Dry |
| `swiss-moved` | `swiss` | The treasury before, and how much went abroad | 32×3 | `{before}`, `{amount}` | Furtive banker |
| `swiss-nothing` | `swiss`, nothing moved | There was nothing to move | 32×2 | — | Furtive, disappointed |
| `loan-wait` | `loan-wait` | The application to this power is under consideration | 32×2 | `{power}` | Waiting-room |
| `loan-early` | `loan-result`, too early | It's too soon to ask | 32×3 | `{power}` | Patronising diplomat |
| `loan-nomore` | `loan-result`, no more (unreachable, kept) | This power has already lent once and won't again | 32×3 | `{power}` | Final |
| `loan-refused-east` | `loan-result`, refused by the East | A curt refusal in the East's own style | 32×3 | — | Committee officialese |
| `loan-refused-west` | `loan-result`, refused by the West | A curt refusal in the West's own style | 32×3 | — | Banker's brush-off |
| `loan-granted` | `loan-result`, granted | The amount granted by this power | 32×3 | `{power}`, `{amount}` | Grudging generosity |
| `news-alert` | `news-alert` | Breaking news | 32×2 | — | Tabloid, loud |
| `assassin-attempt` | `assassin-attempt` | An assassin sent by this faction strikes | 32×2 | `{faction}` | Thriller, sudden |
| `assassin-killed` | `assassin-result`, killed | The President is dead | 32×2 | — | Stark |
| `assassin-survived` | `assassin-result`, survived | The attempt failed; the President lives | 32×2 | — | Relief, bravado |
| `war-threat` | `war-threat` | The Neighbour threatens war; the home groups rally round the flag | 32×4 | `{neighbour}` | War-poster patriotism |
| `invasion` | `invasion` | The Neighbour invades; our strength against theirs | 32×4 | `{neighbour}`, `{ours}`, `{theirs}` | Radio war bulletin |
| `war-won` | `war-result`, won | The invaders are beaten back | 32×2 | `{neighbour}` | Triumphant |
| `war-lost` | `war-result`, lost | The country has fallen to the invaders | 32×2 | `{neighbour}` | Dire |
| `heli-escape` | `heli-escape` | The President got away by helicopter | 32×3 | — | Sly, cowardly triumph |
| `execution-heading` | `execution`, heading (two variants) | The helicopter failed to start; or the Neighbour has won | 32×1 | `{neighbour}` | Bathos / dire |
| `execution` | `execution` | Condemned as a traitor and shot | 32×3 | — | Stark, short |
| `revolt-alarm` | `revolt-alarm` | A revolution has broken out | 32×2 | — | Siren, alarm |
| `escape-ask` | `escape-ask` | Try to escape? | 32×2 | — | Urgent whisper |
| `help-rebels` | `help-list` | This faction has risen with this ally; their combined strength | 32×3 | `{faction}`, `{ally}`, `{combined}` | Crisis briefing |
| `help-option` | `help-list`, one per listed group | A group that could be asked for help, with its number | 28×1 each (after the number) | `{n}`, `{group}` | Crisis briefing |
| `help-ask` | `help-list` | Press a number to ask for help | 32×1 | — | Urgent |
| `alone` | `alone` | Nobody will help; you'll fight alone | 32×3 | — | Bleak |
| `joke` | `joke` | Asking that group is absurd; there's nothing for it but to run | 32×3 | `{group}` | Scornful |
| `strength` | `strength` | The President's, the helper's and the rebels' strengths, set side by side | 32×4 | `{pstr}`, `{helper}`, `{hstr}`, `{rebels}` | Tense tally |
| `revolt-start` | `revolt-start` | The fighting has begun | 32×2 | — | Action |
| `overthrown` | `overthrown` | Overthrown and killed | 32×3 | — | Stark |
| `crushed` | `crushed` | The revolt is crushed | 32×2 | — | Triumphant, vindictive |
| `punish-ask` | `crushed` | Punish the rebels? | 32×1 | — | Vindictive |
| `heli-fail` | `heli-fail` | The engine dies on the pad; it's on foot from here | 32×3 | — | Bathos |
| `mountains` | `mountains` | The trek over the mountains to the Neighbour, through guerrilla country | 32×3 | `{neighbour}` | Breathless |
| `caught` | `caught` | The guerrillas caught the President, and celebrate | 32×3 | — | Dark comedy |
| `escaped` | `escaped` | The guerrillas missed; the President is across the border | 32×3 | `{neighbour}` | Relief, sly |
| `funeral` | `funeral` | Mourning, and how many months the rule lasted | 32×4 | `{months}` | Mock-solemn state funeral |
| `rating-pop` | `rating` | Points from total popularity | 32×1 | `{pop}` | Scoreboard |
| `rating-months` | `rating` | Months ruled, times three | 32×1 | `{months}`, `{points}` | Scoreboard |
| `rating-alive` | `rating`, alive only | 10 for surviving; points for the Swiss money (two lines) | 32×2 | `{swiss}`, `{points}` | Scoreboard, smug |
| `rating-total` | `rating` | The total | 32×1 | `{total}` | Scoreboard, emphatic |
| `rating-best` | `rating` | The best so far, which already includes this game (RULES §14), and, if beaten, that this is a new best | 32×2 | `{best}` | Scoreboard |

### 8.2 The data texts (RULES §17)

One row per kind; each item's topic is already in RULES §17, so the UI design writes 49 texts to these budgets.

| id | Kind | Count | When | Conveys | Budget | Placeholders | Tone |
|---|---|---|---|---|---|---|---|
| `request-text` | Requests R1–R24 | 24 | `audience`, `advice`, `dialog` | What the faction asks for (the topic), in the faction's own voice: the Army barks, the Peasants petition, the Landowners expect | 32×2 | `{country}`, `{neighbour}`, `{power}` where the topic names them | In character per faction, never a caricature of a real people |
| `decision-label` | Decisions D1–D19 | 19 | `section` list | A short name for the option | 28×1 (after the number) | as above | Official agenda |
| `decision-text` | Decisions D1–D12, D16–D19 | 16 | `advice`, `dialog`, `cash-short` | What the President would do (the topic); D11 notes it can be repeated | 32×2 | as above | The President's own grand voice |
| `headline` | News N1–N6 | 6 | `news-headline` | The topic, as a front page | 32×3 | `{country}`, `{neighbour}`, `{crop}` | Tabloid headline |

D13, D14 and D15 have labels only: they never show advice or a dialog (RULES §9.2).

### 8.3 Worst-case placeholder widths

| Placeholder | Range (RULES) | Reserve |
|---|---|---|
| `{amount}`, `{costs}`, `{swiss}`, `{before}` | Money in thousands of dollars; treasury may be negative; loans add up to 469 each | 12 columns (a minus sign and `$12,345,000`) |
| `{month}`, `{months}` | No limit | 3 digits |
| `{pop}`, `{str}`, `{revstr}`, `{change}` | 0–9, 10–12, ±9 | 2 columns |
| `{pstr}` | 0 upward, no maximum (+2 per bodyguard) | 3 digits |
| `{ours}`, `{theirs}`, `{combined}`, `{rebels}` | Sums of strengths (plus `{pstr}` for ours) | 3 digits |
| `{total}`, `{best}`, `{points}` | Popularity 0–72, 3 per month, money points | 5 digits |
| `{faction}`, `{group}`, `{ally}`, `{power}`, `{neighbour}`, `{country}`, `{crop}` | Names from §4 | 12 columns |

### 8.4 Row counts

- **Messages (§8.1):** 83 rows: 74 for the game's screens and 9 for the extras and the shared footer prompts.
- **Data texts (§8.2):** 4 rows covering 24 requests, 19 decision labels, 16 decision texts and 6 headlines.

## 9. Audio

All melodies are new and written for this game; effects are generic beeper sounds (sweeps, ticks, noise). Nothing reproduces the original's tunes or effect patterns. Lengths are targets; the art bible fixes the notes. Sound starts after the first key press (browser rule), and M toggles it. Where a screen is timed by "its sound" (RULES §15.5), the screen lasts as long as the sound, and when sound is off it lasts the same time in silence.

| id | Trigger | Purpose / mood | Length | Character |
|---|---|---|---|---|
| `anthem` | `title` | The regime's pompous national anthem: self-important, slightly off | 6–8 s, once | Original march motif in a major key, dotted rhythms, a cadence that lands a beat late |
| `welcome-fanfare` | `welcome` | A herald's welcome to the palace | 1.5 s | Four rising notes, original |
| `month-chime` | `month` | Another month begins | 0.5 s | Two-note chime, clock-like |
| `ledger` | `treasury` | Money being counted | 0.6 s | Quick ticks, a cash-drawer click |
| `report-open` | `report` | A secret file is opened | 0.4 s | Short descending sweep, a click |
| `report-none` | `report-offer`, unavailable | No report today | 1.2 s | Flat two-tone buzz |
| `bankrupt-slide` | `bankrupt` | The money's gone | 2 s | Slow falling sweep ending in a low rasp |
| `audience-bell` | `audience` | Someone at the door | 0.8 s | A three-note doorbell, original |
| `answer-blip` *(optional)* | Any key at a prompt | Acknowledge the key | 0.05 s | Single click; yes and no may differ in pitch (generic) |
| `wait-tick` *(optional)* | While a screen waits for a key | A ticking clock under the footer | 0.03 s every 1 s | Soft tick (generic); off by default |
| `cash-short-raspberry` | `cash-short` | Embarrassment | 1 s | A low wobbling buzz |
| `refuse-thud` | `must-refuse` | The door is shut | 0.4 s | One low thud |
| `swiss-whistle` | `swiss`, money moved | Something sneaky | 1 s | A furtive four-note whistle, original |
| `loan-typewriter` | `loan-wait` | Officials considering | 1 s | Irregular ticks, a bell at the end |
| `loan-yes` | `loan-result`, granted | Money arrives | 1 s | A bright arpeggio and a cash-register ding |
| `loan-no` | `loan-result`, not granted | Rejection | 0.6 s | Two falling notes |
| `news-teleprinter` | `news-alert` | Breaking news | up to 6 s | Teleprinter chatter with a two-note sting, original |
| `assassin-shot` | `assassin-attempt` | A shot rings out | 0.5 s | Noise burst with a sharp decay |
| `assassin-dead` | `assassin-result`, killed | Death | 2 s | A long, low, wavering tone (not a single held beep) |
| `assassin-miss` | `assassin-result`, survived | A lucky escape | 1 s | Ricochet sweep up, then a relieved two-note figure |
| `war-drums` | `war-threat` | War looms; patriotic rally | 2 s | Snare-like noise rolls with a short bugle call, original |
| `war-short` | `invasion` | The short war | 3 s | Alternating noise bursts and falling sweeps |
| `war-won` | `war-result`, won | Victory | 2 s | Brass-style fanfare, original |
| `war-lost` | `war-result`, lost | Defeat | 2 s | Descending minor figure |
| `rotor` | `heli-escape` | The getaway | 2.5 s | Pulsed clicks speeding up, then a rising sweep fading out |
| `sputter` | `heli-fail`, and `execution` when its heading is the helicopter's failure | The engine dies | 1.5 s | Uneven clicks slowing to a stop, a cough |
| `volley` | `execution` | The firing squad | 1 s | Three short noise bursts close together (no melody) |
| `revolt-siren` | `revolt-alarm` | Revolution! | up to 5 s | A new two-tone siren pattern, alternating at under 3 Hz, distinct in pitch and rhythm from any period alarm |
| `heartbeat` | `strength` | Tension before the fight | up to 5 s | Low double thumps, quickening |
| `skirmish` | `revolt-start` | The fighting | 2 s | Random noise crackle |
| `overthrown-drop` | `overthrown` | The end | 2 s | A falling sweep into silence |
| `crushed-fanfare` | `crushed` | Victory over the rebels | 1.5 s | A short triumphant figure, original |
| `footsteps` | `mountains` | The trek | up to 4 s | Steady crunching clicks, getting slower |
| `caught-jig` | `caught` | The guerrillas celebrate | 2 s | A cheerful original dance figure, cruelly upbeat |
| `escaped-whistle` | `escaped` | Over the border | 1.5 s | A cheeky rising whistle, original |
| `funeral` | `funeral` | Mock-solemn state funeral | 8–12 s, once | **Recommended: an original mourning motif** (slow, minor, heavy repeated bass notes, a pompous turn at the end), not an arrangement of a public-domain march. See below. |
| `rating-tally` | `rating` | Counting the score | 0.1 s per line | Rising ticks as each line appears |
| `new-best` | `rating`, new best | A new record | 1.5 s | A bright original flourish |

**The funeral music.** Two options were considered:
- *A new arrangement of a public-domain mourning theme.* Legal as long as the arrangement is our own, and instantly readable as "funeral". But a well-known funeral march is exactly what a player expects from the period, so it is the closest our sound could come to the original's choice, and it competes with pillar 1's "looks new".
- *An original motif* written for this game. Fully ours, carries the same meaning through tempo and key, and can quote the remake's own `anthem` in a slow minor form, which is a better joke: the regime's own anthem played as its dirge.

**Recommendation: the original motif**, built as a slow, minor-key variation of our `anthem`.

## 10. Platforms and controls

**Keys** (RULES §15.1; these are gameplay and must not change):

| Prompt | Keys | Notes |
|---|---|---|
| Every prompt | One key per prompt | Never a typed line |
| Yes/no questions | **Y** = yes; any other key = no | Case of Y is an open decision (§15); recommendation: accept both cases |
| Screens that wait | Any key continues | A key that doesn't fit the prompt counts as "no" or "next" |
| Decision menu | **1–5** choose a section | Any other key: no decision this month |
| Inside a section | The number of an available option | Any other key, or a used or unlisted number, goes back to the menu without an error |
| Help list | **1–6** only | Other keys are ignored; an unlisted number is accepted and is the joke |
| Anywhere | **M** toggles sound | Handled by the platform layer and **not passed to the game**, so M never counts as "no" or "next" (see the M-key risk in §13) |
| `title` only | **H** how to play, **A** About | Any other key starts the game. The title is not a game prompt, so this doesn't touch RULES' input semantics |

**Touch:**
- A touch keypad under (portrait) or beside (landscape) the screen offers exactly the keys that matter at each prompt: *Yes* / *No* at questions; *1–5* and *No decision* at the menu; the listed option numbers and *Back* in a section; *1–6* at the help list; *Next* where any key continues. The *No*, *No decision*, *Back* and *Next* buttons send a neutral key, so behaviour matches a keyboard "any other key".
- **Tapping the screen counts as any key** (RULES §15.1), except at the help list, where only 1–6 count, so a stray tap does nothing there.
- A small sound button toggles sound, like M.
- Touch targets are at least 44 × 44 CSS pixels.

**Screen sizes:**
- **Desktop:** the 256×192 screen plus border, scaled by whole numbers, centred; keyboard only, the keypad hidden unless the device has touch.
- **Phone portrait:** the screen fits the width; the keypad sits below it.
- **Phone landscape:** the screen fits the height; the keypad sits to one side.

**Other:** a static page with no server calls, so it keeps working offline once loaded; current versions of Chrome, Firefox, Safari and Edge, desktop and mobile; no account, no cookies, no tracking.

## 11. Accessibility

- **Screen-reader text for every screen.** The template mirrors the screen to an `aria-live` region. For every screen in §7, the UI design writes a text version that contains everything on the screen in reading order, describes any picture that carries meaning (a portrait, the helicopter, the coffin), and ends with the keys available at that prompt. Specific rules:
  - `report`: read as a list, one group per line ("Army: popularity 6, strength 6"), then each plot as a sentence, then the President's strength and the revolution strength.
  - `advice`: the requester's line says so in words, not only by a marker.
  - `help-list` and `section`: each option is read with its number.
  - Alarms and deaths (`revolt-alarm`, `assassin-attempt`, `invasion`, the death screens) use an assertive announcement; everything else is polite.
- **Flashing under 3 Hz.** Spectrum FLASH swaps about every 0.32 s (about 1.6 full cycles a second), which is within the limit; no screen may flash faster, flash more than a small area, or flash red at large size. The siren's visual equivalent, if any, follows the same limit.
- **Contrast.** Text uses ink/paper pairs with a contrast ratio of at least 4.5:1 (for example white or yellow on black or blue; never red on blue or magenta on red for text). The art bible lists the allowed text pairs.
- **Keyboard-only play.** The whole game, including the extras, works with the keyboard alone. No mouse or touch is ever required, and focus never leaves the game.
- **Nothing carried by colour or sound alone.** A plot is marked in words as well as by FLASH or colour; debt shows a minus sign or the word, not only red; every sound has a matching on-screen message, so the game is fully playable muted.
- **Timing.** Timed screens follow RULES §15.5. Because RULES allows lengthening (never shortening), the remake offers a **"wait for a key on timed screens"** setting, off by default, for players who need more reading time or use a screen reader. It changes no game state, and parity testing runs with it off. (Open decision 7.)
- **Motion and sound:** sound starts muted until the first key; there is no autoplay and no full-screen flashing.

## 12. Scope and non-goals

**In scope:** the game exactly as RULES describes it; the four extras (title, how to play, About, sound toggle); keyboard and touch; three layouts; screen-reader text; the best rating kept in the browser's local storage (only that number; if storage is unavailable the game still runs and shows no best).

**Not in scope (deliberately):**
- **No rule changes.** Not to the balance, the draws, the quirks or the input. Ideas for "improvements" go to the owner as open decisions, never into the game.
- **No saved games** or resume. A reign is short; closing the page ends it.
- **No difficulty modes**, no tutorials that change play, no hints beyond the in-game advice.
- No online leaderboard, accounts, analytics or cookies.
- No intro screen imitating a publisher credit, and no imitation of the original's screens.
- No translations in the first release (English only); the text budget leaves room to add them later.
- No new content: no extra requests, decisions or headlines.

## 13. Risks

| Risk | Kind | Likelihood | Mitigation |
|---|---|---|---|
| The title collides with an existing game or trademark (especially *President for Life* or keeping *Dictator*) | Legal | Medium | Search game stores, trademark registers and the web before the owner chooses; prefer the most distinctive option |
| A screen still looks like the original's (the request screen's icon row, the report's column layout, tiled backgrounds, the title wallpaper) | Legal | Medium | The wireframes and art bible design from RULES and this document only; the art bible's distinctiveness table; phase 7's visual review |
| Original wording leaks into new text, through memory or paraphrase | Legal | Low–medium | Text written from purposes only; `overlap.py` with the original's names at every phase; a guard test of hashes of the original strings |
| The funeral or other tunes resemble the original's | Legal | Low | Original motifs only (§9); the funeral uses our own anthem, not a public-domain march |
| A setting reads as a caricature of a real people or region | Design / reputational | Low–medium | §4.1 ground rules; the art bible avoids national costume and real-region scenery; owner review |
| The satire offends because the subject (coups, executions) is grim | Design | Low | Keep the joke on the regime; stark, short wording for deaths; no gore in art |
| Short timed screens are hard to read on phones or with screen readers | Design / accessibility | Medium | Lengthen where RULES allows; the "wait for a key" setting; the text mirror |
| The M key (sound) swallowing a keypress changes the input semantics compared with the baseline | Technical / parity | Low | The parity harness never sends M; documented in §10 |
| Phone layouts squeeze a 32-column screen too small to read | Technical | Medium | Fit-to-width scaling; the keypad never overlaps the screen; test on small phones in phase 7 |
| Local storage is blocked (private browsing) | Technical | Low | Wrap reads and writes; the game runs with no best rating |
| The newsflash money quirk looks like a bug to players | Design | Medium | Keep it (faithful), and say nothing in-game; or mention it in the how-to-play pages if the owner wishes (§15, item 3) |

## 14. Decision log

| Date | Decision | By |
|---|---|---|
| 2026-11-06 | The faithful (private) version is served only to the owner, behind a login, at `icelander.net/recreations/zxspectrum/dictator`. That leaves `icelander.net/retro-games/…` free for the public remakes. | Owner |
| 2026-11-06 | The skill is named `create-retro-game`; the remake lives in `games/dictator/`. | Owner |
| 2026-11-06 | `docs/RULES.md` approved on merge (PR #4). | Owner |
| 2026-11-06 | RULES clarified from the designer's questions, checked against the baseline: affordability wording (§8.3); one execution screen after a lost war, headed by the helicopter's failure or the Neighbour's victory (§11); the joke skips the helicopter (§13.4); the rating's best includes this game (§14); platform keys such as M never reach the game (§15.1). | Spec role |
| _pending_ | Title, setting and names (this GDD's gate). | Owner |

## 15. Open decisions

| # | Decision | Options | Recommendation |
|---|---|---|---|
| 1 | **The title** | *President for Life*, *Tinpot*, *One More Month*, or keep *Dictator* with the risk accepted | *Tinpot* |
| 2 | **The setting and names** | A: Splendoria / Modestia; B: Brinmoor / Wyndle; C: Philatelia / Perforia (§4) | A, Splendoria |
| 3 | **The newsflash money quirk** (RULES §9.4, §12): a headline also re-applies the money of the last item whose dialog was shown | Keep it on (faithful), or switch it off | Keep it on: pillar 1, and it's part of the original's character. The switch exists in code for testing only. |
| 4 | **The case of the Y key** (RULES §15.1) | Accept Y and y (as the baseline does), or only lower-case y (as the original did with caps lock off) | Accept both. The original's case behaviour was an accident of the keyboard, not a design; a caps-lock trap would feel like a bug today, and the touch keypad sends one "yes" anyway. |
| 5 | **Permission from the original author's estate** to publish a free remake | Ask, or rely on the clean-room work alone | Ask, politely and early. Permission doesn't replace the clean-room work, but it lowers the risk and is a courtesy. |
| 6 | **The remake's public address** | `icelander.net/retro-games/<title-slug>` (e.g. `/retro-games/tinpot`); `icelander.net/retro-games/dictator` (free now that the private version lives under `/recreations/`); a subdomain such as `<title-slug>.icelander.net` | `icelander.net/retro-games/<title-slug>`, once the title is chosen, so the address matches the name on the screen. The repository folder can stay `games/dictator/`. |
| 7 | **"Wait for a key on timed screens"** setting (§11) | Offer it (off by default), or not | Offer it: RULES allows lengthening, it changes no state, and it helps screen-reader users. |
