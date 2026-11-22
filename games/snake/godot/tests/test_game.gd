extends SceneTree
## Headless checks of the game's rules: godot --headless --path godot -s tests/test_game.gd
## Drives the real main scene tick by tick (no frames, no input devices).

var failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var cases := ["moves_one_cell_per_tick", "eating_grows_scores_and_respawns", "combo_multiplies",
		"no_reversing_and_buffered_turns", "wall_kills", "biting_yourself_kills", "tail_cell_is_free",
		"tall_window_gets_tall_grid"]
	for c in cases:
		var game := _fresh()
		# A case returns true when it ran to the end; a script error inside it returns null.
		if call(c, game) != true:
			failures += 1
			push_error("FAILED: %s stopped early" % c)
		game.queue_free()
		await process_frame
	print("%d failure(s)" % failures if failures else "all %d passed" % cases.size())
	quit(1 if failures else 0)


func _fresh() -> Node:
	var game: Node = load("res://main.tscn").instantiate()
	root.add_child(game)
	game._start()
	return game


func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		push_error("FAILED: " + what)


func moves_one_cell_per_tick(g: Node) -> bool:
	g.food = Vector2i(0, 0)
	var head: Vector2i = g.snake[0]
	g._step()
	_check(g.snake[0] == head + Vector2i.RIGHT, "the head moves right")
	_check(g.snake.size() == 4, "the length stays 4")
	return true


func eating_grows_scores_and_respawns(g: Node) -> bool:
	g.food = g.snake[0] + Vector2i.RIGHT
	g._step()
	_check(g.score == 10, "an orb scores 10, got %d" % g.score)
	_check(g.food not in g.snake, "the new orb is on a free cell")
	g.food = Vector2i(0, 0)
	g._step()
	_check(g.snake.size() == 5, "the snake grows by one, got %d" % g.snake.size())
	_check(g.step_time < g.START_STEP, "the game speeds up")
	return true


func combo_multiplies(g: Node) -> bool:
	g.food = g.snake[0] + Vector2i.RIGHT
	g._step()
	g.food = g.snake[0] + Vector2i.RIGHT
	g._step()
	_check(g.score == 10 + 20, "a quick second orb scores ×2, got %d" % g.score)
	return true


func no_reversing_and_buffered_turns(g: Node) -> bool:
	g.food = Vector2i(0, 0)
	g._push_dir(Vector2i.LEFT)
	_check(g.dir_queue.is_empty(), "reversing is ignored")
	g._push_dir(Vector2i.UP)
	g._push_dir(Vector2i.LEFT)
	_check(g.dir_queue.size() == 2, "a quick up-then-left is kept")
	var head: Vector2i = g.snake[0]
	g._step()
	g._step()
	_check(g.snake[0] == head + Vector2i(-1, -1), "both turns are taken, one per tick")
	return true


func wall_kills(g: Node) -> bool:
	g.food = Vector2i(0, 0)
	g.dir = Vector2i.UP
	for i in g.rows + 1:
		if g.state != g.State.PLAYING:
			break
		g._step()
	_check(g.state == g.State.DEAD, "running into the wall ends the game")
	return true


func biting_yourself_kills(g: Node) -> bool:
	g.food = Vector2i(0, 0)
	var h := Vector2i(5, 5)
	g.snake.assign([h, h + Vector2i(1, 0), h + Vector2i(1, 1), h + Vector2i(0, 1), h + Vector2i(-1, 1), h + Vector2i(-1, 0)])
	g.prev_snake.assign(g.snake)
	g.dir = Vector2i.DOWN
	g._step()
	_check(g.state == g.State.DEAD, "turning into your own body ends the game")
	return true


func tail_cell_is_free(g: Node) -> bool:
	g.food = Vector2i(0, 0)
	var h := Vector2i(5, 5)
	g.snake.assign([h, h + Vector2i(1, 0), h + Vector2i(1, 1), h + Vector2i(0, 1)])
	g.prev_snake.assign(g.snake)
	g.dir = Vector2i.DOWN
	g._step()
	_check(g.state == g.State.PLAYING, "chasing your own tail is allowed: the tail moves away")
	return true


func tall_window_gets_tall_grid(g: Node) -> bool:
	g.view = Vector2(720, 1500)
	root.content_scale_size = Vector2i(720, 1500)
	root.size = Vector2i(720, 1500)
	g._layout(true)
	_check(g.rows > g.cols, "a tall window gets a tall board (%dx%d)" % [g.cols, g.rows])
	_check(g.origin.x >= 0.0 and g.origin.x + g.cols * g.cell <= 720.0, "the board fits across")
	return true
