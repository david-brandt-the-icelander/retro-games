# Canal lock remake: behaviour spec

Status: approved by the owner · Phase 1 of create-retro-game · Written by the spec role from the reference material, which is kept outside this repository.

This file describes what the original game does, in our own words. It quotes none of the original's text and uses none of its names. Where it says "the canal" or "the company", the remake chooses its own names in the GDD.

## 1. State

| Field | Meaning | Start value | Range |
|---|---|---|---|
| day | The current day of service | 1 | 1–21 |
| water | Water left in the upper pound | 5 | at most 9; below 1 ends the game |
| coins | The keeper's money | 50 | below 0 ends the game |
| goodwill | How the boat crews regard the keeper | 3 | below 1 ends the game |
| best | Longest service so far this session | 0 | never reset while the program runs |

## 2. Boat kinds

Each day exactly one boat arrives. There are four kinds:

| Kind | If let through: coins | water | goodwill |
|---|---|---|---|
| 1. Small family boat | +3 | −1 | +1 |
| 2. Heavy cargo boat | +6 | −2 | 0 |
| 3. Holiday party boat | +2 | −1 | +1 |
| 4. The company's inspector | −8 (he charges a fee) | −1 | +2 |

If the boat is turned away, only goodwill changes, by −1, whatever the kind.

## 3. One day

1. Draw the boat kind: one random draw, uniform over the four kinds.
2. Show the day screen (day number, water, coins and goodwill as they stand at the start of the day, the boat that has arrived, and the choice).
3. Wait for the choice (see Quirks: only `o` or `k`).
4. Apply the choice from the table in §2.
5. Draw for rain: one random draw, rain with probability 1 in 3. Rain adds 2 to water, and the rain notice is shown.
6. If water is above 9, set it to 9. The cap is applied after rain, every day.
7. End checks, in this order, stopping at the first that is true:
   1. water below 1: the canal has run dry
   2. coins below 0: the keeper is bankrupt
   3. goodwill below 1: the keeper is dismissed
8. Add 1 to day. If day is now above 20, the keeper retires (a win).
9. Otherwise show the next-day prompt, wait for any key, and start the next day at step 1.

## 4. End of a game

- Show the ending for the reason found (one of four, see §6).
- If day is greater than best, best becomes day. Day is the value *after* step 8, so a retirement records 21 and a loss on day 7 records 7.
- Show the best-service line, wait for any key, and return to the title screen. A new game starts from the start values in §1; best is kept.

## 5. Quirks (all part of the behaviour)

- **Input on the day screen:** only lower-case `o` (let the boat through) and `k` (turn it away) are accepted. Upper case and every other key are ignored, and the screen keeps waiting. Nothing is redrawn and no random number is drawn while it waits.
- **Title screen:** lower-case `i` opens a one-page help screen, which returns to the start of the game on any key; any other key starts the game straight away.
- **Order of checks:** water before coins before goodwill before the day limit. A day that empties both the pound and the purse ends as "run dry".
- **Rain can save the day:** rain is added before the water check, so a let-through that takes water to 0 or −1 is survived when it rains that day.
- **The inspector can bankrupt you** only by being let through; turning him away costs goodwill as usual.
- **Random draws:** exactly two per day, in this order: the boat kind, then rain. No other draws are made. The random source is a seeded generator kept in the game state (mulberry32, as in the web template), so a seed replays the same game.
- **Integer arithmetic only;** there is no truncation or rounding anywhere.
- **No timed screens:** every screen waits for a key.

## 6. Message purposes

The remake writes all text fresh. Each message the original shows, by purpose:

| # | When | Must tell the player | Size limit |
|---|---|---|---|
| 1 | Title | The game's name | 1 line |
| 2 | Title | A one-line invitation: keep the canal working | 1 line, ≤ 30 cols |
| 3 | Title | Author and publisher credit | 2 lines |
| 4 | Title | Which key opens the help page | 1 line |
| 5 | Help | Four short lines: boats arrive daily; letting them through earns tolls; every boat let through costs water; turning boats away costs goodwill | 4 lines, ≤ 32 cols each |
| 6 | Day | Day number and where the lock is | 1 line; placeholder `{day}` |
| 7 | Day | Water, coins and goodwill | 1 line; placeholders `{water}`, `{coins}`, `{goodwill}` |
| 8–11 | Day | Which of the four boat kinds has arrived, with a touch of character | 1–2 lines each |
| 12 | Day | The choice and its two keys | 1 line, ≤ 32 cols |
| 13 | After the choice, when it rains | Rain has fallen and the pound has risen | 1–2 lines |
| 14 | Before the next day | Press a key to go on | 1 line |
| 15 | Ending: run dry | The canal is empty; the boats are stranded | 1–2 lines |
| 16 | Ending: bankrupt | The keeper's money has run out and the house is taken | 1–2 lines |
| 17 | Ending: dismissed | The crews have complained and the company has sacked the keeper | 1–2 lines |
| 18 | Ending: retired | Twenty days completed; a comfortable retirement | 1–2 lines |
| 19 | Ending | The longest service so far, in days | 1 line; placeholder `{best}` |
