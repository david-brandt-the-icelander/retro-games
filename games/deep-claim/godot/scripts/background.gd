class_name Background
extends Node2D
## Procedural asteroid-interior backdrop: depth gradient, three parallax rock layers, work-light beams,
## distant ore glints and drifting dust.

var tint := Color(0.3, 0.5, 1.0)
var focus := Vector2(640, 320)
var layers: Array = []
var t := 0.0
var dust: CPUParticles2D


func _ready() -> void:
	z_index = -10
	dust = CPUParticles2D.new()
	dust.amount = 90
	dust.lifetime = 14.0
	dust.preprocess = 14.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(680, 340)
	dust.position = Vector2(640, 320)
	dust.direction = Vector2(0.3, -1)
	dust.spread = 60.0
	dust.initial_velocity_min = 3.0
	dust.initial_velocity_max = 12.0
	dust.gravity = Vector2(0, -2)
	dust.scale_amount_min = 1.0
	dust.scale_amount_max = 2.5
	dust.color = Color(1.3, 1.3, 1.4, 0.3)
	add_child(dust)
	set_theme(tint)


func set_theme(c: Color) -> void:
	tint = c
	_generate()
	queue_redraw()


func _generate() -> void:
	layers.clear()
	var noise := FastNoiseLite.new()
	noise.seed = randi()
	noise.frequency = 0.006
	for i in 3:
		var top := PackedVector2Array([Vector2(-120, -120)])
		var bot := PackedVector2Array([Vector2(-120, 800)])
		var x := -120.0
		while x <= 1400.0:
			var n := noise.get_noise_2d(x, i * 400.0)
			var drip := 0.0
			if fposmod(x * 0.37 + i * 13.0, 9.0) < 1.2:
				drip = 40.0 + absf(n) * 90.0
			top.append(Vector2(x, 40.0 + i * 30.0 + n * 70.0 + drip))
			var n2 := noise.get_noise_2d(x, 900.0 + i * 400.0)
			bot.append(Vector2(x, 600.0 - i * 40.0 + n2 * 80.0))
			x += 24.0
		top.append(Vector2(1400, -120))
		bot.append(Vector2(1400, 800))
		var shade := Color(0.05, 0.05, 0.08).lerp(tint, 0.06 + i * 0.05).darkened(0.1 * (2 - i))
		layers.append({"top": top, "bot": bot, "color": shade, "factor": 0.015 + i * 0.03})


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	var deep := Color(0.015, 0.015, 0.03)
	var low := Color(tint.r * 0.1, tint.g * 0.1, tint.b * 0.12)
	draw_polygon(PackedVector2Array([Vector2(-200, -200), Vector2(1500, -200), Vector2(1500, 900), Vector2(-200, 900)]),
			PackedColorArray([deep, deep, low, low]))
	# distant glow
	for i in 6:
		draw_circle(Vector2(900 - (focus.x - 640) * 0.01, 260), 380.0 - i * 55.0, Color(tint.r, tint.g, tint.b, 0.025))
	# light shafts from cracks in the ceiling
	for i in 4:
		var sx := 180.0 + i * 310.0 + sin(t * 0.2 + i) * 20.0
		var a := 0.035 + 0.02 * sin(t * 0.7 + i * 2.0)
		var col := Color(tint.r * 1.2, tint.g * 1.2, tint.b * 1.2, a)
		draw_colored_polygon(PackedVector2Array([Vector2(sx, 0), Vector2(sx + 40, 0), Vector2(sx + 180, 640), Vector2(sx + 30, 640)]), col)
	# distant mineral glints embedded in the far wall
	for i in 40:
		var gx := fposmod(i * 197.3, 1280.0) + (640.0 - focus.x) * 0.01
		var gy := 120.0 + fposmod(i * 83.7, 420.0)
		var tw := 0.5 + 0.5 * sin(t * (0.6 + fposmod(i * 0.37, 1.0)) + i)
		draw_circle(Vector2(gx, gy), 1.2 + tw, Color(tint.r * 1.4, tint.g * 1.4, tint.b * 1.4, 0.25 * tw))
	for l in layers:
		var f: float = l["factor"]
		var off := Vector2((640.0 - focus.x) * f, (320.0 - focus.y) * f * 0.5)
		draw_set_transform(off, 0.0, Vector2.ONE)
		draw_colored_polygon(l["top"], l["color"])
		draw_colored_polygon(l["bot"], l["color"])
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
