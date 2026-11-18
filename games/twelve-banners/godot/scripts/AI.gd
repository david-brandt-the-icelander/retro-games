class_name AI
extends RefCounted
## Simple but functional opponent AI. Runs on the host and issues ordinary
## commands through `submit`, exactly like a human client would.

const GRACE_TURNS = 20

const BUILD_PRIORITY = ["granary", "library", "market", "barracks", "workshop", "walls",
	"university", "bank", "castle", "factory", "hospital", "research_lab"]

const TECH_BIAS = {
	"pottery": 3, "mining": 3, "bronze_working": 2, "writing": 3, "archery": 2,
	"currency": 2, "mathematics": 1, "iron_working": 1, "education": 2, "philosophy": 1,
}

static func run_turn(g: Game, pid: int, submit: Callable) -> void:
	var p = g.player(pid)
	if not p.alive:
		return
	_research(g, pid, submit)
	var war = _war_mode(g, pid)
	var target_city = _pick_target_city(g, pid) if war else null
	for u in g.player_units(pid):
		if not g.units.has(u.id):
			continue
		match u.type:
			"settler":
				_settler(g, u, submit)
			"worker":
				_worker(g, u, submit)
			_:
				_military(g, u, submit, war, target_city)
	_cities(g, pid, submit)

# ---------------------------------------------------------------- research

static func _research(g: Game, pid: int, submit: Callable) -> void:
	var p = g.player(pid)
	if p.research != "":
		return
	var avail = g.available_techs(pid)
	if avail.is_empty():
		return
	var best = ""
	var best_v = 1e9
	for t in avail:
		var v: float = Defs.TECHS[t].cost - TECH_BIAS.get(t, 0) * 12 + g.rng.randf() * 15.0
		if v < best_v:
			best_v = v
			best = t
	submit.call({"t": "research", "tech": best})

# ---------------------------------------------------------------- cities

static func _cities(g: Game, pid: int, submit: Callable) -> void:
	var cities = g.player_cities(pid)
	var p = g.player(pid)
	var military = 0
	var settlers = 0
	var workers = 0
	for u in g.player_units(pid):
		if u.type == "settler": settlers += 1
		elif u.type == "worker": workers += 1
		else: military += 1
	for c in cities:
		if c.production == "settler": settlers += 1
		elif c.production == "worker": workers += 1
		elif Defs.UNITS.has(c.production): military += 1
	var target_cities = 4 + int(g.w * g.h / 900.0)
	var broke = g.income(pid).gold < 0 and p.gold < 40
	for c in cities:
		var threatened = _threat_near(g, c.pos, pid, 4)
		var need_change = c.production == "" or c.production == "wealth" or c.production == "research"
		if threatened and not Defs.UNITS.has(c.production) and military < cities.size() * 3:
			need_change = true
		if not need_change:
			_maybe_buy(g, c, submit, threatened)
			continue
		var choice = ""
		if threatened and _local_defenders(g, c.pos, pid) < 2:
			choice = _best_military(g, c)
		elif settlers == 0 and cities.size() < target_cities and c.pop >= 2 and g.turn < 160 and g.can_build(c, "settler"):
			choice = "settler"
			settlers += 1
		elif military < cities.size() + 1 and not broke:
			choice = _best_military(g, c)
		elif workers < maxi(1, cities.size() / 2) and g.turn > 5:
			choice = "worker"
			workers += 1
		else:
			if g.can_build(c, "spaceship"):
				choice = "spaceship"
			else:
				for b in BUILD_PRIORITY:
					if g.can_build(c, b):
						choice = b
						break
			if (choice == "" or (military < cities.size() * 2.5 and g.rng.randf() < 0.45)) and not broke:
				choice = _best_military(g, c)
			if choice == "":
				choice = "wealth" if broke else "research"
		if choice != "" and choice != c.production:
			if Defs.UNITS.has(choice) and choice != "settler" and choice != "worker":
				military += 1
			submit.call({"t": "prod", "c": c.id, "item": choice})
		_maybe_buy(g, c, submit, threatened)

static func _maybe_buy(g: Game, c, submit: Callable, threatened: bool) -> void:
	var cost = g.buy_cost(c)
	if cost <= 0:
		return
	var gold = g.player(c.owner).gold
	if (threatened and Defs.UNITS.has(c.production) and gold >= cost) or gold >= cost * 2 + 60:
		submit.call({"t": "buy", "c": c.id})

static func _best_military(g: Game, c) -> String:
	var best = "warrior"
	var bv = -1.0
	for k in Defs.UNITS:
		var d: Dictionary = Defs.UNITS[k]
		if d["class"] == "civilian" or k == "scout" or not g.can_build(c, k):
			continue
		var v: float = maxf(d.str, d.rstr * 0.9) + g.rng.randf() * 3.0
		if d["class"] == "siege":
			v *= 0.8
		if v > bv:
			bv = v
			best = k
	return best

static func _threat_near(g: Game, pos: Vector2i, pid: int, r: int) -> bool:
	for u in g.units.values():
		if u.owner != pid and not u.is_civilian() and Hex.distance(u.pos, pos) <= r:
			return true
	return false

static func _local_defenders(g: Game, pos: Vector2i, pid: int) -> int:
	var n = 0
	for u in g.units.values():
		if u.owner == pid and not u.is_civilian() and Hex.distance(u.pos, pos) <= 2:
			n += 1
	return n

# ---------------------------------------------------------------- settlers / workers

static func site_score(g: Game, pos: Vector2i, pid: int) -> float:
	if not g.is_land(pos):
		return -1.0
	var o = g.tile_owner[g.idx(pos)]
	if o != -1 and o != pid:
		return -1.0
	var nearest_own = 99
	for c in g.cities.values():
		var d = Hex.distance(c.pos, pos)
		if d < 3:
			return -1.0
		if c.owner == pid:
			nearest_own = mini(nearest_own, d)
	var s = 0.0
	for t in g.within(pos, 2):
		var y = g.tile_yield(t)
		var w = 1.0 if Hex.distance(t, pos) == 1 else 0.6
		s += (y.x * 1.4 + y.y * 1.1 + y.z * 0.6) * w
		var ow = g.tile_owner[g.idx(t)]
		if ow != -1 and ow != pid:
			s -= 1.5
	if g.hills[g.idx(pos)] == 1:
		s += 2.0
	for n in g.neighbors(pos):
		if g.is_water(n):
			s += 0.6
			break
	if nearest_own < 99:
		s -= absf(nearest_own - 4.0) * 1.5
	return s

static func _settler(g: Game, u, submit: Callable) -> void:
	if u.goto.x >= 0 and u.moves == 0:
		return
	var here = site_score(g, u.pos, u.owner)
	var best = u.pos
	var best_s = here
	for t in g.within(u.pos, 7):
		var s = site_score(g, t, u.owner)
		if s < 0:
			continue
		s -= Hex.distance(t, u.pos) * 1.2
		if s > best_s + 0.5:
			best_s = s
			best = t
	if (best == u.pos or here > best_s - 2.0) and g.can_found_city(u):
		submit.call({"t": "found", "u": u.id})
		return
	if best != u.pos and u.moves > 0:
		if not submit.call({"t": "move", "u": u.id, "to": best}):
			if g.can_found_city(u):
				submit.call({"t": "found", "u": u.id})
	elif g.can_found_city(u):
		submit.call({"t": "found", "u": u.id})
	elif u.moves > 0:
		# Wander to escape a bad spot.
		var opts = g.neighbors(u.pos)
		opts.shuffle()
		for n in opts:
			if submit.call({"t": "move", "u": u.id, "to": n}):
				break

static func _worker(g: Game, u, submit: Callable) -> void:
	if u.build_kind != "" or u.moves <= 0:
		return
	if _threat_near(g, u.pos, u.owner, 2):
		var c = _nearest_own_city(g, u)
		if c != null and c.pos != u.pos:
			submit.call({"t": "move", "u": u.id, "to": c.pos})
			return
	var kind = _improve_kind(g, u, u.pos)
	if kind != "":
		submit.call({"t": "improve", "u": u.id, "kind": kind})
		return
	var best = Vector2i(-1, -1)
	var bd = 99
	for c in g.player_cities(u.owner):
		for t in g.city_tiles(c):
			if g.improvement[g.idx(t)] != "" or g.city_at.has(t):
				continue
			if _improve_kind(g, u, t) == "":
				continue
			var taken = false
			for o in g.units.values():
				if o != u and o.type == "worker" and (o.pos == t or o.goto == t):
					taken = true
			if taken:
				continue
			var d = Hex.distance(u.pos, t)
			if d < bd:
				bd = d
				best = t
	if best.x >= 0:
		submit.call({"t": "move", "u": u.id, "to": best})
	else:
		submit.call({"t": "sleep", "u": u.id})

static func _improve_kind(g: Game, u, t: Vector2i) -> String:
	var saved: Vector2i = u.pos
	u.pos = t
	var out = ""
	if g.improvement[g.idx(t)] == "":
		for k in ["mine", "farm", "trading_post"]:
			if g.can_improve(u, k):
				if k == "trading_post" and g.terrain[g.idx(t)] in [Defs.GRASS, Defs.PLAINS]:
					continue
				out = k
				break
	u.pos = saved
	return out

static func _nearest_own_city(g: Game, u):
	var best = null
	var bd = 999
	for c in g.player_cities(u.owner):
		var d = Hex.distance(u.pos, c.pos)
		if d < bd:
			bd = d
			best = c
	return best

# ---------------------------------------------------------------- military

static func _war_mode(g: Game, pid: int) -> bool:
	if g.turn < GRACE_TURNS + 15:
		return false
	var mil = 0
	for u in g.player_units(pid):
		if not u.is_civilian():
			mil += 1
	var aggression = 1.0 + float((pid * 7919 + g.players.size()) % 5) * 0.25
	return mil * aggression >= g.player_cities(pid).size() * 1.3 + 3

static func _pick_target_city(g: Game, pid: int):
	var cs = g.player_cities(pid)
	if cs.is_empty():
		return null
	var home: Vector2i = cs[0].pos
	var best = null
	var bv = 1e9
	for c in g.cities.values():
		if c.owner == pid:
			continue
		var v = Hex.distance(home, c.pos) * 2.0 + c.hp / 25.0 + c.pop
		if v < bv:
			bv = v
			best = c
	if best != null and Hex.distance(home, best.pos) > 22:
		return null
	return best

static func _military(g: Game, u, submit: Callable, war: bool, target_city) -> void:
	if u.moves <= 0:
		return
	var in_own = g.tile_owner[g.idx(u.pos)] == u.owner
	# 1. Attacks
	var best_t = Vector2i(-1, -1)
	var best_v = 0.0
	var r: int = u.def().range if u.is_ranged() else 1
	for t in g.within(u.pos, r):
		if not g.can_attack(u, t):
			continue
		var tgt_owner = -1
		var tc = g.city_at.get(t)
		var tu = g.military_at(t)
		if tc != null and tc.owner != u.owner:
			tgt_owner = tc.owner
		elif tu != null:
			tgt_owner = tu.owner
		var defensive: bool = g.tile_owner[g.idx(t)] == u.owner or in_own
		if g.turn < GRACE_TURNS and not defensive:
			continue
		if not war and not defensive and g.turn < GRACE_TURNS * 3:
			continue
		var odds = g.combat_odds(u, t)
		if odds.is_empty():
			continue
		var v: float = odds.to_def - odds.to_att * 1.1
		if tu != null and tc == null and odds.to_def >= tu.hp:
			v += 40.0
		if tc != null:
			v += 10.0 if tc.hp < 60 else 0.0
			if not u.is_ranged() and tc.hp > odds.to_def and odds.to_att > u.hp * 0.6:
				continue
		if not u.is_ranged() and odds.to_att >= u.hp:
			continue
		if v > best_v:
			best_v = v
			best_t = t
	if best_t.x >= 0:
		submit.call({"t": "attack", "u": u.id, "target": best_t})
		return
	# 2. Retreat when hurt
	if u.hp < 45:
		var c = _nearest_own_city(g, u)
		if c != null and c.pos != u.pos:
			if submit.call({"t": "move", "u": u.id, "to": c.pos}):
				return
		submit.call({"t": "fortify", "u": u.id})
		return
	# 3. Garrison empty cities
	for c in g.player_cities(u.owner):
		if g.military_at(c.pos) == null and Hex.distance(c.pos, u.pos) <= 6:
			var closer = false
			for o in g.player_units(u.owner):
				if o != u and not o.is_civilian() and Hex.distance(o.pos, c.pos) < Hex.distance(u.pos, c.pos) and o.goto != c.pos:
					closer = true
					break
			if not closer and submit.call({"t": "move", "u": u.id, "to": c.pos}):
				return
	if g.city_at.has(u.pos) and g.city_at[u.pos].owner == u.owner:
		# Keep one defender home; extras may leave in war.
		var stay = true
		if war and target_city != null:
			stay = false
			for o in g.units_at(u.pos):
				pass
			stay = _local_defenders(g, u.pos, u.owner) <= 1
		if stay:
			if not u.fortified:
				submit.call({"t": "fortify", "u": u.id})
			return
	# 4. Scouts explore
	if u.type == "scout" or (g.turn < 25 and u.def()["class"] != "ranged" and g.rng.randf() < 0.3):
		var dest = Vector2i(g.rng.randi() % g.w, g.rng.randi() % g.h)
		for i in 12:
			if g.is_land(dest) and Hex.distance(dest, u.pos) > 4:
				break
			dest = Vector2i(g.rng.randi() % g.w, g.rng.randi() % g.h)
		if submit.call({"t": "move", "u": u.id, "to": dest}):
			return
	# 5. Offensive
	if war and target_city != null:
		var stop_dist = 2 if u.is_ranged() else 1
		var d = Hex.distance(u.pos, target_city.pos)
		if d > stop_dist:
			var dest: Vector2i = target_city.pos
			var best_n = Vector2i(-1, -1)
			var bd = 999
			for t in g.within(target_city.pos, stop_dist):
				if Hex.distance(t, target_city.pos) != stop_dist or not g.is_land(t):
					continue
				var dd = Hex.distance(t, u.pos)
				if dd < bd and g.can_occupy(u, t):
					bd = dd
					best_n = t
			if best_n.x >= 0:
				dest = best_n
			if submit.call({"t": "move", "u": u.id, "to": dest}):
				return
	# 6. Idle: patrol near home border, otherwise fortify.
	if not u.fortified:
		submit.call({"t": "fortify", "u": u.id})
