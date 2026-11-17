extends SceneTree
## Headless self-test of Twelve Banners.
## Run: godot --headless --path . -s tests/selftest.gd
##
##  1. Hex maths and rules (paths, founding cities, combat odds, production).
##  2. Lockstep: a host Game and a mirror Game fed only the host's events stay identical, turn after turn,
##     through a whole AI game with eight civilizations (the same flow the network uses).
##  3. Twelve civilizations for 120 turns: everyone founds a city, research advances, nothing breaks.
##  4. The real scene: the menu, a single-player game started from it, the world and HUD built, a few frames run.

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("Hex maths and rules")
	_test_hex()
	_test_rules()
	print("Lockstep")
	_test_lockstep()
	print("Twelve civilizations")
	_test_twelve()
	print("The scene")
	await _test_scene()
	print("%s: %d failure(s)" % ["FAILED" if failures else "PASSED", failures])
	quit(1 if failures else 0)


# ------------------------------------------------------------------ helpers

func _slots(n: int) -> Array:
	var out := []
	for i in n:
		out.append({"id": i, "name": "AI %d" % i, "civ": i, "color": i, "peer": 0})
	return out


func _new_game(n: int, seed_value: int, size: int = 1) -> Game:
	var s: Dictionary = Defs.MAP_SIZES[size]
	var g := Game.new()
	g.setup_from_dict(MapGen.generate(s.w, s.h, seed_value, _slots(n)))
	g.rng.seed = seed_value
	return g


## One full turn the way Net's host runs it: AIs act, cities bombard, the turn resolves.
## Every event is also handed to `mirror` (if any), as the network would.
func _host_turn(g: Game, mirror: Game) -> void:
	var emit := func(evs: Array) -> void:
		for ev in evs:
			g.apply(ev)
			if mirror:
				mirror.apply(bytes_to_var(var_to_bytes(ev)))  # as if it had crossed the wire
	for u in g.units.values().duplicate():
		if g.units.has(u.id) and u.goto.x >= 0 and u.moves > 0:
			var evs := g.resolve(u.owner, {"t": "move", "u": u.id, "to": u.goto})
			emit.call(evs if not evs.is_empty() else [{"t": "cancel", "u": u.id}])
	for p in g.players:
		if p.alive and not g.finished:
			var pid: int = p.id
			AI.run_turn(g, pid, func(cmd):
				var evs := g.resolve(pid, cmd)
				emit.call(evs)
				return not evs.is_empty())
	emit.call(g.city_bombard_events())
	emit.call([{"t": "new_turn"}])


# ------------------------------------------------------------------ 1. hex + rules

func _test_hex() -> void:
	var ok := true
	for y in 12:
		for x in 12:
			var c := Vector2i(x, y)
			if Hex.from_world(Hex.to_world(c)) != c:
				ok = false
			for n in Hex.neighbors(c):
				if Hex.distance(c, n) != 1:
					ok = false
	check(ok, "every hex round-trips through world space and its six neighbours are at distance 1")
	check(Hex.ring(Vector2i(5, 5), 2).size() == 19, "a radius-2 area holds 19 hexes")


func _test_rules() -> void:
	var g := _new_game(2, 99)
	var settler = null
	var warrior = null
	for u in g.player_units(0):
		if u.type == "settler": settler = u
		if u.type == "warrior": warrior = u
	check(settler != null and warrior != null, "each civilization starts with a settler, a warrior and a scout")
	check(g.can_found_city(settler), "the settler can found a city on its start tile")
	var evs := g.resolve(0, {"t": "found", "u": settler.id})
	for ev in evs:
		g.apply(ev)
	var cities := g.player_cities(0)
	check(cities.size() == 1 and cities[0].capital, "founding makes a capital")
	var city = cities[0]
	check(not g.units.has(settler.id), "the settler is used up")
	check(g.tile_owner[g.idx(city.pos)] == 0, "the city claims its tile")
	check(g.resolve(1, {"t": "prod", "c": city.id, "item": "warrior"}).is_empty(), "nobody may give orders to another civilization's city")
	check(g.resolve(0, {"t": "prod", "c": city.id, "item": "tank"}).is_empty(), "a unit needs its technology")
	for ev in g.resolve(0, {"t": "prod", "c": city.id, "item": "warrior"}):
		g.apply(ev)
	check(city.production == "warrior", "production can be chosen")
	var before := g.player_units(0).size()
	for i in 20:
		g.apply({"t": "new_turn"})
	check(g.player_units(0).size() > before, "the city trains the warrior")
	check(g.turn == 21, "turns advance")
	# Movement and paths
	var reach := g.reachable(warrior)
	check(not reach.is_empty(), "the warrior can move somewhere")
	var far := Vector2i(-1, -1)
	for y in g.h:
		for x in g.w:
			var t := Vector2i(x, y)
			if g.is_land(t) and Hex.distance(t, warrior.pos) > 5 and not g.find_path(warrior, t).is_empty():
				far = t
				break
		if far.x >= 0:
			break
	if far.x >= 0:
		var path := g.find_path(warrior, far)
		var adjacent := true
		var prev: Vector2i = warrior.pos
		for step in path:
			if Hex.distance(prev, step) != 1 or not g.is_land(step):
				adjacent = false
			prev = step
		check(adjacent and path[-1] == far, "a long path walks hex to hex over land to its goal")
	# Combat odds: a tank beats a warrior, and fortifying helps the defender.
	var a := Game.Unit.new(); a.type = "tank"; a.owner = 0; a.pos = Vector2i(3, 3); a.moves = 5
	var d := Game.Unit.new(); d.type = "warrior"; d.owner = 1; d.pos = Vector2i(4, 3)
	var g2 := _new_game(2, 7)
	g2.units.clear()
	g2.units[1] = a; a.id = 1
	g2.units[2] = d; d.id = 2
	for t in [a.pos, d.pos]:
		g2.terrain[g2.idx(t)] = Defs.GRASS
		g2.forest[g2.idx(t)] = 0
		g2.hills[g2.idx(t)] = 0
	var o := g2.combat_odds(a, d.pos)
	check(o.to_def > o.to_att * 3.0, "a tank strongly outfights a warrior")
	var plain: float = g2.defense_strength(d, a)
	d.fortified = true
	check(g2.defense_strength(d, a) > plain, "fortifying raises defence")


# ------------------------------------------------------------------ 2. lockstep

func _test_lockstep() -> void:
	var host := _new_game(8, 4242)
	var map := MapGen.generate(Defs.MAP_SIZES[1].w, Defs.MAP_SIZES[1].h, 4242, _slots(8))
	var mirror := Game.new()
	mirror.setup_from_dict(bytes_to_var(var_to_bytes(map)))
	check(host.checksum() == mirror.checksum(), "both start from the same state")
	var same := true
	var first_bad := -1
	for i in 100:
		_host_turn(host, mirror)
		if host.checksum() != mirror.checksum():
			same = false
			first_bad = host.turn
			break
		if host.finished:
			break
	check(same, "the mirror matches the host every turn for 100 turns%s" % ("" if same else " (diverged on turn %d)" % first_bad))
	check(host.cities.size() >= 8, "eight civilizations have founded cities (%d cities)" % host.cities.size())


# ------------------------------------------------------------------ 3. twelve civs

func _test_twelve() -> void:
	var g := _new_game(12, 12345, 2)
	var t0 := Time.get_ticks_msec()
	for i in 120:
		_host_turn(g, null)
		if g.finished:
			break
	var founded := true
	for p in g.players:
		if not p.ever_had_city:
			founded = false
	check(g.players.size() == 12, "twelve civilizations take part")
	check(founded, "every civilization founded a city")
	var most := 0
	for p in g.players:
		most = maxi(most, p.techs.size())
	check(most >= 15, "research advances (best: %d technologies by turn %d)" % [most, g.turn])
	check(g.turn > 100 or g.finished, "the game runs past turn 100 or ends with a winner")
	print("       %d turns in %.1f s" % [g.turn - 1, (Time.get_ticks_msec() - t0) / 1000.0])


# ------------------------------------------------------------------ 4. the scene

func _test_scene() -> void:
	change_scene_to_file("res://scenes/Main.tscn")
	for i in 5:
		await process_frame
	var main := current_scene
	check(main != null and main.menu != null and main.menu.visible, "the menu opens")
	var net = root.get_node("Net")
	net.host_offline("Tester")
	net.lobby.ai_count = 3
	net.auto_end_delay = 0.0
	net.start_game(2024)
	for i in 10:
		await process_frame
	check(main.game != null and main.view != null and main.hud != null, "a single-player game starts with the world and the HUD")
	check(not main.menu.visible, "the menu closes")
	var mine := 0
	for u in main.game.units.values():
		if u.owner == main.pid:
			mine += 1
	check(mine == 3, "the player has a settler, a warrior and a scout")
	var settler = null
	for u in main.game.units.values():
		if u.owner == main.pid and u.type == "settler":
			settler = u
	main.select_unit(settler.id)
	main.cmd_unit("found")
	for i in 3:
		await process_frame
	check(main.game.player_cities(main.pid).size() == 1, "founding a city from the HUD works")
	var city = main.game.player_cities(main.pid)[0]
	main.cmd_city("prod", city.id, "warrior")
	net.send({"t": "research", "tech": "pottery"})
	main.end_turn_pressed(true)
	for i in 10:
		await process_frame
	check(main.game.turn == 2, "ending the turn lets the AIs move and starts turn 2")
	check(main.hud.top_turn.text.begins_with("Turn 2"), "the HUD shows the new turn")
	main.hud.toggle_tech_tree()
	await process_frame
	check(main.hud.tech_overlay.visible, "the tech tree opens")
	main.leave_game()
	for i in 3:
		await process_frame
	check(main.menu.visible and main.game == null, "leaving returns to the menu")
