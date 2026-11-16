extends Node
## The Iron Dominion: a build-order AI that expands onto oil, defends its base and
## launches growing attack waves.

var team := 1
const BUILD_ORDER := ["derrick", "barracks", "derrick", "factory", "derrick", "flak", "dock",
	"derrick", "barracks", "flak", "derrick", "factory", "flak", "derrick"]

var think_t := 3.0
var build_idx := 0
var wave_size := 6
var attack_timer := 160.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func _process(delta: float) -> void:
	if Game.game_over:
		return
	attack_timer -= delta
	think_t -= delta
	if think_t > 0.0:
		return
	think_t = 1.0
	_think()


func _think() -> void:
	var buildings := []
	var cons := []
	var army := []
	for e in Game.entities:
		if e.team != team:
			continue
		if e.is_building:
			buildings.append(e)
		elif e.kind == "constructor":
			cons.append(e)
		else:
			army.append(e)
	if buildings.is_empty():
		return
	var hq = Game.get_hq(team)
	var home: Vector3 = hq.position if hq != null else buildings[0].position

	# 1. Keep a crew of constructors.
	var want_cons := 2 if build_idx < 6 else 3
	if hq != null and hq.complete and cons.size() < want_cons and hq.queue.is_empty():
		hq.enqueue("constructor")

	# 2. Finish and repair what we have.
	for b in buildings:
		var needs_work: bool = not b.complete or b.hp < b.max_hp * 0.6
		if needs_work and not _has_builder(b, cons):
			var c = _idle_constructor(cons)
			if c != null:
				c.cmd_build(b)

	# 3. Next structure in the build order.
	var kind := ""
	if build_idx < BUILD_ORDER.size():
		kind = BUILD_ORDER[build_idx]
	else:
		kind = _late_build(buildings)
	if kind != "":
		var cost: int = Game.BUILDINGS[kind]["cost"]
		var c = _idle_constructor(cons)
		if c != null and Game.fuel[team] >= cost:
			var pos = _find_spot(kind, buildings, home)
			if pos != null:
				var site = Game.place_building(team, kind, pos)
				if site != null:
					c.cmd_build(site)
					if build_idx < BUILD_ORDER.size():
						build_idx += 1
			elif build_idx < BUILD_ORDER.size():
				build_idx += 1

	# 4. Production, keeping a reserve for the next structure.
	var reserve := 0.0
	if kind != "" and _idle_constructor(cons) != null:
		reserve = float(Game.BUILDINGS[kind]["cost"]) * 0.6
	var player_air := 0
	for e in Game.entities:
		if e.team == Game.PLAYER and e.is_air:
			player_air += 1
	var mix := {"trooper": 0, "tank": 0, "howitzer": 0, "zeppelin": 0}
	for u in army:
		mix[u.kind] = int(mix.get(u.kind, 0)) + 1
	var producers := {}
	for b in buildings:
		if not b.complete or b.kind == "hq":
			continue
		for k in b.produces():
			mix[k] = int(mix.get(k, 0)) + b.queued(k)
			if not producers.has(k) or b.queue.size() < producers[k].queue.size():
				producers[k] = b
	var want := {"trooper": 0.38, "tank": 0.34, "howitzer": 0.13, "zeppelin": 0.15}
	if player_air > 2:
		want["trooper"] = 0.5
	var total := float(army.size() + 1)
	var best_k := ""
	var best_deficit := -INF
	for k in producers:
		if producers[k].queue.size() >= 2:
			continue
		var deficit: float = float(want.get(k, 0.1)) - float(mix.get(k, 0)) / total
		if deficit > best_deficit:
			best_deficit = deficit
			best_k = k
	if best_k != "":
		var unit_cost := float(Game.UNITS[best_k]["cost"])
		if Game.fuel[team] - unit_cost >= reserve:
			producers[best_k].enqueue(best_k)
		elif Game.fuel[team] > 900.0 and producers.has("trooper") and producers["trooper"].queue.is_empty():
			producers["trooper"].enqueue("trooper")

	# 5. Defend the base.
	var threat = _find_threat(buildings)
	if threat != null:
		var tp: Vector3 = threat.position
		for u in army:
			if u.is_idle() or u.flat_dist_to(home) < 60.0:
				u.cmd_attack_move(tp)
		return

	# 6. Attack in waves.
	if army.size() >= wave_size or (attack_timer <= 0.0 and army.size() >= 4):
		var target = _attack_target(home)
		if target != null:
			var tgt_pos: Vector3 = target.position
			for u in army:
				u.cmd_attack_move(tgt_pos + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
			wave_size = mini(wave_size + 2, 20)
			attack_timer = 100.0
	else:
		# Stragglers far from home keep pushing instead of loitering.
		for u in army:
			if u.is_idle() and u.flat_dist_to(home) > 55.0:
				var t = _attack_target(u.position)
				if t != null:
					u.cmd_attack_move(t.position)


func _has_builder(b, cons: Array) -> bool:
	for c in cons:
		if c.build_target == b:
			return true
	return false


func _idle_constructor(cons: Array):
	for c in cons:
		if c.is_idle():
			return c
	return null


func _choose_unit(building_kind: String, player_air: int) -> String:
	match building_kind:
		"barracks":
			return "trooper"
		"factory":
			return "tank" if rng.randf() < 0.65 else "howitzer"
		"dock":
			return "zeppelin"
	return "trooper" if player_air > 2 else "tank"


func _late_build(buildings: Array) -> String:
	if Game.fuel[team] < 450.0:
		return ""
	var counts := {}
	for b in buildings:
		counts[b.kind] = int(counts.get(b.kind, 0)) + 1
	if _find_spot("derrick", buildings, buildings[0].position) != null:
		return "derrick"
	if int(counts.get("flak", 0)) < 5:
		return "flak"
	if int(counts.get("factory", 0)) < 2:
		return "factory"
	if int(counts.get("dock", 0)) < 2:
		return "dock"
	return ""


func _find_spot(kind: String, buildings: Array, home: Vector3):
	if kind == "derrick":
		var best = null
		var best_d := INF
		for w in Game.wells:
			if Game.alive(w["owner"]):
				continue
			var wp: Vector3 = w["pos"]
			var p = Game.placement_pos(team, "derrick", wp)
			if p == null:
				continue
			var d := home.distance_to(wp)
			if d < best_d:
				best_d = d
				best = p
		return best
	var toward_center := (-home).normalized()
	for attempt in 40:
		var anchor = buildings[rng.randi() % buildings.size()]
		var ap: Vector3 = anchor.position
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(10.0, 24.0)
		var p := ap + Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)
		if kind == "flak":
			p += toward_center * 8.0
		var r = Game.placement_pos(team, kind, p)
		if r != null:
			return r
	return null


func _find_threat(buildings: Array):
	var best = null
	var best_d := INF
	for e in Game.entities:
		if e.team == team or e.is_building or e.dead:
			continue
		var ep: Vector3 = e.position
		for b in buildings:
			var bp: Vector3 = b.position
			var d := Vector2(ep.x - bp.x, ep.z - bp.z).length()
			if d < 38.0 and d < best_d:
				best_d = d
				best = e
	return best


func _attack_target(from: Vector3):
	var best = null
	var best_d := INF
	for e in Game.entities:
		if e.team == team or e.dead:
			continue
		var d: float = from.distance_to(e.position)
		if not e.is_building:
			d += 40.0
		if d < best_d:
			best_d = d
			best = e
	return best
