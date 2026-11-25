# The `deploy` step of every retro-games pipeline (deploys: true): the database migration gate, then the Worker the
# `build` step bundled, from /zazzle/input/artifacts/build/ (run.sh). It never rebuilds, so it has no Godot and runs no
# npm ci. Shared by every game.
#
# Pinned: Node 22 (as the build step), wrangler 4.167.0 (the newest any game's package-lock.json holds; the bundle itself
# was made by the game's own locked wrangler in `build`), and the GitHub CLI 2.103.3 for the gate
# (.github/scripts/migration-gate.sh reads the pull requests' descriptions with it), checked against its published
# SHA-256 sums.
FROM node:22.23.2-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl git \
 && rm -rf /var/lib/apt/lists/*

ENV GH_VERSION=2.103.3
RUN set -eu; \
    case "$(uname -m)" in \
      aarch64) arch=arm64; sum=ee32df2323c8847f5fac6cb6b4b69ca75828e9329a8f22f677021f7b3306ce63 ;; \
      x86_64)  arch=amd64; sum=4c806978ffce1cec70853302a56d70ac6da4f19bae7adca4e1a8ab00633dd91d ;; \
      *) echo "no gh build for $(uname -m)" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    curl -fsSLo gh.tar.gz "https://github.com/cli/cli/releases/download/v${GH_VERSION}/gh_${GH_VERSION}_linux_${arch}.tar.gz"; \
    echo "$sum  gh.tar.gz" | sha256sum -c -; \
    tar -xzf gh.tar.gz; mv "gh_${GH_VERSION}_linux_${arch}/bin/gh" /usr/local/bin/gh; \
    rm -rf /tmp/gh.tar.gz "/tmp/gh_${GH_VERSION}_linux_${arch}"; \
    gh --version

RUN npm install -g --no-audit --no-fund wrangler@4.167.0 && npm cache clean --force && wrangler --version

COPY run.sh /run.sh
CMD ["bash", "/run.sh"]
