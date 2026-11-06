# HIVESTORM

An arcade shooter for one or two players, free to play at [icelander.net/games/retro/hivestorm](https://icelander.net/games/retro/hivestorm/).

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
- The high score is kept in your browser.

Every number is in [`src/engine/rules.ts`](src/engine/rules.ts).

## Code

- `src/engine/`: the game, with no DOM. `Game.step(input)` advances one frame (1/60 s) and returns what happened (`shoot`, `hit`, `die`…) for the sound to play. It uses a seeded random generator, so tests can replay games.
- `src/ui/art.ts`: every sprite and a 5×7 font, as pixel maps.
- `src/ui/render.ts`: draws the game onto a 224×288 canvas.
- `src/ui/sound.ts`: sound effects made with Web Audio, with no sound files.
- `src/ui/input.ts`: the keyboard and touch buttons.
- `src/main.ts`: the page and its fixed-step loop.

```bash
npm ci
npm test         # engine and art tests
npm run build    # static site in dist/games/retro/hivestorm/
npm run deploy   # test, build and deploy the hivestorm Worker to icelander.net/games/retro/hivestorm*
```
