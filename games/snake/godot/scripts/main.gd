extends Node2D
## Neon Snake — a modern take on Snake for Godot 4.
##
## Everything (visuals, particles, UI, sound) is generated in code, so the
## project has no external assets. Game logic runs on a fixed grid tick; the
## renderer interpolates between ticks so the snake glides smoothly.

const SFX := preload("res://scripts/sfx.gd")
const BG_SHADER := preload("res://shaders/background.gdshader")

const FONT := preload("res://fonts/inter-latin-600-normal.woff2")

# The board fits the window: wide windows get a wide board, tall (phone) windows a tall one.
const GRID_WIDE := Vector2i(28, 15)
const GRID_TALL := Vector2i(15, 24)
const HUD_TOP := 112.0
const MARGIN := 28.0

const START_STEP := 0.13      # seconds per tick at the start
const MIN_STEP := 0.055       # fastest tick
const SPEEDUP := 0.0022       # tick reduction per orb eaten
const COMBO_WINDOW := 2.6     # seconds between orbs to keep a combo
const BONUS_LIFETIME := 6.0
const BONUS_EVERY := 5

# Colours: some channels are over 1.0, which a renderer with HDR 2D would bloom; here they clamp, and
# the glow layer (_draw_glow) does the blooming.
const COL_HEAD := Color(0.35, 1.6, 1.45)
const COL_TAIL := Color(0.6, 0.32, 1.3)
const COL_DEAD := Color(1.7, 0.28, 0.35)
const COL_FOOD := Color(1.9, 0.35, 0.85)
const COL_BONUS := Color(2.0, 1.5, 0.35)
const COL_OUTLINE := Color(0.015, 0.04, 0.08, 0.95)

enum State { TITLE, PLAYING, PAUSED, DEAD }

var view := Vector2(1280, 720)
var cols := GRID_WIDE.x
var rows := GRID_WIDE.y
var cell := 40.0
var origin := Vector2.ZERO

var state: State = State.TITLE
var snake: Array[Vector2i] = []
var prev_snake: Array[Vector2i] = []
var dir := Vector2i.RIGHT
var dir_queue: Array[Vector2i] = []
var pending_grow := 0
var step_time := START_STEP
var accum := 0.0
var clock := 0.0

var food := Vector2i.ZERO
var food_age := 0.0
var bonus := Vector2i(-1, -1)
var bonus_left := 0.0
var foods_eaten := 0

var score := 0
var best := 0
var new_best := false
var combo := 0
var last_eat_time := -100.0

var dead_time := 0.0
var dissolved := 0
var border_flash := 0.0
var shake := 0.0

var board: Node2D
var glow_layer: Node2D          # additive halos: the bloom, drawn by hand (Compatibility has no 2D HDR glow)
var _glow_pts := PackedVector2Array()
var _glow_r := PackedFloat32Array()
var _glow_c := PackedColorArray()
var fx_layer: Node2D
var camera: Camera2D
var bg_material: ShaderMaterial
var head_trail: CPUParticles2D
var soft_dot: Texture2D
var panel_style := StyleBoxFlat.new()
var sfx: Node

var font: Font
var score_cap: Label
var best_cap: Label
var score_label: Label
var best_label: Label
var combo_label: Label
var speed_bar: ProgressBar
var overlay: Control
var title_label: Label
var sub_label: Label
var hint_label: Label

var touch_start := Vector2.ZERO
var touch_active := false
var swiped := false


# --------------------------------------------------------------------------
# Setup
# --------------------------------------------------------------------------

func _ready() -> void:
	randomize()
	_load_best()
	_build_world()
	_build_hud()
	get_viewport().size_changed.connect(_layout.bind(false))
	sfx = SFX.new()
	add_child(sfx)
	_reset_game()
	_show_overlay("NEON SNAKE", "Eat the glowing orbs. Chain them fast for combos.", _hint("play"))


func _build_world() -> void:
	# Animated shader background on its own layer (unaffected by camera shake).
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -10
	add_child(bg_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_material = ShaderMaterial.new()
	bg_material.shader = BG_SHADER
	bg.material = bg_material
	bg_layer.add_child(bg)

	board = Node2D.new()
	add_child(board)
	board.draw.connect(_draw_board)

	glow_layer = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow_layer.material = add
	add_child(glow_layer)
	glow_layer.draw.connect(_draw_glow)

	fx_layer = Node2D.new()
	add_child(fx_layer)

	camera = Camera2D.new()
	add_child(camera)


	# Soft round sprite used by every particle effect.
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	soft_dot = gt

	# Board panel.
	panel_style.bg_color = Color(0.03, 0.05, 0.09, 0.72)
	panel_style.set_corner_radius_all(22)
	panel_style.set_border_width_all(2)
	panel_style.shadow_color = Color(0, 0, 0, 0.45)
	panel_style.shadow_size = 32
	panel_style.anti_aliasing = true

	# Sparkle trail behind the head.
	head_trail = CPUParticles2D.new()
	head_trail.texture = soft_dot
	head_trail.amount = 48
	head_trail.lifetime = 0.55
	head_trail.local_coords = false
	head_trail.gravity = Vector2.ZERO
	head_trail.spread = 180.0
	head_trail.initial_velocity_min = 8.0
	head_trail.initial_velocity_max = 30.0
	head_trail.scale_amount_min = 0.05
	head_trail.scale_amount_max = 0.13
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.5, 1.8, 1.6, 0.9))
	ramp.set_color(1, Color(0.6, 0.3, 1.3, 0.0))
	head_trail.color_ramp = ramp
	head_trail.emitting = false
	fx_layer.add_child(head_trail)


func _ls(size: int, color: Color, outline: int = 0) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font = font
	ls.font_size = size
	ls.font_color = color
	if outline > 0:
		ls.outline_size = outline
		ls.outline_color = Color(0, 0, 0, 0.55)
	return ls


func _build_hud() -> void:
	font = FONT

	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)

	score_cap = Label.new()
	score_cap.text = "SCORE"
	score_cap.label_settings = _ls(14, Color(0.55, 0.8, 0.9, 0.7))
	hud.add_child(score_cap)

	score_label = Label.new()
	score_label.label_settings = _ls(40, Color(0.9, 1.0, 1.0))
	score_label.pivot_offset = Vector2(0, 28)
	hud.add_child(score_label)

	best_cap = Label.new()
	best_cap.text = "BEST"
	best_cap.label_settings = _ls(14, Color(0.55, 0.8, 0.9, 0.7))
	best_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_cap.size = Vector2(240, 20)
	hud.add_child(best_cap)

	best_label = Label.new()
	best_label.label_settings = _ls(40, Color(1.0, 0.85, 0.5))
	best_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	best_label.size = Vector2(240, 50)
	hud.add_child(best_label)

	combo_label = Label.new()
	combo_label.label_settings = _ls(30, Color(1.6, 0.6, 1.2), 0)
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.size = Vector2(400, 44)
	combo_label.pivot_offset = Vector2(200, 22)
	combo_label.modulate.a = 0.0
	hud.add_child(combo_label)

	# Thin speed meter under the combo.
	speed_bar = ProgressBar.new()
	speed_bar.show_percentage = false
	speed_bar.size = Vector2(220, 5)
	speed_bar.max_value = 1.0
	speed_bar.step = 0.0
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(1, 1, 1, 0.07)
	sb_bg.set_corner_radius_all(3)
	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.4, 1.4, 1.3)
	sb_fill.set_corner_radius_all(3)
	speed_bar.add_theme_stylebox_override("background", sb_bg)
	speed_bar.add_theme_stylebox_override("fill", sb_fill)
	hud.add_child(speed_bar)

	# Title / pause / game-over overlay.
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.015, 0.04, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(box)

	title_label = Label.new()
	title_label.label_settings = _ls(92, Color(0.5, 1.75, 1.6))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title_label)

	sub_label = Label.new()
	sub_label.label_settings = _ls(26, Color(0.85, 0.92, 1.0, 0.9))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub_label)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 18)
	box.add_child(spacer)

	hint_label = Label.new()
	hint_label.label_settings = _ls(20, Color(0.6, 0.85, 0.95, 0.75))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint_label)


# --------------------------------------------------------------------------
# Game flow
# --------------------------------------------------------------------------

func _reset_game() -> void:
	_layout(true)
	var mid := Vector2i(int(cols / 4.0), int(rows / 2.0))
	snake = [mid, mid - Vector2i(1, 0), mid - Vector2i(2, 0), mid - Vector2i(3, 0)]
	prev_snake = snake.duplicate()
	dir = Vector2i.RIGHT
	dir_queue.clear()
	pending_grow = 0
	step_time = START_STEP
	accum = 0.0
	score = 0
	combo = 0
	new_best = false
	foods_eaten = 0
	last_eat_time = -100.0
	bonus = Vector2i(-1, -1)
	dissolved = 0
	dead_time = 0.0
	_spawn_food()
	_update_score(false)
	_update_combo()


## Fits the board to the window. With choose_grid (a new game) a tall window gets the tall grid;
## mid-game only the cell size and position change.
func _layout(choose_grid: bool) -> void:
	view = get_viewport_rect().size
	if choose_grid:
		var g := GRID_TALL if view.y > view.x * 1.1 else GRID_WIDE
		cols = g.x
		rows = g.y
	cell = floorf(minf((view.x - MARGIN * 2.0) / cols, (view.y - HUD_TOP - MARGIN) / rows))
	var size := Vector2(cols, rows) * cell
	origin = Vector2(roundf((view.x - size.x) / 2.0), roundf(HUD_TOP + (view.y - HUD_TOP - MARGIN - size.y) / 2.0))
	var top := origin.y - 92.0
	score_cap.position = Vector2(origin.x, top)
	score_label.position = Vector2(origin.x, top + 14.0)
	best_cap.position = Vector2(origin.x + size.x - 240.0, top)
	best_label.position = Vector2(origin.x + size.x - 240.0, top + 14.0)
	combo_label.position = Vector2(view.x / 2.0 - 200.0, top + 4.0)
	speed_bar.position = Vector2(view.x / 2.0 - 110.0, top + 52.0)
	camera.position = view / 2.0
	bg_material.set_shader_parameter("resolution", view)


func _hint(what: String) -> String:
	var touch := DisplayServer.is_touchscreen_available()
	match what:
		"play":
			return "Tap to play  ·  swipe to steer" if touch else "SPACE to play   ·   ARROWS / WASD to steer   ·   P to pause"
		"again":
			return "Tap to play again" if touch else "SPACE to play again"
		_:
			return "Tap to resume" if touch else "P / ESC / SPACE to resume"


func _start() -> void:
	if state == State.DEAD:
		_reset_game()
	state = State.PLAYING
	accum = 0.0
	_hide_overlay()
	sfx.play("start")


func _toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		sfx.play("pause")
		_show_overlay("PAUSED", "Score %d" % score, _hint("resume"))
	elif state == State.PAUSED:
		state = State.PLAYING
		sfx.play("pause", 1.25)
		_hide_overlay()


func _on_confirm() -> void:
	match state:
		State.TITLE:
			_start()
		State.PAUSED:
			_toggle_pause()
		State.DEAD:
			if dead_time > 0.8:
				_start()


func _step() -> void:
	prev_snake = snake.duplicate()
	if not dir_queue.is_empty():
		dir = dir_queue.pop_front()
	var nh := snake[0] + dir
	var growing := pending_grow > 0

	if nh.x < 0 or nh.y < 0 or nh.x >= cols or nh.y >= rows:
		_die()
		return
	var body_end := snake.size() if growing else snake.size() - 1
	for i in body_end:
		if snake[i] == nh:
			_die()
			return

	snake.insert(0, nh)
	if growing:
		pending_grow -= 1
	else:
		snake.pop_back()

	if nh == food:
		_eat(false)
	elif nh == bonus:
		_eat(true)


func _eat(is_bonus: bool) -> void:
	var pos := _cell_center(snake[0])
	if clock - last_eat_time <= COMBO_WINDOW:
		combo += 1
	else:
		combo = 0
	last_eat_time = clock
	var mult := 1 + mini(combo, 4)
	var pts := (50 if is_bonus else 10) * mult
	score += pts
	pending_grow += 3 if is_bonus else 1

	if is_bonus:
		bonus = Vector2i(-1, -1)
		_burst(pos, COL_BONUS, 56, 420.0, 0.9, 0.3)
		sfx.play("bonus")
		_popup(pos, "+%d" % pts, Color(1.0, 0.85, 0.4))
	else:
		foods_eaten += 1
		_burst(pos, COL_FOOD, 32, 320.0, 0.7, 0.26)
		sfx.play("eat", 1.0 + 0.06 * mini(combo, 8))
		_popup(pos, "+%d" % pts, Color(1.0, 0.75, 0.92))
		_spawn_food()
		if foods_eaten % BONUS_EVERY == 0:
			_spawn_bonus()

	step_time = maxf(MIN_STEP, START_STEP - foods_eaten * SPEEDUP)
	border_flash = 1.0
	shake = maxf(shake, 3.0)
	var tw := create_tween()
	camera.zoom = Vector2(1.015, 1.015)
	tw.tween_property(camera, "zoom", Vector2.ONE, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_update_score(true)
	_update_combo()


func _die() -> void:
	state = State.DEAD
	prev_snake = snake.duplicate()
	dead_time = 0.0
	dissolved = 0
	shake = 14.0
	combo = 0
	_update_combo()
	sfx.play("die")
	_burst(_cell_center(snake[0]), Color(2.0, 0.5, 0.5), 64, 520.0, 1.0, 0.3)
	if score > best:
		best = score
		new_best = true
		_save_best()
	_update_score(false)
	await get_tree().create_timer(0.9).timeout
	if state == State.DEAD:
		var line := "Score %d   ·   Best %d" % [score, best]
		_show_overlay("NEW BEST!" if new_best else "GAME OVER", line, _hint("again"))


func _win() -> void:
	state = State.DEAD
	dead_time = 1.0
	dissolved = 0
	if score > best:
		best = score
		_save_best()
	_show_overlay("YOU WIN", "You filled the whole board. Score %d" % score, _hint("again"))


func _free_cells() -> Array[Vector2i]:
	var taken := {}
	for c in snake:
		taken[c] = true
	if bonus.x >= 0:
		taken[bonus] = true
	taken[food] = true
	var cells: Array[Vector2i] = []
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			if not taken.has(c):
				cells.append(c)
	return cells


func _spawn_food() -> void:
	var cells := _free_cells()
	if cells.is_empty():
		_win()
		return
	food = cells.pick_random()
	food_age = 0.0


func _spawn_bonus() -> void:
	var cells := _free_cells()
	if cells.is_empty():
		return
	bonus = cells.pick_random()
	bonus_left = BONUS_LIFETIME


# --------------------------------------------------------------------------
# Per-frame
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	clock += delta
	border_flash = move_toward(border_flash, 0.0, delta * 2.0)
	bg_material.set_shader_parameter("pulse", border_flash)

	if shake > 0.0:
		shake = move_toward(shake, 0.0, delta * 30.0)
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	else:
		camera.offset = Vector2.ZERO

	match state:
		State.TITLE:
			food_age += delta
		State.PLAYING:
			food_age += delta
			if bonus.x >= 0:
				bonus_left -= delta
				if bonus_left <= 0.0:
					_burst(_cell_center(bonus), Color(COL_BONUS, 0.6), 18, 140.0, 0.5, 0.18)
					bonus = Vector2i(-1, -1)
			accum += delta
			while accum >= step_time and state == State.PLAYING:
				accum -= step_time
				_step()
			if combo > 0 and clock - last_eat_time > COMBO_WINDOW:
				combo = 0
				_update_combo()
		State.DEAD:
			dead_time += delta
			var target := mini(int(maxf(0.0, dead_time - 0.35) * 45.0), snake.size())
			while dissolved < target:
				var k := float(dissolved) / maxf(1.0, snake.size() - 1)
				_burst(_cell_center(snake[dissolved]), _snake_color(k).lerp(COL_DEAD, 0.4), 10, 190.0, 0.6, 0.18)
				if dissolved % 3 == 0:
					sfx.play("pop", randf_range(0.85, 1.3))
				dissolved += 1

	head_trail.emitting = state == State.PLAYING
	if not snake.is_empty():
		head_trail.position = _head_pos()

	speed_bar.value = inverse_lerp(START_STEP, MIN_STEP, step_time)
	title_label.modulate = Color(1, 1, 1, 0.85 + 0.15 * sin(clock * 2.5))
	board.queue_redraw()
	glow_layer.queue_redraw()


func _interp() -> float:
	if state == State.PLAYING or state == State.PAUSED:
		return clampf(accum / step_time, 0.0, 1.0)
	return 1.0


func _cell_center(c: Vector2i) -> Vector2:
	return origin + (Vector2(c) + Vector2(0.5, 0.5)) * cell


func _head_pos() -> Vector2:
	return _cell_center(prev_snake[0]).lerp(_cell_center(snake[0]), _interp())


func _snake_color(k: float) -> Color:
	var c := COL_HEAD.lerp(COL_TAIL, clampf(k, 0.0, 1.0))
	if state == State.DEAD:
		c = c.lerp(COL_DEAD, 0.55)
	return c


# --------------------------------------------------------------------------
# Input
# --------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_UP, KEY_W:
				_push_dir(Vector2i.UP)
			KEY_DOWN, KEY_S:
				_push_dir(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				_push_dir(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				_push_dir(Vector2i.RIGHT)
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				_on_confirm()
			KEY_P, KEY_ESCAPE:
				_toggle_pause()
	elif event is InputEventJoypadButton and event.pressed:
		match event.button_index:
			JOY_BUTTON_DPAD_UP:
				_push_dir(Vector2i.UP)
			JOY_BUTTON_DPAD_DOWN:
				_push_dir(Vector2i.DOWN)
			JOY_BUTTON_DPAD_LEFT:
				_push_dir(Vector2i.LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_push_dir(Vector2i.RIGHT)
			JOY_BUTTON_A:
				_on_confirm()
			JOY_BUTTON_START:
				_toggle_pause()
	elif event is InputEventScreenTouch:
		if event.pressed:
			touch_start = event.position
			touch_active = true
			swiped = false
		else:
			if touch_active and not swiped:
				_on_confirm()
			touch_active = false
	elif event is InputEventScreenDrag and touch_active:
		var d: Vector2 = event.position - touch_start
		if d.length() > 36.0:
			if absf(d.x) > absf(d.y):
				_push_dir(Vector2i.RIGHT if d.x > 0 else Vector2i.LEFT)
			else:
				_push_dir(Vector2i.DOWN if d.y > 0 else Vector2i.UP)
			touch_start = event.position
			swiped = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not DisplayServer.is_touchscreen_available():
			_on_confirm()


func _push_dir(d: Vector2i) -> void:
	if state == State.TITLE:
		_start()
	if state != State.PLAYING:
		return
	var last: Vector2i = dir_queue.back() if not dir_queue.is_empty() else dir
	if d == last or d == -last:
		return
	if dir_queue.size() < 3:
		dir_queue.append(d)


# --------------------------------------------------------------------------
# HUD helpers
# --------------------------------------------------------------------------

func _update_score(punch: bool) -> void:
	score_label.text = str(score)
	best_label.text = str(maxi(best, score))
	if punch:
		score_label.scale = Vector2(1.25, 1.25)
		var tw := score_label.create_tween()
		tw.tween_property(score_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_combo() -> void:
	if combo <= 0:
		var tw := combo_label.create_tween()
		tw.tween_property(combo_label, "modulate:a", 0.0, 0.25)
		return
	combo_label.text = "COMBO  ×%d" % (1 + mini(combo, 4))
	combo_label.modulate.a = 1.0
	combo_label.scale = Vector2(1.35, 1.35)
	var tw2 := combo_label.create_tween()
	tw2.tween_property(combo_label, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _show_overlay(title: String, sub: String, hint: String) -> void:
	title_label.text = title
	sub_label.text = sub
	hint_label.text = hint
	overlay.visible = true
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "modulate:a", 1.0, 0.35).from(0.0)


func _hide_overlay() -> void:
	var tw := overlay.create_tween()
	tw.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tw.tween_callback(func() -> void: overlay.visible = false)


func _popup(pos: Vector2, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.label_settings = _ls(26, color, 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.size = Vector2(120, 40)
	l.position = pos - Vector2(60, 46)
	l.pivot_offset = Vector2(60, 20)
	l.scale = Vector2(0.4, 0.4)
	fx_layer.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 56.0, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.55)
	tw.chain().tween_callback(l.queue_free)


func _burst(pos: Vector2, color: Color, amount: int, speed: float, life: float, size: float) -> void:
	var p := CPUParticles2D.new()
	p.texture = soft_dot
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.3
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.9
	p.damping_max = speed * 1.5
	p.scale_amount_min = size * 0.35
	p.scale_amount_max = size
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	p.color_ramp = ramp
	p.position = pos
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)


# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _glow(at: Vector2, radius: float, color: Color) -> void:
	_glow_pts.append(at)
	_glow_r.append(radius)
	_glow_c.append(color)


func _draw_glow() -> void:
	for i in _glow_pts.size():
		var r := _glow_r[i]
		glow_layer.draw_texture_rect(soft_dot, Rect2(_glow_pts[i] - Vector2(r, r), Vector2(r, r) * 2.0), false, _glow_c[i])


func _draw_board() -> void:
	_glow_pts.clear()
	_glow_r.clear()
	_glow_c.clear()
	var size := Vector2(cols, rows) * cell
	var pad := 14.0
	panel_style.border_color = Color(0.2, 0.55, 0.65, 0.5).lerp(Color(0.5, 1.8, 1.6, 1.0), border_flash)
	panel_style.draw(board.get_canvas_item(), Rect2(origin - Vector2(pad, pad), size + Vector2(pad, pad) * 2.0))

	for y in rows:
		for x in cols:
			if (x + y) % 2 == 0:
				board.draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), Color(1, 1, 1, 0.017))
	for y in rows + 1:
		for x in cols + 1:
			board.draw_circle(origin + Vector2(x, y) * cell, 1.4, Color(0.6, 0.9, 1.0, 0.09))

	_draw_food()
	if bonus.x >= 0:
		_draw_bonus()
	_draw_snake()


func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3.0) + c1 * pow(x - 1.0, 2.0)


func _draw_food() -> void:
	var c := _cell_center(food)
	var s := _ease_out_back(clampf(food_age / 0.4, 0.0, 1.0))
	var r := cell * 0.27 * s * (1.0 + 0.08 * sin(clock * 6.0))
	for i in 4:
		board.draw_circle(c, r * (1.6 + i * 0.6), Color(1.0, 0.3, 0.65, 0.05))
	board.draw_circle(c, r, COL_FOOD)
	_glow(c, r * 4.5, Color(1.0, 0.25, 0.6, 0.55))
	board.draw_circle(c - Vector2(r, r) * 0.3, r * 0.35, Color(2.0, 1.8, 2.0, 0.65))
	for i in 3:
		var a := clock * 2.2 + TAU * i / 3.0
		board.draw_circle(c + Vector2(cos(a), sin(a)) * r * 1.9, 2.2 * s, Color(1.6, 0.7, 1.3))


func _draw_bonus() -> void:
	var c := _cell_center(bonus)
	var life := bonus_left / BONUS_LIFETIME
	var alpha := 1.0 if bonus_left > 1.5 or fmod(clock, 0.2) < 0.12 else 0.3
	var r := cell * 0.38 * (1.0 + 0.07 * sin(clock * 8.0))
	for i in 3:
		board.draw_circle(c, r * (1.3 + i * 0.5), Color(1.0, 0.8, 0.3, 0.05 * alpha))
	var pts := PackedVector2Array()
	for i in 10:
		var a := clock * 1.5 + TAU * i / 10.0 - PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	board.draw_colored_polygon(pts, Color(COL_BONUS, alpha))
	_glow(c, r * 3.5, Color(1.0, 0.75, 0.2, 0.5 * alpha))
	board.draw_arc(c, cell * 0.6, -PI / 2.0, -PI / 2.0 + TAU * life, 48, Color(1.6, 1.2, 0.4, 0.8 * alpha), 3.0, true)


func _draw_snake() -> void:
	var n := snake.size()
	if n == 0:
		return
	var t := _interp()
	var pts := PackedVector2Array()
	for i in n:
		var a: Vector2i = prev_snake[mini(i, prev_snake.size() - 1)]
		pts.append(_cell_center(a).lerp(_cell_center(snake[i]), t))

	# Sample densely along the body so overlapping circles form a smooth tube.
	const SUB := 6
	var sp := PackedVector2Array()
	var sr := PackedFloat32Array()
	var sk := PackedFloat32Array()
	for i in range(n - 1, -1, -1):
		if state == State.DEAD and i < dissolved:
			continue
		var steps := SUB if i > 0 else 1
		for s in steps:
			var f := float(s) / steps
			var p := pts[i]
			if i > 0:
				p = pts[i].lerp(pts[i - 1], f)
			var k := (float(i) - f) / maxf(1.0, n - 1)
			sp.append(p)
			sr.append(lerpf(cell * 0.4, cell * 0.22, k))
			sk.append(k)

	if sp.is_empty():
		return

	var head_alive := not (state == State.DEAD and dissolved > 0)
	if head_alive:
		board.draw_circle(pts[0], cell * 0.8, Color(0.3, 1.0, 0.9, 0.05))

	var count := sp.size()
	for j in count:  # drop shadow
		board.draw_circle(sp[j] + Vector2(0, 7), sr[j], Color(0, 0, 0, 0.26))
	for j in count:  # outline
		board.draw_circle(sp[j], sr[j] + 2.5, COL_OUTLINE)
	for j in count:  # body with subtle per-segment banding
		var seg := sk[j] * (n - 1)
		var band := 0.86 + 0.14 * cos(seg * TAU)
		var col := _snake_color(sk[j])
		board.draw_circle(sp[j], sr[j], Color(col.r * band, col.g * band, col.b * band))
	for j in range(0, count, 3):  # bloom
		var gc := _snake_color(sk[j])
		_glow(sp[j], sr[j] * 2.6, Color(gc.r * 0.5, gc.g * 0.5, gc.b * 0.5, 0.22))
	for j in count:  # glossy highlight
		board.draw_circle(sp[j] + Vector2(-0.22, -0.3) * sr[j], sr[j] * 0.4, Color(1, 1, 1, 0.16))

	if head_alive:
		_draw_face(pts)


func _draw_face(pts: PackedVector2Array) -> void:
	var head := pts[0]
	var fwd := Vector2(dir)
	if pts.size() > 1 and pts[0].distance_to(pts[1]) > 1.0:
		fwd = (pts[0] - pts[1]).normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var ink := Color(0.02, 0.03, 0.06)
	var blink := fmod(clock, 3.7) < 0.12

	for sgn in [-1.0, 1.0]:
		var e: Vector2 = head + fwd * cell * 0.1 + side * sgn * cell * 0.17
		if state == State.DEAD:
			var a := cell * 0.07
			board.draw_line(e + Vector2(-a, -a), e + Vector2(a, a), ink, 3.0, true)
			board.draw_line(e + Vector2(-a, a), e + Vector2(a, -a), ink, 3.0, true)
		elif blink:
			board.draw_line(e - side * cell * 0.08, e + side * cell * 0.08, ink, 3.0, true)
		else:
			board.draw_circle(e, cell * 0.11, Color(1.3, 1.3, 1.3))
			board.draw_circle(e + fwd * cell * 0.035, cell * 0.055, ink)

	if state == State.PLAYING and fmod(clock, 2.3) < 0.25:
		var tongue := Color(1.8, 0.3, 0.5)
		var base := head + fwd * cell * 0.36
		var tip := head + fwd * cell * 0.62
		board.draw_line(base, tip, tongue, 2.5, true)
		board.draw_line(tip, tip + (fwd + side * 0.8).normalized() * 6.0, tongue, 2.0, true)
		board.draw_line(tip, tip + (fwd - side * 0.8).normalized() * 6.0, tongue, 2.0, true)


# --------------------------------------------------------------------------
# Persistence
# --------------------------------------------------------------------------

func _load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://neon_snake.cfg") == OK:
		best = int(cfg.get_value("scores", "best", 0))


func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best)
	cfg.save("user://neon_snake.cfg")
