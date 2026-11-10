# Player

**Kind:** person in a role
**Evidence:** `games/rally/worker/index.ts` (`AUTH`, `gamePage`: the page and the score API need a sign-in to icelander.net with the `games:play` role), `games/rally/src/main.ts` (`start`, `joinMatch`), `games/rally/src/scores.ts` (`defaultName`)
**Evidence:** `games/shatterbelt/worker/index.ts` (`AUTH`, `gamePage`: Shatterbelt's page and score API need the same sign-in and role), `games/shatterbelt/src/main.ts` (`launch`, `joinMatch`), `games/shatterbelt/src/input.ts` (`Input.controls`: one pilot per browser)

## What they want from the system

- To play Rally against the computer, at a level they choose, and get onto the high-score table ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/rally/.dev/user-journey.json), `climb-the-table`).
- To play a friend who is on another device ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-online`; [journeys](../games/rally/.dev/user-journey.json), `play-a-friend`).
- To fly Shatterbelt alone and get onto its high-score table ([Shatterbelt's use cases](../games/shatterbelt/src/.dev/use-case.json), `fly-solo-and-enter-table`; [journeys](../games/shatterbelt/.dev/user-journey.json), `climb-the-table`).
- To fly Shatterbelt with up to eight friends online, each on their own device, together or against each other, and see everyone's scores on the table ([Shatterbelt's use cases](../games/shatterbelt/src/.dev/use-case.json), `fly-online`; [journeys](../games/shatterbelt/.dev/user-journey.json), `fly-with-friends`).

## How they reach it

Rally's page at icelander.net/games/retro/rally/, signed in to icelander.net, with a keyboard, a mouse or a touch screen. Online matches start on the games hub's multiplayer page, which opens the game with `?match=ID`; the other player in an online match is a player too.

Shatterbelt's page is at icelander.net/games/retro/shatterbelt/, signed in the same way, with a keyboard, a gamepad or a touch screen; its online games, for two to nine pilots, start on the same multiplayer page, and every pilot in them is a player too.
