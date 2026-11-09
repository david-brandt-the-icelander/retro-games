#!/usr/bin/env bash
# Prints the commit the last successful Deploy run deployed, or else $1 (the push's `before`),
# or nothing when Git has neither. The migration gate checks everything since that commit, so a
# deploy that failed the gate is checked again by the next one.
set -euo pipefail
cd "$(dirname "$0")/../.."
last=$(gh run list --workflow deploy.yml --branch main --status success --limit 1 --json headSha --jq '.[0].headSha // ""')
for c in "$last" "${1:-}"; do
  if [ -n "$c" ] && git cat-file -e "$c^{commit}" 2>/dev/null; then echo "$c"; exit 0; fi
done
