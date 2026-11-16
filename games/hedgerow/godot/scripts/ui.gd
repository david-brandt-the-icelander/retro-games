class_name GameUI
extends CanvasLayer
## HUD: turn banner, objectives, unit card, hover/odds panel, combat log.

signal end_turn_pressed
signal next_unit_pressed
signal restart_pressed
signal artillery_pressed

const GOLD := Color(0.95, 0.83, 0.55)

var root: Control
var turn_label: RichTextLabel
var obj_label: RichTextLabel
var unit_panel: PanelContainer
var unit_card: RichTextLabel
var hover_panel: PanelContainer
var hover_label: RichTextLabel
var log_label: RichTextLabel
var banner: Label
var toast: Label
var end_btn: Button
var next_btn: Button
var arty_btn: Button
var over: Control
var over_title: Label
var over_text: RichTextLabel
var headless_log := false


func _ready() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	add_child(root)

	var tl := _panel()
	_place(tl, 0, 0, 16, 16)
	var v := VBoxContainer.new()
	tl.add_child(v)
	var title := Label.new()
	title.text = "HEDGEROW"
	var tf := SystemFont.new()
	tf.font_names = PackedStringArray(["Georgia", "Times New Roman", "DejaVu Serif", "serif"])
	tf.font_weight = 700
	title.add_theme_font_override("font", tf)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", GOLD)
	v.add_child(title)
	var sub := Label.new()
	sub.text = "Normandy · July 1944"
	sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.62))
	v.add_child(sub)
	turn_label = _rtl(300)
	v.add_child(turn_label)

	var tr := _panel()
	_place(tr, 1, 0, -16, 16)
	var v2 := VBoxContainer.new()
	tr.add_child(v2)
	var oh := Label.new()
	oh.text = "OBJECTIVES"
	oh.add_theme_color_override("font_color", GOLD)
	v2.add_child(oh)
	obj_label = _rtl(300)
	v2.add_child(obj_label)

	var lp := _panel()
	_place(lp, 1, 0, -16, 168)
	var v3 := VBoxContainer.new()
	lp.add_child(v3)
	var lh := Label.new()
	lh.text = "COMBAT LOG"
	lh.add_theme_color_override("font_color", GOLD)
	v3.add_child(lh)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.custom_minimum_size = Vector2(400, 300)
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 13)
	v3.add_child(log_label)

	unit_panel = _panel()
	_place(unit_panel, 0, 1, 16, -16)
	unit_card = _rtl(380)
	unit_panel.add_child(unit_card)
	unit_panel.visible = false

	hover_panel = _panel()
	_place(hover_panel, 0.5, 1, 0, -16)
	hover_label = _rtl(470)
	hover_panel.add_child(hover_label)
	hover_panel.visible = false

	var br := VBoxContainer.new()
	_place(br, 1, 1, -16, -16)
	br.add_theme_constant_override("separation", 8)
	root.add_child(br)
	var hb := HBoxContainer.new()
	hb.alignment = BoxContainer.ALIGNMENT_END
	hb.add_theme_constant_override("separation", 10)
	br.add_child(hb)
	arty_btn = Button.new()
	arty_btn.text = "Artillery (3)  [F]"
	arty_btn.custom_minimum_size = Vector2(170, 44)
	arty_btn.toggle_mode = true
	arty_btn.pressed.connect(func() -> void: artillery_pressed.emit())
	hb.add_child(arty_btn)
	next_btn = Button.new()
	next_btn.text = "Next unit  [Tab]"
	next_btn.custom_minimum_size = Vector2(160, 44)
	next_btn.pressed.connect(func() -> void: next_unit_pressed.emit())
	hb.add_child(next_btn)
	end_btn = Button.new()
	end_btn.text = "End turn  [Enter]"
	end_btn.custom_minimum_size = Vector2(190, 44)
	end_btn.pressed.connect(func() -> void: end_turn_pressed.emit())
	hb.add_child(end_btn)
	var help := Label.new()
	help.text = "LMB select · move · fire    F artillery    RMB cancel    WASD pan    Q/E rotate    Wheel zoom    MMB orbit"
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8, 0.75))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	br.add_child(help)

	banner = Label.new()
	banner.add_theme_font_override("font", tf)
	banner.add_theme_font_size_override("font_size", 46)
	banner.add_theme_color_override("font_color", GOLD)
	banner.add_theme_constant_override("outline_size", 12)
	banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(banner, 0.5, 0.26, 0, 0)
	banner.modulate.a = 0.0
	root.add_child(banner)

	toast = Label.new()
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_color", Color(1.0, 0.7, 0.4))
	toast.add_theme_constant_override("outline_size", 8)
	toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(toast, 0.5, 0.7, 0, 0)
	toast.modulate.a = 0.0
	root.add_child(toast)

	over = ColorRect.new()
	(over as ColorRect).color = Color(0, 0, 0, 0.55)
	over.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.visible = false
	root.add_child(over)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	over.add_child(cc)
	var op := _panel(false)
	cc.add_child(op)
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 14)
	op.add_child(ov)
	over_title = Label.new()
	over_title.add_theme_font_override("font", tf)
	over_title.add_theme_font_size_override("font_size", 44)
	over_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ov.add_child(over_title)
	over_text = _rtl(520)
	ov.add_child(over_text)
	var again := Button.new()
	again.text = "Play again"
	again.custom_minimum_size = Vector2(200, 46)
	again.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	again.pressed.connect(func() -> void: restart_pressed.emit())
	ov.add_child(again)


func _place(c: Control, ax: float, ay: float, ox: float, oy: float) -> void:
	c.anchor_left = ax
	c.anchor_right = ax
	c.anchor_top = ay
	c.anchor_bottom = ay
	c.offset_left = ox
	c.offset_right = ox
	c.offset_top = oy
	c.offset_bottom = oy
	if ax >= 1.0:
		c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	elif ax > 0.0:
		c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	else:
		c.grow_horizontal = Control.GROW_DIRECTION_END
	if ay >= 1.0:
		c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	elif ay > 0.0:
		c.grow_vertical = Control.GROW_DIRECTION_BOTH
	else:
		c.grow_vertical = Control.GROW_DIRECTION_END


func _panel(add: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	if add:
		root.add_child(p)
	return p


func _rtl(w: float) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.custom_minimum_size = Vector2(w, 0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _make_theme() -> Theme:
	var t := Theme.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.06, 0.84)
	sb.border_color = Color(0.78, 0.66, 0.42, 0.5)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 8
	t.set_stylebox("panel", "PanelContainer", sb)
	var bn := StyleBoxFlat.new()
	bn.bg_color = Color(0.2, 0.22, 0.15, 0.95)
	bn.border_color = Color(0.85, 0.72, 0.45, 0.8)
	bn.set_border_width_all(1)
	bn.set_corner_radius_all(5)
	bn.set_content_margin_all(8)
	var bh := bn.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.3, 0.32, 0.2, 0.98)
	var bp := bn.duplicate() as StyleBoxFlat
	bp.bg_color = Color(0.14, 0.15, 0.1, 0.98)
	var bd := bn.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.15, 0.15, 0.15, 0.7)
	bd.border_color = Color(0.4, 0.4, 0.4, 0.5)
	t.set_stylebox("normal", "Button", bn)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color(0.95, 0.9, 0.78))
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_font_size("font_size", "Button", 16)
	t.set_color("font_color", "Label", Color(0.92, 0.9, 0.84))
	t.set_font_size("font_size", "Label", 15)
	t.set_color("default_color", "RichTextLabel", Color(0.92, 0.9, 0.84))
	t.set_font_size("normal_font_size", "RichTextLabel", 15)
	t.set_font_size("bold_font_size", "RichTextLabel", 15)
	t.set_constant("separation", "VBoxContainer", 6)
	return t


# ------------------------------------------------------------------ API

func set_turn(turn: int, max_turns: int, side: String, player_side: String) -> void:
	var s := "Turn [b]%d[/b] of %d\n" % [turn, max_turns]
	if side == player_side:
		s += "[color=#8fbaff]US Army — your orders, Lieutenant[/color]"
	else:
		s += "[color=#ff9585]German turn…[/color]"
	turn_label.text = s
	end_btn.disabled = side != player_side
	next_btn.disabled = side != player_side
	arty_btn.disabled = side != player_side


func set_artillery(left: int, available: bool, armed: bool) -> void:
	arty_btn.text = "Artillery (%d)  [F]" % left
	arty_btn.disabled = not available
	arty_btn.set_pressed_no_signal(armed)


func set_objectives(objs: Array, turn: int, max_turns: int) -> void:
	var s := ""
	var held := 0
	for o in objs:
		var us: bool = o["owner"] == "US"
		if us:
			held += 1
		s += "%s  [color=%s][b]%s[/b][/color]\n" % [o["name"], "#7fa8ff" if us else "#ff7a6a", "US" if us else "German"]
	s += "[color=#cfc39b]Hold 2 of 3 at the end of turn %d.[/color]" % max_turns
	obj_label.text = s


func log_msg(text: String) -> void:
	log_label.append_text(text + "\n")
	if headless_log:
		var re := RegEx.new()
		re.compile("\\[[^\\]]*\\]")
		print(re.sub(text, "", true))


func show_unit(u: Unit) -> void:
	if u == null:
		unit_panel.visible = false
		return
	unit_panel.visible = true
	var d: Dictionary = u.d
	var sc: String = "#8fbaff" if u.side == "US" else "#ff9585"
	var s := "[font_size=21][b][color=%s]%s[/color][/b][/font_size]\n" % [sc, d["name"]]
	s += "[color=#b9b39b]%s · %s[/color]\n" % ["US Army" if u.side == "US" else "Wehrmacht", d["role"]]
	s += "[color=#d8cfae]%s[/color]\n" % d["weapons"]
	s += "Move [b]%d[/b]    Firepower [b]%d[/b]    Range [b]%d[/b]\n" % [int(d["mp"]), u.fp(), int(d["rng"])]
	if u.has_at():
		s += "AT penetration [b]%dmm[/b] (range %d)\n" % [int(d["at_pen"]), int(d["at_rng"])]
	if u.is_vehicle():
		s += "Armor front [b]%dmm[/b] · side [b]%dmm[/b]\n" % [int(d["armor_f"]), int(d["armor_s"])]
	var st := "Ready"
	var stc := "#9fe08a"
	if u.status == "pinned":
		st = "Shaken" if u.is_vehicle() else "Pinned (cannot move, -2 fire)"
		stc = "#ffd36b"
	elif u.status == "broken":
		st = "Broken (cannot fire)"
		stc = "#ff9a50"
	var strength: String = "%d/%d" % [u.steps, int(d["steps"])]
	s += "Morale [b]%d[/b]    Strength [b]%s[/b]\n" % [int(d["morale"]), strength]
	s += "Status: [color=%s]%s[/color]" % [stc, st]
	if u.side == "US":
		s += "    Moved %s · Fired %s" % ["yes" if u.moved else "no", "yes" if u.fired else "no"]
	unit_card.text = s


func set_hover(text: String) -> void:
	hover_panel.visible = text != ""
	hover_label.text = text


func show_banner(text: String) -> void:
	banner.text = text
	var tw := banner.create_tween()
	tw.tween_property(banner, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.3)
	tw.tween_property(banner, "modulate:a", 0.0, 0.5)


func flash(text: String) -> void:
	toast.text = text
	toast.modulate.a = 1.0
	var tw := toast.create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast, "modulate:a", 0.0, 0.5)


func show_game_over(title: String, text: String, win: bool) -> void:
	over.visible = true
	over_title.text = title
	over_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0) if win else Color(1.0, 0.55, 0.45))
	over_text.text = text
	end_btn.disabled = true
	next_btn.disabled = true
	arty_btn.disabled = true
