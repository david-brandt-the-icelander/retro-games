# Player

**Kind:** person in a role
**Evidence:** `games/rally/worker/index.ts` (`AUTH`, `gamePage`: the page and the score API need a sign-in to icelander.net with the `games:play` role), `games/rally/src/main.ts` (`start`, `joinMatch`), `games/rally/src/scores.ts` (`defaultName`)
**Evidence (Gambit):** `games/chess/worker/index.ts` (`default.fetch`: the page needs a sign-in to icelander.net with the `games:play` role), `games/chess/worker/auth.ts` (`currentUser`: Gambit's own player record, keyed by address), `games/chess/worker/api.ts` (`handleApi`: an invitation is answered by the player signed in with the address it was sent to), `games/chess/godot/scripts/main.gd` (`Main._lobby`, `Main._setup`, `Main._history`)

## What they want from the system

- To play Rally against the computer, at a level they choose, and get onto the high-score table ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/rally/.dev/user-journey.json), `climb-the-table`).
- To play a friend who is on another device ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-online`; [journeys](../games/rally/.dev/user-journey.json), `play-a-friend`).
- To play a friend somewhere else at their own pace in Gambit: invite them by email, play over days and chat as they go ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `invite-a-friend`, `answer-an-invitation`, `play-online`; [journeys](../games/chess/.dev/user-journey.json), `play-a-friend`).
- To play the computer in Gambit at a strength they choose, and keep the game ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `play-the-computer`; [journeys](../games/chess/.dev/user-journey.json), `play-the-computer`).
- To look back on their Gambit games and their record against each friend ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `replay-a-game`, `visit-a-contact`; [journeys](../games/chess/.dev/user-journey.json), `relive-a-game`).

## How they reach it

Rally's page at icelander.net/games/retro/rally/, signed in to icelander.net, with a keyboard, a mouse or a touch screen. Online matches start on the games hub's multiplayer page, which opens the game with `?match=ID`; the other player in an online match is a player too.

Gambit is at icelander.net/games/retro/chess/, signed in to icelander.net, with a mouse or a touch screen. An invitation's link (`?challenge=ID`) opens it at that invitation; the friend invited is a player too, known by the email address the invitation was sent to.
