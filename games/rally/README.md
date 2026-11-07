# Rally

*Two paddles. One ball. First to eleven.* A table-tennis game for the browser: play the computer, a friend on the same keyboard or phone, or a friend on another computer.

Play it at <https://icelander.net/games/retro/rally/>.

Rally is an original game in the paddle-and-ball genre that the earliest arcade and home video games made famous. It doesn't copy any one of them: its name, look, sounds and code are its own. Its scoring follows table tennis.

## How to play

- Hit the ball past the other paddle. The further from your paddle's centre the ball lands, the steeper it leaves (up to 55°: the engine works in slopes, not angles). Every return is 6% faster than the last, up to a top speed.
- **First to 11 wins, by two clear points.** The serve changes every two points, and every point from 10–10. The ball rests on the server's paddle for a moment, so the server chooses where to serve from.
- **One player:** you are the left paddle against the computer (easy, normal or hard; the choice is remembered). Use **W/S** or **↑/↓**, drag anywhere on the table, or move the mouse over it.
- **Two players:** left uses **W/S** or drags on the left half; right uses **↑/↓** or drags on the right half. Both can play with keys, or both by touch on one phone or tablet.
- **Online:** play a friend on another computer, phone or tablet, started from the multiplayer page. See below.
- **P** or **Esc** pauses (so does switching away from the tab), and **M** turns sound on and off. On the title screen, **1** and **2** start a game, **H** shows how to play and **S** the high scores.

## Playing online

Games with friends start on the multiplayer page, [icelander.net/games/multiplayer](https://icelander.net/games/multiplayer/), not in the game itself. Everyone who plays must be signed in to the games. One player starts a game there and waits; the others join it by choosing the game and typing that player's address (which keeps it in their contacts, so they can see when that friend is waiting). Once two or more are waiting, a 60-second countdown starts, and starts again whenever someone else joins; the game begins when it runs out, or as soon as everyone presses Ready. Each player's browser then opens this game with `?match=ID`. The one who joined the lobby's game first plays on the left; the scoreboard shows the other by name. Each of you uses your own keys, finger or mouse, as in a one-player game. An online match can't be paused: **Esc** opens a menu over it while it goes on, from which you can leave. After a match, **BACK TO MULTIPLAYER** returns to the lobby for another. Online matches don't go on the high-score table, which is for matches against the computer.

Every browser runs the whole game itself, in lockstep (`src/online.ts`). Each one sends only its own player's controls, a few steps ahead of when they are played (the delay, set when the game starts from everyone's measured connection: usually 60–150 ms). A browser steps the game only once it has every player's controls for that step, so every browser plays exactly the same game; it is the same property that lets the server replay a game for the high-score table. Every 120 steps (a second or two) the browsers compare a fingerprint of their games, and end the game if they ever differ. A browser that falls behind (a slow connection, or a hidden tab) makes the others wait, and they say so.

The relay is the games hub's, not this game's: a Cloudflare Durable Object per match in the `recreations` repository (`worker/match.ts`), at `GET /games/multiplayer/match/{ID}` (a WebSocket). It lets in only the signed-in players the lobby put in the match, each in their place in the lobby, and passes each one's messages to the others in order. `src/online.ts` and `test/online.test.ts` are the same files in Rally, Shatterbelt and Hivestorm.

## High scores

One-player matches score: each point you win is worth 100 on easy, 200 on normal and 300 on hard, and winning the match adds ten points' worth (1,000, 2,000 or 3,000).

After a match you may put your score on the public table, also at [icelander.net/games/retro/rally/scores](https://icelander.net/games/retro/rally/scores/), under a name of up to 12 characters (capitals, digits, dots, hyphens and spaces), typed in the style of the old arcade tables. Each letter sits over its own underline with a space between, and the cursor blinks under the next one. Type on your keyboard, or tap or click the keys drawn on screen; each key blinks as it is pressed. **DEL** (or Backspace) deletes the last letter, **ENTER** saves and **SKIP** (or Escape) leaves the match off the table. While you type, M is a letter, not the sound key.

The name is remembered for the rest of the browser session, for every game on icelander.net (Samosa uses the same rules). A player signed in at icelander.net/games starts with the part of their email address before the @ (from `/games/me`). No email address is asked for or stored.

**Scores can't be faked.** The server issues each one-player match's seed. The browser records the player's paddle control tick by tick, one entry per change, and the server replays the whole match with the same engine, against the same computer, before it lists the score the replay produced. Each seed enters once. The engine uses only `+ − × ÷` and `√`, which every browser computes to the same bit (not `sin`, `cos`, `pow` or `hypot`, which may differ), so a match played in any browser replays exactly on the server. A 10-minute match replays in about 5 ms.

## The computer

It looks at the ball every so often (0.3 s on easy, 0.08 s on hard), works out where the ball will reach its paddle, bounces included, and moves there at a capped speed. Its guess is off by a random amount that grows with the ball's speed, so fast, sharp returns beat it. On harder levels it also aims off-centre to return sharper shots. The tests check that a whole match always ends with a proper score, and that hard beats easy.

## Develop

```bash
npm install
npm test          # typecheck, then the rules and computer-player tests
npm run build     # bundle into dist/games/retro/rally/ (BASE_PATH="" builds at the root)
npm run dev       # rebuild on change; serve dist/ with any static server
```

| Path | What |
|---|---|
| `src/engine/rules.ts` | The pure game: table size, speeds, the serve, returns, scoring and the win-by-two rule. `step(state, controls, dt)` advances it and returns events. It sub-steps the ball, so even at top speed the ball can't pass through a paddle. |
| `src/engine/ai.ts` | The computer player and its three levels |
| `src/engine/rng.ts` | The seeded generator, so a match replays exactly in tests |
| `src/ui/` | Canvas drawing (`render.ts`), keys/touch/mouse (`input.ts`) and synthesised sound (`sound.ts`) |
| `src/engine/match.ts` | Scoring, and a one-player match as the table sees it: the recorder, and `replay(seed, level, recording)`, which the server runs |
| `src/names.ts`, `src/scores.ts` | The name rules (the same as Samosa's), and the browser's side of the table: seeds, submitting, the session name |
| `src/ui/entry.ts` | The name entry: underlined slots, the blinking cursor, the on-screen keyboard |
| `src/main.ts` | Menus, the fixed-step frame loop (120 Hz), recording, name entry, the table, the scoreboard, online matches and layout. A computer-against-computer match plays behind the menus. |
| `src/online.ts` | Online play in the browser: the match's WebSocket and the lockstep |
| `worker/` | The Worker: the high-score API (seeds, replay, table), the public scores page in icelander.net's look, and the D1 schema |
| `public/` | The page, its styles, and `_headers` (strict CSP: everything comes from this origin) |
| `test/` | node:test suites |

## Deploy

A Worker named `rally` (`wrangler.jsonc`), routed at `icelander.net/games/retro/rally*`. It serves the static game, and `worker/index.ts` answers the high-score API under `/games/retro/rally/api/` and the page `/games/retro/rally/scores/`, backed by the D1 database `rally-scores`. Its `migrations` delete the Durable Object class `Room`, which held online rooms before they moved to the games hub; keep both entries.

```bash
npm run deploy    # test, build, wrangler deploy (needs CLOUDFLARE_API_TOKEN or `wrangler login`)
```

- The database `rally-scores` and its tables exist (created 2026-11-06 with `wrangler d1 create` and `npx wrangler d1 execute rally-scores --remote --file worker/schema.sql`); a later schema change goes in `worker/migrations/`.
- Local: `npx wrangler d1 execute rally-scores --local --file worker/schema.sql`, then `npm run build && npx wrangler dev`, and open `http://localhost:8787/games/retro/rally/`. An online match needs the games hub too, on the same origin (the `recreations` repository).

## Licence

MPL-2.0, as the rest of this repository.
