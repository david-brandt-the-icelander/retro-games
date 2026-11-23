"""Merge reviewer outputs into the verified list, the unverified list and stats."""
import json, os, sys, random, collections
S = sys.argv[1]; OUT = sys.argv[2]
DROP = set(json.load(open(S + "/review/drop.json"))) if os.path.exists(S + "/review/drop.json") else set()
EDIT = json.load(open(S + "/review/edits.json")) if os.path.exists(S + "/review/edits.json") else {}
kept, rejected = {}, []
for i in range(1, 11):
    p = f"{S}/review/out{i}.json"
    if not os.path.exists(p): print("missing", p); continue
    for o in json.load(open(p)):
        if o.get("keep") and o["w"] not in DROP and o["w"] not in kept:
            o.update(EDIT.get(o["w"], {}))
            kept[o["w"]] = o
        elif not o.get("keep"):
            rejected.append(o)
words = []
for w in sorted(kept, key=lambda x: x.lower()):
    o = kept[w]
    words.append({"ord": w, "ordflokkur": o.get("ordflokkur"), "skilgreining": o.get("skilgreining"),
                  "heimild": o.get("heimild"), "tengill": o.get("tengill"), "malid": o.get("malid"),
                  "obscurity": o.get("obscurity"), "studningur": o.get("studningur"),
                  "athugasemd": o.get("athugasemd") or "", "ovisst_mal": bool(o.get("ovisst_mal"))})
os.makedirs(OUT, exist_ok=True)
json.dump(words, open(OUT + "/verified-words.json", "w"), ensure_ascii=False, indent=1)
unv = []
for f in ("no_meaning.txt", "no_meaning2.txt"):
    for w in open(f"{S}/review/{f}").read().split("\n"):
        if w.strip(): unv.append({"ord": w.strip(), "astaeda": "Engin merking fannst í heimildum á málið.is (orðið finnst aðeins í BÍN/Ritmálssafni án skýringar, eða alls ekki)."})
for o in rejected:
    if o.get("astaeda") == "NO_CLEAR_MEANING":
        unv.append({"ord": o["w"], "astaeda": "Heimildir á málið.is gefa ekki nógu skýra merkingu. " + (o.get("athugasemd") or "")})
json.dump(unv, open(OUT + "/unverified-candidates.json", "w"), ensure_ascii=False, indent=1)
print("verified", len(words), "unverified", len(unv), "rejected", len(rejected))
print("by source", collections.Counter(w["heimild"] for w in words))
print("by obscurity", collections.Counter(w["obscurity"] for w in words))
print("reject reasons", collections.Counter(o.get("astaeda") for o in rejected))
print("unsure wording", sum(w["ovisst_mal"] for w in words))
