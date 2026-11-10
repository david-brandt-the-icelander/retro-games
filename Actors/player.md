# Player

**Kind:** person in a role
**Evidence:** `games/rally/worker/index.ts` (`AUTH`, `gamePage`: the page and the score API need a sign-in to icelander.net with the `games:play` role), `games/rally/src/main.ts` (`start`, `joinMatch`), `games/rally/src/scores.ts` (`defaultName`)
**Evidence (Gambit):** `games/chess/worker/index.ts` (`default.fetch`: the page needs a sign-in to icelander.net with the `games:play` role), `games/chess/worker/auth.ts` (`currentUser`: Gambit's own player record, keyed by address), `games/chess/worker/api.ts` (`handleApi`: an invitation is answered by the player signed in with the address it was sent to), `games/chess/godot/scripts/main.gd` (`Main._lobby`, `Main._setup`, `Main._history`)
Samosa: `games/dictator/worker/index.ts` (`AUTH`, `gamePage`: the page and the score API need a sign-in to icelander.net with the `games:play` role), `games/dictator/src/main.ts` (`title`, `io`, `offerTable`), `games/dictator/src/scores.ts` (`defaultName`)
**Evidence (Hivestorm):** `games/hivestorm/worker/index.ts` (`AUTH`, `gamePage`: the same sign-in and role), `games/hivestorm/src/ui/input.ts` (`Controls`), `games/hivestorm/src/main.ts` (`step`, `joinMatch`, `offerTable`)
**Evidence:** `games/shatterbelt/worker/index.ts` (`AUTH`, `gamePage`: Shatterbelt's page and score API need the same sign-in and role), `games/shatterbelt/src/main.ts` (`launch`, `joinMatch`), `games/shatterbelt/src/input.ts` (`Input.controls`: one pilot per browser)

## What they want from the system

- To play Rally against the computer, at a level they choose, and get onto the high-score table ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/rally/.dev/user-journey.json), `climb-the-table`).
- To play a friend who is on another device ([Rally's use cases](../games/rally/src/.dev/use-case.json), `play-online`; [journeys](../games/rally/.dev/user-journey.json), `play-a-friend`).
- To play a friend somewhere else at their own pace in Gambit: invite them by email, play over days and chat as they go ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `invite-a-friend`, `answer-an-invitation`, `play-online`; [journeys](../games/chess/.dev/user-journey.json), `play-a-friend`).
- To play the computer in Gambit at a strength they choose, and keep the game ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `play-the-computer`; [journeys](../games/chess/.dev/user-journey.json), `play-the-computer`).
- To look back on their Gambit games and their record against each friend ([Gambit's use cases](../games/chess/godot/scripts/.dev/use-case.json), `replay-a-game`, `visit-a-contact`; [journeys](../games/chess/.dev/user-journey.json), `relive-a-game`).
- To rule Samosa's Nicaragua for as long and as well as they can, month by month, and get out alive with money in Switzerland ([Samosa's use cases](../games/dictator/src/engine/.dev/use-case.json), `survive-a-month`; [journeys](../games/dictator/.dev/user-journey.json), `a-reign`).
- To put a reign of Samosa on its high-score table, and see it ranked ([Samosa's use cases](../games/dictator/src/.dev/use-case.json), `reign-and-enter-table`; [journeys](../games/dictator/.dev/user-journey.json), `climb-the-table`).
- To play Hivestorm against the hive and get onto its high-score table ([Hivestorm's use cases](../games/hivestorm/src/.dev/use-case.json), `play-and-enter-table`; [journeys](../games/hivestorm/.dev/user-journey.json), `climb-the-table`).
- To play a friend at Hivestorm on another device, taking turns, each with their own score on the table ([Hivestorm's use cases](../games/hivestorm/src/.dev/use-case.json), `play-online`; [journeys](../games/hivestorm/.dev/user-journey.json), `play-a-friend`).
- To fly Shatterbelt alone and get onto its high-score table ([Shatterbelt's use cases](../games/shatterbelt/src/.dev/use-case.json), `fly-solo-and-enter-table`; [journeys](../games/shatterbelt/.dev/user-journey.json), `climb-the-table`).
- To fly Shatterbelt with up to eight friends online, each on their own device, together or against each other, and see everyone's scores on the table ([Shatterbelt's use cases](../games/shatterbelt/src/.dev/use-case.json), `fly-online`; [journeys](../games/shatterbelt/.dev/user-journey.json), `fly-with-friends`).

## How they reach it

Rally's page at icelander.net/games/retro/rally/, signed in to icelander.net, with a keyboard, a mouse or a touch screen. Online matches start on the games hub's multiplayer page, which opens the game with `?match=ID`; the other player in an online match is a player too.

Gambit is at icelander.net/games/retro/chess/, signed in to icelander.net, with a mouse or a touch screen. An invitation's link (`?challenge=ID`) opens it at that invitation; the friend invited is a player too, known by the email address the invitation was sent to.
Samosa's page at icelander.net/games/retro/samosa/, signed in to icelander.net, with a keyboard, or on a touch screen with the keypad of the keys each prompt accepts; its scores page needs no sign-in.
Hivestorm's page at icelander.net/games/retro/hivestorm/, signed in to icelander.net, with a keyboard or the touch buttons under the screen. Its online games also start on the multiplayer page, which opens the game with `?match=ID`; there, the other player plays their own turns of the same two-player game.
Shatterbelt's page is at icelander.net/games/retro/shatterbelt/, signed in the same way, with a keyboard, a gamepad or a touch screen; its online games, for two to nine pilots, start on the same multiplayer page, and every pilot in them is a player too.
