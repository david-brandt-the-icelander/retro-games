# Implementation

The implementer builds the game from `docs/` alone: RULES, GDD, WIREFRAMES, ART-BIBLE and UI-DESIGN. Start by copying `assets/web-template/` to `games/<slug>/` and filling in its placeholders (name, base path).

## Architecture

```
src/
  engine/   pure game: state, rules, the turn flow (no DOM, no timers)
  ui/       screen painters: one function per screen kind, using the template's painter
  zx/       platform layer from the template: screen model, display, font, input, sound
  main.ts   wires engine + painters + platform; presentation-only extras (intro, About)
```

- **State** is one plain object, created by `newGame(seed)`. Everything the rules need is in it, so a test can set up any situation.
- **Randomness** comes from one seeded generator kept in the state. Draw from it **in exactly the order RULES gives**: the same seed must give the same game. That is what makes parity testing possible, and it is part of the behaviour.
- **Rules** are small pure functions, named for what they do in *this* game, not for the original's routines, line numbers or variable names. Each takes the state and returns or mutates only what RULES says.
- **The flow** is an async function that plays one game. It talks to the outside world only through an interface:
  ```ts
  interface IO { show(screen: Screen): Promise<string> }   // resolves with the key pressed
  ```
  `Screen` is a discriminated union of every screen kind with the data it shows. The browser implements `show` by painting and waiting for input; tests implement it with a script. Keep presentation-only screens (intro, help, About) outside the engine.
- **The parity hook.** When there is a baseline, `src/engine/index.ts` also exports `snapshot(state)`: the state in RULES' terms (RULES' field names and group order, the RNG's raw state included), in the exact shape the verify role gives in the brief. The verify role snapshots at every `show`, before the key is applied.
- **Keys reach the engine raw** (`"y"`, `"Y"`, `"Enter"`, `" "`). The engine applies RULES' key semantics itself, so the browser layer never decides what a key means. Platform keys (such as M for sound) are taken by the input layer and never reach the engine.
- **Every screen goes through `show`**, timed ones included; the engine ignores the key a timed screen returns. Pacing lives in the presentation layer, so changing it (an owner may ask for every screen to wait for a key) never touches the engine.
- **State changes around screens.** Apply each change at the point RULES gives. Where RULES doesn't say whether a change happens before or after a screen with no decision on it (a death flag, a rally), pick one and list it in your report: parity tolerates it around such screens, but not at decision screens or screens that print numbers.
- **Screens print the state they are shown in.** Fill a screen's numbers from the state at the moment of `show`, never from a copy taken earlier; the verify role checks displayed values against the snapshot.
- **Painters** draw one screen kind each, from the UI design. They return the keys to offer on the touch keypad. Text and colours live in the painters or a text table, never in the engine.
- **Text:** keep every player-facing string in one module (e.g. `src/ui/text.ts`). That makes the overlap check, translation and review easy.

## Clean-room discipline
- Don't open the original, its listing or the faithful baseline while coding. If RULES is unclear, ask the spec role (or the owner), and get RULES updated rather than peeking.
- Use your own names, data structures and control flow. Restate numeric tables in a shape that suits the code (e.g. objects with named fields), not the original's encoding or layout.
- No comments that reference the original's line numbers, routines or text.

## Platform layer (from the template)
- `zx/screen.ts`: a 256×192 bitmap, 32×24 attributes (ink, paper, BRIGHT, FLASH) and a border, with a pure RGBA renderer. It also keeps a text mirror (`textRows()`) and a `clipped` counter for layout tests.
- `zx/display.ts`: draws to a canvas, FLASH at the hardware rate, integer scaling, fitting phones.
- `zx/font.ts`: our own 8×8 font. Extend it, never replace it with the ROM font.
- `zx/input.ts`: one key per prompt; reserved keys (e.g. M for sound); a touch keypad offering the keys that matter; tap-to-continue; optional timeouts for screens that move on by themselves.
- `zx/sound.ts`: square-wave notes and noise, silent until the first key. **The tunes are yours to compose** (art bible); the template ships none.
- `ui/paint.ts`: page, band, text, multi-part lines (e.g. one flashing word), word wrap, tiling, icons with overlap tracking, footer.

## Deploying
- The template's `wrangler.jsonc` serves `dist/` as static assets. `BASE_PATH` in `build.mjs` nests the site, e.g. under `retro-games/<slug>/`, when it shares a domain.
- `public/_headers` sets a strict CSP. Everything the game needs is served from its own origin, with no CDNs.
- Deploy only after the publish gate.
