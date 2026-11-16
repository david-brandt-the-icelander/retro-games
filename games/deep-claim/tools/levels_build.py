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
