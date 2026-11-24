#!/usr/bin/env bash
# The `build` step of a retro-games pipeline. The pipeline's name is the game: `…/retro-games:chess` builds games/chess.
# It does what the game's `npm run deploy` does short of `wrangler deploy`, as .github/workflows/game.yml did:
#
#   npm ci; npm test; npm run test:godot (when the game has it); npm run build; no .dev folder in dist/;
#   wrangler deploy --dry-run --outdir, with the game's own wrangler (package-lock.json).
#
# and leaves in /zazzle/output everything the `deploy` step needs, so that it never rebuilds:
#
#   BUILD            game=, commit=, wrangler= (the game's locked version), node=, godot=
#   wrangler.jsonc   the game's config; `deploy` names bundle/index.js as the script, so its `main` is not used
#   bundle/          the bundled Worker (index.js, and its source map)
#   dist.tar.gz      the static assets, dist/ as the build left it (packed: some games have thousands of files)
set -euo pipefail
export HOME=/tmp npm_config_cache=/tmp/.npm CI=1 WRANGLER_SEND_METRICS=false
unset BASE_PATH # dictator, hivestorm, meg, rally and shatterbelt build for another path when it is set

out=${ZAZZLE_OUTPUT:-/zazzle/output}
game=${ZAZZLE_PIPELINE:?ZAZZLE_PIPELINE is not set}
game=${game#*:}; game=${game%@*}
case "$game" in ''|*[!a-z0-9_-]*) echo "build: '$game' (from ZAZZLE_PIPELINE=$ZAZZLE_PIPELINE) is not a game folder name" >&2; exit 1 ;; esac
src=$(ls -d /zazzle/input/repos/*/retro-games 2>/dev/null | head -1)
[ -n "$src" ] || { echo "build: no retro-games checkout under /zazzle/input/repos" >&2; exit 1; }
for f in package.json package-lock.json wrangler.jsonc; do
  [ -f "$src/games/$game/$f" ] || { echo "build: games/$game/$f is missing: the pipeline's name must be a game's folder" >&2; exit 1; }
done
commit=${ZAZZLE_COMMIT:-$(git -c safe.directory='*' -C "$src" rev-parse HEAD)}

# The input is read-only, so build in a copy: the game, and the shared folders a game reaches with ../ (the sign-in
# library, and the word lists Laumufarþegi bundles).
repo=/tmp/retro-games
mkdir -p "$repo/games"
cp -R "$src/games/$game" "$repo/games/$game"
cp -R "$src/vendor" "$repo/vendor"
cp -R "$src/games/word-lists" "$repo/games/word-lists"
cd "$repo/games/$game"

# Godot looks for its export templates in ~/.local/share/godot, and writes its editor settings there.
mkdir -p "$HOME/.local/share/godot/export_templates"
ln -sfn "/opt/godot/export_templates/$GODOT_VERSION.stable" "$HOME/.local/share/godot/export_templates/$GODOT_VERSION.stable"
# Godot imports S3TC/BPTC textures (desktop GPUs, and the macOS export's requirement) by default only when the editor
# runs on x86_64, as it did on GitHub's runners; on an arm64 builder it would not. Every game sets ETC2/ASTC itself and
# none sets S3TC/BPTC, so say it here, in the copy's project.godot, for any game that does not decide it: the same build
# on any machine. (Not override.cfg: the editor, which exports, ignores it.) Godot merges a repeated [rendering] section.
if [ -f godot/project.godot ] && ! grep -q 'import_s3tc_bptc' godot/project.godot; then
  printf '\n[rendering]\n\ntextures/vram_compression/import_s3tc_bptc=true\n' >> godot/project.godot
fi
# Iron Haze and Twelve Banners print the commit on their landing page.
export GITHUB_SHA=$commit

echo "build: $game at $commit"
npm ci --no-audit --no-fund
npm test
if node -e 'process.exit(require("./package.json").scripts?.["test:godot"] ? 0 : 1)'; then
  npm run test:godot
fi
npm run build

found=$(find dist -name .dev)
if [ -n "$found" ]; then echo "build: the build would ship .dev folders (they document the code, AGENTS.md): $found" >&2; exit 1; fi

npx wrangler deploy --dry-run -c wrangler.jsonc --outdir /tmp/bundle
[ -f /tmp/bundle/index.js ] || { echo "build: wrangler left no bundle/index.js" >&2; ls -la /tmp/bundle >&2; exit 1; }

mkdir -p "$out/bundle"
cp /tmp/bundle/index.js "$out/bundle/"
[ ! -f /tmp/bundle/index.js.map ] || cp /tmp/bundle/index.js.map "$out/bundle/"
cp wrangler.jsonc "$out/wrangler.jsonc"
tar -czf "$out/dist.tar.gz" dist
{
  echo "game=$game"
  echo "commit=$commit"
  echo "wrangler=$(node -p 'require("./node_modules/wrangler/package.json").version')"
  echo "node=$(node --version)"
  echo "godot=$GODOT_VERSION"
} > "$out/BUILD"

cat "$out/BUILD"
ls -l "$out" "$out/bundle"
echo "build: $game built ($(find dist -type f | wc -l | tr -d ' ') files in dist/)"
