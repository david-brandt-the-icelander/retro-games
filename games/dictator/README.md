# Samosa

*New dynasty. Same old palace.* You are President Ortiga of Nicaragua. Every month a group of the nation wants something, every refusal makes enemies, and the treasury never quite covers it. There is no winning: a reign ends when you are killed or when you flee the country, and then you are scored.

Inspired by *Dictator* (1983) by Don Priestley, published by DK'Tronics. Independent remake, not affiliated with or endorsed by the original rights holders.

Play it at <https://icelander.net/games/retro/samosa/>. All the games are listed at <https://icelander.net/games/>.

## How to play

Each month:
1. **The books are checked.** The treasury pays the monthly costs. A treasury in debt costs you the goodwill of the army and State Security, and thins your bodyguard.
2. **An audience.** A group asks a favour. Ask your adviser what it would do to everyone, then grant it or refuse it. Refusing costs the group the goodwill it would have gained. If the treasury can't cover it, you must refuse.
3. **Dangers.** An assassin may strike; Honduras may threaten war, or invade.
4. **Your decision.** Take one decision from five sections, or none: reward a group, please everyone, look after yourself (secret police, more guards, a helicopter, a Swiss account), find money (loans from Moscow or Washington, seizures), or make a group stronger.
5. **News**, and perhaps **a revolution**: run (by helicopter if you have one, or on foot over the mountains), or fight with whatever help you can find.

Several times a month State Security offers you its file for $1,000: every group's popularity (POP.) and strength (STR.), and who is plotting what. It is your only view of the plots.

**Score:** total popularity of all eight groups, plus 3 for every month ruled; if you got out alive, plus 10 and 1 point for every $10,000 in Switzerland. The best score is kept in your browser.

**Keys:** one key per prompt. **Y** means yes; any other key means no, or "go on". **1–5** choose a section of the decision menu, the option numbers choose inside it, and **1–6** ask a group for help in a revolution. On the title, **H** shows how to play and **A** the About page. **M** turns sound on and off at any time. On a phone, a keypad offers the keys that matter, and tapping the screen counts as any key.

## The high-score table

After a reign you may enter the public table under a name of your choosing (up to 12 letters, digits or spaces; accented letters are written plainly, so Davíð becomes David). No email or other personal data is asked for. The server doesn't trust the browser's score: it issued the reign's random seed, and it replays your key presses through the same game engine to compute the score itself. Press S on the title screen to see the table, or open <https://icelander.net/games/retro/samosa/scores/>.

## Develop

```bash
npm install
npm test          # typecheck + rules, flow, input, RNG, pacing, layout, bot and display tests
npm run sheet     # render every screen to docs/contact-sheet.png
npm run build     # bundle into dist/games/retro/samosa/ (BASE_PATH="" builds at the root)
npm run dev       # rebuild on change
```

`npm run sheet` takes an optional pattern to render only some screens, e.g.
`node build.mjs --test && SHEET_PAIRS=1 node dist-test/scripts/contact-sheet.mjs /tmp/report.png "^report"`.

| Path | What |
|---|---|
| `docs/` | The design: `RULES.md` (behaviour), `GDD.md`, `WIREFRAMES.md`, `ART-BIBLE.md`, `UI-DESIGN.md`, `TEST-PLAN.md`, the contact sheet |
| `src/engine/` | The pure game: state with one seeded generator (`state.ts`), the data tables (`data.ts`), the rules (`rules.ts`), the screens and the `show(screen) → key` interface (`screens.ts`), one reign as an async flow (`flow.ts`), and `snapshot()` for parity testing; `index.ts` exports `newGame`, `playGame` and `snapshot` |
| `src/ui/` | One painter per screen kind (`screens.ts`), the drawing vocabulary (`paint.ts`), every player-facing string (`text.ts`), the pixel art (`art.ts`), the sound motifs (`sounds.ts`) and the sound overlay |
| `src/zx/` | Platform layer: the emulated Spectrum display (bitmap, attributes, FLASH), our own 8×8 font, keyboard and touch input, beeper-style sound |
| `src/main.ts` | Wires it together in the browser; the title, how to play, About and sound toggle live here, outside the engine |
| `test/` | node:test suites; `samples.ts` lists the worst-case screens for the layout tests and the contact sheet |
| `public/` | Page, styles and `_headers` (strict CSP) |
| `worker/` | The high-score API (seeds, replay, table) and its D1 schema |
| `src/scores.ts` | The browser's side of the high-score table |

The engine never touches the DOM or timers. `playGame(io, newGame(seed), best)` plays one reign through `io.show(screen)`, which resolves with the raw key pressed (`"y"`, `"Y"`, `"1"`, `"Enter"`…); in tests it resolves at once. It returns `{ score, best }`.

## Deploy

A Worker named `samosa` (`wrangler.jsonc`), routed at `icelander.net/games/retro/samosa*` (the old `icelander.net/retro-games/samosa*` redirects there). It serves the static game, and `worker/index.ts` answers the high-score API under `/retro-games/samosa/api/`, backed by the D1 database `samosa-scores`.

- First time only: `npx wrangler d1 execute samosa-scores --remote --file worker/schema.sql`.
- Deploy: `npm run deploy` (needs `CLOUDFLARE_API_TOKEN`).
- Local: `npx wrangler d1 execute samosa-scores --local --file worker/schema.sql`, then `npm run build && npx wrangler dev`.

## Licence

MPL-2.0, as the rest of this repository.
