extends Node2D
## The rocket on its launch pad. position = bottom of the engine segment.

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")

var segments := 1
var fuel := 0
var model := 0
var t := 0.0
var thrusting := false
var flame: CPUParticles2D
var smoke: CPUParticles2D


func _ready() -> void:
	z_index = 2
	position = Vector2(W.PAD_X, W.ROCKET_BASE_Y)

	smoke = CPUParticles2D.new()
	smoke.amount = 70
	smoke.lifetime = 1.8
	smoke.local_coords = false
	smoke.texture = Gfx.soft()
	smoke.position = Vector2(0, 8)
	smoke.direction = Vector2(0, 1)
	smoke.spread = 75.0
	smoke.initial_velocity_min = 60.0
	smoke.initial_velocity_max = 190.0
	smoke.damping_min = 40.0
	smoke.damping_max = 90.0
	smoke.gravity = Vector2(0, -25)
	smoke.scale_amount_min = 0.35
	smoke.scale_amount_max = 0.7
	smoke.color_ramp = Gfx.ramp([Color(1.2, 0.8, 0.6, 0.5), Color(0.45, 0.4, 0.5, 0.35), Color(0.2, 0.2, 0.28, 0)])
	smoke.emitting = false
	add_child(smoke)

	flame = CPUParticles2D.new()
	flame.amount = 140
	flame.lifetime = 0.5
	flame.local_coords = false
	flame.texture = Gfx.soft()
	flame.position = Vector2(0, 8)
	flame.direction = Vector2(0, 1)
	flame.spread = 10.0
	flame.initial_velocity_min = 320.0
	flame.initial_velocity_max = 440.0
	flame.scale_amount_min = 0.12
	flame.scale_amount_max = 0.24
	flame.scale_amount_curve = Gfx.fade_curve()
	flame.color_ramp = Gfx.ramp([Color(3.2, 2.8, 2.0, 1), Color(3.0, 1.2, 0.3, 0.9), Color(1.2, 0.2, 0.3, 0.5), Color(0.2, 0.1, 0.2, 0)])
	flame.emitting = false
	add_child(flame)


func reset(m: int, segs: int = 1) -> void:
	model = m % 4
	segments = segs
	fuel = 0
	position = Vector2(W.PAD_X, W.ROCKET_BASE_Y)
	set_flame(false)


func set_flame(on: bool) -> void:
	thrusting = on
	flame.emitting = on
	smoke.emitting = on


func top_y() -> float:
	return position.y - W.SEG_H * segments


func rect() -> Rect2:
	return Rect2(position.x - 22.0, top_y(), 44.0, W.SEG_H * segments)


func is_ready() -> bool:
	return segments >= 3 and fuel >= W.FUEL_NEEDED


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _draw() -> void:
	if thrusting:
		Gfx.glow(self, Vector2(0, 16), 110, Color(2.6, 1.3, 0.5, 0.9))
	var fill_total := float(fuel) / float(W.FUEL_NEEDED) * 3.0
	for i in segments:
		Gfx.draw_segment(self, i, model, Vector2(0, -W.SEG_H * (i + 0.5)), clampf(fill_total - i, 0.0, 1.0))
	var on_pad := absf(position.y - W.ROCKET_BASE_Y) < 1.0
	if on_pad and segments < 3:
		for i in range(segments, 3):
			var rr := Rect2(-20, -W.SEG_H * (i + 1), 40, W.SEG_H)
			draw_rect(rr, Color(0.5, 0.85, 1.6, 0.16 + 0.08 * sin(t * 3.0 + i)), false, 1.5)
	if is_ready() and not thrusting:
		Gfx.glow(self, Vector2(0, -W.SEG_H * 3.0 - 8.0), 34, Color(0.5, 2.6, 1.0, 0.45 + 0.4 * sin(t * 8.0)))
