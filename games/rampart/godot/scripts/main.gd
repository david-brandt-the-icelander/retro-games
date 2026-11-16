extends Node3D
## Scene root: environment, camera, game flow.

const PlayerScript = preload("res://scripts/player.gd")
const LevelScript = preload("res://scripts/level.gd")
const HudScript = preload("res://scripts/hud.gd")
const BossScript = preload("res://scripts/boss.gd")
const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const SKY_SHADER = preload("res://shaders/sky.gdshader")

const CAM_OFFSET := Vector3(-19.0, 25.0, 21.0)

var camera: Camera3D
var player
var level
var hud
var boss = null
var sun: DirectionalLight3D
var starfield: CPUParticles3D
var cam_target: Vector3 = Vector3.ZERO
var respawn_timer: float = -1.0
var clear_timer: float = -1.0
var over_timer: float = 0.0
var fuel_alarm: float = 0.0
var last_section: String = ""
var shot_dir: String = ""
var shot_times: Array = [3.0, 7.0, 11.0]
var elapsed: float = 0.0
var goto_chunk: int = 0


func _ready() -> void:
	process_priority = 100  # run after the ship moves so the camera never lags a frame
	Game.world = self
	_setup_environment()
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.5
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	level = LevelScript.new()
	add_child(level)
	player = PlayerScript.new()
	add_child(player)
	Game.player = player
	player.died.connect(_on_player_died)
	level.boss_trigger.connect(_on_boss_trigger)
	hud = HudScript.new()
	add_child(hud)
	_make_starfield()
	_enter_title()
	for a in OS.get_cmdline_user_args():
		if a == "--autoplay":
			Game.autopilot = true
		elif a.begins_with("--goto="):
			goto_chunk = int(a.substr(7))
		elif a.begins_with("--shots="):
			shot_dir = a.substr(8)
	if Game.autopilot:
		_start_game.call_deferred()


func _setup_environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = SKY_SHADER
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.4, 0.58)
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.1
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 0.9
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 0.8)
	env.set_glow_level(3, 0.6)
	env.set_glow_level(4, 0.4)
	env.set_glow_level(5, 0.2)
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.07, 0.15)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -35.0, 0.0)
	sun.light_energy = 1.35
	sun.light_color = Color(1.0, 0.95, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 95.0
	sun.shadow_blur = 1.5
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -150.0, 0.0)
	fill.light_energy = 0.35
	fill.light_color = Color(0.4, 0.6, 1.0)
	add_child(fill)


func _make_starfield() -> void:
	starfield = CPUParticles3D.new()
	starfield.amount = 700
	starfield.lifetime = 7.0
	starfield.preprocess = 7.0
	starfield.local_coords = false
	starfield.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	starfield.emission_box_extents = Vector3(45.0, 14.0, 70.0)
	starfield.direction = Vector3(0, 0, 1)
	starfield.spread = 0.0
	starfield.initial_velocity_min = 0.0
	starfield.initial_velocity_max = 0.0
	starfield.gravity = Vector3.ZERO
	var sm := T.sphere(0.11, 4)
	sm.material = M.add(Color(1, 1, 1), 4.0, 0, true)
	starfield.mesh = sm
	starfield.scale_amount_min = 0.5
	starfield.scale_amount_max = 1.6
	starfield.color_ramp = M.gradient([Color(0.7, 0.8, 1.0, 0.0), Color(0.8, 0.9, 1.0, 1.0), Color(0.8, 0.9, 1.0, 1.0), Color(0.7, 0.8, 1.0, 0.0)])
	starfield.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(starfield)
	starfield.emitting = true


# --- flow --------------------------------------------------------------------

func _speed_for(l: int) -> float:
	return minf(15.0 + (l - 1) * 2.0, 24.0)


func _clear_dynamic() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = null
	Game.boss = null
	for s in get_tree().get_nodes_in_group("enemy_shot"):
		s.queue_free()


func _enter_title() -> void:
	Game.state = Game.State.TITLE
	_clear_dynamic()
	level.start(1, 0.0)
	player.reset_to(Vector3(0, 3.5, 0))
	player.speed_forward = 14.0
	player.set_active(false)
	cam_target = Vector3(0, 2.5, -7)
	hud.show_title()


func _start_game() -> void:
	get_tree().paused = false
	Game.new_game()
	_clear_dynamic()
	var z: float = player.global_position.z
	level.start(1, z)
	level.plan_index = goto_chunk
	player.speed_forward = _speed_for(1)
	player.reset_to(Vector3(0, 3.5, z))
	player.set_active(true)
	respawn_timer = -1.0
	clear_timer = -1.0
	last_section = ""
	Game.state = Game.State.PLAYING
	hud.show_game()
	hud.message("LEVEL 1", "BREACH THE FORTRESS", 2.5)
	Sfx.play("start", -4.0)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start") or event.is_action_pressed("fire"):
		if Game.state == Game.State.TITLE:
			_start_game()
		elif Game.state == Game.State.GAME_OVER and over_timer > 1.2:
			_start_game()


func _on_player_died() -> void:
	Game.lives -= 1
	Game.state = Game.State.DYING
	respawn_timer = 2.4


func _respawn() -> void:
	for s in get_tree().get_nodes_in_group("enemy_shot"):
		s.queue_free()
	Game.fuel = 100.0
	player.respawn()
	Game.state = Game.State.PLAYING
	hud.message("READY", "", 1.2)


func _game_over() -> void:
	Game.state = Game.State.GAME_OVER
	over_timer = 0.0
	Game.save_hi()
	hud.show_game_over()


func _on_boss_trigger() -> void:
	if boss != null:
		return
	boss = BossScript.new()
	boss.lvl = Game.level
	boss.position = player.global_position + Vector3(0, 4, -90)
	add_child(boss)
	Game.boss = boss
	boss.defeated.connect(_on_boss_defeated)


func _on_boss_defeated() -> void:
	boss = null
	Game.boss = null
	if Game.state == Game.State.PLAYING or Game.state == Game.State.DYING:
		hud.message("WARDEN DESTROYED", "CITADEL BREACHED", 3.0)
		clear_timer = 3.5


func _next_level() -> void:
	Game.level += 1
	level.next_level(Game.level)
	player.speed_forward = _speed_for(Game.level)
	Game.add_fuel(50.0)
	hud.message("LEVEL %d" % Game.level, "THE NEXT FORTRESS AWAITS", 2.5)


# --- per frame ---------------------------------------------------------------

func _process(delta: float) -> void:
	elapsed += delta
	if shot_dir != "" and shot_times.size() > 0 and elapsed >= float(shot_times[0]):
		shot_times.pop_front()
		get_viewport().get_texture().get_image().save_png("%s/shot_%02d.png" % [shot_dir, int(elapsed)])
		if shot_times.is_empty():
			get_tree().quit()
	var pz: float = player.global_position.z
	level.update(pz)
	player.over_floor = level.is_floor_at(pz)
	_update_camera(delta)
	starfield.global_position = Vector3(0, -24, pz - 60)
	_update_section(pz)

	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			if Game.lives > 0:
				_respawn()
			else:
				_game_over()
	if clear_timer > 0.0:
		clear_timer -= delta
		if clear_timer <= 0.0:
			_next_level()
	if Game.state == Game.State.GAME_OVER:
		over_timer += delta
	if Game.state == Game.State.PLAYING and player.alive and Game.fuel < 25.0:
		fuel_alarm -= delta
		if fuel_alarm <= 0.0:
			fuel_alarm = 0.9
			Sfx.play("alarm", -10.0)

	var boss_ratio := -1.0
	if boss != null and is_instance_valid(boss):
		boss_ratio = boss.health_ratio()
	hud.update_hud(player.position.y, boss_ratio)


func _update_camera(delta: float) -> void:
	var p: Vector3 = player.global_position
	var desired := Vector3(p.x * 0.6, 1.5 + p.y * 0.3, p.z - 9.0)
	cam_target.x = lerpf(cam_target.x, desired.x, 1.0 - exp(-4.0 * delta))
	cam_target.y = lerpf(cam_target.y, desired.y, 1.0 - exp(-3.0 * delta))
	cam_target.z = desired.z
	var shake := Vector3.ZERO
	if Game.shake_amount > 0.0:
		shake = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * Game.shake_amount
		Game.shake_amount = maxf(0.0, Game.shake_amount - delta * 2.0)
	camera.global_position = cam_target + CAM_OFFSET + shake
	camera.look_at(cam_target + shake * 0.4, Vector3.UP)


func _section_name(s: String) -> String:
	match s:
		"gate", "fortress", "exit":
			return "FORTRESS"
		"space":
			return "OPEN SPACE"
		"citadel", "arena":
			return "CITADEL"
	return "APPROACH"


func _update_section(pz: float) -> void:
	var sname := _section_name(level.section_at(pz))
	if sname == last_section:
		return
	if Game.state == Game.State.PLAYING and last_section != "":
		match sname:
			"FORTRESS":
				hud.message("FORTRESS", "WATCH YOUR ALTITUDE", 2.0)
			"OPEN SPACE":
				hud.message("OPEN SPACE", "INTERCEPTORS INBOUND", 2.0)
			"CITADEL":
				if boss == null:
					hud.message("THE CITADEL", "DESTROY THE WARDEN'S CORE", 2.5)
	last_section = sname
	hud.set_section(sname)
