class_name Hud
extends CanvasLayer
## In-game interface: top bar, unit & city panels, tech tree, minimap,
## notifications, chat and end-turn button.

var main  ## Main.gd
var game: Game
var pid := 0

var root: Control
var top_civ: Label
var top_turn: Label
var top_gold: Label
var top_sci: Label
var research_btn: Button
var research_bar: ProgressBar
var players_box: HBoxContainer

var unit_panel: PanelContainer
var unit_title: Label
var unit_stats: RichTextLabel
var unit_hp: ProgressBar
var unit_actions: HFlowContainer

var city_panel: PanelContainer
var city_body: VBoxContainer

var end_btn: Button
var end_sub: Label
var minimap: TextureRect
var minimap_img: Image
var minimap_tex: ImageTexture
var notes: VBoxContainer
var tooltip: PanelContainer
var tooltip_lbl: RichTextLabel
var chat_edit: LineEdit
var tech_overlay: Control
var tech_canvas: Control
var over_overlay: Control

func setup(m, g: Game, local_pid: int) -> void:
	main = m
	game = g
	pid = local_pid
	layer = 10
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.build()
	add_child(root)
	_build_top()
	_build_unit_panel()
	_build_city_panel()
	_build_bottom_right()
	_build_notes()
	_build_tooltip()
	_build_chat()
	_build_tech_tree()
	game.notify.connect(_on_notify)
	refresh()

# ---------------------------------------------------------------- top bar

func _build_top() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 10
	bar.offset_right = -10
	bar.offset_top = 8
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 22)
	bar.add_child(hb)
	top_civ = UiTheme.label("", 17)
	hb.add_child(top_civ)
	top_turn = UiTheme.label("", 15, UiTheme.MUTED)
	hb.add_child(top_turn)
	top_gold = UiTheme.label("", 15, UiTheme.GOLD)
	top_gold.mouse_filter = Control.MOUSE_FILTER_PASS
	hb.add_child(top_gold)
	top_sci = UiTheme.label("", 15, UiTheme.SCIENCE)
	hb.add_child(top_sci)
	var rbox := VBoxContainer.new()
	rbox.add_theme_constant_override("separation", 2)
	rbox.custom_minimum_size = Vector2(260, 0)
	hb.add_child(rbox)
	research_btn = Button.new()
	research_btn.flat = true
	research_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	research_btn.add_theme_color_override("font_color", UiTheme.SCIENCE)
	research_btn.pressed.connect(toggle_tech_tree)
	rbox.add_child(research_btn)
	research_bar = UiTheme.bar(UiTheme.SCIENCE, 4)
	rbox.add_child(research_bar)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(spacer)
	players_box = HBoxContainer.new()
	players_box.add_theme_constant_override("separation", 4)
	hb.add_child(players_box)
	var menu := UiTheme.button("Leave", func(): main.leave_game(), 13)
	hb.add_child(menu)

func _player_chip(p) -> Control:
	var pc := PanelContainer.new()
	var s := UiTheme.sb(Color(p.color, 0.85) if p.alive else Color(0.3, 0.3, 0.3, 0.5), 6, Color(1, 1, 1, 0.5) if p.id == pid else Color(0, 0, 0, 0), 2 if p.id == pid else 0, 5)
	s.shadow_size = 0
	pc.add_theme_stylebox_override("panel", s)
	var l := UiTheme.label(p.civ_name().left(3).to_upper(), 12, Color(0.05, 0.05, 0.07))
	if not p.alive:
		l.text = "✝"
	elif not p.is_ai():
		l.text += " ✓" if p.ready else " …"
	pc.add_child(l)
	var kind := "AI" if p.is_ai() else "Human"
	pc.tooltip_text = "%s of %s (%s)\nScore %d · %d cities" % [p.name, p.civ_name(), kind, game.score(p.id), game.player_cities(p.id).size()]
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	return pc

# ---------------------------------------------------------------- unit panel

func _build_unit_panel() -> void:
	unit_panel = PanelContainer.new()
	unit_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	unit_panel.offset_left = 12
	unit_panel.offset_bottom = -12
	unit_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	unit_panel.custom_minimum_size = Vector2(380, 0)
	root.add_child(unit_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	unit_panel.add_child(vb)
	unit_title = UiTheme.label("", 20, UiTheme.ACCENT)
	vb.add_child(unit_title)
	unit_stats = RichTextLabel.new()
	unit_stats.bbcode_enabled = true
	unit_stats.fit_content = true
	unit_stats.scroll_active = false
	unit_stats.custom_minimum_size = Vector2(350, 0)
	vb.add_child(unit_stats)
	unit_hp = UiTheme.bar(Color("5be37d"), 8)
	vb.add_child(unit_hp)
	unit_actions = HFlowContainer.new()
	unit_actions.add_theme_constant_override("h_separation", 6)
	unit_actions.add_theme_constant_override("v_separation", 6)
	vb.add_child(unit_actions)
	unit_panel.visible = false

func show_unit(u) -> void:
	city_panel.visible = false
	if u == null:
		unit_panel.visible = false
		return
	unit_panel.visible = true
	var d: Dictionary = u.def()
	var mine: bool = u.owner == pid
	unit_title.text = d.name + ("  ★" if u.veteran else "")
	if not mine:
		unit_title.text += "  (%s)" % game.player(u.owner).civ_name()
	var s := "[color=#9aa6b5]Moves[/color] %d/%d" % [u.moves, d.moves]
	if d.str > 0:
		s += "    [color=#9aa6b5]Strength[/color] %d" % d.str
	if d.rstr > 0:
		s += "    [color=#9aa6b5]Ranged[/color] %d (range %d)" % [d.rstr, d.range]
	if u.build_kind != "":
		s += "\nBuilding %s — %d turns left" % [Defs.IMPROVEMENTS[u.build_kind].name, u.build_left]
	elif u.fortified:
		s += "\n[color=#8fe388]Fortified (+25% defense)[/color]"
	elif u.goto.x >= 0:
		s += "\nMoving to destination…"
	var y := game.tile_yield(u.pos)
	s += "\n[color=#9aa6b5]%s[/color]" % _tile_desc(u.pos)
	unit_stats.text = s
	unit_hp.value = u.hp
	unit_hp.visible = d.str > 0
	for ch in unit_actions.get_children():
		ch.queue_free()
	if not mine:
		return
	if u.type == "settler":
		var b := UiTheme.button("Found City [B]", func(): main.cmd_unit("found"))
		b.disabled = not game.can_found_city(u)
		if b.disabled:
			b.tooltip_text = "Needs land at least 3 tiles from other cities."
		unit_actions.add_child(b)
	if u.type == "worker":
		for k in Defs.IMPROVEMENTS:
			if game.can_improve(u, k):
				var kk: String = k
				var imp: Dictionary = Defs.IMPROVEMENTS[k]
				var b := UiTheme.button("Build %s (%d)" % [imp.name, imp.turns], func(): main.cmd_unit("improve", {"kind": kk}))
				unit_actions.add_child(b)
	if not u.is_civilian():
		unit_actions.add_child(UiTheme.button("Fortify [F]", func(): main.cmd_unit("fortify")))
	else:
		unit_actions.add_child(UiTheme.button("Sleep", func(): main.cmd_unit("sleep")))
	if u.fortified or u.sleeping:
		unit_actions.add_child(UiTheme.button("Wake", func(): main.cmd_unit("wake")))
	if u.goto.x >= 0 or u.build_kind != "":
		unit_actions.add_child(UiTheme.button("Cancel", func(): main.cmd_unit("cancel")))
	unit_actions.add_child(UiTheme.button("Skip [Space]", func(): main.cmd_unit("skip")))
	unit_actions.add_child(UiTheme.button("Disband", func(): main.cmd_unit("disband")))

func _tile_desc(c: Vector2i) -> String:
	var i := game.idx(c)
	var parts := [Defs.TERRAIN[game.terrain[i]].name]
	if game.hills[i] == 1: parts.append("Hills")
	if game.forest[i] == 1: parts.append("Forest")
	if game.resource[i] != "": parts.append(Defs.RESOURCES[game.resource[i]].name)
	if game.improvement[i] != "": parts.append(Defs.IMPROVEMENTS[game.improvement[i]].name)
	var y := game.tile_yield(c)
	return "%s  ·  %d food  %d prod  %d gold" % [", ".join(parts), y.x, y.y, y.z]

# ---------------------------------------------------------------- city panel

func _build_city_panel() -> void:
	city_panel = PanelContainer.new()
	city_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	city_panel.offset_right = -12
	city_panel.offset_left = -360
	city_panel.offset_top = 70
	city_panel.offset_bottom = -260
	root.add_child(city_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	city_panel.add_child(scroll)
	city_body = VBoxContainer.new()
	city_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	city_body.add_theme_constant_override("separation", 6)
	scroll.add_child(city_body)
	city_panel.visible = false

func show_city(c) -> void:
	unit_panel.visible = false
	if c == null:
		city_panel.visible = false
		return
	city_panel.visible = true
	for ch in city_body.get_children():
		ch.queue_free()
	var mine: bool = c.owner == pid
	var title := UiTheme.label(("★ " if c.capital else "") + c.name, 22, game.player(c.owner).color.lightened(0.3))
	city_body.add_child(title)
	city_body.add_child(UiTheme.label("%s · Population %d · HP %d/%d · Strength %d" % [game.player(c.owner).civ_name(), c.pop, c.hp, c.max_hp(), int(game.city_strength(c))], 13, UiTheme.MUTED))
	if not mine:
		return
	var y := game.city_yields(c)
	var yl := RichTextLabel.new()
	yl.bbcode_enabled = true
	yl.fit_content = true
	yl.scroll_active = false
	yl.text = "[color=#8fe388]Food %d (%+d)[/color]   [color=#ffa45c]Prod %d[/color]   [color=#ffd166]Gold %d[/color]   [color=#6fc3ff]Sci %d[/color]" % [y.food, y.surplus, y.prod, y.gold, y.sci]
	city_body.add_child(yl)
	var grow := UiTheme.bar(UiTheme.FOOD, 6)
	grow.max_value = c.growth_threshold()
	grow.value = c.food
	city_body.add_child(grow)
	var gt := "Stagnant" if y.surplus == 0 else ("Starving!" if y.surplus < 0 else "Grows in %d turns" % ceili(float(c.growth_threshold() - c.food) / y.surplus))
	city_body.add_child(UiTheme.label(gt, 12, UiTheme.MUTED))
	city_body.add_child(HSeparator.new())
	city_body.add_child(UiTheme.label("Production", 16, UiTheme.ACCENT))
	if c.production != "":
		var cost := Defs.item_cost(c.production)
		var row := UiTheme.label("%s%s" % [Defs.item_name(c.production), ("  —  %d turns" % game.turns_to_build(c)) if cost > 0 else ""], 15)
		city_body.add_child(row)
		if cost > 0:
			var pb := UiTheme.bar(UiTheme.PROD, 6)
			pb.max_value = cost
			pb.value = c.prod
			city_body.add_child(pb)
		var bc := game.buy_cost(c)
		if bc > 0:
			var bb := UiTheme.button("Buy for %d ◎" % bc, func(): main.cmd_city("buy", c.id))
			bb.disabled = game.player(pid).gold < bc
			city_body.add_child(bb)
	else:
		city_body.add_child(UiTheme.label("Nothing — choose below", 14, Color("ff8a6b")))
	city_body.add_child(HSeparator.new())
	var prodv: int = maxi(1, y.prod)
	for item in game.buildable_items(c):
		var cost := Defs.item_cost(item)
		var txt := Defs.item_name(item)
		if cost > 0:
			txt += "   %d⚙ · %dt" % [cost, maxi(1, ceili(float(cost) / prodv))]
		var it: String = item
		var b := UiTheme.button(txt, func(): main.cmd_city("prod", c.id, it), 14)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if item == c.production:
			b.add_theme_color_override("font_color", UiTheme.ACCENT)
		if Defs.UNITS.has(item):
			var ud: Dictionary = Defs.UNITS[item]
			b.tooltip_text = "Strength %d%s · Moves %d" % [ud.str, (" · Ranged %d" % ud.rstr) if ud.rstr > 0 else "", ud.moves]
		elif Defs.BUILDINGS.has(item):
			b.tooltip_text = Defs.BUILDINGS[item].desc
		else:
			b.tooltip_text = Defs.PROJECTS[item].desc
		city_body.add_child(b)
	if not c.buildings.is_empty():
		city_body.add_child(HSeparator.new())
		var names := []
		for bname in c.buildings:
			names.append(Defs.BUILDINGS[bname].name)
		var bl := UiTheme.label("Buildings: " + ", ".join(names), 13, UiTheme.MUTED)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		city_body.add_child(bl)

# ---------------------------------------------------------------- end turn + minimap

func _build_bottom_right() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	box.offset_right = -12
	box.offset_bottom = -12
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.add_theme_constant_override("separation", 8)
	root.add_child(box)
	var mp := PanelContainer.new()
	box.add_child(mp)
	minimap = TextureRect.new()
	minimap.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	minimap.stretch_mode = TextureRect.STRETCH_SCALE
	minimap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var aspect := float(game.h * 1.5) / (game.w * 1.732)
	minimap.custom_minimum_size = Vector2(300, 300 * aspect)
	minimap.gui_input.connect(_on_minimap_input)
	mp.add_child(minimap)
	minimap_img = Image.create(game.w * 2 + 1, game.h, false, Image.FORMAT_RGBA8)
	minimap_tex = ImageTexture.create_from_image(minimap_img)
	minimap.texture = minimap_tex
	end_btn = Button.new()
	end_btn.custom_minimum_size = Vector2(300, 64)
	end_btn.add_theme_font_size_override("font_size", 20)
	var s := UiTheme.sb(Color(UiTheme.ACCENT, 0.9), 12, Color(1, 1, 1, 0.3), 1, 14)
	end_btn.add_theme_stylebox_override("normal", s)
	var sh := UiTheme.sb(UiTheme.ACCENT.lightened(0.15), 12, Color(1, 1, 1, 0.5), 1, 14)
	end_btn.add_theme_stylebox_override("hover", sh)
	end_btn.add_theme_stylebox_override("pressed", sh)
	end_btn.add_theme_color_override("font_color", Color(0.08, 0.08, 0.1))
	end_btn.add_theme_color_override("font_hover_color", Color(0.08, 0.08, 0.1))
	end_btn.pressed.connect(func(): main.end_turn_pressed(false))
	box.add_child(end_btn)
	end_sub = UiTheme.label("", 12, UiTheme.MUTED)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(end_sub)

func _on_minimap_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		var f: Vector2 = ev.position / minimap.size
		main.camera.look_at_tile(Vector2i(int(f.x * game.w), int(f.y * game.h)))

func update_minimap(view: WorldView) -> void:
	minimap_img.fill(Color(0.03, 0.04, 0.06, 1))
	for y in game.h:
		for x in game.w:
			var c := Vector2i(x, y)
			if not view.is_explored(c):
				continue
			var i := game.idx(c)
			var col: Color = Defs.TERRAIN[game.terrain[i]].color
			if game.forest[i] == 1:
				col = col.darkened(0.25)
			var o: int = game.tile_owner[i]
			if o >= 0:
				col = col.lerp(game.player(o).color, 0.45)
			if game.city_at.has(c):
				col = game.player(game.city_at[c].owner).color.lightened(0.5)
			if not view.is_visible_tile(c):
				col = col.darkened(0.45)
			var px := x * 2 + (y & 1)
			minimap_img.set_pixel(px, y, col)
			minimap_img.set_pixel(px + 1, y, col)
	minimap_tex.update(minimap_img)

func set_end_button(text: String, sub: String, waiting: bool) -> void:
	end_btn.text = text
	end_sub.text = sub
	end_btn.modulate = Color(0.75, 0.8, 0.9) if waiting else Color.WHITE

# ---------------------------------------------------------------- notifications / tooltip / chat

func _build_notes() -> void:
	notes = VBoxContainer.new()
	notes.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notes.offset_left = 12
	notes.offset_top = 70
	notes.custom_minimum_size = Vector2(340, 0)
	notes.add_theme_constant_override("separation", 6)
	notes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes)

func _on_notify(target: int, text: String, pos: Vector2i) -> void:
	if target != -1 and target != pid:
		return
	toast(text, pos)

func toast(text: String, pos := Vector2i(-1, -1)) -> void:
	var pc := PanelContainer.new()
	var s := UiTheme.sb(Color(0.07, 0.09, 0.13, 0.92), 10, Color(UiTheme.ACCENT, 0.35), 1, 10)
	pc.add_theme_stylebox_override("panel", s)
	var b := Button.new()
	b.flat = true
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(320, 0)
	b.add_theme_font_size_override("font_size", 14)
	if pos.x >= 0:
		b.pressed.connect(func(): main.camera.look_at_tile(pos))
	pc.add_child(b)
	notes.add_child(pc)
	notes.move_child(pc, 0)
	while notes.get_child_count() > 6:
		var last := notes.get_child(notes.get_child_count() - 1)
		notes.remove_child(last)
		last.queue_free()
	var tw := pc.create_tween()
	pc.modulate.a = 0.0
	tw.tween_property(pc, "modulate:a", 1.0, 0.25)
	tw.tween_interval(7.0)
	tw.tween_property(pc, "modulate:a", 0.0, 0.8)
	tw.tween_callback(pc.queue_free)

func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_lbl = RichTextLabel.new()
	tooltip_lbl.bbcode_enabled = true
	tooltip_lbl.fit_content = true
	tooltip_lbl.scroll_active = false
	tooltip_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	tooltip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tooltip_lbl)
	root.add_child(tooltip)
	tooltip.visible = false

func show_tooltip(text: String, at: Vector2) -> void:
	if text == "":
		tooltip.visible = false
		return
	tooltip_lbl.text = text
	tooltip.visible = true
	tooltip.reset_size()
	var vs := root.get_viewport_rect().size
	var p := at + Vector2(18, 18)
	p.x = minf(p.x, vs.x - tooltip.size.x - 8)
	p.y = minf(p.y, vs.y - tooltip.size.y - 8)
	tooltip.position = p

func _build_chat() -> void:
	chat_edit = LineEdit.new()
	chat_edit.placeholder_text = "Press Enter to chat…"
	chat_edit.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	chat_edit.offset_left = -200
	chat_edit.offset_right = 200
	chat_edit.offset_top = -46
	chat_edit.offset_bottom = -12
	chat_edit.visible = Net.online
	chat_edit.modulate.a = 0.75
	chat_edit.text_submitted.connect(func(t: String):
		if t.strip_edges() != "":
			Net.send({"t": "chat", "text": t})
		chat_edit.text = ""
		chat_edit.release_focus())
	root.add_child(chat_edit)

# ---------------------------------------------------------------- tech tree

func _build_tech_tree() -> void:
	tech_overlay = Control.new()
	tech_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_overlay.visible = false
	root.add_child(tech_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tech_overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 60
	panel.offset_bottom = -40
	tech_overlay.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	hb.add_child(UiTheme.label("Technology", 26, UiTheme.SCIENCE))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(UiTheme.button("Close  [T]", toggle_tech_tree))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	tech_canvas = Control.new()
	tech_canvas.custom_minimum_size = Vector2(11 * 210 + 40, 5 * 110 + 40)
	tech_canvas.draw.connect(_draw_tech_lines)
	scroll.add_child(tech_canvas)

func toggle_tech_tree() -> void:
	tech_overlay.visible = not tech_overlay.visible
	if tech_overlay.visible:
		_rebuild_tech_buttons()

func _tech_rect(id: String) -> Rect2:
	var t: Dictionary = Defs.TECHS[id]
	return Rect2(Vector2(20 + t.col * 210, 20 + t.row * 110), Vector2(180, 78))

func _rebuild_tech_buttons() -> void:
	for ch in tech_canvas.get_children():
		ch.queue_free()
	var p := game.player(pid)
	var avail := game.available_techs(pid)
	var sci: int = game.income(pid).sci
	for id in Defs.TECHS:
		var t: Dictionary = Defs.TECHS[id]
		var r := _tech_rect(id)
		var b := Button.new()
		b.position = r.position
		b.size = r.size
		b.clip_text = true
		var known := p.techs.has(id)
		var can := avail.has(id)
		var col := Color("2e6b45") if known else (Color("2c5c86") if can else Color("1d222b"))
		if id == p.research:
			col = Color("8a6a1f")
		var s := UiTheme.sb(Color(col, 0.9), 10, Color(1, 1, 1, 0.15), 1, 8)
		s.shadow_size = 0
		b.add_theme_stylebox_override("normal", s)
		var sh := s.duplicate()
		sh.bg_color = col.lightened(0.15)
		b.add_theme_stylebox_override("hover", sh)
		b.add_theme_stylebox_override("pressed", sh)
		b.add_theme_stylebox_override("disabled", s)
		var unl := Defs.tech_unlocks(id)
		var turns := "" if known else ("  ·  %dt" % maxi(1, ceili(float(t.cost - (p.science if can else 0)) / sci)))
		b.text = "%s%s\n%s" % [t.name, turns, ", ".join(unl).left(34)]
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_disabled_color", Color(0.85, 0.9, 0.95) if known else UiTheme.MUTED)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.tooltip_text = "%s — %d science\nUnlocks: %s" % [t.name, t.cost, ", ".join(unl)]
		b.disabled = not can
		var tid: String = id
		b.pressed.connect(func():
			Net.send({"t": "research", "tech": tid})
			tech_overlay.visible = false)
		tech_canvas.add_child(b)
	tech_canvas.queue_redraw()

func _draw_tech_lines() -> void:
	var p := game.player(pid)
	for id in Defs.TECHS:
		var r := _tech_rect(id)
		for pre in Defs.TECHS[id].pre:
			var pr := _tech_rect(pre)
			var a := pr.position + Vector2(pr.size.x, pr.size.y * 0.5)
			var b := r.position + Vector2(0, r.size.y * 0.5)
			var col := Color(0.4, 0.85, 0.55, 0.8) if p.techs.has(pre) else Color(1, 1, 1, 0.18)
			var mid := (a.x + b.x) * 0.5
			tech_canvas.draw_polyline(PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b]), col, 2.0, true)

# ---------------------------------------------------------------- refresh

func refresh() -> void:
	var p := game.player(pid)
	top_civ.text = "%s  ·  %s" % [p.civ_name(), p.name]
	top_civ.add_theme_color_override("font_color", p.color.lightened(0.3))
	top_turn.text = "Turn %d  ·  %s" % [game.turn, _year(game.turn)]
	var inc := game.income(pid)
	top_gold.text = "◎ %d (%+d)" % [p.gold, inc.gold]
	top_gold.tooltip_text = "Gold. Unit upkeep: %d/turn" % inc.upkeep
	top_sci.text = "⚗ +%d" % inc.sci
	if p.research != "":
		var t: Dictionary = Defs.TECHS[p.research]
		research_btn.text = "%s  ·  %d turns" % [t.name, maxi(1, ceili(float(t.cost - p.science) / inc.sci))]
		research_bar.max_value = t.cost
		research_bar.value = p.science
	else:
		research_btn.text = "⚠ Choose research  [T]" if not game.available_techs(pid).is_empty() else "All technologies researched"
		research_bar.value = 0
	for ch in players_box.get_children():
		ch.queue_free()
	for pl in game.players:
		players_box.add_child(_player_chip(pl))
	if tech_overlay.visible:
		_rebuild_tech_buttons()

func _year(t: int) -> String:
	var y := -4000 + (t - 1) * 40
	if t > 75: y = -1000 + (t - 75) * 25
	if t > 135: y = 500 + (t - 135) * 10
	if t > 210: y = 1250 + (t - 210) * 5
	if t > 260: y = 1500 + (t - 260) * 10
	return "%d %s" % [absi(y), "BC" if y < 0 else "AD"]

func show_game_over(winner: int, kind: String) -> void:
	if over_overlay:
		return
	over_overlay = PanelContainer.new()
	over_overlay.set_anchors_preset(Control.PRESET_CENTER)
	over_overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(over_overlay)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	vb.custom_minimum_size = Vector2(460, 0)
	over_overlay.add_child(vb)
	var won := winner == pid
	var head := UiTheme.label("VICTORY" if won else "DEFEAT", 44, UiTheme.ACCENT if won else Color("ff6b5b"))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	var msg := "No one survived."
	if winner >= 0:
		msg = "%s wins a %s victory on turn %d." % [game.player(winner).civ_name(), kind, game.turn]
	var l := UiTheme.label(msg, 17)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var scores := []
	for p in game.players:
		scores.append([game.score(p.id), p.civ_name()])
	scores.sort_custom(func(a, b): return a[0] > b[0])
	for s in scores:
		var sl := UiTheme.label("%s — %d" % [s[1], s[0]], 14, UiTheme.MUTED)
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(sl)
	vb.add_child(UiTheme.button("Keep watching", func(): over_overlay.visible = false))
	vb.add_child(UiTheme.button("Back to menu", func(): main.leave_game()))
