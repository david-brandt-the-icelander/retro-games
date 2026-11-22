extends Node2D
## Sky, nebulae, ringed planet, mountains, ground, launch pad and the floating platforms.

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")

const PLANET_C := Vector2(1080, 150)
const PLANET_R := 64.0

var stars := []
var t := 0.0
var far_hills := PackedVector2Array()
var near_hills := PackedVector2Array()
var planet_shadow := []
var rocks := []


func _ready() -> void:
	z_index = -10
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	for i in 260:
		var tint: Color = [Color(1, 1, 1), Color(0.75, 0.85, 1.0), Color(1.0, 0.9, 0.75), Color(0.9, 0.8, 1.0)][rng.randi() % 4]
		stars.append({
			"p": Vector2(rng.randf() * W.WIDTH, rng.randf() * (W.GROUND_Y - 40)),
			"s": rng.randf_range(0.6, 1.8) if rng.randf() < 0.9 else rng.randf_range(2.0, 2.8),
			"ph": rng.randf() * TAU,
			"sp": rng.randf_range(0.6, 3.0),
			"c": tint,
		})
	far_hills = _hills(rng, 560.0, 50.0, 0.006, W.GROUND_Y + 2)
	near_hills = _hills(rng, 610.0, 34.0, 0.013, W.GROUND_Y + 2)
	var disc := Gfx.ellipse(PLANET_C, PLANET_R, PLANET_R, 48)
	var lit := Gfx.ellipse(PLANET_C + Vector2(-26, -18), PLANET_R * 1.05, PLANET_R * 1.05, 48)
	planet_shadow = Geometry2D.clip_polygons(disc, lit)
	for i in 70:
		rocks.append({
			"p": Vector2(rng.randf() * W.WIDTH, rng.randf_range(W.GROUND_Y + 10, W.HEIGHT)),
			"r": rng.randf_range(2, 7),
			"c": rng.randf_range(0.0, 1.0),
		})


func _hills(rng: RandomNumberGenerator, base: float, amp: float, freq: float, bottom: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var o1 := rng.randf() * 100.0
	var o2 := rng.randf() * 100.0
	var x := 0.0
	while x <= W.WIDTH:
		var y := base - amp * (0.6 * sin(x * freq + o1) + 0.4 * sin(x * freq * 2.7 + o2)) - amp * 0.2 * absf(sin(x * freq * 6.1))
		pts.append(Vector2(x, y))
		x += 16.0
	pts.append(Vector2(W.WIDTH, bottom))
	pts.append(Vector2(0, bottom))
	return pts


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	# sky
	Gfx.vgrad_rect(self, Rect2(0, 0, W.WIDTH, W.GROUND_Y), Color(0.015, 0.02, 0.06), Color(0.13, 0.05, 0.2))
	# nebulae
	Gfx.glow(self, Vector2(280, 210), 420, Color(0.35, 0.08, 0.5, 0.32))
	Gfx.glow(self, Vector2(1000, 470), 460, Color(0.05, 0.22, 0.45, 0.32))
	Gfx.glow(self, Vector2(660, 110), 300, Color(0.5, 0.12, 0.3, 0.22))
	Gfx.glow(self, Vector2(520, 560), 360, Color(0.6, 0.2, 0.35, 0.18))
	# stars
	for s in stars:
		var a: float = 0.55 + 0.45 * sin(t * s["sp"] + s["ph"])
		var sz: float = s["s"]
		var c: Color = s["c"]
		if sz > 1.9:
			draw_circle(s["p"], sz * 0.6, Gfx.hdr(c, 1.6 + a))
			Gfx.glow(self, s["p"], sz * 4.0, Color(c.r, c.g, c.b, 0.25 * a))
		else:
			draw_circle(s["p"], sz * 0.5, Color(c.r, c.g, c.b, 0.35 + 0.65 * a))
	_draw_planet()
	# small moon
	draw_circle(Vector2(170, 120), 16, Color(0.55, 0.52, 0.62))
	draw_circle(Vector2(176, 124), 14, Color(0.38, 0.35, 0.45))
	draw_circle(Vector2(164, 115), 3, Color(0.48, 0.45, 0.55))
	# hills
	draw_colored_polygon(far_hills, Color(0.1, 0.05, 0.17))
	draw_polyline(far_hills.slice(0, far_hills.size() - 2), Color(0.5, 0.3, 0.8, 0.35), 1.5, true)
	draw_colored_polygon(near_hills, Color(0.065, 0.035, 0.11))
	draw_polyline(near_hills.slice(0, near_hills.size() - 2), Color(0.8, 0.35, 0.9, 0.3), 1.0, true)
	_draw_ground()
	_draw_pad()
	for r in W.platforms():
		_draw_platform(r)


func _draw_planet() -> void:
	var c := PLANET_C
	Gfx.glow(self, c, PLANET_R * 2.4, Color(0.9, 0.5, 0.3, 0.22))
	# back half of ring
	draw_set_transform(c, -0.32, Vector2(1, 0.26))
	draw_arc(Vector2.ZERO, PLANET_R * 1.75, PI, TAU, 48, Color(0.95, 0.75, 0.55, 0.55), 7.0, true)
	draw_arc(Vector2.ZERO, PLANET_R * 1.55, PI, TAU, 48, Color(0.8, 0.55, 0.45, 0.35), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(c, PLANET_R, Color(0.86, 0.5, 0.36))
	draw_circle(c + Vector2(-8, -18), PLANET_R * 0.72, Color(0.95, 0.62, 0.42, 0.5))
	draw_circle(c + Vector2(10, 22), PLANET_R * 0.5, Color(0.7, 0.35, 0.3, 0.5))
	for poly in planet_shadow:
		draw_colored_polygon(poly, Color(0.08, 0.03, 0.12, 0.78))
	# front half of ring
	draw_set_transform(c, -0.32, Vector2(1, 0.26))
	draw_arc(Vector2.ZERO, PLANET_R * 1.75, 0.0, PI, 48, Color(1.1, 0.85, 0.6, 0.85), 7.0, true)
	draw_arc(Vector2.ZERO, PLANET_R * 1.55, 0.0, PI, 48, Color(0.85, 0.6, 0.5, 0.55), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_ground() -> void:
	Gfx.vgrad_rect(self, Rect2(0, W.GROUND_Y, W.WIDTH, W.HEIGHT - W.GROUND_Y), Color(0.2, 0.12, 0.25), Color(0.04, 0.02, 0.07))
	for r in rocks:
		var c: float = r["c"]
		draw_circle(r["p"], r["r"], Color(0.28 + c * 0.1, 0.18, 0.3 + c * 0.08, 0.7))
		draw_circle(r["p"] + Vector2(-1, -1), r["r"] * 0.5, Color(0.4, 0.3, 0.45, 0.5))
	# glowing fissures
	for i in 6:
		var x := 90.0 + i * 205.0
		var a := 0.6 + 0.4 * sin(t * 1.5 + i)
		draw_polyline(PackedVector2Array([Vector2(x, W.GROUND_Y + 8), Vector2(x + 14, W.GROUND_Y + 22), Vector2(x + 6, W.GROUND_Y + 36), Vector2(x + 22, W.GROUND_Y + 52)]),
			Color(1.6 * a, 0.4 * a, 1.4 * a, 0.8), 1.5, true)
	Gfx.vgrad_rect(self, Rect2(0, W.GROUND_Y - 18, W.WIDTH, 18), Color(0.3, 0.7, 1.0, 0.0), Color(0.3, 0.7, 1.0, 0.12))
	draw_line(Vector2(0, W.GROUND_Y), Vector2(W.WIDTH, W.GROUND_Y), Color(0.5, 1.3, 2.0), 2.0)


func _draw_pad() -> void:
	var x := W.pad_x()
	var y := W.GROUND_Y
	draw_rect(Rect2(x - 58, y - 3, 116, 7), Color(0.26, 0.27, 0.33))
	draw_rect(Rect2(x - 58, y - 3, 116, 2), Color(0.45, 0.46, 0.55))
	for i in 7:
		var cx := x - 48 + i * 16
		draw_colored_polygon(PackedVector2Array([Vector2(cx, y + 1), Vector2(cx + 6, y + 1), Vector2(cx + 10, y + 4), Vector2(cx + 4, y + 4)]), Color(0.9, 0.7, 0.15, 0.8))
	for s in [-1.0, 1.0]:
		var bx: float = x + s * 62.0
		draw_line(Vector2(bx, y), Vector2(bx, y - 18), Color(0.4, 0.42, 0.5), 3.0)
		var blink := 0.5 + 0.5 * sin(t * 4.0 + s)
		draw_circle(Vector2(bx, y - 20), 3.0, Color(2.6 * blink + 0.3, 0.4, 0.3))


func _draw_platform(r: Rect2) -> void:
	Gfx.glow(self, Vector2(r.get_center().x, r.end.y + 6), r.size.x * 0.55, Color(0.2, 0.7, 1.0, 0.12))
	Gfx.vgrad_rect(self, r, Color(0.36, 0.38, 0.47), Color(0.12, 0.13, 0.18))
	var x := r.position.x + 24.0
	while x < r.end.x - 10.0:
		draw_line(Vector2(x, r.position.y + 4), Vector2(x, r.end.y - 2), Color(0.08, 0.08, 0.12, 0.7), 1.0)
		x += 32.0
	draw_rect(Rect2(r.position.x - 4, r.position.y - 1, 8, r.size.y + 2), Color(0.2, 0.21, 0.27))
	draw_rect(Rect2(r.end.x - 4, r.position.y - 1, 8, r.size.y + 2), Color(0.2, 0.21, 0.27))
	draw_line(Vector2(r.position.x, r.position.y), Vector2(r.end.x, r.position.y), Color(0.45, 1.8, 2.2), 2.0)
	var n := int(r.size.x / 28.0)
	for i in n:
		var lx := r.position.x + 14.0 + i * (r.size.x - 28.0) / maxf(1.0, float(n - 1))
		var a := 0.5 + 0.5 * sin(t * 3.0 - i * 0.7 + r.position.x)
		draw_circle(Vector2(lx, r.end.y - 4), 1.6, Color(1.8 * a + 0.2, 0.9 * a + 0.2, 0.3, 1.0))
