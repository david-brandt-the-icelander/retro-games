"""Check that every grid item / category example exists: as a lemma in the Icelandic Gigaword
frequency list (count >= MIN), in ÍNO or in the CEFR lists. Multi-word items: every word must pass.
usage: verify_items.py SCRATCH FILE.json -> prints unknown items with their location."""
import json, pickle, sys
S, path = sys.argv[1], sys.argv[2]
MIN = 5
freq = pickle.load(open(S + "/freq/freq.pkl", "rb"))
ino = pickle.load(open(S + "/v3/ino_nouns.pkl", "rb"))
cefr = set()
for L in ("A1", "A2", "B1", "B2"):
    for o in json.load(open(f"{S}/cefr/x/CEFR_ordalistar/{L}_ordafordi.json")):
        cefr.add(o["lemma"])
def known(tok):
    t = tok.strip(".,!?'\"()")
    if not t: return True
    for v in (t, t.lower(), t[:1].upper() + t[1:]):
        if freq.get(v, 0) >= MIN or v in ino or v in cefr: return True
    return False
d = json.load(open(path)); bad = []
for g in d.get("grids", []):
    for w in g["ord"]:
        if not all(known(t) for t in w.split()): bad.append((g["efni"], w))
for c in d.get("categories", []):
    for w in c["daemi"]:
        if not all(known(t) for t in w.split()): bad.append((c["flokkur_texti"], w))
print(len(bad), "unknown")
for b in bad: print(" | ".join(b))
