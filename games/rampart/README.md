# Rampart

An original isometric fortress-run shooter, made in Godot 4 and played in the browser at
[icelander.net/games/retro/rampart](https://icelander.net/games/retro/rampart/) by anyone signed in to icelander.net.
Everything in it is made in code: the models, the shaders and the sound effects, so the project has no binary assets.

## How it plays

- The ship flies forward on its own; you steer it sideways and up and down. **Altitude** is the skill: a cyan ring on the deck sits under the ship and the ALT gauge gives its height.
- **Walls** are either tall, with a green-framed window to thread, or low enough to fly over. **Force fields** block the bottom or the top, and from level 2 some blink on and off.
- **Fuel** drains all the time; shooting **fuel tanks** refuels. Ground targets can only be hit when flying low. **Turrets** aim ahead of you, **silos** launch missiles straight up, and **radar dishes** are worth 1000.
- **Open space** has no deck, so no ring: interceptors weave toward you and you have only the gauge.
- **The citadel** holds the Warden. Its armour petals open from time to time; hit the core while it is exposed. Each level after that is faster.
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
The developer flags `godot --path godot -- --autoplay [--goto=N] [--shots=DIR]` start an invulnerable autopilot run, jump to chunk N of the level plan (19 is the citadel on level 1), and save screenshots to DIR.

## Deploy

A merge to `main` that changes this folder deploys it (`.github/workflows/deploy.yml`, which installs Godot for this game as it does for Gambit). By hand: `npm run deploy`. The Worker has no database and no secrets; its route is `icelander.net/games/retro/rampart*`. The games page lists it from `site/games.json` in the icelander.net repository.
