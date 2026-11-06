# UI wireframes

A wireframe fixes *where things go and what they're for* on each screen, before colour, art or words. On the Spectrum the screen is a grid of 32 × 24 character cells, so wireframes are drawn as text, one character per cell. That makes them exact, diffable and checkable by `scripts/wireframe_check.py`.

## Notation

Each screen is a level-2 heading, a `wireframe` block, and a legend:

````markdown
## Screen: storm
Kind: storm · Input: any key · Timed: no · From: night · To: night-report

```wireframe
################################
#..............................#
#...TTTTTTTTTTTTTTTTTTTTTTTT...#
#..............................#
#.....IIII......................
...
```

Legend:
- T: event title; ≤ 24 chars; centred
- I: storm icon, 4×2 cells
- K: footer prompt; full width; rows 21–23
````

Rules the checker enforces:
- Exactly **24 lines of 32 characters** in each `wireframe` block, so pad with `.`.
- Characters: `.` is empty background and `#` is decoration (border, wallpaper, tiling). Letters `A`–`Z` and `a`–`z` and digits `0`–`9` are **regions**.
- Every region character in the grid has exactly one legend line (`- X: purpose…`), and every legend line is used in the grid.
- Screen ids are unique, and lowercase with dashes.

Write in the legend:
- **purpose:** what the region shows or does
- **budget:** maximum characters or lines (from the GDD)
- **alignment**
- **behaviour:** flashes, timed, appears only when…

Never put final text in a wireframe; use the region letter.

## The flow

After the screens comes one `flow` block. List every transition as `from -> to`, with an optional `[input or condition]`:

````markdown
## Flow

```flow
title -> help [H]
title -> night [any key]
night -> storm [storm rolled]
storm -> night-report [any key]
night-report -> night [any key]
night-report -> ending [ship lost]
```
````

The checker requires every flow node to be a defined screen, and every screen to appear in the flow. Timed screens say so in the condition, e.g. `[after 1 s]`.

## Designing the layouts

- **Start from purpose, not memory.** List what the player must see and decide on this screen, then place it. If you remember the original's layout, deliberately do something else. The art bible's distinctiveness table lists what to avoid.
- **One idea per screen.** Period games show one message at a time with a prompt; keep that rhythm, it's part of the feel.
- **Reserve the same footer** on every screen that waits for a key, so players learn where to look. Its design is ours (phase 4); a footer as such is generic.
- **Leave room for the budget:** a 30-character message in a 32-column region is fine; a 32-character one leaves no margin.
- **Phones:** the canvas scales, so the wireframe still holds. Decide in the UI design what touch keys each screen offers.
- **Every engine screen kind** in RULES and every GDD screen must have a wireframe. The checker can't know the engine's kinds; tick them off by hand against the GDD screen list.

## Check

```bash
python3 -I -B <skill-dir>/scripts/wireframe_check.py games/<slug>/docs/WIREFRAMES.md
```

It exits non-zero and lists every problem: wrong size, unknown characters, undefined or unused regions, duplicate ids, and dangling or missing flow nodes.
