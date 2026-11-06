#!/usr/bin/env python3
"""Find a ZX Spectrum original's graphics and tunes inside a remake.

Usage:
    python3 -I zx_assets.py LISTING REPO_DIR [--min-notes N] [--json]

LISTING   A BASIC listing produced by zx_basic_list.py.
REPO_DIR  The remake to check (.git, node_modules, dist and binary files skipped).

From the listing it collects:
  * graphics: every 8-byte group from DATA lines whose items are all bytes
    (0-255 or BIN literals). These are usually UDGs POKEd to USR "a".
  * tunes: BEEP pitches in program order (literal `BEEP d,p` statements), plus
    pitches from DATA lines that alternate duration and pitch.

In the remake it reads every number in order (decimal, 0x.., 0b.., $..), and
every row of 8 characters drawn as a bitmap ("..XXXX..", "00111100", "  ##  ").
It reports, with file and line:
  * GLYPH      an original 8-byte graphic present as 8 consecutive numbers or 8
               consecutive bitmap rows (also mirrored or inverted copies);
  * TUNE       a run of at least --min-notes (default 6) original pitches;
  * TRANSPOSED the same run of intervals at a different pitch.
Blank, solid and other trivial glyphs (fewer than 3 distinct rows) are ignored.
Exit status: 0 when nothing is found, 1 when matches remain.
"""
import argparse
import json
import os
import re
import sys

SKIP_DIRS = {".git", "node_modules", "dist", "build", "out", "target", "__pycache__", ".venv", "venv"}
BIN = re.compile(r"\bBIN\s*([01]{1,8})\b")
NUM = re.compile(r"(?<![\w.])-?\d+(?:\.\d+)?|(?<![\w.])-?\.\d+")
LINE = re.compile(r"^\s*(\d{1,4})\s+(.*)$")
BEEP = re.compile(r"BEEP\s+([-\d.]+)\s*,\s*([-\d.]+)")
REPO_NUM = re.compile(r"0[xX][0-9a-fA-F]+|0[bB][01]+|\$[0-9a-fA-F]{2}\b|-?\d+(?:\.\d+)?")
BITROW = re.compile(r"""["'`]([.#xX01 _*@o-]{8})["'`]""")


def data_items(stmt):
    """Split the items of a DATA statement into numbers (None for non-numeric)."""
    body = stmt.split("DATA", 1)[1]
    items = []
    for raw in body.split(","):
        raw = raw.strip()
        m = BIN.fullmatch(raw) or (re.fullmatch(r"BIN\s*([01]{1,8})", raw))
        if m:
            items.append(int(m.group(1), 2))
            continue
        try:
            items.append(float(raw))
        except ValueError:
            items.append(None)
    return items


def parse_listing(path):
    glyphs, notes = [], []
    for line in open(path, encoding="utf-8", errors="replace"):
        m = LINE.match(line)
        if not m:
            continue
        number, text = int(m.group(1)), m.group(2)
        if text.lstrip().startswith("REM"):
            continue
        for stmt in re.split(r":(?=(?:[^\"]*\"[^\"]*\")*[^\"]*$)", text):
            stmt = stmt.strip()
            for b in BEEP.finditer(stmt):
                try:
                    notes.append((float(b.group(2)), number))
                except ValueError:
                    pass
            if stmt.startswith("DATA"):
                items = data_items(stmt)
                if not items or any(v is None for v in items):
                    continue
                if all(v == int(v) and 0 <= v <= 255 for v in items) and len(items) >= 8:
                    for i in range(0, len(items) - 7, 8):
                        glyphs.append((tuple(int(v) for v in items[i:i + 8]), number))
                elif len(items) >= 4 and len(items) % 2 == 0:
                    durations, pitches = items[0::2], items[1::2]
                    if all(0 < d <= 5 for d in durations) and all(-60 <= p <= 69 for p in pitches):
                        notes.extend((p, number) for p in pitches)
    return glyphs, notes


def bitrow_value(s):
    on = set("#xX1*@o")
    return sum(1 << (7 - i) for i, ch in enumerate(s) if ch in on)


def repo_streams(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            path = os.path.join(dirpath, f)
            try:
                raw = open(path, "rb").read(2_000_000)
            except OSError:
                continue
            if b"\0" in raw[:4096]:
                continue
            nums, rows = [], []
            for n, line in enumerate(raw.decode("utf-8", "replace").splitlines(), 1):
                for tok in REPO_NUM.findall(line):
                    try:
                        if tok[:2] in ("0x", "0X"):
                            v = int(tok, 16)
                        elif tok[:2] in ("0b", "0B"):
                            v = int(tok, 2)
                        elif tok.startswith("$"):
                            v = int(tok[1:], 16)
                        else:
                            v = float(tok)
                        nums.append((v, n))
                    except ValueError:
                        pass
                for r in BITROW.findall(line):
                    if set(r) - set(" ._-0"):  # skip blank-looking rows only if all blank
                        rows.append((bitrow_value(r), n))
                    else:
                        rows.append((0, n))
            yield os.path.relpath(path, root), nums, rows


def variants(g):
    mirror = tuple(int(f"{b:08b}"[::-1], 2) for b in g)
    inverse = tuple(255 - b for b in g)
    out = {"exact": g}
    for name, v in (("mirrored", mirror), ("inverted", inverse)):
        if v not in out.values():
            out[name] = v
    return out


def find_runs(seq, pattern):
    k = len(pattern)
    vals = [v for v, _ in seq]
    for i in range(len(vals) - k + 1):
        if vals[i:i + k] == list(pattern):
            yield i


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("listing")
    ap.add_argument("repo")
    ap.add_argument("--min-notes", type=int, default=6)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv[1:])

    glyphs, notes = parse_listing(a.listing)
    glyphs = [(g, n) for g, n in glyphs if len(set(g)) >= 3]
    findings = []
    for rel, nums, rows in repo_streams(a.repo):
        for g, src in glyphs:
            for kind, pat in variants(g).items():
                for stream, how in ((nums, "numbers"), (rows, "bitmap rows")):
                    for i in find_runs(stream, pat):
                        findings.append({"kind": "GLYPH", "file": rel, "line": stream[i][1],
                                         "detail": "%s graphic from listing line %d (%s, %s)" % (kind, src, how, ",".join(map(str, g)))})
        if len(notes) >= a.min_notes:
            pitches = [p for p, _ in notes]
            k = a.min_notes
            # Tunes are often stored as (duration, pitch) pairs, so also read
            # every second number, in both phases.
            for stride, phase in ((1, 0), (2, 0), (2, 1)):
                sub = nums[phase::stride]
                vals = [v for v, _ in sub]
                hit = set()
                for s in range(len(pitches) - k + 1):
                    run = pitches[s:s + k]
                    if len(set(run)) < 3:
                        continue
                    intervals = [run[j + 1] - run[j] for j in range(k - 1)]
                    for i in range(len(vals) - k + 1):
                        if i in hit:
                            continue
                        window = vals[i:i + k]
                        if window == run:
                            kind, detail = "TUNE", "%d notes from listing line %d: %s" % (k, notes[s][1], run)
                        elif [window[j + 1] - window[j] for j in range(k - 1)] == intervals:
                            kind, detail = "TRANSPOSED", "%d notes from listing line %d shifted by %g semitones" % (k, notes[s][1], window[0] - run[0])
                        else:
                            continue
                        if stride == 2:
                            detail += " (interleaved with durations)"
                        findings.append({"kind": kind, "file": rel, "line": sub[i][1], "detail": detail})
                        hit.update(range(i, i + k))

    uniq = {(f["kind"], f["file"], f["line"], f["detail"]): f for f in findings}
    findings = sorted(uniq.values(), key=lambda f: (f["file"], f["line"], f["kind"]))
    summary = "assets: %d glyph matches, %d tune runs, %d transposed runs (reference: %d glyphs, %d notes)" % (
        sum(f["kind"] == "GLYPH" for f in findings), sum(f["kind"] == "TUNE" for f in findings),
        sum(f["kind"] == "TRANSPOSED" for f in findings), len(glyphs), len(notes))
    if a.json:
        print(json.dumps({"summary": summary, "findings": findings}, indent=2))
    else:
        for f in findings:
            print("%-40s %-10s %s" % ("%s:%d" % (f["file"], f["line"]), f["kind"], f["detail"]))
        print(summary)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
