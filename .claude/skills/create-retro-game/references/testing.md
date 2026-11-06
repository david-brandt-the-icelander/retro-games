# Testing and verification

Two questions decide whether a remake is done: *does it play the same?* and *is it new?* The tests below answer both. Record what was run and the results in `docs/TEST-PLAN.md`.

## 1. Rules and flow (node:test)
- **One test per rule in RULES:** set up the state, apply the rule, and check the outcome, including boundaries (≤ vs <, truncation, clamping).
- **Probabilities:** run thousands of seeded trials and compare the rate with RULES within a tolerance.
- **Flow tests:** drive `playGame(io, newGame(seed))` with scripted keys and assert the *order of screen kinds*, e.g. month 1 shows exactly this sequence.
- **Termination:** every game ends for several input policies (always yes, always no, random keys, invalid keys) over hundreds of seeds.
- **Quirks:** invalid input, wrong case, and timed screens each get a test.

## 2. Layout (node:test, headless)
- Render every screen kind with **worst-case values**: longest names, the biggest numbers, negative money, every option present, every flag set.
- Assert `clipped === 0`. The template's screen model counts characters drawn off the grid; the painter counts text under the footer and text/art overlaps.
- Assert the key wording and that elements which must flash do, and those which mustn't don't.
- Keep a test that every screen kind the flow can emit has a sample, by collecting kinds from a few hundred games.

## 3. Parity (verify role, scratch only)
Use this when a faithful baseline or an executable model of the original exists. The kit is in `assets/parity/` (README and `parity.ts`).

- Put the harness in scratch storage, **never in the repo**. It imports the baseline's engine (pinned commit) and the remake's engine.
- The remake exposes `newGame(seed)`, `playGame(io, state, best)` and `snapshot(state)` in RULES' terms (see `implementation.md`). Write the snapshot's exact shape into the implementer's brief; map the baseline's state onto it in the baseline adapter.
- **Canonical kinds:** map both games' screens to the GDD's engine kinds, expanding a merged screen into the kinds the other game splits it into, and folding variants that change what the key means into the kind.
- **Policies draw only on decision screens.** A policy that draws a random key on every screen desyncs as soon as one game shows a screen the other doesn't (a split screen, an added funeral). Use the kit's `policy()`. Policies: random (valid and invalid keys, both cases), eager (mostly yes, first options), invalid (junk keys via `junkFor`).
- **Key handling:** pass keys as each game's UI would (e.g. lower-cased, if the baseline's UI does that).
- **Baseline switches:** set them to match the owner's decisions, and say so.
- **Compare:**
  - screen kinds at every step
  - the full state exactly at every decision screen, every screen that shows the game's numbers, and the end
  - between those, report state changes that sit one screen earlier or later (`reordered`): they are presentation order, but list each `kind:field` in TEST-PLAN.md with its reason
  - **what each screen displays**, too: map the numbers each screen carries (month, money, popularities) on both sides and compare them, or assert in the adapter that the remake's screen payload equals the values derived from its own snapshot. State parity alone can't see a screen printing a stale number.
- Play at least 10,000 games per policy (30,000 games of a 100-step game run in under a minute).
- Every difference is a bug, unless RULES documents it as a deliberate restoration or an owner decision. Report games, steps, differences and the reordered kinds.

## 4. Clean-room checks
```bash
python3 -I -B ../clean-room-rebuild/scripts/overlap.py <listing> <manual.txt> games/<slug> --names <InventedName>...
python3 -I -B ../zx-spectrum-clean-room/scripts/zx_assets.py <listing> games/<slug>
```
- Both must report nothing, except entries accepted in PROVENANCE (e.g. the factual credit line's names).
- **Guard test:** the web template ships `test/guard.test.ts`, which skips until the verify role adds `test/original-hashes.json`:
  ```bash
  python3 -I -B scripts/make_guard_hashes.py <listing> <manual.txt> --names <InventedName>... > games/<slug>/test/original-hashes.json
  ```
  It holds only truncated hashes, so it is safe in a public repo. Prove it works once by planting a name in a source file, seeing the test fail, and removing it.
- **When a hit appears**, give the designer the file, line and matched phrase only, and ask for the *whole message* to be rewritten. Don't hand the designer lists of the original's text in advance.

## 5. Browser (Playwright, against the built page)
- Play full games by keyboard on desktop, and by tapping on phone portrait and phone landscape (Playwright device profiles).
- Assert no page errors or console errors; check that sound is driven (count oscillator starts) without asserting how it sounds.
- Run the CSP under `wrangler dev` (headers present, no violations during a playthrough), and again on the live page after deploying.
- **Measure touch targets** in the browser (each visible button's bounding box ≥ 44 × 44 CSS px), including the sound button.
- **Cloudflare Web Analytics:** if the zone has it on, Cloudflare injects a beacon script into every HTML page, and the strict CSP blocks it (a console error on the live page only). Keeping it blocked matches a "no tracking" GDD; otherwise the owner can exclude the path or allow the beacon. Report it; don't loosen the CSP on your own.
- Check timed screens move on by themselves and keyed screens wait.

## 6. Visual review
- Generate the contact sheet (`npm run sheet`) and look at every screen. Ask:
  - would anyone mistake it for the original?
  - is it readable on a phone?
  - does it follow the art bible?
- Sample a FLASH cell at two times to prove flashing works in the real display.

## 7. Accessibility
- Every screen sets the live-region text.
- Full keyboard play, with no mouse needed.
- Touch targets of at least 44 px.
- Flashing under 3 Hz.
- No information carried by colour or sound alone.
