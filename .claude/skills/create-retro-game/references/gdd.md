# The game design document

The GDD decides everything about the remake that isn't a rule. RULES.md says *what the game does*; the GDD says *what the game is*: its name, its world, its voice, its screens and its sounds. It is written by the designer from RULES.md, never from the original.

## What it must decide

| Section | Decides | Notes |
|---|---|---|
| Identity | Working title, three title proposals, a one-line pitch, the factual credit line | Keep the original title only if the owner accepts the risk (it's often a common word, which is a weak mark; say so). |
| Pillars | 3–5 principles to settle arguments later | Always include "plays the same, looks new". Others are usually about tone (satirical? grim?), session length, and the platform's feel. |
| Same and new | A two-column list: kept (rules, numbers, quirks, the platform's hardware look) and renewed (text, names, layouts, art, sound, code) | This is the contract the later phases check against. |
| Setting and names | The world the new text lives in, and every invented proper noun | Rename every *distinctive* invented name from the original: places, factions, characters, items. Keep generic words. Record old → new in PROVENANCE.md, not in public docs, if the repo is public. |
| Player experience | Who plays, for how long, on what device; the emotional arc of a session | A strategy game of the period often lasts 5–20 minutes and ends in disaster: design for repeat play. |
| Core loop | A short restatement of the turn structure from RULES, in player terms | Links back to RULES sections; no new rules. |
| Screen list | Every screen the player can see, with an id, its purpose, and how you reach it | The wireframes phase must cover exactly this list. Include the extras the remake adds (About, how to play, settings) and mark them as additions. |
| Text budget | One row per message: id, when it appears, what it must convey, max columns × lines, tone, placeholders | Written from RULES' message purposes. The UI design phase writes the words to fit. |
| Audio list | Every sound: id, trigger, purpose, length, character | New melodies only; generic effects (clicks, sweeps) are fine. |
| Platforms and controls | Desktop keyboard, touch, screen sizes, offline, browsers | Keep the original's key semantics (they're gameplay); add touch equivalents. |
| Accessibility | Screen-reader text, flash rate (under 3 Hz), contrast, timing, no reliance on sound | |
| Scope and non-goals | What is deliberately not done: save games, difficulty modes, "improvements" | Improvements to the rules are never in scope; offer them as open decisions instead. |
| Risks | Legal (closeness of look, names), technical, design | |
| Decision log | Date, decision, by whom | Every gate's outcome goes here. |

## Writing the text budget

Work from RULES' list of message purposes. For each message:
- **Conveys:** the facts and the feeling, e.g. "the treasury can't pay; the request must be refused; mild humiliation".
- **Budget:** the columns and lines the screen allows. The wireframes may tighten it.
- **Placeholders:** the numbers or names it shows, e.g. `{group}`, `{amount}`.
- **Tone:** e.g. "pompous official", "deadpan", "tabloid headline".

Don't write the final words here; that happens in the UI design. If you knew the original's wording, don't let it leak into the "conveys" column: describe the purpose, not the phrasing.

## Example (invented game)

> **Identity.** Working title *Keeper*. Proposals: *Keeper*, *Lamp & Rock*, *The Long Watch*.
> Credit: "Inspired by *Lighthouse* (1984) by A. Author, published by Example Soft. Independent remake, not affiliated with or endorsed by the original rights holders."
>
> **Pillars.** Plays the same, looks new. Every night is a story worth telling. One more night.
>
> | id | When | Conveys | Budget | Tone |
> |---|---|---|---|---|
> | storm-warning | A storm event is rolled | A storm is coming; the lamp oil drops by `{n}` | 32×2 | Terse logbook |
