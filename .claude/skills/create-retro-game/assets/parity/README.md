# Parity kit (verify role)

Proves the remake **plays the same** as a faithful baseline: same seeds, same inputs, the same screens in the same order, the same game state. Copy `parity.ts` to scratch storage and write two adapters beside it. **Never commit the harness**: the baseline adapter imports the private baseline.

## 1. The remake's side (the implementer builds this)
The implementer brief must ask for, in `src/engine/index.ts`:
- `newGame(seed)`, `playGame(io, state, best)` and `snapshot(state)`
- `snapshot` returns the state **in RULES' terms**: the field names and group order that RULES uses, the RNG's raw state included. The verify role writes the exact shape into the brief.
- `screen.kind` uses the GDD's engine kinds; variants are flags on the screen object.
- `show` resolves with the **raw key** (`"y"`, `"Y"`, `"Enter"`); the engine applies RULES' key semantics. Timed screens go through `show` too and ignore their key.

## 2. Adapters (verify role)
Each adapter runs one game and returns `Step[]`:
```ts
const steps: Step[] = [];
const io = { async show(screen) {
  const kinds = canonical(screen);              // e.g. ["newsAlert", "newsHeadline"]
  const key = pol.key(kinds[0], screen);
  for (const k of kinds) steps.push({ kind: k, state: snap(state) });
  return key;                                   // baseline: key.toLowerCase() if its UI lower-cases
} };
await playGame(io, state, best);
steps.push({ kind: "end", state: snap(state) });
```
- **Canonical kinds.** Map both games onto the GDD's engine kinds. Where one game merges two screens and the other splits them, expand the merged one into both kinds. Fold variants into the kind when they change what the key means (`dialog` vs `dialogUnaffordable`, `reportOffer` vs `reportOfferNone`).
- **Baseline switches.** Set every baseline switch to match the owner's decisions (e.g. a quirk the remake switches off), and say so in the report.
- **Key handling.** Pass keys the way each game's UI would: if the baseline's UI lower-cases keys before its engine sees them, the adapter does too.

## 3. Policies and the run
- Use `policy(seed, choices, neutral)`. It draws only on decision kinds, so screens shown by only one game can't desync the inputs.
- Run at least **10,000 games per policy**:
  - **random:** valid and invalid keys, both cases
  - **eager:** mostly yes, and the first options
  - **invalid:** junk keys everywhere, using `junkFor`
- `diff(a, b, { checked, remakeOnly })`:
  - `checked` is every decision kind, every screen that displays the game's numbers (reports, treasury, rating), and `"end"`
  - `remakeOnly` is any screen the remake adds
- Bundle with the game's esbuild and run with node:
  ```bash
  node_modules/.bin/esbuild run.ts --bundle --platform=node --format=esm --outfile=run.mjs && node run.mjs 10000
  ```

## 4. Reading the result
- **`first` set:** a real difference, a bug unless RULES documents it. Fix the remake (or RULES, if the spec was wrong), never the comparison.
- **`reordered` counts:** state that changed one screen earlier or later than in the baseline, around a screen with no decision and no numbers. Typical cases:
  - a death flag set before the death screen
  - a rally applied before its announcement

  List every `kind:field` in TEST-PLAN.md, with the RULES section that makes it harmless.
- **The report:** games, steps, differences (0) and the reordered kinds. Paste it into TEST-PLAN.md and the PR.
