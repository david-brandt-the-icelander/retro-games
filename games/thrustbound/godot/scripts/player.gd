extends Node2D
## The jetpack astronaut (original design). Physics are hand-rolled AABB against the platforms.

signal fired(pos: Vector2, dir: int)

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")

const HALF := Vector2(13, 22)
const GRAVITY := 620.0
const THRUST := 1350.0
const MAX_UP := -330.0
const MAX_DOWN := 430.0

var vel := Vector2.ZERO
var facing := 1
var on_floor := false
var thrusting := false
var alive := false
var carrying = null
var invuln := 0.0
var cooldown := 0.0
var anim_t := 0.0
var flame: CPUParticles2D


func _ready() -> void:
	z_index = 5
	flame = CPUParticles2D.new()
	flame.amount = 70
	flame.lifetime = 0.42
	flame.local_coords = false
	flame.texture = Gfx.soft()
	flame.direction = Vector2(0, 1)
	flame.spread = 14.0
	flame.initial_velocity_min = 170.0
	flame.initial_velocity_max = 260.0
	flame.gravity = Vector2(0, 80)
	flame.scale_amount_min = 0.07
	flame.scale_amount_max = 0.13
	flame.scale_amount_curve = Gfx.fade_curve()
	flame.color_ramp = Gfx.ramp([Color(3.0, 2.4, 1.5, 1), Color(2.4, 0.9, 0.25, 0.9), Color(0.8, 0.15, 0.35, 0.5), Color(0.2, 0.1, 0.3, 0)])
	flame.emitting = false
	add_child(flame)


func reset(pos: Vector2) -> void:
	position = pos
	vel = Vector2.ZERO
	facing = 1
	alive = true
	visible = true
	invuln = 2.0
	carrying = null
	thrusting = false
	flame.emitting = false


func rect() -> Rect2:
	return Rect2(position - HALF, HALF * 2.0)


func hit_rect() -> Rect2:
	return rect().grow(-3.0)


func step(delta: float) -> void:
	if not alive:
		return
	anim_t += delta
	invuln = maxf(0.0, invuln - delta)
	cooldown = maxf(0.0, cooldown - delta)

	var ix := Input.get_axis("left", "right")
	thrusting = Input.is_action_pressed("thrust")
	if ix > 0.2:
		facing = 1
	elif ix < -0.2:
		facing = -1

	var top_speed := 190.0 if (on_floor and not thrusting) else 270.0
	var accel := 1100.0 if on_floor else 600.0
	vel.x = move_toward(vel.x, ix * top_speed, accel * delta)
	vel.y += GRAVITY * delta
	if thrusting:
		vel.y -= THRUST * delta
	vel.y = clampf(vel.y, MAX_UP, MAX_DOWN)

	position.x += vel.x * delta
	for r in W.PLATFORMS:
		if rect().intersects(r):
			if vel.x > 0.0:
				position.x = r.position.x - HALF.x
			elif vel.x < 0.0:
				position.x = r.end.x + HALF.x
			vel.x = 0.0

	position.y += vel.y * delta
	on_floor = false
	for r in W.solids():
		if rect().intersects(r):
			if vel.y > 0.0:
				position.y = r.position.y - HALF.y
				on_floor = true
			else:
				position.y = r.end.y + HALF.y
			vel.y = 0.0

	if position.y - HALF.y < W.CEILING_Y:
		position.y = W.CEILING_Y + HALF.y
		vel.y = maxf(vel.y, 0.0)
	position.x = W.wrap_x(position.x)

	if Input.is_action_pressed("fire") and cooldown <= 0.0:
		cooldown = 0.16
		fired.emit(position + Vector2(facing * 26.0, -1.5), facing)

	flame.position = Vector2(-12.5 * facing, 14)
	flame.emitting = thrusting
	if invuln > 0.0:
		modulate.a = 0.35 if int(invuln * 12.0) % 2 == 0 else 1.0
	else:
		modulate.a = 1.0
	queue_redraw()


func _draw() -> void:
	for o in W.edge_offsets(position.x):
		draw_set_transform(Vector2(o, 0), 0.0, Vector2(facing, 1))
		_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body() -> void:
	var suit := Color(0.9, 0.92, 0.97)
	var suit_dark := Color(0.6, 0.64, 0.75)
	var metal := Color(0.32, 0.34, 0.4)
	var t := anim_t

	if thrusting:
		Gfx.glow(self, Vector2(-12, 20), 30, Color(2.4, 1.2, 0.4, 0.8))

	# jetpack
	draw_rect(Rect2(-20, -14, 11, 26), metal)
	draw_rect(Rect2(-19, -13, 3, 24), Color(0.48, 0.5, 0.58))
	draw_rect(Rect2(-18, 12, 9, 4), Color(0.16, 0.16, 0.2))
	var ind := Color(2.4, 1.0, 0.3) if thrusting else Color(0.9, 0.45, 0.2)
	draw_rect(Rect2(-15, -9, 2, 7), ind)

	# legs
	var l1 := Vector2(-3, 19)
	var l2 := Vector2(4, 19)
	if on_floor and absf(vel.x) > 15.0:
		var swing := sin(t * 16.0) * 5.0
		l1.x += swing
		l2.x -= swing
	elif not on_floor:
		l1 = Vector2(-8, 17)
		l2 = Vector2(0, 19)
	draw_line(Vector2(-3, 8), l1, suit_dark, 6.0)
	draw_rect(Rect2(l1.x - 3.5, l1.y - 1, 7, 4), Color(0.24, 0.26, 0.32))
	draw_line(Vector2(4, 8), l2, suit, 6.0)
	draw_rect(Rect2(l2.x - 3.5, l2.y - 1, 8, 4), Color(0.3, 0.32, 0.38))

	# torso
	draw_rect(Rect2(-10, -9, 20, 19), suit)
	draw_rect(Rect2(4, -9, 6, 19), suit_dark)
	draw_rect(Rect2(-4, -4, 7, 4), Color(0.3, 1.6, 2.2))
	draw_rect(Rect2(-10, 7, 20, 3), Color(0.28, 0.3, 0.36))

	# arm + blaster
	draw_line(Vector2(1, -3), Vector2(13, 0), suit, 5.0)
	draw_rect(Rect2(11, -4, 13, 5), Color(0.2, 0.21, 0.26))
	draw_rect(Rect2(12, -6, 5, 2), Color(0.42, 0.44, 0.52))
	var muzzle := Color(2.4, 0.6, 2.0) if cooldown > 0.08 else Color(0.8, 0.3, 0.7)
	draw_circle(Vector2(24.5, -1.5), 2.0, muzzle)

	# helmet
	draw_circle(Vector2(1, -18), 10.5, suit)
	draw_arc(Vector2(1, -18), 10.0, 0.1, PI - 0.1, 14, suit_dark, 2.0)
	draw_circle(Vector2(4.5, -18), 7.0, Color(0.05, 0.1, 0.22))
	draw_circle(Vector2(5.5, -18), 5.5, Color(0.12, 0.5, 1.1))
	draw_circle(Vector2(7.5, -20.5), 1.8, Color(1.8, 2.0, 2.2))
	# antenna beacon
	draw_line(Vector2(-6, -26), Vector2(-9, -33), suit_dark, 1.5)
	draw_circle(Vector2(-9, -33), 2.0, Gfx.hdr(Color(2.6, 0.5, 0.4), 0.6 + 0.4 * sin(t * 6.0)))
