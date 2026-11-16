class_name Guardian
extends Node2D
## Cavern guardians. "g" crawls along a ledge, "f" drifts horizontally, "v" bobs vertically.

var kind := "g"
var level: Level
var dir := 1.0
var speed := 70.0
var t := 0.0
var color := Color(1, 0.4, 0.2)
var light: PointLight2D


func setup(k: String, lvl: Level) -> void:
	kind = k
	level = lvl
	t = randf() * 10.0
	match kind:
		"g":
			speed = 70.0
			color = Color(1.0, 0.45, 0.15)
		"f":
			speed = 115.0
			color = Color(1.0, 0.2, 0.55)
		"v":
			speed = 95.0
			color = Color(0.35, 1.0, 0.45)


func _ready() -> void:
	light = Fx.make_light(color, 0.9, 0.9)
	add_child(light)


func hit_rect() -> Rect2:
	return Rect2(position - Vector2(10, 10), Vector2(20, 20))


func _physics_process(delta: float) -> void:
	t += delta
	var T := Level.T
	match kind:
		"g", "f":
			var nx := position.x + dir * speed * delta
			var cx := int(floor((nx + dir * 12.0) / T))
			var cy := int(floor(position.y / T))
			var blocked := level.is_solid(cx, cy) or level.cell(cx, cy) == "^"
			if kind == "g" and not blocked:
				blocked = not level.is_solid(cx, cy + 1)
			if blocked:
				dir = -dir
			else:
				position.x = nx
		"v":
			var ny := position.y + dir * speed * delta
			var cy := int(floor((ny + dir * 13.0) / T))
			if level.is_solid(int(floor(position.x / T)), cy):
				dir = -dir
			else:
				position.y = ny
	queue_redraw()


func _draw() -> void:
	var outline := Color(0.03, 0.02, 0.05)
	var hot := Color(color.r * 3.5, color.g * 3.5, color.b * 3.5)
	match kind:
		"g":
			# armoured crawler with scuttling legs
			var s := 1.0 if dir > 0 else -1.0
			for i in 3:
				var lx := (-7 + i * 7) * 1.0
				var lift := sin(t * 14.0 + i * 2.0) * 2.0
				draw_line(Vector2(lx, 4), Vector2(lx - 3 * s, 11 + minf(lift, 0.0)), outline, 3.0)
			draw_circle(Vector2(0, 1), 11.0, outline)
			draw_circle(Vector2(0, 1), 9.5, Color(0.28, 0.2, 0.25))
			for i in 3:
				draw_arc(Vector2(0, 1), 9.5 - i * 3.0, PI, TAU, 12, Color(0.45, 0.32, 0.38), 1.5)
			draw_circle(Vector2(5 * s, 0), 3.0, hot)
		"f":
			# hover drone with spinning rotors
			var bob := sin(t * 3.0) * 3.0
			var spin := absf(sin(t * 40.0))
			draw_line(Vector2(-14 * spin, -10 + bob), Vector2(14 * spin, -10 + bob), Color(0.7, 0.75, 0.85, 0.8), 2.0)
			draw_line(Vector2(0, -10 + bob), Vector2(0, -5 + bob), outline, 3.0)
			draw_circle(Vector2(0, bob), 10.5, outline)
			draw_circle(Vector2(0, bob), 9.0, Color(0.22, 0.24, 0.32))
			draw_rect(Rect2(-7, -2 + bob, 14, 5), outline)
			var scan := sin(t * 2.5) * 4.0
			draw_circle(Vector2(scan, 0.5 + bob), 2.8, hot)
		"v":
			# spiked crystal mine
			var pts := PackedVector2Array()
			var spikes := 8
			for i in spikes * 2:
				var a := t * 1.6 + i * PI / spikes
				var r := 13.0 if i % 2 == 0 else 7.0
				pts.append(Vector2(cos(a), sin(a)) * r)
			draw_colored_polygon(pts, Color(0.18, 0.3, 0.22))
			pts.append(pts[0])
			draw_polyline(pts, outline, 2.0)
			var pulse := 0.75 + 0.25 * sin(t * 6.0)
			draw_circle(Vector2.ZERO, 5.0 * pulse, hot)
