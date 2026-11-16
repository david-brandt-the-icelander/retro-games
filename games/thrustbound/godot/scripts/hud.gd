extends Control
## HUD, messages, title / pause / game-over overlays. All drawn in code.

const Gfx = preload("res://scripts/gfx.gd")

var score := 0
var hiscore := 0
var lives := 0
var level := 1
var fuel := 0
var fuel_needed := 6
var segments := 1
var state := "title"
var paused := false

var msg := ""
var sub := ""
var msg_t := 0.0
var msg_dur := 1.0
var t := 0.0
var font: Font


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	var sf := SystemFont.new()
	sf.font_names = PackedStringArray(["Avenir Next", "Futura", "Segoe UI", "Helvetica Neue", "Roboto", "DejaVu Sans", "Sans-Serif"])
	sf.font_weight = 700
	font = sf


func show_message(m: String, s: String = "", dur: float = 2.6) -> void:
	msg = m
	sub = s
	msg_t = dur
	msg_dur = dur


func tick(delta: float) -> void:
	t += delta
	msg_t = maxf(0.0, msg_t - delta)
	queue_redraw()


func _txt(s: String, pos: Vector2, sz: int, col: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, w: float = -1.0, outline: int = 6) -> void:
	draw_string_outline(font, pos, s, align, w, sz, outline, Color(0, 0, 0, 0.55 * col.a))
	draw_string(font, pos, s, align, w, sz, col)


func _draw() -> void:
	if state == "title":
		_draw_title()
		return
	var dim := Color(0.55, 0.7, 0.9, 0.85)
	var white := Color(0.95, 0.97, 1.0)
	Gfx.vgrad_rect(self, Rect2(0, 0, 1280, 62), Color(0, 0, 0.02, 0.7), Color(0, 0, 0.02, 0.0))
	_txt("SCORE", Vector2(28, 22), 13, dim)
	_txt("%06d" % score, Vector2(28, 50), 28, white)
	_txt("HI-SCORE", Vector2(0, 22), 13, dim, HORIZONTAL_ALIGNMENT_CENTER, 1280)
	_txt("%06d" % hiscore, Vector2(0, 50), 28, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	# lives
	for i in maxi(lives - 1, 0):
		var c := Vector2(178 + i * 22, 42)
		draw_circle(c, 7.5, Color(0.9, 0.92, 0.97))
		draw_circle(c + Vector2(2.5, 0), 4.5, Color(0.15, 0.55, 1.2))

	# rocket status (right)
	var rx := 1252.0
	_txt("LEVEL %d" % level, Vector2(rx - 400, 22), 13, dim, HORIZONTAL_ALIGNMENT_RIGHT, 400)
	if segments < 3:
		_txt("BUILD", Vector2(rx - 120, 48), 14, dim)
		for i in 3:
			var on := i < segments
			var r := Rect2(rx - 66 + i * 22, 34, 16, 16)
			draw_rect(r, Color(0.5, 1.8, 2.2) if on else Color(0.2, 0.25, 0.35))
	else:
		_txt("FUEL", Vector2(rx - 170, 48), 14, dim)
		for i in fuel_needed:
			var on := i < fuel
			var r := Rect2(rx - 124 + i * 21, 36, 15, 13)
			draw_rect(r, Color(1.6, 0.4, 2.4) if on else Color(0.2, 0.18, 0.3))

	if msg_t > 0.0:
		var a := clampf(minf(msg_t, msg_dur - msg_t) * 4.0, 0.0, 1.0)
		_txt(msg, Vector2(0, 300), 54, Color(1.5, 1.2, 2.2, a), HORIZONTAL_ALIGNMENT_CENTER, 1280, 10)
		if sub != "":
			_txt(sub, Vector2(0, 340), 22, Color(0.8, 0.9, 1.0, a), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	if state == "gameover":
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0.03, 0.55))
		_txt("GAME OVER", Vector2(0, 320), 84, Color(2.4, 0.6, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280, 10)
		_txt("Score %d" % score, Vector2(0, 375), 26, white, HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if score >= hiscore and score > 0:
			_txt("NEW HI-SCORE!", Vector2(0, 415), 24, Color(2.2, 1.8, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 1280)
		if fmod(t, 1.0) < 0.65:
			_txt("PRESS ENTER", Vector2(0, 500), 24, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	if paused:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0.03, 0.5))
		_txt("PAUSED", Vector2(0, 350), 64, Color(0.6, 1.6, 2.2), HORIZONTAL_ALIGNMENT_CENTER, 1280, 10)
		_txt("Esc to resume", Vector2(0, 395), 20, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 1280)


func _draw_title() -> void:
	Gfx.vgrad_rect(self, Rect2(0, 0, 1280, 720), Color(0, 0, 0.03, 0.5), Color(0, 0, 0.03, 0.8))
	var pulse := 0.85 + 0.15 * sin(t * 2.0)
	_txt("THRUSTBOUND", Vector2(0, 250), 108, Color(1.3 * pulse, 0.95 * pulse, 2.3 * pulse), HORIZONTAL_ALIGNMENT_CENTER, 1280, 12)
	_txt("ASSEMBLE   /   REFUEL   /   ESCAPE", Vector2(0, 298), 20, Color(0.6, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	var lines := [
		["MOVE", "A / D   or   LEFT / RIGHT"],
		["JETPACK", "W   or   UP"],
		["FIRE", "SPACE   or   J"],
		["PAUSE", "ESC"],
	]
	var y := 390.0
	for l in lines:
		_txt(l[0], Vector2(0, y), 16, Color(0.55, 0.7, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 610)
		_txt(l[1], Vector2(670, y), 16, Color(0.95, 0.97, 1.0))
		y += 30.0
	_txt("Gamepad: stick to move, A to thrust, X / RB to fire", Vector2(0, y + 6), 14, Color(0.55, 0.65, 0.8), HORIZONTAL_ALIGNMENT_CENTER, 1280)

	if fmod(t, 1.0) < 0.65:
		_txt("PRESS ENTER TO START", Vector2(0, 610), 28, Color(2.2, 1.7, 0.5), HORIZONTAL_ALIGNMENT_CENTER, 1280, 8)
	_txt("HI-SCORE  %06d" % hiscore, Vector2(0, 665), 18, Color(1.0, 0.85, 0.45), HORIZONTAL_ALIGNMENT_CENTER, 1280)
