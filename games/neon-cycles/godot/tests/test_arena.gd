extends SceneTree
## Run with: godot --headless --path godot -s tests/test_arena.gd
## Checks the arena's collision and ray rules, then plays rounds with every rider on autopilot.

const MainScript := preload("res://scripts/main.gd")

var failures := 0
var main: Node3D
var frames := 0
var rounds_seen := 0
var last_round := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok  ", what)
	else:
		failures += 1
		printerr("  FAIL ", what)


func _init() -> void:
	Engine.time_scale = 4.0
	Engine.max_physics_steps_per_frame = 16
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)


func _rules() -> void:
	# A fresh round: four riders, each at its spawn, nobody's trail in the way.
	check(main.cycles.size() == 4, "four riders")
	check(main.player != null and main.player.is_player, "the first rider is the player")
	var far: float = main.ray_distance(Vector2(0, 0), Vector2(1, 0), 500.0)
	check(is_equal_approx(far, main.ARENA_HALF), "a ray from the centre stops at the arena wall")
	# A wall across the ray stops it at the wall's near side.
	var c: LightCycle = main.cycles[1]
	c.walls.append(Rect2(Vector2(20, -10), Vector2(2, 20)))
	check(is_equal_approx(main.ray_distance(Vector2(0, 0), Vector2(1, 0), 500.0), 20.0), "a ray stops at a trail wall")
	check(main.ray_distance(Vector2(21, 0), Vector2(1, 0), 500.0) == 0.0, "a ray starting inside a wall goes nowhere")
	# A sweep crossing that wall hits it; one beside it does not.
	check(main._sweep_hits(main.player, Vector3(15, 0, 0), Vector3(25, 0, 0)), "a sweep through a wall hits it")
	check(not main._sweep_hits(main.player, Vector3(15, 0, 30), Vector3(25, 0, 30)), "a sweep beside a wall misses it")
	c.walls.clear()
	# Turning: left of forward is -X, and two lefts face back.
	var p: LightCycle = main.player
	p.active = true
	var d0 := p.dir
	p.turn(1)
	check(p.dir.is_equal_approx(d0.rotated(Vector3.UP, PI * 0.5).round()), "a left turn turns 90 degrees left")
	check(p.walls.size() == 1, "a turn closes the trail segment behind it")
	p.active = false


func _process(_delta: float) -> bool:
	frames += 1
	if frames == 2:
		_rules()
		main._start_round()
		# Autopilot for the player too, so rounds end on their own.
		main.player.is_player = false
	elif frames > 2:
		if main.player != null and main.player.is_player:
			main.player.is_player = false
		if main.round_num != last_round:
			last_round = main.round_num
			rounds_seen += 1
	if rounds_seen >= 3 or Time.get_ticks_msec() > 180000:
		check(rounds_seen >= 3, "rounds play to an end and the next one starts (%d seen)" % rounds_seen)
		var total := 0
		for k in main.scores:
			total += main.scores[k]
		check(total >= 1, "a round winner scores")
		print("%d failure(s)" % failures)
		quit(1 if failures else 0)
	return false
