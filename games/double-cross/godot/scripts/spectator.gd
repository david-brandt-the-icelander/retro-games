extends CanvasLayer
class_name SpectatorView
## Split-screen grid showing every surviving agent at once (or one, full screen).

var game: Game
var root: Control
var grid: GridContainer
var cells: Array = []     # [{id, cam, label, hp}]
var focus := -1           # -1 = grid, otherwise index into cells
var is_open := false


func setup(g: Game) -> void:
	game = g
	layer = 5
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.03)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	grid = GridContainer.new()
	grid.set_anchors_preset(Control.PRESET_FULL_RECT)
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	root.add_child(grid)


func open() -> void:
	is_open = true
	root.visible = true
	rebuild()


func cycle_focus() -> void:
	if cells.is_empty():
		return
	focus += 1
	if focus >= cells.size():
		focus = -1
	_apply_focus()


func _targets() -> Array:
	var out := []
	var ids: Array = game.agents.keys()
	ids.sort()
	for id in ids:
		if game.info[id].alive or game.game_over:
			out.append(id)
	return out


func rebuild() -> void:
	if not is_open:
		return
	for c in grid.get_children():
		c.queue_free()
	cells.clear()
	var targets := _targets()
	if targets.is_empty():
		targets = [-1]   # overview camera
	grid.columns = ceili(sqrt(targets.size()))
	for id in targets:
		_add_cell(id)
	focus = clampi(focus, -1, cells.size() - 1)
	_apply_focus()


func _add_cell(id: int) -> void:
	var cell := Control.new()
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cell.clip_contents = true
	grid.add_child(cell)

	var svc := SubViewportContainer.new()
	svc.stretch = true
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell.add_child(svc)
	var sv := SubViewport.new()
	sv.msaa_3d = Viewport.MSAA_2X
	svc.add_child(sv)
	var cam := Camera3D.new()
	cam.fov = 50
	sv.add_child(cam)

	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", HUD.panel_style(0.7))
	cell.add_child(tag)
	tag.position = Vector2(10, 10)
	var v := VBoxContainer.new()
	tag.add_child(v)
	var label: Label
	var hp: Label
	if id == -1:
		label = HUD.lbl("OVERVIEW", 16, Color(1, 1, 1, 0.8))
		hp = HUD.lbl("", 12)
	else:
		label = HUD.lbl(game.info[id].name.to_upper(), 16, game.info[id].color)
		hp = HUD.lbl("", 12, Color(1, 1, 1, 0.8))
	v.add_child(label)
	v.add_child(hp)

	var border := ReferenceRect.new()
	border.set_anchors_preset(Control.PRESET_FULL_RECT)
	border.border_color = Color(1, 1, 1, 0.12) if id == -1 else Color(game.info[id].color, 0.6)
	border.border_width = 2
	border.editor_only = false
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(border)
	cells.append({"id": id, "cam": cam, "hp": hp, "cell": cell})
	_place_cam(cells.back(), 1.0)


func _apply_focus() -> void:
	for i in cells.size():
		cells[i].cell.visible = focus == -1 or focus == i
	grid.columns = ceili(sqrt(cells.size())) if focus == -1 else 1


func _process(delta: float) -> void:
	if not is_open:
		return
	for c in cells:
		_place_cam(c, delta)
		if c.id != -1 and game.info.has(c.id):
			var i: Dictionary = game.info[c.id]
			var intel := []
			for it in i.items:
				intel.append(Maps.ITEM_LABELS[it])
			c.hp.text = "%d HP · %s" % [i.hp, ", ".join(intel) if not intel.is_empty() else "no intel"]


func _place_cam(c: Dictionary, delta: float) -> void:
	var cam: Camera3D = c.cam
	var target := Vector3.ZERO
	var dist := 13.0
	if c.id == -1 or not game.agents.has(c.id):
		for r in game.layout.rooms:
			target += r.center
		target /= maxf(1.0, game.layout.rooms.size())
		dist = 32.0
	else:
		target = game.agents[c.id].position
	var want := target + Vector3(0, dist, dist * 0.43)
	cam.position = cam.position.lerp(want, minf(1.0, 1.0 - exp(-6.0 * delta)))
	cam.look_at(cam.position - Vector3(0, dist, dist * 0.43))
