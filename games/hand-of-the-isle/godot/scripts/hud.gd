class_name Hud
extends CanvasLayer
## All interface, built in code: faith, population balance, power bar,
## behaviour switch, notifications, and the title / help / end screens.

signal power_chosen(i: int)
signal behavior_chosen(b: int)
signal start_requested(level: int)
signal restart_requested

const ACCENT := Color(1.0, 0.8, 0.38)
const PANEL := Color(0.05, 0.07, 0.11, 0.84)
const KEYS := ["1", "2", "3", "4", "5", "6", "7", "8"]
const BEHAVIORS := [["Settle", "Z", "Walkers seek flat land and build homes"],
	["Gather", "X", "Walkers march to your beacon and merge"],
	["Crusade", "C", "Walkers hunt the rival's people and homes"]]

var root := Control.new()
var _faith_bar := ProgressBar.new()
var _faith_lbl := Label.new()
var _rival_bar := ProgressBar.new()
var _you_bar := ColorRect.new()
var _rival_rect := ColorRect.new()
var _you_lbl := Label.new()
var _rival_lbl := Label.new()
var _info_lbl := Label.new()
var _desc := Label.new()
var _power_btns: Array[Button] = []
var _beh_btns: Array[Button] = []
var _toasts := VBoxContainer.new()
var _title := Control.new()
var _end := Control.new()
var _end_head := Label.new()
var _end_body := Label.new()
var _help := Control.new()
var _selected := 0
var _frame: MarginContainer


func _ready() -> void:
	layer = 5
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)
	var frame := MarginContainer.new()
	_frame = frame
	frame.visible = false
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		frame.add_theme_constant_override("margin_" + side, 16)
	root.add_child(_ignore(frame))
	var col := VBoxContainer.new()
	frame.add_child(_ignore(col))
	col.add_child(_build_top())
	_toasts.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toasts.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_ignore(_toasts))
	col.add_child(_build_bottom())
	_build_title()
	_build_end()
	_build_help()


# ------------------------------------------------------------------- theme
static func panel_box(col := PANEL, radius := 14) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	return sb


func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 15
	th.set_stylebox("panel", "PanelContainer", panel_box())
	var normal := panel_box(Color(0.12, 0.15, 0.22, 0.95), 10)
	normal.set_content_margin_all(8)
	normal.shadow_size = 0
	var hover := normal.duplicate()
	hover.bg_color = Color(0.19, 0.23, 0.33)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(0.32, 0.25, 0.1)
	pressed.border_color = ACCENT
	pressed.set_border_width_all(2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.09, 0.1, 0.13, 0.9)
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", hover)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("hover_pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color(0.9, 0.92, 0.96))
	th.set_color("font_pressed_color", "Button", ACCENT)
	th.set_color("font_hover_pressed_color", "Button", ACCENT)
	th.set_color("font_color", "Label", Color(0.9, 0.92, 0.96))
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(1, 1, 1, 0.08)
	bg.set_corner_radius_all(6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = ACCENT
	fill.set_corner_radius_all(6)
	th.set_stylebox("background", "ProgressBar", bg)
	th.set_stylebox("fill", "ProgressBar", fill)
	return th


func _label(text: String, size := 15, col := Color(0.9, 0.92, 0.96)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _ignore(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return _ignore(c)


# ---------------------------------------------------------------- top bar
func _build_top() -> Control:
	var row := HBoxContainer.new()
	_ignore(row)
	row.add_theme_constant_override("separation", 14)

	var faith := PanelContainer.new()
	faith.custom_minimum_size = Vector2(300, 0)
	var fv := VBoxContainer.new()
	faith.add_child(fv)
	var fh := HBoxContainer.new()
	fh.add_child(_label("FAITH", 13, ACCENT))
	fh.add_child(_spacer())
	_faith_lbl.add_theme_font_size_override("font_size", 20)
	fh.add_child(_faith_lbl)
	fv.add_child(fh)
	_faith_bar.max_value = World.MANA_MAX
	_faith_bar.show_percentage = false
	_faith_bar.custom_minimum_size = Vector2(0, 12)
	fv.add_child(_faith_bar)
	row.add_child(faith)

	row.add_child(_spacer())

	var bal := PanelContainer.new()
	bal.custom_minimum_size = Vector2(420, 0)
	var bv := VBoxContainer.new()
	bal.add_child(bv)
	var bh := HBoxContainer.new()
	_you_lbl.add_theme_color_override("font_color", Walker.team_color(0).lightened(0.3))
	_rival_lbl.add_theme_color_override("font_color", Walker.team_color(1).lightened(0.3))
	bh.add_child(_you_lbl)
	bh.add_child(_spacer())
	bh.add_child(_label("FOLLOWERS", 12, Color(1, 1, 1, 0.55)))
	bh.add_child(_spacer())
	bh.add_child(_rival_lbl)
	bv.add_child(bh)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 2)
	bars.custom_minimum_size = Vector2(0, 12)
	_you_bar.color = Walker.team_color(0)
	_rival_rect.color = Walker.team_color(1)
	for r in [_you_bar, _rival_rect]:
		r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bars.add_child(r)
	bv.add_child(bars)
	var rh := HBoxContainer.new()
	rh.add_child(_label("Rival faith", 12, Color(1, 1, 1, 0.5)))
	_rival_bar.max_value = World.MANA_MAX
	_rival_bar.show_percentage = false
	_rival_bar.custom_minimum_size = Vector2(0, 6)
	_rival_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rival_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var rf := StyleBoxFlat.new()
	rf.bg_color = Walker.team_color(1).darkened(0.2)
	rf.set_corner_radius_all(4)
	_rival_bar.add_theme_stylebox_override("fill", rf)
	rh.add_child(_rival_bar)
	bv.add_child(rh)
	row.add_child(bal)

	row.add_child(_spacer())

	var info := PanelContainer.new()
	info.custom_minimum_size = Vector2(300, 0)
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info.add_child(_info_lbl)
	row.add_child(info)
	return row


# ------------------------------------------------------------- bottom bar
func _build_bottom() -> Control:
	var row := HBoxContainer.new()
	_ignore(row)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var panel := PanelContainer.new()
	row.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.custom_minimum_size = Vector2(0, 40)
	_desc.add_theme_color_override("font_color", Color(1, 1, 1, 0.72))
	_desc.add_theme_font_size_override("font_size", 14)
	v.add_child(_desc)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	v.add_child(h)

	var bg := ButtonGroup.new()
	for i in BEHAVIORS.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = bg
		b.text = "%s\n%s" % [BEHAVIORS[i][0], BEHAVIORS[i][1]]
		b.tooltip_text = BEHAVIORS[i][2]
		b.custom_minimum_size = Vector2(84, 62)
		b.pressed.connect(func(): behavior_chosen.emit(i))
		h.add_child(b)
		_beh_btns.append(b)
	_beh_btns[0].button_pressed = true
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(14, 0)
	h.add_child(sep)

	var pg := ButtonGroup.new()
	for i in World.POWERS.size():
		var pw: Dictionary = World.POWERS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = pg
		b.text = "%s  %s\n%d faith" % [KEYS[i], pw.name, pw.cost]
		b.custom_minimum_size = Vector2(118, 62)
		b.pressed.connect(func(): power_chosen.emit(i))
		b.mouse_entered.connect(func(): _show_desc(i))
		b.mouse_exited.connect(func(): _show_desc(_selected))
		h.add_child(b)
		_power_btns.append(b)
	select_power(0)
	return row


func _show_desc(i: int) -> void:
	var pw: Dictionary = World.POWERS[i]
	_desc.text = "%s — %s" % [pw.name, pw.desc]


func select_power(i: int) -> void:
	_selected = i
	_power_btns[i].button_pressed = true
	_show_desc(i)


func select_behavior(b: int) -> void:
	_beh_btns[b].button_pressed = true


# ---------------------------------------------------------------- overlays
func _overlay(c: Control) -> VBoxContainer:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(c)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.06, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_box(Color(0.06, 0.08, 0.13, 0.94), 22))
	center.add_child(p)
	var m := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 26)
	p.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(560, 0)
	m.add_child(v)
	return v


func _build_title() -> void:
	var v := _overlay(_title)
	var t := _label("HAND OF THE ISLE", 44, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var sub := _label("Shape the land. Shelter your faithful. Outlast the rival god.", 17, Color(1, 1, 1, 0.75))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var body := _label(
		"Your people (blue) build homes on flat ground — the more flat land around a home, " +
		"the bigger it grows: hut, house, castle. Homes breed followers, and followers give you faith. " +
		"Spend faith to sculpt the island and to call down powers on the rival's people (red).", 15,
		Color(1, 1, 1, 0.82))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(body)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	for i in 3:
		var b := Button.new()
		b.text = ["Gentle rival", "Even match", "Wrathful rival"][i]
		b.custom_minimum_size = Vector2(160, 52)
		b.pressed.connect(func(): start_requested.emit(i))
		h.add_child(b)
	v.add_child(h)
	var hint := _label("Press H in game for controls", 13, Color(1, 1, 1, 0.45))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _build_end() -> void:
	var v := _overlay(_end)
	_end_head.add_theme_font_size_override("font_size", 40)
	_end_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_end_head)
	_end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_body.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	v.add_child(_end_body)
	var b := Button.new()
	b.text = "Shape a new world"
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(func(): restart_requested.emit())
	v.add_child(b)
	_end.visible = false


func _build_help() -> void:
	var v := _overlay(_help)
	v.add_child(_label("Controls", 28, ACCENT))
	var rows := [
		["Left click / hold", "Raise land (Sculpt) or cast the chosen power"],
		["Right click / hold", "Lower land (Sculpt)"],
		["1 – 8", "Choose a power"],
		["Z  X  C", "Followers: Settle, Gather at beacon, Crusade"],
		["W A S D / arrows", "Pan the camera"],
		["Q  E  /  middle-drag", "Rotate the camera"],
		["Mouse wheel", "Zoom"],
		["Space", "Pause"],
		["F", "Toggle fast-forward"],
		["Home", "Centre on your people"],
		["Esc", "Back to Sculpt"],
		["H", "Show or hide this help"],
	]
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 26)
	g.add_theme_constant_override("v_separation", 6)
	for r in rows:
		g.add_child(_label(r[0], 15, ACCENT.lightened(0.3)))
		g.add_child(_label(r[1], 15))
	v.add_child(g)
	var tip := _label("Tip: flatten a 5×5 patch around a hut to raise a castle. Homes on " +
		"low ground drown in a Flood; homes on uneven ground collapse.", 14, Color(1, 1, 1, 0.6))
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(tip)
	_help.visible = false


func toggle_help() -> void:
	_help.visible = not _help.visible


func help_visible() -> bool:
	return _help.visible


func hide_title() -> void:
	_title.visible = false
	_frame.visible = true


func show_end(won: bool, body: String) -> void:
	_end_head.text = "VICTORY" if won else "DEFEAT"
	_end_head.add_theme_color_override("font_color", ACCENT if won else Walker.team_color(1))
	_end_body.text = body
	_end.visible = true


func hide_end() -> void:
	_end.visible = false


# ---------------------------------------------------------------- updates
func toast(text: String, col := Color(1, 1, 1)) -> void:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := panel_box(Color(0.05, 0.07, 0.11, 0.78), 10)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(_label(text, 16, col))
	_toasts.add_child(p)
	while _toasts.get_child_count() > 4:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := p.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(p, "modulate:a", 0.0, 0.6)
	tw.tween_callback(p.queue_free)


func update_stats(w: World, paused: bool, speed: float) -> void:
	var m: float = w.mana[0]
	_faith_bar.value = m
	_faith_lbl.text = "%d" % int(m)
	_rival_bar.value = w.mana[1]
	var a := w.team_total(0)
	var b := w.team_total(1)
	_you_lbl.text = "You  %d" % a
	_rival_lbl.text = "%d  Rival" % b
	_you_bar.size_flags_stretch_ratio = maxf(0.02, float(a))
	_rival_rect.size_flags_stretch_ratio = maxf(0.02, float(b))
	var ca := w.count_of(0)
	var t := int(w.elapsed)
	var state := "PAUSED" if paused else ("FAST ×%d" % int(speed) if speed > 1.0 else "")
	_info_lbl.text = "%02d:%02d   %s\n%d homes · %d walkers   [H] help" % [t / 60, t % 60, state, ca.y, ca.x]
	for i in _power_btns.size():
		var afford := m >= float(World.POWERS[i].cost)
		_power_btns[i].modulate = Color(1, 1, 1, 1.0 if afford else 0.45)
