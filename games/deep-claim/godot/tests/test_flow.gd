extends SceneTree
## Plays every shaft through the real game: step out of the buggy, collect each ore (by placing the
## miner on it), board again and drive out through the tunnel. Fails unless the game is won.
## Run: godot --headless --path godot -s tests/test_flow.gd

var main: Main
var t := 0.0
var started := false


func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)


func _process(delta: float) -> bool:
	t += delta
	if t > 1.0 and not started:
		main._start_game()
		started = true
	for a in ["move_left", "move_right", "interact"]:
		Input.action_release(a)
	if main.state == Main.State.PLAYING:
		var lv: Level = main.level
		var p := lv.player
		if lv.ore.size() > 0:
			if p.in_buggy:
				lv.toggle_buggy()
			else:
				p.position = lv.ore[0]["pos"]
				p.velocity = Vector2.ZERO
		elif not p.in_buggy:
			if p.position.distance_to(lv.buggy.position) > 30.0:
				p.position = lv.buggy.position + Vector2(0, -12)
				p.velocity = Vector2.ZERO
			if p.is_on_floor():
				lv.toggle_buggy()
		else:
			Input.action_press("move_right")
	if main.state == Main.State.WON:
		print("PASS: all %d shafts cleared, %d credits, %d miners left" % [Levels.DATA.size(), main.score, main.lives])
		quit(0)
	elif main.state == Main.State.GAMEOVER or t > 900.0:
		printerr("FAIL: state %d in shaft %d after %.0f s" % [main.state, main.level_index, t])
		quit(1)
	return false
