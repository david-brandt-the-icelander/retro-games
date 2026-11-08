#!/bin/bash
# Renders the design's reference screens into docs/screens/ at 1440×900 with Godot's OpenGL
# (Compatibility) renderer, from the reference scenario. Needs Godot 4.7.2 on the PATH (or $GODOT),
# Xvfb, and the local dev server (npm run dev) with .dev.vars holding DEV_LOGIN=1 and dummy
# GOOGLE_/GITHUB_ client ids and secrets (so the sign-in screen shows both buttons). Run seed.py and
# retime.py first, on a fresh local database.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
GAME=$(dirname "$(dirname "$HERE")")
GODOT=${GODOT:-godot}
OUT=$GAME/docs/screens
UD=${GODOT_USER_DATA:-$HOME/.local/share/godot/app_userdata/Gambit}
mkdir -p "$OUT"
cd "$GAME/godot"
ids() { python3 -c "import json;print(json.load(open('$HERE/.seed.json'))['ids']['$1'])"; }
shot() {
  name=$1; shift
  timeout 90 xvfb-run -a -s "-screen 0 1440x900x24" "$GODOT" --rendering-driver opengl3 --resolution 1440x900 -- "$@" --shot="$OUT/$name.png" >/dev/null 2>&1
  echo "$name $(test -f "$OUT/$name.png" && echo ok || echo MISSING)"
}
rm -f "$UD/computer.json" "$UD/history.json"
shot 01-home-signed-out --shot-after=4
shot 02-sign-in --goto=lobby --shot-after=4
shot 03-computer-setup --goto=setup --shot-after=3
shot 04-computer-your-move --goto=computer --moves=e2e4,e7e5,g1f3,b8c6,f1c4,f8c5 --shot-after=4
shot 05-home-continue --shot-after=4
python3 "$HERE/local_history.py" "$UD/history.json"
shot 06-history-signed-out --goto=history --shot-after=4
rm -f "$UD/computer.json"
A=--dev-email=alice@test.io
shot 07-home-signed-in $A --shot-after=5
shot 08-lobby $A --goto=lobby --shot-after=5
shot 09-lobby-invitation-sent $A --goto=lobby --invite=gina@test.io --shot-after=4
shot 10-contact $A --goto=contact --contact=bob@test.io --shot-after=4
shot 11-history $A --goto=history --shot-after=4
shot 12-game-draw-offered $A --goto=game --id="$(ids carla_offer)" --shot-after=5
shot 13-game-check $A --goto=game --id="$(ids bob_check)" --shot-after=5
shot 14-game-piece-selected $A --goto=game --id="$(ids dan_promo)" --select=g1 --shot-after=2
shot 15-game-promotion $A --goto=game --id="$(ids dan_promo)" --promote=b7a8 --shot-after=2
shot 16-game-looking-back $A --goto=game --id="$(ids carla_offer)" --view=4 --shot-after=2
shot 17-game-finished $A --goto=game --id="$(ids bob_mate)" --mode=online --shot-after=5
shot 18-replay-start $A --goto=game --id="$(ids bob_mate)" --shot-after=5
shot 19-replay-midway $A --goto=game --id="$(ids bob_mate)" --seek=7 --shot-after=2
shot 20-game-waiting $A --goto=game --id="$(ids bob_waiting)" --shot-after=5
shot 21-toast-info $A --toast="Invitation sent." --shot-after=1
shot 22-toast-error $A "--error-toast=You can't challenge yourself. Try the computer!" --shot-after=1
timeout 90 xvfb-run -a -s "-screen 0 1440x900x24" "$GODOT" --rendering-driver opengl3 --resolution 1440x900 -s tests/pieces_shot.gd -- --out="$OUT/23-pieces.png" >/dev/null 2>&1
echo "23-pieces $(test -f "$OUT/23-pieces.png" && echo ok || echo MISSING)"
python3 "$HERE/contact_sheet.py" "$OUT" "$GAME/docs/contact-sheet.png"
