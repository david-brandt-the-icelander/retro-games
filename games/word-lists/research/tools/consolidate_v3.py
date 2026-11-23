"""Build the word lists for the clue, outsider, trap, category-race and one-syllable games.

usage: consolidate_v3.py SCRATCH OUT_DIR
Reads the reviewers' outputs in SCRATCH/v3, applies drop.json / edits.json / grid_fixes.json, checks every grid item
and category example (local lemma lists first, then málið.is for what is left, cached in v3/malid_cache.json), and
writes common-nouns.json, topic-grids.json, category-prompts.json and one-syllable-words.json to OUT_DIR, plus
rejected-nouns.json.
"""
import collections, glob, json, os, pickle, ssl, sys, time, urllib.parse, urllib.request

S, OUT = sys.argv[1], sys.argv[2]
sys.path.insert(0, S + "/tools")
from syllables import syllables  # noqa: E402

V = S + "/v3"
DROP = set(json.load(open(V + "/drop.json")))
EDIT = json.load(open(V + "/edits.json"))
FIX = json.load(open(V + "/grid_fixes.json"))
DROP_CATS = {"Íslenskt nýyrði", "Íslenskur jólasveinn", "Myndasögupersóna", "Íslenskt ættarnafn"}
LICENCE = ("CC BY-SA 4.0. Orðin eru valin og metin upp úr Íslenskri nútímamálsorðabók (gagnasafn 2023, CC BY-SA 4.0), "
           "orðaforðalistum Evrópska tungumálarammans fyrir íslensku (CC BY 4.0) og tíðnilistum Risamálheildarinnar "
           "(CC BY 4.0), © Stofnun Árna Magnússonar í íslenskum fræðum.")

# ---------- common nouns ----------
inp = {}
for p in glob.glob(V + "/nouns*.jsonl"):
    for line in open(p):
        o = json.loads(line); inp[o["w"]] = o
nouns, rejected = [], []
for p in sorted(glob.glob(V + "/out_nouns*.json")):
    for o in json.load(open(p)):
        w = o["w"]; src = inp.get(w, {})
        if not o.get("keep") or w in DROP:
            rejected.append({"ord": w, "astaeda": o.get("astaeda") or "DROPPED_IN_AUDIT"}); continue
        o.update(EDIT.get(w, {}))
        nouns.append({
            "ord": w, "kyn": o.get("kyn") or src.get("kyn", ""),
            "thekking": int(o["thekking"]), "hlutbundid": bool(o.get("hlutbundid")),
            "margraett": bool(o.get("margraett")), "merkingar": o.get("merkingar") or [],
            "litriki": int(o["litriki"]), "lysanleiki": int(o["lysanleiki"]),
            "barnvaent": bool(o.get("barnvaent")), "flokkur": o.get("flokkur") or "annað",
            "atkvaedi": syllables(w), "samsett": bool(src.get("samsett")),
            "cefr": src.get("CEFR"), "tidni": src.get("tíðni", 0),
            "tengill": src.get("tengill") or src.get("malid"), "athugasemd": o.get("athugasemd") or "",
        })
nouns.sort(key=lambda e: e["ord"].lower())

GAMES = {
    "dulmal": {"lysing": "Lykilorð í dulmálsleik (lið gefa vísbendingar um fjögur leynileg orð)",
               "sia": "thekking <= 3 og litriki >= 2"},
    "krossvisbendingar": {"lysing": "Orð á röðum og dálkum í reitaleik (ein vísbending tengir tvö orð)",
                          "sia": "thekking <= 3, litriki >= 2 og (hlutbundid eða margraett)"},
    "gildruord": {"lysing": "Markorð sem á að lýsa framhjá földum gildruorðum; lysanleiki er erfiðleikastig",
                  "sia": "thekking <= 4"},
    "einsatkvaedis_lett": {"lysing": "Auðveld markorð í leik þar sem aðeins má nota einsatkvæðisorð",
                           "sia": "thekking <= 2, lysanleiki == 1 og hlutbundid"},
    "einsatkvaedis_erfitt": {"lysing": "Erfiðari markorð í sama leik (samsett orð eða erfiðari að lýsa)",
                             "sia": "thekking <= 3 og (samsett eða lysanleiki >= 2)"},
}
def fits(e, g):
    t, l, d = e["thekking"], e["litriki"], e["lysanleiki"]
    return {"dulmal": t <= 3 and l >= 2,
            "krossvisbendingar": t <= 3 and l >= 2 and (e["hlutbundid"] or e["margraett"]),
            "gildruord": t <= 4,
            "einsatkvaedis_lett": t <= 2 and d == 1 and e["hlutbundid"],
            "einsatkvaedis_erfitt": t <= 3 and (e["samsett"] or d >= 2)}[g]
for e in nouns:
    e["leikir"] = [g for g in GAMES if fits(e, g)]

# ---------- existence checks for grids and categories ----------
freq = pickle.load(open(S + "/freq/freq.pkl", "rb"))
ino = pickle.load(open(V + "/ino_nouns.pkl", "rb"))
cefr = set()
for L in ("A1", "A2", "B1", "B2"):
    for o in json.load(open(f"{S}/cefr/x/CEFR_ordalistar/{L}_ordafordi.json")):
        cefr.add(o["lemma"])
cache_p = V + "/malid_cache.json"
cache = json.load(open(cache_p)) if os.path.exists(cache_p) else {}
ctx = ssl.create_default_context(cafile="/root/.ccr/ca-bundle.crt")

def malid(tok):
    if tok not in cache:
        url = "https://malid.is/api_proxy/" + urllib.parse.quote(tok)
        d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "word-research-script"}),
                                              context=ctx, timeout=30).read())
        m = d.get("malid") or {}
        heads = any(v for k, v in m.items() if k != "beygingar")
        forms = any(b.get("flettur") for b in m.get("beygingar", []))
        cache[tok] = bool(heads or forms)
        time.sleep(0.4)
    return cache[tok]

def known_tok(tok):
    t = tok.strip(".,!?'\"()")
    if not t: return True
    for v in (t, t.lower(), t[:1].upper() + t[1:]):
        if freq.get(v, 0) >= 5 or v in ino or v in cefr: return True
    for part in t.split("-"):
        if part and not malid(part): return False
    return True

def known(item):
    return all(known_tok(t) for t in item.split())

# ---------- topic grids ----------
grids = []
for p, tag in ((V + "/out_gridsA.json", "A"), (V + "/out_gridsB.json", "B")):
    for g in json.load(open(p))["grids"]:
        if tag == "B" and g["efni"] in FIX.get("__drop_B__", []): continue
        words = [FIX.get(g["efni"], {}).get(w, w) for w in g["ord"]]
        assert len(set(words)) == 16, g["efni"]
        grids.append({"efni": g["efni"], "ord": words, "barnvaent": bool(g["barnvaent"]),
                      "erfidleiki": int(g["erfidleiki"]), "flokkur": g.get("flokkur", ""),
                      "ostadfest": [w for w in words if not known(w)]})
assert len({g["efni"] for g in grids}) == len(grids)

# ---------- category prompts ----------
cats = []
for p in (V + "/out_catsA.json", V + "/out_catsB.json"):
    for c in json.load(open(p))["categories"]:
        if c["flokkur_texti"] in DROP_CATS: continue
        cats.append({"flokkur_texti": c["flokkur_texti"], "daemi": c["daemi"], "barnvaent": bool(c["barnvaent"]),
                     "erfidleiki": int(c["erfidleiki"]), "tegund": c["tegund"],
                     "ostadfest": [w for w in c["daemi"] if not known(w)]})
assert len({c["flokkur_texti"].lower() for c in cats}) == len(cats)
json.dump(cache, open(cache_p, "w"), ensure_ascii=False)

# ---------- write ----------
os.makedirs(OUT, exist_ok=True)
json.dump({"leyfi": LICENCE, "leikir": GAMES, "ord": nouns}, open(OUT + "/common-nouns.json", "w"), ensure_ascii=False, indent=1)
json.dump({"leyfi": "CC BY-SA 4.0. Frumsamið efni; orð staðfest í gagnasöfnum Stofnunar Árna Magnússonar (málið.is).",
           "efnisgrindur": grids}, open(OUT + "/topic-grids.json", "w"), ensure_ascii=False, indent=1)
json.dump({"leyfi": "CC BY-SA 4.0. Frumsamið efni; dæmi staðfest í gagnasöfnum Stofnunar Árna Magnússonar (málið.is).",
           "flokkar": cats}, open(OUT + "/category-prompts.json", "w"), ensure_ascii=False, indent=1)
one = json.load(open(V + "/einsatkvaedisord.json"))
json.dump({"leyfi": "CC BY 4.0. Orðmyndir úr orðaforðalistum Evrópska tungumálarammans fyrir íslensku (CLARIN-IS), "
           "atkvæði talin eftir sérhljóðakjörnum (au, ei, ey teljast eitt).", "ordmyndir": one},
          open(OUT + "/one-syllable-words.json", "w"), ensure_ascii=False, indent=0)
json.dump(sorted(rejected, key=lambda r: r["ord"].lower()), open(OUT + "/../research/rejected-nouns.json", "w"),
          ensure_ascii=False, indent=0)

# ---------- stats ----------
print("nouns", len(nouns), "rejected", len(rejected), collections.Counter(r["astaeda"] for r in rejected))
print("thekking", sorted(collections.Counter(e["thekking"] for e in nouns).items()),
      "margraett", sum(e["margraett"] for e in nouns), "hlutbundid", sum(e["hlutbundid"] for e in nouns),
      "barnvaent", sum(e["barnvaent"] for e in nouns))
for g in GAMES:
    sel = [e for e in nouns if g in e["leikir"]]
    print("game", g, len(sel), "barnvaent", sum(e["barnvaent"] for e in sel))
print("grids", len(grids), "barnvaent", sum(g["barnvaent"] for g in grids),
      "with unverified items", sum(1 for g in grids if g["ostadfest"]), "unverified items", sum(len(g["ostadfest"]) for g in grids))
print("categories", len(cats), "barnvaent", sum(c["barnvaent"] for c in cats), collections.Counter(c["tegund"] for c in cats),
      "unverified examples", sum(len(c["ostadfest"]) for c in cats))
print("one-syllable forms", len(one))
