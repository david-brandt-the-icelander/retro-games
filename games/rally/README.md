# Rally

*Two paddles. One ball. First to eleven.* A table-tennis game for the browser: play the computer, or a friend on the same keyboard or phone.

Play it at <https://icelander.net/games/retro/rally/>.

Rally is an original game in the paddle-and-ball genre that the earliest arcade and home video games made famous. It doesn't copy any one of them: its name, look, sounds and code are its own. Its scoring follows table tennis.

## How to play

- Hit the ball past the other paddle. The further from your paddle's centre the ball lands, the steeper it leaves (up to 55°). Every return is 6% faster than the last, up to a top speed.
- **First to 11 wins, by two clear points.** The serve changes every two points, and every point from 10–10. The ball rests on the server's paddle for a moment, so the server chooses where to serve from.
- **One player:** you are the left paddle against the computer (easy, normal or hard; the choice is remembered). Use **W/S** or **↑/↓**, drag anywhere on the table, or move the mouse over it.
- **Two players:** left uses **W/S** or drags on the left half; right uses **↑/↓** or drags on the right half. Both can play with keys, or both by touch on one phone or tablet.
- **P** or **Esc** pauses (so does switching away from the tab), and **M** turns sound on and off. On the title screen, **1** and **2** start a game and **H** shows how to play.

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
| `src/main.ts` | Menus, the fixed-step frame loop (120 Hz), the scoreboard and layout. A computer-against-computer match plays behind the menus. |
| `public/` | The page, its styles, and `_headers` (strict CSP: everything comes from this origin) |
| `test/` | node:test suites |

## Deploy

A static-assets Worker named `rally` (`wrangler.jsonc`), routed at `icelander.net/games/retro/rally*`. There is no server code and no database.

```bash
npm run deploy    # test, build, wrangler deploy (needs CLOUDFLARE_API_TOKEN or `wrangler login`)
```

## Licence

MPL-2.0, as the rest of this repository.
