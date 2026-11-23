"""Merge v2 reviews (difficulty-scored) into one word list, a rejected list and level stats.

usage: consolidate_v2.py SCRATCH RESEARCH_DIR
"""
import collections, glob, json, os, sys

S, R = sys.argv[1], sys.argv[2]
DROP = set(json.load(open(S + "/review/drop_v2.json"))) if os.path.exists(S + "/review/drop_v2.json") else set()
EDIT = json.load(open(S + "/review/edits_v2.json")) if os.path.exists(S + "/review/edits_v2.json") else {}
LEVELS = [
    {"id": "barnvaent", "heiti": "Barnvænt", "min": 1, "max": 4, "adeins_barnvaent": True},
    {"id": "lett", "heiti": "Létt", "min": 2, "max": 6, "adeins_barnvaent": False},
    {"id": "midlungs", "heiti": "Miðlungs", "min": 4, "max": 8, "adeins_barnvaent": False},
    {"id": "erfitt", "heiti": "Erfitt", "min": 6, "max": 10, "adeins_barnvaent": False},
]
FIELDS = ["ord", "ordflokkur", "skilgreining", "erfidleiki", "barnvaent", "sjaldgaef_merking", "flokkur",
          "heimild", "tengill", "malid", "studningur", "athugasemd", "ovisst_mal"]


def norm(o, base=None):
    base = base or {}
    e = {
        "ord": o.get("w") or base.get("ord"),
        "ordflokkur": base.get("ordflokkur") or o.get("ordflokkur"),
        "skilgreining": base.get("skilgreining") or o.get("skilgreining"),
        "erfidleiki": int(o["erfidleiki"]),
        "barnvaent": bool(o.get("barnvaent")),
        "sjaldgaef_merking": bool(o.get("sjaldgaef_merking")),
        "flokkur": o.get("flokkur") or "annað",
        "heimild": base.get("heimild") or o.get("heimild"),
        "tengill": base.get("tengill") or o.get("tengill"),
        "malid": base.get("malid") or o.get("malid"),
        "studningur": base.get("studningur") or o.get("studningur") or "",
        "athugasemd": "; ".join(x for x in (base.get("athugasemd"), o.get("athugasemd")) if x),
        "ovisst_mal": bool(base.get("ovisst_mal") or o.get("ovisst_mal")),
    }
    e.update(EDIT.get(e["ord"], {}))
    return e


words, rejected = {}, []
old = {o["ord"]: o for o in json.load(open(R + "/verified-words.json"))}
for o in json.load(open(S + "/review/v2out_kept.json")):
    if o.get("keep") and o["w"] not in DROP:
        words[o["w"]] = norm(o, old[o["w"]])
    else:
        rejected.append({"ord": o["w"], "astaeda": o.get("astaeda") or "DROPPED_IN_AUDIT", "athugasemd": o.get("athugasemd") or ""})
for p in sorted(glob.glob(S + "/review/v2out_known*.json")) + sorted(glob.glob(S + "/review/v2out_ino*.json")):
    for o in json.load(open(p)):
        if o.get("keep") and o["w"] not in DROP:
            if o["w"] not in words:
                words[o["w"]] = norm(o)
        else:
            rejected.append({"ord": o["w"], "astaeda": o.get("astaeda") or "DROPPED_IN_AUDIT", "athugasemd": o.get("athugasemd") or ""})
# earlier rejections that v2 did not revisit (transparent, unsuitable, ...)
for o in json.load(open(S + "/review/rejected_v1_backup.json")):
    if o["astaeda"] != "KNOWN" and o["ord"] not in words:
        rejected.append(o)
rejected = [r for r in rejected if r["ord"] not in words]

out = sorted(words.values(), key=lambda e: e["ord"].lower())
json.dump({"utgafa": 2, "leyfi": "CC BY-SA 4.0 (skilgreiningar að hluta umorðaðar eftir Íslenskri nútímamálsorðabók, © Stofnun Árna Magnússonar)",
           "erfidleikastig": LEVELS, "ord": [{k: e[k] for k in FIELDS} for e in out]},
          open(R + "/words.json", "w"), ensure_ascii=False, indent=1)
json.dump(sorted(rejected, key=lambda r: r["ord"].lower()), open(R + "/rejected-candidates.json", "w"), ensure_ascii=False, indent=1)

hist = collections.Counter(e["erfidleiki"] for e in out)
print("words", len(out), "rejected", len(rejected))
print("difficulty histogram", [hist.get(i, 0) for i in range(1, 11)])
for L in LEVELS:
    n = [e for e in out if L["min"] <= e["erfidleiki"] <= L["max"]
         and (not L["adeins_barnvaent"] or (e["barnvaent"] and not e["sjaldgaef_merking"]))]
    print(L["heiti"], f"{L['min']}-{L['max']}", len(n))
print("barnvaent", sum(e["barnvaent"] for e in out), "sjaldgaef_merking", sum(e["sjaldgaef_merking"] for e in out))
print("by source", collections.Counter(e["heimild"] for e in out))
print("by theme", collections.Counter(e["flokkur"] for e in out).most_common(25))
print("reject reasons", collections.Counter(r["astaeda"] for r in rejected))
print("unsure wording", sum(e["ovisst_mal"] for e in out))
