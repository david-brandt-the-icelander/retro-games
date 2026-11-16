extends Node2D
## Collectables: rocket parts, fuel pods and bonus crystals.

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")

const PART := 0
const FUEL := 1
const GEM := 2

var kind := PART
var part_index := 1
var model := 0
var state := "fall"   # fall, rest, carried, drop, landed_rocket
var vel_y := 0.0
var t := 0.0
var carrier = null
var target_y := 0.0
var gem_color := Color(2, 2, 2)
var size := Vector2(40, 54)


func setup_part(idx: int, m: int) -> void:
	kind = PART
	part_index = idx
	model = m
	size = Vector2(40, 54)


func setup_fuel() -> void:
	kind = FUEL
	size = Vector2(26, 34)


func setup_gem(c: Color) -> void:
	kind = GEM
	gem_color = c
	size = Vector2(24, 24)


func _ready() -> void:
	z_index = 3


func rect() -> Rect2:
	return Rect2(position - size * 0.5, size)


func drop_target_y(rocket: Node2D) -> float:
	if kind == PART:
		return rocket.position.y - W.SEG_H * (part_index + 0.5)
	return rocket.position.y - W.SEG_H * 3.0 + 22.0


func start_drop(x: float, y: float) -> void:
	state = "drop"
	carrier = null
	position.x = x
	target_y = y
	vel_y = 60.0


func step(delta: float) -> void:
	t += delta
	match state:
		"fall":
			vel_y = minf(vel_y + 420.0 * delta, 260.0)
			position.y += vel_y * delta
			for r in W.solids():
				var rr := rect()
				if rr.intersects(r) and rr.end.y - vel_y * delta <= r.position.y + 1.0:
					position.y = r.position.y - size.y * 0.5
					vel_y = 0.0
					state = "rest"
					break
		"carried":
			if is_instance_valid(carrier):
				position = carrier.position + Vector2(carrier.facing * 6.0, 4.0)
		"drop":
			vel_y = minf(vel_y + 600.0 * delta, 420.0)
			position.y += vel_y * delta
			if position.y >= target_y:
				position.y = target_y
				state = "landed_rocket"
	queue_redraw()


func _draw() -> void:
	for o in W.edge_offsets(position.x):
		draw_set_transform(Vector2(o, 0), 0.0, Vector2.ONE)
		_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body() -> void:
	match kind:
		PART:
			if state == "rest":
				Gfx.glow(self, Vector2.ZERO, 50, Color(0.5, 0.8, 1.6, 0.22 + 0.1 * sin(t * 3.0)))
			Gfx.draw_segment(self, part_index, model, Vector2.ZERO, 0.0)
		FUEL:
			Gfx.glow(self, Vector2.ZERO, 34, Color(1.4, 0.4, 2.2, 0.35 + 0.15 * sin(t * 4.0)))
			var metal := Color(0.36, 0.38, 0.46)
			draw_rect(Rect2(-11, -6, 22, 12), metal)
			draw_circle(Vector2(0, -6), 11, metal)
			draw_circle(Vector2(0, 6), 11, metal.darkened(0.15))
			draw_rect(Rect2(-4, -20, 8, 4), Color(0.2, 0.2, 0.25))
			draw_rect(Rect2(-6, -11, 12, 22), Color(0.07, 0.04, 0.12))
			var lvl := 0.78 + 0.05 * sin(t * 5.0)
			draw_rect(Rect2(-6, -11 + 22 * (1.0 - lvl), 12, 22 * lvl), Color(1.5, 0.35, 2.3))
			for i in 3:
				var by := 9.0 - fmod(t * 14.0 + i * 7.0, 18.0)
				draw_circle(Vector2(-2.0 + i * 2.0, by), 1.2, Color(2.4, 1.6, 2.6, 0.8))
			draw_rect(Rect2(-11, -1, 22, 2), Color(0.95, 0.75, 0.2))
			draw_rect(Rect2(-9, -5, 2, 12), Color(1, 1, 1, 0.18))
		GEM:
			Gfx.glow(self, Vector2.ZERO, 32, Gfx.with_alpha(gem_color, 0.5))
			var sx := cos(t * 3.0)
			sx = signf(sx) * maxf(absf(sx), 0.2) if sx != 0.0 else 0.2
			var top := Vector2(0, -12)
			var bot := Vector2(0, 12)
			var l := Vector2(-10.0 * sx, -3)
			var r := Vector2(10.0 * sx, -3)
			var base := Color(gem_color.r * 0.45, gem_color.g * 0.45, gem_color.b * 0.45)
			draw_colored_polygon(PackedVector2Array([top, r, bot, l]), base)
			draw_colored_polygon(PackedVector2Array([top, r, Vector2(0, -3)]), Gfx.hdr(base, 1.8))
			draw_polyline(PackedVector2Array([l, top, r, bot, l, r]), gem_color, 1.5, true)
			if sin(t * 5.0) > 0.7:
				var s := Vector2(6, -9)
				draw_line(s - Vector2(4, 0), s + Vector2(4, 0), Color(3, 3, 3), 1.2)
				draw_line(s - Vector2(0, 4), s + Vector2(0, 4), Color(3, 3, 3), 1.2)
