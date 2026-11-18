extends Node3D
## Smooth RTS camera: arrow keys / screen-edge pan, wheel zoom, Q/E or middle-drag to rotate.

const MIN_DIST := 16.0
const MAX_DIST := 105.0
const EDGE := 6.0

var cam: Camera3D
var target_pos := Vector3.ZERO
var yaw := deg_to_rad(-45.0)
var target_yaw := deg_to_rad(-45.0)
var zoom := 0.3
var target_zoom := 0.3
var ground_y := 0.0
var rotating := false
var edge_scroll := true
## Edge-scrolling only while the pointer is over the game: in a browser the last mouse position stays put when
## the pointer leaves the canvas (or was never on it), which would otherwise scroll the map forever.
var mouse_inside := false


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.5
	cam.far = 900.0
	add_child(cam)
	cam.current = true
	_update_camera()


func focus(p: Vector3, instant: bool = false) -> void:
	target_pos = Vector3(p.x, 0.0, p.z)
	if instant:
		position = target_pos
		ground_y = Game.world.height_at(p.x, p.z)
		position.y = ground_y
		_update_camera()


func _process(delta: float) -> void:
	var move := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		move.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT):
		move.x += 1.0
	if Input.is_key_pressed(KEY_UP):
		move.y += 1.0
	if Input.is_key_pressed(KEY_DOWN):
		move.y -= 1.0
	if edge_scroll and mouse_inside and DisplayServer.window_is_focused():
		var vp := get_viewport()
		var mp := vp.get_mouse_position()
		var sz := vp.get_visible_rect().size
		if Rect2(Vector2.ZERO, sz).has_point(mp):
			if mp.x < EDGE:
				move.x -= 1.0
			elif mp.x > sz.x - EDGE:
				move.x += 1.0
			if mp.y < EDGE:
				move.y += 1.0
			elif mp.y > sz.y - EDGE:
				move.y -= 1.0
	var spd := lerpf(28.0, 120.0, zoom)
	var fwd := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	target_pos += (right * move.x + fwd * move.y) * spd * delta
	var lim := Game.MAP_HALF + 10.0
	target_pos.x = clampf(target_pos.x, -lim, lim)
	target_pos.z = clampf(target_pos.z, -lim, lim)
	if Input.is_key_pressed(KEY_Q):
		target_yaw += 1.6 * delta
	if Input.is_key_pressed(KEY_E):
		target_yaw -= 1.6 * delta
	var k := 1.0 - exp(-10.0 * delta)
	position.x = lerpf(position.x, target_pos.x, k)
	position.z = lerpf(position.z, target_pos.z, k)
	ground_y = lerpf(ground_y, Game.world.height_at(position.x, position.z), 1.0 - exp(-4.0 * delta))
	position.y = ground_y
	yaw = lerp_angle(yaw, target_yaw, k)
	zoom = lerpf(zoom, target_zoom, 1.0 - exp(-8.0 * delta))
	_update_camera()


func _update_camera() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	var dist := lerpf(MIN_DIST, MAX_DIST, zoom)
	var pitch := deg_to_rad(lerpf(38.0, 62.0, zoom))
	cam.position = Vector3(0.0, sin(pitch) * dist, cos(pitch) * dist)
	cam.rotation = Vector3(-pitch, 0.0, 0.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_MOUSE_EXIT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		mouse_inside = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		mouse_inside = true


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		mouse_inside = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_zoom = clampf(target_zoom - 0.07, 0.0, 1.0)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_zoom = clampf(target_zoom + 0.07, 0.0, 1.0)
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			rotating = mb.pressed
	elif event is InputEventMouseMotion and rotating:
		var mm := event as InputEventMouseMotion
		target_yaw -= mm.relative.x * 0.006
		target_zoom = clampf(target_zoom + mm.relative.y * 0.002, 0.0, 1.0)
