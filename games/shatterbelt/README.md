# Shatterbelt

*Break the belt. Mind your wingmates.* A drifting belt of rock surrounds your ships. Shoot the rocks apart before they hit you, for as long as your ships last. Up to nine pilots play on one screen, together (co-op) or against each other (versus).

Shatterbelt is an original game in the rock-shooter genre that arcades made popular around 1979: turn, thrust, shoot, and the screen wraps at every edge. Its name, look, sounds, rules for crystal and iron rocks, pods, blink, streaks, drones and multiplayer are its own.

Play it at <https://icelander.net/games/retro/shatterbelt/>. It is listed with the other games at <https://icelander.net/games/>.

## How to play

- **Break every rock to clear the wave.** Large rocks split into two medium ones, and medium into two small ones. Crystal rocks (blue) split in three, are worth double and may drop a **pod**: rapid fire, spread shot (three shots at once) or a shield that takes one hit. Rapid fire and spread last 10 seconds. Iron rocks (rust) take two hits and are worth triple. They appear from wave 3.
- **Drones** cross the field and shoot. The large one fires anywhere. The small hunter, from wave 3, aims at the nearest ship.
- **Blink** jumps your ship 230 pixels ahead, and you can't be hurt for half a second. It recharges in 3 seconds; the short bar under your score shows when it's ready.
- **Ships that touch each other are both lost**, in co-op as in versus. A ship that has just appeared blinks; for 3 seconds nothing can hurt it, and it can't hurt others.
- **Streaks:** each hit within 1.6 seconds of your last adds to a streak. Every 5 hits raise your multiplier, up to ×4.
- **Lives:** 3 ships each, and a new ship every 10,000 points. The game ends when every player is out of ships.
- **Co-op:** your shots pass through other ships. **Versus:** they don't, and a takedown is worth 500. The highest score wins.

| Points | Large | Medium | Small |
|---|---|---|---|
| Stone | 25 | 60 | 120 |
| Crystal (×2) | 50 | 120 | 240 |
| Iron (×3) | 75 | 180 | 360 |

Large drone 250, hunter 700, versus takedown 500. Each of these is multiplied by your streak.

## Joining: one to nine players

Choose co-op or versus. On the join screen, each player presses **their own FIRE** to take the next slot. Then press **SPACE** (or START on a gamepad) to launch. A single keyboard player can just press SPACE; they may then use the arrow keys or WASD and fire with SPACE.

| Controls | Turn | Thrust | Fire | Blink |
|---|---|---|---|---|
| Keyboard 1 | A / D | W | Q | S |
| Keyboard 2 | F / H | T | R | G |
| Keyboard 3 | J / L | I | U | K |
| Keyboard 4 | ← / → | ↑ | Enter (or / , right Shift, right Ctrl) | ↓ |
| Keyboard 5 | Numpad 4 / 6 | Numpad 8 | Numpad 0 | Numpad 5 |
| Gamepad (up to 9) | stick or d-pad | d-pad up, right trigger or stick up | A or right bumper | B, X or left bumper |
| Touch (phones, tablets) | ◀ ▶ | THRUST | FIRE | BLINK |

Most keyboards can't register more than a handful of keys at once, so for more than two or three players use gamepads. **P** or START pauses. In the pause screen, **Esc** quits to the title. **M** turns sound on and off. Leaving the tab pauses the game.

The ten best scores are kept in your browser, with three initials.

## Develop

```bash
npm install
npm test          # typecheck, then the engine rules and whole-game simulations (1–9 players, both modes)
npm run build     # bundle into dist/games/retro/shatterbelt/ (BASE_PATH="" builds at the root)
npm run dev       # rebuild on change
```

| Path | What |
|---|---|
| `src/engine/` | The pure game: every tuning number (`config.ts`), the seeded generator (`rng.ts`) and the simulation (`game.ts`). `step(game, controls[])` advances one 1/60 s step and lists what happened in `game.events`. No DOM, no timers, no `Math.random`. |
| `src/input.ts` | The five keyboard key sets, gamepads and touch, turned into one `Controls` per player |
| `src/render.ts` | Canvas drawing: field, effects, HUD, title, join screen, pause, game over, initials |
| `src/sound.ts` | Sound effects made with Web Audio; no sound files |
| `src/scores.ts` | The best-ten table, kept in the browser (localStorage) |
| `src/main.ts` | Screens, the fixed-step frame loop, and the wiring |
| `test/` | node:test suites: `engine.test.ts` (each rule on its own), `sim.test.ts` (long random games, replay from a seed, bots) |
| `public/` | Page, styles and `_headers` (strict CSP) |

## Deploy

A Worker named `shatterbelt` (`wrangler.jsonc`), routed at `icelander.net/games/retro/shatterbelt*`. It serves static assets only. Its route is more specific than the `recreations` Worker's `icelander.net/games/*`, so it wins. It also answers the game's first address, `icelander.net/retro-games/shatterbelt*`, and `public/_redirects` sends that to the new one with a 301.

```bash
npm run deploy    # test, build, wrangler deploy (needs CLOUDFLARE_API_TOKEN)
```

## Licence

MPL-2.0, as the rest of this repository.
