# Rampart

An original isometric fortress-run shooter (the fortress runs up and to the right), made in Godot 4 and played in the browser at
[icelander.net/games/retro/rampart](https://icelander.net/games/retro/rampart/) by anyone signed in to icelander.net.
Everything in it is made in code: the models, the shaders and the sound effects, so the project has no binary assets.

## How it plays

- The ship flies forward on its own; you steer it sideways and up and down. **Altitude** is the skill: a cyan ring on the deck sits under the ship and the ALT gauge gives its height.
- **Walls** are either tall, with a green-framed window to thread, or low enough to fly over. **Force fields** block the bottom or the top, and from level 2 some blink on and off.
- **Fuel** drains all the time; shooting **fuel tanks** refuels. Ground targets can only be hit when flying low. **Turrets** aim ahead of you, **silos** launch missiles straight up, and **radar dishes** are worth 1000.
- **Open space** has no deck, so no ring: interceptors weave toward you at altitudes of their own, dive to your height for an attack run, peel away after it, and jink up or down when you line up on one and shoot. They attack and dodge more often on later levels.
- **The citadel** holds the Warden. Its armour petals open from time to time; hit the core while it is exposed.
- **Twelve levels** ramp up from a gentle start: level 1 is short and slow, with wide windows, low walls, half the stretches empty, few turrets, no silos and two or three interceptors that rarely fire. Each level after that is longer and faster, with narrower gaps, more and quicker-firing enemies, silos from level 3, blinking fields from level 3 and a tougher Warden. `Game.ramp` in `game.gd` sets every value from level 1 to level 12; after 12 the game goes on at the hardest setting.
- The high score is kept in the browser.

Controls: arrows or WASD to steer and climb, Space to fire, P to pause, Enter to start. A gamepad works too.

## Code

| Path | What it is |
| --- | --- |
| `godot/` | The Godot 4.7 project. `scripts/main.gd` (scene root, camera, game flow), `game.gd` and `sfx.gd` (autoloads: state and input, synthesised sound), `level.gd` (streams the fortress in 40-unit chunks from a section plan), `player.gd`, `target.gd` and the targets that extend it, `boss.gd` (the Warden), `hud.gd`; `shaders/` (deck grid, force field, additive glow, sky with a gas giant); `web_shell/shell.html` (the export's page) |
| `web/` | `boot.ts` (starts the engine with a progress bar; the page allows no inline script), `shell.css`, `favicon.svg`, `_headers` (the Content-Security-Policy) |
| `worker/index.ts` | The Worker: the page for anyone holding `games:play`, the engine's parts joined into `index.wasm`, everything else static |
| `test/` | The Worker's tests (`npm test`) |
| `scripts/smoke.sh` | Runs the game headless on autopilot, through the fortress and the boss fight, and fails on any script error (`npm run test:godot`) |
| `build.mjs` | The Godot web export into `dist/games/retro/rampart/`, the engine split into 20 MiB parts (Cloudflare serves files of at most 25 MiB), and the page's files |

Collision layers in the game: 1 ship, 2 player shots, 3 targets, 4 walls, fields and armour, 5 enemy shots.

## Develop

Needs Node 22 and Godot 4.7.2 with its web export templates (`GODOT` names the binary if it isn't `godot` on the PATH).

```sh
npm install
npm test               # the Worker's tests
npm run test:godot     # the headless smoke run
npm run build          # dist/
```

Open `godot/project.godot` in the Godot editor to play it on the desktop (the Forward+ renderer, with SSAO; the web build uses the Compatibility renderer).
The developer flags `godot --path godot -- --autoplay [--level=N] [--goto=N] [--shots=DIR]` start an invulnerable autopilot run, start on level N, jump to chunk N of the level plan (13 is the citadel on level 1, 29 on level 12), and save screenshots to DIR.

## Deploy

Nothing deploys from GitHub any more: the owner deploys it from their own machine by running `npm run deploy` in this folder (tests, the Godot export, then `wrangler deploy`), with Godot as above and wrangler logged in to icelander.net's Cloudflare account. The Worker has no database and no secrets; its route is `icelander.net/games/retro/rampart*`. The games page lists it from `site/games.json` in the icelander.net repository.
