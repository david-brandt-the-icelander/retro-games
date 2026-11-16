extends SceneTree
## Headless smoke test for the player-facing command paths.
## Run: godot --headless --fixed-fps 30 --path . -s tests/selftest.gd

var failures := 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await process_frame


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	_run.call_deferred()


func _run() -> void:
	await frames(10)
	var game = root.get_node("Game")
	var w = game.world
	var ctrl = w.controller
	var hud = w.hud
	var hq = game.get_hq(0)
	check(hq != null, "player HQ exists")
	var con = null
	var troopers := []
	for e in game.entities:
		if e.team == 0 and e.kind == "constructor":
			con = e
		if e.team == 0 and e.kind == "trooper":
			troopers.append(e)
	check(con != null and troopers.size() == 2, "starting constructor and troopers")

	# picking & ground projection
	var cam: Camera3D = w.camera_rig.cam
	var target := Vector3(-70, 0, 72)
	target.y = w.height_at(target.x, target.z)
	var gp = ctrl.ground_point(cam.unproject_position(target))
	check(gp != null and gp.distance_to(target) < 1.5, "ground_point round-trips (%s)" % str(gp))
	var picked = ctrl.pick_entity(cam.unproject_position(hq.position + Vector3(0, hq.aim_height(), 0)))
	check(picked == hq, "pick_entity finds HQ")

	# command card
	ctrl._set_selection([con])
	hud._refresh()
	check(hud.cmd_buttons.size() == 7, "constructor command card has 7 buttons (%d)" % hud.cmd_buttons.size())

	# place a pump jack on the nearest well and a barracks
	var well = game.free_well_near(Vector3(-60, 0, 58), 4.0)
	ctrl.begin_placement("derrick")
	var dp = game.placement_pos(0, "derrick", well["pos"])
	check(dp != null, "derrick placement valid on well")
	ctrl.ghost_valid = true
	ctrl.ghost_pos = dp
	ctrl._try_place(false)
	check(ctrl.place_kind == "", "placement mode ends after click")
	var site = well["owner"]
	check(game.alive(site) and not site.complete, "derrick site created and owns the well")
	check(con.state == 4, "constructor ordered to build")
	var bad = game.placement_pos(0, "barracks", Vector3(60, 0, -60))
	check(bad == null and game.last_place_error != "", "placement rejected far from base: " + game.last_place_error)
	var bp = null
	for dx in [14, -14, 18]:
		bp = game.placement_pos(0, "barracks", hq.position + Vector3(dx, 0, 4))
		if bp != null:
			break
	check(bp != null, "barracks spot found near HQ")
	var fuel_before: float = game.fuel[0]
	var bsite = game.place_building(0, "barracks", bp)
	check(bsite != null and game.fuel[0] == fuel_before - 160, "barracks costs 160")

	# orders
	ctrl._set_selection(troopers)
	ctrl._formation_move(troopers, Vector3(-60, 0, 60), false)
	check(troopers[0].state == 1, "troopers moving")
	ctrl._set_selection([hq])
	hud._refresh()
	hud.trigger_hotkey(0)
	check(hq.queue.size() == 1, "hotkey Z queues a constructor at HQ")
	hq.cancel_last()
	check(hq.queue.is_empty(), "cancel refunds queue")

	await frames(400)
	check(site.complete, "pump jack finished building")
	check(game.income_of(0) > 9.0, "income includes pump jack (%.0f/s)" % game.income_of(0))
	var t0: Vector3 = troopers[0].position
	check(Vector2(t0.x + 60, t0.z - 60).length() < 6.0, "troopers arrived (%s)" % str(t0))
	con.cmd_build(bsite)
	await frames(500)
	check(bsite.complete, "barracks finished")
	check(bsite.enqueue("trooper"), "barracks accepts a trooper order")

	# combat: drop an enemy tank next to our troopers
	var enemy = w.spawn_unit("tank", 1, Vector3(-58, 0, 66))
	await frames(300)
	check(not game.alive(enemy) or enemy.hp < enemy.max_hp, "troopers auto-engage enemy tank")

	print("SELFTEST ", "PASSED" if failures == 0 else "FAILED (%d)" % failures)
	quit(1 if failures > 0 else 0)
