# MEG: The Current Remembers

An original cartoon shark game for the browser, on desktop and phone. You are the last megalodon. A warm current has hidden your kind for millions of years, and a shadowy agency, the Directorate, is closing in. Stay fed, stay hidden and protect the current across eight incident files.

MEG is not a remake: its story, characters and look are its own.

## Play

At [icelander.net/games/retro/meg](https://icelander.net/games/retro/meg/), signed in to icelander.net (the games are part of the site; the Worker checks the sign-in with `vendor/icelander-auth/`).

The game is one page, `public/index.html`, with its stylesheet `public/meg.css` and one script, `public/meg.js`: the cartoon art is drawn as vector shapes on a canvas at the screen's full pixel density, and the sound is synthesized. The only things it loads from outside are three Google Fonts (Lilita One, Nunito and Special Elite), and it falls back to system fonts without them.

## Controls

| Action | Keyboard | Phone | Gamepad |
|---|---|---|---|
| Turn counterclockwise / clockwise | ← → or A D | ↺ ↻ (bottom left) | Left stick or d-pad |
| Speed up (hold), slow down (release) | Space (also ↑ or W) | SWIM (bottom right) | A or right trigger |
| Pause | P or Esc | PAUSE | |
| Sound on/off | M | SOUND | |

Everything else is automatic:

- **Biting:** the jaws snap shut on anything edible the mouth touches, including the swimmers bobbing at the surface, who panic and draw attention when they spot the shark.
- **Breaching:** hit the surface heading upward at full speed (the speed bar turns yellow) and the shark leaps clear of the water. Landing on a deck damages the ship. At full speed the shark also rams hulls from below.
- **Hiding:** inside the glowing warm current, nothing can see the shark.

## How it plays

Strength drains all the time, from 1.5 a second at rest to 5 a second at full speed; eating restores it. Every live catch leaves a ragged blood cloud that drifts apart and thins out. A whale dies at the first bite, which takes a chunk out of it; the carcass rolls belly-up and floats up, can be bitten on the way, and raises exposure sharply when it reaches the surface. Exposure rises when lights, sonar, cameras or spotlights catch the shark, and falls when it hides deep or in the current. When exposure fills, a hunter fleet drops depth charges for a while. A charge tumbles down and bursts in a bubble blast when it touches anything (the shark, fish, a whale, the sub, the seabed) or at a random depth at least a third of the way from the surface to the seabed. Each file opens with a redacted Directorate document that a teleprinter types out, with key clacks, heavier strikes on the redactions, a bell and carriage return at each line and a double ding at the end; tap it to skip. Each file closes with a cover-story memo.

## Prey and score

Every catch scores points, more for bigger or more darkly funny prey. A cleared file adds a bonus of 500 × the file number plus 10 per point of strength left. The score carries through a run of files and ends when the shark fails, after the last file, or with End run.

| Prey | Points | Strength | Where |
|---|---|---|---|
| Reef fish | 10 | 10 | Everywhere, in schools |
| Squid | 20 | 16 | Schools |
| Cod, haddock | 25 | 14 | Schools; the trawler's net is full of them |
| Salmon | 40 | 18 | Schools |
| Whale | 100 a bite, up to 6 | 25 a bite | File 4 |
| Seal | 120 | 28 | Near the surface |
| Seagull | 150 | 12 | Above the waves; only by breaching |
| Manta ray | 150 | 32 | Mid-water |
| Dolphin | 200 | 30 | Pods of two or three; they flee and leap |
| Puffin | 200 | 12 | Above the waves; only by breaching |
| Swimmer | 250 | 45 | At the surface; they panic and draw attention |
| Scuba diver | 300 | 45 | Now and then, deep |
| Greenlandic kayaker | 400 | 50 | At the surface, in a qajaq |
| Polar bear | 500 | 45 | Swimming at the surface; swipes back |

Visitors wander in over time and leave again; swimmers and kayaks keep clear of boats. Sabotage scores too: buoys, ships, the sub, drums, turrets and drones.

On icelander.net the high-score table is shared: when a run ends, the player enters a name and the score goes to the table, which the game, the public page at [/games/retro/meg/scores/](https://icelander.net/games/retro/meg/scores/) and icelander.net's games pages show. A copy opened from disk keeps its table on the device instead.

The server cannot replay a run, so it trusts the score within limits it can check: each run gets a ticket from the server when it starts, a ticket takes one score, no sooner than five seconds and no later than a day after it was issued, and the score must be one the time since the ticket could have earned (150 points a second, plus every clear bonus up to the file reached). A determined cheater could still post a plausible score; replay-checking is a backlog item.

## Files to clear

Meeting a file's goal starts a 10-second countdown, shown on screen. The game carries on, and dying before it runs out loses the file. A file never ends while you are being hunted: if the countdown runs out with the hunter fleet still on your trail (or the file 7 hunter still enraged), the timer reads LOSE THE HUNTERS and the file closes only once they lose you.

| File | Goal |
|---|---|
| 1 The Trawler at Night | Eat 12 fish and shred the trawler's net (six bites tear it apart and free the fish inside). Sinking the trawler loses the file |
| 2 Buoy Line | Destroy 5 sonar buoys |
| 3 The Photographer | Survive 120 seconds. A dive boat races about above and drops divers in behind you, closer and more accurately the more exposed you are, and it never runs out: eat one and it sends another. A diver photographs you if you come within half a screen of him outside the current; with a photo he races back at 70% of your top speed, and if he climbs aboard with it you lose |
| 4 Whale Migration | Take 8 bites of whale |
| 5 The Research Sub | Cut the sub's tether, or lure it over the hot vents |
| 6 Cover-Up | Sink 2 dumping ships before the current goes cold |
| 7 Storm Breach | Bring down the hunter ship |
| 8 The Directorate's Base | Destroy 3 turrets and free the young one |

Progress (the highest file reached), the sound setting, the high-score table and the last name entered are kept in the browser's `localStorage`.

## Files

| Path | What it is |
|---|---|
| `public/index.html` | The page: the canvas, HUD, touch controls and menu overlay |
| `public/meg.js` | The whole game: audio, input, entities, the eight files, the simulation loop, drawing, scoring and the menu screens |
| `public/meg.css` | The page's styles |
| `public/_headers` | The Content-Security-Policy and other headers: scripts and styles from this origin and Google Fonts only, nothing inline |
| `worker/index.ts` | The Worker: sends anyone signed out to sign in before serving the page; the high-score API under `api/` and the public scores page; everything else is a static asset |
| `worker/scores.ts` | The shared table: run tickets, the plausibility limits, names, and the `ScoreTable` Durable Object that keeps the best hundred |
| `worker/scores-page.ts`, `worker/look.ts` | The public scores page, in icelander.net's look |
| `test/` | The sign-in, the high-score table and its API, and checks that the page works under its Content-Security-Policy and that the script parses |
| `build.mjs` | Copies `public/` into `dist/games/retro/meg/` as served, and builds the tests |
| `wrangler.jsonc` | The Worker's route, `icelander.net/games/retro/meg*`, its assets and the login service binding |
| `.dev/` | This folder's diagrams and knowledge files |

## Develop

```bash
npm install
npm test        # type-check, then the tests
npm run build   # dist/, as served
```

To play a local copy, open `public/index.html` in a browser; the sign-in is only on icelander.net.

## Deploy

Nothing deploys from GitHub any more: the owner deploys it from their own machine with `npm run deploy` (tests, build, `wrangler deploy`). MEG has no D1 database: its high-score table is a Durable Object, which the deploy creates from the migrations in `wrangler.jsonc`, so nothing is migrated by hand. Keep every entry in that list.

## Status

MEG is on icelander.net behind the sign-in, with a shared high-score table of trusted scores. Replay-checking them, as the other games do, is a backlog item in `.dev/backlog.json`; it first needs the simulation made deterministic.
