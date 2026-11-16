extends Node3D
## Neon Cycles — game controller. Builds the arena, lighting, camera and HUD
## procedurally, runs rounds and resolves collisions.

const LightCycleScript := preload("res://scripts/light_cycle.gd")
const MinimapScript := preload("res://scripts/minimap.gd")
const WALL_SHADER := preload("res://shaders/light_wall.gdshader")
const FLOOR_SHADER := preload("res://shaders/grid_floor.gdshader")

const ARENA_HALF := 100.0
const WINS_TO_MATCH := 5

const RIDERS := [
	{"name": "YOU", "color": Color(0.0, 0.86, 1.0)},
	{"name": "RINZLER", "color": Color(1.0, 0.42, 0.04)},
	{"name": "SARK", "color": Color(1.0, 0.12, 0.55)},
	{"name": "CLU", "color": Color(0.95, 0.85, 0.1)},
]

enum State { COUNTDOWN, PLAYING, ROUND_OVER, MATCH_OVER, PAUSED }

var cycles: Array[LightCycle] = []
var player: LightCycle
var scores := {}
var round_num := 0

var _state := State.COUNTDOWN
var _state_before_pause := State.PLAYING
var _timer := 0.0
var _world: Node3D
var _trails: Node3D
var _camera: Camera3D
var _cam_shake := 0.0
var _orbit_angle := 0.0
var _spectate: LightCycle
var _cam_dir := Vector3.FORWARD
var _cam_follow: LightCycle
var _cam_blend := 1.0

# HUD
var _hud: CanvasLayer
var _center_label: Label
var _sub_label: Label
var _score_box: VBoxContainer
var _speed_label: Label
var _boost_bar: ProgressBar
var _minimap: Control


func _ready() -> void:
	randomize()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_build_environment()
	_build_arena()
	_build_camera()
	_build_hud()
	for r in RIDERS:
		scores[r.name] = 0
	_start_round()


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _setup_input() -> void:
	_bind("turn_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT])
	_bind("turn_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT])
	_bind("boost", [KEY_SPACE, KEY_W, KEY_UP], [JOY_BUTTON_A])
	_bind("confirm", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START])
	_bind("restart", [KEY_R], [JOY_BUTTON_BACK])
	_bind("pause", [KEY_ESCAPE, KEY_P], [])


func _unhandled_input(event: InputEvent) -> void:
	# Touch: tap the left or right half of the screen to turn.
	if event is InputEventScreenTouch and event.pressed and player != null and player.alive:
		var half := get_viewport().get_visible_rect().size.x * 0.5
		player.turn(1 if event.position.x < half else -1)
	elif event is InputEventScreenTouch and event.pressed and _state in [State.ROUND_OVER, State.MATCH_OVER]:
		Input.action_press("confirm")
		Input.action_release.call_deferred("confirm")


func _bind(action: String, keys: Array, buttons: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var j := InputEventJoypadButton.new()
		j.button_index = b
		InputMap.action_add_event(action, j)


# --------------------------------------------------------------------------
# World construction
# --------------------------------------------------------------------------

func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.004, 0.006, 0.02)
	sky_mat.sky_horizon_color = Color(0.16, 0.05, 0.28)
	sky_mat.ground_horizon_color = Color(0.06, 0.02, 0.12)
	sky_mat.ground_bottom_color = Color(0, 0, 0)
	sky_mat.sky_curve = 0.12
	sky_mat.sky_energy_multiplier = 1.4
	sky_mat.sun_angle_max = 0.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0

	env.glow_enabled = true
	env.glow_normalized = false
	env.glow_intensity = 0.55
	env.glow_strength = 0.95
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.1
	env.glow_hdr_scale = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.6)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.6)
	env.set_glow_level(5, 0.4)
	env.set_glow_level(6, 0.2)

	env.fog_enabled = true
	env.fog_light_color = Color(0.07, 0.03, 0.14)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.15

	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.15

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.45, 0.55, 1.0)
	moon.light_energy = 0.35
	moon.rotation_degrees = Vector3(-55, 30, 0)
	moon.shadow_enabled = true
	add_child(moon)


func _build_arena() -> void:
	_world = Node3D.new()
	_world.name = "World"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_trails = Node3D.new()
	_trails.name = "Trails"
	_world.add_child(_trails)

	# Floor.
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(ARENA_HALF * 8.0, ARENA_HALF * 8.0)
	floor_mi.mesh = plane
	var fmat := ShaderMaterial.new()
	fmat.shader = FLOOR_SHADER
	fmat.set_shader_parameter("arena_half", ARENA_HALF)
	floor_mi.material_override = fmat
	_world.add_child(floor_mi)

	# Boundary walls.
	var bmat := ShaderMaterial.new()
	bmat.shader = WALL_SHADER
	bmat.set_shader_parameter("wall_color", Color(0.55, 0.75, 1.0))
	bmat.set_shader_parameter("energy", 0.9)
	bmat.set_shader_parameter("scan_speed", 0.6)
	var h := 4.0
	var t := 0.6
	var span := ARENA_HALF * 2.0 + t
	var sides := [
		[Vector3(0, h * 0.5, -ARENA_HALF - t * 0.5), Vector3(span, h, t)],
		[Vector3(0, h * 0.5, ARENA_HALF + t * 0.5), Vector3(span, h, t)],
		[Vector3(-ARENA_HALF - t * 0.5, h * 0.5, 0), Vector3(t, h, span)],
		[Vector3(ARENA_HALF + t * 0.5, h * 0.5, 0), Vector3(t, h, span)],
	]
	for s in sides:
		var w := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3.ONE
		w.mesh = b
		w.material_override = bmat
		w.position = s[0]
		w.scale = s[1]
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(w)

	# Corner pylons.
	var pylon_mat := StandardMaterial3D.new()
	pylon_mat.albedo_color = Color(0.9, 0.95, 1.0)
	pylon_mat.emission_enabled = true
	pylon_mat.emission = Color(0.6, 0.8, 1.0)
	pylon_mat.emission_energy_multiplier = 6.0
	for cx in [-1.0, 1.0]:
		for cz in [-1.0, 1.0]:
			var p := MeshInstance3D.new()
			var pb := BoxMesh.new()
			pb.size = Vector3(1.6, 9.0, 1.6)
			p.mesh = pb
			p.material_override = pylon_mat
			p.position = Vector3(cx * (ARENA_HALF + 0.8), 4.5, cz * (ARENA_HALF + 0.8))
			_world.add_child(p)

	_build_skyline()


func _build_skyline() -> void:
	# Distant monoliths with glowing edges give depth and a horizon.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1982
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.015, 0.018, 0.03)
	dark.emission_enabled = true
	dark.emission = Color(0.03, 0.04, 0.09)
	dark.metallic = 0.8
	dark.roughness = 0.3
	var palette := [Color(0.1, 0.6, 1.0), Color(0.6, 0.2, 1.0), Color(1.0, 0.35, 0.1)]
	for i in 46:
		var ang := TAU * i / 46.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(220.0, 330.0)
		var height := rng.randf_range(18.0, 95.0)
		var width := rng.randf_range(8.0, 22.0)
		var tower := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(width, height, width)
		tower.mesh = box
		tower.material_override = dark
		tower.position = Vector3(cos(ang) * dist, height * 0.5, sin(ang) * dist)
		tower.rotation.y = rng.randf() * PI
		_world.add_child(tower)

		var edge_col: Color = palette[rng.randi() % palette.size()]
		var emat := StandardMaterial3D.new()
		emat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		emat.albedo_color = edge_col * 3.0
		for k in rng.randi_range(1, 3):
			var band := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(width + 0.3, 0.35, width + 0.3)
			band.mesh = bb
			band.material_override = emat
			band.position = Vector3(0, rng.randf_range(-0.45, 0.48) * height, 0)
			tower.add_child(band)



func _build_camera() -> void:
	_camera = Camera3D.new()
	_camera.fov = 72.0
	_camera.far = 1200.0
	_camera.near = 0.1
	_camera.position = Vector3(0, 40, 90)
	add_child(_camera)
	_camera.make_current()


# --------------------------------------------------------------------------
# HUD
# --------------------------------------------------------------------------

func _label_settings(size: int, color := Color.WHITE, outline := 0) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = Color(0, 0, 0, 0.8)
	ls.shadow_color = Color(color.r, color.g, color.b, 0.45)
	ls.shadow_size = 10
	ls.shadow_offset = Vector2.ZERO
	return ls


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(root)

	# Title / round info, top-left.
	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 22)
	tl.add_theme_constant_override("separation", 4)
	root.add_child(tl)
	var title := Label.new()
	title.text = "NEON CYCLES"
	title.label_settings = _label_settings(26, Color(0.75, 0.92, 1.0))
	tl.add_child(title)
	_score_box = VBoxContainer.new()
	_score_box.add_theme_constant_override("separation", 2)
	tl.add_child(_score_box)

	# Centre messages.
	_center_label = Label.new()
	_place(_center_label, 0.5, 0.5, 0.5, 0.5, -800, -220, 800, -30)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.label_settings = _label_settings(88, Color.WHITE, 6)
	root.add_child(_center_label)

	_sub_label = Label.new()
	_place(_sub_label, 0.5, 0.5, 0.5, 0.5, -800, -20, 800, 30)
	_sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_label.label_settings = _label_settings(24, Color(0.8, 0.9, 1.0), 4)
	root.add_child(_sub_label)

	# Speed + boost, bottom-centre.
	var bottom := VBoxContainer.new()
	_place(bottom, 0.5, 1.0, 0.5, 1.0, -200, -120, 200, -24)
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_speed_label = Label.new()
	_speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speed_label.label_settings = _label_settings(30, Color(0.7, 0.95, 1.0))
	bottom.add_child(_speed_label)
	_boost_bar = ProgressBar.new()
	_boost_bar.custom_minimum_size = Vector2(360, 10)
	_boost_bar.show_percentage = false
	_boost_bar.max_value = 1.0
	_boost_bar.step = 0.001
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.1, 0.18, 0.7)
	bg.set_corner_radius_all(5)
	bg.border_color = Color(0.3, 0.7, 1.0, 0.5)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.9, 1.0)
	fill.set_corner_radius_all(5)
	fill.shadow_color = Color(0.2, 0.9, 1.0, 0.6)
	fill.shadow_size = 8
	_boost_bar.add_theme_stylebox_override("background", bg)
	_boost_bar.add_theme_stylebox_override("fill", fill)
	bottom.add_child(_boost_bar)
	var hint := Label.new()
	hint.text = "A / D  turn     SPACE  boost     ESC  pause     R  restart"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.label_settings = _label_settings(14, Color(0.55, 0.7, 0.85, 0.8))
	bottom.add_child(hint)

	# Minimap, top-right.
	_minimap = MinimapScript.new()
	_minimap.game = self
	_place(_minimap, 1.0, 0.0, 1.0, 0.0, -238, 24, -28, 234)
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_minimap)


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, o_r: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = o_r
	c.offset_bottom = ob


func _refresh_scores() -> void:
	for c in _score_box.get_children():
		c.queue_free()
	for r in RIDERS:
		var l := Label.new()
		var col: Color = r.color
		var alive_mark := ""
		for c in cycles:
			if c.display_name == r.name and not c.alive:
				alive_mark = "  (out)"
				col = col.darkened(0.55)
		l.text = "%s  %s%s" % [_pips(scores[r.name]), r.name, alive_mark]
		l.label_settings = _label_settings(18, col)
		_score_box.add_child(l)


func _pips(n: int) -> String:
	# Plain ASCII: the web build's default font has no box or bullet glyphs.
	return "%d/%d" % [n, WINS_TO_MATCH]


func _show_message(main: String, sub := "", color := Color.WHITE) -> void:
	_center_label.text = main
	_center_label.label_settings.font_color = color
	_center_label.label_settings.shadow_color = Color(color.r, color.g, color.b, 0.6)
	_sub_label.text = sub


# --------------------------------------------------------------------------
# Rounds
# --------------------------------------------------------------------------

func _start_round() -> void:
	for c in cycles:
		c.cleanup()
	cycles.clear()
	for child in _trails.get_children():
		child.queue_free()
	round_num += 1

	var d := ARENA_HALF * 0.6
	var spawns := [
		[Vector3(-20, 0, d), Vector3.FORWARD],
		[Vector3(20, 0, -d), Vector3.BACK],
		[Vector3(d, 0, 20), Vector3.LEFT],
		[Vector3(-d, 0, -20), Vector3.RIGHT],
	]
	for i in RIDERS.size():
		var c: LightCycle = LightCycleScript.new()
		c.name = RIDERS[i].name
		_world.add_child(c)
		c.setup(self, RIDERS[i].color, spawns[i][0], spawns[i][1], i == 0, RIDERS[i].name, _trails)
		c.crashed.connect(_on_cycle_crashed)
		cycles.append(c)
	player = cycles[0]
	_spectate = player
	_cam_dir = player.dir

	_state = State.COUNTDOWN
	_timer = 3.6
	_refresh_scores()


func _on_cycle_crashed(c: LightCycle) -> void:
	_refresh_scores()
	if _camera.global_position.distance_to(c.global_position) < 40.0:
		_cam_shake = max(_cam_shake, 1.0 if c == player else 0.45)
	if c == player and _state == State.PLAYING:
		_show_message("DEREZZED", "Spectating...  press ENTER to skip", Color(1, 0.3, 0.3))


func _alive() -> Array[LightCycle]:
	var a: Array[LightCycle] = []
	for c in cycles:
		if c.alive:
			a.append(c)
	return a


func _end_round() -> void:
	var alive := _alive()
	if alive.size() == 1:
		var w := alive[0]
		w.active = false
		scores[w.display_name] += 1
		_refresh_scores()
		if scores[w.display_name] >= WINS_TO_MATCH:
			_state = State.MATCH_OVER
			var msg := "YOU WIN THE GRID" if w == player else "%s WINS THE GRID" % w.display_name
			_show_message(msg, "Press ENTER for a new match", w.color)
			return
		var msg2 := "ROUND WON" if w == player else "%s WINS" % w.display_name
		_show_message(msg2, "Round %d  -  next round starting..." % round_num, w.color)
	else:
		_show_message("DRAW", "Mutual derezzing", Color(0.8, 0.85, 1))
	_state = State.ROUND_OVER
	_timer = 3.0


# --------------------------------------------------------------------------
# Main loop
# --------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		_toggle_pause()
	if _state == State.PAUSED:
		return
	if Input.is_action_just_pressed("restart"):
		_start_round()
		return

	match _state:
		State.COUNTDOWN:
			_timer -= delta
			if _timer > 0.6:
				_show_message(str(int(ceil(_timer - 0.6))), "Round %d  -  first to %d" % [round_num, WINS_TO_MATCH], Color(0.7, 0.95, 1.0))
			else:
				_show_message("GO", "", Color(0.3, 1.0, 0.6))
			if _timer <= 0.6 and not player.active:
				for c in cycles:
					c.active = true
			if _timer <= 0.0:
				_state = State.PLAYING
				_show_message("")
			if _timer <= 0.6:
				_simulate(delta)
		State.PLAYING:
			_simulate(delta)
			if _alive().size() <= 1:
				_end_round()
			elif not player.alive and Input.is_action_just_pressed("confirm"):
				_start_round()
		State.ROUND_OVER:
			_simulate(delta)
			_timer -= delta
			if _timer <= 0.0 or Input.is_action_just_pressed("confirm"):
				_start_round()
		State.MATCH_OVER:
			_simulate(delta)
			if Input.is_action_just_pressed("confirm"):
				for k in scores:
					scores[k] = 0
				round_num = 0
				_start_round()


func _toggle_pause() -> void:
	if _state == State.PAUSED:
		_state = _state_before_pause
		get_tree().paused = false
		_show_message("")
	else:
		_state_before_pause = _state
		_state = State.PAUSED
		get_tree().paused = true
		_show_message("PAUSED", "ESC to resume  -  R to restart round", Color(0.7, 0.9, 1))


func _simulate(delta: float) -> void:
	var moves := {}
	for c in cycles:
		if c.alive and c.active:
			c.think(delta)
	for c in cycles:
		if c.alive and c.active:
			moves[c] = c.advance(delta)

	var to_crash: Array[LightCycle] = []
	for c in moves:
		var f0: Vector3 = moves[c][0]
		var f1: Vector3 = moves[c][1]
		if absf(f1.x) > ARENA_HALF or absf(f1.z) > ARENA_HALF or _sweep_hits(c, f0, f1):
			to_crash.append(c)
	# Head-on bike collisions.
	var live := moves.keys()
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: LightCycle = live[i]
			var b: LightCycle = live[j]
			if a.position.distance_to(b.position) < 1.6:
				if not to_crash.has(a):
					to_crash.append(a)
				if not to_crash.has(b):
					to_crash.append(b)
	for c in to_crash:
		c.crash()


func _sweep_hits(c: LightCycle, f0: Vector3, f1: Vector3) -> bool:
	var sweep := Rect2(Vector2(minf(f0.x, f1.x), minf(f0.z, f1.z)),
		Vector2(absf(f1.x - f0.x), absf(f1.z - f0.z)))
	for o in cycles:
		if not o.collidable:
			continue
		for r in o.walls:
			if r.intersects(sweep, true):
				return true
		if o != c and o.alive and o.current_rect().intersects(sweep, true):
			return true
	return false


## Distance along an axis-aligned ray until it hits a wall or the arena edge.
func ray_distance(origin: Vector2, d: Vector2, max_d: float) -> float:
	var best := max_d
	if d.x > 0.0:
		best = minf(best, ARENA_HALF - origin.x)
	elif d.x < 0.0:
		best = minf(best, origin.x + ARENA_HALF)
	if d.y > 0.0:
		best = minf(best, ARENA_HALF - origin.y)
	elif d.y < 0.0:
		best = minf(best, origin.y + ARENA_HALF)
	for o in cycles:
		if not o.collidable:
			continue
		for r in o.walls:
			best = _ray_rect(origin, d, r, best)
		if o.alive:
			best = _ray_rect(origin, d, o.current_rect(), best)
	return maxf(best, 0.0)


func _ray_rect(o: Vector2, d: Vector2, r: Rect2, best: float) -> float:
	var t := INF
	if d.x != 0.0:
		if o.y < r.position.y or o.y > r.end.y:
			return best
		if d.x > 0.0:
			if o.x > r.end.x:
				return best
			t = r.position.x - o.x
		else:
			if o.x < r.position.x:
				return best
			t = o.x - r.end.x
	else:
		if o.x < r.position.x or o.x > r.end.x:
			return best
		if d.y > 0.0:
			if o.y > r.end.y:
				return best
			t = r.position.y - o.y
		else:
			if o.y < r.position.y:
				return best
			t = o.y - r.end.y
	return minf(best, maxf(t, 0.0))


# --------------------------------------------------------------------------
# Camera & HUD update
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if _state == State.PAUSED:
		return
	_update_camera(delta)
	if player != null:
		_speed_label.text = "%d  km/h" % int(player.speed * 9.0) if player.alive else "-"
		_boost_bar.value = player.boost_energy


func _update_camera(delta: float) -> void:
	var target: LightCycle = null
	if player != null and player.alive:
		target = player
	elif _spectate != null and is_instance_valid(_spectate) and _spectate.alive:
		target = _spectate
	else:
		for c in _alive():
			target = c
			_spectate = c
			break

	var desired_pos: Vector3
	var look_at_pos: Vector3
	var desired_fov := 72.0
	if target != null and (target.active or _state == State.COUNTDOWN):
		var fwd := target.dir
		var boost_k := clampf((target.speed - LightCycle.BASE_SPEED) / (LightCycle.BOOST_SPEED - LightCycle.BASE_SPEED), 0.0, 1.0)
		desired_pos = target.position - fwd * (7.5 + boost_k * 2.0) + Vector3.UP * (3.2 - boost_k * 0.5)
		look_at_pos = target.position + fwd * 10.0 + Vector3.UP * 0.6
		desired_fov = 72.0 + boost_k * 14.0
		# Smooth only the heading, so the camera never lags behind at speed.
		_cam_dir = _cam_dir.lerp(fwd, 1.0 - exp(-7.0 * delta)).normalized()
		desired_pos = target.position - _cam_dir * (7.0 + boost_k * 1.5) + Vector3.UP * (2.8 - boost_k * 0.4)
		look_at_pos = target.position + _cam_dir * 9.0 + Vector3.UP * 0.6
		if target != _cam_follow:
			# New subject (round start / spectating): glide over instead of snapping.
			_cam_follow = target
			_cam_dir = target.dir
			_cam_blend = 0.0 if _state != State.COUNTDOWN else 1.0
		_cam_blend = minf(1.0, _cam_blend + delta * 1.2)
		var k := lerpf(1.0 - exp(-3.0 * delta), 1.0, _cam_blend * _cam_blend)
		_camera.position = _camera.position.lerp(desired_pos, k)
	else:
		_cam_follow = null
		_orbit_angle += delta * 0.12
		desired_pos = Vector3(cos(_orbit_angle) * 140.0, 70.0, sin(_orbit_angle) * 140.0)
		look_at_pos = Vector3.ZERO
		_camera.position = _camera.position.lerp(desired_pos, 1.0 - exp(-1.2 * delta))

	_camera.fov = lerpf(_camera.fov, desired_fov, 1.0 - exp(-4.0 * delta))
	var up := Vector3.UP
	if not _camera.position.is_equal_approx(look_at_pos):
		_camera.look_at(look_at_pos, up)
	if _cam_shake > 0.0:
		_cam_shake = maxf(0.0, _cam_shake - delta * 1.8)
		var s := _cam_shake * _cam_shake * 0.6
		_camera.position += Vector3(randf_range(-s, s), randf_range(-s, s), randf_range(-s, s))
