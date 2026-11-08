extends Camera3D
## The orbit camera (docs/DESIGN.md § The camera). It orbits the player's ship, which never moves
## or turns in the scene, between 1.5 and 5 ship lengths away.
##
## Space-anchored (the default): the camera holds its direction in space. Each frame the space
## scene hands it the sim's roll and pitch angles, and it turns its own direction and up by the
## same rotation the sim gives the universe, so the ship swings under a steady camera. Follow:
## it eases back behind the active laser mount. The arrow keys and a right-drag orbit, `+`/`-`
## and the wheel zoom, Home puts it behind the active mount and `\` switches the mode. A new
## mount swings the camera behind it.

const MIN_ZOOM := 1.5
const MAX_ZOOM := 5.0
## The angle above the mount axis the camera sits at when placed behind a mount.
const BEHIND_TILT := deg_to_rad(16.0)
## The direction each mount fires along, in the ship's (Godot) frame: fore, aft, port, starboard.
const MOUNT_AXES := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]

@export var ship_length := 49.0
@export var zoom := 2.5
## Read by the HUD's camera hint.
var follow := false
## Orbit keys are read only while true (charts use the arrows for their cursor).
var keys_enabled := true
## The camera turns with the universe only in flight.
var anchored := false
var mount := 0
## Seconds since the last camera input, for the HUD's hint.
var idle := 99.0
## The farthest the camera may be this frame: the space scene pulls it in when the station or a
## ship comes between it and the player's ship (docs/DESIGN.md § The camera, Obstacles).
var limit := INF

var _dir := Vector3(0.6, 0.25, 0.75).normalized()
var _up := Vector3.UP
var _swing := 0.0
var _swing_dir := Vector3.ZERO
var _dragging := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="):
			var yaw := deg_to_rad(float(arg.trim_prefix("--yaw=")))
			_dir = Vector3(sin(yaw), _dir.y, cos(yaw)).normalized()
		elif arg.begins_with("--zoom="):
			zoom = clampf(float(arg.trim_prefix("--zoom=")), MIN_ZOOM, MAX_ZOOM)
	fov = 60.0
	near = 0.5
	far = 30000.0
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.0 / 1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.1)
	elif event is InputEventMouseMotion and _dragging:
		_orbit(-event.relative.x * 0.005, -event.relative.y * 0.005)
	elif keys_enabled and event.is_action_pressed("camera_reset"):
		behind_mount(mount, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera_mode"):
		follow = not follow
		idle = 0.0
		get_viewport().set_input_as_handled()


## Turns the camera with the universe: the sim's per-tick roll and pitch angles, for `seconds`
## of the tick (RULES B.7.2's rotation, applied to the camera's direction and up).
func turn_with_universe(roll_angle: float, pitch_angle: float, seconds: float) -> void:
	if not anchored:
		return
	var share := seconds * 12.0
	_dir = _turn(_dir, roll_angle * share, pitch_angle * share)
	_up = _turn(_up, roll_angle * share, pitch_angle * share)
	_tidy()


## Puts the camera behind a mount: at once, or swung over half a second.
func behind_mount(new_mount: int, now: bool = false) -> void:
	mount = new_mount
	var axis: Vector3 = MOUNT_AXES[clampi(new_mount, 0, 3)]
	var target := (-axis * cos(BEHIND_TILT) + Vector3.UP * sin(BEHIND_TILT)).normalized()
	idle = 0.0
	if now:
		_dir = target
		_up = Vector3.UP
		_swing = 0.0
	else:
		_swing_dir = target
		_swing = 0.5


## The camera placed for the title or the hangar: a fixed angle, not anchored.
func set_view(direction: Vector3, new_zoom: float) -> void:
	_dir = direction.normalized()
	_up = Vector3.UP
	zoom = clampf(new_zoom, MIN_ZOOM, MAX_ZOOM)
	_tidy()


func _process(delta: float) -> void:
	idle += delta
	if keys_enabled:
		var turn := Input.get_axis("camera_left", "camera_right")
		var tilt := Input.get_axis("camera_down", "camera_up")
		if turn != 0.0 or tilt != 0.0:
			_orbit(-turn * 1.6 * delta, tilt * 1.2 * delta)
		if Input.is_action_pressed("camera_zoom_in"):
			_zoom_by(1.0 - 1.2 * delta)
		elif Input.is_action_pressed("camera_zoom_out"):
			_zoom_by(1.0 + 1.2 * delta)
	if _swing > 0.0:
		var k := 1.0 - exp(-8.0 * delta)
		_dir = _dir.slerp(_swing_dir, k)
		_up = _up.slerp(Vector3.UP, k)
		_swing -= delta
		_tidy()
	elif follow and idle > 1.5:
		var axis: Vector3 = MOUNT_AXES[clampi(mount, 0, 3)]
		var target := (-axis * cos(BEHIND_TILT) + Vector3.UP * sin(BEHIND_TILT)).normalized()
		var k := 1.0 - exp(-2.0 * delta)
		_dir = _dir.slerp(target, k)
		_up = _up.slerp(Vector3.UP, k)
		_tidy()
	_place()


func _orbit(yaw: float, pitch: float) -> void:
	_dir = _dir.rotated(_up, yaw)
	var right := _up.cross(_dir).normalized()
	var tilted := _dir.rotated(right, -pitch)
	if absf(tilted.dot(_up)) < 0.97:
		_dir = tilted
	idle = 0.0
	_tidy()


func _zoom_by(factor: float) -> void:
	zoom = clampf(zoom * factor, MIN_ZOOM, MAX_ZOOM)
	idle = 0.0


## The sim's rotation of a vector by roll ρ and pitch φ (RULES B.7.2), in Godot axes.
func _turn(v: Vector3, roll: float, pitch: float) -> Vector3:
	var x := v.x
	var y := v.y
	var z := -v.z
	y -= roll * x
	x += roll * y
	y -= pitch * z
	z += pitch * y
	return Vector3(x, y, -z)


func _tidy() -> void:
	_dir = _dir.normalized()
	_up = (_up - _dir * _up.dot(_dir)).normalized()
	if _up.length_squared() < 0.5:
		_up = Vector3.UP


## The direction from the ship to the camera, in the ship's frame.
func direction() -> Vector3:
	return _dir


func _place() -> void:
	var distance := minf(zoom * ship_length, maxf(limit, ship_length * 0.6))
	position = _dir * distance
	look_at(Vector3.ZERO, _up)
