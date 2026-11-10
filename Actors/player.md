# Player

**Kind:** person in a role
**Evidence:** `games/rally/worker/index.ts` (`AUTH`, `gamePage`: the page and the score API need a sign-in to icelander.net with the `games:play` role), `games/rally/src/main.ts` (`start`, `joinMatch`), `games/rally/src/scores.ts` (`defaultName`)
**Evidence (Hivestorm):** `games/hivestorm/worker/index.ts` (`AUTH`, `gamePage`: the same sign-in and role), `games/hivestorm/src/ui/input.ts` (`Controls`), `games/hivestorm/src/main.ts` (`step`, `joinMatch`, `offerTable`)

## What they want from the system

- To play Rally against the computer, at a level they choose, and get onto the high-score table ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/rally/.dev/user-journey.json), `climb-the-table`).
- To play a friend who is on another device ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-online`; [journeys](../games/rally/.dev/user-journey.json), `play-a-friend`).
- To play Hivestorm against the hive and get onto its high-score table ([Hivestorm's use cases](../games/hivestorm/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/hivestorm/.dev/user-journey.json), `climb-the-table`).
- To play a friend at Hivestorm on another device, taking turns, each with their own score on the table ([Hivestorm's use cases](../games/hivestorm/src/.dev/use-case.json), `play-online`; [journeys](../games/hivestorm/.dev/user-journey.json), `play-a-friend`).

## How they reach it

Rally's page at icelander.net/games/retro/rally/, signed in to icelander.net, with a keyboard, a mouse or a touch screen. Online matches start on the games hub's multiplayer page, which opens the game with `?match=ID`; the other player in an online match is a player too.

Hivestorm's page at icelander.net/games/retro/hivestorm/, signed in to icelander.net, with a keyboard or the touch buttons under the screen. Its online games also start on the multiplayer page, which opens the game with `?match=ID`; there, the other player plays their own turns of the same two-player game.
