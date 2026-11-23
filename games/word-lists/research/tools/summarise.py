"""Summarise cached málið.is JSON into a compact per-word record (JSON lines)."""
import html, json, os, re, sys
raw_dir, out = sys.argv[1], sys.argv[2]

def strip(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    return html.unescape(s).replace("＝", "=").strip()

def blondal_segment(fhtml, word):
    toks = re.split(r"(<b>.*?</b>)", fhtml)
    base = None; segs = []; cur = None
    for t in toks:
        m = re.fullmatch(r"<b>(.*?)</b>", t)
        if m:
            h = strip(m.group(1))
            if re.fullmatch(r"[0-9IVX]+\.?|[a-z]\)", h):
                if cur: cur[1].append(t)
                continue
            if h.startswith("-") and base is not None:
                full = base + h[1:]
            else:
                parts = h.split("|")
                base = parts[0]
                full = h.replace("|", "")
            cur = [full, []]; segs.append(cur)
        elif cur:
            cur[1].append(t)
    hits = [strip("".join(c)) for f, c in segs if f.replace(" ", "") == word or re.sub(r"[^\wáéíóúýþæöð]", "", f) == word]
    return hits

rows = []
for fn in sorted(os.listdir(raw_dir)):
    word = fn[:-5]
    d = json.load(open(os.path.join(raw_dir, fn)))
    m = d.get("malid") if isinstance(d, dict) else None
    if not m:
        rows.append({"w": word, "found": []}); continue
    r = {"w": word}
    found = []
    ino = [k for k in m.get("kata", []) if k.get("fletta") == word]
    if ino:
        found.append("ÍNO")
        r["ino_id"] = ino[0]["id"]
        r["ino"] = [{"ofl": k["ordflokkur"], "skyr": [s["skyring"] for s in (k.get("skyring") or [])],
                     "notkun": k.get("notkun"), "svid": k.get("svid"),
                     "lidir": [(l.get("skyring") or l.get("texti") or "") if isinstance(l, dict) else l for l in (k.get("lidur") or [])][:6]} for k in ino]
    bl = [b for b in m.get("blondal", []) if b.get("ord") == word]
    if bl:
        found.append("Blöndal")
        r["blondal_id"] = bl[0]["id"]; r["blondal_bok"] = bl[0].get("bok")
        segs = []
        for b in bl:
            segs += blondal_segment(b["fletta"], word)
        if segs:
            r["blondal"] = segs[:3]
        else:
            found.pop(); r.pop("blondal_id"); r.pop("blondal_bok")
    rm = [x for x in m.get("ritmalssafn", []) if x.get("fletta") == word]
    if rm:
        found.append("Ritmálssafn")
        r["roh"] = [(x["ordflokkur"], x.get("fjoldi"), x.get("aldur")) for x in rm]
        r["roh_id"] = rm[0]["id"]
    en = [x for x in m.get("enska", []) if x.get("fletta") == word]
    if en:
        found.append("ISLEX")
        r["en"] = [mm["target_lang"] for x in en for mm in x.get("merking", [])][:5]
        r["islex_id"] = en[0]["id"]
    da = [x for x in m.get("danska", []) if x.get("fletta") == word]
    if da:
        r["da"] = [mm["target_lang"] for x in da for mm in x.get("merking", [])][:5]
    ob = [x for x in m.get("ordabanki", []) if x.get("hugtak_ord") == word]
    if ob:
        found.append("Íðorðabanki")
        r["obanki"] = [(x.get("ordasafn"), strip(x.get("skilgreining")), strip(x.get("skyring")), [t["erlent_ord"] for t in (x.get("thyding") or [])][:2]) for x in ob][:3]
    osb = [x for x in m.get("ordsifjabok", []) if word in str(x.get("fletta"))]
    if osb:
        found.append("Orðsifjabók")
        r["osb"] = strip(osb[0]["faersla_html"])[:300]
    if any(x.get("fletta") == word for x in m.get("ordanet", [])): found.append("Orðanet")
    if any(x.get("fletta") == word for x in m.get("stafsetning", [])): found.append("Stafsetning")
    if any(x.get("lemma") == word for x in m.get("bin_malid2", [])): found.append("BÍN")
    r["n_coll"] = sum(1 for k, v in m.items() if v)
    r["found"] = found
    rows.append(r)
with open(out, "w", encoding="utf-8") as f:
    for r in rows: f.write(json.dumps(r, ensure_ascii=False) + "\n")
print(len(rows), "rows;", sum(1 for r in rows if r["found"]), "found in some source")
