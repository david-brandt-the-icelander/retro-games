extends CanvasLayer
## Dieselpunk HUD: resource bar, minimap, selection panel, command card, help and end screens.

const Minimap := preload("res://scripts/minimap.gd")
const Overlay := preload("res://scripts/overlay.gd")

const GOLD := Color(0.95, 0.76, 0.40)
const CREAM := Color(0.94, 0.88, 0.74)
const DIM := Color(0.64, 0.57, 0.46)
const BRASS := Color(0.72, 0.55, 0.27)
const HOTKEYS := ["Z", "X", "C", "V", "B"]

var root: Control
var fuel_label: Label
var income_label: Label
var army_label: Label
var time_label: Label
var info_title: Label
var info_hp: ProgressBar
var info_hp_label: Label
var info_body: Label
var info_queue: ProgressBar
var cmd_title: Label
var cmd_grid: GridContainer
var message_label: Label
var help_panel: PanelContainer
var end_panel: PanelContainer
var end_title: Label
var end_sub: Label
var title_box: VBoxContainer
var msg_time := 0.0
var signature := ""
var cmd_buttons: Array = []
var hotkey_actions: Array = []
var refresh_t := 0.0


func _ready() -> void:
	layer = 10
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	var overlay := Overlay.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	_build_top_bar()
	_build_minimap()
	_build_info()
	_build_commands()
	_build_message()
	_build_help()
	_build_end()
	_build_title()
	Game.notified.connect(_on_notify)
	Game.game_ended.connect(_on_game_ended)


# ================================================================ theme

func _panel_style(bg: Color, border: Color, bw: int, radius: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.anti_aliasing = true
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "DIN Alternate", "Oswald", "Roboto Condensed",
		"Arial Narrow", "DejaVu Sans Condensed", "Liberation Sans Narrow"])
	font.font_weight = 600
	t.default_font = font
	t.default_font_size = 15
	var panel := _panel_style(Color(0.075, 0.066, 0.058, 0.93), BRASS, 2, 4, 10.0)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	var bn := _panel_style(Color(0.16, 0.13, 0.095), Color(0.50, 0.38, 0.19), 2, 3, 6.0)
	bn.shadow_size = 2
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.27, 0.21, 0.12)
	bh.border_color = Color(0.98, 0.78, 0.40)
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = Color(0.40, 0.29, 0.13)
	bp.border_color = Color(1.0, 0.86, 0.5)
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.10, 0.09, 0.08)
	bd.border_color = Color(0.28, 0.24, 0.18)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", CREAM)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.92, 0.7))
	t.set_color("font_pressed_color", "Button", Color(1.0, 0.95, 0.8))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.4, 0.33))
	t.set_font_size("font_size", "Button", 13)
	t.set_color("font_color", "Label", CREAM)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.85))
	var pb_bg := _panel_style(Color(0.04, 0.035, 0.03), Color(0.35, 0.27, 0.14), 1, 2, 0.0)
	pb_bg.shadow_size = 0
	var pb_fill := _panel_style(Color(0.85, 0.64, 0.28), Color(0, 0, 0, 0), 0, 2, 0.0)
	pb_fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	var tip := _panel_style(Color(0.07, 0.06, 0.05, 0.97), BRASS, 1, 3, 8.0)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	t.set_font_size("font_size", "TooltipLabel", 13)
	return t


func _label(text: String, size: int, color: Color = CREAM) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _place(c: Control, anchors: Rect2, offsets: Rect2) -> void:
	c.anchor_left = anchors.position.x
	c.anchor_top = anchors.position.y
	c.anchor_right = anchors.size.x
	c.anchor_bottom = anchors.size.y
	c.offset_left = offsets.position.x
	c.offset_top = offsets.position.y
	c.offset_right = offsets.size.x
	c.offset_bottom = offsets.size.y


# ================================================================ layout

func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	_place(bar, Rect2(0, 0, 1, 0), Rect2(10, 8, -10, 52))
	root.add_child(bar)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 26)
	bar.add_child(hb)
	var title := _label("IRON HAZE", 22, GOLD)
	hb.add_child(title)
	hb.add_child(_label("BRASS COALITION COMMAND", 12, DIM))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	fuel_label = _label("FUEL 0", 19, GOLD)
	hb.add_child(fuel_label)
	income_label = _label("+0/s", 15, Color(0.6, 0.9, 0.55))
	hb.add_child(income_label)
	army_label = _label("FORCES 0", 15)
	hb.add_child(army_label)
	time_label = _label("00:00", 15, DIM)
	hb.add_child(time_label)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp2)
	hb.add_child(_label("F1 or ?  CONTROLS", 12, DIM))
	for c in hb.get_children():
		if c is Label:
			c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			c.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _build_minimap() -> void:
	var p := PanelContainer.new()
	_place(p, Rect2(0, 1, 0, 1), Rect2(12, -236, 236, -12))
	p.add_theme_stylebox_override("panel", _panel_style(Color(0.075, 0.066, 0.058, 0.93), BRASS, 2, 4, 10.0))
	root.add_child(p)
	var mm := Minimap.new()
	p.add_child(mm)


func _build_info() -> void:
	var p := PanelContainer.new()
	_place(p, Rect2(0.5, 1, 0.5, 1), Rect2(-270, -184, 250, -12))
	root.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	info_title = _label("NO SELECTION", 20, GOLD)
	vb.add_child(info_title)
	var hb := HBoxContainer.new()
	vb.add_child(hb)
	info_hp = ProgressBar.new()
	info_hp.show_percentage = false
	info_hp.custom_minimum_size = Vector2(0, 14)
	info_hp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_hp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(info_hp)
	info_hp_label = _label("", 13, DIM)
	info_hp_label.custom_minimum_size = Vector2(90, 0)
	info_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hb.add_child(info_hp_label)
	info_body = _label("", 14)
	info_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(info_body)
	info_queue = ProgressBar.new()
	info_queue.show_percentage = false
	info_queue.custom_minimum_size = Vector2(0, 8)
	vb.add_child(info_queue)


func _build_commands() -> void:
	var p := PanelContainer.new()
	_place(p, Rect2(1, 1, 1, 1), Rect2(-398, -212, -12, -12))
	root.add_child(p)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	p.add_child(vb)
	cmd_title = _label("COMMANDS", 12, DIM)
	vb.add_child(cmd_title)
	cmd_grid = GridContainer.new()
	cmd_grid.columns = 3
	cmd_grid.add_theme_constant_override("h_separation", 6)
	cmd_grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(cmd_grid)


func _build_message() -> void:
	message_label = _label("", 20, GOLD)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_constant_override("outline_size", 6)
	message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(message_label, Rect2(0.5, 0, 0.5, 0), Rect2(-420, 66, 420, 100))
	root.add_child(message_label)


func _build_help() -> void:
	help_panel = PanelContainer.new()
	_place(help_panel, Rect2(0.5, 0.5, 0.5, 0.5), Rect2(-330, -260, 330, 230))
	help_panel.visible = false
	root.add_child(help_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	help_panel.add_child(vb)
	vb.add_child(_label("FIELD MANUAL", 24, GOLD))
	var body := _label("", 14)
	body.text = """CAMERA   Arrow keys / screen edge to pan · Mouse wheel to zoom
         Q / E or middle-drag to rotate · H: headquarters · Space: selection

SELECT   Left-click or drag a box · Shift adds · Double-click selects a type
         Ctrl+A: all combat units · Ctrl+0-9 assigns a group, 0-9 recalls

ORDERS   Right-click ground: move · Right-click enemy: attack
         A then click: attack-move · S: stop · Esc: cancel
         Right-click with a structure selected sets its rally point

BUILD    Select a Constructor, pick a structure (Z X C V B), click to place
         Shift-click to keep placing · Right-click a damaged structure to repair
         Pump Jacks must sit on oil wells — they are your fuel supply

ARMY     Troopers beat infantry and can shoot airships
         Ironclads beat vehicles · Howitzers shell bases from long range
         Zeppelins bomb everything below — counter them with Flak Towers

F2 toggles volumetric fog / SSAO for performance (desktop build).
Destroy every Iron Dominion structure to win."""
	vb.add_child(body)
	var close := Button.new()
	close.text = "Close (F1 / ?)"
	close.custom_minimum_size = Vector2(140, 34)
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	close.pressed.connect(toggle_help)
	vb.add_child(close)


func _build_end() -> void:
	end_panel = PanelContainer.new()
	_place(end_panel, Rect2(0.5, 0.5, 0.5, 0.5), Rect2(-260, -120, 260, 120))
	end_panel.visible = false
	root.add_child(end_panel)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 12)
	end_panel.add_child(vb)
	end_title = _label("VICTORY", 48, GOLD)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_title)
	end_sub = _label("", 15)
	end_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(end_sub)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 12)
	vb.add_child(hb)
	var again := Button.new()
	again.text = "New Battle"
	again.custom_minimum_size = Vector2(150, 40)
	again.pressed.connect(func(): get_tree().reload_current_scene())
	hb.add_child(again)
	var quit := Button.new()
	quit.text = "Quit"
	quit.custom_minimum_size = Vector2(110, 40)
	quit.pressed.connect(func(): get_tree().quit())
	quit.visible = not OS.has_feature("web")
	hb.add_child(quit)


func _build_title() -> void:
	title_box = VBoxContainer.new()
	title_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(title_box, Rect2(0.5, 0.3, 0.5, 0.3), Rect2(-500, -60, 500, 80))
	root.add_child(title_box)
	var t := _label("IRON HAZE", 72, GOLD)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_constant_override("outline_size", 10)
	title_box.add_child(t)
	var s := _label("Pump the oil. Build the machines. Break the Iron Dominion.", 18)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.add_theme_constant_override("outline_size", 6)
	title_box.add_child(s)
	var s2 := _label("Press F1 or ? for the field manual", 14, DIM)
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s2.add_theme_constant_override("outline_size", 5)
	title_box.add_child(s2)
	var tw := title_box.create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(title_box, "modulate:a", 0.0, 1.5)
	tw.tween_callback(title_box.hide)


# ================================================================ updates

func _process(delta: float) -> void:
	var f: float = Game.fuel[Game.PLAYER]
	fuel_label.text = "FUEL  %d" % int(f)
	income_label.text = "+%d/s" % int(Game.income_of(Game.PLAYER))
	var army := 0
	for e in Game.entities:
		if e.team == Game.PLAYER and not e.is_building:
			army += 1
	army_label.text = "FORCES  %d" % army
	var secs := int(Game.elapsed)
	time_label.text = "%02d:%02d" % [secs / 60, secs % 60]
	refresh_t -= delta
	if refresh_t <= 0.0:
		refresh_t = 0.1
		_refresh()
	if msg_time > 0.0:
		msg_time -= delta
		message_label.modulate.a = clampf(msg_time, 0.0, 1.0)


func _on_notify(text: String) -> void:
	message_label.text = text
	msg_time = 3.0
	message_label.modulate.a = 1.0


func _on_game_ended(winner: int) -> void:
	end_panel.visible = true
	var secs := int(Game.elapsed)
	if winner == Game.PLAYER:
		end_title.text = "VICTORY"
		end_title.add_theme_color_override("font_color", GOLD)
		end_sub.text = "The Iron Dominion has fallen after %d:%02d of fighting." % [secs / 60, secs % 60]
	else:
		end_title.text = "DEFEAT"
		end_title.add_theme_color_override("font_color", Color(1.0, 0.35, 0.28))
		end_sub.text = "Your last structure has been reduced to rubble."


func toggle_help() -> void:
	help_panel.visible = not help_panel.visible


func trigger_hotkey(i: int) -> void:
	if i >= 0 and i < hotkey_actions.size():
		_on_action(hotkey_actions[i])


func _selection() -> Array:
	return Game.world.controller.selection


func _signature(sel: Array) -> String:
	var parts := []
	for e in sel:
		if Game.alive(e):
			parts.append("%d:%s" % [e.get_instance_id(), str(e.complete) if e.is_building else ""])
	return ",".join(parts)


func _refresh() -> void:
	var sel := _selection()
	var sig := _signature(sel)
	if sig != signature:
		signature = sig
		_rebuild_commands(sel)
	_update_info(sel)
	_update_buttons()


func _rebuild_commands(sel: Array) -> void:
	for c in cmd_grid.get_children():
		c.queue_free()
	cmd_buttons.clear()
	hotkey_actions.clear()
	cmd_title.text = "COMMANDS"
	var live := sel.filter(func(e): return Game.alive(e))
	if live.is_empty():
		return
	var first = live[0]
	if first.team != Game.PLAYER:
		cmd_title.text = "ENEMY — " + String(first.display_name()).to_upper()
		return
	if live.size() == 1 and first.is_building:
		cmd_title.text = String(first.display_name()).to_upper()
		if not first.complete:
			cmd_title.text += " — UNDER CONSTRUCTION"
			return
		for k in first.produces():
			var ud: Dictionary = Game.UNITS[k]
			_add_button({"type": "train", "kind": k, "building": first},
				"%s\nBuild time %ds · Right-click to cancel" % [ud["desc"], int(ud["time"])])
		return
	var has_con := false
	for e in live:
		if e.kind == "constructor":
			has_con = true
	if has_con:
		cmd_title.text = "CONSTRUCTION"
		for k in Game.BUILD_MENU:
			var bd: Dictionary = Game.BUILDINGS[k]
			_add_button({"type": "build", "kind": k}, "%s\nHP %d" % [bd["desc"], bd["hp"]])
	_add_button({"type": "amove"}, "Move, engaging any enemy met on the way.")
	_add_button({"type": "stop"}, "Halt and hold position.")


func _add_button(action: Dictionary, tip: String) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(120, 52)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_on_action.bind(action))
	b.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_RIGHT:
			_on_cancel(action))
	cmd_grid.add_child(b)
	if action["type"] == "train" or action["type"] == "build":
		action["hotkey"] = HOTKEYS[hotkey_actions.size()] if hotkey_actions.size() < HOTKEYS.size() else ""
		hotkey_actions.append(action)
	cmd_buttons.append({"button": b, "action": action})


func _update_buttons() -> void:
	var fuel: float = Game.fuel[Game.PLAYER]
	for entry in cmd_buttons:
		var b: Button = entry["button"]
		var a: Dictionary = entry["action"]
		match a["type"]:
			"train":
				var ud: Dictionary = Game.UNITS[a["kind"]]
				var n := 0
				if Game.alive(a["building"]):
					n = a["building"].queued(a["kind"])
				var q := "  ×%d" % n if n > 0 else ""
				b.text = "%s%s\n%d fuel  [%s]" % [ud["name"], q, ud["cost"], a["hotkey"]]
				b.disabled = fuel < float(ud["cost"])
			"build":
				var bd: Dictionary = Game.BUILDINGS[a["kind"]]
				b.text = "%s\n%d fuel  [%s]" % [bd["name"], bd["cost"], a["hotkey"]]
				b.disabled = fuel < float(bd["cost"])
			"amove":
				b.text = "Attack-Move\n[A]"
			"stop":
				b.text = "Stop\n[S]"


func _on_action(a: Dictionary) -> void:
	var ctrl = Game.world.controller
	match a["type"]:
		"train":
			if Game.alive(a["building"]):
				a["building"].enqueue(a["kind"])
		"build":
			ctrl.begin_placement(a["kind"])
		"amove":
			ctrl.arm_attack_move()
		"stop":
			ctrl.stop_selected()


func _on_cancel(a: Dictionary) -> void:
	if a["type"] == "train" and Game.alive(a["building"]):
		a["building"].cancel_last()


func _update_info(sel: Array) -> void:
	var live := sel.filter(func(e): return Game.alive(e))
	info_queue.visible = false
	if live.is_empty():
		info_title.text = "NO SELECTION"
		info_hp.visible = false
		info_hp_label.text = ""
		info_body.text = "Drag a box or click to select. Right-click to issue orders.\nSelect your Constructor to raise new structures."
		return
	info_hp.visible = true
	if live.size() == 1:
		var e = live[0]
		var title := String(e.display_name()).to_upper()
		if e.team != Game.PLAYER:
			title += "  (ENEMY)"
		info_title.text = title
		info_hp.max_value = e.max_hp
		info_hp.value = e.hp
		info_hp_label.text = "%d / %d" % [int(e.hp), int(e.max_hp)]
		var d: Dictionary = e.def
		var lines := []
		if e.is_building:
			if not e.complete:
				lines.append("Under construction: %d%%" % int(e.progress * 100.0))
				lines.append("Right-click it with a Constructor selected to assist.")
			else:
				lines.append(String(d.get("desc", "")))
				if d.has("income"):
					lines.append("Income: +%d fuel/s" % int(d["income"]))
				if not e.queue.is_empty():
					var names := []
					for k in e.queue:
						names.append(String(Game.UNITS[k]["name"]))
					lines.append("Producing: " + ", ".join(names))
					info_queue.visible = true
					info_queue.max_value = 1.0
					info_queue.value = e.production_ratio()
				if d.has("weapon"):
					lines.append("Range %d · Damage %d" % [int(d["range"]), int(d["damage"])])
		else:
			lines.append(String(d.get("desc", "")))
			if d.has("weapon"):
				lines.append("Damage %d · Range %d · Speed %.1f" % [int(d["damage"]), int(d["range"]), float(d["speed"])])
			lines.append("Status: " + e.state_text())
		info_body.text = "\n".join(lines)
		return
	var counts := {}
	var hp := 0.0
	var mhp := 0.0
	for e in live:
		var nm := String(e.display_name())
		counts[nm] = int(counts.get(nm, 0)) + 1
		hp += e.hp
		mhp += e.max_hp
	info_title.text = "%d UNITS SELECTED" % live.size()
	info_hp.max_value = mhp
	info_hp.value = hp
	info_hp_label.text = "%d%%" % int(100.0 * hp / maxf(mhp, 1.0))
	var lines2 := []
	for k in counts:
		lines2.append("%d × %s" % [counts[k], k])
	info_body.text = "\n".join(lines2)
