class_name CameraRig
extends Node3D
## Orbiting tabletop camera. WASD / arrows pan, Q / E rotate, wheel zooms,
## middle-drag orbits, right-drag with Shift pans.

var focus := Vector3(24, 0, 24)
var yaw := deg_to_rad(35.0)
var pitch := deg_to_rad(52.0)
var dist := 38.0
var shake := 0.0
var bounds := 48.0

var cam := Camera3D.new()
var _focus_t := focus
var _yaw_t := yaw
var _dist_t := dist
var _pitch_t := pitch


func _ready() -> void:
	cam.fov = 50.0
	cam.far = 400.0
	add_child(cam)
	cam.make_current()


func look_at_point(p: Vector3, d := 30.0) -> void:
	_focus_t = p
	_dist_t = d


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist_t = maxf(9.0, _dist_t * 0.9)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist_t = minf(85.0, _dist_t * 1.1)
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_MIDDLE):
		_yaw_t -= e.relative.x * 0.006
		_pitch_t = clampf(_pitch_t + e.relative.y * 0.004, deg_to_rad(22), deg_to_rad(84))


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move.x += 1
	if Input.is_key_pressed(KEY_Q):
		_yaw_t += delta * 1.6
	if Input.is_key_pressed(KEY_E):
		_yaw_t -= delta * 1.6
	if move != Vector2.ZERO:
		var r := move.normalized().rotated(-_yaw_t) * delta * (8.0 + _dist_t * 0.6)
		_focus_t += Vector3(r.x, 0, r.y)
	_focus_t.x = clampf(_focus_t.x, -4, bounds + 4)
	_focus_t.z = clampf(_focus_t.z, -4, bounds + 4)
	var k := minf(1.0, delta * 8.0)
	focus = focus.lerp(_focus_t, k)
	yaw = lerp_angle(yaw, _yaw_t, k)
	dist = lerpf(dist, _dist_t, k)
	pitch = lerpf(pitch, _pitch_t, k)
	var off := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
	var jitter := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(0.0, shake - delta)
		jitter = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.5
	cam.global_position = focus + off + jitter
	cam.look_at(focus + jitter * 0.5, Vector3.UP)
