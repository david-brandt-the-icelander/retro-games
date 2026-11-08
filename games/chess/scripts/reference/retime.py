# Gives the reference scene realistic times: games spread over the last week, moves minutes to hours apart.
# Run after seed.py.
import os
HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(os.path.dirname(HERE))
SEED = os.path.join(HERE, ".seed.json")
import json, subprocess, random, time
seed = json.load(open(SEED))
ids = seed["ids"]
now = int(time.time() * 1000)
H, M, D = 3600_000, 60_000, 86400_000
# When each game started, and how long its moves typically took.
plan = {
    "eva_draw": (now - 6 * D - 3 * H, 90_000),
    "carla_lost": (now - 3 * D - 5 * H, 120_000),
    "bob_mate": (now - 2 * H - 14 * M, 25_000),
    "bob_check": (now - 50 * M, 60_000),
    "dan_promo": (now - 2 * D - 2 * H, 2 * H),
    "carla_offer": (now - 5 * H, 9 * M),
    "bob_waiting": (now - 2 * D, 6 * H),
}
rows = json.loads(subprocess.check_output(["npx", "wrangler", "d1", "execute", "chess", "--local", "--json", "--command",
    "SELECT game_id, seq, kind FROM game_events ORDER BY game_id, seq"], cwd=GAME))[0]["results"]
random.seed(7)
sql = []
last = {}
for r in rows:
    gid = r["game_id"]
    name = next((k for k, v in ids.items() if v == gid), None)
    if name is None:
        continue
    start, pace = plan[name]
    t = last.get(gid, start)
    if r["seq"] > 1:
        gap = {"move": random.uniform(0.25, 1.9) * pace, "chat": random.uniform(8_000, 40_000)}.get(r["kind"], random.uniform(3_000, 15_000))
        if r["kind"] == "end": gap = 0
        t = int(t + gap)
    last[gid] = t
    sql.append(f"UPDATE game_events SET at = {t} WHERE game_id = '{gid}' AND seq = {r['seq']};")
for name, gid in ids.items():
    sql.append(f"UPDATE games SET created = {plan[name][0]}, updated = {last[gid]} WHERE id = '{gid}';")
# The computer game: two days ago.
sql.append(f"UPDATE game_events SET at = at - {2 * D} WHERE game_id IN (SELECT id FROM games WHERE kind = 'computer');")
sql.append(f"UPDATE games SET created = created - {2 * D}, updated = updated - {2 * D} WHERE kind = 'computer';")
sql.append(f"UPDATE challenges SET created = created - {40 * M} WHERE to_email = 'alice@test.io';")
sql.append(f"UPDATE challenges SET created = created - {3 * H} WHERE to_email = 'frank@test.io';")
open(os.path.join(HERE, ".retime.sql"), "w").write("\n".join(sql))
subprocess.check_call(["npx", "wrangler", "d1", "execute", "chess", "--local", "--file", os.path.join(HERE, ".retime.sql")], cwd=GAME, stdout=subprocess.DEVNULL)
print("retimed", len(sql))
