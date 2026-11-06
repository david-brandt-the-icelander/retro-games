#!/usr/bin/env python3
"""Find text from an original game that is still present in a remake.

Usage:
    python3 -I overlap.py REFERENCE [REFERENCE ...] REPO_DIR
        [--ngram N] [--min-words M] [--names NAME [NAME ...]]
        [--exclude GLOB [GLOB ...]] [--allow FILE] [--json]

REFERENCE  The original's text: a BASIC listing (quoted strings are extracted),
           a disassembly (DEFM / DB / DEFB / .byte / .text / .asciiz / dc.b "..." strings
           are extracted), or any
           other text file (read as prose, e.g. a manual).
REPO_DIR   The remake to check. .git, node_modules, dist, build and binary files
           are skipped.

Reports, with file and line:
  * every original string of at least --min-words words (default 3) that
    appears in the remake, ignoring case, punctuation and spacing;
  * every run of --ngram consecutive words (default 5) shared with the
    original, merged into the longest matching passage;
  * every occurrence of a --names word (distinctive invented names, which are
    otherwise too short to match).

--allow FILE lists accepted phrases, one per line; matches inside them are
ignored. Exit status: 0 when nothing is found, 1 when matches remain, 2 on
usage errors.
"""
import argparse
import fnmatch
import json
import os
import re
import sys

WORD = re.compile(r"[a-z0-9]+(?:'[a-z0-9]+)?")
SKIP_DIRS = {".git", "node_modules", "dist", "build", "out", "target", "__pycache__", ".venv", "venv"}
QUOTED = re.compile(r'"((?:[^"]|"")*)"')
ASM_STRING = re.compile(r'^\s*(?:[\w.]+:?\s+)?(?:DEFM|DEFB|DEFS|DB|DM|DC\.B|\.ASCIIZ|\.ASCII|\.TEXT|\.BYTE|\.STR|\.STRING)\b(.*)$', re.I)
BASIC_LINE = re.compile(r"^\s*\d{1,4}\s")


def words(text):
    return WORD.findall(text.lower())


def reference_units(path):
    """Return a list of (text, origin) units from one reference file."""
    lines = open(path, encoding="utf-8", errors="replace").read().splitlines()
    basic = sum(1 for l in lines if BASIC_LINE.match(l)) > len(lines) * 0.5
    asm = sum(1 for l in lines if ASM_STRING.match(l)) > 0
    units = []
    for n, line in enumerate(lines, 1):
        where = "%s:%d" % (os.path.basename(path), n)
        if basic:
            if re.match(r"^\s*\d+\s+REM\b", line):
                continue  # REM lines are comments or embedded machine code
            for m in QUOTED.finditer(line):
                units.append((m.group(1).replace('""', '"'), where))
        elif asm:
            m = ASM_STRING.match(line)
            if m:
                for q in QUOTED.finditer(m.group(1)):
                    units.append((q.group(1), where))
        else:
            if line.strip():
                units.append((line, where))
    if not (basic or asm):
        # Prose: also treat the whole file as one unit so n-grams cross line breaks.
        units.append((" ".join(lines), os.path.basename(path)))
    return units


def iter_repo_files(root, excludes, reference_paths):
    refs = {os.path.realpath(p) for p in reference_paths}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for f in filenames:
            path = os.path.join(dirpath, f)
            rel = os.path.relpath(path, root)
            if os.path.realpath(path) in refs:
                continue
            if any(fnmatch.fnmatch(rel, g) or fnmatch.fnmatch(f, g) for g in excludes):
                continue
            try:
                with open(path, "rb") as fh:
                    raw = fh.read(2_000_000)
            except OSError:
                continue
            if b"\0" in raw[:4096]:
                continue  # binary
            yield rel, raw.decode("utf-8", errors="replace")


def tokens_with_lines(text):
    toks, lines = [], []
    for n, line in enumerate(text.splitlines(), 1):
        for w in words(line):
            toks.append(w)
            lines.append(n)
    return toks, lines


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+", help="REFERENCE [REFERENCE ...] REPO_DIR")
    ap.add_argument("--ngram", type=int, default=5)
    ap.add_argument("--min-words", type=int, default=3)
    ap.add_argument("--names", nargs="*", default=[])
    ap.add_argument("--exclude", nargs="*", default=[])
    ap.add_argument("--allow")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv[1:])
    if len(a.paths) < 2:
        ap.error("need at least one REFERENCE and a REPO_DIR")
    *refs, repo = a.paths
    if not os.path.isdir(repo):
        ap.error("REPO_DIR %r is not a directory" % repo)

    allowed = []
    if a.allow:
        allowed = [words(l) for l in open(a.allow, encoding="utf-8") if words(l)]

    units = []
    for r in refs:
        units.extend(reference_units(r))

    # Whole strings to look for (deduplicated by normalised form).
    strings = {}
    for text, where in units:
        w = words(text)
        if len(w) >= a.min_words:
            strings.setdefault(tuple(w), (text.strip(), where))
    # n-grams of the original.
    ngrams = set()
    for text, _ in units:
        w = words(text)
        for i in range(len(w) - a.ngram + 1):
            ngrams.add(tuple(w[i:i + a.ngram]))
    names = {n.lower() for n in a.names}

    def is_allowed(seq):
        s = " ".join(seq)
        return any(" ".join(al) in s or s in " ".join(al) for al in allowed)

    findings = []
    for rel, text in iter_repo_files(repo, a.exclude, refs):
        toks, lines = tokens_with_lines(text)
        if not toks:
            continue
        # Whole-string matches.
        for seq, (orig, where) in strings.items():
            k = len(seq)
            first = seq[0]
            for i in range(len(toks) - k + 1):
                if toks[i] == first and tuple(toks[i:i + k]) == seq and not is_allowed(seq):
                    findings.append({"kind": "string", "file": rel, "line": lines[i],
                                     "text": orig, "reference": where})
        # n-gram runs.
        hit = [False] * len(toks)
        for i in range(len(toks) - a.ngram + 1):
            if tuple(toks[i:i + a.ngram]) in ngrams:
                for j in range(i, i + a.ngram):
                    hit[j] = True
        i = 0
        while i < len(toks):
            if hit[i]:
                j = i
                while j < len(toks) and hit[j]:
                    j += 1
                seq = toks[i:j]
                if not is_allowed(seq):
                    findings.append({"kind": "ngram", "file": rel, "line": lines[i],
                                     "end_line": lines[j - 1], "text": " ".join(seq)})
                i = j
            else:
                i += 1
        # Distinctive names.
        for i, t in enumerate(toks):
            if t in names:
                findings.append({"kind": "name", "file": rel, "line": lines[i], "text": t})

    # Drop n-gram findings fully covered by a whole-string finding on the same line.
    covered = {(f["file"], f["line"], " ".join(words(f["text"]))) for f in findings if f["kind"] == "string"}
    findings = [f for f in findings if not (f["kind"] == "ngram" and any(
        c[0] == f["file"] and c[1] == f["line"] and f["text"] in c[2] for c in covered))]
    findings.sort(key=lambda f: (f["file"], f["line"], f["kind"]))

    counts = {k: sum(1 for f in findings if f["kind"] == k) for k in ("string", "ngram", "name")}
    files = len({f["file"] for f in findings})
    summary = ("overlap: %d original strings, %d shared %d-word passages, %d name hits in %d files "
               "(reference: %d strings, %d n-grams)" % (counts["string"], counts["ngram"], a.ngram,
                                                         counts["name"], files, len(strings), len(ngrams)))
    if a.json:
        print(json.dumps({"summary": summary, "counts": counts, "findings": findings}, indent=2))
    else:
        for f in findings:
            loc = "%s:%d" % (f["file"], f["line"])
            if f["kind"] == "string":
                print("%-40s STRING  %r  (original %s)" % (loc, f["text"], f["reference"]))
            elif f["kind"] == "ngram":
                print("%-40s PASSAGE %r" % (loc, f["text"]))
            else:
                print("%-40s NAME    %s" % (loc, f["text"]))
        print(summary)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
