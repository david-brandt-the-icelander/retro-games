extends Node3D
## Game flow, world setup, camera and spawning.

const City = preload("res://scripts/city.gd")
const Player = preload("res://scripts/player.gd")
const Hostage = preload("res://scripts/hostage.gd")
const Ant = preload("res://scripts/ant.gd")
const Grenade = preload("res://scripts/grenade.gd")
const Fx = preload("res://scripts/fx.gd")
const Hud = preload("res://scripts/hud.gd")

const GRENADE_GRAVITY := 16.0

enum State { TITLE, PLAYING, LEVEL_DONE, GAME_OVER }

var state := State.TITLE
var level := 1
var score := 0
var kills := 0
var time_left := 150.0

var city
var player
var hostage
var hud
var flow := PackedInt32Array()

var cam: Camera3D
var cam_yaw := PI * 0.25
var _cam_yaw_target := PI * 0.25
var _cam_pitch := deg_to_rad(52.0)
var _cam_dist := 21.0
var _cam_focus := Vector3.ZERO
var _shake := 0.0
var _env: Environment
var _sun: DirectionalLight3D

var _flow_t := 0.0
var _spawn_t := 3.0
var _state_t := 0.0
var _title_angle := 0.0
var _world_root: Node3D


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_setup_environment()
	_world_root = Node3D.new()
	_world_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world_root)
	city = City.new()
	city.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(city)
	city.build_terrain()

	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 900.0
	add_child(cam)

	player = Player.new()
	player.main = self
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(player)
	player.health_changed.connect(_on_player_health)
	player.died.connect(func(): _game_over("YOU WERE OVERRUN"))

	hud = Hud.new()
	add_child(hud)

	_build_level(1)
	_enter_title()


func _setup_input() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "throw": [KEY_F, KEY_CTRL], "rot_left": [KEY_Q], "rot_right": [KEY_E],
		"start": [KEY_ENTER, KEY_KP_ENTER], "pause": [KEY_ESCAPE],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)
	for action in ["throw", "start"]:
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event(action, mb)


func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.20, 0.38, 0.68)
	sky_mat.sky_horizon_color = Color(0.78, 0.66, 0.54)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.82, 0.68, 0.52)
	sky_mat.ground_bottom_color = Color(0.45, 0.35, 0.26)
	sky_mat.sun_angle_max = 12.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat

	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.62, 0.55, 0.52)
	_env.ambient_light_energy = 0.75
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.9
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.04
	_env.glow_hdr_threshold = 1.1
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.86, 0.74, 0.60)
	_env.fog_density = 0.0011
	_env.fog_aerial_perspective = 0.2
	_env.fog_sky_affect = 0.25
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.06
	_env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)

	_sun = DirectionalLight3D.new()
	_sun.rotation = Vector3(deg_to_rad(-36), deg_to_rad(-38), 0)
	_sun.light_color = Color(1.0, 0.88, 0.72)
	_sun.light_energy = 1.45
	_sun.light_angular_distance = 0.0
	_sun.shadow_enabled = true
	_sun.shadow_blur = 2.0
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 70.0
	_sun.directional_shadow_blend_splits = true
	add_child(_sun)


# ------------------------------------------------------------------- levels

func _clear_actors() -> void:
	for n in _world_root.get_children():
		n.queue_free()
	for a in get_tree().get_nodes_in_group("ants"):
		a.remove_from_group("ants")
	hostage = null


func _build_level(n: int) -> void:
	level = n
	_clear_actors()
	city.generate(randi(), level)
	city.build()
	player.reset(city.cell_center(city.start_cell) + Vector3.UP * 0.1)
	hostage = Hostage.new()
	hostage.main = self
	_world_root.add_child(hostage)
	hostage.global_position = city.cell_center(city.hostage_cell) + Vector3.UP * 0.1
	time_left = maxf(90.0, 160.0 - 10.0 * (level - 1))
	flow = city.flow_to(city.cell_of(player.global_position))
	_spawn_t = 2.5
	cam_yaw = PI * 0.25
	_cam_yaw_target = cam_yaw
	_cam_focus = player.global_position
	hud.set_health(player.health)
	hud.set_hostage(100.0, false)
	hud.set_time(time_left)
	hud.set_info(level, score, kills)


func _enter_title() -> void:
	state = State.TITLE
	player.control_enabled = false
	hud.show_title(true)


func _start_game() -> void:
	score = 0
	kills = 0
	_build_level(1)
	_begin_level()


func _begin_level() -> void:
	state = State.PLAYING
	player.control_enabled = true
	hud.show_title(false)
	hud.show_message("LEVEL %d" % level, "Find the hostage and lead them out of the city", 3.0)


func _level_complete() -> void:
	state = State.LEVEL_DONE
	_state_t = 4.0
	player.control_enabled = false
	var bonus := 500 + int(time_left) * 5 + int(hostage.health) * 2
	score += bonus
	hud.set_info(level, score, kills)
	hud.show_message("RESCUED", "+%d   ·   time bonus %ds   ·   level %d next" % [bonus, int(time_left), level + 1], 3.6)


func _game_over(reason: String) -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	_state_t = 1.5
	player.control_enabled = false
	hud.show_message(reason, "Score %d   ·   press ENTER to try again" % score, 0.0)


# -------------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if get_tree().paused:
		return
	match state:
		State.TITLE:
			if Input.is_action_just_pressed("start"):
				_start_game()
		State.PLAYING:
			_update_play(delta)
		State.LEVEL_DONE:
			_state_t -= delta
			if _state_t <= 0.0:
				_build_level(level + 1)
				_begin_level()
		State.GAME_OVER:
			_state_t -= delta
			if _state_t <= 0.0 and Input.is_action_just_pressed("start"):
				_start_game()

	if state != State.TITLE:
		if Input.is_action_just_pressed("rot_left"):
			_cam_yaw_target -= PI / 2
		if Input.is_action_just_pressed("rot_right"):
			_cam_yaw_target += PI / 2
	_update_camera(delta)


func _update_play(delta: float) -> void:
	time_left -= delta
	hud.set_time(time_left)
	if time_left <= 0.0:
		_game_over("OUT OF TIME")
		return

	_flow_t -= delta
	if _flow_t <= 0.0:
		_flow_t = 0.25
		flow = city.flow_to(city.cell_of(player.global_position))

	_spawn_t -= delta
	var alive_ants := get_tree().get_nodes_in_group("ants").size()
	if _spawn_t <= 0.0 and alive_ants < 3 + level * 2:
		_spawn_t = maxf(1.5, 4.5 - level * 0.4)
		_spawn_ant()

	if hostage and not hostage.following:
		var d: Vector3 = hostage.global_position - player.global_position
		if Vector2(d.x, d.z).length() < 1.9 and absf(d.y) < 1.0:
			hostage.start_following()
			hud.set_hostage(hostage.health, true)
			hud.show_message("FOUND YOU", "Get them out through a gate — they'll follow your steps", 3.0)
	elif hostage and hostage.following:
		if city.is_outside(player.global_position) and city.is_outside(hostage.global_position) \
				and player.global_position.distance_to(hostage.global_position) < 8.0:
			_level_complete()


func _spawn_ant() -> void:
	if city.nest_cells.is_empty():
		return
	# Prefer the nest nearest the player that is not right on top of them.
	var cells: Array = city.nest_cells.duplicate()
	cells.shuffle()
	var pick: Vector2i = cells[0]
	for c in cells:
		if city.cell_center(c).distance_to(player.global_position) > 10.0:
			pick = c
			break
	var ant = Ant.new()
	ant.main = self
	ant.city = city
	ant.speed = 4.0 + level * 0.3 + randf() * 0.4
	_world_root.add_child(ant)
	ant.global_position = city.cell_center(pick) + Vector3(randf_range(-0.3, 0.3), 0.2, randf_range(-0.3, 0.3))
	Fx.dust(_world_root, ant.global_position + Vector3.UP * 0.3)


func _update_camera(delta: float) -> void:
	var focus: Vector3
	var dist := _cam_dist
	var pitch := _cam_pitch
	if state == State.TITLE:
		_title_angle += delta * 0.06
		cam_yaw = _title_angle
		_cam_yaw_target = cam_yaw
		focus = Vector3(0, 2, 0)
		dist = 92.0
		pitch = deg_to_rad(34.0)
		_cam_focus = focus
	else:
		cam_yaw = lerp_angle(cam_yaw, _cam_yaw_target, 1.0 - exp(-8.0 * delta))
		focus = player.global_position + Vector3(0, 0.9, 0)
		_cam_focus = _cam_focus.lerp(focus, 1.0 - exp(-7.0 * delta))
	var off := Vector3(sin(cam_yaw) * cos(pitch), sin(pitch), cos(cam_yaw) * cos(pitch)) * dist
	_shake = maxf(_shake - delta * 2.5, 0.0)
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * _shake * 0.6
	cam.global_position = _cam_focus + off + jitter
	cam.look_at(_cam_focus + jitter * 0.5, Vector3.UP)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cam_dist = clampf(_cam_dist - 1.5, 12.0, 36.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cam_dist = clampf(_cam_dist + 1.5, 12.0, 36.0)
	if event.is_action_pressed("pause") and state == State.PLAYING:
		get_tree().paused = not get_tree().paused
		hud.show_message("PAUSED" if get_tree().paused else "", "", 0.0 if get_tree().paused else 0.1)


# ----------------------------------------------------------------- services

func objective_position() -> Vector3:
	if hostage and not hostage.following:
		return hostage.global_position
	var best := Vector3.ZERO
	var bd := INF
	for p in city.exit_points:
		var d: float = p.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = p
	return best


func spawn_grenade(pos: Vector3, vel: Vector3) -> void:
	var g = Grenade.new()
	g.main = self
	g.gravity_scale = GRENADE_GRAVITY / float(ProjectSettings.get_setting("physics/3d/default_gravity"))
	_world_root.add_child(g)
	g.global_position = pos
	g.linear_velocity = vel
	g.angular_velocity = Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8))


func explode_at(pos: Vector3) -> void:
	Fx.explosion(_world_root, pos)
	for a in get_tree().get_nodes_in_group("ants"):
		if a.global_position.distance_to(pos) < 4.2:
			a.die(pos)
	var dp: float = player.global_position.distance_to(pos)
	if dp < 3.5:
		player.hurt(lerpf(30.0, 6.0, dp / 3.5), pos)
	if hostage and hostage.following:
		var dh: float = hostage.global_position.distance_to(pos)
		if dh < 3.5:
			hostage.hurt(lerpf(30.0, 6.0, dh / 3.5), pos)
	_shake = maxf(_shake, clampf(1.4 - dp / 25.0, 0.2, 1.2))


func on_ant_killed(_ant: Node) -> void:
	kills += 1
	score += 50
	hud.set_info(level, score, kills)


func on_hostage_hurt(health: float) -> void:
	hud.set_hostage(health, true)
	if health <= 0.0:
		_game_over("THE HOSTAGE DIDN'T MAKE IT")


func _on_player_health(v: float) -> void:
	if hud == null:
		return
	var prev: float = hud._health.value
	hud.set_health(v)
	if v < prev:
		hud.flash_damage((prev - v) / 25.0)
		_shake = maxf(_shake, 0.5)


# ------------------------------------------------------------ test harness
#   godot --headless --path godot -- --autotest     plays one level through and quits (exit 0 = pass)
#   godot --path godot -- --shots=/tmp/out           renders a few frames to PNGs and quits

func _enter_tree() -> void:
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			_run_autotest.call_deferred()
		elif a.begins_with("--shots="):
			_run_shots.call_deferred(a.substr(8))


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _check(ok: bool, what: String) -> bool:
	print("autotest: %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		get_tree().quit(1)
	return ok


func _run_autotest() -> void:
	for round in 3:
		_start_game()
		await _wait(0.5)
		player.health = 1.0e6
		var fwd: PackedInt32Array = city.reach_from(city.start_cell)
		var back: PackedInt32Array = city.flow_to(city.start_cell)
		var hi: int = city.idx(city.hostage_cell)
		if not _check(fwd[hi] >= 0 and back[hi] >= 0, "hostage can be reached and can get out"): return
		if not _check(city.nest_cells.size() > 0, "the city has ant nests"): return
		if not _check(state == State.PLAYING, "the level starts"): return

		player.global_position = hostage.global_position + Vector3(1.0, 0.3, 0.0)
		await _wait(0.5)
		if not _check(hostage.following, "the hostage follows once reached"): return

		for i in 4:
			var ant = Ant.new()
			ant.main = self
			ant.city = city
			_world_root.add_child(ant)
			ant.global_position = player.global_position + Vector3(4.0 + i, 3.0, 0.0)
		await _wait(2.0)
		var ants := get_tree().get_nodes_in_group("ants")
		if not _check(ants.size() >= 4, "ants are alive and moving"): return
		var before := kills
		explode_at((ants[0] as Node3D).global_position)
		if not _check(kills > before, "a grenade blast kills ants"): return
		spawn_grenade(player.global_position + Vector3(0, 2, 0), Vector3(3, 4, 0))
		await _wait(2.2)
		if not _check(get_tree().get_nodes_in_group("grenades").is_empty(), "a thrown grenade explodes on its fuse"): return

		var exit: Vector3 = city.exit_points[0]
		player.global_position = exit + Vector3(0, 0.3, 0)
		hostage.global_position = exit + Vector3(1.5, 0.3, 0)
		await _wait(0.5)
		if not _check(state == State.LEVEL_DONE, "leading the hostage out completes the level"): return
		await _wait(4.5)
		if not _check(state == State.PLAYING and level == 2, "the next level starts"): return
	print("autotest: passed")
	get_tree().quit(0)


func _snap(dir: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, name])
	print("shot ", name)


func _run_shots(dir: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	await _wait(2.5)
	await _snap(dir, "1_title")
	_start_game()
	await _wait(1.0)
	await _snap(dir, "2_start")
	player.global_position = hostage.global_position + Vector3(2.5, 0.5, 2.5)
	_cam_focus = player.global_position
	for i in 5:
		var ant = Ant.new()
		ant.main = self
		ant.city = city
		_world_root.add_child(ant)
		ant.global_position = player.global_position + Vector3(randf_range(-9, 9), 4, randf_range(-9, 9))
	await _wait(2.0)
	await _snap(dir, "3_ants")
	var ants := get_tree().get_nodes_in_group("ants")
	if ants.size() > 0:
		explode_at((ants[0] as Node3D).global_position + Vector3(0, 0.5, 0))
	await _wait(0.25)
	await _snap(dir, "4_explosion")
	get_tree().quit()
