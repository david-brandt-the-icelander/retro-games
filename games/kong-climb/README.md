# Kong Climb

A recreation of the 1981 arcade climber for the browser, on desktop and phone. A giant ape has carried off a captive; climb the girders, dodge what he sends down, and reach her. Four stages: sloped girders with rolling barrels, conveyor belts with pies, moving lifts with bouncing springs, and the rivets stage, where you win by pulling out all eight rivets.

It keeps the original's rules and feel: the jump height and the fatal fall, ladders you may use and broken ones you may not, a hammer that lasts about ten seconds, points for leaping a barrel (100, then 300, then 800 for two and three in one jump), a bonus that counts down, an extra life at 7000. Everything you see and hear is made for this game: sprites are drawn from rectangles in code, the sounds are synthesized, the stage layouts and the names are its own. It is not affiliated with the original's makers.

## Play

At <https://icelander.net/games/recreations/arcade/kong-climb/>, for players signed in to icelander.net who hold the invite-only role `games:recreations` (granted at icelander.net/private/admin; the Worker checks it with `vendor/icelander-auth/`).

| Action | Keyboard | Phone |
|---|---|---|
| Walk | ← → or A D | on-screen arrows |
| Climb a ladder | ↑ ↓ or W S, at the ladder | on-screen arrows |
| Jump | Space, Z or X | JUMP |
| Pause | P or Esc | Pause |
| Sound on/off | M | Sound |

With the hammer you can neither jump nor climb, but anything you reach in front of you is smashed for 300, 500 or 800.

## The stages

| Stage | What is in your way | How you win |
|---|---|---|
| 25m, girders | Barrels roll down the slopes, some take the ladders, and one that reaches the oil drum may set a fireball loose | Reach the top girder |
| 50m, conveyors (from the second round) | Pies on belts that sometimes reverse; the belts carry you too; fireballs | Reach the top girder |
| 75m, lifts (from the third round) | Rising and falling lifts to hop between, springs bouncing along the top, fireballs | Reach the top-left of the highest girder |
| 100m, rivets | Fireballs, which may chase you | Walk over all eight rivets |

Each round repeats the stages a little faster, with more fireballs. You have three lives; the stage starts again when you lose one.

## How it works

```
src/engine/levels.ts   the four stages as data: platforms (girders, belts, lifts), ladders, where things start
src/engine/game.ts     the rules, stepped 60 times a second with no drawing; events for the sound
src/engine/rng.ts      the seeded random generator every random choice goes through
src/client/main.ts     the page: fixed-rate loop, keyboard and touch input, pause, the best score in localStorage
src/client/render.ts   draws a Game on a 224 × 256 canvas, scaled by whole numbers; every sprite is rectangles
src/client/audio.ts    sound: Web Audio beeps and a short bass line for each stage
public/                the page and its stylesheet
worker/                the Cloudflare Worker: the sign-in and role check, then the files
test/                  the rules, played frame by frame, and the Worker
```

- **No server state.** The Worker has no API and no database; the game runs entirely in the browser and keeps the best score on the device. There is no shared high-score table, so the engine does not need to be replay-checkable, but it is deterministic for a given seed.
- **Pure engine.** `src/engine` imports nothing from the browser. The page builds a `Game`, calls `step(input)` once a frame and draws what it finds; sounds are played from `game.events`.

## Develop

You need Node 22.

```bash
npm install
npm test            # type-checks, then plays the rules headless and tests the Worker
npm run dev         # builds at the root and runs wrangler dev, open to anyone, at http://localhost:8787/
```

## Deploy

Nothing deploys from GitHub: the owner deploys it from their own machine by running `npm run deploy` in this folder (tests, build, then `wrangler deploy`), with wrangler logged in to icelander.net's Cloudflare account. The Worker needs no secrets and no database. It is listed on icelander.net/games from `site/games.json` in the icelander.net repository, in the Recreations group.
