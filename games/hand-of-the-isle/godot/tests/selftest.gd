extends SceneTree
## Headless self-test (npm run test:godot): the island, sculpting and its limits, two powers, and a whole
## match with the rival AI playing both sides. Exits 0 when everything holds, 1 otherwise.

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _island_and_sculpting()
	await _powers()
	await _whole_match()
	await process_frame
	print("[selftest] %s" % ("all checks passed" if _failures == 0 else "%d check(s) failed" % _failures))
	quit(1 if _failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("[selftest] FAILED: ", what)


func _world(seed_value: int) -> World:
	var w := World.new()
	root.add_child(w)
	await process_frame
	_check(w.terrain.is_inside_tree(), "the world is in the scene tree")
	w.start(seed_value)
	w.step(0.5)
	return w


func _island_and_sculpting() -> void:
	var w: World = await _world(4)
	_check(w.team_total(0) == 12 and w.team_total(1) == 12, "each side starts with 12 followers")
	var v := Vector2i(-1, -1)
	for z in Terrain.N + 1:
		for x in Terrain.N + 1:
			var p := Vector2i(x, z)
			if v.x < 0 and w.vertex_in_influence(p, 0) and w.terrain.vh(x, z) < Terrain.MAX_H:
				v = p
	_check(v.x >= 0, "the player has somewhere to sculpt")
	var before := w.terrain.vh(v.x, v.y)
	var faith: float = w.mana[0]
	_check(w.cast(0, 0, Vector3(v.x, 0, v.y)) == "", "sculpting inside the influence works")
	_check(w.terrain.vh(v.x, v.y) == before + 1, "raising lifts the corner one step")
	_check(is_equal_approx(w.mana[0], faith - 1.0), "sculpting costs one faith")
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			_check(absi(w.terrain.vh(v.x + dx, v.y + dz) - w.terrain.vh(v.x, v.y)) <= 1, "neighbours stay within one step")
	_check(w.cast(0, 0, Vector3(Terrain.N, 0, 0)) == "Beyond your influence.", "no sculpting outside the influence")
	w.mana[0] = 0.0
	_check(w.cast(0, 0, Vector3(v.x, 0, v.y)) != "", "no sculpting without faith")
	w.queue_free()
	await process_frame


func _powers() -> void:
	var w: World = await _world(9)
	w.mana[0] = World.MANA_MAX
	var sea := w.terrain.water_level
	_check(w.cast(0, w.power_index("flood"), Vector3.ZERO) == "", "Flood can be cast")
	_check(w.terrain.water_level == sea + 1, "Flood raises the sea one step")
	_check(is_equal_approx(w.mana[0], World.MANA_MAX - 720.0), "Flood costs 720 faith")
	w.mana[0] = 50.0
	_check(w.cast(0, w.power_index("quake"), Vector3(24, 0, 24)) != "", "Earthquake needs 120 faith")
	w.queue_free()
	await process_frame


func _whole_match() -> void:
	var w: World = await _world(3)
	var ais := [RivalAI.new(w, 0, 1), RivalAI.new(w, 1, 1)]
	var winner := [-1]
	w.game_over.connect(func(t: int): winner[0] = t)
	var best_tier := 0
	var t := 0.0
	while winner[0] < 0 and t < 1500.0:
		w.step(0.05)
		for ai in ais:
			ai.tick(0.05)
		for s in w.settlements:
			best_tier = maxi(best_tier, s.tier)
		t += 0.05
	_check(winner[0] >= 0, "a match between two rivals ends within 25 minutes of game time")
	_check(best_tier >= 2, "homes grow beyond huts")
	print("[selftest] match ended after %d s, winner team %d, largest home tier %d" % [int(t), winner[0], best_tier])
	w.queue_free()
	await process_frame
