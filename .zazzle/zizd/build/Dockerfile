# The `build` step of every retro-games pipeline (one per game, named after its folder under games/): the game's tests,
# its Godot tests when it has `test:godot`, its build, and the Worker bundled without deploying (run.sh). Shared by
# every game, so Godot is always here; a game without Godot simply never runs it.
#
# Pinned: Node 22 (the version .github/workflows/game.yml asks for), Godot 4.7.2 with only the export templates the
# games use (Web for all; Linux x86_64, Windows x86_64 and macOS for Iron Haze's and Twelve Banners' downloads),
# checked against the SHA-512 sums Godot publishes with the release. Each game's wrangler and the rest come from its
# own package-lock.json (`npm ci` in run.sh).
FROM node:22.23.2-bookworm-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends bash ca-certificates curl git unzip zip libfontconfig1 \
 && rm -rf /var/lib/apt/lists/*

ENV GODOT_VERSION=4.7.2
RUN set -eu; \
    base="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"; \
    case "$(uname -m)" in \
      aarch64) arch=arm64;  sum=dd59918da086bd49bde2f5450b5e567ff8650cbde9abbd7b8f4ca1197ff8c609baa38834666d032deafb47099078d7822279e2a0e06e5665745468f26533e7e2 ;; \
      x86_64)  arch=x86_64; sum=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65 ;; \
      *) echo "no Godot build for $(uname -m)" >&2; exit 1 ;; \
    esac; \
    cd /tmp; \
    curl -fsSLo godot.zip "$base/Godot_v${GODOT_VERSION}-stable_linux.${arch}.zip"; \
    echo "$sum  godot.zip" | sha512sum -c -; \
    unzip -q godot.zip; mv "Godot_v${GODOT_VERSION}-stable_linux.${arch}" /usr/local/bin/godot; \
    curl -fsSLo templates.tpz "$base/Godot_v${GODOT_VERSION}-stable_export_templates.tpz"; \
    echo "ca4d71c4d7b81dfc15d1a98baa07534aa95b03fdda78a0075b06672e1648d2e5f40980c9adc28d23e1b92e732ee7bf3461997aa804af74ec2fcd7a93ccb84079  templates.tpz" | sha512sum -c -; \
    unzip -q templates.tpz 'templates/version.txt' 'templates/web_*' 'templates/linux_*.x86_64' \
      'templates/windows_*_x86_64*' 'templates/macos.zip' -d /tmp/t; \
    mkdir -p /opt/godot/export_templates; mv /tmp/t/templates "/opt/godot/export_templates/${GODOT_VERSION}.stable"; \
    rm -rf /tmp/godot.zip /tmp/templates.tpz /tmp/t; \
    godot --version

COPY run.sh /run.sh
CMD ["bash", "/run.sh"]
