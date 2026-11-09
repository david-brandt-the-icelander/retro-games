#!/usr/bin/env bash
# The database migration gate (docs/database-migrations.md). It fails when a change to the
# database reaches main, or is about to, without an acknowledgement that production's database
# has been migrated.
#   migration-gate.sh pr <base sha> <pull request number>   the pull request check (migrations.yml)
#   migration-gate.sh deploy [<base sha>]                    before every deploy (deploy.yml)
# Needs gh, signed in (GH_TOKEN in Actions).
set -euo pipefail
cd "$(dirname "$0")/../.."

DOC=docs/database-migrations.md
# What counts as a database change, and how each file reaches production. Each game has its own
# database, named in its wrangler.jsonc.
PATHS=(':(glob)games/*/worker/schema.sql' ':(glob)games/*/worker/migrations/**')
how_to() {
  local game db
  game=$(cut -d/ -f2 <<<"$1")
  db=$(grep -o '"database_name": *"[^"]*"' "games/$game/wrangler.jsonc" | cut -d'"' -f4)
  case "$1" in
    */worker/migrations/*) echo "apply with \`cd games/$game && npx wrangler d1 execute $db --remote -y --file ${1#games/"$game"/}\`" ;;
    *) echo "describes a fresh \`$db\` database. The live one changes only through a file in \`games/$game/worker/migrations/\`: add one if this change has none" ;;
  esac
}

# ---------------------------------------------------------------------------------------------
# The rest is the same in every repository that has this gate.

ack_re='^[[:space:]]*[-*][[:space:]]*\[[xX]\][[:space:]]*(Database migration applied to production|No database migration is needed)'

say() { printf '%s\n' "$@" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}" >&2; }

# The database files changed between $1 and HEAD, deletions left out.
changed() { git diff --name-only --diff-filter=ACMR "$1" HEAD -- "${PATHS[@]}"; }

acked() { gh pr view "$1" --json body --jq .body | grep -qiE "$ack_re"; }

explain() { # explain <files>
  say "" "This change touches the database:" ""
  while read -r f; do [ -n "$f" ] && say "- \`$f\`: $(how_to "$f")"; done <<<"$1"
  say "" \
    "Production's database is not migrated by the pipeline. Apply the migration by hand, as $DOC" \
    "says, and then acknowledge it in the pull request's description with one of these lines:" "" \
    '    - [x] Database migration applied to production: <files>, <database>, <date>' \
    '    - [x] No database migration is needed: <why>' ""
}

mode=${1:-}
case "$mode" in
  pr) # migration-gate.sh pr <base sha> <pull request number>
    files=$(changed "$2")
    if [ -z "$files" ]; then echo "No database changes."; exit 0; fi
    explain "$files"
    if acked "$3"; then say "Acknowledged in the pull request's description."; exit 0; fi
    echo "::error title=Database migration not acknowledged::Apply the migration ($DOC), then tick the box in the pull request's description."
    exit 1 ;;

  deploy) # migration-gate.sh deploy [<base sha>]: the commits since base, by the pull requests that brought them
    base=${2:-}
    git cat-file -e "$base^{commit}" 2>/dev/null || base=HEAD~1
    files=$(changed "$base")
    if [ -z "$files" ]; then echo "No database changes since $base."; exit 0; fi
    explain "$files"
    if [ "${MIGRATION_APPLIED:-false}" = true ]; then
      say "Acknowledged by whoever started this run (migration_applied)."; exit 0
    fi
    missing=""
    for c in $(git log --no-merges --format=%H "$base..HEAD" -- "${PATHS[@]}"); do
      ok=""
      for pr in $(gh api "repos/{owner}/{repo}/commits/$c/pulls" --jq '.[].number'); do
        acked "$pr" && { ok=$pr; break; }
      done
      if [ -n "$ok" ]; then say "- $(git log -1 --format='%h %s' "$c"): acknowledged in #$ok"
      else say "- $(git log -1 --format='%h %s' "$c"): NOT acknowledged"; missing=1; fi
    done
    if [ -z "$missing" ]; then exit 0; fi
    say "" "Nothing was deployed. Apply the migration, tick the box in the pull request, and re-run" \
      "this workflow run; or, for a commit pushed without a pull request, run the Deploy workflow" \
      "by hand with migration_applied ticked. $DOC says how."
    echo "::error title=Database migration not acknowledged::Not deployed. Apply the migration and acknowledge it ($DOC)."
    exit 1 ;;

  *) echo "usage: $0 pr <base sha> <pull request number> | deploy [<base sha>]" >&2; exit 2 ;;
esac
