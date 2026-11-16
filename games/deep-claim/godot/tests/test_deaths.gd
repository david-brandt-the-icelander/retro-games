extends SceneTree
## The two timers kill: a shaft caving in (even in the buggy), and an empty oxygen tank outside it.
## Run: godot --headless --path godot -s tests/test_deaths.gd

var main: Main
var t := 0.0
var started := false
var reasons: Array[String] = []


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 1.0 and not started:
		main._start_game()
		started = true
	if main.state == Main.State.PLAYING:
		var lv: Level = main.level
		if not lv.player_killed.is_connected(_killed):
			lv.player_killed.connect(_killed)
		if reasons.is_empty():
			main.collapse = minf(main.collapse, 0.02)
		elif reasons.size() == 1:
			if lv.player.in_buggy:
				lv.toggle_buggy()
			lv.player.oxygen = minf(lv.player.oxygen, 0.01)
	if reasons.size() >= 2:
		var ok := reasons[0] == "THE SHAFT CAVED IN" and reasons[1] == "OUT OF OXYGEN" and main.lives == 1
		if ok:
			print("PASS: ", reasons)
			quit(0)
		else:
			printerr("FAIL: ", reasons, " lives ", main.lives)
			quit(1)
	elif t > 60.0:
		printerr("FAIL: timed out, deaths so far ", reasons)
		quit(1)
	return false


func _killed(reason: String) -> void:
	reasons.append(reason)
