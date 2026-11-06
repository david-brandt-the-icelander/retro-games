# Samosa: game design document

Status: **approved** · Phase 2 of `create-retro-game` · written by the designer from `docs/RULES.md` · Owner decisions recorded 2026-11-06 (§14)

This document decides what the remake *is*: its name, its world, its voice, its screens and its sounds. `RULES.md` decides what it *does*, and nothing here changes a rule. Where this document mentions a number, a draw or an order, RULES is the authority.

It contains no text from the original game and none of its invented names. Any old → new name mapping is kept in the private repository only, never here.

## 1. Identity

- **Title: *Samosa*** (owner's choice: a pun on the Somoza dynasty, whose stand-in family is a faction in the game). The repository folder stays `games/dictator/`; the public address is `icelander.net/games/retro/samosa`.
- **Title proposals** considered, each with a one-line pitch:

| # | Title | Pitch |
|---|---|---|
| 1 | ***President for Life*** | You've promised to rule forever; the army, the peasants, the landowners and the treasury have other plans. |
| 2 | ***Tinpot*** | A pocket-sized autocracy with an empty treasury, three restless factions and a helicopter on the roof, if you can afford one. |
| 3 | ***One More Month*** | Grant, refuse, bribe and borrow your way through another month in the palace; the only prize is a better score at your funeral. |
| — | *Dictator* (the original's title) | Possible if the owner accepts the risk. It is a common English word, so it is a weak mark, but it is still the name most associated with the 1983 game, so it signals "the same game" more strongly than anything else, and invites confusion with the original's rights holders. |

  The designer recommended *Tinpot*; the owner first chose *Sozoma*, then ***Samosa***: six letters, fits large lettering in 32 columns. Its pitch line is written in the UI design.
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
| The treasury, costs, Swiss account, bodyguard strength, helicopter and loans (§2) | The player's country, its adjective, the bordering state and its people, the export crop, the ruling families' pun names and the named organisations (§4 below) |
| The monthly thresholds and their hidden/shown status (§3) | The title (§1) and the title screen |
| The month's 15 steps in their order, and the plot checks between them (§4) | Every screen layout (wireframes, phase 3); none recreates the original's designs |
| Accounts, plots, reports, audience, decisions, assassination, war, news, revolution, escape, rating: every rule and formula (§5–§14) | Colours per screen, icons, portraits and all pixel art (art bible, phase 4) |
| All data numbers in RULES §17 and their order | All tunes and effect patterns (§9 below); the funeral music |
| The random generator, its seeding and the exact order of draws (§15.4) | The font (our own, from the web template) |
| Input semantics: one key per prompt, only Y means yes, any other key means no or next, 1–5 menu, 1–6 help with other keys ignored (§15.1) | The code: a new engine written from RULES only |
| Integer arithmetic, clamping, ≤/≥ comparisons and the −1/0/+1 swings (§15.2) | The About screen, which replaces any credit screen; there is **no** intro screen imitating a publisher credit |
| Pacing: which screens wait for a key and the minimum time of each timed screen (§15.5); we may lengthen, never shorten | The how-to-play pages, written fresh from RULES |
| The quirks: a request can be skipped when the used marks reset (§8.1); unlimited bodyguards; the unreachable "no more loans" result still has its message | Touch keypad, responsive layouts, screen-reader text, sound toggle (additions that don't change the game) |
| The platform's hardware look: 32×24 cells, 8 colours + BRIGHT, FLASH, border, beeper | |
| The eight groups' roles and order (RULES §1) | Their on-screen labels and identities: the Landowners become the Samosa family, the Guerrillas the Contras, and so on (§4.2) |

## 4. Setting and names

The owner chose a **real setting with real organisations**: the player rules **Nicaragua** as **President Ortiga**, the bordering state is **Honduras**, and the game is titled ***Samosa***. Events are built on Nicaragua's real history, caricatured. The research brief (kept outside the repository, with sources) gives a historical anchor for every request, decision and headline; the UI design writes the texts from it.

### 4.1 Ground rules

- **Organisations and parties are named** (owner decision): the Sandinistas (FSLN), the Contras, the National Guard, the CIA, *La Prensa*, the business council COSEP, the Soviet Union, Cuba, Washington, and so on. Satire aims at what they did as institutions.
- **No real person is named or drawn.** The two ruling families appear only under pun names: **Ortiga** (for Ortega; Spanish for "nettle") and **Samosa** (for Somoza). No first names, no likenesses, no quotes put in a real person's mouth. Other people appear only by role ("the editor", "the bishop", "the ambassador").
- **The President** is "President Ortiga": no first name, no gender, no spouse.
- **Caricature, not cruelty.** The jokes land on the regime, the dynasties, the superpowers and the bureaucracy: graft, vanity, paranoia, the helicopter on the roof. Never joke about victims: the murdered newspaper editor (1978), the dead of 2018, political prisoners and exiles, the Miskito relocations, or religious faith itself. No caricature of Nicaraguans or Hondurans as peoples.
- **Mixed eras, on purpose.** Flavour may draw on any period, from the filibusters to the canal concession, as if the whole history were one long, very bad presidency.
- **The group labels stay short on screen** so reports, advice and the help list read at a glance (§4.2); the full organisation names appear in requests, headlines and the how-to-play pages.

### 4.2 Names

| Role (RULES) | On-screen label | In texts | Notes |
|---|---|---|---|
| The game | ***SAMOSA*** (6) | | Title only |
| The President | President Ortiga | | The new dynasty; ex-guerrilla turned strongman |
| Army | ARMY | the Sandinista Popular Army; in old-regime jokes, the National Guard | |
| Peasants | PEASANTS | the campesinos, the farm workers' union | |
| Landowners | SAMOSAS | **the Samosa family**: the old dynasty and its estates, businesses and Miami friends | Same faction, same rules and numbers; it speaks as the family |
| Guerrillas | CONTRAS | the Contras, camped over the border in Honduras, paid by Washington | Always hostile, as RULES says |
| The Neighbour | HONDURAS | Honduras and Hondurans | Across the northern mountains |
| Secret police | SEC. POLICE | State Security | |
| The East | EAST | Moscow and Havana (the Soviet Union and Cuba) | |
| The West | WEST | Washington (and its CIA) | |
| Export crop (N4) | | coffee | |
| The mountains (§13.3) | | the northern mountains | |

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
| 4a | `scores` | The public high-score table: the ten best reigns (name, score, months, fled or died), this reign highlighted | `title` (S); after an entry | extra (owner decision 2026-11-06) | key; returns to `title` |
| 4b | `entry` | After a reign: the score, and an HTML form below the screen for the player's email | After the final report, when the server issued the reign's seed | extra (owner decision 2026-11-06) | the form: Enter submits, Escape or SKIP skips |
| 5 | `welcome` | Best rating so far and an encouragement; the first reports are free | `title` | `welcome` | key |
| 6 | `month` | The month number | Start of each month (§4 step 2) | `month` | 1 s |
| 7 | `treasury` | Balance (credit or debt), monthly costs, Swiss balance once above 0 | After `welcome`; after the audience; after a decision, the Swiss transfer or a loan result | `treasury` | key |
| 8 | `report` | The intelligence report: month, every group's popularity and strength, plots, the President's strength, the revolution strength | A *yes* at an available `report-offer`; free after the first `treasury`; free as the *final* report after `rating` | `report` (flag: first / bought / final) | key |
| 9 | `report-offer` | Ask whether to buy a report for 1 (a thousand); or say none is available, with every failing reason | §4 step 15: once a month, at its end | `reportOffer` (variants: available / unavailable) | available: key · unavailable: its sound |
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

**Pacing update (owner, 2026-11-06):** a time in the Pacing column is now the *minimum* time a screen stays up while it draws and plays its sound; after that, every screen waits for a key.

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
| Yes/no questions | **Y** or **y** = yes; any other key = no | Both cases (owner decision) |
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

**Other:** a static page that keeps working offline once loaded. Its only server calls are for the high-score table (owner decision 2026-11-06): a seed at the start of each reign, the reign's keys if the player enters the table, and the table itself. Offline, a reign plays with a local seed and can't be entered. Current versions of Chrome, Firefox, Safari and Edge, desktop and mobile; no account, no cookies, no tracking.

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
- **Timing.** Timed screens follow RULES §15.5 exactly. There is no "wait for a key" setting (owner decision); the screen-reader mirror announces each timed screen as it appears.
- **Motion and sound:** sound starts muted until the first key; there is no autoplay and no full-screen flashing.

## 12. Scope and non-goals

**In scope:** the game exactly as RULES describes it; the four extras (title, how to play, About, sound toggle); keyboard and touch; three layouts; screen-reader text; the best rating kept in the browser's local storage (only that number; if storage is unavailable the game still runs and shows no best).

**Not in scope (deliberately):**
- **No rule changes.** Not to the balance, the draws, the quirks or the input. Ideas for "improvements" go to the owner as open decisions, never into the game.
- **No saved games** or resume. A reign is short; closing the page ends it.
- **No difficulty modes**, no tutorials that change play, no hints beyond the in-game advice.
- No accounts, analytics or cookies. (An online high-score table was added later by owner decision; see the decision log.)
- No intro screen imitating a publisher credit, and no imitation of the original's screens.
- No translations in the first release (English only); the text budget leaves room to add them later.
- No new content: no extra requests, decisions or headlines.

## 13. Risks

| Risk | Kind | Likelihood | Mitigation |
|---|---|---|---|
| The title collides with an existing game or trademark | Legal | Low | *Samosa* is a common food word, a weak mark either way; search game stores before publishing |
| The real setting: the game names real parties and organisations, puns on two real ruling families, and shows Honduras as a hostile invader | Reputational / political | Medium | §4.1: no real person named or drawn; no jokes about victims; no caricature of either people; the About screen says the events are caricatures of history, not a record. The owner chose this and accepts the risk. |
| Named contributors with ties to Nicaragua could face retaliation (its government strips critics of citizenship) | Personal | Low | The owner decides how the credits read; anonymous credits are possible |
| A screen still looks like the original's (the request screen's icon row, the report's column layout, tiled backgrounds, the title wallpaper) | Legal | Medium | The wireframes and art bible design from RULES and this document only; the art bible's distinctiveness table; phase 7's visual review |
| Original wording leaks into new text, through memory or paraphrase | Legal | Low–medium | Text written from purposes only; `overlap.py` with the original's names at every phase; a guard test of hashes of the original strings |
| The funeral or other tunes resemble the original's | Legal | Low | Original motifs only (§9); the funeral uses our own anthem, not a public-domain march |
| A setting reads as a caricature of a real people or region | Design / reputational | Low–medium | §4.1 ground rules; the art bible avoids national costume and real-region scenery; owner review |
| The satire offends because the subject (coups, executions) is grim | Design | Low | Keep the joke on the regime; stark, short wording for deaths; no gore in art |
| Short timed screens are hard to read on phones or with screen readers | Design / accessibility | Medium | Keep timed texts short (UI design budgets); the text mirror announces each one |
| The M key (sound) swallowing a keypress changes the input semantics compared with the baseline | Technical / parity | Low | The parity harness never sends M; documented in §10 |
| Phone layouts squeeze a 32-column screen too small to read | Technical | Medium | Fit-to-width scaling; the keypad never overlaps the screen; test on small phones in phase 7 |
| Local storage is blocked (private browsing) | Technical | Low | Wrap reads and writes; the game runs with no best rating |

## 14. Decision log

| Date | Decision | By |
|---|---|---|
| 2026-11-06 | The faithful (private) version is served only to the owner, behind a login, at `icelander.net/recreations/zxspectrum/dictator`. That leaves `icelander.net/retro-games/…` free for the public remakes. | Owner |
| 2026-11-06 | The skill is named `create-retro-game`; the remake lives in `games/dictator/`. | Owner |
| 2026-11-06 | `docs/RULES.md` approved on merge (PR #4). | Owner |
| 2026-11-06 | RULES clarified from the designer's questions, checked against the baseline: affordability wording (§8.3); one execution screen after a lost war, headed by the helicopter's failure or the Neighbour's victory (§11); the joke skips the helicopter (§13.4); the rating's best includes this game (§14); platform keys such as M never reach the game (§15.1). | Spec role |
| 2026-11-06 | Title: *Sozoma*; later changed to *Samosa*. | Owner |
| 2026-11-06 | Setting: Nicaragua; the Neighbour is Honduras. Names in §4.2. | Owner |
| 2026-11-06 | The newsflash money quirk is switched off. | Owner |
| 2026-11-06 | Y is accepted in both cases. | Owner |
| 2026-11-06 | No request for permission from the original author's estate. | Owner |
| 2026-11-06 | Public address: `icelander.net/retro-games/samosa` (follows the title). | Owner |
| 2026-11-06 | The address moves to `icelander.net/games/retro/samosa`, beside the games page `icelander.net/games`; the old address redirects. | Owner |
| 2026-11-06 | Real parties and organisations are named; real people are not. Events are built on Nicaraguan history, caricatured. The ruling families are the puns Ortiga and Samosa; the player is President Ortiga; the Landowners faction becomes the Samosa family (rules unchanged). | Owner |
| 2026-11-06 | No "wait for a key on timed screens" setting. | Owner |
| 2026-11-06 | Credits name the remake's author as David Brandt. Headlines run under the real masthead *La Prensa*. | Owner |
| 2026-11-06 | State Security's screens (report, report offer) are dark: white type on black paper. | Owner |
| 2026-11-06 | After playtesting: every screen waits for a key (a newsflash went by too fast to read). Timed screens draw in full and play their sound, then show the any-key footer. | Owner |
| 2026-11-06 | After playtesting: one report offer a month, at the end of the turn (RULES §4 step 15). | Owner |
| 2026-11-06 | A public high-score table, keyed by the player's email: the table shows only the part before the @ (the full address is stored privately and never shown or shared); there is no email check; the server issues each reign's seed and replays the reign from its keys to compute the score, so scores can't be faked. | Owner |

## 15. Decisions (all closed)

| # | Decision | Options considered | Decided |
|---|---|---|---|
| 1 | The title | *President for Life*, *Tinpot*, *One More Month*, keep *Dictator* | ***Samosa*** (owner's own) |
| 2 | The setting and names | Splendoria, Brinmoor or Philatelia (fictional) | **Nicaragua and Honduras**, real organisations, pun-named families (§4) |
| 3 | The newsflash money quirk (RULES §9.4, §12) | Keep it on, or switch it off | **Off** |
| 4 | The case of the Y key (RULES §15.1) | Both cases, or lower case only | **Both cases** |
| 5 | Ask the original author's estate for permission | Ask, or rely on the clean-room work | **Don't ask** |
| 6 | The public address | `/retro-games/<title-slug>`, `/retro-games/dictator`, a subdomain | **`icelander.net/games/retro/samosa`** (first `/retro-games/samosa`) |
| 7 | A "wait for a key on timed screens" setting | Offer it, or not | First **not offered**; then, after playtesting, **every screen waits for a key**, for everyone (no setting) |
