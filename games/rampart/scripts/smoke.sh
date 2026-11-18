#!/usr/bin/env bash
# Runs the game headless for a while on autopilot (an invulnerable run through the level, then the
# citadel and its boss, then the same on level 12, the hardest) and fails on any script error. GODOT is the Godot 4.7.2 binary ("godot" by default).
set -euo pipefail
cd "$(dirname "$0")/../godot"
godot="${GODOT:-godot}"
"$godot" --headless --path . --import >/dev/null 2>&1 || true
fail=0
for args in "--autoplay" "--autoplay --goto=13" "--autoplay --level=12" "--autoplay --level=12 --goto=29"; do
  # shellcheck disable=SC2086
  out=$("$godot" --headless --path . --quit-after 2400 -- $args 2>&1 || true)
  if grep -E "SCRIPT ERROR|Parse Error|Failed to load script" <<<"$out"; then fail=1; fi
done
if [ "$fail" = 1 ]; then echo "Rampart: script errors in the smoke run" >&2; exit 1; fi
echo "Rampart: smoke run clean"
