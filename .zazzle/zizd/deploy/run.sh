#!/usr/bin/env bash
# The `deploy` step of a retro-games pipeline (deploys: true). The pipeline's name is the game, as in `build`.
# It deploys what `build` left in /zazzle/input/artifacts/build/ and never rebuilds:
#
#   1. refuse without CLOUDFLARE_API_TOKEN or GITHUB_TOKEN (the gate reads pull requests with it), or without the
#      build's artifacts, or with artifacts of another game or commit;
#   2. the database migration gate (docs/database-migrations.md): nothing deploys while a change to this game's
#      worker/schema.sql or worker/migrations/ since its last deploy is unacknowledged in its pull request. "The last
#      deploy" is the newest of the Worker's deployments whose version message is `zizd <commit>` (this step writes it);
#      before the first, the commit that added this step to the repository;
#   3. `wrangler deploy bundle/index.js --no-bundle`, with the game's own wrangler.jsonc and its dist/, and the message
#      `zizd <commit>`.
#
# Before each sub-step it checks ZAZZLE_HALT_FILE and exits 75 when asked to halt, so a deployment stops between
# sub-steps, never in the middle of one. Production's database is never migrated here: that stays by hand.
#
# By hand only (no pipeline names these): DEPLOY_DRY_RUN=1 needs no Cloudflare credentials, takes the gate's starting
# commit from MIGRATION_GATE_BASE (or the fallback above) instead of asking Cloudflare, and runs
# `wrangler deploy --dry-run`. The gate still runs, and reads GitHub when it finds a database change.
set -euo pipefail
export HOME=/tmp npm_config_cache=/tmp/.npm CI=1 WRANGLER_SEND_METRICS=false
# The old Deploy workflow's override. No step may skip the gate: a database change is acknowledged in its pull request.
unset MIGRATION_APPLIED
# No game's wrangler.jsonc names the account (the same id .github/workflows/game.yml set).
export CLOUDFLARE_ACCOUNT_ID=${CLOUDFLARE_ACCOUNT_ID:-ab026008f5aa2bef2dca4cfccd0f70ef}

dry=${DEPLOY_DRY_RUN:-}
art=${ZAZZLE_ARTIFACTS:-/zazzle/input/artifacts}/build
game=${ZAZZLE_PIPELINE:?ZAZZLE_PIPELINE is not set}
game=${game#*:}; game=${game%@*}
case "$game" in ''|*[!a-z0-9_-]*) echo "deploy: refusing: '$game' (from ZAZZLE_PIPELINE=$ZAZZLE_PIPELINE) is not a game folder name" >&2; exit 1 ;; esac
refuse() { echo "deploy: refusing to deploy $game: $*" >&2; exit 1; }
halted() {
  if [ -n "${ZAZZLE_HALT_FILE:-}" ] && [ -f "$ZAZZLE_HALT_FILE" ]; then
    echo "deploy: halting before $1, as asked: $(cat "$ZAZZLE_HALT_FILE")"
    exit 75
  fi
}

# 1. Credentials and artifacts.
if [ -z "$dry" ]; then
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || refuse "CLOUDFLARE_API_TOKEN is not set"
  [ -n "${GITHUB_TOKEN:-}" ] || refuse "GITHUB_TOKEN is not set (the migration gate reads the pull requests with it)"
fi
for f in BUILD wrangler.jsonc bundle/index.js dist.tar.gz; do
  [ -f "$art/$f" ] || refuse "the build step's artifacts have no $f ($art)"
done
built_game=$(sed -n 's/^game=//p' "$art/BUILD"); built_commit=$(sed -n 's/^commit=//p' "$art/BUILD")
[ "$built_game" = "$game" ] || refuse "the artifacts are of '$built_game', not '$game'"
[ -z "${ZAZZLE_COMMIT:-}" ] || [ "$built_commit" = "$ZAZZLE_COMMIT" ] || refuse "the artifacts are of $built_commit, not $ZAZZLE_COMMIT"
commit=$built_commit
src=$(ls -d /zazzle/input/repos/*/retro-games 2>/dev/null | head -1)
[ -n "$src" ] || refuse "no retro-games checkout under /zazzle/input/repos (the migration gate needs its history)"
owner=$(basename "$(dirname "$src")")
git config --global --add safe.directory '*'
[ "$(git -C "$src" rev-parse HEAD)" = "$commit" ] || refuse "the checkout is at $(git -C "$src" rev-parse HEAD), not $commit"
[ "$(git -C "$src" rev-parse --is-shallow-repository)" = false ] || refuse "the checkout is shallow: the migration gate needs the history since the last deploy"

rm -rf /tmp/deploy && mkdir -p /tmp/deploy
cp -R "$art/bundle" "$art/wrangler.jsonc" /tmp/deploy/
tar -xzf "$art/dist.tar.gz" -C /tmp/deploy
cd /tmp/deploy
[ -d dist ] || refuse "dist.tar.gz holds no dist/"
echo "deploy: $game at $commit, built with $(sed -n 's/^wrangler=/wrangler /p' "$art/BUILD"), uploading with wrangler $(wrangler --version 2>/dev/null | tail -1)"

# 2. The migration gate.
halted "the migration gate"
# The newest deployment this step made, from the version messages (`wrangler deploy --message "zizd <commit>"`).
last_deployed() {
  local deployments versions
  deployments=$(wrangler deployments list --json -c wrangler.jsonc 2>/dev/null) || return 0
  versions=$(wrangler versions list --json -c wrangler.jsonc 2>/dev/null) || versions='[]'
  DEPLOYMENTS=$deployments VERSIONS=$versions node -e '
    const parse = (s) => { try { const v = JSON.parse(s.slice(s.search(/^\s*[[{]/m))); return Array.isArray(v) ? v : (v.items ?? v.versions ?? v.deployments ?? []); } catch { return []; } };
    const message = new Map(parse(process.env.VERSIONS).map((v) => [v.id, v.annotations?.["workers/message"]]));
    const zizd = (m) => /^zizd [0-9a-f]{40}$/.test(m ?? "") ? m.slice(5) : "";
    const deployments = parse(process.env.DEPLOYMENTS).sort((a, b) => String(b.created_on).localeCompare(String(a.created_on)));
    for (const d of deployments) {
      const found = [d.annotations?.["workers/message"], ...(d.versions ?? []).map((v) => message.get(v.version_id))].map(zizd).find(Boolean);
      if (found) { console.log(found); break; }
    }'
}
if [ -n "$dry" ]; then
  base=${MIGRATION_GATE_BASE:-}
else
  base=$(last_deployed)
  [ -z "$base" ] || echo "deploy: last deployed by zizd: $base"
fi
if [ -z "$base" ] || ! git -C "$src" cat-file -e "$base^{commit}" 2>/dev/null; then
  [ -z "$base" ] || echo "deploy: $base is not in the history; falling back"
  base=$(git -C "$src" log --diff-filter=A --format=%H -1 -- .zazzle/zizd/deploy/run.sh)
  [ -n "$base" ] || refuse "cannot tell what was deployed last, so the migration gate cannot run"
  echo "deploy: no earlier deploy by zizd found; the gate checks everything since this step was added ($base)"
fi
if ! GH_TOKEN=${GITHUB_TOKEN:-} GH_REPO="$owner/retro-games" MIGRATION_GATE_GAME=$game \
     "$src/.github/scripts/migration-gate.sh" deploy "$base"; then
  echo "deploy: not deployed. Apply the migration (docs/database-migrations.md), tick the box in its pull request's" \
    "description, and run this pipeline's deploy again." >&2
  exit 1
fi

# 3. The Worker.
halted "the deploy"
if [ -n "$dry" ]; then
  wrangler deploy bundle/index.js --no-bundle -c wrangler.jsonc --dry-run
else
  wrangler deploy bundle/index.js --no-bundle -c wrangler.jsonc --message "zizd $commit"
fi
echo "deploy: $game deployed at $commit${dry:+ (dry run)}"
