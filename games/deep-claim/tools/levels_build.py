"""Builds the original asteroid-shaft layouts, checks reachability, writes scripts/levels.gd.

Rules every shaft follows:
  * row 19 is a continuous floor and rows 17-18 have no rock, so the buggy can drive the whole floor
  * the buggy starts at the left (B), the exit tunnel door is in the right wall (D, rows 17-18)
Usage (from games/deep-claim): python3 tools/levels_build.py godot/scripts/levels.gd
"""
import sys

W, H = 40, 20
SOLID = set("#<>=D")
ITEMS = set("rpb")


def new():
    g = [["." for _ in range(W)] for _ in range(H)]
    for x in range(W):
        g[0][x] = "#"
        g[H - 1][x] = "#"
    for y in range(H):
        g[y][0] = "#"
        g[y][W - 1] = "#"
    g[17][W - 1] = "D"
    g[18][W - 1] = "D"
    g[18][2] = "B"
    return g


def plat(g, x0, x1, y, ch="#"):
    for x in range(x0, x1 + 1):
        g[y][x] = ch


def put(g, x, y, ch):
    g[y][x] = ch


def items(g, lst):
    for x, y, k in lst:
        if g[y][x] in "gfv" and len(LEVELS) >= 5:
            # an ore lands on a guardian: move the guardian to the nearest free cell in its row
            guard = g[y][x]
            for dx in (2, -2, 3, -3, 4, -4):
                nx = x + dx
                if 0 < nx < W - 1 and g[y][nx] == "." and (guard != "g" or g[y + 1][nx] in SOLID):
                    g[y][nx] = guard
                    break
            else:
                raise SystemExit(f"no room to move guardian at {x},{y}")
        put(g, x, y, k)


LEVELS = []

# ---------------------------------------------------------------- 1
g = new()
plat(g, 10, 15, 19, ">")
put(g, 20, 18, "^"); put(g, 21, 18, "^")
plat(g, 5, 10, 16)
plat(g, 13, 18, 13)
plat(g, 6, 11, 10)
plat(g, 15, 20, 7)
plat(g, 24, 29, 15)
plat(g, 31, 36, 12)
plat(g, 25, 30, 9, "=")
plat(g, 32, 37, 6)
plat(g, 21, 25, 4)
put(g, 28, 18, "g")
items(g, [(8, 15, "p"), (15, 12, "r"), (8, 9, "r"), (17, 6, "b"), (26, 14, "r"),
          (33, 11, "p"), (27, 8, "r"), (34, 5, "b"), (23, 3, "p")])
LEVELS.append(("Regolith Gallery", 130, g, (0.35, 0.6, 1.0)))

# ---------------------------------------------------------------- 2
g = new()
plat(g, 6, 18, 19, "<")
plat(g, 22, 34, 19, ">")
plat(g, 3, 8, 16)
plat(g, 11, 17, 16, "=")
plat(g, 20, 26, 14, "<")
plat(g, 29, 36, 16)
plat(g, 33, 38, 13)
plat(g, 24, 30, 11, ">")
plat(g, 14, 20, 11)
plat(g, 4, 10, 13)
plat(g, 2, 6, 10)
plat(g, 7, 13, 7, "=")
plat(g, 17, 25, 8)
plat(g, 28, 34, 6)
plat(g, 35, 38, 9)
for x in (12, 13, 27, 28):
    put(g, x, 18, "^")
put(g, 31, 15, "g")
put(g, 22, 4, "v")
put(g, 15, 10, "g")
items(g, [(5, 15, "r"), (14, 15, "b"), (23, 13, "r"), (34, 15, "p"), (37, 12, "r"), (27, 10, "b"),
          (17, 10, "r"), (6, 12, "p"), (10, 6, "r"), (21, 7, "r"), (31, 5, "p"), (37, 8, "r"),
          (3, 9, "b"), (20, 2, "p")])
LEVELS.append(("Neodymium Vein", 130, g, (0.75, 0.45, 1.0)))

# ---------------------------------------------------------------- 3
g = new()
for x in range(4, 37):
    if x not in (18, 19, 20, 21):
        put(g, x, 18, "^")
plat(g, 12, 16, 16, "=")
plat(g, 23, 27, 16, "=")
plat(g, 7, 11, 14, "=")
plat(g, 28, 32, 14, "=")
plat(g, 2, 6, 12)
plat(g, 33, 38, 12)
plat(g, 8, 13, 10, "=")
plat(g, 26, 31, 10, "=")
plat(g, 15, 24, 8)
plat(g, 4, 9, 7, "=")
plat(g, 30, 35, 7, "=")
plat(g, 17, 22, 5, "=")
put(g, 19, 7, "g")
put(g, 3, 9, "v")
put(g, 36, 9, "v")
items(g, [(14, 15, "r"), (25, 15, "p"), (9, 13, "b"), (30, 13, "r"), (3, 11, "r"), (37, 11, "b"),
          (10, 9, "p"), (28, 9, "r"), (6, 6, "p"), (33, 6, "r"), (19, 2, "p"), (3, 5, "r")])
LEVELS.append(("Fractured Core", 120, g, (0.55, 0.9, 0.5)))

# ---------------------------------------------------------------- 4
g = new()
plat(g, 5, 11, 16)
plat(g, 14, 20, 14)
plat(g, 2, 8, 12)
plat(g, 10, 15, 10, ">")
plat(g, 18, 24, 11)
plat(g, 25, 31, 15, "<")
plat(g, 33, 38, 16)
plat(g, 33, 38, 12)
plat(g, 26, 31, 9)
plat(g, 17, 23, 6, "=")
plat(g, 6, 12, 6)
plat(g, 28, 37, 6)
put(g, 15, 17, "f")
put(g, 30, 3, "f")
put(g, 13, 8, "v")
put(g, 25, 4, "v")
put(g, 22, 13, "v")
put(g, 7, 11, "g")
put(g, 23, 18, "^"); put(g, 24, 18, "^")
items(g, [(8, 15, "r"), (17, 13, "p"), (3, 11, "b"), (12, 9, "r"), (21, 10, "r"), (28, 14, "p"),
          (35, 15, "b"), (35, 11, "r"), (28, 8, "p"), (20, 5, "r"), (9, 5, "p"), (33, 5, "r"),
          (3, 6, "p")])
LEVELS.append(("Drone Nest", 120, g, (1.0, 0.35, 0.6)))

# ---------------------------------------------------------------- 5
g = new()
plat(g, 8, 14, 19, ">")
plat(g, 25, 31, 19, "<")
for x in (16, 17, 22, 23):
    put(g, x, 18, "^")
plat(g, 2, 7, 16)
plat(g, 10, 15, 14, "=")
plat(g, 18, 21, 16)
plat(g, 24, 29, 14, "=")
plat(g, 32, 38, 16)
plat(g, 33, 38, 12, "<")
plat(g, 26, 31, 10)
plat(g, 17, 23, 11, ">")
plat(g, 9, 14, 9)
plat(g, 2, 7, 11)
plat(g, 3, 8, 6, "=")
plat(g, 11, 17, 4)
plat(g, 20, 26, 6, "=")
plat(g, 29, 35, 5)
put(g, 12, 13, "g")
put(g, 35, 15, "g")
put(g, 20, 8, "f")
put(g, 30, 2, "f")
put(g, 16, 7, "v")
put(g, 32, 8, "v")
items(g, [(4, 15, "r"), (12, 13, "p"), (19, 15, "b"), (26, 13, "r"), (36, 15, "p"), (36, 11, "b"),
          (28, 9, "r"), (20, 10, "p"), (11, 8, "r"), (4, 10, "p"), (5, 5, "r"), (14, 3, "p"),
          (23, 5, "r"), (32, 4, "p"), (37, 6, "p")])
LEVELS.append(("The Iridium Heart", 140, g, (1.0, 0.55, 0.25)))


# ---------------------------------------------------------------- 6
g = new()
plat(g, 8, 14, 19, "<")
plat(g, 3, 8, 16)
plat(g, 11, 16, 14)
plat(g, 19, 24, 12, "=")
plat(g, 27, 32, 14)
plat(g, 34, 38, 16)
plat(g, 30, 36, 11)
plat(g, 22, 27, 9)
plat(g, 14, 19, 8)
plat(g, 5, 11, 11)
plat(g, 3, 8, 8, "=")
put(g, 20, 18, "^"); put(g, 21, 18, "^")
put(g, 28, 13, "g")
put(g, 16, 7, "g")
items(g, [(5, 15, "r"), (13, 13, "p"), (21, 11, "r"), (29, 13, "b"), (36, 15, "r"), (33, 10, "p"),
          (24, 8, "r"), (16, 7, "b"), (8, 10, "p"), (5, 7, "r")])
LEVELS.append(("Basalt Stairway", 130, g, (0.9, 0.75, 0.3)))

# ---------------------------------------------------------------- 7
g = new()
plat(g, 12, 18, 19, ">")
plat(g, 24, 30, 19, "<")
for x in (20, 21, 22):
    put(g, x, 18, "^")
plat(g, 4, 9, 16, "=")
plat(g, 12, 17, 13)
plat(g, 20, 25, 15)
plat(g, 28, 33, 12, "=")
plat(g, 35, 38, 9)
plat(g, 24, 29, 9)
plat(g, 14, 20, 7, "=")
plat(g, 4, 10, 9)
plat(g, 3, 7, 6)
plat(g, 30, 34, 6)
put(g, 14, 12, "g")
put(g, 22, 14, "g")
put(g, 27, 3, "v")
items(g, [(6, 15, "p"), (14, 12, "r"), (22, 14, "b"), (30, 11, "r"), (36, 8, "p"), (26, 8, "r"),
          (16, 6, "r"), (7, 8, "b"), (32, 5, "p"), (5, 5, "r")])

LEVELS.append(("Cobalt Chimney", 125, g, (0.3, 0.8, 0.9)))

# ---------------------------------------------------------------- 8
g = new()
plat(g, 3, 7, 16)
plat(g, 10, 14, 13, "=")
plat(g, 17, 21, 16)
plat(g, 24, 28, 13, "=")
plat(g, 31, 36, 16)
plat(g, 33, 38, 10)
plat(g, 26, 31, 8, "=")
plat(g, 18, 23, 10)
plat(g, 9, 14, 8)
plat(g, 2, 7, 10)
plat(g, 14, 20, 4, "=")
plat(g, 24, 30, 4)
for x in range(8, 33):
    if x % 3:
        put(g, x, 18, "^")
put(g, 19, 9, "f")
put(g, 29, 12, "f")
put(g, 11, 12, "v")
items(g, [(5, 15, "r"), (12, 12, "p"), (19, 15, "r"), (26, 12, "b"), (34, 15, "p"), (35, 9, "r"),
          (28, 7, "r"), (20, 9, "p"), (11, 7, "b"), (4, 9, "r"), (16, 3, "p"), (27, 3, "r")])
LEVELS.append(("Spike Garden", 125, g, (0.95, 0.4, 0.45)))

# ---------------------------------------------------------------- 9
g = new()
plat(g, 6, 34, 19, ">")
plat(g, 3, 9, 16, "<")
plat(g, 12, 18, 13, ">")
plat(g, 21, 27, 15, "<")
plat(g, 30, 36, 13, ">")
plat(g, 24, 30, 10, "<")
plat(g, 15, 21, 9, ">")
plat(g, 6, 12, 10, "<")
plat(g, 3, 8, 7, ">")
plat(g, 12, 18, 6)
plat(g, 28, 36, 7, "<")
put(g, 25, 14, "g")
put(g, 8, 9, "g")
put(g, 33, 12, "g")
items(g, [(6, 15, "r"), (15, 12, "b"), (24, 14, "p"), (33, 12, "r"), (27, 9, "r"), (18, 8, "p"),
          (9, 9, "r"), (5, 6, "p"), (15, 5, "r"), (32, 6, "b"), (36, 6, "p")])
LEVELS.append(("Conveyor Maze", 130, g, (0.6, 0.6, 0.65)))

# ---------------------------------------------------------------- 10
g = new()
plat(g, 4, 9, 16, "=")
plat(g, 12, 17, 14, "=")
plat(g, 20, 25, 12, "=")
plat(g, 28, 33, 14, "=")
plat(g, 35, 38, 11, "=")
plat(g, 28, 33, 9)
plat(g, 20, 26, 7, "=")
plat(g, 12, 18, 10, "=")
plat(g, 4, 10, 11, "=")
plat(g, 6, 12, 8)
plat(g, 15, 21, 4, "=")
plat(g, 28, 36, 6)
put(g, 22, 11, "g")
put(g, 14, 9, "g")
put(g, 30, 8, "g")
put(g, 8, 15, "v")
put(g, 16, 3, "f")
items(g, [(6, 15, "p"), (14, 13, "r"), (22, 11, "r"), (30, 13, "b"), (36, 10, "p"), (30, 8, "r"),
          (23, 6, "p"), (15, 9, "r"), (6, 10, "b"), (8, 7, "r"), (18, 3, "p"), (32, 5, "r")])
LEVELS.append(("Crumbling Mile", 120, g, (0.85, 0.6, 0.45)))

# ---------------------------------------------------------------- 11
g = new()
plat(g, 14, 25, 19, "<")
plat(g, 3, 8, 16)
plat(g, 11, 16, 13)
plat(g, 19, 24, 16, "=")
plat(g, 27, 32, 13)
plat(g, 34, 38, 16)
plat(g, 33, 38, 11, "<")
plat(g, 24, 30, 8)
plat(g, 15, 21, 10, ">")
plat(g, 6, 12, 8)
plat(g, 2, 7, 5)
plat(g, 11, 17, 5, "=")
plat(g, 21, 27, 4)
for x in (8, 9, 10, 31, 32, 33):
    put(g, x, 18, "^")
put(g, 18, 9, "f")
put(g, 29, 7, "f")
put(g, 9, 7, "g")
put(g, 22, 3, "v")
items(g, [(5, 15, "r"), (13, 12, "p"), (21, 15, "r"), (30, 12, "b"), (36, 15, "p"), (36, 10, "r"),
          (27, 7, "p"), (18, 9, "r"), (9, 7, "r"), (4, 4, "p"), (14, 4, "b"), (24, 3, "r")])
LEVELS.append(("Sentry Run", 120, g, (0.5, 0.45, 1.0)))

# ---------------------------------------------------------------- 12
g = new()
plat(g, 3, 6, 16)
plat(g, 9, 12, 14)
plat(g, 15, 18, 16)
plat(g, 21, 24, 14)
plat(g, 27, 30, 16)
plat(g, 33, 37, 14)
plat(g, 30, 34, 11)
plat(g, 23, 27, 8)
plat(g, 16, 20, 10)
plat(g, 9, 13, 8)
plat(g, 3, 7, 10)
plat(g, 3, 8, 5)
plat(g, 12, 17, 5, "=")
plat(g, 21, 26, 5)
plat(g, 30, 36, 5, "=")
for x in range(7, 33):
    if x % 4 != 0:
        put(g, x, 18, "^")
put(g, 22, 13, "g")
put(g, 17, 9, "g")
put(g, 33, 9, "v")
put(g, 14, 3, "f")
items(g, [(4, 15, "r"), (10, 13, "p"), (16, 15, "r"), (22, 13, "b"), (28, 15, "p"), (35, 13, "r"),
          (32, 10, "r"), (25, 7, "p"), (18, 9, "b"), (11, 7, "r"), (5, 9, "p"), (5, 4, "r"),
          (15, 4, "p"), (23, 4, "r")])
LEVELS.append(("Stalactite Hollow", 125, g, (0.4, 0.9, 0.75)))

# ---------------------------------------------------------------- 13
g = new()
plat(g, 8, 13, 19, ">")
plat(g, 27, 32, 19, "<")
plat(g, 3, 8, 16, "=")
plat(g, 11, 16, 14)
plat(g, 19, 24, 16, "=")
plat(g, 27, 32, 13)
plat(g, 34, 38, 16, "=")
plat(g, 33, 38, 10)
plat(g, 26, 31, 9, "=")
plat(g, 18, 24, 11)
plat(g, 10, 15, 9, "=")
plat(g, 2, 7, 11)
plat(g, 2, 8, 6)
plat(g, 12, 18, 5, "=")
plat(g, 22, 29, 5)
put(g, 18, 18, "^"); put(g, 22, 18, "^"); put(g, 23, 18, "^")
put(g, 13, 13, "g")
put(g, 21, 10, "g")
put(g, 30, 8, "f")
put(g, 7, 5, "v")
put(g, 33, 4, "f")
items(g, [(5, 15, "p"), (13, 13, "r"), (21, 15, "r"), (30, 12, "b"), (36, 15, "p"), (35, 9, "r"),
          (28, 8, "r"), (20, 10, "p"), (12, 8, "b"), (4, 10, "r"), (4, 5, "p"), (15, 4, "r"),
          (25, 4, "p")])
LEVELS.append(("Gantry Descent", 120, g, (1.0, 0.7, 0.35)))

# ---------------------------------------------------------------- 14
g = new()
plat(g, 3, 8, 16)
plat(g, 11, 15, 13)
plat(g, 18, 22, 16, "=")
plat(g, 25, 29, 13)
plat(g, 32, 37, 16)
plat(g, 31, 36, 10, "<")
plat(g, 24, 29, 7, "=")
plat(g, 17, 22, 9, ">")
plat(g, 10, 15, 7, "=")
plat(g, 3, 8, 9, "<")
plat(g, 3, 9, 5)
plat(g, 13, 19, 4, "=")
plat(g, 27, 32, 4)
for x in range(6, 35):
    if x % 5 in (1, 2, 3):
        put(g, x, 18, "^")
put(g, 14, 12, "g")
put(g, 27, 12, "g")
put(g, 20, 8, "f")
put(g, 34, 9, "v")
put(g, 6, 4, "f")
items(g, [(5, 15, "r"), (13, 12, "p"), (20, 15, "r"), (27, 12, "b"), (34, 15, "p"), (33, 9, "r"),
          (26, 6, "r"), (19, 8, "p"), (12, 6, "b"), (5, 8, "r"), (6, 4, "p"), (16, 3, "r"),
          (29, 3, "p")])
LEVELS.append(("Magnetic Seam", 120, g, (0.8, 0.5, 0.95)))

# ---------------------------------------------------------------- 15
g = new()
plat(g, 5, 36, 19, "<")
plat(g, 3, 8, 16, "=")
plat(g, 11, 16, 13, "=")
plat(g, 19, 24, 16, "=")
plat(g, 27, 32, 13, "=")
plat(g, 34, 38, 16, "=")
plat(g, 33, 38, 10, "=")
plat(g, 25, 30, 9, "=")
plat(g, 17, 22, 10, "=")
plat(g, 9, 14, 9, "=")
plat(g, 2, 7, 10, "=")
plat(g, 4, 9, 7, "=")
plat(g, 14, 20, 6, "=")
plat(g, 24, 30, 6, "=")
put(g, 12, 12, "g")
put(g, 28, 12, "g")
put(g, 20, 9, "g")
put(g, 6, 9, "f")
put(g, 35, 7, "f")
put(g, 22, 3, "v")
items(g, [(5, 15, "r"), (13, 12, "p"), (21, 15, "r"), (29, 12, "b"), (36, 15, "p"), (35, 9, "r"),
          (27, 8, "p"), (19, 9, "r"), (11, 8, "b"), (4, 9, "r"), (6, 6, "p"), (17, 5, "r"),
          (27, 5, "p")])
LEVELS.append(("The Long Fall", 115, g, (0.9, 0.9, 0.5)))

# ---------------------------------------------------------------- 16
g = new()
plat(g, 8, 12, 19, ">")
plat(g, 16, 20, 19, "<")
plat(g, 24, 28, 19, ">")
plat(g, 32, 36, 19, "<")
plat(g, 3, 7, 16)
plat(g, 10, 14, 14)
plat(g, 17, 21, 16, "=")
plat(g, 24, 28, 14)
plat(g, 31, 35, 16, "=")
plat(g, 35, 38, 13)
plat(g, 29, 33, 10)
plat(g, 21, 26, 9, "=")
plat(g, 13, 18, 10)
plat(g, 4, 9, 11, "=")
plat(g, 3, 8, 8)
plat(g, 11, 15, 7, "=")
plat(g, 19, 24, 6)
plat(g, 28, 34, 7, "=")
for x in (14, 15, 22, 23, 29, 30):
    put(g, x, 18, "^")
put(g, 12, 13, "g")
put(g, 26, 13, "g")
put(g, 15, 9, "f")
put(g, 31, 9, "f")
put(g, 22, 4, "v")
put(g, 6, 5, "v")
items(g, [(5, 15, "r"), (12, 13, "p"), (19, 15, "r"), (26, 13, "b"), (33, 15, "p"), (36, 12, "r"),
          (31, 9, "r"), (23, 8, "p"), (15, 9, "b"), (6, 10, "r"), (5, 7, "p"), (13, 6, "r"),
          (21, 5, "p"), (31, 6, "r")])
LEVELS.append(("Pressure Gate", 115, g, (0.35, 0.7, 1.0)))

# ---------------------------------------------------------------- 17
g = new()
plat(g, 3, 7, 16, "=")
plat(g, 10, 13, 13)
plat(g, 16, 19, 16, "=")
plat(g, 22, 25, 13)
plat(g, 28, 31, 16, "=")
plat(g, 34, 38, 14)
plat(g, 31, 36, 10, "<")
plat(g, 24, 29, 8)
plat(g, 17, 22, 10, ">")
plat(g, 10, 15, 8, "=")
plat(g, 3, 8, 10)
plat(g, 3, 9, 5, ">")
plat(g, 13, 19, 4)
plat(g, 23, 29, 3, "=")
plat(g, 36, 38, 7)
for x in range(5, 34):
    if x % 3 == 1:
        put(g, x, 18, "^")
put(g, 12, 12, "g")
put(g, 24, 12, "g")
put(g, 20, 9, "f")
put(g, 33, 9, "f")
put(g, 6, 9, "v")
put(g, 16, 3, "v")
items(g, [(5, 15, "r"), (11, 12, "p"), (18, 15, "r"), (23, 12, "b"), (30, 15, "p"), (36, 13, "r"),
          (33, 9, "r"), (26, 7, "p"), (19, 9, "b"), (12, 7, "r"), (5, 9, "p"), (6, 4, "r"),
          (15, 3, "p"), (25, 2, "r"), (37, 6, "p")])
LEVELS.append(("Ironstone Spiral", 115, g, (0.75, 0.35, 0.3)))

# ---------------------------------------------------------------- 18
g = new()
plat(g, 3, 6, 16)
plat(g, 9, 12, 14, "=")
plat(g, 15, 18, 12)
plat(g, 21, 24, 14, "=")
plat(g, 27, 30, 16)
plat(g, 33, 38, 15, "=")
plat(g, 31, 35, 12)
plat(g, 22, 26, 9, "=")
plat(g, 17, 21, 8)
plat(g, 10, 14, 10, "=")
plat(g, 3, 7, 8)
plat(g, 4, 10, 5, "=")
plat(g, 14, 19, 5)
plat(g, 23, 28, 5, "=")
plat(g, 32, 37, 5, "=")
for x in range(4, 35):
    if x % 4 in (0, 1):
        put(g, x, 18, "^")
put(g, 16, 11, "g")
put(g, 29, 15, "g")
put(g, 12, 9, "f")
put(g, 22, 7, "f")
put(g, 30, 3, "f")
put(g, 6, 3, "v")
put(g, 34, 10, "v")
items(g, [(4, 15, "p"), (10, 13, "r"), (16, 11, "r"), (22, 13, "b"), (28, 15, "p"), (35, 14, "r"),
          (33, 11, "r"), (24, 8, "p"), (19, 7, "b"), (12, 9, "r"), (4, 7, "p"), (7, 4, "r"),
          (16, 4, "p"), (26, 4, "r"), (35, 4, "p")])
LEVELS.append(("Widowmaker", 110, g, (0.95, 0.3, 0.7)))

# ---------------------------------------------------------------- 19
g = new()
plat(g, 6, 14, 19, ">")
plat(g, 20, 34, 19, "<")
plat(g, 3, 7, 16, "=")
plat(g, 10, 14, 13)
plat(g, 17, 21, 16, "=")
plat(g, 24, 28, 13, "=")
plat(g, 31, 35, 15)
plat(g, 34, 38, 12, "<")
plat(g, 27, 32, 9)
plat(g, 19, 24, 10, ">")
plat(g, 11, 16, 8, "=")
plat(g, 3, 8, 9)
plat(g, 3, 8, 6, "=")
plat(g, 12, 18, 5)
plat(g, 21, 26, 5, "=")
plat(g, 30, 36, 6)
put(g, 16, 18, "^"); put(g, 17, 18, "^"); put(g, 18, 18, "^")
put(g, 11, 12, "g")
put(g, 25, 12, "g")
put(g, 29, 8, "g")
put(g, 20, 8, "f")
put(g, 7, 7, "f")
put(g, 15, 3, "v")
put(g, 33, 4, "v")
items(g, [(5, 15, "r"), (12, 12, "p"), (19, 15, "r"), (26, 12, "b"), (33, 14, "p"), (36, 11, "r"),
          (29, 8, "r"), (21, 9, "p"), (13, 7, "b"), (5, 8, "r"), (5, 5, "p"), (14, 4, "r"),
          (23, 4, "p"), (33, 5, "r")])
LEVELS.append(("Furnace Vent", 110, g, (1.0, 0.45, 0.15)))

# ---------------------------------------------------------------- 20
g = new()
plat(g, 3, 6, 16, "=")
plat(g, 9, 12, 14, "=")
plat(g, 15, 18, 16)
plat(g, 21, 24, 14, "=")
plat(g, 27, 30, 16, "=")
plat(g, 33, 38, 14, "=")
plat(g, 32, 36, 11, "<")
plat(g, 25, 29, 8, "=")
plat(g, 18, 22, 10)
plat(g, 11, 15, 8, "=")
plat(g, 3, 8, 10, ">")
plat(g, 3, 8, 7, "=")
plat(g, 12, 17, 5)
plat(g, 21, 26, 5, "=")
plat(g, 30, 36, 5)
for x in range(4, 35):
    if x % 3 != 0:
        put(g, x, 18, "^")
put(g, 16, 15, "g")
put(g, 21, 9, "g")
put(g, 36, 13, "g")
put(g, 12, 7, "f")
put(g, 27, 7, "f")
put(g, 6, 3, "f")
put(g, 33, 2, "f")
put(g, 14, 3, "v")
put(g, 23, 3, "v")
items(g, [(4, 15, "r"), (10, 13, "p"), (16, 15, "r"), (22, 13, "b"), (28, 15, "p"), (35, 13, "r"),
          (34, 10, "r"), (27, 7, "p"), (20, 9, "b"), (13, 7, "r"), (5, 9, "p"), (5, 6, "r"),
          (15, 4, "p"), (23, 4, "r"), (33, 4, "p")])
LEVELS.append(("Halvard's Core", 110, g, (1.0, 0.85, 0.4)))


# ---------------------------------------------------------------- checks
def cell(g, x, y):
    if x < 0 or x >= W or y < 0 or y >= H:
        return "#"
    return g[y][x]


def standable(g, x, y):
    c = cell(g, x, y)
    return c not in SOLID and c != "^" and cell(g, x, y + 1) in SOLID and cell(g, x, y - 1) not in SOLID


def free(g, x, y):
    return cell(g, x, y) not in SOLID


def reach(g, max_up):
    # the buggy can drop the astronaut anywhere safe on the floor
    starts = [(x, 18) for x in range(1, W - 1) if standable(g, x, 18)]
    seen = set(starts)
    stack = list(starts)
    while stack:
        x, y = stack.pop()
        nxt = []
        for dx in (-1, 1):
            nx = x + dx
            if free(g, nx, y) and cell(g, nx, y) != "^":
                yy = y
                while yy < H - 1 and not standable(g, nx, yy) and free(g, nx, yy + 1) and cell(g, nx, yy) != "^":
                    yy += 1
                if standable(g, nx, yy):
                    nxt.append((nx, yy))
        if free(g, x, y - 1) and free(g, x, y - 2):
            for tx in range(x - 5, x + 6):
                for ty in range(y - max_up, y + 8):
                    if (tx, ty) == (x, y) or not standable(g, tx, ty):
                        continue
                    if ty < y and abs(tx - x) > 4:
                        continue
                    apex = min(y, ty) - 1
                    step = 1 if tx >= x else -1
                    if all(free(g, cx, apex) for cx in range(x, tx + step, step)):
                        nxt.append((tx, ty))
        for n in nxt:
            if n not in seen:
                seen.add(n)
                stack.append(n)
    return seen


ok_all = True
for name, collapse, g, col in LEVELS:
    for row in g:
        assert len(row) == W
    for x in range(1, W - 1):
        assert cell(g, x, 19) in SOLID, (name, "floor gap", x)
        for y in (17, 18):
            assert cell(g, x, y) not in SOLID, (name, "rock in buggy lane", x, y)
    jump = reach(g, 3)
    jet = reach(g, 6)

    def touch(st, x, y, up):
        return any(abs(sx - x) <= 1 and 0 <= sy - y <= up for sx, sy in st)

    bad, jet_only = [], []
    n_items = 0
    for y in range(H):
        for x in range(W):
            if g[y][x] in ITEMS:
                n_items += 1
                if touch(jump, x, y, 3):
                    continue
                if touch(jet, x, y, 6):
                    jet_only.append((x, y))
                else:
                    bad.append((x, y))
    print(f"{name}: {n_items} items, jetpack-only {jet_only}, unreachable {bad}")
    ok_all = ok_all and not bad

out = ["# Generated by tools/levels_build.py: original asteroid-shaft layouts.", "extends RefCounted",
       "class_name Levels", "", "const DATA := ["]
for name, collapse, g, col in LEVELS:
    out += ["\t{", f'\t\t"name": "{name}",', f'\t\t"collapse": {collapse}.0,',
            f'\t\t"tint": Color({col[0]}, {col[1]}, {col[2]}),', '\t\t"map": [']
    out += [f'\t\t\t"{"".join(row)}",' for row in g]
    out += ["\t\t],", "\t},"]
out.append("]")
open(sys.argv[1], "w").write("\n".join(out) + "\n")
print("OK" if ok_all else "PROBLEMS")
