extends SceneTree
## Every shaft loads, has ore, a buggy and a two-cell exit door, and a collapse time.
## Run: godot --headless --path godot -s tests/test_levels.gd

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return false
	_done = true
	for a in ["move_left", "move_right", "jump"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
	var failures := 0
	for i in Levels.DATA.size():
		var data: Dictionary = Levels.DATA[i]
		var lv := Level.new()
		lv.setup(data)
		root.add_child(lv)
		var problems: Array[String] = []
		if lv.ore_total < 5:
			problems.append("only %d ore" % lv.ore_total)
		if lv.door_cells.size() != 2:
			problems.append("%d door cells" % lv.door_cells.size())
		if lv.buggy == null or lv.buggy_start == Vector2.ZERO:
			problems.append("no buggy")
		if lv.collapse_time < 60.0:
			problems.append("collapse time %.0f" % lv.collapse_time)
		if problems.is_empty():
			print("ok  shaft %d %s: %d ore, %.0f s" % [i + 1, lv.level_name, lv.ore_total, lv.collapse_time])
		else:
			failures += 1
			printerr("FAIL shaft %d: %s" % [i + 1, ", ".join(problems)])
		lv.free()
	quit(1 if failures else 0)
	return false
