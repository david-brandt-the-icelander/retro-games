# <Working title>: UI design

Status: draft · Phase 5 of create-retro-game · Contact sheet: `docs/contact-sheet.png` · Owner approval: _pending_

## Global patterns
- **Footer prompt (any key):** rows 21–23, …
- **Yes/no and numbered choices:** …
- **Keypad offers:** any-key screens: [KEY]; yes/no: [Y = YES][NO]; menus: the numbers plus [NONE]
- **Responsive:** desktop (integer scale), phone portrait (keypad below), phone landscape (keypad beside)
- **Accessibility:** contrast pairs used, flash rate, live-region text

## Screens

### <screen id>
- **Wireframe:** WIREFRAMES.md § <screen id>
- **Colour family:** …
- **Border:** …

| Region | Cells (rows × cols) | Ink | Paper | BRIGHT | FLASH | Align | Content (final text or icon id) |
|---|---|---|---|---|---|---|---|
| T | 2 × 4–27 | white | blue | yes | no | centre | "…" (≤ 24) |

- **States:** …
- **Input:** keys: …; keypad offers: …
- **Timing:** waits for a key / moves on after … s
- **Sound:** motif id
- **Screen-reader text:** "…"
