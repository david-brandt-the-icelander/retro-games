extends Camera3D
## The space-anchored orbit camera (docs/DESIGN.md § The camera): it holds its direction in
## space and orbits the player's ship, between 1.5 and 5 ship lengths away.

@export var ship_length := 59.0
@export var zoom := 2.5
@export var yaw := deg_to_rad(-38.0)
@export var pitch := deg_to_rad(14.0)

var _dragging := false


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--yaw="):
			yaw = deg_to_rad(float(arg.trim_prefix("--yaw=")))
		elif arg.begins_with("--pitch="):
			pitch = deg_to_rad(float(arg.trim_prefix("--pitch=")))
		elif arg.begins_with("--zoom="):
			zoom = clampf(float(arg.trim_prefix("--zoom=")), 1.5, 5.0)
	fov = 60.0
	near = 0.5
	far = 20000.0
	_place()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clampf(zoom / 1.1, 1.5, 5.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom * 1.1, 1.5, 5.0)
	elif event is InputEventMouseMotion and _dragging:
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch + event.relative.y * 0.005, deg_to_rad(-80.0), deg_to_rad(80.0))


func _process(delta: float) -> void:
	var turn := Input.get_axis("ui_left", "ui_right")
	var tilt := Input.get_axis("ui_down", "ui_up")
	yaw -= turn * 1.6 * delta
	pitch = clampf(pitch + tilt * 1.2 * delta, deg_to_rad(-80.0), deg_to_rad(80.0))
	_place()


func _place() -> void:
	var distance := zoom * ship_length
	var offset := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	position = offset + Vector3(0, -ship_length * 0.12, 0)
	look_at(Vector3(0, ship_length * 0.06, 0), Vector3.UP)
