extends Node2D
## Enemies, one kind per level layout: 0 = ember meteor (burns up on platforms), 1 = jelly bouncer,
## 2 = wobbling saucer, 3 = homing spike orb, 4 = drift mine (slow, bobbing), 5 = dart comet (fast, flat),
## 6 = zigzag wasp, 7 = phase ghost (drifts through platforms towards you), 8 = dive hawk (patrols
## high, then stoops on you), 9 = ricochet shard (fast diagonal bouncer), 10 = hunter drone (lunges).

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")

var kind := 0
var vel := Vector2.ZERO
var radius := 16.0
var max_speed := 150.0
var t := 0.0
var phase := 0.0
var dead := false
var hit_solid := false
var mode := 0
var rock_pts := PackedVector2Array()
var trail: CPUParticles2D


func setup(k: int, pos: Vector2, dir: int, level: int, rng: RandomNumberGenerator) -> void:
	kind = k
	position = pos
	phase = rng.randf() * TAU
	var sk := 1.0 + minf(0.06 * float(level - 1), 0.8)
	match kind:
		0:
			radius = 15.0
			vel = Vector2(dir * rng.randf_range(110, 170), rng.randf_range(25, 90)) * sk
		1:
			radius = 17.0
			vel = Vector2(dir * rng.randf_range(100, 150), rng.randf_range(60, 130) * (1 if rng.randf() < 0.5 else -1)) * sk
		2:
			radius = 18.0
			vel = Vector2(dir * rng.randf_range(120, 170) * sk, 0)
		3:
			radius = 15.0
			max_speed = 135.0 * sk
			vel = Vector2(dir * 90.0, 0)
		4:
			radius = 21.0
			vel = Vector2(dir * rng.randf_range(55, 90) * sk, 0)
		5:
			radius = 13.0
			vel = Vector2(dir * minf(280.0 * sk, 460.0), 0)
		6:
			radius = 14.0
			vel = Vector2(dir * rng.randf_range(100, 140) * sk, 0)
		7:
			radius = 17.0
			max_speed = 78.0 * sk
			vel = Vector2(dir * 40.0, 0)
		8:
			radius = 16.0
			vel = Vector2(dir * rng.randf_range(100, 130) * sk, 0)
		9:
			radius = 13.0
			var sp := minf(210.0 * sk, 340.0)
			vel = Vector2(dir * sp, sp * (1 if rng.randf() < 0.5 else -1))
		10:
			radius = 15.0
			max_speed = minf(330.0 * sk, 480.0)
			vel = Vector2(dir * 60.0, 0)
	for i in 9:
		var a := TAU * float(i) / 9.0
		rock_pts.append(Vector2(cos(a), sin(a)) * radius * rng.randf_range(0.78, 1.08))


func _ready() -> void:
	z_index = 4
	if kind == 0 or kind == 3:
		trail = CPUParticles2D.new()
		trail.amount = 36
		trail.lifetime = 0.5
		trail.local_coords = false
		trail.texture = Gfx.soft()
		trail.spread = 25.0
		trail.initial_velocity_min = 10.0
		trail.initial_velocity_max = 40.0
		trail.gravity = Vector2.ZERO
		trail.scale_amount_min = 0.12
		trail.scale_amount_max = 0.22
		trail.scale_amount_curve = Gfx.fade_curve()
		if kind == 0:
			trail.color_ramp = Gfx.ramp([Color(3.0, 1.8, 0.8, 1), Color(2.0, 0.5, 0.15, 0.6), Color(0.3, 0.1, 0.1, 0)])
		else:
			trail.color_ramp = Gfx.ramp([Color(2.4, 0.5, 2.2, 0.8), Color(0.8, 0.1, 0.9, 0.4), Color(0.2, 0.0, 0.3, 0)])
			trail.scale_amount_max = 0.14
		trail.emitting = true
		add_child(trail)


func rect() -> Rect2:
	return Rect2(position - Vector2(radius, radius) * 0.85, Vector2(radius, radius) * 1.7)


func step(delta: float, target: Vector2) -> void:
	t += delta
	hit_solid = false
	match kind:
		0:
			position += vel * delta
			if W.hits_solid(rect()):
				hit_solid = true
		1:
			_move_bounce(delta)
		2:
			vel.y = sin(t * 2.4 + phase) * 85.0
			_move_bounce(delta)
		3:
			var dx := W.wrap_dx(position.x, target.x)
			var desired := Vector2(dx, target.y - position.y).normalized() * max_speed
			vel = vel.lerp(desired, clampf(1.3 * delta, 0.0, 1.0))
			_move_bounce(delta)
		4:
			vel.y = sin(t * 1.6 + phase) * 60.0
			_move_bounce(delta)
		5:
			_move_bounce(delta)
		6:
			vel.y = cos(t * 6.0 + phase) * 170.0
			_move_bounce(delta)
		7:
			var dx7 := W.wrap_dx(position.x, target.x)
			vel = vel.lerp(Vector2(dx7, target.y - position.y).normalized() * max_speed, clampf(1.0 * delta, 0.0, 1.0))
			position += vel * delta
		8:
			_step_hawk(delta, target)
		9:
			_move_bounce(delta)
		10:
			var dx10 := W.wrap_dx(position.x, target.x)
			var lunging := fmod(t + phase, 2.2) < 0.7
			var want := Vector2(dx10, target.y - position.y).normalized() * max_speed if lunging else Vector2.ZERO
			vel = vel.lerp(want, clampf(6.0 * delta, 0.0, 1.0))
			_move_bounce(delta)
	if position.y < W.CEILING_Y + radius:
		position.y = W.CEILING_Y + radius
		vel.y = absf(vel.y)
	position.x = W.wrap_x(position.x)
	if trail:
		trail.direction = -vel.normalized() if vel.length() > 1.0 else Vector2.UP
	queue_redraw()


func _step_hawk(delta: float, target: Vector2) -> void:
	if mode == 0:
		vel.y = clampf((110.0 - position.y) * 2.0, -150.0, 150.0)
		if absf(W.wrap_dx(position.x, target.x)) < 40.0 and position.y < 220.0:
			mode = 1
			vel = Vector2(0.0, 430.0)
	elif mode == 1:
		if vel.y < 0.0:
			mode = 2
	else:
		vel = Vector2(signf(vel.x) * 110.0 if vel.x != 0.0 else 110.0, -170.0)
		if position.y < 130.0:
			mode = 0
	_move_bounce(delta)


func _move_bounce(delta: float) -> void:
	var ox := position.x
	position.x += vel.x * delta
	if W.hits_solid(rect()):
		position.x = ox
		vel.x = -vel.x
	var oy := position.y
	position.y += vel.y * delta
	if W.hits_solid(rect()):
		position.y = oy
		vel.y = -vel.y


func _draw() -> void:
	for o in W.edge_offsets(position.x):
		draw_set_transform(Vector2(o, 0), 0.0, Vector2.ONE)
		_draw_body()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_body() -> void:
	var look := vel.normalized() * 2.0 if vel.length() > 1.0 else Vector2.ZERO
	match kind:
		0:
			Gfx.glow(self, Vector2.ZERO, radius * 3.0, Color(2.0, 0.7, 0.2, 0.55))
			var rot := Transform2D(t * 2.2, Vector2.ZERO)
			var pts := rot * rock_pts
			draw_colored_polygon(pts, Color(0.35, 0.2, 0.16))
			var inner := PackedVector2Array()
			for p in pts:
				inner.append(p * 0.62 + Vector2(-2, -2))
			draw_colored_polygon(inner, Color(0.58, 0.36, 0.26))
			draw_circle(rot * Vector2(4, 3), 3.0, Color(2.8, 1.3, 0.35))
			draw_circle(rot * Vector2(-5, 5), 1.8, Color(2.8, 1.0, 0.3))
		1:
			var sq := 1.0 + sin(t * 9.0 + phase) * 0.12
			Gfx.glow(self, Vector2.ZERO, radius * 2.6, Color(0.3, 1.6, 0.6, 0.45))
			for i in 4:
				var x := -9.0 + i * 6.0
				var wob := sin(t * 10.0 + i) * 3.0
				draw_line(Vector2(x, radius * 0.6), Vector2(x + wob, radius + 7.0), Color(0.3, 1.2, 0.55, 0.9), 2.5)
			var body := Gfx.ellipse(Vector2.ZERO, radius * sq, radius / sq, 24)
			draw_colored_polygon(body, Color(0.18, 0.7, 0.38))
			draw_colored_polygon(Gfx.ellipse(Vector2(-3, -5), radius * 0.55 * sq, radius * 0.38 / sq, 16), Color(0.42, 0.98, 0.58))
			draw_polyline(Gfx.closed(body), Color(0.6, 2.2, 1.0), 2.0, true)
			for ex in [-6.0, 6.0]:
				draw_circle(Vector2(ex, -2), 4.5, Color(0.97, 1.0, 0.97))
				draw_circle(Vector2(ex, -2) + look, 2.2, Color(0.04, 0.05, 0.1))
		2:
			Gfx.glow(self, Vector2(0, 6), radius * 2.4, Color(0.3, 1.0, 2.0, 0.45))
			draw_colored_polygon(Gfx.ellipse(Vector2(0, -5), 10, 9, 20), Color(0.25, 0.7, 1.2, 0.95))
			draw_circle(Vector2(-3, -9), 2.4, Color(1.6, 2.0, 2.2))
			draw_colored_polygon(Gfx.ellipse(Vector2(0, 2), radius + 6.0, 7, 28), Color(0.62, 0.66, 0.76))
			draw_colored_polygon(Gfx.ellipse(Vector2(0, -0.5), radius + 2.0, 3.5, 24), Color(0.85, 0.88, 0.95))
			draw_colored_polygon(Gfx.ellipse(Vector2(0, 6), radius - 3.0, 4, 20), Color(0.28, 0.3, 0.38))
			var cols := [Color(2.6, 0.5, 0.5), Color(2.6, 2.2, 0.4), Color(0.5, 2.6, 0.8), Color(0.5, 1.2, 2.8)]
			for i in 8:
				var a := t * 4.0 + i * TAU / 8.0
				if sin(a) > -0.15:
					draw_circle(Vector2(cos(a) * (radius + 2.0), 3.0 + sin(a) * 2.0), 2.0, cols[i % 4])
		3:
			Gfx.glow(self, Vector2.ZERO, radius * 3.0, Color(1.8, 0.3, 1.6, 0.6))
			var star := PackedVector2Array()
			for i in 16:
				var a := t * 3.0 + TAU * float(i) / 16.0
				var rr := radius * (1.2 if i % 2 == 0 else 0.62)
				star.append(Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(star, Color(0.5, 0.08, 0.48))
			draw_polyline(Gfx.closed(star), Color(1.8, 0.4, 1.7), 1.5, true)
			draw_circle(Vector2.ZERO, radius * 0.55, Color(0.85, 0.2, 0.75))
			draw_circle(look * 1.5, 4.2, Color(2.6, 2.3, 0.5))
			draw_circle(look * 2.2, 1.8, Color(0.1, 0.0, 0.1))
		4:
			Gfx.glow(self, Vector2.ZERO, radius * 2.6, Color(2.0, 0.3, 0.3, 0.4))
			for i in 10:
				var a := TAU * float(i) / 10.0 + t * 0.6
				draw_line(Vector2(cos(a), sin(a)) * radius * 0.8, Vector2(cos(a), sin(a)) * (radius + 7.0), Color(0.7, 0.72, 0.8), 3.0)
			draw_circle(Vector2.ZERO, radius * 0.85, Color(0.22, 0.22, 0.28))
			draw_circle(Vector2(-4, -4), radius * 0.35, Color(0.4, 0.42, 0.5))
			var blink := 0.5 + 0.5 * sin(t * 6.0 + phase)
			draw_circle(Vector2.ZERO, 5.0, Color(2.8 * blink + 0.4, 0.2, 0.2))
		5:
			var back := -vel.normalized() if vel.length() > 1.0 else Vector2.LEFT
			Gfx.glow(self, Vector2.ZERO, radius * 3.0, Color(2.0, 1.8, 0.4, 0.5))
			for i in 4:
				draw_line(back * (radius + i * 9.0), back * (radius + 9.0 + i * 9.0), Color(2.4, 1.6 - i * 0.3, 0.3, 0.8 - i * 0.18), 7.0 - i * 1.5)
			draw_circle(Vector2.ZERO, radius * 0.9, Color(2.6, 2.4, 1.2))
			draw_circle(-back * 3.0, radius * 0.45, Color(3.0, 3.0, 2.6))
		6:
			var flap := sin(t * 40.0) * 0.5
			Gfx.glow(self, Vector2.ZERO, radius * 2.4, Color(2.0, 1.3, 0.2, 0.4))
			for sgn in [-1.0, 1.0]:
				draw_colored_polygon(Gfx.ellipse(Vector2(sgn * 8.0, -10.0 - flap * 3.0), 10.0, 4.0 + flap * 2.0, 12), Color(0.8, 0.95, 1.0, 0.55))
			draw_colored_polygon(Gfx.ellipse(Vector2.ZERO, radius * 0.85, radius * 0.62, 16), Color(0.95, 0.75, 0.1))
			for bx in [-5.0, 1.0, 7.0]:
				draw_line(Vector2(bx, -7), Vector2(bx, 7), Color(0.1, 0.07, 0.04), 3.0)
			draw_line(Vector2(0, radius * 0.5), Vector2(0, radius + 5.0), Color(2.6, 0.5, 0.2), 2.5)
			draw_circle(Vector2(-radius * 0.7, -2) + look, 2.5, Color(0.1, 0.0, 0.0))
		7:
			var a7 := 0.55 + 0.25 * sin(t * 3.0 + phase)
			Gfx.glow(self, Vector2.ZERO, radius * 2.8, Color(0.8, 1.6, 2.0, 0.3))
			var body7 := PackedVector2Array()
			for i in 15:
				var a := PI + PI * float(i) / 14.0
				body7.append(Vector2(cos(a), sin(a)) * radius)
			for i in 5:
				var fx := radius - float(i) * radius * 0.5
				body7.append(Vector2(fx, radius * (0.9 if i % 2 == 0 else 0.55) + sin(t * 5.0 + i) * 2.0))
			draw_colored_polygon(body7, Color(0.75, 0.95, 1.1, a7))
			for ex in [-6.0, 6.0]:
				draw_circle(Vector2(ex, -3) + look, 3.2, Color(0.05, 0.1, 0.2))
		8:
			var wing := sin(t * 7.0 + phase) * 7.0
			Gfx.glow(self, Vector2.ZERO, radius * 2.6, Color(0.2, 2.0, 1.4, 0.38))
			var dirx := 1.0 if vel.x >= 0.0 else -1.0
			draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(-24, -10 + wing), Vector2(-8, 6)]), Color(0.1, 0.55, 0.45))
			draw_colored_polygon(PackedVector2Array([Vector2(0, -3), Vector2(24, -10 + wing), Vector2(8, 6)]), Color(0.1, 0.55, 0.45))
			draw_colored_polygon(Gfx.ellipse(Vector2.ZERO, 9, 13, 14), Color(0.2, 0.85, 0.65))
			draw_colored_polygon(PackedVector2Array([Vector2(dirx * 5, -9), Vector2(dirx * 15, -4), Vector2(dirx * 5, -3)]), Color(2.6, 2.0, 0.4))
			draw_circle(Vector2(dirx * 3, -6), 2.2, Color(0.05, 0.05, 0.1))
		9:
			Gfx.glow(self, Vector2.ZERO, radius * 2.8, Color(0.5, 1.4, 2.4, 0.45))
			var rot9 := Transform2D(t * 5.0, Vector2.ZERO)
			var shard := PackedVector2Array([Vector2(0, -radius * 1.35), Vector2(radius * 0.7, 0), Vector2(0, radius * 1.35), Vector2(-radius * 0.7, 0)])
			draw_colored_polygon(rot9 * shard, Color(0.55, 0.85, 1.2, 0.95))
			draw_polyline(Gfx.closed(rot9 * shard), Color(1.2, 2.2, 3.0), 2.0, true)
			draw_line(rot9 * Vector2(0, -radius), rot9 * Vector2(0, radius), Color(1.8, 2.6, 3.0, 0.8), 1.5)
		10:
			var spin := t * 9.0
			Gfx.glow(self, Vector2.ZERO, radius * 3.0, Color(2.2, 0.3, 0.8, 0.45))
			for i in 4:
				var a := spin + TAU * float(i) / 4.0
				var arm := Vector2(cos(a), sin(a)) * (radius + 2.0)
				draw_line(Vector2.ZERO, arm, Color(0.35, 0.08, 0.2), 4.0)
				draw_circle(arm, 4.5, Color(0.9, 0.2, 0.4))
			draw_circle(Vector2.ZERO, radius * 0.6, Color(0.25, 0.05, 0.15))
			draw_circle(look * 1.4, 5.0, Color(2.8, 0.5, 1.0))
			draw_circle(look * 1.8, 2.0, Color(1.0, 1.0, 1.0))
