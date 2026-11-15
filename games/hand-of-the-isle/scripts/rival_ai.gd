class_name RivalAI
extends RefCounted
## The rival deity. Plays by the player's rules: it sculpts only inside its
## own influence and pays faith for everything it does.

var world: World
var team := 1
var level := 1                   # 0 easy, 1 normal, 2 hard

var _think := 2.0
var _power_t := 40.0
var _rng := RandomNumberGenerator.new()


func _init(w: World, t: int, lvl: int) -> void:
	world = w
	team = t
	level = lvl
	_rng.randomize()
	_power_t = [90.0, 55.0, 35.0][lvl]


func tick(dt: float) -> void:
	_think -= dt
	_power_t -= dt
	if _think > 0.0:
		return
	_think = [1.6, 0.9, 0.5][level]
	_sculpt([2, 4, 7][level])
	_choose_behavior()
	if _power_t <= 0.0:
		_power_t = _rng.randf_range(1.0, 1.6) * [70.0, 40.0, 24.0][level]
		_cast_power()


# ------------------------------------------------------------------ shaping
func _sculpt(budget: int) -> void:
	var own: Array[Settlement] = []
	for s in world.settlements:
		if s.team == team and s.tier < 3:
			own.append(s)
	var spent := 0
	var tries := 0
	while spent < budget and tries < 6 and world.mana[team] > 8.0:
		tries += 1
		if own.is_empty():
			spent += _flatten_for_walker()
			continue
		var s: Settlement = own[_rng.randi() % own.size()]
		var r := s.tier
		var t := s.tile + Vector2i(_rng.randi_range(-r, r), _rng.randi_range(-r, r))
		if t == s.tile or not world.terrain.in_tiles(t):
			continue
		if world.terrain.tile_flat(t) and world.terrain.tile_min(t) == s.base_h:
			continue
		var o: Settlement = world.claim.get(t)
		if o != null and o != s:
			continue
		if not _safe_to_shape(t, s):
			continue
		spent += _shape(t, s.base_h)
	if spent == 0 and _rng.randf() < 0.5:
		_flatten_for_walker()


func _flatten_for_walker() -> int:
	var mine: Array[Walker] = []
	for w in world.walkers:
		if w.team == team:
			mine.append(w)
	if mine.is_empty():
		return 0
	var w: Walker = mine[_rng.randi() % mine.size()]
	var t := Vector2i(floor(w.gp.x), floor(w.gp.y))
	if world.terrain.tile_flat(t) or not _safe_to_shape(t, null):
		return 0
	var target := maxi(world.terrain.tile_max(t), world.terrain.water_level + 1)
	if world.terrain.tile_max(t) - world.terrain.tile_min(t) == 1:
		target = world.terrain.tile_min(t) if world.terrain.tile_min(t) > world.terrain.water_level else target
	return _shape(t, target)


## Never reshape ground under a different settlement.
func _safe_to_shape(t: Vector2i, keep: Settlement) -> bool:
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var o: Settlement = world.claim.get(t + Vector2i(dx, dz))
			if o != null and o != keep:
				return false
	return true


func _shape(t: Vector2i, target: int) -> int:
	var n := 0
	for c in [t, t + Vector2i(1, 0), t + Vector2i(0, 1), t + Vector2i(1, 1)]:
		var hv := world.terrain.vh(c.x, c.y)
		if hv == target or not world.vertex_in_influence(c, team):
			continue
		var p := Vector3(c.x, 0, c.y)
		var idx := world.power_index("sculpt")
		if world.cast(team, idx, p, hv > target) == "":
			n += 1
	return n


# --------------------------------------------------------------- strategy
func _choose_behavior() -> void:
	var mine := world.team_total(team)
	var theirs := world.team_total(1 - team)
	var walkers := world.count_of(team).x
	var b: int = world.behavior[team]
	var grace: float = [300.0, 180.0, 100.0][level]
	if world.elapsed > grace and mine > theirs * 1.35 and mine > 70 and walkers >= 3:
		b = World.CRUSADE
	elif b == World.CRUSADE and mine < theirs * 1.1:
		b = World.SETTLE
	world.behavior[team] = b


func _cast_power() -> void:
	var foe := 1 - team
	var target := _richest(foe)
	var mine := world.team_total(team)
	var theirs := world.team_total(foe)
	var m: float = world.mana[team]
	var options: Array[String] = []
	if level >= 1 and m >= 1200.0 and mine > theirs * 1.6:
		options.append("armageddon")
	if level >= 1 and m >= 460.0 and target != null:
		options.append("volcano")
	if m >= 260.0 and level >= 1:
		options.append("champion")
	if m >= 170.0 and target != null:
		options.append("swamp")
	if m >= 120.0 and target != null:
		options.append("quake")
	if options.is_empty():
		return
	var pick: String = options[0] if _rng.randf() < 0.45 else options[_rng.randi() % options.size()]
	var at := Vector3.ZERO
	if target != null:
		at = Vector3(target.tile.x + 0.5, 0, target.tile.y + 0.5)
		if pick == "swamp":
			at += Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
	world.cast(team, world.power_index(pick), at)


func _richest(t: int) -> Settlement:
	var best: Settlement = null
	for s in world.settlements:
		if s.team == t and (best == null or s.pop * s.tier > best.pop * best.tier):
			best = s
	return best
