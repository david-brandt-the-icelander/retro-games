# Neon Snake

Snake, made new: a glowing snake that glides between cells instead of jumping, with combos for quick bites, timed bonus stars and particle bursts, on a board that fits any window, phones included. Made in Godot 4 for the web.

It lives at <https://icelander.net/games/retro/snake/>. Like every game on icelander.net/games it needs a sign-in, with Google or GitHub, through icelander.net's login service.

## How to play

- **Steer** with the arrow keys or WASD, a gamepad's D-pad, or by swiping. Turns are buffered, so a quick up-then-left is not lost.
- **Space**, Enter or a tap starts and restarts; **P** or Esc pauses.
- **Pink orbs** score 10 and make you one longer and a little faster.
- **Combos:** eat the next orb within 2.6 seconds to multiply its score, up to ×5.
- **Gold stars** appear after every fifth orb and last six seconds (the ring counts down): 50 × your multiplier, and three longer.
- **Walls and your own body** end the game. Chasing your own tail is fine: it moves out of the way.
- Your **best score** is kept in your browser.

A wide window gets a 28 × 15 board, a tall one (a phone held upright) a 15 × 24 board.

## How it works

```
godot/                     the game (Godot 4.7, GDScript, Compatibility renderer for WebGL 2)
  main.tscn                one node; its script builds everything else in code
  scripts/main.gd          rules on a fixed tick, drawing interpolated between ticks, the hand-drawn
                           bloom (an additive layer of soft halos), particles, HUD, layout, input, best score
  scripts/sfx.gd           every sound, synthesised into WAVs at start-up: no audio files
  shaders/background.gdshader   the drifting aurora behind the board
  fonts/                   Inter (SIL Open Font License, Inter-OFL.txt)
  web_shell/shell.html     the page the web export runs in
  tests/test_game.gd       the rules, driven tick by tick
bridge/boot.ts             the page's script: starts the engine and fills the loading bar (the CSP allows no inline script)
web/                       the page's styles, icon and _headers (Content-Security-Policy)
worker/index.ts            the Cloudflare Worker: the page for signed-in players only, and the engine joined from its parts
test/worker.test.ts        the Worker's tests
```

- **No server-side state.** The Worker has no API and no database; the game runs entirely in the browser.
- **The engine file.** Godot's WebAssembly engine is about 39 MB and Cloudflare serves static files of at most 25 MiB, so the build stores it as `index.wasm.0` and `index.wasm.1` and the Worker streams them back as one `index.wasm` (as Gambit's does).

## Develop

You need Node 22 and [Godot 4.7.2](https://godotengine.org/download) with its web export templates (set `GODOT` to its path if it isn't on the PATH as `godot`). To play it on the desktop, open `godot/project.godot` in Godot and press F5.

```bash
npm install
npm test                 # the Worker
npm run test:godot       # the rules, headless
npm run dev              # exports the game, then wrangler dev at http://localhost:8787/games/retro/snake/
```

## Deploy

Nothing deploys from GitHub any more: the owner deploys it from their own machine by running `npm run deploy` in this folder (tests, the Godot export, then `wrangler deploy`), with Godot 4.7.2 and its web export templates installed and wrangler logged in to icelander.net's Cloudflare account. The Worker needs no secrets and no database. It is listed on icelander.net/games from `site/games.json` in the icelander.net repository.
