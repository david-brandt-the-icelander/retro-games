class_name Hud
extends Control
## HUD strip (oxygen, jetpack fuel, collapse timer, cargo, credits, lives), context prompts,
## pickup pop-ups and the overlay screens (title, banners, pause, game over, victory).

var main: Main
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos + Vector2(0, 2), s, align, width, size, 6, Color(0, 0, 0, 0.6 * col.a))
	draw_string(font, pos, s, align, width, size, col)


func _label(pos: Vector2, s: String) -> void:
	_text(pos, s, 13, Color(0.6, 0.62, 0.7))


func _bar(pos: Vector2, w: float, frac: float, col: Color, flash: bool) -> void:
	draw_rect(Rect2(pos, Vector2(w, 12)), Color(0.1, 0.1, 0.14))
	var c := col
	if flash and fmod(Time.get_ticks_msec() / 1000.0, 0.4) < 0.2:
		c = Color(3.0, 0.6, 0.5)
	draw_rect(Rect2(pos, Vector2(w * clampf(frac, 0.0, 1.0), 12)), Color(c.r * 1.6, c.g * 1.6, c.b * 1.6))
	draw_rect(Rect2(pos, Vector2(w, 12)), Color(1, 1, 1, 0.25), false, 1.0)


func _blink() -> float:
	return 0.55 + 0.45 * sin(Time.get_ticks_msec() / 260.0)


func _draw() -> void:
	if main == null or main.level == null:
		return
	var lv := main.level
	var p := lv.player
	var tint := lv.tint
	var bright := Color(tint.r * 2.2, tint.g * 2.2, tint.b * 2.2)
	var white := Color(0.95, 0.95, 1.0)

	# pickup pop-ups (screen space == world space: the camera is fixed)
	for pop in main.popups:
		var k: float = clampf(float(pop["t"]) / 1.3, 0.0, 1.0)
		var c: Color = pop["color"]
		var pos: Vector2 = pop["pos"] + Vector2(0, -24.0 - (1.0 - k) * 30.0)
		_text(pos - Vector2(100, 0), pop["text"], 15, Color(c.r * 1.6, c.g * 1.6, c.b * 1.6, minf(1.0, k * 2.0)), HORIZONTAL_ALIGNMENT_CENTER, 200)

	# --- bottom panel
	var top := 640.0
	draw_polygon(PackedVector2Array([Vector2(0, top), Vector2(1280, top), Vector2(1280, 720), Vector2(0, 720)]),
			PackedColorArray([Color(0.06, 0.06, 0.1), Color(0.06, 0.06, 0.1), Color(0.02, 0.02, 0.04), Color(0.02, 0.02, 0.04)]))
	draw_rect(Rect2(0, top, 1280, 2), bright)
	_label(Vector2(20, top + 28), "SHAFT %d" % (main.level_index + 1))
	_text(Vector2(20, top + 56), lv.level_name, 20, white)

	_label(Vector2(270, top + 28), "OXYGEN")
	_bar(Vector2(270, top + 38), 170, p.oxygen, Color(0.35, 0.95, 1.0), not p.in_buggy and p.oxygen < 0.25)
	_label(Vector2(270, top + 66), "JET FUEL")
	_bar(Vector2(340, top + 56), 100, p.fuel, Color(1.0, 0.6, 0.2), p.fuel < 0.15)

	var secs := main.collapse_seconds()
	var cc := Color(1.0, 0.85, 0.3).lerp(Color(1.0, 0.25, 0.2), clampf(1.0 - main.collapse * 2.0, 0.0, 1.0))
	_label(Vector2(470, top + 28), "COLLAPSE IN")
	_bar(Vector2(470, top + 38), 200, main.collapse, cc, secs < 15.0)
	var tcol := Color(3.0, 0.7, 0.5) if secs < 15.0 and fmod(Time.get_ticks_msec() / 1000.0, 0.5) < 0.25 else white
	_text(Vector2(470, top + 70), "%d:%02d" % [int(secs) / 60, int(secs) % 60], 20, tcol)

	var got := lv.ore_total - lv.ore.size()
	_label(Vector2(700, top + 28), "ORE")
	_text(Vector2(700, top + 58), "%d / %d" % [got, lv.ore_total], 22, Color(0.6, 2.4, 1.2) if got == lv.ore_total else white)

	_label(Vector2(810, top + 28), "CREDITS")
	_text(Vector2(810, top + 58), _credits(main.score), 22, white)

	_label(Vector2(990, top + 28), "STATUS")
	var status := "IN BUGGY · REFILLING" if p.in_buggy and (p.oxygen < 1.0 or p.fuel < 1.0) else ("IN BUGGY" if p.in_buggy else "EVA")
	if lv.door_open:
		status += "  ·  TUNNEL OPEN"
	_text(Vector2(990, top + 56), status, 14, Color(0.6, 2.2, 1.2) if lv.door_open else Color(0.8, 0.82, 0.9))

	_label(Vector2(1180, top + 28), "MINERS")
	for i in maxi(main.lives, 0):
		_draw_life_icon(Vector2(1188 + i * 24, top + 50))

	# --- context prompts
	if main.state == Main.State.PLAYING and p.alive:
		var prompt := ""
		if p.in_buggy:
			if lv.door_open:
				prompt = "Drive right, into the tunnel"
			else:
				prompt = "[E] step out    LEFT / RIGHT drive"
		elif lv.buggy_in_reach():
			prompt = "[E] board buggy  (refills oxygen and fuel)"
		elif p.oxygen < 0.25:
			prompt = "LOW OXYGEN, get back to the buggy!"
		if prompt != "":
			_text(Vector2(0, 628), prompt, 16, Color(1.6, 1.6, 1.8, _blink()), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	_draw_touch_buttons()

	# --- overlays
	match main.state:
		Main.State.TITLE:
			_draw_title()
		Main.State.PAUSED:
			_dim(0.55)
			_text(Vector2(0, 320), "PAUSED", 56, Color(2.0, 2.0, 2.2), HORIZONTAL_ALIGNMENT_CENTER, 1280)
			_text(Vector2(0, 370), "Esc to resume  ·  R to abandon this shaft (costs a miner)", 20, Color(0.8, 0.8, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		Main.State.GAMEOVER:
			_dim(0.6)
			_text(Vector2(0, 300), "CLAIM LOST", 64, Color(3.0, 0.8, 0.7), HORIZONTAL_ALIGNMENT_CENTER, 1280)
			_text(Vector2(0, 360), "Haul %s   ·   Best %s" % [_credits(main.score), _credits(main.hiscore)], 24, white, HORIZONTAL_ALIGNMENT_CENTER, 1280)
			if main.last_rank >= 0:
				_text(Vector2(0, 400), "A place on the table: number %d" % (main.last_rank + 1), 20, Color(2.2, 1.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 1280)
			_text(Vector2(0, 450), "Press SPACE", 24, Color(1.6, 1.6, 1.8, _blink()), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		Main.State.WON:
			_draw_victory()
		Main.State.SCORES:
			_draw_scores()
	if main.banner_t > 0.0 and main.state != Main.State.TITLE:
		var k := clampf(main.banner_t, 0.0, 1.0)
		var y := 250.0 - (1.0 - k) * 20.0
		draw_rect(Rect2(0, y - 46, 1280, 76), Color(0, 0, 0, 0.45 * k))
		_text(Vector2(0, y), main.banner_text, 40, Color(bright.r, bright.g, bright.b, k), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if main.banner_sub != "":
			_text(Vector2(0, y + 24), main.banner_sub, 16, Color(0.85, 0.85, 0.95, k), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_touch_buttons() -> void:
	if not DisplayServer.is_touchscreen_available():
		return
	for b in Main.TOUCH_BUTTONS:
		var c: Vector2 = b[1]
		var r: float = b[2]
		var held := Input.is_action_pressed(b[0])
		draw_circle(c, r, Color(1, 1, 1, 0.16 if held else 0.07))
		draw_arc(c, r, 0, TAU, 40, Color(1, 1, 1, 0.35), 2.0)
		var ink := Color(1, 1, 1, 0.7)
		var k := r * 0.38
		match String(b[3]):
			"left":
				draw_colored_polygon(PackedVector2Array([c + Vector2(-k, 0), c + Vector2(k * 0.7, -k), c + Vector2(k * 0.7, k)]), ink)
			"right":
				draw_colored_polygon(PackedVector2Array([c + Vector2(k, 0), c + Vector2(-k * 0.7, -k), c + Vector2(-k * 0.7, k)]), ink)
			"up":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0, -k), c + Vector2(k, k * 0.7), c + Vector2(-k, k * 0.7)]), ink)
			"pause":
				draw_rect(Rect2(c + Vector2(-k * 0.7, -k), Vector2(k * 0.5, k * 2)), ink)
				draw_rect(Rect2(c + Vector2(k * 0.2, -k), Vector2(k * 0.5, k * 2)), ink)
			_:
				_text(c + Vector2(-r, 8), b[3], int(r * 0.55), ink, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0)


func _credits(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return "₵" + s + out if font.has_char(0x20B5) else "CR " + s + out


func _dim(a: float) -> void:
	draw_rect(Rect2(0, 0, 1280, 640), Color(0.0, 0.0, 0.02, a))


func _draw_title() -> void:
	_dim(0.6)
	var tt := Time.get_ticks_msec() / 1000.0
	var g := 2.2 + 0.4 * sin(tt * 2.0)
	_text(Vector2(0, 150), "DEEP CLAIM", 92, Color(g * 1.1, g * 0.75, g * 0.35), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var story := [
		"Earth's rare-earth seams are exhausted, or locked up by a handful of oligarchs.",
		"And hauling titanium and aluminium up the gravity well costs more than the metal is worth.",
		"So you go where the metal is: the mine shafts of asteroid 4471 Halvard.",
		"Grab the ore, keep your suit breathing, and drive out before each shaft caves in.",
	]
	for i in story.size():
		_text(Vector2(0, 205 + i * 28), story[i], 19, Color(0.82, 0.84, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var go := "Tap JUMP to suit up" if DisplayServer.is_touchscreen_available() else "Press SPACE to suit up"
	_text(Vector2(0, 375), go, 26, Color(1.6, 1.6, 1.8, _blink()), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var lines := [
		"Arrows or A D   walk / drive        SPACE, W or UP   jump        hold it in the air   jetpack",
		"E, S or DOWN   board or leave the buggy (it refills oxygen and fuel)        Esc   pause",
		"Collect all the ore to open the exit tunnel, then drive through it before the timer runs out.",
	]
	for i in lines.size():
		_text(Vector2(0, 450 + i * 26), lines[i], 15, Color(0.6, 0.62, 0.72), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	if main.hiscore > 0:
		_text(Vector2(0, 560), "BEST HAUL %s" % _credits(main.hiscore), 18, Color(0.9, 0.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_victory() -> void:
	_dim(0.7)
	var tt := Time.get_ticks_msec() / 1000.0
	var g := 2.3 + 0.4 * sin(tt * 2.0)
	var gold := Color(g, g * 0.82, g * 0.4)
	# a few drifting sparks of ore light behind the title
	for i in 18:
		var ph := float(i) * 0.7
		var x := fposmod(120.0 + float(i) * 67.0 + sin(tt * 0.6 + ph) * 30.0, 1280.0)
		var y := 70.0 + fposmod(float(i) * 41.0 - tt * 22.0, 150.0)
		draw_circle(Vector2(x, y), 2.0 + sin(tt * 3.0 + ph), Color(gold.r, gold.g, gold.b, 0.5))
	_text(Vector2(0, 150), "CLAIM WORKED OUT", 72, gold, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text(Vector2(0, 200), "All %d shafts of asteroid 4471 Halvard are cleared." % main.cleared, 22, Color(0.9, 0.92, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text(Vector2(0, 232), "The haul goes to orbit, no gravity well to climb.", 18, Color(0.75, 0.78, 0.9), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	var rows := [
		["Shafts cleared", "%d / %d" % [main.cleared, Levels.DATA.size()]],
		["Miners brought home", "%d" % main.lives],
		["Miner bonus", _credits(main.miner_bonus)],
		["Final haul", _credits(main.score)],
		["Best haul", _credits(main.hiscore)],
	]
	for i in rows.size():
		var y := 315.0 + i * 40.0
		var big: bool = i == 3
		_text(Vector2(360, y), rows[i][0], 24 if big else 20, white if big else Color(0.75, 0.78, 0.9))
		_text(Vector2(0, y), rows[i][1], 24 if big else 20, gold if big else white, HORIZONTAL_ALIGNMENT_RIGHT, 920)
	if main.last_rank >= 0:
		var msg := "NEW BEST HAUL!" if main.last_rank == 0 else "A place on the table: number %d" % (main.last_rank + 1)
		_text(Vector2(0, 540), msg, 26, Color(2.4, 2.0, 1.0, 0.7 + 0.3 * sin(tt * 5.0)), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text(Vector2(0, 595), "Press SPACE", 22, Color(1.6, 1.6, 1.8, _blink()), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_scores() -> void:
	_dim(0.8)
	var tt := Time.get_ticks_msec() / 1000.0
	_text(Vector2(0, 110), "BEST HAULS", 64, Color(2.2, 1.7, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_text(Vector2(300, 170), "RANK", 16, Color(0.6, 0.62, 0.72))
	_text(Vector2(430, 170), "HAUL", 16, Color(0.6, 0.62, 0.72))
	_text(Vector2(0, 170), "SHAFTS", 16, Color(0.6, 0.62, 0.72), HORIZONTAL_ALIGNMENT_RIGHT, 980)
	for i in main.scores.size():
		var y := 205.0 + i * 36.0
		var mine: bool = i == main.last_rank
		var col := Color(2.4, 2.0, 1.0, 0.75 + 0.25 * sin(tt * 6.0)) if mine else Color(0.85, 0.87, 0.95)
		_text(Vector2(300, y), "%d" % (i + 1), 22, col)
		_text(Vector2(430, y), _credits(int(main.scores[i]["score"])), 22, col)
		var n := int(main.scores[i]["shafts"])
		_text(Vector2(0, y), "%d" % n if n > 0 else "-", 22, col, HORIZONTAL_ALIGNMENT_RIGHT, 980)
		if mine:
			_text(Vector2(1000, y), "< YOU", 18, col)
	_text(Vector2(0, 600), "Press SPACE", 22, Color(1.6, 1.6, 1.8, _blink()), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_life_icon(c: Vector2) -> void:
	draw_circle(c, 9.0, Color(0.03, 0.03, 0.06))
	draw_circle(c, 7.5, Color(0.9, 0.91, 0.94))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(6, -4), c + Vector2(7, 0), c + Vector2(5, 4), c + Vector2(0, 4)]), Color(0.95, 0.68, 0.18))
