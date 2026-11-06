#!/usr/bin/env python3
"""Write the guard test's hash list from the original's reference material (verify role).

Usage:
    python3 -I -B make_guard_hashes.py REFERENCE [REFERENCE ...] --names NAME [NAME ...]
        [--min-words 3] > games/<slug>/test/original-hashes.json

REFERENCE  The same files you give overlap.py: a BASIC listing (its quoted strings),
           a disassembly, or prose (a manual: each line becomes a unit).

Every original string of at least --min-words words, normalised exactly as overlap.py
does (lower case, words only, single spaces), and every --names word, is hashed with
SHA-256 and truncated to 16 hex digits. The output groups the hashes by word count:
{"1": [...], "3": [...], ...}. Only hashes are written, never the text, so the file is
safe to commit to a public repository. The web template's test/guard.test.ts reads it.

Exit status: 0 on success, 2 on usage errors.
"""
import argparse
import hashlib
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "clean-room-rebuild", "scripts"))
from overlap import reference_units, words  # noqa: E402


def build(references, names, min_words):
    seqs = set()
    for path in references:
        for text, _ in reference_units(path):
            w = words(text)
            if len(w) >= min_words:
                seqs.add(" ".join(w))
    for name in names:
        w = words(name)
        if w:
            seqs.add(" ".join(w))
    out = {}
    for s in seqs:
        out.setdefault(len(s.split()), []).append(hashlib.sha256(s.encode()).hexdigest()[:16])
    return {str(k): sorted(v) for k, v in sorted(out.items())}


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("references", nargs="+")
    ap.add_argument("--names", nargs="*", default=[])
    ap.add_argument("--min-words", type=int, default=3)
    args = ap.parse_args(argv)
    for p in args.references:
        if not os.path.isfile(p):
            ap.error("not a file: %s" % p)
    table = build(args.references, args.names, args.min_words)
    json.dump(table, sys.stdout, indent=0)
    sys.stdout.write("\n")
    total = sum(len(v) for v in table.values())
    print("guard hashes: %d strings and names, word counts %s" % (total, ", ".join(table)), file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
