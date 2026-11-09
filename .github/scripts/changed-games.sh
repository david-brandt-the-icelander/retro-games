#!/usr/bin/env bash
# Prints, as a JSON array, the games under games/ that have a package.json and changed between
# the commit $1 and HEAD. With no $1, or one Git cannot diff against (a new branch, a force
# push), every game. A change outside games/ (the workflows themselves, say) also means every game.
set -euo pipefail
cd "$(dirname "$0")/../.."

all=$(for f in games/*/package.json; do basename "$(dirname "$f")"; done)
if [ -n "${1:-}" ] && files=$(git diff --name-only "$1" HEAD 2>/dev/null); then
  if grep -q '^\.github/' <<<"$files"; then
    games=$all
  else
    games=$(for g in $all; do grep -q "^games/$g/" <<<"$files" && echo "$g"; done || true)
  fi
else
  games=$all
fi
printf '%s\n' $games | jq -R . | jq -sc 'map(select(. != ""))'
