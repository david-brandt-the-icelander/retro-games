extends Node3D
## Entry point: scene dressing, input, cursor, and the game-state machine.
## Command-line test switches (after `--`): --autoplay --play --level=N
## --seed=N --speed=N --shot=path.png --shot-time=S --quit-after=S

var world: World
var hud: Hud
var rig: CameraRig
var rival: RivalAI
var stand_in: RivalAI          # plays the blue side in attract / autoplay mode
var state := "title"           # title | play | over
var paused := false
var speed := 1.0
var power := 0
var level := 1

var _cursor := Node3D.new()
var _ring := MeshInstance3D.new()
var _ring_mat := StandardMaterial3D.new()
var _pin := MeshInstance3D.new()
var _hover: Variant = null
var _hold := 0
var _hold_t := 0.0
var _hud_t := 0.0
var _toast_t := 0.0
var _last_err := ""
var _restart_t := -1.0
var _args := {}
var _log_t := 0.0
var _clock := 0.0
var _sim_time := 0.0
var _sim_cost := 0.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=")
		_args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	level = int(_args.get("level", "1"))
	_build_environment()
	rig = CameraRig.new()
	add_child(rig)
	hud = Hud.new()
	add_child(hud)
	hud.power_chosen.connect(_select_power)
	hud.behavior_chosen.connect(_select_behavior)
	hud.start_requested.connect(_start)
	hud.restart_requested.connect(func(): _start(level))
	_build_cursor()
	if _args.has("autoplay"):
		hud.hide_title()
		state = "over"
		_new_world(int(_args.get("seed", "7")), true)
		state = "autoplay"
	elif _args.has("play"):
		_start(level)
	else:
		_new_world(randi(), true)
	speed = float(_args.get("speed", "1"))
	if _args.has("zoom"):
		var foe: bool = _args.get("focus", "") == "red"
		var p := Vector3(38, 2, 24) if foe else _home_point()
		rig.look_at_point(p, float(_args["zoom"]))


func _new_world(seed_value: int, attract: bool) -> void:
	if world:
		world.queue_free()
	world = World.new()
	add_child(world)
	world.message.connect(_on_message)
	world.game_over.connect(_on_game_over)
	world.shake.connect(func(a: float): rig.shake = maxf(rig.shake, a))
	world.terrain.reveal_all = attract
	world.start(seed_value)
	rival = RivalAI.new(world, 1, level)
	stand_in = RivalAI.new(world, 0, 1) if attract else null
	paused = false
	_restart_t = -1.0
	rig.look_at_point(Vector3(Terrain.N * 0.5, 2, Terrain.N * 0.5), 46.0 if attract else 30.0)
	if not attract:
		var home := _home_point()
		rig.look_at_point(home, 28.0)


func _start(lvl: int) -> void:
	level = lvl
	state = "play"
	hud.hide_title()
	hud.hide_end()
	_new_world(int(_args.get("seed", str(randi()))), false)
	_select_power(0)
	_select_behavior(World.SETTLE)
	hud.toast("Your followers await. Flatten the land so they can build.", Hud.ACCENT)


func _home_point() -> Vector3:
	var sum := Vector2.ZERO
	var n := 0
	for w in world.walkers:
		if w.team == 0:
			sum += w.gp
			n += 1
	for s in world.settlements:
		if s.team == 0:
			sum += Vector2(s.tile)
			n += 1
	if n == 0:
		return Vector3(Terrain.N * 0.5, 2, Terrain.N * 0.5)
	var p := sum / n
	return Vector3(p.x, world.terrain.height_at(p), p.y)


# ------------------------------------------------------------- scene dress
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.24, 0.42, 0.72)
	psm.sky_horizon_color = Color(0.72, 0.8, 0.88)
	psm.ground_horizon_color = Color(0.5, 0.6, 0.7)
	psm.ground_bottom_color = Color(0.08, 0.13, 0.2)
	psm.sun_angle_max = 20.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.2
	env.adjustment_contrast = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.6, 0.7, 0.82)
	env.fog_density = 0.004
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -38, 0)
	sun.light_energy = 1.25
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	var sea := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(900, 900)
	sea.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.03, 0.12, 0.22)
	sm.roughness = 0.3
	sm.metallic = 0.2
	sea.material_override = sm
	sea.position = Vector3(Terrain.N * 0.5, Terrain.BASE_Y - 0.4, Terrain.N * 0.5)
	add_child(sea)


func _build_cursor() -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 48
	_ring.mesh = tor
	_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_mat.no_depth_test = true
	_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_mat.albedo_color = Color(1, 0.85, 0.4, 0.85)
	_ring.material_override = _ring_mat
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cursor.add_child(_ring)
	var sp := SphereMesh.new()
	sp.radius = 0.09
	sp.height = 0.18
	_pin.mesh = sp
	_pin.material_override = _ring_mat
	_cursor.add_child(_pin)
	_cursor.visible = false
	add_child(_cursor)


# ------------------------------------------------------------------- input
func _select_power(i: int) -> void:
	power = i
	hud.select_power(i)


func _select_behavior(b: int) -> void:
	if not world:
		return
	world.behavior[0] = b
	hud.select_behavior(b)
	if b == World.GATHER and world.beacon[0] == null:
		hud.toast("Plant a Beacon (2) so your people know where to gather.", Hud.ACCENT)


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and not e.pressed:
		if e.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			_hold = 0


func _unhandled_input(e: InputEvent) -> void:
	if state != "play":
		return
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_LEFT:
			_hold = 1 if power == 0 else 0
			_hold_t = 0.22
			_act(false)
		elif e.button_index == MOUSE_BUTTON_RIGHT:
			if power == 0:
				_hold = 2
				_hold_t = 0.22
				_act(true)
			else:
				_select_power(0)
	elif e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8:
				_select_power(e.keycode - KEY_1)
			KEY_Z:
				_select_behavior(World.SETTLE)
			KEY_X:
				_select_behavior(World.GATHER)
			KEY_C:
				_select_behavior(World.CRUSADE)
			KEY_SPACE:
				paused = not paused
			KEY_F:
				speed = 3.0 if speed == 1.0 else 1.0
			KEY_H:
				hud.toggle_help()
			KEY_HOME:
				rig.look_at_point(_home_point(), 28.0)
			KEY_ESCAPE:
				if hud.help_visible():
					hud.toggle_help()
				else:
					_select_power(0)


func _act(alt: bool) -> void:
	if _hover == null or paused:
		return
	var err := world.cast(0, power, _hover, alt)
	if err != "":
		if err != _last_err or _toast_t <= 0.0:
			hud.toast(err, Color(1, 0.7, 0.6))
			_last_err = err
			_toast_t = 1.2
		return
	if power != 0 and not Input.is_key_pressed(KEY_SHIFT):
		_select_power(0)


# -------------------------------------------------------------------- loop
func _process(delta: float) -> void:
	_clock += delta
	_toast_t -= delta
	_update_hover()
	var running := not paused and not hud.help_visible() and state != "over"
	if running and world:
		var dt := minf(delta, 0.1) * speed
		var t0 := Time.get_ticks_usec()
		_sim_time += dt
		while dt > 0.0:
			var sub := minf(dt, 0.05)
			dt -= sub
			world.step(sub)
			rival.tick(sub)
			if stand_in:
				stand_in.tick(sub)
			if state == "play" and _hold > 0 and power == 0:
				_hold_t -= sub / speed
				if _hold_t <= 0.0:
					_hold_t = 0.12
					_act(_hold == 2)
		_sim_cost += (Time.get_ticks_usec() - t0) / 1e6
	if world:
		world.animate(delta)
	if _restart_t > 0.0:
		_restart_t -= delta
		if _restart_t <= 0.0:
			_new_world(randi(), true)
	_hud_t -= delta
	if _hud_t <= 0.0 and world:
		_hud_t = 0.1
		hud.update_stats(world, paused, speed)
	_test_hooks(delta)


func _update_hover() -> void:
	_hover = null
	_cursor.visible = false
	if state != "play" or world == null:
		return
	var mp := get_viewport().get_mouse_position()
	if _args.has("cursor"):
		mp = get_viewport().get_visible_rect().size * Vector2(0.55, 0.45)
	var hit = world.terrain.raycast(rig.cam.project_ray_origin(mp), rig.cam.project_ray_normal(mp))
	if hit == null:
		return
	_hover = hit
	_cursor.visible = true
	var pw: Dictionary = World.POWERS[power]
	var ok: bool = world.mana[0] >= pw.cost
	if power == 0:
		var v := Vector2i(roundi(hit.x), roundi(hit.z))
		ok = ok and world.vertex_in_influence(v, 0)
		_cursor.position = Vector3(v.x, world.terrain.vh(v.x, v.y) * Terrain.HSTEP, v.y)
		_pin.visible = true
		_ring.scale = Vector3(0.45, 1, 0.45)
	else:
		_cursor.position = hit
		_pin.visible = false
		var r: float = maxf(0.8, pw.radius)
		_ring.scale = Vector3(r, 1, r)
	_ring.position.y = 0.05
	_ring_mat.albedo_color = Color(1, 0.85, 0.4, 0.9) if ok else Color(1, 0.35, 0.3, 0.8)


# --------------------------------------------------------------- reactions
func _on_message(text: String, team: int) -> void:
	if state == "autoplay":
		print("[autoplay]   %.0fs: %s" % [world.elapsed, text])
	if state == "play":
		hud.toast(text, Walker.team_color(team).lightened(0.4))


func _on_game_over(winner: int) -> void:
	if state == "title":
		_restart_t = 4.0
		return
	if state == "autoplay":
		print("[autoplay] game over at %.0fs, winner team %d" % [world.elapsed, winner])
		get_tree().quit()
		return
	state = "over"
	var t := int(world.elapsed)
	var s0: Dictionary = world.stats[0]
	var body := "%s after %d:%02d.\nBattles won: %d · Homes razed: %d" % [
		"The rival god's people are no more" if winner == 0 else "Your last follower has fallen",
		t / 60, t % 60, s0.get("kills", 0), s0.get("razed", 0)]
	hud.show_end(winner == 0, body)


# ------------------------------------------------------------- test hooks
func _test_hooks(delta: float) -> void:
	if world and _args.has("autoplay"):
		_log_t -= delta * speed
		if _log_t <= 0.0:
			_log_t = 30.0
			var tiers := [0, 0, 0, 0, 0, 0, 0, 0]
			for s in world.settlements:
				tiers[s.team * 4 + s.tier] += 1
			print("[autoplay] t=%4.0fs  blue %4d (w%d s%d, huts %d houses %d castles %d, faith %d)  red %4d (w%d s%d, huts %d houses %d castles %d, faith %d)  sea %d" % [
				world.elapsed, world.team_total(0), world.count_of(0).x, world.count_of(0).y,
				tiers[1], tiers[2], tiers[3], int(world.mana[0]),
				world.team_total(1), world.count_of(1).x, world.count_of(1).y,
				tiers[5], tiers[6], tiers[7], int(world.mana[1]), world.terrain.water_level])
			print("[autoplay]   sim cost %.1f ms per simulated second" % [1000.0 * _sim_cost / maxf(0.001, _sim_time)])
			_sim_cost = 0.0
			_sim_time = 0.0
	if _args.has("click-test") and _clock > 3.0:
		_args.erase("click-test")
		var vp := get_viewport()
		var mp := vp.get_visible_rect().size * 0.5
		var hit = world.terrain.raycast(rig.cam.project_ray_origin(mp), rig.cam.project_ray_normal(mp))
		var v := Vector2i(roundi(hit.x), roundi(hit.z))
		var before := world.terrain.vh(v.x, v.y)
		var mana_before: float = world.mana[0]
		var mm := InputEventMouseMotion.new()
		mm.position = mp
		Input.parse_input_event(mm)
		for btn in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			for down in [true, false]:
				var mb := InputEventMouseButton.new()
				mb.button_index = btn
				mb.pressed = down
				mb.position = mp
				Input.parse_input_event(mb)
		await get_tree().process_frame
		await get_tree().process_frame
		print("[click-test] vertex %s height %d -> %d, faith %.1f -> %.1f, in influence: %s" % [
			v, before, world.terrain.vh(v.x, v.y), mana_before, world.mana[0], world.vertex_in_influence(v, 0)])
	if _args.has("quit-after") and _clock >= float(_args["quit-after"]):
		print("[test] quit-after reached")
		get_tree().quit()
	if _args.has("shot") and _clock >= float(_args.get("shot-time", "5")):
		var img := get_viewport().get_texture().get_image()
		img.save_png(_args["shot"])
		print("[test] screenshot saved ", _args["shot"])
		_args.erase("shot")
		get_tree().quit()
