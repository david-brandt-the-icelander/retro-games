# Room host

**Kind:** person in a role
**Evidence:** `games/laumufarthegi/worker/index.ts` (`mayHost`, `createRoom`: starting a room needs a sign-in to icelander.net with the `games:play` role unless `HOST_SIGN_IN` is `none`), `games/laumufarthegi/shared/game.ts` (`State.hostId`, `newRoom`: whoever starts a room is its host; `act`: settings, start, next, end, kick and resetTopics are the host's alone; `claimHost`: another player becomes host once the host has been away `HOST_GRACE_MS`), `games/laumufarthegi/web/app.ts` (`homeScreen`, `lobbyScreen`, `settingsCard`, `hostBar`)

## What they want from the system

- To start a Laumufarþegi room and get a group into it from one shared link, for example in a Teams chat: [the page's use cases](../games/laumufarthegi/web/.dev/use-case.json), `start-a-room`; [journeys](../games/laumufarthegi/.dev/user-journey.json), `host-a-game`.
- To set the game up for the group (rounds, timers, difficulty, child-friendly topics), pace it round by round, remove someone who should not be there, and end it: [use cases](../games/laumufarthegi/web/.dev/use-case.json), `run-the-game`; [features](../games/laumufarthegi/shared/.dev/feature.json), `host-controls`.

## How they reach it

Laumufarþegi's page at icelander.net/games/laumufarthegi/, on a phone or a computer; signed in to icelander.net with the invite-only role `games:laumufarthegi` (the Worker's `HOST_ROLE`), unless `HOST_SIGN_IN` is `none`. After that, the room's WebSocket, like every player.

## Not to be confused with

The [Player](player.md): the host is also a player in their room, scored like everyone else, and any player can become the host by taking over from one who has been disconnected for 30 seconds. The code tells them apart only by `State.hostId`, and only the person who starts a room needs to be signed in. Not the [Owner](owner.md), who runs the repository and the site, not a room.
