extends Node
## Mouse & keyboard command layer: selection, orders, construction placement, control groups.

const Models := preload("res://scripts/models.gd")

var selection: Array = []
var groups := {}
var mouse_down := false
var dragging := false
var drag_start := Vector2.ZERO
var drag_now := Vector2.ZERO
var pending_double := false
var place_kind := ""
var ghost: Node3D = null
var ghost_valid := false
var ghost_pos := Vector3.ZERO
var _ghost_state := -1
var attack_move_armed := false


func cam() -> Camera3D:
	return Game.world.camera_rig.cam


func _process(_delta: float) -> void:
	for i in range(selection.size() - 1, -1, -1):
		if not Game.alive(selection[i]):
			selection.remove_at(i)
	if place_kind != "":
		_update_ghost()


# ---------------------------------------------------------------- picking

func ground_point(screen: Vector2):
	var c := cam()
	var o := c.project_ray_origin(screen)
	var d := c.project_ray_normal(screen)
	if d.y > -0.0001:
		return null
	var h := 0.0
	var p := o
	for i in 6:
		var t := (h - o.y) / d.y
		if t < 0.0:
			return null
		p = o + d * t
		h = Game.world.height_at(p.x, p.z)
	p.y = h
	return p


func pick_entity(screen: Vector2):
	var c := cam()
	var best = null
	var best_d := INF
	var right := c.global_transform.basis.x
	for e in Game.entities:
		if e.dead:
			continue
		var center: Vector3 = e.global_position + Vector3(0, e.aim_height(), 0)
		if c.is_position_behind(center):
			continue
		var sp := c.unproject_position(center)
		var edge := c.unproject_position(center + right * float(e.radius))
		var pr := maxf(sp.distance_to(edge) * 1.1, 14.0)
		var d := sp.distance_to(screen)
		if d < pr and d < best_d:
			best = e
			best_d = d
	return best


# ---------------------------------------------------------------- input

func _input(event: InputEvent) -> void:
	# Track drags even when the cursor passes over HUD panels.
	if not mouse_down:
		return
	if event is InputEventMouseMotion:
		drag_now = (event as InputEventMouseMotion).position
		if drag_now.distance_to(drag_start) > 8.0:
			dragging = true
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			mouse_down = false
			if dragging:
				_box_select(mb.shift_pressed)
			else:
				_click_select(mb.position, mb.shift_pressed, pending_double)
			dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if Game.game_over:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if place_kind != "":
				_try_place(mb.shift_pressed)
				return
			if attack_move_armed:
				attack_move_armed = false
				var gp = ground_point(mb.position)
				var tgt = pick_entity(mb.position)
				if tgt != null and tgt.team != Game.PLAYER:
					_order_attack(tgt)
				elif gp != null:
					_formation_move(_own_units(), gp, true)
					FX.order_marker(gp, Color(1.0, 0.4, 0.3))
				return
			mouse_down = true
			dragging = false
			pending_double = mb.double_click
			drag_start = mb.position
			drag_now = mb.position
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if place_kind != "":
				cancel_placement()
				return
			if attack_move_armed:
				attack_move_armed = false
				return
			_command(mb.position)
	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			_key(k)


func _key(k: InputEventKey) -> void:
	var code := k.keycode
	if code >= KEY_0 and code <= KEY_9:
		var n := int(code - KEY_0)
		if k.ctrl_pressed or k.meta_pressed:
			groups[n] = selection.duplicate()
			Game.notify("Group %d assigned" % n)
		elif groups.has(n):
			var g: Array = groups[n].filter(func(e): return Game.alive(e))
			if g == selection and not g.is_empty():
				Game.world.camera_rig.focus(g[0].position)
			_set_selection(g)
		return
	match code:
		KEY_ESCAPE:
			if place_kind != "":
				cancel_placement()
			elif attack_move_armed:
				attack_move_armed = false
			else:
				_set_selection([])
		KEY_S:
			stop_selected()
		KEY_A:
			if k.ctrl_pressed or k.meta_pressed:
				_set_selection(Game.entities.filter(func(e): return e.team == Game.PLAYER and not e.is_building and e.has_weapon()))
			else:
				arm_attack_move()
		KEY_H:
			var hq = Game.get_hq(Game.PLAYER)
			if hq != null:
				Game.world.camera_rig.focus(hq.position)
		KEY_SPACE:
			if not selection.is_empty():
				Game.world.camera_rig.focus(selection[0].position)
		KEY_F1, KEY_SLASH, KEY_QUESTION:
			Game.world.hud.toggle_help()
		KEY_F2:
			Game.world.toggle_quality()
		KEY_DELETE, KEY_BACKSPACE:
			if selection.size() == 1 and selection[0].is_building and selection[0].team == Game.PLAYER:
				selection[0].cancel_last()
		KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B:
			var idx := [KEY_Z, KEY_X, KEY_C, KEY_V, KEY_B].find(code)
			Game.world.hud.trigger_hotkey(idx)


# ---------------------------------------------------------------- selection

func _set_selection(arr: Array) -> void:
	for e in selection:
		if Game.alive(e):
			e.set_selected(false)
	selection = arr.duplicate()
	for e in selection:
		e.set_selected(true)


func _own_units() -> Array:
	return selection.filter(func(e): return Game.alive(e) and e.team == Game.PLAYER and not e.is_building)


func _click_select(screen: Vector2, additive: bool, double: bool) -> void:
	var e = pick_entity(screen)
	if e == null:
		if not additive:
			_set_selection([])
		return
	if double and e.team == Game.PLAYER and not e.is_building:
		var same := []
		var vp := get_viewport().get_visible_rect()
		for o in Game.entities:
			if o.team == Game.PLAYER and o.kind == e.kind and not o.dead:
				if vp.has_point(cam().unproject_position(o.global_position)):
					same.append(o)
		_set_selection(same)
		return
	if additive and e.team == Game.PLAYER and not e.is_building:
		var s := _own_units()
		if s.has(e):
			s.erase(e)
		else:
			s.append(e)
		_set_selection(s)
	else:
		_set_selection([e])


func _box_select(additive: bool) -> void:
	var rect := Rect2(drag_start, drag_now - drag_start).abs()
	var c := cam()
	var picked := _own_units() if additive else []
	for e in Game.entities:
		if e.team != Game.PLAYER or e.is_building or e.dead:
			continue
		var p: Vector3 = e.global_position + Vector3(0, e.aim_height(), 0)
		if c.is_position_behind(p):
			continue
		if rect.has_point(c.unproject_position(p)) and not picked.has(e):
			picked.append(e)
	_set_selection(picked)


# ---------------------------------------------------------------- orders

func _command(screen: Vector2) -> void:
	var own := _own_units()
	var target = pick_entity(screen)
	var gp = ground_point(screen)
	if own.is_empty():
		if selection.size() == 1 and selection[0].is_building and selection[0].team == Game.PLAYER and gp != null:
			selection[0].rally = gp
			FX.order_marker(gp, Color(1.0, 0.85, 0.4))
		return
	if target != null and target.team != Game.PLAYER:
		_order_attack(target)
		return
	if target != null and target.is_building and (not target.complete or target.hp < target.max_hp):
		var sent := false
		for u in own:
			if u.kind == "constructor":
				u.cmd_build(target)
				sent = true
		if sent:
			FX.order_marker(target.position, Color(1.0, 0.85, 0.4))
			own = own.filter(func(u): return u.kind != "constructor")
			if own.is_empty():
				return
	if gp != null:
		_formation_move(own, gp, false)
		FX.order_marker(gp, Color(0.45, 1.0, 0.5))


func command_move_to(p: Vector3) -> void:
	var own := _own_units()
	if not own.is_empty():
		_formation_move(own, p, false)
		FX.order_marker(Vector3(p.x, Game.world.height_at(p.x, p.z), p.z), Color(0.45, 1.0, 0.5))


func _order_attack(target) -> void:
	for u in _own_units():
		u.cmd_attack(target)
	FX.order_marker(target.position, Color(1.0, 0.35, 0.3))


func _formation_move(units: Array, dest: Vector3, attack: bool) -> void:
	if units.is_empty():
		return
	var center := Vector3.ZERO
	for u in units:
		center += u.position
	center /= units.size()
	var fwd := dest - center
	fwd.y = 0.0
	if fwd.length() < 0.1:
		fwd = Vector3.FORWARD
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP)
	var spacing := 0.0
	for u in units:
		spacing = maxf(spacing, float(u.radius) * 2.3)
	units.sort_custom(func(a, b): return a.position.dot(right) < b.position.dot(right))
	var cols := int(ceil(sqrt(units.size())))
	for i in units.size():
		var row := i / cols
		var col := i % cols
		var p := dest + right * (col - (cols - 1) * 0.5) * spacing - fwd * row * spacing
		if attack:
			units[i].cmd_attack_move(p)
		else:
			units[i].cmd_move(p)


func stop_selected() -> void:
	for u in _own_units():
		u.cmd_stop()


func arm_attack_move() -> void:
	var armed := false
	for u in _own_units():
		if u.has_weapon():
			armed = true
	attack_move_armed = armed


# ---------------------------------------------------------------- construction

func begin_placement(kind: String) -> void:
	var cost: int = Game.BUILDINGS[kind]["cost"]
	if Game.fuel[Game.PLAYER] < cost:
		Game.notify("Insufficient fuel")
		return
	cancel_placement()
	attack_move_armed = false
	place_kind = kind
	ghost = Models.build_building(kind, Game.PLAYER)
	_ghost_state = -1
	Game.world.fx_root.add_child(ghost)
	_update_ghost()


func cancel_placement() -> void:
	place_kind = ""
	if ghost != null and is_instance_valid(ghost):
		ghost.queue_free()
	ghost = null


func _update_ghost() -> void:
	var gp = ground_point(get_viewport().get_mouse_position())
	if gp == null:
		ghost.visible = false
		return
	ghost.visible = true
	var r = Game.placement_pos(Game.PLAYER, place_kind, gp)
	ghost_valid = r != null
	ghost_pos = r if ghost_valid else gp
	ghost.position = ghost_pos
	ghost.rotation.y = Game.facing_yaw(ghost_pos)
	var st := 1 if ghost_valid else 0
	if st != _ghost_state:
		_ghost_state = st
		Models.make_ghost(ghost, ghost_valid)


func _try_place(keep_placing: bool) -> void:
	if not ghost_valid:
		Game.notify(Game.last_place_error if Game.last_place_error != "" else "Can't build there")
		return
	var cost: int = Game.BUILDINGS[place_kind]["cost"]
	if Game.fuel[Game.PLAYER] < cost:
		Game.notify("Insufficient fuel")
		cancel_placement()
		return
	var site = Game.place_building(Game.PLAYER, place_kind, ghost_pos)
	if site == null:
		return
	var cons := _own_units().filter(func(u): return u.kind == "constructor")
	if cons.is_empty():
		var best = null
		var bd := INF
		for e in Game.entities:
			if e.team == Game.PLAYER and e.kind == "constructor" and not e.dead:
				var d: float = e.position.distance_to(ghost_pos)
				if e.is_idle():
					d *= 0.5
				if d < bd:
					bd = d
					best = e
		if best != null:
			cons = [best]
	for c in cons:
		c.cmd_build(site)
	FX.order_marker(ghost_pos, Color(1.0, 0.85, 0.4))
	if not keep_placing or Game.fuel[Game.PLAYER] < cost:
		cancel_placement()
