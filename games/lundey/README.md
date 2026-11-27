# Lundey

> **To be served at [icelander.net/games/lundey](https://icelander.net/games/lundey/)**, for invited players only (role `games:lundey`, granted at icelander.net/private/admin). `worker/index.ts` is a Cloudflare Worker that serves the built page behind the site's sign-in and keeps nothing; the game runs in the browser. `npm test` checks the game and the Worker, and the owner publishes it from their own machine with `npm run deploy` (nothing deploys from GitHub). It has not been deployed yet.

An original maze chase for one player. You are a puffin on Lundey ("puffin island"), gathering sand eels from a maze of burrows cut into the turf while four hunters come after you. The game, its maze generator, its characters, its art and its sounds were all made for this repository; it is in the family of arcade maze chases and is not a remake of any one of them.

- **A new burrow every level.** Each maze is dug from a seed: mirrored left to right, no dead ends, the hunters' den in the middle, and one tunnel that runs off the side of the island and comes back on the other.
- **Four hunters, four ways of hunting.** Refur the fox follows your scent, tile by tile, so crossing your own trail can throw it. Minkur the mink takes the shortest way. Skúmur the skua flies to your next meal, the nearest eel that isn't right under your beak, and turns on you when it is close. Hrafn the raven wanders until it sees you down a straight tunnel, then dives, faster than you can run. The fox, mink and skua hunt and prowl in turn.
- **Tern feathers.** Four to a burrow. Pick one up and the arctic terns mob every hunter in the tunnels: they turn tail and slow down, and touching one routs it back to the den for 250, 500, 750 and 1,000 points.
- **Treats** wash up twice a burrow (herring, crab, mussel, starfish, pearl), an extra puffin comes at 4,000 points and every 8,000 after, and a burrow cleared without losing a puffin is worth 500.
- Hunters get faster, the terns stay for less time and the prowls get shorter on each burrow. The season changes too.

Keyboard (arrows or WASD, Enter to start, P to pause, M for sound), swipes or the on-screen buttons on a phone, or a gamepad. The best score is kept on the device (`localStorage`); there is no high-score table. Left alone on the title screen, the game plays a demo.

```bash
npm install
npm test        # type-check, then the maze, game and Worker tests
npm run build   # dist/games/lundey/
npm run dev     # rebuild the bundle as the source changes
npm run deploy  # owner only: test, build, wrangler deploy
```

To look at it without the sign-in, build it and serve `dist/` with any static server, then open `/games/lundey/`.

## Rules, in numbers

They live in `src/engine/rules.ts`. The game takes 60 steps a second; speeds are thousandths of a tile a step.

| | |
|---|---|
| Island | 21 × 23 tiles; about 230 to 255 sand eels a burrow |
| Speeds | puffin 100; fox 90, mink 84, skua 94, raven 80 (diving +28); each burrow +2, up to +12; mobbed 52; routed 220 |
| Out of the den | fox at once; mink after 2 s, skua 7 s, raven 12 s (half a second sooner each burrow) |
| Hunt, then prowl | fox 14 s and 4 s; mink 10 s and 5 s; skua 12 s and 4 s (prowls half a second shorter each burrow, never under 1 s) |
| Fox's nose | scent up to 8 s old |
| Raven's dive | 3 s, then 2.5 s before it can dive again |
| Terns | 8 s on the first burrow, half a second less on each, never under 3 s; hunters flash for the last 2 s |
| Points | eel 5, feather 25, routs 250/500/750/1,000, treats 100/200/300/500/800, clean burrow 500 |
| Puffins | 3 to start; one more at 4,000 and every 8,000 after; never more than 5 |

## Layout

- `src/engine/`: the game with no page and no clock. `rules.ts` (the numbers), `rng.ts` (the seeded generator), `maze.ts` (digging a burrow, distances along the tunnels), `game.ts` (`Game.step`: one sixtieth of a second), `autopilot.ts` (a simple player for the demo and the tests). The same seed and the same controls always give the same game: only whole-number arithmetic, and random numbers only from `rng.ts`.
- `src/ui/`: `art.ts` (the cast and pickups as canvas shapes; there are no image files), `render.ts` (the island, the score line, the words), `input.ts` (keyboard, swipes, buttons, gamepad), `sound.ts` (Web Audio; there are no sound files).
- `src/main.ts`: the page's loop: 60 steps a second, a frame drawn at the screen's own resolution, the best score, the demo.
- `public/`: the page, its styles, its icon and the response headers (`_headers`: everything from this origin, no inline script or style).
- `worker/`: the Worker (`index.ts`) and its address and role (`config.ts`).
- `test/`: `maze.test.ts` (300 seeds: connected, mirrored, no dead ends, the den shut), `game.test.ts` (movement, each hunter's way of hunting, feathers, lives, clearing a burrow, the demo), `worker.test.ts` (who may fetch what).
