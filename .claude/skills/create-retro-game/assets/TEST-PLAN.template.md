# <Working title>: test plan and results

Status: phase 7 of create-retro-game

| # | Area | What | How | Result |
|---|---|---|---|---|
| 1 | Rules | One test per RULES rule, including boundaries | `npm test` | _n passed_ |
| 2 | Probabilities | Seeded rates within tolerance | `npm test` | |
| 3 | Flow | Screen-kind order; every game ends for each input policy | `npm test` | |
| 4 | Quirks | Invalid input, case, timed screens | `npm test` | |
| 5 | Layout | Every screen at worst case: clipped = 0; flash where designed | `npm test` | |
| 6 | Parity | ≥ 10,000 games per policy vs the baseline; full state each step | scratch harness | _games / steps / diffs_ |
| 7 | Text overlap | `overlap.py` with `--names` | clean-room-rebuild | _summary line_ |
| 8 | Assets | `zx_assets.py` (UDGs and tunes) | zx-spectrum-clean-room | _summary line_ |
| 9 | Guard | Hashes of original strings never reappear | `npm test` | |
| 10 | Browser | Full games: desktop keyboard, phone portrait and landscape taps; no console errors | Playwright | |
| 11 | CSP | Headers present; no violations during play | `wrangler dev` + Playwright | |
| 12 | Visual | "Mistakable for the original?": no, for every screen | contact sheet review | |
| 13 | Accessibility | Live-region text, keyboard-only, 44 px targets, flash < 3 Hz | manual + Playwright | |

## Parity differences
| Difference | Explanation (RULES §) | Accepted by |
|---|---|---|

## Accepted overlap entries
| Entry | Reason |
|---|---|
| Names in the credit line | Factual attribution |
