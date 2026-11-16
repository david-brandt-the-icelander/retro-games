# Neon Cycles

A modern light-cycle arena game, made in Godot 4 for the browser. You and three computer riders race across a neon grid, each leaving a glowing wall behind. Hit a wall, a trail or another bike and you are derezzed. The last rider left wins the round, and the first to five rounds wins the match.

It is not a copy of any particular game: the riders, arena and effects are its own, and every mesh, material and effect is made in code or a shader, with no imported assets.

## Play

At [icelander.net/games/retro/neon-cycles](https://icelander.net/games/retro/neon-cycles/), signed in to icelander.net (the games are part of the site; the Worker checks the sign-in with `vendor/icelander-auth/`). It needs a browser with WebGL 2.

## Controls

| Action | Keyboard | Touch | Gamepad |
|---|---|---|---|
| Turn left / right | A / D or ← / → | Tap the left or right half of the screen | LB / RB or d-pad |
| Boost (uses energy, which refills) | Space, W or ↑ | | A |
| Pause | Esc or P | | |
| Restart the round | R | | Back |
| Skip ahead after crashing, new match | Enter | Tap | Start |

## How it plays

Riders move only in straight lines and turn 90 degrees. A crashed rider's trail sinks away after a moment and stops blocking. The computer riders look ahead along their path and to each side, turn away from walls into open space, take the odd random turn, and sometimes try to cut across the player's path. The camera follows your bike, and once you crash it follows a rider still racing. Nothing is kept between visits.

## Develop

```bash
npm install
npm test             # the Worker's tests (sign-in and the joined engine file)
npm run test:godot   # the headless Godot test: arena rules, then rounds on autopilot
npm run build        # exports the game into dist/games/retro/neon-cycles/
npm run dev          # build, then serve it with wrangler dev
```

Building needs Godot 4.7.2 and its web export templates (set `GODOT` to its path if it isn't on the PATH as `godot`). To work on the game itself, open `godot/project.godot` in the Godot editor and press F5.

| Path | What it is |
|---|---|
| `godot/scenes/main.tscn` | The one scene: a node whose script builds everything else |
| `godot/scripts/main.gd` | Rounds and scores, the arena and skyline, lighting, the camera, the HUD, collisions and the rays the AI uses |
| `godot/scripts/light_cycle.gd` | A rider: movement, boost, trail walls, the AI, the bike model, and the crash and derez effects |
| `godot/scripts/minimap.gd` | The radar in the top right |
| `godot/shaders/` | The light walls (trails and the arena edge) and the glossy grid floor |
| `godot/web_shell/shell.html` | The page the web export is written into |
| `godot/tests/test_arena.gd` | The headless test |
| `web/` | The page's loading screen and `boot.js`, which starts the engine, plus the favicon and `_headers` |
| `worker/index.ts` | The Worker: the sign-in on the page, and the engine joined from its parts |
| `test/` | The Worker's tests |

The web export uses the Compatibility renderer (WebGL 2), keeps the glow and leaves out threads, so the page needs no cross-origin isolation headers. Its Content-Security-Policy forbids inline script, so the export's configuration sits in the page as JSON and `boot.js` starts the engine with it. The engine is about 38 MiB, more than the 25 MiB Cloudflare serves as one static file, so `build.mjs` splits it into `index.wasm.0`, `.1`, … and the Worker streams them back as one `index.wasm`, as Gambit does.

## Deploy

Pushing to `main` deploys it (`.github/workflows/deploy.yml`), or run `npm run deploy` here. It has no database and no secrets: the sign-in is icelander.net's login service, through the `ACCOUNTS` service binding and the public keys in `ACCOUNTS_JWKS` in `wrangler.jsonc`.

## Licence

MPL-2.0, as the rest of this repository.
