extends Node2D
## BACKSEAT DRIVER - a comedy about being the front-seat passenger.
## Signs approach. Say the right thing before they arrive, or the sign gets its revenge.

const Gfx = preload("res://gfx.gd")
const HazA = preload("res://hazards_a.gd")
const HazB = preload("res://hazards_b.gd")
const Events = preload("res://events.gd")

const W := 1280.0
const H := 720.0
const HORIZON := 285.0
const ROAD_B := 600.0
const MAX_STRIKES := 3
const SAVE_PATH := "user://backseat_driver.cfg"

enum State { TITLE, DRIVE, SIGN, RESULT, OVER }

var state: int = State.TITLE
var gfx: Gfx
var haz_a: HazA
var haz_b: HazB
var rng := RandomNumberGenerator.new()

var score := 0
var best := 0
var strikes := 0
var streak := 0
var handled := 0
var new_best := false

var ev: Dictionary = {}
var opts: Array = []
var bag: Array = []
var t := 0.0          # 0..1 until the sign is "on you"
var sign_t := 0.0     # where the roadside sign is (keeps going after you answer)
var react_time := 6.5
var gap := 2.0
var et := 0.0         # seconds spent on this event (hazard animation clock)
var hc := 0.0         # crossing progress: 1.0 = dead centre in front of the bumper
var dep := 0.0        # approach depth of the hazard, 0..1
var swerve := 0.0
var result_good := false
var result_head := ""
var result_text := ""
var result_timer := 0.0
var driver_line := ""
var idle_timer := 3.0
var mood := "calm"
var epitaph := ""

var scroll := 0.0
var speed := 0.3
var anim := 0.0
var over_lock := 0.0
var shake := 0.0
var flash := 0.0
var flash_col := Color.RED
var particles: Array = []
var cracks: Array = []

var c_top := Color("5db3f2")
var c_bot := Color("cfeaff")
var c_ground := Color("4c9a3c")

var bar: HBoxContainer
var buttons: Array = []


func _ready() -> void:
	rng.randomize()
	gfx = Gfx.new(self)
	haz_a = HazA.new(gfx)
	haz_b = HazB.new(gfx)
	_load_best()
	_build_ui()
	driver_line = "Buckle up. I drive great. Ask anyone."


# ---------------------------------------------------------------- UI / input

func _box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(3)
	sb.border_color = Color("e8e8f0")
	sb.set_content_margin_all(10)
	return sb


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	bar = HBoxContainer.new()
	bar.position = Vector2(30, 618)
	bar.size = Vector2(1220, 92)
	bar.add_theme_constant_override("separation", 14)
	layer.add_child(bar)
	for i in 3:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 20)
		b.set("autowrap_mode", 3)
		b.add_theme_stylebox_override("normal", _box(Color("2e3a52")))
		b.add_theme_stylebox_override("hover", _box(Color("42578a")))
		b.add_theme_stylebox_override("pressed", _box(Color("4f9a5f")))
		b.pressed.connect(_on_option.bind(i))
		bar.add_child(b)
		buttons.append(b)
	bar.visible = false


func _input(e: InputEvent) -> void:
	var go := false
	var pick := -1
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		if k == KEY_SPACE or k == KEY_ENTER or k == KEY_R:
			go = true
		elif k == KEY_1 or k == KEY_KP_1:
			pick = 0
		elif k == KEY_2 or k == KEY_KP_2:
			pick = 1
		elif k == KEY_3 or k == KEY_KP_3:
			pick = 2
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		go = true
	if pick >= 0:
		_on_option(pick)
	elif go and (state == State.TITLE or (state == State.OVER and over_lock <= 0.0)):
		_start()


func _on_option(i: int) -> void:
	if state == State.SIGN and i < opts.size():
		_resolve(i)


# ---------------------------------------------------------------- game flow

func _start() -> void:
	score = 0
	strikes = 0
	streak = 0
	handled = 0
	new_best = false
	cracks.clear()
	particles.clear()
	bag.clear()
	ev = {}
	mood = "calm"
	gap = 2.5
	speed = 0.3
	driver_line = Events.IDLE.pick_random()
	idle_timer = 4.0
	state = State.DRIVE


func _next_sign() -> void:
	if bag.is_empty():
		for i in Events.LIST.size():
			bag.append(i)
		bag.shuffle()
	ev = Events.LIST[bag.pop_back()]
	opts = []
	var raw: Array = ev["o"]
	for i in raw.size():
		opts.append({"t": raw[i][0], "r": raw[i][1], "ok": i == 0})
	opts.shuffle()
	for i in buttons.size():
		var b: Button = buttons[i]
		b.text = "[%d]  %s" % [i + 1, opts[i]["t"]]
	t = 0.0
	sign_t = 0.0
	et = 0.0
	hc = 0.0
	dep = 0.0
	swerve = 0.0
	react_time = maxf(3.6, 6.8 - 0.2 * float(handled))
	driver_line = ev["d"]
	mood = "calm"
	bar.visible = true
	state = State.SIGN


func _resolve(i: int) -> void:
	bar.visible = false
	var ok := false
	if i >= 0:
		ok = opts[i]["ok"]
	result_good = ok
	if ok:
		streak += 1
		handled += 1
		var gain: int = 100 + int((1.0 - t) * 100.0) + streak * 10
		score += gain
		result_head = "NICE SAVE!   +%d" % gain
		result_text = ev["good"]
		driver_line = Events.THANKS.pick_random()
		mood = "happy"
		_burst(Vector2(W * 0.5, 380), Color("ffd21f"), 45, 380.0, 240.0)
	else:
		streak = 0
		strikes += 1
		if i < 0:
			result_head = "TOO SLOW!"
			result_text = ev["late"]
		else:
			result_head = "WRONG THING TO SAY!"
			result_text = opts[i]["r"]
		driver_line = Events.BLAME.pick_random()
		mood = "scared"
		shake = 28.0
		flash = 0.85
		flash_col = Color(0.9, 0.08, 0.08)
		_burst(Vector2(W * 0.5, 420), Color.html(ev["fx"]), 110, 650.0, 520.0)
		_add_crack()
	result_timer = 3.6 + float(result_text.length()) * 0.03
	state = State.RESULT


func _game_over() -> void:
	state = State.OVER
	over_lock = 1.3
	epitaph = Events.EPITAPHS.pick_random()
	if score > best:
		best = score
		new_best = true
		_save_best()


func _load_best() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		best = int(cf.get_value("game", "best", 0))


func _save_best() -> void:
	var cf := ConfigFile.new()
	cf.set_value("game", "best", best)
	cf.save(SAVE_PATH)


func _burst(pos: Vector2, col: Color, n: int, spd: float, grav: float) -> void:
	for i in n:
		var a: float = rng.randf() * TAU
		var v: Vector2 = Vector2(cos(a), sin(a)) * rng.randf_range(0.2, 1.0) * spd
		particles.append({"p": pos, "v": v, "l": rng.randf_range(0.8, 1.8), "g": grav, "c": col, "s": rng.randf_range(4.0, 11.0)})


func _add_crack() -> void:
	var o := Vector2(rng.randf_range(320, 980), rng.randf_range(150, 460))
	var segs: Array = []
	for i in 7:
		var a: float = rng.randf() * TAU
		var ln: float = rng.randf_range(60, 230)
		var dir := Vector2(cos(a), sin(a))
		var mid: Vector2 = o + dir * ln * 0.5 + Vector2(rng.randf_range(-14, 14), rng.randf_range(-14, 14))
		segs.append([o, mid, o + dir * ln])
	cracks.append(segs)


# ---------------------------------------------------------------- simulation

func _process(delta: float) -> void:
	anim += delta
	over_lock = maxf(0.0, over_lock - delta)
	shake = maxf(0.0, shake - 40.0 * delta)
	flash = maxf(0.0, flash - 1.4 * delta)
	var target_speed := 0.3
	match state:
		State.TITLE, State.DRIVE:
			_idle_chatter(delta)
			if state == State.DRIVE:
				gap -= delta
				if gap <= 0.0:
					_next_sign()
		State.SIGN:
			et += delta
			t = minf(1.0, t + delta / react_time)
			sign_t = t
			hc = t
			dep = t * 0.98
			if t >= 1.0:
				_resolve(-1)
		State.RESULT:
			et += delta
			result_timer -= delta
			if result_good:
				target_speed = 0.04 if result_timer > 0.9 else 0.3
				hc = minf(3.0, hc + delta * 0.55)
				sign_t += delta * 0.35
				swerve = move_toward(swerve, 1.0, delta * 1.5)
				if dep < 0.78:
					dep = minf(0.78, dep + delta * 0.25)
			else:
				target_speed = 0.0
				if hc < 1.0:
					hc = move_toward(hc, 1.0, delta * 2.0)
				dep = move_toward(dep, 0.98, delta * 1.6)
			if result_timer <= 0.0:
				if strikes >= MAX_STRIKES:
					_game_over()
				else:
					ev = {}
					mood = "calm"
					gap = rng.randf_range(1.4, 2.4)
					driver_line = Events.IDLE.pick_random()
					idle_timer = 4.0
					state = State.DRIVE
		State.OVER:
			target_speed = 0.0
	speed = move_toward(speed, target_speed, delta * 0.8)
	scroll = fposmod(scroll + speed * delta, 1.0)
	_update_palette(delta)
	_update_particles(delta)
	queue_redraw()


func _idle_chatter(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		driver_line = Events.IDLE.pick_random()
		idle_timer = 4.5


func _update_palette(delta: float) -> void:
	var tt := Color("5db3f2")
	var tb := Color("cfeaff")
	var tg := Color("4c9a3c")
	if not ev.is_empty():
		if ev.has("sky"):
			tt = Color.html(ev["sky"][0])
			tb = Color.html(ev["sky"][1])
		if ev.has("gr"):
			tg = Color.html(ev["gr"])
	var k: float = clampf(delta * 2.0, 0.0, 1.0)
	c_top = c_top.lerp(tt, k)
	c_bot = c_bot.lerp(tb, k)
	c_ground = c_ground.lerp(tg, k)


func _update_particles(delta: float) -> void:
	var i := particles.size() - 1
	while i >= 0:
		var p: Dictionary = particles[i]
		p["l"] = float(p["l"]) - delta
		if float(p["l"]) <= 0.0:
			particles.remove_at(i)
		else:
			var v: Vector2 = p["v"]
			v.y += float(p["g"]) * delta
			p["v"] = v
			p["p"] = Vector2(p["p"]) + v * delta
		i -= 1


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0.5:
		off = Vector2(rng.randf_range(-shake, shake), rng.randf_range(-shake, shake))
	draw_set_transform(off, 0.0, Vector2.ONE)
	_draw_world()
	if not ev.is_empty():
		_draw_event_objects()
	_draw_cabin()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for p in particles:
		var sz: float = p["s"]
		var col: Color = p["c"]
		col.a = clampf(float(p["l"]), 0.0, 1.0)
		var pos: Vector2 = p["p"]
		draw_rect(Rect2(pos - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)
	_draw_hud()
	if flash > 0.0:
		draw_rect(Rect2(0, 0, W, H), Color(flash_col.r, flash_col.g, flash_col.b, flash * 0.5))
	_draw_overlays()


func _draw_world() -> void:
	draw_polygon(PackedVector2Array([Vector2(-20, -20), Vector2(W + 20, -20), Vector2(W + 20, HORIZON), Vector2(-20, HORIZON)]), PackedColorArray([c_top, c_top, c_bot, c_bot]))
	var night: bool = c_top.v < 0.35
	draw_circle(Vector2(980, 120), 46.0, Color("e8ecff") if night else Color(1.0, 0.95, 0.7, 0.9))
	var hill: Color = c_ground.darkened(0.25)
	draw_circle(Vector2(220, HORIZON + 30), 170.0, hill)
	draw_circle(Vector2(760, HORIZON + 60), 220.0, hill.lightened(0.05))
	draw_circle(Vector2(1120, HORIZON + 30), 150.0, hill)
	draw_rect(Rect2(-20, HORIZON, W + 40, H - HORIZON + 20), c_ground)
	var ext: float = (H - HORIZON) / (ROAD_B - HORIZON)
	gfx.poly([Vector2(W * 0.5 - 2.0, HORIZON), Vector2(W * 0.5 + 2.0, HORIZON), Vector2(W * 0.5 + 575.0 * ext, H), Vector2(W * 0.5 - 575.0 * ext, H)], Color("3b3b42"))
	draw_line(Vector2(W * 0.5 - 1.0, HORIZON), Vector2(W * 0.5 - 520.0 * ext, H), Color(0.92, 0.92, 0.92), 6.0)
	draw_line(Vector2(W * 0.5 + 1.0, HORIZON), Vector2(W * 0.5 + 520.0 * ext, H), Color(0.92, 0.92, 0.92), 6.0)
	for i in 10:
		var d: float = fposmod(scroll + float(i) / 10.0, 1.0)
		var s0: float = gfx.scale_of(d)
		var s1: float = gfx.scale_of(minf(d + 0.045, 1.0))
		gfx.poly([gfx.P(-14, s0), gfx.P(14, s0), gfx.P(14, s1), gfx.P(-14, s1)], Color("e8e8e8"))
	var items: Array = []
	for side in [-1.0, 1.0]:
		for i in 7:
			var d2: float = fposmod(scroll + float(i) / 7.0 + (0.07 if side > 0.0 else 0.0), 1.0)
			items.append([d2, side, i])
	items.sort_custom(func(a, b): return a[0] < b[0])
	var foliage: Color = c_ground.darkened(0.4)
	for it in items:
		var s: float = gfx.scale_of(it[0])
		var x: float = float(it[1]) * (720.0 + float(int(it[2]) % 3) * 90.0)
		var base: Vector2 = gfx.P(x, s)
		draw_rect(Rect2(base.x - 14.0 * s, base.y - 150.0 * s, 28.0 * s, 150.0 * s), Color("5a3d24"))
		draw_circle(base + Vector2(0, -210.0 * s), 90.0 * s, foliage)
		draw_circle(base + Vector2(-30.0 * s, -230.0 * s), 55.0 * s, foliage.lightened(0.12))


func _draw_event_objects() -> void:
	var id: String = ev["id"]
	var s_h: float = gfx.scale_of(clampf(dep, 0.0, 1.0))
	var bad: bool = state == State.RESULT and not result_good
	if not haz_a.draw(id, s_h, hc, et, bad, swerve):
		haz_b.draw(id, s_h, hc, et, bad, swerve)
	if sign_t < 1.2:
		var ss: float = gfx.scale_of(sign_t)
		var gp: Vector2 = gfx.P(640, ss)
		var top: Vector2 = gp + Vector2(0, -330.0 * ss)
		draw_line(gp, top, Color("9a9aa2"), maxf(2.0, 10.0 * ss))
		gfx.sign_plate(ev["shape"], top, 150.0 * ss, Color.html(ev["c"]), Color.html(ev["ink"]), ev["glyph"])


func _draw_cabin() -> void:
	var dark := Color("17171c")
	gfx.rc(Vector2(W * 0.5, 4), W + 40.0, 54.0, dark)
	gfx.poly([Vector2(-20, -20), Vector2(110, -20), Vector2(40, ROAD_B), Vector2(-20, ROAD_B)], dark)
	gfx.poly([Vector2(W + 20, -20), Vector2(W - 110, -20), Vector2(W - 40, ROAD_B), Vector2(W + 20, ROAD_B)], dark)
	gfx.rc(Vector2(W * 0.5, 66), 220.0, 58.0, Color("0f0f13"))
	gfx.rc(Vector2(W * 0.5, 66), 206.0, 46.0, Color("2d4054"))
	gfx.line(Vector2(W * 0.5 - 60, 84), Vector2(W * 0.5 + 60, 54), Color(0.9, 0.9, 0.9, 0.5), 3.0)
	for segs in cracks:
		for sg in segs:
			draw_polyline(PackedVector2Array(sg), Color(1, 1, 1, 0.75), 2.0)
	_draw_driver()
	gfx.rc(Vector2(W * 0.5, 660), W + 40.0, 130.0, Color("23232b"))
	draw_line(Vector2(0, ROAD_B), Vector2(W, ROAD_B), Color("3d3d4a"), 4.0)


func _draw_driver() -> void:
	var skin := Color("e0b090")
	var ink := Color("2a1a1a")
	var hp := Vector2(255, 425 + sin(anim * 2.0) * 2.0)
	gfx.poly([Vector2(120, 600), Vector2(140, 520), Vector2(200, 478), Vector2(310, 478), Vector2(370, 520), Vector2(390, 600)], Color("5a4a8a"))
	gfx.rc(Vector2(255, 468), 30.0, 26.0, skin)
	draw_circle(hp, 46.0, skin)
	draw_circle(hp + Vector2(-46, 6), 9.0, skin)
	draw_circle(hp + Vector2(46, 6), 9.0, skin)
	gfx.el(hp + Vector2(0, -26), 50.0, 28.0, Color("3a2a1a"))
	if mood == "scared":
		for sx in [-18.0, 18.0]:
			draw_circle(hp + Vector2(sx, -5), 11.0, Color.WHITE)
			draw_circle(hp + Vector2(sx + sin(anim * 30.0) * 2.0, -5), 3.5, Color.BLACK)
		gfx.line(hp + Vector2(-30, -22), hp + Vector2(-8, -28), ink, 3.0)
		gfx.line(hp + Vector2(30, -22), hp + Vector2(8, -28), ink, 3.0)
		gfx.el(hp + Vector2(0, 26), 11.0, 15.0, Color("3a1010"))
	else:
		gfx.rc(hp + Vector2(0, -4), 80.0, 15.0, Color("0c0c10"))
		if mood == "happy":
			draw_arc(hp + Vector2(0, 18), 15.0, 0.2, PI - 0.2, 12, ink, 3.0)
		else:
			gfx.line(hp + Vector2(-12, 26), hp + Vector2(12, 26), ink, 3.0)
	draw_arc(Vector2(255, 612), 94.0, PI, TAU, 40, Color("1d1d22"), 14.0)
	draw_circle(Vector2(165, 585), 15.0, skin)
	draw_circle(Vector2(345, 585), 15.0, skin)
	if driver_line != "" and state != State.OVER:
		var h: float = gfx.bubble(Vector2(24, 150), driver_line, 232.0, Color("fff8e0"), Color("222222"), 18)
		var by: float = 150.0 + h
		gfx.poly([Vector2(80, by - 3), Vector2(140, by - 3), Vector2(205, 372)], Color("fff8e0"))
		gfx.line(Vector2(80, by - 3), Vector2(205, 372), Color("222222"), 3.0)
		gfx.line(Vector2(140, by - 3), Vector2(205, 372), Color("222222"), 3.0)


func _draw_hud() -> void:
	if state == State.TITLE:
		return
	gfx.txt("SCORE", Vector2(22, 34), 16, Color("cfd8ff"))
	gfx.txt(str(score), Vector2(22, 66), 30, Color.WHITE)
	gfx.txt("BEST %d" % best, Vector2(22, 90), 16, Color("cfd8ff"))
	if streak >= 2:
		gfx.txt("STREAK x%d" % streak, Vector2(22, 114), 18, Color("ffd21f"))
	gfx.txt("STRIKES", Vector2(W - 190, 30), 16, Color("ffd0d0"), HORIZONTAL_ALIGNMENT_RIGHT, 170.0)
	for i in MAX_STRIKES:
		var cx: float = W - 36.0 - float(i) * 44.0
		var used: bool = (MAX_STRIKES - 1 - i) < strikes
		draw_circle(Vector2(cx, 62), 17.0, Color("d62828") if used else Color(0, 0, 0, 0.5))
		draw_arc(Vector2(cx, 62), 17.0, 0.0, TAU, 24, Color.WHITE, 2.0)
		if used:
			gfx.line(Vector2(cx - 8, 54), Vector2(cx + 8, 70), Color.WHITE, 4.0)
			gfx.line(Vector2(cx + 8, 54), Vector2(cx - 8, 70), Color.WHITE, 4.0)
	if ev.is_empty():
		return
	gfx.panel(Rect2(290, 10, 700, 114), Color(0.05, 0.05, 0.1, 0.84), Color("e8e8f0"))
	gfx.sign_plate(ev["shape"], Vector2(352, 64), 62.0, Color.html(ev["c"]), Color.html(ev["ink"]), ev["glyph"])
	gfx.txt(ev["name"], Vector2(412, 44), 26, Color("ffd21f"))
	draw_multiline_string(gfx.font, Vector2(412, 72), ev["scene"], HORIZONTAL_ALIGNMENT_LEFT, 560.0, 17, -1, Color.WHITE)
	if state == State.SIGN:
		draw_rect(Rect2(300, 108, 680, 8), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(300, 108, 680.0 * (1.0 - t), 8), Color("4ac26b").lerp(Color("e8453c"), t))
	elif state == State.RESULT:
		var sz: Vector2 = gfx.font.get_multiline_string_size(result_text, HORIZONTAL_ALIGNMENT_LEFT, 660.0, 21)
		var fill := Color(0.08, 0.42, 0.2, 0.95) if result_good else Color(0.55, 0.07, 0.07, 0.95)
		gfx.panel(Rect2(290, 134, 700, sz.y + 76.0), fill, Color.WHITE)
		gfx.txt(result_head, Vector2(312, 174), 32, Color.WHITE)
		draw_multiline_string(gfx.font, Vector2(312, 206), result_text, HORIZONTAL_ALIGNMENT_LEFT, 660.0, 21, -1, Color.WHITE)


func _draw_overlays() -> void:
	var blink: bool = fmod(anim, 1.2) < 0.8
	if state == State.TITLE:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.62))
		gfx.txt("BACKSEAT DRIVER", Vector2(0, 190), 84, Color("ffd21f"), HORIZONTAL_ALIGNMENT_CENTER, W)
		gfx.txt("You are the front-seat passenger. The driver is... confident.", Vector2(0, 244), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
		var lines: Array = [
			"Signs and hazards are coming. Read them. Say the right thing. Fast.",
			"Press 1 / 2 / 3, or click a button, to speak to the driver.",
			"Say nothing, or the wrong thing, and the sign takes its revenge.",
			"Three strikes and the car is totaled. (Dark humor. You were warned.)",
		]
		for i in lines.size():
			gfx.txt(lines[i], Vector2(0, 330.0 + float(i) * 36.0), 22, Color("cfd8ff"), HORIZONTAL_ALIGNMENT_CENTER, W)
		if blink:
			gfx.txt("PRESS SPACE OR CLICK TO START", Vector2(0, 560), 34, Color("4ac26b"), HORIZONTAL_ALIGNMENT_CENTER, W)
	elif state == State.OVER:
		draw_rect(Rect2(0, 0, W, H), Color(0.25, 0, 0, 0.78))
		gfx.txt("TOTALED", Vector2(0, 180), 110, Color("ff4a3a"), HORIZONTAL_ALIGNMENT_CENTER, W)
		gfx.txt("Score: %d" % score, Vector2(0, 250), 38, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, W)
		var sub: String = "NEW BEST!" if new_best else "Best: %d" % best
		gfx.txt(sub, Vector2(0, 295), 26, Color("ffd21f"), HORIZONTAL_ALIGNMENT_CENTER, W)
		draw_multiline_string(gfx.font, Vector2(240, 380), epitaph, HORIZONTAL_ALIGNMENT_CENTER, 800.0, 26, -1, Color("ffe0d8"))
		if over_lock <= 0.0 and blink:
			gfx.txt("PRESS SPACE OR CLICK TO RIDE AGAIN", Vector2(0, 560), 32, Color("4ac26b"), HORIZONTAL_ALIGNMENT_CENTER, W)
