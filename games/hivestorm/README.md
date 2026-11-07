# HIVESTORM

An arcade shooter for one or two players, free to play at [games.icelander.net/retro/hivestorm](https://games.icelander.net/retro/hivestorm/).

HIVESTORM is an original game in the formation-and-dive shooter genre of the late 1970s. A hive of 37 wasp-like aliens sways across the top of the screen. Aliens peel off from the ends of the hive, swoop down at your ship and fire as they come, then fly back in at the top. Your ship has one shot in the air at a time. The name, the creatures, the pixel art, the sounds, the screen text, the scoring numbers and the code were all made for this game; none of them are taken from an existing title.

## Playing

| | Keyboard | Touch |
|---|---|---|
| Start a 1-player game | `1` | **1 PLAYER** |
| Start a 2-player game | `2` | **2 PLAYERS** |
| Move | `←` `→` (or `A` `D`) | ◀ ▶ |
| Fire (hold to keep firing) | `Space` (or `↑`, `Ctrl`, `Enter`) | **FIRE** |
| Pause | `P` or `Esc` | **PAUSE** |
| Sound on or off | `M` | **SOUND** |

**Two players** take turns at the same controls. The turn passes each time a ship is lost. Each player has their own score, ships, wave and hive, and a hive stays as its player left it until their next turn. When one player is out of ships, the other plays on alone. The game ends when both are out and names the winner.

## Playing online

Games with friends start on the multiplayer page, [games.icelander.net/multiplayer](https://games.icelander.net/multiplayer/), not in the game itself. Everyone who plays must be signed in to the games. One player starts a game there and waits; the others join it by choosing the game and typing that player's address (which keeps it in their contacts, so they can see when that friend is waiting). Once two or more are waiting, a 60-second countdown starts, and starts again whenever someone else joins; the game begins when it runs out, or as soon as everyone presses Ready. Each player's browser then opens this game with `?match=ID`. Two players on different computers, phones or tablets play the same two-player game, taking turns as they would on one machine. The one who joined the lobby's game first is player 1. Each of you plays your own turns with your own controls, and watches the other's; the line under the screen says which player you are and who you play. An online game can't be paused. If the other player leaves, you play both turns. When the game ends, each of you can put your own score on the high-score table: the host's browser sends the game with both names, and the server replays it as any other. **BACK TO MULTIPLAYER**, under the screen, returns to the lobby for another game.

Every browser runs the whole game itself, in lockstep (`src/online.ts`). Each one sends only its own player's controls, a few steps ahead of when they are played (the delay, set when the game starts from everyone's measured connection: usually 60–150 ms). A browser steps the game only once it has every player's controls for that step, so every browser plays exactly the same game; it is the same property that lets the server replay a game for the high-score table. Every 120 steps (a second or two) the browsers compare a fingerprint of their games, and end the game if they ever differ. A browser that falls behind (a slow connection, or a hidden tab) makes the others wait, and they say so.

The relay is the games hub's, not this game's: a Cloudflare Durable Object per match in the `recreations` repository (`worker/match.ts`), at `GET /multiplayer/match/{ID}` (a WebSocket). It lets in only the signed-in players the lobby put in the match, each in their place in the lobby, and passes each one's messages to the others in order. `src/online.ts` and `test/online.test.ts` are the same files in Rally, Shatterbelt and Hivestorm.

## Rules

- You start with 3 ships and get one extra ship at 7,000 points.
- Points for each alien, shot at home in the hive or out diving:

  | Alien | In hive | Diving |
  |---|---|---|
  | Queen (crowned, top row) | 60 | 200, or 400 / 800 if 1 / 2 of her escorts were shot first on that dive |
  | Guard (magenta) | 50 | 100 |
  | Drone (orange) | 40 | 80 |
  | Worker (yellow) | 30 | 60 |

- A queen may dive with up to two guards from beside her as escorts.
- A diving alien that rams your ship destroys both, and you still get its points.
- Clearing the hive starts the next wave. Each wave dives faster and more often, with more aliens out at once.
- When only 5 aliens are left, they stop going home and dive one after another.
- **High scores:** when a game ends, each player whose score makes the top ten can enter a name for the public table. The title screens show the table every other 10 seconds, and the web page [/retro/hivestorm/scores/](https://games.icelander.net/retro/hivestorm/scores/) lists the top 25. Only the name is kept: no email or other personal data.

Every number is in [`src/engine/rules.ts`](src/engine/rules.ts).

## How scores are checked

The browser never reports a score. When a game starts, the page uses a seed the server issued (`POST api/game`). It records the controls on every frame as runs of the same input, and sends them with the names when the game ends (`POST api/score`). The server plays the whole game again with the same engine, from that seed (`src/engine/replay.ts`). It records the scores the replay reaches, and only if the controls start a game on their first frame and end it on their last. Each seed counts once. The engine uses its own sine and cosine (`src/engine/trig.ts`), made from plain arithmetic, so every browser and the server reach exactly the same positions. A replay takes about 1 ms per minute of play.

The table lives in the D1 database `hivestorm-scores` (schema: `worker/schema.sql`).

## Code

- `src/engine/`: the game, with no DOM. `Game.step(input)` advances one frame (1/60 s) and returns what happened (`shoot`, `hit`, `die`…) for the sound to play. It uses a seeded random generator, so tests can replay games.
- `src/ui/art.ts`: every sprite and a 5×7 font, as pixel maps.
- `src/ui/render.ts`: draws the game onto a 224×288 canvas.
- `src/ui/sound.ts`: sound effects made with Web Audio, with no sound files.
- `src/ui/input.ts`: the keyboard and touch buttons.
- `src/main.ts`: the page and its fixed-step loop. It records each game, offers the high-score table, and plays online games.
- `src/online.ts`: online play in the browser: the match's WebSocket and the lockstep.
- `src/scores.ts`, `src/name.ts`: the browser's side of the table, and how a name is cleaned.
- `worker/`: the Worker. It serves the game, the high-score API, the scores page (`scores-page.ts`, in icelander.net's look from `look.ts`). Its `migrations` delete the Durable Object class `Room`, which held online rooms before they moved to the games hub; keep both entries.

```bash
npm ci
npm test         # engine, art, replay and API tests
npm run build    # static site in dist/retro/hivestorm/
npm run deploy   # test, build and deploy the hivestorm Worker to games.icelander.net/retro/hivestorm*
```
