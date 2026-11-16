extends Control
## Screen-space overlay: health bars, construction/production progress, drag box, cursor hints.

const GOLD := Color(1.0, 0.82, 0.4)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var w = Game.world
	if w == null or w.camera_rig == null or w.controller == null:
		return
	var cam: Camera3D = w.camera_rig.cam
	var ctrl = w.controller
	var vp := get_viewport_rect().size
	var right := cam.global_transform.basis.x
	for e in Game.entities:
		if e.dead:
			continue
		var under_construction: bool = e.is_building and not e.complete
		var producing: bool = e.is_building and e.complete and not e.queue.is_empty()
		if not (e.is_selected() or e.hp < e.max_hp - 0.5 or under_construction or (producing and e.team == Game.PLAYER)):
			continue
		var top: Vector3 = e.global_position + Vector3(0, e.bar_height(), 0)
		if cam.is_position_behind(top):
			continue
		var sp := cam.unproject_position(top)
		if sp.x < -60 or sp.y < -60 or sp.x > vp.x + 60 or sp.y > vp.y + 60:
			continue
		var edge := cam.unproject_position(top + right * float(e.radius))
		var wdt := clampf(sp.distance_to(edge) * 1.6, 28.0, 120.0)
		var r := Rect2(sp.x - wdt * 0.5, sp.y - 3.0, wdt, 5.0)
		draw_rect(r.grow(1.5), Color(0, 0, 0, 0.75))
		var ratio := clampf(float(e.hp) / float(e.max_hp), 0.0, 1.0)
		var col: Color
		if ratio > 0.5:
			col = Color(0.95, 0.8, 0.2).lerp(Color(0.35, 0.9, 0.35), (ratio - 0.5) * 2.0)
		else:
			col = Color(0.9, 0.2, 0.15).lerp(Color(0.95, 0.8, 0.2), ratio * 2.0)
		if e.team != Game.PLAYER:
			col = col.lerp(Color(1.0, 0.3, 0.25), 0.5)
		draw_rect(Rect2(r.position, Vector2(wdt * ratio, 5.0)), col)
		if under_construction:
			var pr := Rect2(r.position + Vector2(0, 8), Vector2(wdt, 4))
			draw_rect(pr.grow(1.0), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(pr.position, Vector2(wdt * float(e.progress), 4)), Color(0.4, 0.75, 1.0))
		elif producing and e.team == Game.PLAYER:
			var pr2 := Rect2(r.position + Vector2(0, 8), Vector2(wdt, 4))
			draw_rect(pr2.grow(1.0), Color(0, 0, 0, 0.75))
			draw_rect(Rect2(pr2.position, Vector2(wdt * float(e.production_ratio()), 4)), GOLD)
	if ctrl.dragging:
		var rect := Rect2(ctrl.drag_start, ctrl.drag_now - ctrl.drag_start).abs()
		draw_rect(rect, Color(1.0, 0.82, 0.4, 0.1))
		draw_rect(rect, Color(1.0, 0.82, 0.4, 0.9), false, 1.5)
	var font := get_theme_default_font()
	var mp := get_viewport().get_mouse_position()
	if ctrl.attack_move_armed:
		draw_arc(mp, 11.0, 0.0, TAU, 24, Color(1.0, 0.35, 0.3), 2.0)
		draw_line(mp - Vector2(16, 0), mp + Vector2(16, 0), Color(1.0, 0.35, 0.3), 1.5)
		draw_line(mp - Vector2(0, 16), mp + Vector2(0, 16), Color(1.0, 0.35, 0.3), 1.5)
		draw_string_outline(font, mp + Vector2(18, 30), "ATTACK-MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, mp + Vector2(18, 30), "ATTACK-MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.45, 0.35))
	if ctrl.place_kind != "":
		var bd: Dictionary = Game.BUILDINGS[ctrl.place_kind]
		var txt := "%s  (%d fuel)" % [bd["name"], bd["cost"]]
		var sub: String = "Click to build  ·  Shift-click: build more  ·  Right-click: cancel"
		var c := Color(0.55, 1.0, 0.6)
		if not ctrl.ghost_valid:
			sub = Game.last_place_error
			c = Color(1.0, 0.45, 0.4)
		draw_string_outline(font, mp + Vector2(20, 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color(0, 0, 0, 0.85))
		draw_string(font, mp + Vector2(20, 32), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, c)
		draw_string_outline(font, mp + Vector2(20, 50), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color(0, 0, 0, 0.85))
		draw_string(font, mp + Vector2(20, 50), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.92, 0.86, 0.72))
