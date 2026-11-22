extends SceneTree
## Run with: godot --headless --path godot -s tests/test_maps.gd
## Every map, over many seeds: the same seed always builds the same building, every room can be
## reached, the extraction door is on an outside wall, and there is a spawn point for every agent
## the map allows.

var failures := 0


func check(cond: bool, what: String) -> void:
	if not cond:
		failures += 1
		printerr("  FAIL ", what)


func _init() -> void:
	var maps = load("res://scripts/maps.gd").new()
	for id in maps.ids():
		var def: Dictionary = maps.DEFS[id]
		for seed_value in range(1, 201):
			var a: Dictionary = maps.generate(id, seed_value)
			var b: Dictionary = maps.generate(id, seed_value)
			var where := "%s seed %d" % [id, seed_value]
			check(var_to_str(a.doors) == var_to_str(b.doors) and var_to_str(a.furniture) == var_to_str(b.furniture), where + ": same seed, same building")
			# Every room reachable through doors
			var seen := {0: true}
			var todo := [0]
			while not todo.is_empty():
				var r: int = todo.pop_back()
				for d in a.doors:
					if d.rooms.has(r):
						var other: int = d.rooms[0] if d.rooms[1] == r else d.rooms[1]
						if not seen.has(other):
							seen[other] = true
							todo.append(other)
			check(seen.size() == a.rooms.size(), where + ": every room reachable")
			# Extraction on an outside wall of the exit room
			check(not a.exit.is_empty(), where + ": has an extraction door")
			var out: Vector3 = a.exit.pos + a.exit.normal * 1.0
			check(maps.room_at(a, out) == -1, where + ": extraction leads outside")
			check(maps.room_at(a, a.exit.pos - a.exit.normal * 1.0) == a.exit_room, where + ": extraction is in the exit room")
			# Enough spawn points, none in the exit room
			check(a.spawns.size() >= def.max_players, where + ": a spawn for every agent")
			for sp in a.spawns:
				check(maps.room_at(a, sp) != a.exit_room, where + ": nobody spawns at the exit")
			# Furniture never blocks a doorway
			for f in a.furniture:
				for d in a.doors:
					check(Vector2(f.pos.x - d.pos.x, f.pos.z - d.pos.z).length() > 1.5, where + ": furniture clear of doors")
			# Enough furniture to hide the intel and the gadgets
			check(a.furniture.size() >= 4 + 4 * maxi(2, ceili(def.max_players * 0.75)), where + ": room for all the intel and gadgets")
	maps.free()
	if failures == 0:
		print("test_maps: all passed")
	quit(1 if failures > 0 else 0)
