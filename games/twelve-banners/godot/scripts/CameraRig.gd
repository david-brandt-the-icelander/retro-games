class_name CameraRig
extends Node3D
## Strategy camera: WASD / arrows / screen-edge / middle-drag to pan,
## wheel to zoom (tilts as it zooms), Q/E to rotate.

var camera: Camera3D
var bounds := Rect2(0, 0, 50, 50)
var zoom := 0.45            ## 0 = close, 1 = far
var target_zoom := 0.45
var yaw := 0.0
var target_yaw := 0.0
var focus := Vector3.ZERO
var target_focus := Vector3.ZERO
var edge_pan := true
var _dragging := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 42.0
	camera.far = 400.0
	add_child(camera)
	_apply()

func look_at_tile(c: Vector2i, instant := false) -> void:
	target_focus = Hex.to_world(c)
	if instant:
		focus = target_focus
		_apply()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clampf(target_zoom - 0.07, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clampf(target_zoom + 0.07, 0.0, 1.0)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var dist := _distance()
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		target_focus -= (right * event.relative.x + fwd * event.relative.y) * dist * 0.0016
	elif event is InputEventMagnifyGesture:
		target_zoom = clampf(target_zoom / event.factor, 0.0, 1.0)
	elif event is InputEventPanGesture:
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		target_focus += (right * event.delta.x + fwd * event.delta.y) * _distance() * 0.02

func _distance() -> float:
	return lerpf(5.0, 34.0, zoom * zoom)

func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if not _text_focus():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): move.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): move.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): move.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): move.x += 1
		if Input.is_key_pressed(KEY_Q): target_yaw += delta * 1.6
		if Input.is_key_pressed(KEY_E): target_yaw -= delta * 1.6
	if edge_pan and DisplayServer.window_is_focused():
		var mp := get_viewport().get_mouse_position()
		var vs := get_viewport().get_visible_rect().size
		if mp.x >= 0 and mp.y >= 0 and mp.x <= vs.x and mp.y <= vs.y:
			if mp.x < 6: move.x -= 1
			if mp.x > vs.x - 6: move.x += 1
			if mp.y < 6: move.y -= 1
			if mp.y > vs.y - 6: move.y += 1
	if move != Vector2.ZERO:
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		target_focus += (right * move.x + fwd * move.y).normalized() * delta * (6.0 + _distance() * 0.9)
	target_focus.x = clampf(target_focus.x, bounds.position.x, bounds.end.x)
	target_focus.z = clampf(target_focus.z, bounds.position.y, bounds.end.y)
	var k := 1.0 - exp(-delta * 10.0)
	focus = focus.lerp(target_focus, k)
	zoom = lerpf(zoom, target_zoom, k)
	yaw = lerp_angle(yaw, target_yaw, k)
	_apply()

func _text_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit

func _apply() -> void:
	if camera == null:
		return
	var dist := _distance()
	var pitch := deg_to_rad(lerpf(38.0, 62.0, zoom))
	var offset := Vector3(0, sin(pitch) * dist, cos(pitch) * dist)
	offset = offset.rotated(Vector3.UP, yaw)
	camera.position = focus + offset
	camera.look_at(focus + Vector3(0, 0.0, 0), Vector3.UP)

## Ray-cast the mouse onto the map (approximate ground plane at y=0.12).
func mouse_tile(mp: Vector2) -> Vector2i:
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	if absf(dir.y) < 0.0001:
		return Vector2i(-1, -1)
	var t := (0.12 - from.y) / dir.y
	if t < 0:
		return Vector2i(-1, -1)
	return Hex.from_world(from + dir * t)
