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
Use this when a faithful baseline or an executable model of the original exists.

- Put the harness in scratch storage, **never in the repo**. It imports the baseline's engine (pinned commit) and the remake's engine.
- Give both the same seed and the same scripted inputs. Input policies: always the first option, always yes, always no, random valid keys, random including invalid keys, and boundary values.
- Compare after every screen:
  - the screen *kind*: the wording differs on purpose
  - the full game state, mapped field by field (names differ between the codebases, so write the mapping explicitly)
  - the RNG position
- Play at least 10,000 games per policy.
- Every difference is a bug, unless RULES documents it as a deliberate restoration of the original's behaviour. Report the games and steps compared, and each difference with its explanation.

## 4. Clean-room checks
```bash
python3 -I ../clean-room-rebuild/scripts/overlap.py <listing> <manual.txt> games/<slug> --names <InventedName>...
python3 -I ../zx-spectrum-clean-room/scripts/zx_assets.py <listing> games/<slug>
```
- Both must report nothing, except entries accepted in PROVENANCE (e.g. the factual credit line's names).
- Add a **guard test**: store SHA-256 hashes of the original's normalised strings (never the strings), and fail if any player-facing string in `src/ui/text.ts` hashes to one of them.

## 5. Browser (Playwright, against the built page)
- Play full games by keyboard on desktop, and by tapping on phone portrait and phone landscape (Playwright device profiles).
- Assert no page errors or console errors; check that sound is driven (count oscillator starts) without asserting how it sounds.
- Run the CSP under `wrangler dev` (headers present, no violations during a playthrough).
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
