# Writes a signed-out player's local history (one finished game against the computer) for the render.
import os
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(os.path.dirname(HERE))
SEED = os.path.join(HERE, ".seed.json")
import json, sys, urllib.request
seed = json.load(open(SEED))
req = urllib.request.Request("http://127.0.0.1:8787/games/retro/chess/api/games", headers={"Authorization": "Bearer " + seed["alice"]})
games = json.load(urllib.request.urlopen(req))["games"]
g = next(x for x in games if x["kind"] == "computer")
g["id"] = "local-1"
g["white"] = {"id": None, "email": None, "name": "You", "avatar": None}
json.dump([g], open(sys.argv[1], "w"))
