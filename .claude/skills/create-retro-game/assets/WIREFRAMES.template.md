# <Working title>: UI wireframes

Status: draft · Phase 3 of create-retro-game · Check: `python3 -I scripts/wireframe_check.py docs/WIREFRAMES.md`

Notation: 32×24 cells per screen. `.` is empty, `#` is decoration, and letters and digits are regions explained in each screen's legend (see `references/wireframes.md`). The two screens below are an example; replace them.

## Screen: title
Kind: extra · Input: any key, H · Timed: no

```wireframe
################################
#..............................#
#...TTTTTTTTTTTTTTTTTTTTTTTT...#
#..............................#
#..............................#
#.........IIIIIIIIIIII.........#
#.........IIIIIIIIIIII.........#
#.........IIIIIIIIIIII.........#
#.........IIIIIIIIIIII.........#
#..............................#
#..............................#
#.....PPPPPPPPPPPPPPPPPPPP.....#
#..............................#
#.....HHHHHHHHHHHHHHHHHHHH.....#
#..............................#
#..............................#
#..............................#
#..............................#
#..............................#
#..............................#
################################
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
```

Legend:
- T: game title; ≤ 24 chars; centred; BRIGHT
- I: title image, 12×4 cells (art bible: title concept)
- P: "press a key to play" prompt; ≤ 20 chars
- H: how-to-play hint; ≤ 20 chars
- K: footer prompt; rows 21–23; waits for a key

## Screen: night-report
Kind: report · Input: any key · Timed: no

```wireframe
RRRRRRRRRRRRRRRRRRRRRRRRRRRRRRRR
................................
..LLLLLLLLLLLLLLLLLL..NNNNNNNN..
..LLLLLLLLLLLLLLLLLL..NNNNNNNN..
..LLLLLLLLLLLLLLLLLL..NNNNNNNN..
..LLLLLLLLLLLLLLLLLL..NNNNNNNN..
................................
..MMMMMMMMMMMMMMMMMMMMMMMMMMMM..
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
................................
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
KKKKKKKKKKKKKKKKKKKKKKKKKKKKKKKK
```

Legend:
- R: report header with the night number; ≤ 32 chars
- L: list of resources, one per row; labels ≤ 18 chars
- N: value meters, one per row; ≤ 8 cells
- M: one-line summary; ≤ 28 chars
- K: footer prompt; rows 21–23

## Flow

```flow
title -> title [H shows help, then back]
title -> night-report [any key]
night-report -> night-report [any key: next night]
```
