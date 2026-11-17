class_name Game
extends Node
## Authoritative game state + rules.
##
## Networking model: clients send *commands*; the host validates a command,
## resolves any randomness and turns it into one or more *events*.  Every peer
## (host included) applies the same events in the same order with no
## randomness, so all game states stay identical.

signal event_applied(ev: Dictionary)
signal notify(pid: int, text: String, pos: Vector2i)
signal game_over(winner: int, kind: String)

const Unit = GameTypes.Unit
const City = GameTypes.City
const Player = GameTypes.Player

var w := 0
var h := 0
var terrain := PackedByteArray()
var hills := PackedByteArray()
var forest := PackedByteArray()
var resource: Array = []
var improvement: Array = []
var tile_owner := PackedInt32Array()

var players: Array = []
var units: Dictionary = {}      ## id -> Unit
var cities: Dictionary = {}     ## id -> City
var city_at: Dictionary = {}    ## Vector2i -> City
var turn := 1
var next_id := 1
var finished := false
var winner := -1

var rng := RandomNumberGenerator.new()  ## host only

# ---------------------------------------------------------------- setup

func setup_from_dict(d: Dictionary) -> void:
	w = d.w
	h = d.h
	terrain = d.terrain
	hills = d.hills
	forest = d.forest
	resource = d.resource.duplicate()
	improvement = []
	improvement.resize(w * h)
	improvement.fill("")
	tile_owner = PackedInt32Array()
	tile_owner.resize(w * h)
	tile_owner.fill(-1)
	players.clear()
	for pd in d.players:
		var p := Player.new()
		p.id = pd.id
		p.name = pd.name
		p.civ = pd.civ
		p.color = Defs.PLAYER_COLORS[pd.color]
		p.peer_id = pd.peer
		p.human = pd.peer != 0
		p.gold = 10
		players.append(p)
	for s in d.starts:
		_spawn_unit("settler", s.p, s.pos)
		var near := _free_land_near(s.pos, "warrior")
		_spawn_unit("warrior", s.p, near)
		var near2 := _free_land_near(s.pos, "scout")
		_spawn_unit("scout", s.p, near2)
	for p in players:
		p.research = ""

# ---------------------------------------------------------------- tiles

func idx(c: Vector2i) -> int:
	return c.y * w + c.x

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h

func neighbors(c: Vector2i) -> Array:
	var out := []
	for n in Hex.neighbors(c):
		if in_bounds(n):
			out.append(n)
	return out

func within(c: Vector2i, r: int) -> Array:
	var out := []
	for n in Hex.ring(c, r):
		if in_bounds(n):
			out.append(n)
	return out

func t_of(c: Vector2i) -> int:
	return terrain[idx(c)]

func is_water(c: Vector2i) -> bool:
	return Defs.TERRAIN[terrain[idx(c)]].water

func is_land(c: Vector2i) -> bool:
	return not is_water(c) and terrain[idx(c)] != Defs.MOUNTAIN

func tile_yield(c: Vector2i, pid: int = -1) -> Vector3i:
	var i := idx(c)
	var t: Dictionary = Defs.TERRAIN[terrain[i]]
	var f: int = t.food
	var p: int = t.prod
	var g: int = t.gold
	if hills[i] == 1:
		f = 0
		p = 2
	if forest[i] == 1:
		f = 1
		p = 2
	var r: String = resource[i]
	if r != "":
		f += Defs.RESOURCES[r].food
		p += Defs.RESOURCES[r].prod
		g += Defs.RESOURCES[r].gold
	var imp: String = improvement[i]
	if imp != "":
		f += Defs.IMPROVEMENTS[imp].food
		p += Defs.IMPROVEMENTS[imp].prod
		g += Defs.IMPROVEMENTS[imp].gold
	return Vector3i(f, p, g)

func units_at(c: Vector2i) -> Array:
	var out := []
	for u in units.values():
		if u.pos == c:
			out.append(u)
	return out

func military_at(c: Vector2i) -> Unit:
	for u in units.values():
		if u.pos == c and not u.is_civilian():
			return u
	return null

func civilian_at(c: Vector2i) -> Unit:
	for u in units.values():
		if u.pos == c and u.is_civilian():
			return u
	return null

func player(pid: int) -> Player:
	return players[pid]

func player_cities(pid: int) -> Array:
	var out := []
	for c in cities.values():
		if c.owner == pid:
			out.append(c)
	return out

func player_units(pid: int) -> Array:
	var out := []
	for u in units.values():
		if u.owner == pid:
			out.append(u)
	return out

# ---------------------------------------------------------------- movement

func move_cost(u: Unit, to: Vector2i) -> int:
	if not in_bounds(to):
		return -1
	var t := t_of(to)
	if t == Defs.MOUNTAIN or Defs.TERRAIN[t].water:
		return -1
	var i := idx(to)
	if hills[i] == 1 or forest[i] == 1:
		return 2
	return 1

func build_occ() -> Dictionary:
	var occ := {}
	for o in units.values():
		if occ.has(o.pos):
			occ[o.pos].append(o)
		else:
			occ[o.pos] = [o]
	return occ

## Can unit u stand on tile c at the end of a step?
func can_occupy(u: Unit, c: Vector2i, occ = null) -> bool:
	var city: City = city_at.get(c)
	if city != null and city.owner != u.owner:
		return false
	var list: Array = (occ.get(c, []) if occ != null else units_at(c))
	for o in list:
		if o == u:
			continue
		if o.owner != u.owner:
			return false
		if o.is_civilian() == u.is_civilian():
			return false
	return true

## Can unit u pass through tile c (not ending there)?
func can_pass(u: Unit, c: Vector2i, occ = null) -> bool:
	var city: City = city_at.get(c)
	if city != null and city.owner != u.owner:
		return false
	var list: Array = (occ.get(c, []) if occ != null else units_at(c))
	for o in list:
		if o.owner != u.owner:
			return false
	return true

## A* path (excluding start). Empty if unreachable.
func find_path(u: Unit, target: Vector2i, max_iter: int = 4000) -> Array:
	if not in_bounds(target) or target == u.pos:
		return []
	if move_cost(u, target) < 0:
		return []
	var occ := build_occ()
	var heap_f: Array = []
	var heap_n: Array = []
	var came := {}
	var g := {u.pos: 0}
	var closed := {}
	_heap_push(heap_f, heap_n, 0.0, u.pos)
	var iterations := 0
	while heap_n.size() > 0:
		iterations += 1
		if iterations > max_iter:
			break
		var cur: Vector2i = _heap_pop(heap_f, heap_n)
		if closed.has(cur):
			continue
		if cur == target:
			var path := [cur]
			while came.has(cur):
				cur = came[cur]
				if cur != u.pos:
					path.push_front(cur)
			return path
		closed[cur] = true
		for n in neighbors(cur):
			if closed.has(n):
				continue
			var c := move_cost(u, n)
			if c < 0:
				continue
			if n != target and not can_pass(u, n, occ):
				continue
			if n == target and not can_occupy(u, n, occ):
				continue
			var ng: int = g[cur] + c
			if not g.has(n) or ng < g[n]:
				g[n] = ng
				came[n] = cur
				_heap_push(heap_f, heap_n, ng + Hex.distance(n, target) * 1.01, n)
	return []

static func _heap_push(f: Array, n: Array, pri: float, item: Vector2i) -> void:
	f.append(pri)
	n.append(item)
	var i := f.size() - 1
	while i > 0:
		var parent := (i - 1) >> 1
		if f[parent] <= f[i]:
			break
		var tf = f[parent]; f[parent] = f[i]; f[i] = tf
		var tn = n[parent]; n[parent] = n[i]; n[i] = tn
		i = parent

static func _heap_pop(f: Array, n: Array) -> Vector2i:
	var top: Vector2i = n[0]
	var last := f.size() - 1
	f[0] = f[last]
	n[0] = n[last]
	f.resize(last)
	n.resize(last)
	var i := 0
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < last and f[l] < f[m]:
			m = l
		if r < last and f[r] < f[m]:
			m = r
		if m == i:
			break
		var tf = f[m]; f[m] = f[i]; f[i] = tf
		var tn = n[m]; n[m] = n[i]; n[i] = tn
		i = m
	return top

## Tiles reachable this turn: pos -> remaining moves.
func reachable(u: Unit) -> Dictionary:
	var out := {}
	if u.moves <= 0:
		return out
	var occ := build_occ()
	var best := {u.pos: u.moves}
	var frontier := [u.pos]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var left: int = best[cur]
		if left <= 0:
			continue
		for n in neighbors(cur):
			var c := move_cost(u, n)
			if c < 0 or not can_pass(u, n, occ):
				continue
			var rem := maxi(0, left - c)
			if not best.has(n) or best[n] < rem:
				best[n] = rem
				frontier.append(n)
	for k in best:
		if k != u.pos and can_occupy(u, k, occ):
			out[k] = best[k]
	return out

## Split a path into steps actually walkable this turn (a unit may always
## enter a tile while having any moves left).
func walkable_prefix(u: Unit, path: Array) -> Array:
	var out := []
	var m := u.moves
	for i in path.size():
		var step: Vector2i = path[i]
		if m <= 0:
			break
		var c := move_cost(u, step)
		if c < 0:
			break
		var last := i == path.size() - 1
		if not can_pass(u, step):
			break
		m -= c
		out.append(step)
		if last:
			break
	# Trim back to a tile we may stop on.
	while not out.is_empty() and not can_occupy(u, out[-1]):
		out.pop_back()
	return out

func path_turns(u: Unit, path: Array) -> Array:
	## Returns per-step turn number (1 = this turn).
	var out := []
	var m := u.moves
	var t := 1
	if m <= 0:
		t = 2
		m = u.max_moves()
	for step in path:
		if m <= 0:
			t += 1
			m = u.max_moves()
		m -= maxi(1, move_cost(u, step))
		out.append(t)
	return out

# ---------------------------------------------------------------- combat

func unit_strength(u: Unit, ranged: bool) -> float:
	var s: float = u.def().rstr if ranged else u.def().str
	if u.veteran:
		s *= 1.2
	return s

func defense_strength(d: Unit, attacker: Unit) -> float:
	var s := float(d.def().str)
	if d.veteran:
		s *= 1.2
	var mult := 1.0
	var i := idx(d.pos)
	if hills[i] == 1:
		mult += 0.25
	if forest[i] == 1:
		mult += 0.25
	if d.fortified:
		mult += 0.25
	if d.def().get("anti_mounted", false) and attacker != null and attacker.def()["class"] == "mounted":
		mult += 0.5
	if city_at.has(d.pos):
		mult += 0.25
	return s * mult * (0.5 + 0.5 * d.hp / 100.0)

func city_strength(c: City) -> float:
	var s := 6.0 + c.pop * 0.8 + player(c.owner).techs.size() * 0.25
	for b in c.buildings:
		s += Defs.BUILDINGS[b].get("defense", 0)
	var g := military_at(c.pos)
	if g != null:
		s += g.def().str * 0.5
	if c.capital:
		s += 2.0
	return s

## Expected damage pair (to_defender, to_attacker) for UI previews and resolution.
func combat_odds(a: Unit, target: Vector2i) -> Dictionary:
	var ranged := a.is_ranged()
	var att := unit_strength(a, ranged) * (0.5 + 0.5 * a.hp / 100.0)
	var city: City = city_at.get(target)
	var d := military_at(target)
	var def := 1.0
	var siege: bool = a.def()["class"] == "siege"
	if city != null and city.owner != a.owner:
		def = city_strength(city)
		if siege:
			att *= 2.0
	elif d != null:
		def = defense_strength(d, a)
		if ranged:
			def = maxf(def * 0.85, 1.0)
	else:
		return {}
	var r := clampf(att / maxf(def, 0.5), 0.1, 10.0)
	var to_def := clampf(30.0 * pow(r, 1.15), 1.0, 100.0)
	var to_att := 0.0 if ranged else clampf(30.0 / pow(r, 1.15), 1.0, 100.0)
	return {"to_def": to_def, "to_att": to_att, "att": att, "def": def, "city": city != null}

func can_attack(a: Unit, target: Vector2i) -> bool:
	if a.is_civilian() or a.moves <= 0 or a.attacked:
		return false
	if not in_bounds(target):
		return false
	var dist := Hex.distance(a.pos, target)
	if a.is_ranged():
		if dist > a.def().range or dist < 1:
			return false
	else:
		if dist != 1 or move_cost(a, target) < 0:
			return false
	var city: City = city_at.get(target)
	if city != null and city.owner != a.owner:
		return true
	var d := military_at(target)
	return d != null and d.owner != a.owner

# ---------------------------------------------------------------- cities

func can_found_city(u: Unit) -> bool:
	if u.type != "settler" or u.moves <= 0:
		return false
	if not is_land(u.pos):
		return false
	for c in cities.values():
		if Hex.distance(c.pos, u.pos) < 3:
			return false
	var o := tile_owner[idx(u.pos)]
	return o == -1 or o == u.owner

func city_tiles(c: City) -> Array:
	var out := []
	for t in within(c.pos, 2):
		if tile_owner[idx(t)] == c.owner:
			out.append(t)
	return out

## Choose worked tiles and return the yields of a city.
func city_yields(c: City) -> Dictionary:
	var center := tile_yield(c.pos)
	var f := maxi(2, center.x)
	var p := maxi(1, center.y)
	var g := maxi(1, center.z)
	var cands := []
	for t in city_tiles(c):
		if t == c.pos:
			continue
		var oc: City = city_at.get(t)
		if oc != null:
			continue
		var y := tile_yield(t)
		var score := y.x * 3.0 + y.y * 2.2 + y.z * 1.2
		cands.append({"t": t, "y": y, "s": score + (t.x * 0.0001 + t.y * 0.00001)})
	cands.sort_custom(func(a, b): return a.s > b.s)
	var worked := []
	for i in mini(c.pop, cands.size()):
		var y: Vector3i = cands[i].y
		f += y.x
		p += y.y
		g += y.z
		worked.append(cands[i].t)
	# Unworked citizens become specialists: +1 production each.
	p += maxi(0, c.pop - cands.size())
	var sci := c.pop
	for b in c.buildings:
		var bd: Dictionary = Defs.BUILDINGS[b]
		f += bd.food
		p += bd.prod
		g += bd.gold
		sci += bd.sci
	if c.capital:
		sci += 3
		g += 3
		p += 2
	if c.production == "wealth":
		g += p / 2
	elif c.production == "research":
		sci += p / 2
	return {"food": f, "prod": p, "gold": g, "sci": sci, "surplus": f - c.pop * 2, "worked": worked}

func can_build(c: City, item: String) -> bool:
	var p := player(c.owner)
	if Defs.UNITS.has(item):
		var t: String = Defs.UNITS[item].tech
		if t != "" and not p.techs.has(t):
			return false
		if item == "settler" and c.pop < 2:
			return false
		return true
	if Defs.BUILDINGS.has(item):
		if c.buildings.has(item):
			return false
		var bd: Dictionary = Defs.BUILDINGS[item]
		if bd.has("requires") and not c.buildings.has(bd.requires):
			return false
		return p.techs.has(bd.tech)
	if item == "wealth" or item == "research":
		return true
	if item == "spaceship":
		return p.techs.has("space_flight") and c.capital
	return false

func buildable_items(c: City) -> Array:
	var out := []
	for k in Defs.UNITS:
		if can_build(c, k):
			out.append(k)
	for k in Defs.BUILDINGS:
		if can_build(c, k):
			out.append(k)
	for k in Defs.PROJECTS:
		if can_build(c, k):
			out.append(k)
	return out

func buy_cost(c: City) -> int:
	var cost := Defs.item_cost(c.production)
	if cost <= 0:
		return -1
	var left := maxi(0, cost - c.prod)
	if c.production == "spaceship":
		return -1
	return left * 2 + 10

func turns_to_build(c: City) -> int:
	var cost := Defs.item_cost(c.production)
	if cost <= 0:
		return -1
	var p: int = maxi(1, city_yields(c).prod)
	return maxi(1, ceili(float(cost - c.prod) / p))

# ---------------------------------------------------------------- research / economy

func available_techs(pid: int) -> Array:
	var p := player(pid)
	var out := []
	for k in Defs.TECHS:
		if p.techs.has(k):
			continue
		var ok := true
		for pre in Defs.TECHS[k].pre:
			if not p.techs.has(pre):
				ok = false
				break
		if ok:
			out.append(k)
	return out

func income(pid: int) -> Dictionary:
	var gold := 0
	var sci := 0
	for c in player_cities(pid):
		var y := city_yields(c)
		gold += y.gold
		sci += y.sci
	var upkeep := unit_upkeep(pid)
	return {"gold": gold - upkeep, "sci": maxi(1, sci), "upkeep": upkeep}

func unit_upkeep(pid: int) -> int:
	var n := 0
	for u in units.values():
		if u.owner == pid and not u.is_civilian():
			n += 1
	return maxi(0, n - 3 - player_cities(pid).size() * 2)

func visible_tiles(pid: int) -> PackedByteArray:
	var vis := PackedByteArray()
	vis.resize(w * h)
	for u in units.values():
		if u.owner != pid:
			continue
		var s: int = u.sight()
		if hills[idx(u.pos)] == 1:
			s += 1
		for t in within(u.pos, s):
			vis[idx(t)] = 1
	for c in cities.values():
		if c.owner != pid:
			continue
		for t in within(c.pos, 3):
			vis[idx(t)] = 1
	return vis

func score(pid: int) -> int:
	var p := player(pid)
	var s := p.techs.size() * 4
	for c in player_cities(pid):
		s += 10 + c.pop * 4 + c.buildings.size() * 2
	return s

# ================================================================ HOST: resolve commands

## Returns list of events, empty if command invalid.
func resolve(pid: int, cmd: Dictionary) -> Array:
	if finished:
		return []
	var t: String = cmd.get("t", "")
	match t:
		"chat":
			return [{"t": "chat", "p": pid, "text": str(cmd.text).left(200)}]
		"ready":
			return [{"t": "ready", "p": pid, "v": bool(cmd.v)}]
		"research":
			if available_techs(pid).has(cmd.tech):
				return [{"t": "research", "p": pid, "tech": cmd.tech}]
		"prod":
			var c: City = cities.get(cmd.c)
			if c and c.owner == pid and can_build(c, cmd.item):
				return [{"t": "prod", "c": c.id, "item": cmd.item}]
		"buy":
			var c: City = cities.get(cmd.c)
			if c and c.owner == pid:
				var cost := buy_cost(c)
				if cost > 0 and player(pid).gold >= cost:
					return [{"t": "buy", "c": c.id, "cost": cost}]
	# unit commands
	var u: Unit = units.get(cmd.get("u", -1))
	if u == null or u.owner != pid:
		return []
	match t:
		"move":
			return _resolve_move(u, cmd.to)
		"attack":
			return _resolve_attack(u, cmd.target)
		"found":
			if can_found_city(u):
				return [{"t": "found", "u": u.id, "name": _next_city_name(pid)}]
		"fortify", "sleep", "wake", "skip", "disband", "cancel":
			return [{"t": t, "u": u.id}]
		"improve":
			if can_improve(u, cmd.kind):
				return [{"t": "improve", "u": u.id, "kind": cmd.kind}]
	return []

func _resolve_move(u: Unit, to: Vector2i) -> Array:
	if not in_bounds(to) or u.moves <= 0:
		if in_bounds(to) and to != u.pos:
			return [{"t": "goto", "u": u.id, "to": to}]
		return []
	# Moving onto an enemy civilian with a military unit captures it.
	var capture := -1
	var target_civ := civilian_at(to)
	if target_civ != null and target_civ.owner != u.owner and not u.is_civilian() \
			and military_at(to) == null and not city_at.has(to) and Hex.distance(u.pos, to) == 1:
		if move_cost(u, to) < 0:
			return []
		return [{"t": "move", "u": u.id, "path": [to], "goto": Vector2i(-1, -1), "capture": target_civ.id}]
	var path := find_path(u, to)
	if path.is_empty():
		return []
	var steps := walkable_prefix(u, path)
	var goto := Vector2i(-1, -1)
	if steps.size() < path.size():
		goto = to
	if steps.is_empty():
		return [{"t": "goto", "u": u.id, "to": to}]
	return [{"t": "move", "u": u.id, "path": steps, "goto": goto, "capture": capture}]

func _resolve_attack(a: Unit, target: Vector2i) -> Array:
	if not can_attack(a, target):
		return []
	var odds := combat_odds(a, target)
	if odds.is_empty():
		return []
	var to_def := int(round(odds.to_def * rng.randf_range(0.8, 1.2)))
	var to_att := int(round(odds.to_att * rng.randf_range(0.8, 1.2)))
	var ev := {"t": "attack", "u": a.id, "target": target, "dmg_def": to_def, "dmg_att": to_att,
		"def_unit": -1, "city": -1}
	var city: City = city_at.get(target)
	if city != null and city.owner != a.owner:
		ev.city = city.id
	else:
		ev.def_unit = military_at(target).id
	return [ev]

func city_bombard_events() -> Array:
	var out := []
	for c in cities.values():
		var best: Unit = null
		for u in units.values():
			if u.owner == c.owner or u.is_civilian():
				continue
			if Hex.distance(u.pos, c.pos) > 2:
				continue
			if best == null or u.hp < best.hp:
				best = u
		if best == null:
			continue
		var att := city_strength(c) * 0.8
		var def := defense_strength(best, null)
		var r := clampf(att / maxf(def, 0.5), 0.1, 10.0)
		var dmg := int(round(clampf(30.0 * pow(r, 1.15), 1.0, 100.0) * rng.randf_range(0.8, 1.2)))
		out.append({"t": "city_attack", "c": c.id, "u": best.id, "dmg": dmg})
	return out

func can_improve(u: Unit, kind: String) -> bool:
	if u.type != "worker" or u.moves <= 0:
		return false
	if not Defs.IMPROVEMENTS.has(kind):
		return false
	var tech: String = Defs.IMPROVEMENTS[kind].tech
	if tech != "" and not player(u.owner).techs.has(tech):
		return false
	var i := idx(u.pos)
	if tile_owner[i] != u.owner or city_at.has(u.pos) or improvement[i] == kind:
		return false
	if is_water(u.pos):
		return false
	var r: String = resource[i]
	match kind:
		"farm":
			return forest[i] == 0 and hills[i] == 0 and terrain[i] in [Defs.GRASS, Defs.PLAINS, Defs.DESERT, Defs.TUNDRA]
		"mine":
			return hills[i] == 1 or r in ["iron", "gold", "gems"]
		"trading_post":
			return forest[i] == 0 and hills[i] == 0 and terrain[i] in [Defs.GRASS, Defs.PLAINS, Defs.DESERT, Defs.TUNDRA, Defs.SNOW]
	return false

func _next_city_name(pid: int) -> String:
	var p := player(pid)
	var names: Array = Defs.CIVS[p.civ].cities
	var n: String
	if p.city_name_index < names.size():
		n = names[p.city_name_index]
	else:
		n = "%s %d" % [names[p.city_name_index % names.size()], p.city_name_index / names.size() + 1]
	return n

# ================================================================ apply events (all peers)

func apply(ev: Dictionary) -> void:
	match ev.t:
		"chat":
			notify.emit(-1, "[%s] %s" % [player(ev.p).name, ev.text], Vector2i(-1, -1))
		"ready":
			player(ev.p).ready = ev.v
		"research":
			player(ev.p).research = ev.tech
		"prod":
			cities[ev.c].production = ev.item
		"buy":
			var c: City = cities[ev.c]
			player(c.owner).gold -= ev.cost
			c.prod = Defs.item_cost(c.production)
		"goto":
			var u: Unit = units[ev.u]
			u.goto = ev.to
			u.fortified = false
			u.sleeping = false
		"move":
			_apply_move(ev)
		"attack":
			_apply_attack(ev)
		"city_attack":
			var c: City = cities.get(ev.c)
			var u: Unit = units.get(ev.u)
			if c and u:
				u.hp -= ev.dmg
				c.bombarded = true
				if u.hp <= 0:
					notify.emit(u.owner, "%s was destroyed by %s's defenses." % [u.def().name, c.name], u.pos)
					_remove_unit(u)
		"found":
			_apply_found(ev)
		"fortify":
			var u: Unit = units[ev.u]
			u.fortified = true
			u.goto = Vector2i(-1, -1)
		"sleep":
			var u: Unit = units[ev.u]
			u.sleeping = true
			u.goto = Vector2i(-1, -1)
		"wake":
			var u: Unit = units[ev.u]
			u.sleeping = false
			u.fortified = false
		"skip":
			units[ev.u].skip = true
		"cancel":
			var u: Unit = units[ev.u]
			u.goto = Vector2i(-1, -1)
			u.build_kind = ""
		"disband":
			_remove_unit(units[ev.u])
		"improve":
			var u: Unit = units[ev.u]
			u.build_kind = ev.kind
			u.build_left = Defs.IMPROVEMENTS[ev.kind].turns
			u.moves = 0
			u.goto = Vector2i(-1, -1)
		"new_turn":
			_apply_new_turn()
		"drop":
			var p := player(ev.p)
			p.peer_id = 0
			notify.emit(-1, "%s disconnected — the AI takes over %s." % [p.name, p.civ_name()], Vector2i(-1, -1))
	_check_victory()
	event_applied.emit(ev)

func _apply_move(ev: Dictionary) -> void:
	var u: Unit = units.get(ev.u)
	if u == null:
		return
	for step in ev.path:
		var c := move_cost(u, step)
		u.moves = maxi(0, u.moves - maxi(c, 1))
		u.pos = step
	u.goto = ev.goto
	u.fortified = false
	u.sleeping = false
	u.skip = false
	u.build_kind = ""
	u.acted = true
	if ev.get("capture", -1) >= 0:
		var cv: Unit = units.get(ev.capture)
		if cv:
			var old := cv.owner
			notify.emit(old, "Your %s was captured!" % cv.def().name, cv.pos)
			cv.owner = u.owner
			if cv.type == "settler":
				cv.type = "worker"
			cv.moves = 0
			cv.build_kind = ""
			cv.goto = Vector2i(-1, -1)
			_check_elimination(old)

func _apply_attack(ev: Dictionary) -> void:
	var a: Unit = units.get(ev.u)
	if a == null:
		return
	a.attacked = true
	a.acted = true
	a.fortified = false
	a.goto = Vector2i(-1, -1)
	var mobile: bool = a.def()["class"] == "mounted" or a.def()["class"] == "armor"
	a.moves = maxi(0, a.moves - 2) if mobile else 0
	var target: Vector2i = ev.target
	if ev.city >= 0:
		var c: City = cities.get(ev.city)
		if c == null:
			return
		c.hp -= ev.dmg_def
		a.hp -= ev.dmg_att
		if a.hp <= 0:
			notify.emit(a.owner, "Your %s died attacking %s." % [a.def().name, c.name], target)
			_remove_unit(a)
			c.hp = maxi(c.hp, 1)
			return
		if c.hp <= 0:
			c.hp = 0
			if not a.is_ranged() and a.def()["class"] != "siege":
				_capture_city(c, a)
		return
	var d: Unit = units.get(ev.def_unit)
	if d == null:
		return
	d.hp -= ev.dmg_def
	a.hp -= ev.dmg_att
	var def_owner := d.owner
	if d.hp <= 0:
		notify.emit(d.owner, "Your %s was destroyed by %s %s." % [d.def().name, player(a.owner).civ_name(), a.def().name], target)
		_remove_unit(d)
		if a.hp <= 0:
			a.hp = 1
		if not a.is_ranged():
			# Advance; capture any civilian left behind.
			var civ := civilian_at(target)
			if civ != null and civ.owner != a.owner:
				civ.owner = a.owner
				if civ.type == "settler":
					civ.type = "worker"
				civ.moves = 0
				civ.build_kind = ""
			if military_at(target) == null and not city_at.has(target):
				a.pos = target
		_check_elimination(def_owner)
	elif a.hp <= 0:
		notify.emit(a.owner, "Your %s died in battle." % a.def().name, a.pos)
		_remove_unit(a)

func _capture_city(c: City, a: Unit) -> void:
	var old := c.owner
	# Destroy remaining enemy units on the tile.
	for u in units_at(c.pos):
		if u.owner == old:
			if u.is_civilian():
				u.owner = a.owner
				if u.type == "settler":
					u.type = "worker"
			else:
				_remove_unit(u)
	if old >= 0:
		notify.emit(old, "%s has been captured by %s!" % [c.name, player(a.owner).civ_name()], c.pos)
	notify.emit(a.owner, "You captured %s!" % c.name, c.pos)
	c.owner = a.owner
	c.capital = false
	c.pop = maxi(1, c.pop - 1)
	c.hp = c.max_hp() / 4
	c.production = ""
	c.prod = 0
	c.buildings.erase("walls")
	c.buildings.erase("castle")
	a.pos = c.pos
	for t in within(c.pos, 2):
		var i := idx(t)
		if tile_owner[i] == old and _closest_city_owner(t) == a.owner:
			tile_owner[i] = a.owner
	# Give old owner a new capital.
	_ensure_capital(old)
	_check_elimination(old)

func _closest_city_owner(t: Vector2i) -> int:
	var best := 999
	var o := -1
	for c in cities.values():
		var d := Hex.distance(c.pos, t)
		if d < best or (d == best and c.id < 0):
			best = d
			o = c.owner
	return o

func _ensure_capital(pid: int) -> void:
	if pid < 0:
		return
	var cs := player_cities(pid)
	for c in cs:
		if c.capital:
			return
	if not cs.is_empty():
		cs[0].capital = true

func _apply_found(ev: Dictionary) -> void:
	var u: Unit = units.get(ev.u)
	if u == null:
		return
	var p := player(u.owner)
	var c := City.new()
	c.id = next_id
	next_id += 1
	c.name = ev.name
	c.owner = u.owner
	c.founder = u.owner
	c.pos = u.pos
	c.capital = player_cities(u.owner).is_empty()
	c.hp = c.max_hp()
	cities[c.id] = c
	city_at[c.pos] = c
	p.city_name_index += 1
	p.ever_had_city = true
	_remove_unit(u)
	_claim(c, 1)
	notify.emit(c.owner, "%s has been founded." % c.name, c.pos)

func _claim(c: City, radius: int) -> void:
	for t in within(c.pos, radius):
		var i := idx(t)
		if tile_owner[i] == -1 or t == c.pos:
			tile_owner[i] = c.owner

func _spawn_unit(type: String, pid: int, pos: Vector2i, vet := false) -> Unit:
	var u := Unit.new()
	u.id = next_id
	next_id += 1
	u.type = type
	u.owner = pid
	u.pos = pos
	u.moves = Defs.UNITS[type].moves
	u.veteran = vet
	units[u.id] = u
	return u

func _remove_unit(u: Unit) -> void:
	units.erase(u.id)

func _free_land_near(c: Vector2i, type: String) -> Vector2i:
	var probe := Unit.new()
	probe.type = type
	probe.owner = -99
	for r in range(0, 4):
		for t in within(c, r):
			if is_land(t) and can_occupy(probe, t):
				return t
	return c

func _spawn_pos_for(c: City, type: String) -> Vector2i:
	var probe := Unit.new()
	probe.type = type
	probe.owner = c.owner
	if can_occupy(probe, c.pos):
		return c.pos
	for r in range(1, 3):
		for t in within(c.pos, r):
			if is_land(t) and can_occupy(probe, t):
				return t
	return Vector2i(-1, -1)

func _apply_new_turn() -> void:
	for p in players:
		if not p.alive:
			continue
		var pid: int = p.id
		# Cities
		var sorted := player_cities(pid)
		sorted.sort_custom(func(a, b): return a.id < b.id)
		var gold := 0
		var sci := 0
		for c in sorted:
			var y := city_yields(c)
			gold += y.gold
			sci += y.sci
			c.bombarded = false
			c.hp = mini(c.max_hp(), c.hp + 20)
			# Growth
			c.food += y.surplus
			if c.food >= c.growth_threshold():
				c.food = 0 if not c.buildings.has("granary") else c.growth_threshold() / 4
				c.pop += 1
				notify.emit(pid, "%s has grown to size %d." % [c.name, c.pop], c.pos)
				if c.pop == 3:
					_claim(c, 2)
			elif c.food < 0:
				if c.pop > 1:
					c.pop -= 1
					notify.emit(pid, "%s is starving!" % c.name, c.pos)
				c.food = 0
			# Production
			if c.production != "" and c.production != "wealth" and c.production != "research":
				c.prod += y.prod
				var cost := Defs.item_cost(c.production)
				if c.prod >= cost:
					_complete_production(c, cost)
		# Economy
		var up := unit_upkeep(pid)
		p.gold += gold - up
		if p.gold < 0:
			for u in player_units(pid):
				if not u.is_civilian():
					notify.emit(pid, "Bankrupt! A %s has been disbanded." % u.def().name, u.pos)
					_remove_unit(u)
					break
			p.gold = 0
		# Science
		if p.research == "" or p.techs.has(p.research):
			p.research = ""
		p.science += maxi(1, sci)
		if p.research != "":
			var cost: int = Defs.TECHS[p.research].cost
			if p.science >= cost:
				p.science -= cost
				p.techs[p.research] = true
				notify.emit(pid, "Researched %s!" % Defs.TECHS[p.research].name, Vector2i(-1, -1))
				p.research = ""
	# Units
	for u in units.values():
		var heal := 0
		if not u.acted:
			heal = 10
			var o := tile_owner[idx(u.pos)]
			if o == u.owner:
				heal = 20
			if city_at.has(u.pos) and city_at[u.pos].owner == u.owner:
				heal = 30
		u.hp = mini(100, u.hp + heal)
		u.moves = u.max_moves()
		u.attacked = false
		u.acted = false
		u.skip = false
		if u.build_kind != "":
			u.build_left -= 1
			if u.build_left <= 0:
				improvement[idx(u.pos)] = u.build_kind
				u.build_kind = ""
				if forest[idx(u.pos)] == 1 and improvement[idx(u.pos)] != "mine":
					forest[idx(u.pos)] = 0
			else:
				u.moves = 0
	for p in players:
		p.ready = false
	turn += 1

func _complete_production(c: City, cost: int) -> void:
	var item := c.production
	if Defs.UNITS.has(item):
		var pos := _spawn_pos_for(c, item)
		if pos.x < 0:
			return  # blocked, wait
		var u := _spawn_unit(item, c.owner, pos, c.buildings.has("barracks"))
		u.moves = 0
		if item == "settler":
			c.pop = maxi(1, c.pop - 1)
		notify.emit(c.owner, "%s trained %s." % [c.name, Defs.with_article(u.def().name)], c.pos)
		c.prod -= cost
		c.production = ""
	elif Defs.BUILDINGS.has(item):
		c.buildings.append(item)
		if Defs.BUILDINGS[item].has("hp"):
			c.hp += Defs.BUILDINGS[item].hp
		notify.emit(c.owner, "%s built %s." % [c.name, Defs.with_article(Defs.BUILDINGS[item].name)], c.pos)
		c.prod -= cost
		c.production = ""
	elif item == "spaceship":
		c.prod = 0
		finished = true
		winner = c.owner
		notify.emit(-1, "%s has launched a colony ship to the stars!" % player(c.owner).civ_name(), c.pos)
		game_over.emit(c.owner, "Science")
	c.prod = maxi(0, c.prod)

func _check_elimination(pid: int) -> void:
	if pid < 0:
		return
	var p := player(pid)
	if not p.alive:
		return
	if not player_cities(pid).is_empty():
		return
	var has_settler := false
	var any_unit := false
	for u in units.values():
		if u.owner == pid:
			any_unit = true
			if u.type == "settler":
				has_settler = true
	if not has_settler or not any_unit:
		p.alive = false
		for u in player_units(pid):
			_remove_unit(u)
		notify.emit(-1, "%s has been eliminated!" % p.civ_name(), Vector2i(-1, -1))

func _check_victory() -> void:
	if finished:
		return
	for p in players:
		_check_elimination(p.id)
	var alive := []
	for p in players:
		if p.alive:
			alive.append(p.id)
	if alive.size() == 1 and players.size() > 1:
		finished = true
		winner = alive[0]
		game_over.emit(winner, "Domination")
	elif alive.is_empty():
		finished = true
		winner = -1
		game_over.emit(-1, "None")
	elif turn > 300:
		finished = true
		var best := -1
		var bs := -1
		for pid in alive:
			var s := score(pid)
			if s > bs:
				bs = s
				best = pid
		winner = best
		game_over.emit(best, "Score")

func humans_ready() -> bool:
	for p in players:
		if p.alive and not p.is_ai() and not p.ready:
			return false
	return true

func checksum() -> int:
	var s := turn * 7919
	for u in units.values():
		s = (s * 31 + u.id * 7 + u.pos.x * 13 + u.pos.y * 17 + u.hp) % 1000000007
	for c in cities.values():
		s = (s * 31 + c.id + c.pop * 3 + c.prod + c.owner) % 1000000007
	for p in players:
		s = (s * 31 + p.gold + p.science + p.techs.size()) % 1000000007
	return s
