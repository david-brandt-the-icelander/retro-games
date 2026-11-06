# Dictator remake: behaviour spec

Status: phase 1 of `create-retro-game` · written by the spec role from the faithful baseline (private) · owner approval: _pending_

This document says **what the game does**: every state, rule, number, random draw and quirk. It says nothing about how it looks or what its text says; the GDD and UI design decide those. It contains no text from the original and none of its invented names.

- **Names in this spec:** neutral working names, chosen in the GDD. *The country* is the player's state; *the Neighbour* is the bordering state; *the East* and *the West* are the two superpowers.
- **Money** is counted in whole thousands of dollars ("units"). A value of 1000 is a million.

## 1. The groups

Eight groups, always in this order (the order matters for plots, wars and the help list):

| # | Group | Initial | Popularity | Strength | Role |
|---|---|---|---|---|---|
| 1 | Army | A | 7 | 6 | Domestic faction: may plot |
| 2 | Peasants | P | 7 | 6 | Domestic faction: may plot |
| 3 | Landowners | L | 7 | 6 | Domestic faction: may plot |
| 4 | Guerrillas | G | 0 | 6 | Always hostile; a ready-made ally for plotters |
| 5 | The Neighbour | N | 7 | 6 | The bordering state; can go to war |
| 6 | Secret police | S | 7 | 6 | Reports on plots; protects against assassins |
| 7 | The East | E | 7 | — | Superpower; lends once |
| 8 | The West | W | 7 | — | Superpower; lends once |

- **Popularity** is how well the group regards the President: 0–9, for all eight groups.
- **Strength** is the group's power: 0–9, for groups 1–6 only.
- Every change is applied and then **clamped to 0–9**.

## 2. The President and the treasury

| Value | Start | Notes |
|---|---|---|
| Treasury | 1000 | May go negative (in debt) |
| Monthly costs | 60 | Never below 0 |
| Swiss account | 0 | Only ever grows; counts in the rating only if the President survives |
| President's strength (bodyguard) | 4 | +2 per bodyguard decision, with **no upper limit**; −1 per bankrupt month (not below 0) |
| Month | 0 | Becomes 1 at the start of the first month |
| Helicopter | no | Bought by decision D12 |
| East loan / West loan granted | no / no | Each superpower lends at most once |
| Plot pause | 0 | Plots are suppressed while the month is below this |
| Last costed item | — | Original only; the remake does not keep it (§9.4) |

## 3. Monthly thresholds

At the very start of each month, before the month number goes up, roll two hidden numbers:
- **Threshold** (the *disaffection line*): 2, 3 or 4, equally likely. A group whose popularity is **at or below** it is *disaffected*.
- **Revolution strength:** 10, 11 or 12, equally likely. The player sees this number on every intelligence report.

## 4. The month, step by step

1. Roll the threshold, then the revolution strength (§3).
2. The month number goes up by one. **Month screen.**
3. **Plot check** (§6).
4. **Accounts** (§5). If bankrupt: **bankruptcy screen**, plot check, then a **report offer** (§7).
5. **Audience** (§8): choose a request, show it, offer advice, then the decision dialog. The treasury report follows.
6. Plot check.
7. **Assassination check** (§10).
8. **War check** (§11). This runs even after a failed assassination attempt.
9. Plot check.
10. Report offer.
11. **Presidential decision** (§9): at most one, possibly none.
12. Plot check, then a report offer.
13. **News check** (§12). If news happens: the news screens, plot check, report offer.
14. **Revolution check** (§13).
15. Next month.

A game ends only by death or escape. There is no time limit and no victory condition.

**Before month 1:** a welcome screen showing the best rating so far, then a treasury report and a free intelligence report. That first report shows no plots and the revolution strength from before the first roll, 10.

**After the end:** the death screens, then (if the President died) the funeral, then the rating (§14), then a **final** intelligence report, then back to the title.

## 5. Accounts

- If the treasury is **negative**, the government is **bankrupt** and nothing is paid. Army popularity −1, secret police popularity −1, secret police strength −1, President's strength −1 (each not below 0).
- Otherwise, if the treasury is **positive**, it pays the month's running costs. That may push it into debt, and the penalty then comes a month later.
- A treasury of **exactly 0** neither pays nor is penalised.

## 6. The plot check

1. In months 1 and 2: nothing happens. Statuses stay as they are, which is all clear at the start.
2. Otherwise every domestic faction's status is cleared to *no plot*.
3. If the month is below the plot pause: stop. All stay clear.
4. Otherwise, for each domestic faction (Army, Peasants, Landowners) that is **disaffected** (popularity ≤ threshold):
   - Look for an **ally** among groups 1–6, in order, skipping the faction itself and any group that is not disaffected. The first whose strength plus the faction's strength is **at least the revolution strength** becomes the ally, and the faction plans a **revolution**.
   - If no group qualifies, the faction plans an **assassination**.

## 7. Intelligence reports

A **report offer** asks whether to buy a report.

**Availability:** the report is available only if the treasury is **positive**, the secret police's popularity is **above** the threshold, and their strength is **above** the threshold.

- **If available:** a yes costs 1 (a thousand dollars) and shows the report. Any other answer skips it.
- **If not:** the offer says it's unavailable and lists every failing reason:
  - the police's popularity (with its value)
  - the police's strength (with its value)
  - that the treasury can't pay

**The report shows:**
- the month number
- every group's popularity, and the power (strength) of groups 1–6
- for each domestic faction, whether it plots a **revolution** (with its ally's group number) or an **assassination**
- the President's strength
- this month's revolution strength

It never shows the threshold.

## 8. The audience

### 8.1 Choosing the request
Requests R1–R24 are in three blocks of eight: Army R1–8, Peasants R9–16, Landowners R17–24. Each has a *used* mark.

1. Draw a starting point from 1–24.
2. Take the first **unused** request from there onward, wrapping from 24 to 1, looking at **22 places at most** (the start and the next 21).
3. If none of those 22 is unused, mark all 24 unused and go back to step 1.

The chosen request is marked used at once, whatever the answer. A request left unseen near the end of a cycle can therefore be skipped when the marks reset.

### 8.2 Advice
After the request is shown, a yes/no offer of **advice**. Yes shows the request's popularity and strength changes (non-zero entries only), with the requester's own popularity line marked. Advice is free and changes nothing.

### 8.3 The decision dialog and affordability
The dialog shows the requester, the request and its money:
- the one-off change ("adds/takes … from the treasury")
- the monthly change: whether running costs go up or down, and by how much
- both together, or a statement that none of this costs anything

(In the original, showing it also recorded the item as the **last costed item**; the remake drops that, §9.4.)

**Affordable?**
- If treasury + one-off change > 0: affordable.
- Otherwise, if the item costs money (a negative one-off change, or a monthly change that raises costs) and either treasury + one-off change < 0 or treasury − the rise in monthly costs < 0: **not affordable**. (An item that lowers monthly costs counts as a negative rise, so it never fails the second test.)
- Otherwise affordable.

| Situation | What happens |
|---|---|
| **Affordable** | The dialog waits for an answer. Yes grants the request; anything else refuses it. |
| **Not affordable** | The dialog shows by itself for a few seconds, without a yes prompt. Then a *cash short* note (§16), then a *must refuse* note. The request is then **refused**. |

### 8.4 Granting and refusing
- **Granting** applies the request's popularity and strength changes, then its money: the one-off change to the treasury, the monthly change to monthly costs (not below 0).
- **Refusing** lowers the **requester's** popularity by exactly the amount it would have gained. Nothing else changes.

Then the treasury report.

## 9. Presidential decisions

### 9.1 The menu
- **Five sections:**
  1. favour one group (D1–D6)
  2. favour everyone (D7–D9)
  3. improve the President's odds (D10–D13)
  4. raise money (D14–D16)
  5. strengthen one group (D17–D19)
- **Choosing a section:** keys 1–5 choose; any other key means no decision this month.
- **Inside a section:**
  - Options keep fixed numbers by position within the section. Used options are hidden but don't renumber the rest.
  - If every option is used, a note says so for a few seconds, then back to the menu.
  - Pressing an unlisted or used option's number goes back to the menu.
- **For a normal option:** an advice offer (§8.2), then the decision dialog with affordability (§8.3).
  - Yes applies it.
  - Any other answer goes back to the menu.
  - **Not affordable:** the dialog shows for a few seconds and the cash-short note follows, then back to the menu.
- **One-time use:** every option is used once taken, except D11 (bodyguard) and D13 (Swiss), which can be taken any number of times.

### 9.2 Special options (no advice, no dialog; each ends the decision phase)

**D13, the Swiss account:**
- Moves floor(treasury ÷ 2) to the Swiss account, if that is at least 1. Otherwise nothing moves.
- A screen reports the treasury before, the amount moved, and then the treasury lines.

**D14, East loan / D15, West aid:**
1. A short wait screen.
2. **Too early** if the month is below 3 + a draw from 0–4.
3. Otherwise **no more** if that power has already lent; this can't actually be reached, because a granted loan leaves the menu.
4. Otherwise **refused** if that power's popularity is at or below the threshold.
5. Otherwise **granted**: popularity × 30 + a draw from 0–199 is added to the treasury, and that loan option is used (hidden from now on).

After the result, the treasury report.

### 9.3 After any decision
- After a normal decision: the treasury report, then the plot check and a report offer (§4 step 12).
- D11 (bodyguard): applies its changes **and** raises the President's strength by 2. It is never marked used.
- D12 (helicopter): gives the President the helicopter.

### 9.4 The last costed item (an original quirk, switched off in the remake)
The original remembers the money of the **last item whose decision dialog was shown**: this month's request, or any presidential option that reached its dialog, whether or not it was taken or affordable. A newsflash applies that money again (§12). **The remake switches this off** (owner decision): a newsflash changes only popularity and strength. The remake need not track the last costed item at all.

## 10. Assassination

1. Pick one domestic faction at random (1 of 3).
2. If it doesn't plan an assassination, nothing happens.
3. Otherwise an **attempt**:
   - If all three domestic factions plan assassinations: the President is **killed**.
   - Otherwise, if the secret police's popularity is at or below the threshold **and** their strength is at or below the threshold: a coin flip (pick(2)): the President is killed on a 0 and survives on a 1.
   - Otherwise the attempt **fails**. The game goes on, and the war check still follows.

## 11. War with the Neighbour

**Hostility:** the Neighbour is *hostile* if its popularity is at or below the threshold **and** its strength is at or above the threshold. If not hostile, nothing happens.

**If hostile,** one chance in three of **invasion**; otherwise a **threat of war**.

**Threat of war:** popularity +1 for the Army, Peasants, Landowners **and** secret police.

**Invasion:** both sides' strengths are shown.
- **The country:** the President's strength, plus the strengths of Army, Peasants, Landowners and secret police, counting each only if its popularity is above the threshold.
- **The Neighbour:** the strengths of all groups 1–6 whose popularity is at or below the threshold, added up. This includes the guerrillas, the Neighbour itself and any disaffected domestic group.
- **The Neighbour wins** if its total plus a swing of −1, 0 or +1 is **at least** the country's total.

**Results:**
- **The country wins:** the Neighbour's strength becomes 0, and the game goes on.
- **The Neighbour wins:**
  - with a helicopter: 2 chances in 3 to escape (alive)
  - otherwise, or if the helicopter fails: the President is executed (dead). This is one screen: when the helicopter failed, its heading says so; otherwise its heading says the Neighbour has won. There is no separate helicopter-fails note here (that 3 s note belongs to §13.3 only).
  - there is no escape on foot after a war

## 12. News

1. One chance in three each month; otherwise nothing.
2. Draw a starting point from N1–N6 and take the first unused headline from there, wrapping, looking at all 6. If all six are used, no news.
3. The headline is marked used. Headlines never reset.
4. Apply its popularity and strength changes. Nothing else changes: no money moves (§9.4, the original's money quirk is switched off).

**Screens:** an alert with no key wait, then the headline.

## 13. Revolution

### 13.1 Who rises
Make up to three picks of a random domestic faction (1 of 3). The first pick that plans a revolution rises, together with its ally. If none of the three does, no revolution this month.

### 13.2 The alarm and the escape question
- A revolution alarm, shown for a few seconds by itself.
- Then: **attempt escape?**
  - **Yes:** escape (§13.3). The game always ends.
  - **Any other key:** fight (§13.4).

### 13.3 Escape
- **With a helicopter:** it starts 2 times in 3, and the President escapes alive. If it fails, a note says so, then on foot.
- **On foot over the mountains to the Neighbour:** draw u in [0, 1); the President is **caught** if floor(u × (guerrilla strength ÷ 3 + 0.4)) is **not 0**.
  - Caught means dead; otherwise the President escapes alive.
  - With 0 guerrillas the escape always succeeds. At strength 3 about 29% are caught, at 6 about 58%, at 9 about 71%.

### 13.4 Fighting
1. **Help screen:** shows the rebels, their ally and their combined strength, and lists the groups 1–6 whose popularity is **above** the threshold, numbered by group order.
   - **If none are listed:** there is no numbered list and no key is read for it. One screen shows the rebels' lines and a "you are alone" note, and waits for a key; then the fight goes ahead without a helper. (The engine emits only the *alone* screen here, not a help list.)
   - **Otherwise:** the player presses 1–6, and other keys are ignored until one of these comes.
     - A listed group becomes the **helper**.
     - An **unlisted** number (a disaffected group): a "joke" note, and the President must flee on foot (§13.3), so the game ends. An owned helicopter is **not** tried: it goes straight to the mountains.
2. **Strength summary:** the President's strength, the helper's strength and the rebels' combined strength, shown for a few seconds. (The original shows this summary and the start of the revolution as two screens; the baseline merges them into one. The remake follows the original: see §15.6.)
3. **The revolution starts.** It is **crushed** if the rebels' strength is at most the President's plus the helper's (0 without a helper), plus a swing of −1, 0 or +1. Otherwise the President is **overthrown** (dead).
4. **If crushed:**
   - Ask whether to **punish** the rebels. Yes sets popularity and strength to 0 for the rebel faction and its ally.
   - The helper's **strength** becomes 9.
   - The plot pause becomes month + 2.
   - Then the plot check and a report offer. The month ends.

## 14. Ending and rating

**Endings:**

| Ending | Alive? |
|---|---|
| Killed by an assassin, overthrown, caught on the mountains, or executed after a war | Dead |
| Escaped by helicopter (after a revolution or a lost war), or on foot | Alive |

**A dead President** first gets a funeral: a tune of mourning, then the rating.

**The rating** is the sum of:
- all eight popularities
- 3 for every month ruled
- **if alive:** 10, plus floor(Swiss account ÷ 10), so one point per $10,000

The dead don't see the alive and money lines at all.

**The best rating** is kept between games (in the browser) and shown on the welcome screen. The rating screen's "best so far" already includes this game: it is the larger of the stored best and this total. The stored best is updated once the game is over. Then comes the final intelligence report.

## 15. Quirks: keep these exactly

### 15.1 Input
- **One key per prompt.** Prompts never take typed lines.
- **Yes:** only the **Y** key means yes. Every other key means no, or "next". The baseline accepts Y in either case. The original read the keyboard as typed, so only a lower-case y counted while caps lock was off. The remake accepts both cases (owner decision), as the baseline does.
- **Any key:** wherever a screen waits, any key continues, and a key that doesn't fit the prompt counts as "no". On touch screens, tapping the screen counts as any key.
- **The decision menu:** 1–5 choose a section; any other key means no decision this month.
- **Inside a section:** a number that isn't an available option goes back to the menu, without an error.
- **Asking for help:** only 1–6 are accepted, and other keys are ignored. An unlisted number is accepted and is a joke (§13.4).
- **Keys outside the game:** the remake's platform layer may reserve keys of its own (such as a sound toggle). Such a key never reaches the game, so it is neither "no" nor "next"; parity tests never send it.

### 15.2 Arithmetic
- Money is whole thousands. Integer division rounds down: the Swiss transfer takes floor(treasury ÷ 2), and rating points for money are floor(Swiss ÷ 10).
- Every change to a **group's** popularity or strength is clamped to 0–9 after each one. The **President's** strength is not: it never drops below 0 but has no maximum, so four bodyguards make 12 (this counts in war and revolt totals). Running costs never go below 0.
- Disaffected means popularity **≤** the threshold, and the plot ally test is **≥** the revolution strength. Hostility needs popularity ≤ the threshold and strength **≥** the threshold.
- The war and the revolution compare with a −1/0/+1 swing (§11, §13.4).

### 15.3 The order of checks
- Each month follows exactly §4.
- The plot check runs at the points listed there, so the statuses a report shows are as of the most recent check.
- The accounts check debt (bankrupt) before credit (pay).
- In an assassination attempt, the all-three test comes before the police test.
- In a loan request, the checks run in this order: too early, no more, refused, granted.

### 15.4 Random numbers: generator and draw order
Parity testing needs the remake to draw exactly the same random numbers, in the same order, as the baseline.

**The generator:** one stream per game, seeded at the start, which is the baseline's own convention.
- The state is a 32-bit unsigned integer, the seed.
- A draw adds 0x6D2B79F5 (mod 2³²) to the state, then mixes: `t = state; t = imul(t ^ (t >>> 15), t | 1); t ^= t + imul(t ^ (t >>> 7), t | 61); u = ((t ^ (t >>> 14)) >>> 0) / 2³²`.
- **pick(n)** = floor(u × n), giving 0…n−1.

**The draws, in order:**

| When | Draws |
|---|---|
| Start of each month | pick(3) for the threshold (+2); pick(3) for the revolution strength (+10) |
| Choosing the request | pick(24) for the start; again after each reset |
| Assassination check | pick(3) for the faction; then, **only if** an attempt is made, not all three plot, and the police are both unloved and weak, pick(2), where 0 means killed |
| War check (only if hostile) | pick(3), where 0 means invasion. If invading: pick(3) for the swing (value − 1). If the war is lost and there is a helicopter: pick(3), where 0 means the helicopter fails |
| Loan request | pick(5) for the "too early" test, always. **Only if** the loan is then granted: pick(200) |
| News check | pick(3), where 0 means news. Only then pick(6) for the start |
| Revolution check | Up to three pick(3), stopping at the first faction that plans a revolution |
| Escape | Helicopter: pick(3), where 0 means it fails. On foot: one raw draw u |
| Fight | pick(3) for the swing (value − 1) |

Nothing else draws: not advice, dialogs, reports, the Swiss transfer or plots.

### 15.5 Pacing (from the original's pauses)

**Waits for a key:**
- title, welcome
- treasury reports
- intelligence reports, and an available report offer
- audience, advice offer and advice, an affordable decision dialog
- decision menu and sections
- the result of a loan request
- escape question, help list, "you are alone"
- punish question, rating, final report
- the funeral (a remake addition: it waits for a key, as the baseline's does)

**Moves on by itself:**

| Screen | Shown for about |
|---|---|
| Month | 1 s |
| Bankruptcy notice | 5 s |
| Unaffordable dialog | 5 s |
| Cash-short note | 7 s |
| Must-refuse note | 5 s |
| "Section used up" note | 3 s |
| Loan wait | 1 s |
| News alert | 6 s |
| News headline | 2 s |
| Revolution alarm | 5 s |
| Helicopter-fails note | 3 s |
| Mountains | 4 s |
| Joke note | 3 s |
| Strength summary | 5 s |
| Swiss transfer | 2 s, then the treasury lines appear and it waits for a key |
| Unavailable report offer | its sound |
| Threat of war | its sound |
| Invasion (both strengths) | its sound (the short war) |
| Assassination attempt and result, war result, revolution start, helicopter escape, caught or escaped on foot | their sound effect |
| Death screens | their sound, then the funeral |

The baseline waits for a key on several of these. The remake follows this table; the GDD may lengthen a time, but should not shorten it.

### 15.6 Deliberate differences from the baseline
Parity testing compares the remake with the faithful baseline. These differences are intended, because they restore the original or are the remake's own choices. Every other difference is a bug.

| Difference | Why |
|---|---|
| Screens that move on by themselves (§15.5), where the baseline waits for a key | Restores the original's pacing. The game state is unaffected. |
| A separate strength summary screen before the revolution starts (§13.4) | Restores the original's two screens. The baseline shows one. |
| Y in either case (§15.1) | Same as the baseline; owner decision. |
| A newsflash moves no money (§9.4, §12) | Owner decision. Parity runs the baseline with its news-money switch **off**. |

## 16. Message purposes

Each message is described by its purpose; the UI design writes the words to fit. Every line must fit 32 columns.

| Screen | When | Must convey |
|---|---|---|
| Welcome | Before the first month | The best rating so far, and an encouragement: to beat it, or for a first attempt. That the first treasury and intelligence reports are free. |
| Month | Start of each month | The month number. |
| Treasury report | After the welcome, the audience and decisions | Treasury balance, as credit or as debt; monthly costs; the Swiss balance once it is above 0. |
| Intelligence report | When bought, at the start, at the end | Everything in §7; *final* instead of the month on the last one. |
| Report offer | §4 | Ask whether to buy a report for 1 (a thousand); or that none is available, with each reason and its value. |
| Bankruptcy | §5 | The treasury is empty; the army's and police's goodwill, police strength and the President's own strength will each drop. |
| Audience | §8 | Which faction asks, and what it asks for. |
| Advice offer and advice | §8.2 | Ask whether to show advice; the request and each non-zero popularity and strength change, with the requester's own line marked. |
| Decision dialog | §8.3, §9.1 | Who asks (for requests) and what; the money: one-off and monthly, or none; a yes prompt when affordable. |
| Cash short | Not affordable | The item; that the money isn't in the treasury; a hint to ask the East or the West for each loan not yet granted. |
| Must refuse | Unaffordable request | That the funds are insufficient, so the answer must be no. |
| Decision menu and sections | §9.1 | The five sections; a section's available options with their numbers; a note when a section is used up. |
| Swiss transfer | D13 | The treasury before and the amount moved; or that nothing moved; then the treasury lines. |
| Loan wait and result | D14, D15 | An application is being considered; then: too early; no more; refused (a curt refusal in each power's own style); or the amount granted. |
| News alert and headline | §12 | A news alert; then the headline (from the N table's topic). |
| Assassination attempt and result | §10 | Which faction's assassin; then killed, or survived. |
| Threat of war | §11 | War threatens, and the home groups rally (popularity rises). |
| Invasion and result | §11 | Both sides' strengths; a short war; then won or lost. |
| Helicopter escape | §11, §13.3 | The President got away by helicopter. |
| Execution | After a lost war | Without a helicopter, or if it fails: condemned as a traitor and shot. The heading says the helicopter failed, or else that the Neighbour won. |
| Revolution alarm | §13.2 | A revolution has broken out. |
| Escape question | §13.2 | Ask whether to try to escape. |
| Help list | §13.4 | Who has risen with whom, their combined strength, and who can be asked for help (numbered). |
| Alone, or joke | §13.4 | No one will help; or that the choice is absurd. |
| Strength summary and start | §13.4 | The President's, helper's and rebels' strengths; then the fight begins. |
| Overthrown | §13.4 | Overthrown and killed. |
| Crushed and punish | §13.4 | The revolt is crushed; ask whether to punish the rebels. |
| Helicopter fails, mountains, caught, escaped | §13.3 | the helicopter fails to start; the trek over the mountains; the guerrillas caught the President and celebrate; or they missed. |
| Funeral (remake addition) | A dead President | Mourning, and how long the rule lasted. |
| Rating | End | Total popularity; months × 3; if alive: 10 for surviving, and the money points; the total; the best so far. |

## 17. The data

The numbers below are the game's balance, restated from the baseline in this layout. The topics are working descriptions for the GDD, not text to show.

- **Changes:** popularity and strength changes are listed by group initial (A, P, L, G, N, S, E, W; §1). For example, `A+4 P−3` means Army +4, Peasants −3.
- **Once:** added to (+) or taken from (−) the treasury when granted, in thousands of dollars.
- **Monthly costs:** raises (+) or lowers (−) the monthly costs, in thousands.
- **Order matters:** it drives the request choice (§8.1), the decision sections and the news choice (§12).

### Requests

| # | From | Topic | Popularity | Strength | Once | Monthly costs |
|---|---|---|---|---|---|---|
| R1 | Army | make military service compulsory | A+4 P−3 L−1 | A+3 P−2 L−1 | — | +5k |
| R2 | Army | seize farmland as army training grounds | A+3 L−3 | A+1 L−1 | — | — |
| R3 | Army | a campaign against rebel camps at home | A+3 P−1 L+1 N−1 E−1 | A+1 L+1 G−4 | −100k | — |
| R4 | Army | a cross-border raid on rebel camps in the Neighbour | A+3 P−1 N−4 E−1 | A+1 L+1 G−2 | −80k | — |
| R5 | Army | dismiss the head of the secret police | A+4 P+2 L+1 S−4 | A+1 L+1 S−3 | — | — |
| R6 | Army | send home the East's military advisers | A+3 N−1 E−4 W+2 | — | — | — |
| R7 | Army | a pay rise for the soldiers | A+4 L−1 | A+2 P−1 L−1 G−1 | — | +9k |
| R8 | Army | new weapons and ammunition | A+4 P−1 L−1 N−1 S−1 | A+3 P−1 L−1 G−2 N−1 | −120k | — |
| R9 | Peasants | end forced recruitment into the army | A−1 P+2 L+1 | A−1 G−1 | — | — |
| R10 | Peasants | a higher legal minimum wage | P+4 L−4 N+1 | P+2 L−1 | — | — |
| R11 | Peasants | curb the secret police | A+1 P+4 L+2 S−4 | A+1 P+1 L+1 G+1 S−3 | — | −3k |
| R12 | Peasants | bar migrant labour from the Neighbour | P+3 L−2 N−2 | P+2 L−2 | — | — |
| R13 | Peasants | free schooling for every child | A−1 P+4 L−2 N+2 S−1 E+1 | P+1 L−1 G−1 | −100k | +8k |
| R14 | Peasants | the right to form trade unions | P+4 L−3 N+1 S−1 E+1 | P+3 L−3 S−1 | — | — |
| R15 | Peasants | release their jailed leader | A−1 P+4 L−2 N+1 S−1 | P+2 L−1 G−1 | — | — |
| R16 | Peasants | a state lottery | P+3 L−1 | G−1 | — | −6k |
| R17 | Landowners | keep the army off their estates | A−2 L+3 | A−1 | — | — |
| R18 | Landowners | a lower legal minimum wage | P−4 L+4 N−1 E−1 | P−2 L+2 G+1 | — | — |
| R19 | Landowners | seize companies owned by the West | L+3 N+1 E+2 W−4 | L+1 | +100k | +5k |
| R20 | Landowners | a tariff on goods from the Neighbour | L+3 N−3 E−1 | P+1 L+2 N−1 | — | −5k |
| R21 | Landowners | a smaller secret police budget | A+1 P+1 L+3 S−4 | A+1 L+1 G+1 S−2 | — | −4k |
| R22 | Landowners | lower taxes on land | L+4 | L+2 | — | +5k |
| R23 | Landowners | lend soldiers to the estates as farm labour | A−2 P−1 L+3 | A−1 P−1 L+1 G+1 | — | — |
| R24 | Landowners | a large irrigation scheme | A+1 P+1 L+3 N−3 E+2 W+1 | L+3 N−2 | −120k | +10k |

### Decisions

| # | Section | Topic | Popularity | Strength | Once | Monthly costs |
|---|---|---|---|---|---|---|
| D1 | 1 | promote the army commander to deputy head of state | A+4 P−1 L−1 S−1 | A+1 G−1 S−1 | — | — |
| D2 | 1 | free health clinics for workers | A−1 P+4 L+1 N+2 E+1 | G−1 | −10k | +4k |
| D3 | 1 | regional authority for the landowners | A−1 P−2 L+4 S−1 E−1 | A−1 P−1 L+2 S−1 | — | — |
| D4 | 1 | sell Western-made weapons to the Neighbour | A−2 N+4 E−2 W+1 | A−1 G−1 N+3 | +50k | — |
| D5 | 1 | sell mining concessions to Western companies | L−1 N−1 E−2 W+3 | — | +120k | — |
| D6 | 1 | lease a naval base to the East | A−2 E+3 W−3 | N+1 | — | −10k |
| D7 | 2 | a general tax cut | A+1 P+3 L+3 | A−1 G−1 | — | +8k |
| D8 | 2 | a large publicity campaign | A+3 P+3 L+3 | G−1 | −80k | — |
| D9 | 2 | strip the secret police of all its powers | A+3 P+3 L+3 S−9 | A+2 P+1 L+1 G+1 S−9 | — | −8k |
| D10 | 3 | give the secret police sweeping new powers | A−3 P−3 L−3 S+8 | A−1 P−1 L−1 G−1 S+8 | — | +6k |
| D11 | 3 | enlarge the President's bodyguard (repeatable) | A−2 P−1 L−1 S−1 | A−2 S−1 | −40k | — |
| D12 | 3 | buy a helicopter for escaping | A−4 P−4 L−3 S−2 | — | −120k | — |
| D13 | 3 | move half the treasury to a Swiss account (repeatable) | — | — | — | — |
| D14 | 4 | ask the East for a loan (special) | — | — | — | — |
| D15 | 4 | ask the West for aid (special) | — | — | — | — |
| D16 | 4 | seize businesses owned by the Neighbour | A+1 P+1 L+3 N−6 E−2 | — | +130k | — |
| D17 | 5 | heavy guns for the army | A+3 N−3 E−1 | A+5 G−2 N−2 S−1 | −50k | — |
| D18 | 5 | freedom of movement for the peasants | P+3 L−1 S−1 | P+5 L−1 G+3 S−1 | — | — |
| D19 | 5 | a private militia for the landowners | A−1 P−1 L+3 S−1 | A−1 P−1 L+5 G−1 S−1 | — | — |

### News

| # | Topic | Popularity | Strength |
|---|---|---|---|
| N1 | the President mislays the secret police's files | S−4 | G+4 S−4 |
| N2 | a foreign revolutionary state arms and trains the rebels | — | A−1 G+9 |
| N3 | an explosion wrecks an army barracks | — | A−4 G+2 S+1 |
| N4 | the price of the country's export crop collapses | — | L−3 N−2 |
| N5 | an earthquake strikes the Neighbour | — | L+2 N−4 |
| N6 | an epidemic among the peasants | — | P−4 L−1 G−2 |
