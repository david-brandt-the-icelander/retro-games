class_name AIController
extends RefCounted
## Utility-scoring AI. Each unit compares "fire now" with "move to the best
## scoring hex (cover, shots available, threats, objectives) then fire".

var g: Node


func _init(game: Node) -> void:
	g = game


func _order(u: Unit) -> int:
	match String(u.d["kind"]):
		"gun":
			return 0
		"team":
			return 1
		"inf":
			return 2
	return 3


func run_turn(side: String) -> void:
	var list: Array[Unit] = []
	for u in g.units:
		if u.alive and u.side == side:
			list.append(u)
	list.sort_custom(func(a: Unit, b: Unit) -> bool: return _order(a) < _order(b))
	for u in list:
		if g.game_over:
			return
		if not u.alive:
			continue
		await _act(u)
		await g.get_tree().create_timer(0.12).timeout


func _enemies(u: Unit) -> Array[Unit]:
	var out: Array[Unit] = []
	for e in g.units:
		if e.alive and e.side != u.side:
			out.append(e)
	return out


func _act(u: Unit) -> void:
	if u.status == "broken":
		if not u.moved:
			var r: Dictionary = g.reachable(u)
			var best: Vector2i = u.hex
			var bs: float = _retreat_score(u, u.hex)
			for h in r["ends"]:
				var s: float = _retreat_score(u, h)
				if s > bs:
					bs = s
					best = h
			if best != u.hex:
				await g.do_move(u, g.build_path(r["prev"], u.hex, best))
		return
	var now: Dictionary = g.best_target(u, u.hex, false)
	if not u.can_move():
		if now["unit"] != null and float(now["ev"]) > 0.04 and u.can_fire():
			await g.do_attack(u, now["unit"], false)
		return
	var plan: Dictionary = _best_move(u)
	var gain: float = float(plan["score"]) - float(plan["stay"])
	var keen: float = 1.2 if u.side == g.attacker_side else 2.5
	if now["unit"] != null and (float(now["ev"]) >= 0.9 or plan["hex"] == u.hex or gain < float(now["ev"]) * keen):
		await g.do_attack(u, now["unit"], false)
		return
	if plan["hex"] != u.hex:
		await g.do_move(u, plan["path"])
		if not u.alive or not u.can_fire():
			return
		var after: Dictionary = g.best_target(u, u.hex, true)
		if after["unit"] != null and float(after["ev"]) > 0.05:
			await g.do_attack(u, after["unit"], false)


func _retreat_score(u: Unit, h: Vector2i) -> float:
	var s: float = g.map.tem(h) * 1.5
	var md := 99
	for e in _enemies(u):
		var dd: int = Hex.distance(e.hex, h)
		md = mini(md, dd)
		if dd <= int(e.d["rng"]) and g.map.los(e.hex, h):
			s -= 1.0
	s += minf(float(md), 6.0) * 0.8
	return s


func _objective_for(u: Unit) -> Dictionary:
	## Returns {"idx": int, "attack": bool, "leash": int}
	var objs: Array = g.map.objectives
	if u.side == g.attacker_side:
		var best := -1
		var bd := 999
		for i in objs.size():
			if objs[i]["owner"] == u.side:
				continue
			var dd: int = Hex.distance(u.hex, objs[i]["hex"])
			if dd < bd:
				bd = dd
				best = i
		if best < 0:
			# all held: guard the nearest one
			for i in objs.size():
				var dd2: int = Hex.distance(u.hex, objs[i]["hex"])
				if dd2 < bd:
					bd = dd2
					best = i
			return {"idx": best, "attack": false, "leash": 1}
		return {"idx": best, "attack": true, "leash": 0}
	# defender
	var a: int = u.anchor if u.anchor >= 0 else 0
	if objs[a]["owner"] != u.side:
		return {"idx": a, "attack": true, "leash": 0}
	if u.is_vehicle():
		var lost := -1
		var ld := 999
		for i in objs.size():
			if objs[i]["owner"] != u.side:
				var dd3: int = Hex.distance(u.hex, objs[i]["hex"])
				if dd3 < ld:
					ld = dd3
					lost = i
		if lost >= 0:
			return {"idx": lost, "attack": true, "leash": 0}
		return {"idx": a, "attack": false, "leash": 3}
	return {"idx": a, "attack": false, "leash": 2}


func _score(u: Unit, h: Vector2i, enemies: Array[Unit], obj: Dictionary) -> float:
	var map: GameMap = g.map
	var s := 0.0
	var tm: int = map.tem(h)
	if u.is_vehicle():
		if map.ttype(h) == GameMap.WOODS:
			s += 0.6
	else:
		s += tm * 1.2
	s += map.elev(h) * 0.2
	var bt: Dictionary = g.best_target(u, h, h != u.hex)
	s += float(bt["ev"]) * 2.0
	for e in enemies:
		var dd: int = Hex.distance(e.hex, h)
		if dd > maxi(int(e.d["rng"]), int(e.d["at_rng"])):
			continue
		if not map.los(e.hex, h):
			continue
		if u.is_vehicle():
			if e.has_at() and dd <= int(e.d["at_rng"]) and Combat.pen_eff(e, dd) >= float(u.d["armor_f"]) * 0.85:
				s -= 1.4
		else:
			var cover_mult: float = 1.0 if tm <= 0 else (0.65 if tm <= 1 else 0.45)
			s -= e.fp() * (0.05 if u.side == g.attacker_side else 0.08) * cover_mult
	if obj["idx"] >= 0:
		var oh: Vector2i = map.objectives[obj["idx"]]["hex"]
		var od: int = Hex.distance(h, oh)
		if obj["attack"]:
			s -= od * 0.75
			if od == 0:
				s += 3.0
		else:
			s -= maxf(0.0, float(od - int(obj["leash"]))) * 1.0
	if h == u.hex:
		s += 0.25
	return s


func _best_move(u: Unit) -> Dictionary:
	var r: Dictionary = g.reachable(u)
	var enemies := _enemies(u)
	var obj := _objective_for(u)
	var stay: float = _score(u, u.hex, enemies, obj)
	var best: Vector2i = u.hex
	var bs: float = stay
	for h in r["ends"]:
		var s: float = _score(u, h, enemies, obj)
		if s > bs:
			bs = s
			best = h
	var path: Array[Vector2i] = []
	if best != u.hex:
		path = g.build_path(r["prev"], u.hex, best)
	return {"hex": best, "score": bs, "stay": stay, "path": path}
