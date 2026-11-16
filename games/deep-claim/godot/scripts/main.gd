class_name Main
extends Node2D
## Game flow: title → shafts → victory / game over. Owns oxygen, fuel refills, the collapse timer,
## lighting, bloom, camera shake, audio and the HUD.

enum State { TITLE, PLAYING, DYING, COMPLETE, PAUSED, GAMEOVER, WON }

const START_LIVES := 3
const OXYGEN_TIME := 40.0      # seconds of air in the suit
const REFILL_RATE := 0.7       # tank fractions per second while in the buggy
const SAVE_PATH := "user://deep_claim.save"

var state := State.TITLE
var level_index := 0
var lives := START_LIVES
var score := 0
var hiscore := 0
var collapse := 1.0
var level: Level
var bg: Background
var hud: Hud
var sfx: Sfx
var camera: Camera2D
var fade: ColorRect
var shake := 0.0
var banner_t := 0.0
var banner_text := ""
var banner_sub := ""
var popups: Array[Dictionary] = []
var _caving := false
var _input_lock := 0.0
var _alarm_t := 0.0
var _refuel_t := 0.0
var _rumble_t := 3.0
var _autotest := false
var _autotest_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_autotest = "--autotest" in OS.get_cmdline_user_args()

	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.1
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for i in 7:
		env.set_glow_level(i, 1.0 if i >= 1 and i <= 4 else 0.0)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var cm := CanvasModulate.new()
	cm.color = Color(0.5, 0.5, 0.6)
	add_child(cm)

	bg = Background.new()
	add_child(bg)

	camera = Camera2D.new()
	camera.position = Vector2(640, 360)
	add_child(camera)
	camera.make_current()

	sfx = Sfx.new()
	add_child(sfx)

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	hud.main = self
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(hud)
	_add_touch_controls(layer)
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(fade)

	_load_hiscore()
	_load_level(0)
	_set_attract(true)
	_fade_to(0.0)
	if _autotest:
		_start_game()


## On-screen buttons for phones and tablets; Godot shows them only on a touchscreen.
## Hud draws them (TOUCH_BUTTONS gives their places), so they match the game's look.
const TOUCH_BUTTONS := [
	["move_left", Vector2(90, 560), 58.0, "left"],
	["move_right", Vector2(225, 560), 58.0, "right"],
	["interact", Vector2(1060, 585), 46.0, "E"],
	["jump", Vector2(1190, 545), 66.0, "up"],
	["pause", Vector2(1240, 36), 26.0, "pause"],
]


func _add_touch_controls(layer: CanvasLayer) -> void:
	for b in TOUCH_BUTTONS:
		var t := TouchScreenButton.new()
		var shape := CircleShape2D.new()
		shape.radius = b[2]
		t.shape = shape
		t.shape_centered = true
		t.position = b[1]
		t.action = b[0]
		t.passby_press = b[0] == "move_left" or b[0] == "move_right"
		t.visibility_mode = TouchScreenButton.VISIBILITY_TOUCHSCREEN_ONLY
		layer.add_child(t)


func _setup_input() -> void:
	_bind("move_left", [KEY_LEFT, KEY_A], [JOY_BUTTON_DPAD_LEFT], -1.0)
	_bind("move_right", [KEY_RIGHT, KEY_D], [JOY_BUTTON_DPAD_RIGHT], 1.0)
	_bind("jump", [KEY_SPACE, KEY_UP, KEY_W, KEY_Z], [JOY_BUTTON_A], 0.0)
	_bind("interact", [KEY_E, KEY_DOWN, KEY_S, KEY_X], [JOY_BUTTON_X, JOY_BUTTON_B], 0.0)
	_bind("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_START], 0.0)
	_bind("restart", [KEY_R], [JOY_BUTTON_BACK], 0.0)
	_bind("start", [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_A, JOY_BUTTON_START], 0.0)


func _bind(action: String, keys: Array, buttons: Array, axis_dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis_dir != 0.0:
		var jm := InputEventJoypadMotion.new()
		jm.axis = JOY_AXIS_LEFT_X
		jm.axis_value = axis_dir
		InputMap.action_add_event(action, jm)


# ------------------------------------------------------------------ flow

func _load_level(i: int) -> void:
	if level:
		remove_child(level)
		level.queue_free()
	sfx.jet(false)
	level_index = i
	level = Level.new()
	level.setup(Levels.DATA[i])
	add_child(level)
	move_child(level, bg.get_index() + 1)
	level.ore_taken.connect(_on_ore)
	level.all_ore_taken.connect(_on_all_ore)
	level.player_killed.connect(_on_killed)
	level.exit_reached.connect(_on_exit)
	level.tile_crumbled.connect(_on_crumbled)
	level.rock_landed.connect(_on_rock)
	level.player.jumped.connect(func() -> void: sfx.play("jump", randf_range(0.95, 1.08)))
	level.player.landed.connect(_on_landed)
	level.player.jet_changed.connect(func(on: bool) -> void: sfx.jet(on))
	bg.set_theme(level.tint)
	collapse = 1.0
	_caving = false
	popups.clear()


func _set_attract(on: bool) -> void:
	level.active = not on
	level.player.frozen = on


func _start_game() -> void:
	lives = START_LIVES
	score = 0
	sfx.play("start")
	await _fade_to(1.0)
	_load_level(0)
	_begin_level()
	_fade_to(0.0)


func _begin_level() -> void:
	_set_attract(false)
	state = State.PLAYING
	var hint := level.level_name
	if level_index == 0:
		hint += "   ·   E to step out of the buggy"
	_banner("SHAFT %d" % (level_index + 1), hint, 3.0)


func _banner(text: String, sub: String, time: float) -> void:
	banner_text = text
	banner_sub = sub
	banner_t = time


func _fade_to(a: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, 0.4)
	await tw.finished


func collapse_seconds() -> float:
	return collapse * level.collapse_time


func _process(delta: float) -> void:
	_input_lock -= delta
	banner_t = maxf(0.0, banner_t - delta)
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] = float(popups[i]["t"]) - delta
		if popups[i]["t"] <= 0.0:
			popups.remove_at(i)
	match state:
		State.TITLE:
			if _pressed("start") or _pressed("jump"):
				state = State.DYING  # transitional; blocks double starts
				_start_game()
		State.PLAYING:
			_update_playing(delta)
		State.PAUSED:
			if _pressed("pause"):
				state = State.PLAYING
				get_tree().paused = false
			elif _pressed("restart"):
				state = State.PLAYING
				get_tree().paused = false
				level._kill("CLAIM ABANDONED")
		State.GAMEOVER, State.WON:
			if (_pressed("start") or _pressed("jump")) and _input_lock <= 0.0:
				state = State.TITLE
				_load_level(0)
				_set_attract(true)
	shake = maxf(0.0, shake - delta * 30.0)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	if level and level.player:
		bg.focus = level.buggy.position if level.player.in_buggy else level.player.position
	if _autotest:
		_run_autotest(delta)


func _update_playing(delta: float) -> void:
	var p := level.player
	if not _caving:
		collapse = maxf(0.0, collapse - delta / level.collapse_time)
	level.collapse_frac = collapse
	var danger := 1.0 - collapse
	shake = maxf(shake, danger * danger * 2.5)
	_rumble_t -= delta
	if danger > 0.3 and _rumble_t <= 0.0:
		_rumble_t = randf_range(2.0, 5.0) * (1.2 - danger)
		sfx.play("rumble", randf_range(0.7, 1.0))
		shake = maxf(shake, 4.0 + danger * 6.0)
	if collapse <= 0.0 and not _caving:
		_cave_in()
		return
	if p.in_buggy:
		var before := p.oxygen + p.fuel
		p.oxygen = minf(1.0, p.oxygen + REFILL_RATE * delta)
		p.fuel = minf(1.0, p.fuel + REFILL_RATE * delta)
		_refuel_t -= delta
		if p.oxygen + p.fuel > before + 0.0001 and _refuel_t <= 0.0:
			_refuel_t = 0.09
			sfx.play("refuel", 0.8 + (p.oxygen + p.fuel) * 0.3)
	else:
		p.oxygen = maxf(0.0, p.oxygen - delta / OXYGEN_TIME)
		if p.oxygen <= 0.0:
			level._kill("OUT OF OXYGEN")
			return
	# alarms
	_alarm_t -= delta
	if _alarm_t <= 0.0:
		if collapse_seconds() < 15.0:
			_alarm_t = 1.0
			sfx.play("klaxon")
		elif not p.in_buggy and p.oxygen < 0.25:
			_alarm_t = 0.7
			sfx.play("alarm")
	if _pressed("interact"):
		var was_in := p.in_buggy
		if level.toggle_buggy():
			sfx.play("board" if not was_in else "unboard")
	elif _pressed("restart"):
		level._kill("CLAIM ABANDONED")
	elif _pressed("pause"):
		state = State.PAUSED
		get_tree().paused = true
		sfx.jet(false)


func _cave_in() -> void:
	_caving = true
	level.cave_in()
	sfx.play("rumble", 0.6)
	sfx.play("crush", 0.7)
	shake = 22.0
	await get_tree().create_timer(0.9).timeout
	if state == State.PLAYING and level.active:
		level._kill("THE SHAFT CAVED IN")


func _pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action)


# ------------------------------------------------------------------ events

func _on_ore(remaining: int, pos: Vector2, mat: Dictionary) -> void:
	var value: int = mat["value"]
	score += value
	var col: Color = mat["color"]
	sfx.play("pickup", 1.0 + (level.ore_total - remaining) * 0.04)
	Fx.burst(level, pos, Color(col.r * 3.0, col.g * 3.0, col.b * 3.0), 22, 230.0, 0.55, 0.0, 3.5)
	popups.append({"text": "%s  +%d" % [mat["name"], value], "pos": pos, "t": 1.3, "color": col})


func _on_all_ore(pos: Vector2) -> void:
	sfx.play("door")
	shake = 5.0
	Fx.burst(level, pos, Color(0.6, 3.0, 1.2), 40, 260.0, 0.8, 0.0, 3.5)
	_banner("TUNNEL OPEN", "Back to the buggy and drive out", 2.4)


func _on_crumbled(pos: Vector2) -> void:
	sfx.play("crumble", randf_range(0.85, 1.15))
	Fx.burst(level, pos, Color(0.7, 0.5, 0.3), 16, 120.0, 0.8, 900.0, 4.0)


func _on_rock(pos: Vector2, big: bool) -> void:
	sfx.play("crush", randf_range(0.9, 1.3) if not big else 0.7)
	Fx.burst(level, pos, Color(0.55, 0.5, 0.46), 18 if big else 10, 160.0, 0.7, 700.0, 4.0)
	shake = maxf(shake, 6.0 if big else 3.0)


func _on_landed(impact: float) -> void:
	if impact > 0.35:
		sfx.play("land", 1.2 - impact * 0.4)
		Fx.burst(level, level.player.position + Vector2(0, Player.HALF.y), Color(0.6, 0.55, 0.5, 0.8), int(6 + impact * 10), 90.0 * impact, 0.4, 200.0, 3.0)
		shake = maxf(shake, impact * 3.0)


func _on_killed(reason: String) -> void:
	if state != State.PLAYING:
		return
	state = State.DYING
	sfx.jet(false)
	var p := level.player
	var where := level.buggy.position if p.in_buggy else p.position
	p.alive = false
	p.visible = false
	p.lamp.visible = false
	sfx.play("die")
	shake = maxf(shake, 14.0)
	Fx.burst(level, where, Color(3.0, 1.6, 0.6), 60, 380.0, 1.0, 500.0, 5.0)
	Fx.burst(level, where, Color(2.4, 2.4, 2.6), 24, 200.0, 0.8, 0.0, 3.0)
	lives -= 1
	_banner(reason, "%d %s left" % [lives, "miner" if lives == 1 else "miners"] if lives > 0 else "", 2.0)
	await get_tree().create_timer(1.6).timeout
	await _fade_to(1.0)
	_load_level(level_index)
	if lives <= 0:
		state = State.GAMEOVER
		_set_attract(true)
		_save_hiscore()
		sfx.play("over")
		_input_lock = 1.0
		banner_t = 0.0
	else:
		_begin_level()
	_fade_to(0.0)


func _on_exit() -> void:
	if state != State.PLAYING:
		return
	state = State.COMPLETE
	level.player.frozen = true
	sfx.play("win")
	_banner("SHAFT CLEARED", "Collapse bonus", 2.5)
	# leftover collapse time pays out as a bonus
	while collapse > 0.0:
		var step := minf(collapse, 0.01)
		collapse -= step
		score += int(round(step * level.collapse_time * 10.0))
		sfx.play("tick", 1.0 + (1.0 - collapse) * 0.5)
		await get_tree().create_timer(0.02).timeout
	collapse = 0.0
	await get_tree().create_timer(0.6).timeout
	await _fade_to(1.0)
	if level_index + 1 >= Levels.DATA.size():
		_load_level(0)
		_set_attract(true)
		state = State.WON
		_save_hiscore()
		_input_lock = 1.0
		banner_t = 0.0
	else:
		_load_level(level_index + 1)
		_begin_level()
	_fade_to(0.0)


# ------------------------------------------------------------------ persistence

func _load_hiscore() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			hiscore = int(f.get_var())


func _save_hiscore() -> void:
	if score > hiscore:
		hiscore = score
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_var(hiscore)


# ------------------------------------------------------------------ headless smoke test

func _run_autotest(delta: float) -> void:
	_autotest_t += delta
	var phase := int(_autotest_t * 2.0) % 6
	for a in ["move_left", "move_right", "jump", "interact"]:
		Input.action_release(a)
	if absf(_autotest_t - 3.0) < delta:
		Input.action_press("interact")
	if phase < 3:
		Input.action_press("move_right")
	else:
		Input.action_press("move_left")
	if phase == 1 or phase == 4:
		Input.action_press("jump")
	if int(_autotest_t * 10) % 20 == 0:
		var p := level.player
		print("t=%.1f state=%d shaft=%d lives=%d score=%d O2=%.2f fuel=%.2f collapse=%.2f ore=%d buggy=%s pos=%s" % [
			_autotest_t, state, level_index, lives, score, p.oxygen, p.fuel, collapse, level.ore.size(), p.in_buggy, level.buggy.position.round()])
	if _autotest_t > 25.0:
		print("AUTOTEST DONE")
		get_tree().quit()
