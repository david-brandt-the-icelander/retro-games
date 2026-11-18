class_name Buggy
extends CharacterBody2D
## The mining buggy: refills oxygen and jetpack fuel while you sit in it, carries the haul,
## and is the only way through the exit tunnel. Armoured: hazards and drones can't hurt it.

const HALF := Vector2(34, 16)
const SPEED := 270.0
const ACCEL := 700.0
const BRAKE := 1100.0
const GRAVITY := 1300.0

var level: Level
var occupied := false
var autopilot := 0.0     # >0 drives right on its own (used for the exit cut-scene)
var vx := 0.0
var facing := 1.0
var wheel_a := 0.0
var t := 0.0
var cargo: Array[Color] = []
var headlight: PointLight2D
var cab_light: PointLight2D


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := RectangleShape2D.new()
	shape.size = HALF * 2.0
	var cs := CollisionShape2D.new()
	cs.shape = shape
	add_child(cs)
	floor_snap_length = 8.0
	headlight = Fx.make_light(Color(1.0, 0.95, 0.8), 0.0, 2.2)
	add_child(headlight)
	cab_light = Fx.make_light(Color(0.4, 0.9, 1.0), 0.5, 0.8)
	cab_light.position = Vector2(6, -18)
	add_child(cab_light)


func rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)


func _physics_process(delta: float) -> void:
	t += delta
	var dir := 0.0
	if autopilot > 0.0:
		dir = autopilot
	elif occupied and level.player.alive and not level.player.frozen:
		dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		vx = move_toward(vx, dir * SPEED, ACCEL * delta)
		facing = signf(dir)
	else:
		vx = move_toward(vx, 0.0, BRAKE * delta)
	velocity.x = vx
	velocity.y = minf(velocity.y + GRAVITY * delta, 900.0)
	move_and_slide()
	if is_on_wall():
		vx = 0.0
	wheel_a += vx * delta / 9.0
	headlight.energy = 1.4 if occupied or autopilot > 0.0 else 0.25
	headlight.position = Vector2(44.0 * facing, -2)
	queue_redraw()


func _draw() -> void:
	var bob := sin(t * 18.0) * 0.8 if absf(vx) > 20.0 else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2(facing, 1))
	var ink := Color(0.03, 0.03, 0.06)
	var hull := Color(0.86, 0.84, 0.78)
	var hull_dark := Color(0.5, 0.5, 0.5)
	var accent := Color(1.0, 0.45, 0.12)
	# chassis
	var body := PackedVector2Array([Vector2(-34, -4), Vector2(-30, -12), Vector2(-2, -12), Vector2(6, -24),
			Vector2(24, -24), Vector2(34, -8), Vector2(34, 6), Vector2(-34, 6)])
	var outline := body.duplicate()
	outline.append(body[0])
	draw_colored_polygon(body, hull)
	draw_polyline(outline, ink, 2.5)
	draw_rect(Rect2(-34, 1, 68, 5), hull_dark)
	# hazard stripes
	for i in 5:
		var x := -30.0 + i * 6.0
		draw_colored_polygon(PackedVector2Array([Vector2(x, -4), Vector2(x + 3, -4), Vector2(x + 6, 0), Vector2(x + 3, 0)]), accent)
	# cab glass
	var glass := PackedVector2Array([Vector2(1, -12), Vector2(8, -21), Vector2(22, -21), Vector2(29, -9), Vector2(1, -9)])
	draw_colored_polygon(glass, Color(0.15, 0.45, 0.6))
	draw_line(Vector2(10, -19), Vector2(16, -13), Color(1.4, 2.0, 2.4, 0.7), 2.0)
	if occupied:
		draw_circle(Vector2(15, -14), 5.0, Color(0.9, 0.9, 0.94))
		draw_rect(Rect2(16, -17, 4, 5), Color(0.95, 0.68, 0.18))
	# cargo bed with the haul
	draw_rect(Rect2(-30, -12, 26, 2), ink)
	for i in mini(cargo.size(), 8):
		var c: Color = cargo[i]
		var px := -27.0 + (i % 4) * 6.0
		var py := -15.0 - (i / 4) * 4.0
		draw_circle(Vector2(px, py), 3.2, Color(c.r * 1.3, c.g * 1.3, c.b * 1.3))
	# antenna + beacon
	draw_line(Vector2(-26, -12), Vector2(-28, -32), ink, 2.0)
	var beacon := 3.0 if fmod(t, 1.0) < 0.5 else 0.4
	draw_circle(Vector2(-28, -33), 2.5, Color(beacon, 0.4 * beacon, 0.15 * beacon))
	# headlight
	draw_rect(Rect2(30, -6, 5, 5), Color(4, 3.6, 2.8) if occupied else Color(0.6, 0.6, 0.5))
	# wheels
	for wx in [-22.0, -6.0, 22.0]:
		var c := Vector2(wx, 8)
		draw_circle(c, 9.5, ink)
		draw_circle(c, 7.5, Color(0.22, 0.23, 0.27))
		draw_circle(c, 3.5, Color(0.6, 0.62, 0.68))
		for k in 3:
			var a := wheel_a + k * TAU / 3.0
			draw_line(c, c + Vector2(cos(a), sin(a)) * 7.0, ink, 1.5)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
