"""Check single words on málið.is: exists if any collection has it as a headword, or BÍN knows it as an inflected form.
usage: malid_exists.py word ... -> prints word, verdict, lemma(s)."""
import json, ssl, sys, time, urllib.parse, urllib.request
ctx = ssl.create_default_context(cafile="/root/.ccr/ca-bundle.crt")
for w in sys.argv[1:]:
    url = "https://malid.is/api_proxy/" + urllib.parse.quote(w)
    d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "word-research-script"}), context=ctx, timeout=30).read())
    m = d.get("malid") or {}
    heads = [k for k, v in m.items() if v and k not in ("beygingar",)]
    lem = [f.get("lemma") or f.get("fletta") for b in m.get("beygingar", []) for f in (b.get("flettur") or []) if isinstance(f, dict)]
    print(w, "OK" if heads or lem else "UNKNOWN", ",".join(sorted(set(x for x in lem if x)))[:80], ",".join(heads)[:60])
    time.sleep(0.4)
