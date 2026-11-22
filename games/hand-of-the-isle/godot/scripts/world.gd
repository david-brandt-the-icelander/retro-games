class_name World
extends Node3D
## The simulation: settlements, walkers, combat, faith and divine powers.
## Both deities (team 0 = player, team 1 = rival) go through the same rules.

signal message(text: String, team: int)
signal game_over(winner: int)

enum { SETTLE, GATHER, CRUSADE }

const MANA_MAX := 1500.0
const WALKER_CAP := 36
const POWERS := [
	{"id": "sculpt", "name": "Sculpt", "cost": 1, "radius": 0.0,
		"desc": "Left-click raises land, right-click lowers it. Flat land lets your people build bigger homes. Only works inside your influence (the bright area)."},
	{"id": "beacon", "name": "Beacon", "cost": 10, "radius": 0.0,
		"desc": "Plant a rally point. In Gather mode your walkers march here and merge into one strong band."},
	{"id": "quake", "name": "Earthquake", "cost": 120, "radius": 4.0,
		"desc": "Shake the ground in a wide area, toppling buildings that lose their flat footing."},
	{"id": "swamp", "name": "Swamp", "cost": 170, "radius": 3.0,
		"desc": "Sow swamps on flat ground. Any walker that steps in sinks. Reshaping the land clears it."},
	{"id": "champion", "name": "Champion", "cost": 260, "radius": 0.0,
		"desc": "Anoint your strongest walker as a haloed champion who hunts the enemy without rest."},
	{"id": "volcano", "name": "Volcano", "cost": 460, "radius": 5.0,
		"desc": "Thrust a smoking mountain out of the earth, strewn with rock that nobody can build on."},
	{"id": "flood", "name": "Flood", "cost": 720, "radius": 0.0,
		"desc": "Raise the sea by one step across the whole world. Low-lying homes drown, yours included."},
	{"id": "armageddon", "name": "Armageddon", "cost": 1200, "radius": 0.0,
		"desc": "Empty every home on the island and march both peoples to a final battle."},
]

var terrain := Terrain.new()
var walkers: Array[Walker] = []
var settlements: Array[Settlement] = []
var claim := {}                       # Vector2i -> Settlement
var mana := [60.0, 60.0]
var behavior := [SETTLE, SETTLE]
var beacon: Array = [null, null]      # Vector2 or null per team
var armageddon := false
var finished := false
var elapsed := 0.0
var stats := [{}, {}]

var _units := Node3D.new()
var _fx := Node3D.new()
var _beacon_nodes: Array[Node3D] = []
var _terrain_changed := true
var _tier_t := 0.0
var _inf_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_child(terrain)
	add_child(_units)
	add_child(_fx)
	for t in 2:
		_beacon_nodes.append(_make_beacon(t))


func start(seed_value: int) -> void:
	_rng.seed = seed_value
	for i in 20:
		terrain.generate(seed_value + i * 7919)
		var a := _find_start(Vector2i(10, 24))
		var b := _find_start(Vector2i(38, 24))
		if a.x >= 0 and b.x >= 0:
			for k in 4:
				_spawn(0, 3, _near_land(a, 2))
				_spawn(1, 3, _near_land(b, 2))
			_recompute_influence()
			return
	push_error("Could not generate a playable island")


func _find_start(c: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var best_d := 1e9
	for z in range(4, Terrain.N - 4):
		for x in range(c.x - 8, c.x + 9):
			var t := Vector2i(x, z)
			if terrain.tile_buildable(t):
				var d := Vector2(t - c).length()
				if d < best_d:
					best_d = d
					best = t
	return best


func _near_land(t: Vector2i, r: int) -> Vector2:
	for i in 30:
		var q := t + Vector2i(_rng.randi_range(-r, r), _rng.randi_range(-r, r))
		if terrain.in_tiles(q) and not terrain.tile_water(q):
			return Vector2(q) + Vector2(0.5, 0.5)
	return Vector2(t) + Vector2(0.5, 0.5)


# ------------------------------------------------------------------ queries
func team_total(team: int) -> int:
	var n := 0
	for w in walkers:
		if w.team == team:
			n += w.strength
	for s in settlements:
		if s.team == team:
			n += int(s.pop)
	return n


func count_of(team: int) -> Vector2i:
	var w := 0
	var s := 0
	for x in walkers:
		w += int(x.team == team)
	for x in settlements:
		s += int(x.team == team)
	return Vector2i(w, s)


func can_afford(team: int, cost: float) -> bool:
	return mana[team] >= cost


func power_index(id: String) -> int:
	for i in POWERS.size():
		if POWERS[i].id == id:
			return i
	return -1


# --------------------------------------------------------------- simulation
func step(dt: float) -> void:
	if finished:
		return
	elapsed += dt
	for t in 2:
		var pop := 0.0
		for s in settlements:
			if s.team == t:
				pop += s.pop * (0.6 + 0.4 * s.tier)
		mana[t] = minf(MANA_MAX, mana[t] + dt * (0.5 + pop * 0.022))
	_tier_t -= dt
	if _terrain_changed or _tier_t <= 0.0:
		_tier_t = 1.0
		_terrain_changed = false
		_reevaluate_settlements()
	for s in settlements.duplicate():
		_grow(s, dt)
	for w in walkers.duplicate():
		if is_instance_valid(w) and w.strength > 0:
			_update_walker(w, dt)
	_resolve_fights(dt)
	_inf_t -= dt
	if _inf_t <= 0.0:
		_inf_t = 0.4
		_recompute_influence()
	_update_beacons()
	_check_victory()


func animate(delta: float) -> void:
	for w in walkers:
		w.animate(delta, terrain)


func _grow(s: Settlement, dt: float) -> void:
	if s.foe_count > 0:
		return
	var cap := s.capacity()
	if s.pop < cap:
		s.pop = minf(cap, s.pop + dt * (0.08 * s.tier + 0.022 * s.pop))
	elif cap > 0 and count_of(s.team).x < WALKER_CAP:
		var leave := int(cap * 0.5)
		var spot := _exit_spot(s)
		if spot.x >= 0.0 and leave > 0:
			s.pop -= leave
			var w := _spawn(s.team, leave, spot)
			w.think = 0.6
	s.refresh()


func _exit_spot(s: Settlement) -> Vector2:
	var r := s.radius() + 1
	for i in 12:
		var a := _rng.randf() * TAU
		var q := Vector2(s.tile) + Vector2(0.5, 0.5) + Vector2(cos(a), sin(a)) * (r + 0.2)
		var t := Vector2i(floor(q.x), floor(q.y))
		if terrain.in_tiles(t) and not terrain.tile_water(t) and not terrain.blight.has(t):
			return q
	return Vector2(-1, -1)


func _reevaluate_settlements() -> void:
	for s in settlements.duplicate():
		var tier := _eval_tier(s)
		if tier == 0:
			var drowned := terrain.tile_water(s.tile)
			var survivors := 0 if drowned else int(ceil(s.pop * 0.5))
			_destroy_settlement(s, "flood" if drowned else "collapse")
			if survivors > 0:
				_spawn(s.team, survivors, Vector2(s.tile) + Vector2(0.5, 0.5))
		elif tier != s.tier:
			_unclaim(s)
			s.set_tier(tier)
			_claim(s)
			s.pop = minf(s.pop, s.capacity())


func _eval_tier(s: Settlement) -> int:
	if not terrain.tile_buildable(s.tile) or terrain.tile_min(s.tile) != s.base_h:
		return 0
	for r in [2, 1]:
		if _area_ok(s.tile, r, s.base_h, s):
			return r + 1
	return 1


func _area_ok(c: Vector2i, r: int, hh: int, owner: Settlement) -> bool:
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := c + Vector2i(dx, dz)
			if not terrain.tile_buildable(t) or terrain.tile_min(t) != hh:
				return false
			var o: Settlement = claim.get(t)
			if o != null and o != owner:
				return false
	return true


func _claim(s: Settlement) -> void:
	var r := s.radius()
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			claim[s.tile + Vector2i(dx, dz)] = s


func _unclaim(s: Settlement) -> void:
	var r := s.radius()
	for dz in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var t := s.tile + Vector2i(dx, dz)
			if claim.get(t) == s:
				claim.erase(t)


func can_found(t: Vector2i) -> bool:
	if not terrain.tile_buildable(t):
		return false
	for dz in range(-2, 3):
		for dx in range(-2, 3):
			if claim.has(t + Vector2i(dx, dz)):
				return false
	return true


func _found(team: int, t: Vector2i, people: int) -> Settlement:
	var s := Settlement.new().setup(team, t, people, terrain.tile_min(t))
	settlements.append(s)
	_units.add_child(s)
	_claim(s)
	var tier := _eval_tier(s)
	if tier > 1:
		_unclaim(s)
		s.set_tier(tier)
		_claim(s)
	s.pop = minf(s.pop, s.capacity())
	return s


func _destroy_settlement(s: Settlement, cause: String) -> void:
	_unclaim(s)
	settlements.erase(s)
	var p := s.position + Vector3(0, 0.5, 0)
	match cause:
		"flood":
			burst(p, Color(0.6, 0.85, 1.0), 40, 1.5)
		"siege":
			burst(p, Color(1.0, 0.5, 0.15), 60, 2.0)
			burst(p + Vector3(0, 0.6, 0), Color(0.25, 0.25, 0.25), 30, 1.0)
		_:
			burst(p, Color(0.7, 0.6, 0.45), 40, 1.6)
	for w in walkers:
		if w.foe == s:
			w.foe = null
	s.queue_free()


# ------------------------------------------------------------------ walkers
func _spawn(team: int, strength: int, p: Vector2) -> Walker:
	var w := Walker.new().setup(team, strength, p)
	walkers.append(w)
	_units.add_child(w)
	w.position = terrain.world_pos(p)
	return w


func kill_walker(w: Walker, cause := "") -> void:
	if not walkers.has(w):
		return
	walkers.erase(w)
	match cause:
		"drown":
			burst(w.position + Vector3(0, 0.2, 0), Color(0.7, 0.9, 1.0), 18, 0.8)
		"swamp":
			burst(w.position + Vector3(0, 0.2, 0), Color(0.35, 0.4, 0.15), 18, 0.7)
		"battle":
			burst(w.position + Vector3(0, 0.4, 0), Walker.team_color(w.team), 16, 0.9)
	for o in walkers:
		if o.foe == w:
			o.foe = null
	w.queue_free()


func _mode(w: Walker) -> int:
	if armageddon or w.champion:
		return CRUSADE
	var m: int = behavior[w.team]
	if m == GATHER and beacon[w.team] == null:
		return SETTLE
	return m


func _update_walker(w: Walker, dt: float) -> void:
	var t := Vector2i(floor(w.gp.x), floor(w.gp.y))
	if terrain.tile_water(t):
		kill_walker(w, "drown")
		return
	if terrain.blight.get(t, 0) == Terrain.BLIGHT_SWAMP and not w.champion:
		kill_walker(w, "swamp")
		return
	if w.foe != null:
		w.moving = false
		return
	w.think -= dt
	if w.think <= 0.0:
		w.think = _rng.randf_range(0.3, 0.55)
		_decide(w, t)
		if not walkers.has(w) or w.foe != null:
			return
	var d := w.target - w.gp
	var len := d.length()
	if len < 0.05:
		w.moving = false
		return
	var here := terrain.height_at(w.gp)
	var speed := (1.9 if w.champion else 1.45) * (1.6 if armageddon else 1.0)
	var np := w.gp + d / len * minf(len, speed * dt)
	var slope := absf(terrain.height_at(np) - here) / maxf(0.001, speed * dt)
	np = w.gp + d / len * minf(len, speed * dt / (1.0 + slope * 0.8))
	var nt := Vector2i(floor(np.x), floor(np.y))
	if nt != t and terrain.tile_water(nt):
		w.target = w.gp
		w.moving = false
		w.think = 0.0
		return
	w.gp = np
	w.moving = true


func _decide(w: Walker, t: Vector2i) -> void:
	var foe := _enemy_walker_near(w, 0.75)
	if foe:
		_engage(w, foe)
		return
	var s: Settlement = claim.get(t)
	if s != null and s.team != w.team:
		_engage(w, s)
		return
	var mode := _mode(w)
	if mode == GATHER:
		var b: Vector2 = beacon[w.team]
		w.target = b + Vector2(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.3, 0.3))
		if w.gp.distance_to(b) < 1.4:
			for o in walkers.duplicate():
				if o != w and o.team == w.team and o.foe == null and not o.champion \
						and o.gp.distance_to(w.gp) < 0.7:
					w.strength += o.strength
					walkers.erase(o)
					o.queue_free()
			w.refresh()
		return
	if mode == CRUSADE:
		var goal := _nearest_enemy(w)
		if goal.x >= 0.0:
			w.target = goal
			return
	# SETTLE (also the fallback when a crusade has nothing left to hunt)
	if s != null and s.team == w.team and s.pop < s.capacity():
		var take := mini(w.strength, int(ceil(s.capacity() - s.pop)))
		s.pop += take
		w.strength -= take
		s.refresh()
		if w.strength <= 0:
			walkers.erase(w)
			w.queue_free()
			return
		w.refresh()
	elif s == null and can_found(t) and not armageddon:
		var ns := _found(w.team, t, w.strength)
		var left := w.strength - int(ns.pop)
		if left <= 0:
			walkers.erase(w)
			w.queue_free()
			return
		w.strength = left
		w.refresh()
	w.target = _find_site(w, t)


func _find_site(w: Walker, t: Vector2i) -> Vector2:
	var best := Vector2(-1, -1)
	var best_d := 1e9
	for i in 26:
		var q := t + Vector2i(_rng.randi_range(-7, 7), _rng.randi_range(-7, 7))
		var ok := can_found(q)
		if not ok:
			var o: Settlement = claim.get(q)
			ok = o != null and o.team == w.team and o.pop < o.capacity() - 0.5
		if ok:
			var d := Vector2(q - t).length()
			if d < best_d:
				best_d = d
				best = Vector2(q) + Vector2(0.5, 0.5)
	if best.x >= 0.0:
		return best
	for i in 10:
		var q := t + Vector2i(_rng.randi_range(-5, 5), _rng.randi_range(-5, 5))
		if terrain.in_tiles(q) and not terrain.tile_water(q):
			return Vector2(q) + Vector2(_rng.randf_range(0.2, 0.8), _rng.randf_range(0.2, 0.8))
	return w.gp


func _enemy_walker_near(w: Walker, r: float) -> Walker:
	for o in walkers:
		if o.team != w.team and o.gp.distance_squared_to(w.gp) < r * r:
			return o
	return null


func _nearest_enemy(w: Walker) -> Vector2:
	var best := Vector2(-1, -1)
	var bd := 1e9
	for s in settlements:
		if s.team != w.team:
			var p := Vector2(s.tile) + Vector2(0.5, 0.5)
			var d := p.distance_squared_to(w.gp)
			if d < bd:
				bd = d
				best = p
	for o in walkers:
		if o.team != w.team:
			var d := o.gp.distance_squared_to(w.gp)
			if d < bd:
				bd = d
				best = o.gp
	return best


# ------------------------------------------------------------------- combat
func _engage(w: Walker, foe: Node3D) -> void:
	w.foe = foe
	w.hit_t = 0.35
	if foe is Walker:
		var o := foe as Walker
		if o.foe == null:
			o.foe = w
			o.hit_t = 0.35
	elif foe is Settlement:
		(foe as Settlement).foe_count += 1


func _resolve_fights(dt: float) -> void:
	for s in settlements:
		s.foe_count = 0
	for w in walkers.duplicate():
		if not walkers.has(w) or w.foe == null:
			continue
		if not is_instance_valid(w.foe) or (w.foe is Walker and not walkers.has(w.foe)) \
				or (w.foe is Settlement and not settlements.has(w.foe)):
			w.foe = null
			continue
		if w.foe is Settlement:
			(w.foe as Settlement).foe_count += 1
		w.hit_t -= dt
		if w.hit_t > 0.0:
			continue
		w.hit_t = 0.45
		var mult := 3.0 if w.champion else 1.0
		if w.foe is Walker:
			var o := w.foe as Walker
			var omult := 3.0 if o.champion else 1.0
			var dmg_o := maxi(1, int(round(w.strength * 0.3 * mult * _rng.randf_range(0.7, 1.3))))
			var dmg_w := maxi(1, int(round(o.strength * 0.3 * omult * _rng.randf_range(0.7, 1.3))))
			o.strength -= dmg_o
			w.strength -= dmg_w
			burst((w.position + o.position) * 0.5 + Vector3(0, 0.4, 0), Color(1, 0.9, 0.6), 6, 0.5)
			o.refresh()
			w.refresh()
			if o.strength <= 0:
				stats[w.team]["kills"] = stats[w.team].get("kills", 0) + 1
				kill_walker(o, "battle")
			if w.strength <= 0:
				stats[o.team]["kills"] = stats[o.team].get("kills", 0) + 1
				kill_walker(w, "battle")
		else:
			var s := w.foe as Settlement
			var dmg := maxf(1.0, w.strength * 0.3 * mult)
			var def := maxi(1, int(round((s.pop * 0.18 + s.tier) * _rng.randf_range(0.7, 1.3) / mult)))
			s.pop -= dmg
			w.strength -= def
			burst(s.position + Vector3(0, 0.6, 0), Color(1.0, 0.55, 0.2), 8, 0.6)
			s.refresh()
			w.refresh()
			if s.pop <= 0.0:
				stats[w.team]["razed"] = stats[w.team].get("razed", 0) + 1
				if s.team == 0:
					message.emit("A %s of yours has fallen!" % Settlement.NAMES[s.tier].to_lower(), 0)
				_destroy_settlement(s, "siege")
			if w.strength <= 0:
				kill_walker(w, "battle")


# ---------------------------------------------------------------- influence
func _recompute_influence() -> void:
	var n := Terrain.N
	var inf := PackedByteArray()
	inf.resize(n * n)
	for s in settlements:
		_paint(inf, s.tile, 4 + s.tier * 2, s.team)
	for w in walkers:
		_paint(inf, Vector2i(floor(w.gp.x), floor(w.gp.y)), 4 if w.champion else 3, w.team)
	if inf != terrain.influence:
		terrain.set_influence(inf)


func _paint(inf: PackedByteArray, c: Vector2i, r: int, team: int) -> void:
	var bit := 1 << team
	var n := Terrain.N
	for z in range(maxi(0, c.y - r), mini(n, c.y + r + 1)):
		for x in range(maxi(0, c.x - r), mini(n, c.x + r + 1)):
			if (x - c.x) * (x - c.x) + (z - c.y) * (z - c.y) <= r * r:
				inf[z * n + x] |= bit


func vertex_in_influence(v: Vector2i, team: int) -> bool:
	for t in [v, v - Vector2i(1, 0), v - Vector2i(0, 1), v - Vector2i(1, 1)]:
		if terrain.has_influence(t, team):
			return true
	return false


# ---------------------------------------------------------- beacons and end
func _make_beacon(team: int) -> Node3D:
	var n := Node3D.new()
	var pillar := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.18
	c.height = 3.0
	pillar.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Walker.team_color(team)
	m.albedo_color.a = 0.55
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Walker.team_color(team)
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar.material_override = m
	pillar.position.y = 1.5
	pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(pillar)
	var orb := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.56
	orb.mesh = sm
	orb.material_override = Walker.mat("orb%d" % team, Walker.team_color(team).lightened(0.3), 4.0)
	orb.position.y = 3.2
	n.add_child(orb)
	n.visible = false
	add_child(n)
	return n


func _update_beacons() -> void:
	for t in 2:
		var b = beacon[t]
		_beacon_nodes[t].visible = b != null
		if b != null:
			_beacon_nodes[t].position = terrain.world_pos(b)
			_beacon_nodes[t].rotation.y += 0.02


func _check_victory() -> void:
	if elapsed < 5.0:
		return
	var alive := [team_total(0) > 0, team_total(1) > 0]
	if alive[0] and alive[1]:
		return
	finished = true
	game_over.emit(0 if alive[0] else 1)


# ------------------------------------------------------------------- powers
## Cast power `i` for `team` at world point `p`. Returns "" on success,
## otherwise the reason it failed.
func cast(team: int, i: int, p: Vector3, alt := false) -> String:
	var pw: Dictionary = POWERS[i]
	if finished:
		return "The world is at rest."
	if mana[team] < pw.cost:
		return "Not enough faith for %s." % pw.name
	var g := Vector2(p.x, p.z)
	var tile := Vector2i(floor(g.x), floor(g.y))
	match pw.id:
		"sculpt":
			var v := Vector2i(roundi(g.x), roundi(g.y))
			if not vertex_in_influence(v, team):
				return "Beyond your influence."
			var ok := terrain.lower_vertex(v.x, v.y) if alt else terrain.raise_vertex(v.x, v.y)
			if not ok:
				return "The land will go no further."
			_terrain_changed = true
		"beacon":
			if terrain.tile_water(tile):
				return "A beacon needs dry land."
			beacon[team] = g
		"quake":
			_quake(g, pw.radius)
		"swamp":
			if not _swamp(g, pw.radius):
				return "No flat ground to sour there."
		"champion":
			if not _champion(team):
				return "You have no walker worthy of it."
		"volcano":
			_volcano(g, pw.radius)
		"flood":
			if terrain.water_level >= 6:
				return "The seas can rise no higher."
			terrain.water_level += 1
			terrain.dirty = true
			_terrain_changed = true
			shake.emit(1.0)
		"armageddon":
			_armageddon()
	mana[team] -= pw.cost
	if pw.cost >= 100:
		var who := "You call" if team == 0 else "The rival calls"
		message.emit("%s down %s." % [who, pw.name.to_upper()], team)
	return ""


signal shake(amount: float)


func _quake(c: Vector2, r: float) -> void:
	for i in 70:
		var a := _rng.randf() * TAU
		var d := sqrt(_rng.randf()) * r
		var v := Vector2i(roundi(c.x + cos(a) * d), roundi(c.y + sin(a) * d))
		if _rng.randf() < 0.55:
			terrain.lower_vertex(v.x, v.y)
		else:
			terrain.raise_vertex(v.x, v.y)
	_terrain_changed = true
	for i in 6:
		var q := c + Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))
		burst(terrain.world_pos(q) + Vector3(0, 0.3, 0), Color(0.62, 0.5, 0.38), 30, 1.8)
	shake.emit(1.2)


func _swamp(c: Vector2, r: float) -> bool:
	var placed := 0
	var ri := int(ceil(r))
	for dz in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var t := Vector2i(floor(c.x) + dx, floor(c.y) + dz)
			if Vector2(dx, dz).length() > r or not terrain.tile_buildable(t):
				continue
			if claim.has(t) or _rng.randf() < 0.35:
				continue
			terrain.blight[t] = Terrain.BLIGHT_SWAMP
			placed += 1
			burst(terrain.world_pos(Vector2(t) + Vector2(0.5, 0.5)), Color(0.4, 0.45, 0.15), 8, 0.6)
	if placed > 0:
		terrain.dirty = true
	return placed > 0


func _champion(team: int) -> bool:
	var best: Walker = null
	for w in walkers:
		if w.team == team and not w.champion and (best == null or w.strength > best.strength):
			best = w
	if best == null:
		var home: Settlement = null
		for s in settlements:
			if s.team == team and (home == null or s.pop > home.pop):
				home = s
		if home == null or home.pop < 2:
			return false
		var spot := _exit_spot(home)
		if spot.x < 0.0:
			return false
		var n := int(home.pop * 0.5)
		home.pop -= n
		best = _spawn(team, n, spot)
	best.strength = best.strength * 2 + 10
	best.make_champion()
	burst(best.position + Vector3(0, 0.6, 0), Color(1, 0.85, 0.35), 50, 1.2)
	return true


func _volcano(c: Vector2, r: float) -> void:
	var v := Vector2i(roundi(c.x), roundi(c.y))
	for k in 6:
		var rr := r * (1.0 - k / 6.0)
		var ri := int(ceil(rr))
		for dz in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				if Vector2(dx, dz).length() <= rr:
					terrain.raise_vertex(v.x + dx, v.y + dz)
	for dz in range(-3, 3):
		for dx in range(-3, 3):
			var t := v + Vector2i(dx, dz)
			if terrain.in_tiles(t) and _rng.randf() < 0.65:
				terrain.blight[t] = Terrain.BLIGHT_ROCK
	_terrain_changed = true
	var top := terrain.world_pos(Vector2(v)) + Vector3(0, 3.0, 0)
	burst(top, Color(1.0, 0.45, 0.1), 120, 3.0, 2.2)
	burst(top + Vector3(0, 1, 0), Color(0.2, 0.2, 0.22), 80, 2.0, 3.0)
	shake.emit(1.6)


func _armageddon() -> void:
	armageddon = true
	for s in settlements.duplicate():
		var n := int(s.pop)
		var p := Vector2(s.tile) + Vector2(0.5, 0.5)
		_destroy_settlement(s, "collapse")
		if n > 0:
			_spawn(s.team, n, p)
	shake.emit(2.0)


# ------------------------------------------------------------------ effects
func burst(p: Vector3, col: Color, amount: int, spread: float, life := 1.0) -> void:
	if amount <= 0 or not is_inside_tree():
		return
	var ps := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.06
	sm.height = 0.12
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = col.v > 0.8
	m.emission = col
	m.vertex_color_use_as_albedo = true
	sm.material = m
	ps.mesh = sm
	ps.amount = amount
	ps.one_shot = true
	ps.explosiveness = 0.9
	ps.lifetime = life
	ps.direction = Vector3.UP
	ps.spread = 70.0
	ps.initial_velocity_min = spread * 1.2
	ps.initial_velocity_max = spread * 2.6
	ps.gravity = Vector3(0, -6.0, 0)
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	ps.scale_amount_curve = curve
	ps.position = p
	_fx.add_child(ps)
	ps.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(ps.queue_free)
