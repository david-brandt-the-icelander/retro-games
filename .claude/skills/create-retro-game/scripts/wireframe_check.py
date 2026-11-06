#!/usr/bin/env python3
"""Validate a WIREFRAMES.md written in the create-retro-game notation.

Each screen is a "## Screen: <id>" heading, followed by a ```wireframe block of exactly
ROWS lines of COLS characters and a legend of "- X: purpose" lines. One ```flow block
lists transitions as "a -> b [optional label]".

Checks: grid size; allowed characters ('.', '#', letters, digits); every region in the
grid has a legend line and every legend line is used; screen ids unique and lowercase;
every flow node is a screen and every screen is in the flow.

Usage:
  python3 -I wireframe_check.py docs/WIREFRAMES.md [--cols 32 --rows 24]
  python3 -I wireframe_check.py --self-test
Exits 0 when clean, 1 when problems are found.
"""
import argparse
import re
import sys

SCREEN_RE = re.compile(r"^##\s+Screen:\s*(\S+)\s*$")
LEGEND_RE = re.compile(r"^\s*[-*]\s+([A-Za-z0-9])\s*[:—–-]\s*(.+)$")
EDGE_RE = re.compile(r"^\s*([a-z0-9][a-z0-9-]*)\s*->\s*([a-z0-9][a-z0-9-]*)\s*(\[.*\])?\s*$")
ID_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
REGION_RE = re.compile(r"[A-Za-z0-9]")


def parse(text):
    """Return (screens, flow_edges, problems). screens: list of dicts with id, grid, legend, line."""
    screens, edges, problems = [], [], []
    lines = text.splitlines()
    i, current, flow_blocks = 0, None, 0
    while i < len(lines):
        line = lines[i]
        m = SCREEN_RE.match(line)
        if m:
            current = {"id": m.group(1), "grid": None, "legend": {}, "line": i + 1}
            screens.append(current)
            i += 1
            continue
        if line.strip().startswith("##") and not m:
            current = None
        fence = line.strip()
        if fence.startswith("```"):
            kind = fence[3:].strip()
            body, j = [], i + 1
            while j < len(lines) and not lines[j].strip().startswith("```"):
                body.append(lines[j])
                j += 1
            if j >= len(lines):
                problems.append(f"line {i + 1}: unclosed ``` block")
            if kind == "wireframe":
                if current is None:
                    problems.append(f"line {i + 1}: wireframe block outside a '## Screen:' section")
                elif current["grid"] is not None:
                    problems.append(f"line {i + 1}: screen '{current['id']}' has more than one wireframe")
                else:
                    current["grid"] = body
                    current["grid_line"] = i + 2
            elif kind == "flow":
                flow_blocks += 1
                for k, raw in enumerate(body):
                    if not raw.strip() or raw.strip().startswith("#"):
                        continue
                    e = EDGE_RE.match(raw)
                    if not e:
                        problems.append(f"line {i + 2 + k}: flow line not 'a -> b [label]': {raw.strip()!r}")
                    else:
                        edges.append((e.group(1), e.group(2), i + 2 + k))
            i = j + 1
            continue
        if current is not None and current["grid"] is not None:
            lm = LEGEND_RE.match(line)
            if lm:
                key = lm.group(1)
                if key in current["legend"]:
                    problems.append(f"line {i + 1}: screen '{current['id']}' defines region '{key}' twice")
                current["legend"][key] = lm.group(2).strip()
        i += 1
    if flow_blocks == 0:
        problems.append("no ```flow block found")
    elif flow_blocks > 1:
        problems.append("more than one ```flow block")
    return screens, edges, problems


def check(text, cols=32, rows=24):
    screens, edges, problems = parse(text)
    if not screens:
        problems.append("no '## Screen: <id>' sections found")
    seen = set()
    for s in screens:
        sid = s["id"]
        if not ID_RE.match(sid):
            problems.append(f"line {s['line']}: screen id '{sid}' must be lowercase letters, digits and dashes")
        if sid in seen:
            problems.append(f"line {s['line']}: duplicate screen id '{sid}'")
        seen.add(sid)
        grid = s["grid"]
        if grid is None:
            problems.append(f"line {s['line']}: screen '{sid}' has no ```wireframe block")
            continue
        if len(grid) != rows:
            problems.append(f"screen '{sid}': {len(grid)} rows, expected {rows}")
        used = set()
        for r, row in enumerate(grid):
            where = f"screen '{sid}' row {r + 1} (line {s['grid_line'] + r})"
            if len(row) != cols:
                problems.append(f"{where}: {len(row)} columns, expected {cols}")
            bad = sorted({c for c in row if c not in ".#" and not REGION_RE.match(c)})
            if bad:
                problems.append(f"{where}: characters not allowed: {''.join(bad)!r}")
            used.update(c for c in row if REGION_RE.match(c))
        legend = set(s["legend"])
        for c in sorted(used - legend):
            problems.append(f"screen '{sid}': region '{c}' has no legend line")
        for c in sorted(legend - used):
            problems.append(f"screen '{sid}': legend '{c}' is not used in the grid")
    ids = {s["id"] for s in screens}
    in_flow = set()
    for a, b, ln in edges:
        for node in (a, b):
            in_flow.add(node)
            if node not in ids:
                problems.append(f"line {ln}: flow node '{node}' is not a defined screen")
    for sid in sorted(ids - in_flow):
        problems.append(f"screen '{sid}' does not appear in the flow")
    return screens, problems


GOOD = """## Screen: a
```wireframe
{grid_a}
```
Legend:
- T: title
- K: footer

## Screen: b
```wireframe
{grid_b}
```
Legend:
- K: footer

## Flow
```flow
a -> b [any key]
b -> a [after 1 s]
```
"""


def _grid(top_row, rows=24, cols=32):
    body = [top_row.ljust(cols, ".")] + ["." * cols] * (rows - 4) + ["K" * cols] * 3
    return "\n".join(body)


def self_test():
    good = GOOD.format(grid_a=_grid("..TTTT"), grid_b=_grid(""))
    _, problems = check(good)
    assert problems == [], problems
    bad = good.replace("- T: title\n", "").replace("b -> a [after 1 s]", "b -> c").replace("..TTTT", "..TT!T", 1)
    bad = bad.replace("." * 32 + "\n", "." * 31 + "\n", 1)
    _, problems = check(bad)
    text = "\n".join(problems)
    for expected in ["region 'T' has no legend line", "flow node 'c' is not a defined screen", "characters not allowed: '!'", "31 columns"]:
        assert expected in text, (expected, problems)
    print("wireframe_check self-test: ok")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", nargs="?")
    ap.add_argument("--cols", type=int, default=32)
    ap.add_argument("--rows", type=int, default=24)
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        self_test()
        return 0
    if not args.file:
        ap.error("give a WIREFRAMES.md file, or --self-test")
    with open(args.file, encoding="utf-8") as f:
        screens, problems = check(f.read(), args.cols, args.rows)
    for p in problems:
        print(f"{args.file}: {p}")
    print(f"wireframe_check: {len(screens)} screens, {len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
