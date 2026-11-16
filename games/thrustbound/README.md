# Thrustbound

An original jetpack arcade game, made in Godot 4 for the web and served at
<https://icelander.net/games/retro/thrustbound/> to anyone signed in to icelander.net.

Fly a jetpack, find the rocket's two loose parts and stack them on the launch pad, catch six fuel
pods as they fall, then board the rocket and lift off. A new kind of alien arrives each level, and every
fourth level the rocket is scrap and a new model has to be built. Crystals that fall from the sky are
bonus points; there is an extra life every 10,000 points.

| Action | Keyboard | Gamepad |
|---|---|---|
| Move | A/D or ←/→ | Left stick / D-pad |
| Jetpack | W or ↑ | A |
| Fire | Space, J or Ctrl | X / RB |
| Pause | Esc or P | Back |

## Provenance

The game loop (jetpack, rocket assembly, fuel, waves of aliens) is a well-known arcade genre. Everything
in this folder was written from scratch: the name, the astronaut, the aliens, the rocket, the
backgrounds and the HUD are drawn in code (`godot/scripts/gfx.gd` and each entity's `_draw`), and every
sound is synthesised at startup (`godot/scripts/sfx.gd`). There are no image, sound or font files, and
no text, graphics, sound or code from any earlier game.

## Code

- `godot/`: the Godot 4.7 project (Compatibility renderer, for the web). `scripts/main.gd` runs the game
  (states, spawning, collisions, scoring, levels); `player.gd`, `alien.gd`, `rocket.gd`, `item.gd`,
  `laser.gd` and `explosion.gd` are the things on screen; `background.gd` and `hud.gd` draw the world and
  the overlays; `world.gd` holds the screen's layout and the wrap-around helpers. `web_shell/shell.html`
  is the page the export is built into.
- `web/`: the page's loader script (`boot.js`), styles, icon and `_headers` (a strict Content-Security-Policy).
- `worker/index.ts`: the Worker. It asks for icelander.net's sign-in (role `games:play`) before serving the
  page, joins the engine's parts back into `index.wasm`, and serves everything else as static assets.
- `test/`: the Worker's tests (`npm test`). `npm run test:godot` plays the game headless with the
  `--selftest` argument, which drives the controls and fast-forwards through building, fuelling, a
  launch and a death, and fails on any script error.

The best score is kept in the browser (`user://thrustbound.save`); there is no server-side table.

## Build and deploy

Needs Godot 4.7.2 with its web export templates on the PATH as `godot` (or set `GODOT`).

```bash
npm install
npm test && npm run test:godot
npm run build      # dist/games/retro/thrustbound/, with the engine split under Cloudflare's 25 MiB limit
```

A merge to `main` deploys it (`.github/workflows/deploy.yml`); `npm run deploy` does the same by hand.
It has no database and no secrets.
