# Dulmál

> **Address once deployed:** [icelander.net/games/fresh/dulmal](https://icelander.net/games/fresh/dulmal/). No sign-in: anyone with a room's link can play (`.dev/decisions.json`, `no-sign-in`).

An original Icelandic team word-association game for 4–8 players (up to 12), each on their own phone or computer, in the same room or far apart. Two teams, **Hraun** and **Jökull**, each have one clue-giver (*sögumaður*) and one or more guessers (*giskarar*). The board is 5×5 Icelandic words; the hidden key gives 9 words to the team that starts, 8 to the other, 7 neutral and 1 game-over word (*draugurinn*). The clue-giver types one word and a number; the team may guess up to the number plus one, and may stop early. A neutral word or the other team's word ends the turn, the game-over word loses the game, and the first team to reveal all its words wins.

The genre is "one-word clues to a grid of words"; the name, look, text and words here are this game's own.

## Playing

1. Open the address, type your name and press **Stofna herbergi**. You are the host.
2. Share the link (**Afrita tengil** or **Deila**), say the four-letter code aloud, or show the QR code (**Sýna QR-kóða**).
3. Players open the link and type their name. Each is put in the smaller team; the first in each team is its clue-giver. Before the game anyone can **Skipta um lið** (change team) or **Verða sögumaður**; the host can move anyone, pick clue-givers, or **Stokka upp liðin**.
4. Optional: open the link on a TV or projector and choose **Stór skjár** (or add `&skjar=1` to the link). It shows the board, clue and score, and a QR code in the lobby, but never the key.
5. The host sets the turn timer (off by default) and may paste their own word list (at least 25 words) under **Stillingar**, then presses **Hefja leik**.
6. After a game, **Nýr leikur, sömu lið** deals a new board; **Breyta liðum** goes back to the lobby.

A player who refreshes, loses signal or closes the browser comes back to the same seat by opening the link again in the same browser (the seat is kept in `localStorage`). On a different device they choose their name under "Hefurðu verið með áður". If the host is away, whoever joined first runs the room until they return. Rooms are deleted after three days without activity.

## How it works

- `src/shared/game.ts`: the rules as pure functions on a `Room`, and `view()`, which builds what one device may see. The key goes only to clue-givers, and to everyone once the game is over.
- `src/shared/protocol.ts`: the WebSocket messages. `src/shared/words.ts`: reading word lists and dealing boards with no look-alike words together.
- `worker/index.ts`: the Worker. `POST api/rooms` creates a room with a fresh code; `api/rooms/<CODE>/ws` is the room's WebSocket, handled by the room's Durable Object.
- `worker/room.ts`: `RoomObject`, one Durable Object per room code: the single source of truth. It stores the room, applies each message through the rules, sends every socket its own view, and runs the turn timer and idle clean-up as an alarm. Its logic is in `RoomCore`, which the tests drive with fake sockets.
- `src/client/main.ts`: the page; `src/client/text.ts`: every word it shows, in Icelandic; `public/`: the HTML, stylesheet and icon.
- `data/ord.txt`: the built-in word list, one word per line. `#` starts a comment; `|` marks where a long word may be split on a small screen (`Reykja|vík`). Words of 9 letters or more need a `|`, and no part may be longer than 9 letters (the tests check this).
- `LANGUAGE-QA.md`: words and phrases for a native speaker to check.

## Develop

```bash
npm install
npm test          # typecheck, rules, rooms, Worker routes and word list
npm run dev       # builds, then wrangler dev with rooms on http://localhost:8787/games/fresh/dulmal/
```

`npm run dev` listens on all interfaces, so phones on the same Wi-Fi can play at `http://<this computer's IP>:8787/games/fresh/dulmal/`.

## Deploy

A merge to `main` deploys it (`.github/workflows/deploy.yml`), as `npm run deploy` does: `wrangler deploy` creates the Worker, its route and the `RoomObject` Durable Object class (migration `rooms-v1`). There is no D1 database, no secret and no sign-in binding.
