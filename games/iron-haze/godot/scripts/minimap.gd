extends Control
## Tactical map: terrain relief, wells, forces and the camera footprint.
## Left-click/drag to look, right-click to send the selection.

var dragging := false


func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _process(_delta: float) -> void:
	queue_redraw()


func world_to_map(p: Vector3) -> Vector2:
	var h := Game.MAP_HALF
	return Vector2((p.x + h) / (2.0 * h) * size.x, (p.z + h) / (2.0 * h) * size.y)


func map_to_world(m: Vector2) -> Vector3:
	var h := Game.MAP_HALF
	return Vector3(m.x / size.x * 2.0 * h - h, 0.0, m.y / size.y * 2.0 * h - h)


func _draw() -> void:
	var w = Game.world
	if w == null or w.minimap_texture == null:
		return
	draw_texture_rect(w.minimap_texture, Rect2(Vector2.ZERO, size), false)
	for well in Game.wells:
		var wp := world_to_map(well["pos"])
		draw_circle(wp, 3.0, Color(0.0, 0.0, 0.0, 0.85))
		draw_arc(wp, 3.0, 0.0, TAU, 10, Color(0.9, 0.75, 0.4, 0.6), 1.0)
	var scale_k := size.x / (Game.MAP_HALF * 2.0)
	for e in Game.entities:
		if e.dead:
			continue
		var p := world_to_map(e.position)
		var col: Color = Game.TEAM_UI_COLORS[e.team]
		if e.is_selected():
			col = Color(1, 1, 1)
		if e.is_building:
			var s := maxf(2.5, float(e.size) * 0.5 * scale_k)
			draw_rect(Rect2(p - Vector2(s, s), Vector2(s, s) * 2.0), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(p - Vector2(s, s) + Vector2(1, 1), Vector2(s, s) * 2.0 - Vector2(2, 2)), col)
		elif e.is_air:
			draw_circle(p, 3.2, Color(0, 0, 0, 0.7))
			draw_circle(p, 2.4, col)
		else:
			draw_circle(p, 2.0, col)
	var ctrl = w.controller
	if ctrl != null:
		var vp := get_viewport().get_visible_rect().size
		var corners := [Vector2(0, 0), Vector2(vp.x, 0), Vector2(vp.x, vp.y), Vector2(0, vp.y)]
		var pts := PackedVector2Array()
		for c in corners:
			var gp = ctrl.ground_point(c)
			if gp == null:
				var cam: Camera3D = w.camera_rig.cam
				var o := cam.project_ray_origin(c)
				var d := cam.project_ray_normal(c)
				d.y = minf(d.y, -0.08)
				gp = o + d * ((0.0 - o.y) / d.y)
			pts.append(world_to_map(gp))
		pts.append(pts[0])
		draw_polyline(pts, Color(1.0, 0.92, 0.7, 0.9), 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.75, 0.57, 0.28), false, 2.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			dragging = mb.pressed
			if mb.pressed:
				_look(mb.position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			var p := map_to_world(mb.position)
			Game.world.controller.command_move_to(p)
		accept_event()
	elif event is InputEventMouseMotion and dragging:
		_look((event as InputEventMouseMotion).position)
		accept_event()


func _look(m: Vector2) -> void:
	Game.world.camera_rig.focus(map_to_world(m))
