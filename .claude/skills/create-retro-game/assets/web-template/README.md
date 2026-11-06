# GAME TITLE

> Template from the `create-retro-game` skill. Replace the example game (a lighthouse keeper rationing oil) with the real one, phase by phase, following the skill. Search for `EXAMPLE GAME (replace)`.

Inspired by *ORIGINAL TITLE* (YEAR) by AUTHOR, published by PUBLISHER. This is an independent remake, not affiliated with or endorsed by the original rights holders.

## How to play
…

## Develop

```bash
npm install
npm test          # typecheck + rules, flow, layout and display tests
npm run sheet     # render every screen to docs/contact-sheet.png
npm run build     # bundle into dist/ (BASE_PATH=retro-games/<slug> to nest it)
npm run dev       # rebuild on change
```

| Path | What |
|---|---|
| `src/engine/` | The pure game: state with a seeded RNG, rules, the flow over one `show(screen) → key` interface |
| `src/ui/` | Screen painters, the text table, the pixel art |
| `src/zx/` | Platform layer: the emulated Spectrum display (bitmap, attributes, FLASH), our own 8×8 font, keyboard and touch input, beeper-style sound |
| `test/` | node:test suites; `samples.ts` lists worst-case screens for the layout test and the contact sheet |
| `public/` | Page, styles and `_headers` (strict CSP) |

## Deploy
A static-assets Worker (`wrangler.jsonc`), with its address chosen at the publish gate. `npm run deploy`.
