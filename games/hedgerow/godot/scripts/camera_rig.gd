class_name CameraRig
extends Node3D
## Orbit/pan/zoom tabletop camera. WASD/arrows pan, Q/E rotate, wheel zoom,
## middle-drag orbit, shift+middle-drag (or edge of screen) pan.

var camera: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(-50.0)
var dist := 15.0
var target := Vector3.ZERO
var _t_yaw := 0.0
var _t_pitch := deg_to_rad(-50.0)
var _t_dist := 15.0
var _t_target := Vector3.ZERO
var bounds := Rect2(0, 0, 40, 25)
var _orbit := false
var _pan := false
var _shake := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.near = 0.05
	camera.far = 300.0
	add_child(camera)
	camera.make_current()


func focus_on(p: Vector3, instant: bool = false) -> void:
	_t_target = Vector3(p.x, 0.0, p.z)
	if instant:
		target = _t_target


func add_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_t_dist = clampf(_t_dist * 0.9, 4.0, 42.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_t_dist = clampf(_t_dist * 1.1, 4.0, 42.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_orbit = mb.pressed and not mb.shift_pressed
			_pan = mb.pressed and mb.shift_pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _orbit:
			_t_yaw -= mm.relative.x * 0.006
			_t_pitch = clampf(_t_pitch - mm.relative.y * 0.004, deg_to_rad(-85.0), deg_to_rad(-18.0))
		elif _pan:
			var b := Basis(Vector3.UP, yaw)
			_t_target += b * Vector3(-mm.relative.x, 0, -mm.relative.y) * 0.0025 * _t_dist


func _process(delta: float) -> void:
	var real: float = delta / maxf(Engine.time_scale, 0.001)
	var mv := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		mv.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		mv.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		mv.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		mv.x += 1
	if mv != Vector3.ZERO:
		_t_target += Basis(Vector3.UP, yaw) * mv.normalized() * 0.9 * _t_dist * real
	if Input.is_key_pressed(KEY_Q):
		_t_yaw += 1.6 * real
	if Input.is_key_pressed(KEY_E):
		_t_yaw -= 1.6 * real
	_t_target.x = clampf(_t_target.x, bounds.position.x, bounds.end.x)
	_t_target.z = clampf(_t_target.z, bounds.position.y, bounds.end.y)
	var k: float = 1.0 - exp(-9.0 * real)
	yaw = lerp_angle(yaw, _t_yaw, k)
	pitch = lerpf(pitch, _t_pitch, k)
	dist = lerpf(dist, _t_dist, k)
	target = target.lerp(_t_target, k)
	global_position = target
	var off := Vector3(0, 0, dist).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var sh := Vector3.ZERO
	if _shake > 0.0:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
		_shake = maxf(0.0, _shake - real * 1.5)
	camera.position = off + sh
	camera.look_at(target + Vector3(0, 0.3, 0) + sh * 0.5, Vector3.UP)
