extends CanvasLayer
class_name HUD
## In-match overlay: health, intel, traps, tools, minimap, feed, prompts.

var game: Game
var root: Control
var hp_bar: ProgressBar
var hp_label: Label
var name_label: Label
var room_label: Label
var timer_label: Label
var mode_label: Label
var alive_label: Label
var obj_slots := {}
var trap_slots: Array = []
var tools_label: RichTextLabel
var prompt: Label
var action_bar: ProgressBar
var feed_box: VBoxContainer
var damage_flash: ColorRect
var big_title: Label
var big_sub: Label
var over_panel: PanelContainer
var over_title: Label
var over_text: Label
var minimap: Minimap
var player_panels: Array = []   # hidden while spectating
var help_label: Label

const ACCENT := Color(0.35, 0.85, 1.0)


static func panel_style(alpha := 0.62, border := Color(1, 1, 1, 0.08)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, alpha)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = border
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


static func lbl(text: String, size := 16, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 4)
	return l


func _panel(anchor_preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	p.set_anchors_and_offsets_preset(anchor_preset, Control.PRESET_MODE_KEEP_SIZE, 0)
	p.set_meta("offset", offset)
	return p


func setup(g: Game) -> void:
	game = g
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	damage_flash = ColorRect.new()
	damage_flash.color = Color(1, 0.1, 0.1, 0)
	damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(damage_flash)

	# --- top-left: identity + health
	var tl := _corner(Control.PRESET_TOP_LEFT, Vector2(20, 20))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	tl.add_child(v)
	var me: Dictionary = game.info.get(game.my_id, {})
	name_label = lbl(me.get("name", Net.my_name).to_upper(), 20, me.get("color", ACCENT))
	v.add_child(name_label)
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(260, 16)
	hp_bar.max_value = Game.MAX_HP
	hp_bar.value = Game.MAX_HP
	hp_bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.35, 1.0, 0.6)
	fill.set_corner_radius_all(8)
	hp_bar.add_theme_stylebox_override("background", bg)
	hp_bar.add_theme_stylebox_override("fill", fill)
	v.add_child(hp_bar)
	hp_label = lbl("100 HP", 13, Color(1, 1, 1, 0.7))
	v.add_child(hp_label)
	room_label = lbl("", 15, Color(0.8, 0.88, 1.0, 0.9))
	v.add_child(room_label)
	player_panels.append(tl)

	# --- top-centre: timer
	var tc := _corner(Control.PRESET_CENTER_TOP, Vector2(0, 16))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tc.add_child(tv)
	timer_label = lbl("10:00", 30)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(timer_label)
	var mode_txt: String = "CO-OP TEAMS" if game.mode == "teams" else "LAST AGENT STANDING"
	mode_label = lbl("%s · %s" % [mode_txt, game.layout.def.name.to_upper()], 12, Color(1, 1, 1, 0.6))
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(mode_label)
	alive_label = lbl("", 13, Color(1, 0.75, 0.5))
	alive_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tv.add_child(alive_label)

	# --- top-right: minimap
	var tr := _corner(Control.PRESET_TOP_RIGHT, Vector2(-20, 20))
	minimap = Minimap.new()
	minimap.game = game
	minimap.custom_minimum_size = Vector2(230, 190)
	tr.add_child(minimap)

	# --- bottom-left: intel
	var bl := _corner(Control.PRESET_BOTTOM_LEFT, Vector2(20, -20))
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 6)
	bl.add_child(bv)
	bv.add_child(lbl("INTEL", 12, Color(1, 1, 1, 0.55)))
	var oh := HBoxContainer.new()
	oh.add_theme_constant_override("separation", 8)
	bv.add_child(oh)
	for o in Maps.OBJECTIVES:
		var slot := PanelContainer.new()
		var sb := panel_style(0.4)
		sb.content_margin_left = 8
		sb.content_margin_right = 8
		slot.add_theme_stylebox_override("panel", sb)
		slot.custom_minimum_size = Vector2(84, 46)
		var l := lbl(Maps.ITEM_LABELS[o].to_upper(), 12, Color(1, 1, 1, 0.35))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot.add_child(l)
		oh.add_child(slot)
		obj_slots[o] = [slot, l, sb]
	bv.add_child(lbl("GADGETS", 12, Color(1, 1, 1, 0.55)))
	tools_label = RichTextLabel.new()
	tools_label.bbcode_enabled = true
	tools_label.fit_content = true
	tools_label.custom_minimum_size = Vector2(360, 22)
	tools_label.add_theme_font_size_override("normal_font_size", 14)
	bv.add_child(tools_label)
	player_panels.append(bl)

	# --- bottom-centre: trap selector
	var bc := _corner(Control.PRESET_CENTER_BOTTOM, Vector2(0, -20))
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 10)
	bc.add_child(th)
	for i in 4:
		var t: String = Maps.TRAP_ORDER[i]
		var def: Dictionary = Maps.TRAPS[t]
		var slot := PanelContainer.new()
		var sb := panel_style(0.5)
		slot.add_theme_stylebox_override("panel", sb)
		slot.custom_minimum_size = Vector2(124, 64)
		var sv := VBoxContainer.new()
		sv.add_theme_constant_override("separation", 2)
		slot.add_child(sv)
		var top := lbl("%d  %s" % [i + 1, def.label.to_upper()], 12, def.color)
		sv.add_child(top)
		var sub := lbl("on " + ("furniture" if def.where == "furniture" else "doorways"), 11, Color(1, 1, 1, 0.5))
		sv.add_child(sub)
		var cd := lbl("READY", 12, Color(1, 1, 1, 0.8))
		sv.add_child(cd)
		th.add_child(slot)
		trap_slots.append([slot, sb, cd, def.color])
	player_panels.append(bc)

	# --- right: feed
	feed_box = VBoxContainer.new()
	feed_box.alignment = BoxContainer.ALIGNMENT_END
	feed_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_theme_constant_override("separation", 4)
	root.add_child(feed_box)
	feed_box.anchor_left = 1.0
	feed_box.anchor_right = 1.0
	feed_box.anchor_top = 0.0
	feed_box.anchor_bottom = 1.0
	feed_box.offset_left = -440
	feed_box.offset_right = -20
	feed_box.offset_top = 240
	feed_box.offset_bottom = -110

	# --- centre: prompt + action progress
	prompt = lbl("", 18, Color(1, 1, 1, 0.95))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(prompt)
	prompt.anchor_left = 0.5
	prompt.anchor_right = 0.5
	prompt.anchor_top = 0.62
	prompt.anchor_bottom = 0.62
	prompt.offset_left = -300
	prompt.offset_right = 300
	action_bar = ProgressBar.new()
	action_bar.show_percentage = false
	action_bar.max_value = 1.0
	action_bar.custom_minimum_size = Vector2(200, 8)
	var abg := StyleBoxFlat.new()
	abg.bg_color = Color(0, 0, 0, 0.5)
	abg.set_corner_radius_all(4)
	var afill := StyleBoxFlat.new()
	afill.bg_color = ACCENT
	afill.set_corner_radius_all(4)
	action_bar.add_theme_stylebox_override("background", abg)
	action_bar.add_theme_stylebox_override("fill", afill)
	root.add_child(action_bar)
	action_bar.anchor_left = 0.5
	action_bar.anchor_right = 0.5
	action_bar.anchor_top = 0.58
	action_bar.anchor_bottom = 0.58
	action_bar.offset_left = -100
	action_bar.offset_right = 100
	action_bar.visible = false

	help_label = lbl("WASD move · E search · F set trap · 1-4 / Q / wheel pick trap · SPACE / click punch", 12, Color(1, 1, 1, 0.4))
	root.add_child(help_label)
	help_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help_label.offset_top = -16
	help_label.offset_bottom = -2
	help_label.grow_horizontal = Control.GROW_DIRECTION_BOTH

	# --- big centre message
	big_title = lbl("", 72)
	big_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(big_title)
	big_title.set_anchors_preset(Control.PRESET_CENTER)
	big_title.offset_left = -500
	big_title.offset_right = 500
	big_title.offset_top = -120
	big_title.offset_bottom = -30
	big_sub = lbl("", 22, Color(1, 1, 1, 0.8))
	big_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(big_sub)
	big_sub.set_anchors_preset(Control.PRESET_CENTER)
	big_sub.offset_left = -500
	big_sub.offset_right = 500
	big_sub.offset_top = -30
	big_sub.offset_bottom = 10

	# --- game over
	over_panel = PanelContainer.new()
	over_panel.add_theme_stylebox_override("panel", panel_style(0.85, Color(1, 1, 1, 0.15)))
	root.add_child(over_panel)
	over_panel.set_anchors_preset(Control.PRESET_CENTER)
	over_panel.offset_left = -300
	over_panel.offset_right = 300
	over_panel.offset_top = -110
	over_panel.offset_bottom = 110
	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 14)
	over_panel.add_child(ov)
	over_title = lbl("", 54)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(over_title)
	over_text = lbl("", 18, Color(1, 1, 1, 0.85))
	over_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	over_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ov.add_child(over_text)
	if Net.is_host():
		var b := Button.new()
		b.text = "Return everyone to the lobby"
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(Net.return_to_lobby)
		ov.add_child(b)
	else:
		ov.add_child(lbl("Waiting for the host…", 14, Color(1, 1, 1, 0.5)))
	over_panel.visible = false
	_over_box = ov

	await get_tree().process_frame
	_layout_corners()
	get_viewport().size_changed.connect(_layout_corners)
	refresh()


var _corners: Array = []
var _over_box: VBoxContainer


func allow_local_return() -> void:
	var b := Button.new()
	b.text = "Back to the briefing room"
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(Net.local_return_to_lobby)
	_over_box.add_child(b)

func _corner(preset: int, offset: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	_corners.append([p, preset, offset])
	return p


func _layout_corners() -> void:
	for c in _corners:
		var p: Control = c[0]
		p.reset_size()
		p.set_anchors_and_offsets_preset(c[1], Control.PRESET_MODE_MINSIZE, 0)
		p.position += c[2]


func refresh() -> void:
	if hp_bar == null:
		return
	var me: Dictionary = game.info.get(game.my_id, {})
	if not me.is_empty():
		hp_bar.value = me.hp
		hp_label.text = "%d HP" % me.hp
		var fill: StyleBoxFlat = hp_bar.get_theme_stylebox("fill")
		fill.bg_color = Color(1, 0.3, 0.3).lerp(Color(0.35, 1.0, 0.6), me.hp / float(Game.MAX_HP))
		var team_have: Array = game._team_objectives(me.team)
		for o in Maps.OBJECTIVES:
			var slot = obj_slots[o]
			var c: Color = Maps.ITEM_COLORS[o]
			var sb: StyleBoxFlat = slot[2]
			if me.items.has(o):
				sb.bg_color = Color(c.r, c.g, c.b, 0.35)
				sb.border_color = c
				sb.set_border_width_all(2)
				slot[1].add_theme_color_override("font_color", Color.WHITE)
			elif team_have.has(o):
				sb.bg_color = Color(c.r, c.g, c.b, 0.12)
				sb.border_color = Color(c.r, c.g, c.b, 0.6)
				sb.set_border_width_all(1)
				slot[1].add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
			else:
				sb.bg_color = Color(0.04, 0.05, 0.08, 0.4)
				sb.border_color = Color(1, 1, 1, 0.08)
				sb.set_border_width_all(1)
				slot[1].add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
		var parts := []
		for t in Maps.TOOLS:
			var n: int = me.tools.count(t)
			if n > 0:
				parts.append("[color=#%s]%s%s[/color]" % [Maps.ITEM_COLORS[t].to_html(false), Maps.ITEM_LABELS[t], " ×%d" % n if n > 1 else ""])
		tools_label.text = "  ·  ".join(parts) if not parts.is_empty() else "[color=#ffffff55]none — search furniture to find counter-gadgets[/color]"
	for i in trap_slots.size():
		var sb: StyleBoxFlat = trap_slots[i][1]
		var c: Color = trap_slots[i][3]
		if i == game.trap_sel:
			sb.border_color = c
			sb.set_border_width_all(2)
			sb.bg_color = Color(c.r * 0.2, c.g * 0.2, c.b * 0.2, 0.75)
		else:
			sb.border_color = Color(1, 1, 1, 0.08)
			sb.set_border_width_all(1)
			sb.bg_color = Color(0.04, 0.05, 0.08, 0.5)
	var alive := 0
	for id in game.info:
		if game.info[id].alive:
			alive += 1
	alive_label.text = "%d / %d agents active" % [alive, game.info.size()]


func update_frame() -> void:
	var t := maxf(0.0, game.time_left)
	timer_label.text = "%d:%02d" % [int(t) / 60, int(t) % 60]
	timer_label.add_theme_color_override("font_color", Color(1, 0.4, 0.35) if t < 60 else Color.WHITE)
	for i in trap_slots.size():
		var t_id: String = Maps.TRAP_ORDER[i]
		var rem: float = game.trap_ready[t_id] - game.now()
		trap_slots[i][2].text = "READY" if rem <= 0 else "%.1fs" % rem
		trap_slots[i][2].modulate = Color(0.6, 1, 0.7) if rem <= 0 else Color(1, 0.7, 0.4)
	# Action progress
	if not game.pending_action.is_empty():
		action_bar.visible = true
		action_bar.value = 1.0 - (game.pending_action.end - game.now()) / game.pending_action.duration
	else:
		action_bar.visible = false
	_update_prompt()
	# Feed fade
	for c in feed_box.get_children():
		var age: float = game.now() - c.get_meta("born")
		if age > 7.0:
			c.modulate.a = maxf(0.0, 1.0 - (age - 7.0))
			if age > 8.0:
				c.queue_free()
	damage_flash.color.a = maxf(0.0, damage_flash.color.a - get_process_delta_time() * 1.5)
	minimap.queue_redraw()


func _update_prompt() -> void:
	prompt.text = ""
	var a := game.local_agent()
	if a == null or not a.alive or game.game_over or not game.pending_action.is_empty():
		return
	var lines := []
	var f := game.nearest_furniture(a.position)
	if f >= 0:
		lines.append("[E] Search %s" % String(game.layout.furniture[f].type).capitalize())
	var t := game.selected_trap()
	var def: Dictionary = Maps.TRAPS[t]
	if def.where == "furniture" and f >= 0:
		lines.append("[F] Rig with %s" % def.label)
	elif def.where == "door":
		var d := game.nearest_door(a.position)
		if d >= 0:
			lines.append("[F] Rig doorway with %s" % def.label)
	if not game.layout.exit.is_empty():
		var ep: Vector3 = game.layout.exit.pos - game.layout.exit.normal * 0.8
		if a.position.distance_to(ep) < 3.0:
			var have: Array = game._team_objectives(game.info[game.my_id].team)
			lines.append("EXTRACTION — %d/4 intel secured" % have.size())
	prompt.text = "    ".join(lines)


func feed(text: String, color := Color.WHITE) -> void:
	print("[%s] %s" % [Net.my_name, text])
	if feed_box == null:
		return
	var p := PanelContainer.new()
	var sb := panel_style(0.55)
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.border_color = Color(color.r, color.g, color.b, 0.5)
	sb.border_width_left = 3
	p.add_theme_stylebox_override("panel", sb)
	var l := lbl(text, 14, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.add_child(l)
	p.set_meta("born", game.now())
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feed_box.add_child(p)
	while feed_box.get_child_count() > 7:
		feed_box.get_child(0).free()


func flash_damage() -> void:
	damage_flash.color.a = 0.35


func set_room(room_name: String) -> void:
	room_label.text = room_name


func big_message(title: String, sub: String, color: Color) -> void:
	big_title.text = title
	big_title.add_theme_color_override("font_color", color)
	big_sub.text = sub
	big_title.modulate.a = 1.0
	big_sub.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(big_title, "modulate:a", 0.0, 0.6)
	tw.parallel().tween_property(big_sub, "modulate:a", 0.0, 0.6)


func set_spectating(on: bool) -> void:
	for p in player_panels:
		p.visible = not on
	help_label.text = "SPECTATING · TAB to switch between grid and single agent" if on else help_label.text
	minimap.custom_minimum_size = Vector2(230, 190) if not on else Vector2(200, 165)


func game_over(title: String, text: String, color: Color) -> void:
	print("[%s] GAME OVER: %s — %s" % [Net.my_name, title, text])
	over_title.text = title
	over_title.add_theme_color_override("font_color", color)
	over_text.text = text
	over_panel.visible = true
	over_panel.modulate.a = 0.0
	create_tween().tween_property(over_panel, "modulate:a", 1.0, 0.4)


# ---------------------------------------------------------------- minimap

class Minimap extends Control:
	var game: Game

	func _draw() -> void:
		if game == null or game.layout.is_empty():
			return
		var rooms: Array = game.layout.rooms
		var max_c := Vector2i.ZERO
		for r in rooms:
			max_c.x = maxi(max_c.x, r.cell.x)
			max_c.y = maxi(max_c.y, r.cell.y)
		var cells := Vector2(max_c.x + 1, max_c.y + 1)
		var cs := minf((size.x - 8) / cells.x, (size.y - 8) / cells.y)
		var origin := (size - cells * cs) * 0.5
		var spect := game._is_spectating()
		for i in rooms.size():
			var r: Dictionary = rooms[i]
			var rect := Rect2(origin + Vector2(r.cell) * cs + Vector2(2, 2), Vector2(cs - 4, cs - 4))
			var col := Color(1, 1, 1, 0.07)
			if i == game.current_room and not spect:
				col = Color(0.35, 0.85, 1.0, 0.28)
			if i == game.layout.exit_room:
				col = col.lerp(Color(0.2, 1, 0.5, 0.35), 0.6)
			draw_rect(rect, col)
			draw_rect(rect, Color(1, 1, 1, 0.15), false, 1.0)
		var scale := cs / Maps.ROOM_SIZE
		var to_map := func(p: Vector3) -> Vector2:
			return origin + (Vector2(p.x, p.z) + Vector2.ONE * Maps.ROOM_SIZE * 0.5) * scale
		for d in game.layout.doors:
			draw_circle(to_map.call(d.pos), 2.5, Color(1, 1, 1, 0.45))
		if not game.layout.exit.is_empty():
			draw_circle(to_map.call(game.layout.exit.pos), 5.0, Color(0.3, 1, 0.55))
		var my_team: int = game.info[game.my_id].team if game.info.has(game.my_id) else -1
		for id in game.agents:
			var a: Agent = game.agents[id]
			if not game.info[id].alive:
				continue
			var show: bool = spect or id == game.my_id or (game.mode == "teams" and game.info[id].team == my_team)
			if not show:
				continue
			var p: Vector2 = to_map.call(a.position)
			draw_circle(p, 5.0 if id == game.my_id else 4.0, a.color)
			if id == game.my_id:
				draw_arc(p, 8.0, 0, TAU, 20, Color(1, 1, 1, 0.8), 1.5)
