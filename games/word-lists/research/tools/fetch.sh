#!/bin/bash
# usage: fetch.sh OUTDIR word  -- fetch one word from málið.is if not cached
out="$1"; w="$2"; f="$out/$w.json"
[ -s "$f" ] && exit 0
enc=$(python3 -I -c 'import sys,urllib.parse;print(urllib.parse.quote(sys.argv[1]))' "$w")
for i in 1 2 3; do
  if curl -sf --max-time 40 -A "word-research-script" "https://malid.is/api_proxy/$enc" -o "$f.tmp" && python3 -I -c 'import json,sys;json.load(open(sys.argv[1]))' "$f.tmp" 2>/dev/null; then mv "$f.tmp" "$f"; exit 0; fi
  sleep 3
done
echo "FAIL $w" >&2; rm -f "$f.tmp"
