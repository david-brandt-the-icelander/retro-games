# Provenance

Remake of: *Title* (year, platform) by Author, published by Publisher.
Reference material used (kept outside this repo): listing / disassembly / manual / screenshots — with source URLs.

Verdicts: **keep** (functional, not protected) · **replace** (copied expression) · **decide** (needs the user).

| # | Item | File(s) | Origin | Category | Verdict | Action taken |
|---|------|---------|--------|----------|---------|--------------|
| 1 | Monthly event messages | src/data.ts | original, verbatim | text | replace | Rewritten from purpose descriptions |
| 2 | Revolt probability formula | src/mechanics.ts | original behaviour, own code | code | keep | — |
| 3 | Title / credit screen | src/ui/title.ts | original layout and wording | branding | replace | New title screen; credit line in About |

## Overlap check

```
<paste the summary line from scripts/overlap.py>
```

Accepted leftovers (generic phrases) and why:

- "press any key to continue" — generic UI phrase.

## Open decisions

- [ ] Title: keep "<original>" or one of: …
- [ ] Rename invented names: …
- [ ] Ask the rights holder for permission? Who: …
