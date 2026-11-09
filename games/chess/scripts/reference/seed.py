# Fills a fresh local dev database with the reference scenario (docs/DESIGN.md, "The reference scenario").
# Run against `npm run dev` with DEV_LOGIN=1, then retime.py, then render.sh.
import os
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(os.path.dirname(HERE))
SEED = os.path.join(HERE, ".seed.json")
import json, urllib.parse, urllib.request
B = "http://127.0.0.1:8787/games/retro/chess/"
tok = {}
def login(email, name):
    r = urllib.request.urlopen(B + f"auth/dev?format=token&email={email}&name={urllib.parse.quote(name)}")
    tok[email] = json.load(r)["token"]
def call(who, method, path, body=None):
    req = urllib.request.Request(B + path, method=method, data=None if body is None else json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + tok[who], **({"Content-Type": "application/json"} if body is not None else {})})
    return json.load(urllib.request.urlopen(req))
people = {"alice@test.io": "Alice Morgan", "bob@test.io": "Bob Hansen", "carla@test.io": "Carla Ortiz", "dan@test.io": "Dan Okafor", "eva@test.io": "Eva Lind"}
for e, n in people.items(): login(e, n)
A = "alice@test.io"
ids = {}
# Moves as UCI strings; tuples are (player, action) inserted in order. The mover is worked out by ply.
def play(white, black, seq, after=()):
    c = call(white, "POST", "api/challenges", {"email": black, "color": "white"})["challenge"]
    g = call(black, "POST", f"api/challenges/{c['id']}/accept", {})["game"]
    ply = 0
    for step in seq:
        if isinstance(step, tuple):
            call(step[0], "POST", f"api/games/{g['id']}/action", step[1])
        else:
            call(white if ply % 2 == 0 else black, "POST", f"api/games/{g['id']}/action", {"type": "move", "uci": step, "ply": ply})
            ply += 1
    return g["id"]
B_, C_, D_, E_ = "bob@test.io", "carla@test.io", "dan@test.io", "eva@test.io"
ids["eva_draw"] = play(A, E_, ["e2e4", "c7c5", "g1f3", "d7d6", "d2d4", "c5d4", "f3d4", "g8f6", "b1c3", "a7a6", (E_, {"type": "draw-offer"}), (A, {"type": "draw-accept"}), (E_, {"type": "chat", "text": "Good game, rematch next week?"})])
ids["carla_lost"] = play(A, C_, ["d2d4", "d7d5", "c2c4", "e7e6", "b1c3", "g8f6", "c1g5", "f8e7", (A, {"type": "resign"}), (C_, {"type": "chat", "text": "Thanks for the game!"})])
ids["bob_mate"] = play(A, B_, [(B_, {"type": "chat", "text": "Good luck! Have fun."}), "e2e4", "e7e5", "f1c4", "b8c6", "d1h5", (B_, {"type": "chat", "text": "Hmm, the queen already?"}), "g8f6", "h5f7", (A, {"type": "chat", "text": "gg, thanks!"})])
ids["bob_check"] = play(A, B_, ["e2e4", "e7e5", "f2f4", "d8h4"])
ids["dan_promo"] = play(A, D_, ["a2a4", "b7b5", "a4b5", "a7a6", "b5a6", "c8b7", "a6b7", "h7h6"])
# Carla is white, Alice black; Alice to move, Carla has offered a draw.
ids["carla_offer"] = play(C_, A, ["e2e4", "e7e5", "g1f3", "b8c6", "f1b5", "a7a6", "b5a4", "g8f6", "e1g1", (C_, {"type": "chat", "text": "Ruy Lopez again :)"}), (C_, {"type": "draw-offer"})])
# A game where it's Bob's move.
ids["bob_waiting"] = play(A, B_, ["c2c4", "e7e5", "b1c3"])
# Invitations: one for Alice, one from Alice.
call(B_, "POST", "api/challenges", {"email": A, "color": "black"})
call(A, "POST", "api/challenges", {"email": "frank@test.io", "color": "random"})
# A finished game against the computer.
call(A, "POST", "api/games/computer", {"level": 5, "color": "white", "moves": ["f2f3", "e7e5", "g2g4", "d8h4"], "times": [9000, 11000, 31000, 33000], "resigned": False})
json.dump({"ids": ids, "alice": tok[A]}, open(SEED, "w"), indent=1)
print(ids)
