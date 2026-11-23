# Laumufarþegi

An Icelandic party word game for 3–10 players, each on their own phone or laptop, in the same room or on a call. Everyone sees a topic and 16 words. Everyone but one player, the **laumufarþegi** (stowaway), also sees which word is secret. In turn, each player gives a short clue; then everyone votes for who they think the stowaway is. If the stowaway is caught, they may guess the secret word.

Play at [icelander.net/games/laumufarthegi](https://icelander.net/games/laumufarthegi/) once it is deployed.

## Hosting and sharing a game

1. Open the game, type your name and press **Stofna nýjan leik**. Starting a room is for **invited hosts**: you must be signed in to icelander.net with the role `games:laumufarthegi`, which the site's owner grants or sends as an invitation at icelander.net/private/admin.
2. The lobby shows a five-letter room code and a link (`…/laumufarthegi/?r=ABCDE`). Press **Afrita hlekk** and paste the link into Teams, a chat or an email.
3. The others open the link, type a name and are in. They don't sign in or install anything. Three connected players are needed; at most ten fit.
4. As host, choose the settings:
   - the number of rounds (default 6);
   - the seconds for each clue (45) and for the vote (90);
   - which topics to use: easy, easy and medium, or all;
   - child-friendly topics only.
5. Press **Byrja leikinn**.
6. After each round, press **Næsta umferð**.

If someone reloads the page or loses the connection, they come back to the same seat. If the host disconnects for more than 30 seconds, any other player can take over. A room deletes itself after a day without use.

## Points

| Event | Points |
|---|---|
| Voting for the stowaway | 1 |
| The stowaway is not caught (a wrong player is voted out, or the vote is tied) | 3 for the stowaway |
| The stowaway is caught but guesses the word | 1 for the stowaway |
| The stowaway is caught and guesses wrong | 1 for every other player |

## How it works

The server decides everything. Each player's device only ever receives what that player may see:
- **The secret word** goes only to the players in the round who are not the stowaway.
- **The stowaway** is named to nobody until the vote catches them or the round ends.

| File | What it does |
|---|---|
| `shared/game.ts` | The rules as pure functions: phases (lobby → clues → voting → guess → reveal → over), points, timeouts, topic choice, and `view()`, which is each player's own view of the room. |
| `shared/protocol.ts` | The game's address, room codes, and the WebSocket messages. |
| `shared/topics.ts` | The topics, read at build time from [`../word-lists/data/topic-grids.json`](../word-lists/data/topic-grids.json): 118 topics of 16 words. A change to that file reaches this game on its next build and deploy. |
| `worker/index.ts` | The Worker. It serves the page (open to everyone) and has these routes:<br>• `GET api/me`: whether you may start a room.<br>• `POST api/rooms`: starts a room; needs a sign-in with `HOST_ROLE` unless `HOST_SIGN_IN` is `"none"`.<br>• `GET api/rooms/CODE/ws`: the room's WebSocket. |
| `worker/room.ts` | The Durable Object `Room`, one per room. It keeps the state in its storage, holds the players' hibernating WebSockets and runs the clue, vote and guess timers on its alarm. |
| `web/` | The page: `index.html`, `app.ts` (built to `app.js`), `style.css`, the icon and the security headers (`_headers`). |
| `test/` | Tests for the rules, for the room object on a fake runtime, and for the Worker's routes and sign-in rule. |

## Develop

```bash
npm install
```

```bash
npm test
```

```bash
npx wrangler dev --var HOST_SIGN_IN:none
```

Then open http://localhost:8787/games/laumufarthegi/. The local run lets anyone start a room, because there is no login service on your machine. Open the room link in several browser windows to play against yourself.

## Deploy

Nothing deploys from GitHub any more: the owner deploys from their own machine, with a Cloudflare token for the icelander.net account, by running `npm run deploy` in this folder (it runs `npm test`, the build and `wrangler deploy`).

The game has no database and no secrets. Its first deploy creates the `Room` Durable Object class through the `rooms-v1` migration in `wrangler.jsonc`, and the route `icelander.net/games/laumufarthegi*`.

Only starting a room checks icelander.net's sign-in, through the site's own cookie (no new app needs registering with the login service): `HOST_SIGN_IN` is `"required"` and `HOST_ROLE` is `games:laumufarthegi` in `wrangler.jsonc`. The role is declared in the icelander.net repository (`accounts/src/config.js`) and granted, or sent as an invitation, at icelander.net/private/admin. Joining a room never needs a sign-in. Set `HOST_SIGN_IN` to `"none"` to let anyone start rooms.

## Credits

The topics are original lists whose words were checked against the Árni Magnússon Institute's open datasets (Íslensk nútímamálsorðabók, the CEFR vocabulary lists for Icelandic and the Icelandic Gigaword frequency lists; © Stofnun Árna Magnússonar í íslenskum fræðum, CC BY-SA 4.0 / CC BY 4.0). See [`../word-lists/README.md`](../word-lists/README.md).
