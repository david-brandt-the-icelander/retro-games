# Shatterbelt

*Break the belt. Mind your wingmates.* A drifting belt of rock surrounds your ships. Shoot the rocks apart before they hit you, for as long as your ships last. Fly alone, or with up to eight friends, each on their own computer, together (co-op) or against each other (versus).

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

## Controls

One pilot per browser. Press **LAUNCH** (Space, Enter, or tap it) on the title screen to fly alone; to play with friends, each of you on your own computer, start from the multiplayer page (below). Every pilot uses the same controls:

| Controls | Turn | Thrust | Fire | Blink |
|---|---|---|---|---|
| Keyboard | ← / → or A / D | ↑ or W | Space or Enter | ↓ or S |
| Gamepad | stick or d-pad | d-pad up, right trigger or stick up | A or right bumper | B, X or left bumper |
| Touch (phones, tablets) | ◀ ▶ | THRUST | FIRE | BLINK |

The numpad works too (4 / 6 turn, 8 thrusts, 0 fires, 5 blinks). **P** or START pauses a game alone. In the pause screen, **Esc** quits to the title. **M** turns sound on and off. Leaving the tab pauses the game.

## Playing online: each pilot on their own computer

Games with friends start on the multiplayer page, [icelander.net/games/multiplayer](https://icelander.net/games/multiplayer/), not in the game itself. Everyone who plays must be signed in to the games. One player starts a game there and waits; the others join it by choosing the game and typing that player's address (which keeps it in their contacts, so they can see when that friend is waiting). Once two or more are waiting, a 60-second countdown starts, and starts again whenever someone else joins; the game begins when it runs out, or as soon as everyone presses Ready. Each player's browser then opens this game with `?match=ID`. Up to nine pilots, each on their own computer, phone or tablet, play one game together; the lobby offers **Shatterbelt co-op** and **Shatterbelt versus**. Pilots are numbered in the order they joined the lobby's game, and the line under the field shows which one you are, in your colour. Each of you flies with the controls above. An online game can't be paused; press **Esc** twice to leave it. A pilot who leaves stays in the game with an idle ship. Online games go on the public table like any other: each pilot names themselves on their own screen, and the host's browser sends the game with every name. **BACK TO MULTIPLAYER**, under the field, returns to the lobby for another game.

Every browser runs the whole game itself, in lockstep (`src/online.ts`). Each one sends only its own player's controls, a few steps ahead of when they are played (the delay, set when the game starts from everyone's measured connection: usually 60–150 ms). A browser steps the game only once it has every player's controls for that step, so every browser plays exactly the same game; it is the same property that lets the server replay a game for the high-score table. Every 120 steps (a second or two) the browsers compare a fingerprint of their games, and end the game if they ever differ. A browser that falls behind (a slow connection, or a hidden tab) makes the others wait, and they say so.

The relay is the games hub's, not this game's: a Cloudflare Durable Object per match in the `recreations` repository (`worker/match.ts`), at `GET /multiplayer/match/{ID}` (a WebSocket). It lets in only the signed-in players the lobby put in the match, each in their place in the lobby, and passes each one's messages to the others in order. `src/online.ts` and `test/online.test.ts` are the same files in Rally, Shatterbelt and Hivestorm.

## The high-score table

At the end of a game, every pilot who made the table types a name, up to 12 letters or digits, in a form over the screen (Esc or SKIP leaves them off). Names are cleaned the same way in the browser and on the server by `src/name.ts`, the same rules as Samosa and Hivestorm: accented letters lose their accents and a few are spelled out (Davíð → David, Þór → Thor). The public table is at <https://icelander.net/games/retro/shatterbelt/scores/>, and its top rows are on the title screen. No email address or other personal data is stored, only the name.

The server doesn't trust the browser's score. It issues each game's random seed, and the browser records every change of every player's controls. At the end, the server replays that recording through the same game engine and lists the scores the replay produces. Each seed can be submitted once. To make a replay come out exactly as the game was played, the engine uses its own sine, cosine and arctangent built from basic arithmetic (`src/engine/dmath.ts`), which every JavaScript engine computes to the same bit.

When the server can't be reached at the start of a game, the game still plays, and its scores are kept on this device only. This device's own top ten is kept in the browser either way.

## Develop

```bash
npm install
npm test          # typecheck, then the engine rules and whole-game simulations (1–9 players, both modes, as online games have)
npm run build     # bundle into dist/retro/shatterbelt/ (BASE_PATH="" builds at the root)
npm run dev       # rebuild on change
```

| Path | What |
|---|---|
| `src/engine/` | The pure game: every tuning number (`config.ts`), the seeded generator (`rng.ts`) and the simulation (`game.ts`). `step(game, controls[])` advances one 1/60 s step and lists what happened in `game.events`. No DOM, no timers, no `Math.random`. |
| `src/input.ts` | The keys, gamepads and touch, turned into this browser's pilot's `Controls` |
| `src/render.ts` | Canvas drawing: field, effects, HUD, title, pause, game over, the high-score screens |
| `src/name.ts` | A player's name for the tables, cleaned the same way in the browser and on the server (shared with Samosa and Hivestorm) |
| `src/sound.ts` | Sound effects made with Web Audio; no sound files |
| `src/engine/replay.ts` | Recording a game's controls, and replaying a recording; shared with the server |
| `src/engine/dmath.ts` | Sine, cosine, arctangent and hypotenuse that give the same bits in every JavaScript engine |
| `src/net.ts` | The browser's side of the public table: a seed per game, submitting a game, loading the table |
| `src/scores.ts` | This device's best ten, kept in the browser (localStorage) |
| `worker/` | The Worker: the score API (seeds, replay, table), the public scores page in icelander.net's look, the redirect from the old address, and the D1 schema |
| `src/main.ts` | Screens, the fixed-step frame loop, online games, and the wiring |
| `src/online.ts` | Online play in the browser: the match's WebSocket and the lockstep |
| `test/` | node:test suites: `engine.test.ts` (each rule on its own), `sim.test.ts` (long random games, replay from a seed, bots), `replay.test.ts` (recordings replay exactly, the server's checks, the deterministic maths), `online.test.ts` (the lockstep) |
| `public/` | Page, styles and `_headers` (strict CSP) |

## Deploy

A Worker named `shatterbelt` (`wrangler.jsonc`), routed at `icelander.net/games/retro/shatterbelt*`. Its route runs before the games hub (the `recreations` Worker), which is the hub's route icelander.net/games/*. It serves the static game, and `worker/index.ts` answers the high-score API under `/games/retro/shatterbelt/api/` and the page at `/games/retro/shatterbelt/scores/`, backed by the D1 database `shatterbelt-scores`. It also answers the game's first address, `icelander.net/retro-games/shatterbelt*`, and redirects it to the new one with a 308. Its `migrations` delete the Durable Object class `Room`, which held online rooms before they moved to the games hub; keep both entries.

- First time only: `npx wrangler d1 execute shatterbelt-scores --remote --file worker/schema.sql`.
- Deploy: `npm run deploy` (test, build, `wrangler deploy`; needs `CLOUDFLARE_API_TOKEN`).
- Local: `npx wrangler d1 execute shatterbelt-scores --local --file worker/schema.sql`, then `npm run build && npx wrangler dev`.

## Licence

MPL-2.0, as the rest of this repository.
