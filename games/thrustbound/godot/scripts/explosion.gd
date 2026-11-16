extends Node2D
## One-shot explosion: flash, shock ring, embers and sparks.

const Gfx = preload("res://scripts/gfx.gd")

var t := 0.0
var color := Color(2, 1, 0.4)
var big := 1.0


func setup(pos: Vector2, c: Color, size: float = 1.0) -> void:
	position = pos
	color = c
	big = size


func _ready() -> void:
	z_index = 8
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = int(36 * big)
	p.lifetime = 0.9
	p.texture = Gfx.soft()
	p.spread = 180.0
	p.initial_velocity_min = 50.0 * big
	p.initial_velocity_max = 300.0 * big
	p.damping_min = 120.0
	p.damping_max = 260.0
	p.gravity = Vector2(0, 90)
	p.scale_amount_min = 0.1 * big
	p.scale_amount_max = 0.26 * big
	p.scale_amount_curve = Gfx.fade_curve()
	p.color_ramp = Gfx.ramp([Color(3.2, 2.8, 2.2, 1), Gfx.hdr(Gfx.with_alpha(color, 1.0), 1.4), Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0)])
	p.emitting = true
	add_child(p)

	var s := CPUParticles2D.new()
	s.one_shot = true
	s.explosiveness = 1.0
	s.amount = int(18 * big)
	s.lifetime = 0.7
	s.spread = 180.0
	s.initial_velocity_min = 160.0 * big
	s.initial_velocity_max = 420.0 * big
	s.damping_min = 200.0
	s.damping_max = 400.0
	s.gravity = Vector2(0, 300)
	s.scale_amount_min = 2.0
	s.scale_amount_max = 3.5
	s.color_ramp = Gfx.ramp([Color(3, 3, 2.5, 1), Gfx.with_alpha(color, 0.0)])
	s.emitting = true
	add_child(s)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()
	if t > 1.3:
		queue_free()


func _draw() -> void:
	var k := 1.0 - t / 0.22
	if k > 0.0:
		Gfx.glow(self, Vector2.ZERO, 60.0 * big * (1.3 - k * 0.3), Color(3.0, 2.6, 2.0, k))
	var ra := maxf(0.0, 1.0 - t * 2.6)
	if ra > 0.0:
		draw_arc(Vector2.ZERO, 8.0 + t * 240.0 * big, 0.0, TAU, 48, Color(color.r * 1.5, color.g * 1.5, color.b * 1.5, ra), 3.0 * ra + 0.5, true)
