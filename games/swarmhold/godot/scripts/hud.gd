extends CanvasLayer

const Meshes = preload("res://scripts/meshes.gd")

var _font: Font
var _health: ProgressBar
var _hostage_box: Control
var _hostage: ProgressBar
var _time: Label
var _info: Label
var _msg: Label
var _sub: Label
var _hint: Label
var _title: Control
var _vignette: TextureRect
var _msg_tween: Tween
var _big: Label
var _tag: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fv := FontVariation.new()
	fv.base_font = load("res://fonts/Montserrat.ttf")
	fv.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): 780}
	_font = fv

	_vignette = TextureRect.new()
	var vg := GradientTexture2D.new()
	vg.gradient = Meshes.gradient([0.0, 0.55, 1.0], [Color(0.8, 0.05, 0.02, 0), Color(0.8, 0.05, 0.02, 0), Color(0.8, 0.05, 0.02, 0.85)])
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.05, 0.5)
	_vignette.texture = vg
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate.a = 0.0
	add_child(_vignette)

	var tl := VBoxContainer.new()
	tl.position = Vector2(32, 26)
	tl.add_theme_constant_override("separation", 6)
	add_child(tl)
	tl.add_child(_label("HEALTH", 15, Color(1, 1, 1, 0.8)))
	_health = _bar(Color(0.35, 0.85, 0.75))
	tl.add_child(_health)
	_hostage_box = VBoxContainer.new()
	_hostage_box.add_theme_constant_override("separation", 6)
	_hostage_box.add_child(_label("HOSTAGE", 15, Color(1, 1, 1, 0.8)))
	_hostage = _bar(Color(1.0, 0.62, 0.3))
	_hostage_box.add_child(_hostage)
	_hostage_box.visible = false
	tl.add_child(_hostage_box)

	_time = _label("2:30", 46, Color(1, 0.97, 0.9))
	_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_time.offset_left = -260
	_time.offset_right = -32
	_time.offset_top = 16
	add_child(_time)
	_info = _label("", 17, Color(1, 1, 1, 0.85))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_info.offset_left = -360
	_info.offset_right = -34
	_info.offset_top = 78
	add_child(_info)

	_msg = _label("", 64, Color(1, 0.96, 0.88))
	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_msg.offset_left = -700
	_msg.offset_right = 700
	_msg.offset_top = -120
	_msg.offset_bottom = -40
	add_child(_msg)
	_sub = _label("", 24, Color(1, 0.93, 0.8))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub.offset_left = -700
	_sub.offset_right = 700
	_sub.offset_top = -36
	_sub.offset_bottom = 10
	add_child(_sub)

	_hint = _label("WASD move   SPACE jump   hold F / left-click to throw   Q E rotate view   wheel zoom   ESC pause",
			15, Color(1, 1, 1, 0.65))
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_left = -700
	_hint.offset_right = 700
	_hint.offset_top = -44
	_hint.offset_bottom = -18
	add_child(_hint)

	_title = Control.new()
	_title.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var shade := TextureRect.new()
	var sg := GradientTexture2D.new()
	sg.gradient = Meshes.gradient([0.0, 0.6, 1.0], [Color(0.05, 0.03, 0.02, 0.0), Color(0.05, 0.03, 0.02, 0.25), Color(0.05, 0.03, 0.02, 0.7)])
	sg.fill_from = Vector2(0.5, 0.0)
	sg.fill_to = Vector2(0.5, 1.0)
	shade.texture = sg
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_title.add_child(shade)
	var big := _label("SWARMHOLD", 120, Color(1.0, 0.92, 0.78))
	_big = big
	big.label_settings.outline_size = 10
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	big.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	big.offset_left = -800
	big.offset_right = 800
	big.offset_top = -330
	big.offset_bottom = -180
	_title.add_child(big)
	var tag := _label("The city has fallen to the swarm. Someone is still inside.", 26, Color(1, 0.88, 0.72))
	_tag = tag
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tag.offset_left = -800
	tag.offset_right = 800
	tag.offset_top = -180
	tag.offset_bottom = -140
	_title.add_child(tag)
	var press := _label("CLICK OR PRESS ENTER", 30, Color(1, 1, 1))
	press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	press.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	press.offset_left = -400
	press.offset_right = 400
	press.offset_top = -110
	press.offset_bottom = -70
	_title.add_child(press)
	var pt := press.create_tween().set_loops()
	pt.tween_property(press, "modulate:a", 0.3, 0.8)
	pt.tween_property(press, "modulate:a", 1.0, 0.8)
	_msg.modulate.a = 0.0
	_sub.modulate.a = 0.0
	get_viewport().size_changed.connect(_fit)
	_fit()


## Keep the big title and messages inside narrow browser windows.
func _fit() -> void:
	var w := get_viewport().get_visible_rect().size.x
	_big.label_settings.font_size = clampi(int(w / 11.5), 44, 120)
	_tag.label_settings.font_size = clampi(int(w / 52.0), 15, 26)
	_msg.label_settings.font_size = clampi(int(w / 22.0), 34, 64)
	_sub.label_settings.font_size = clampi(int(w / 60.0), 14, 24)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	var ls := LabelSettings.new()
	ls.font = _font
	ls.font_size = size
	ls.font_color = color
	ls.outline_size = maxi(4, size / 8)
	ls.outline_color = Color(0.12, 0.06, 0.03, 0.85)
	ls.shadow_size = maxi(4, size / 6)
	ls.shadow_color = Color(0, 0, 0, 0.35)
	ls.shadow_offset = Vector2(0, 3)
	l.label_settings = ls
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _bar(color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(300, 14)
	b.show_percentage = false
	b.max_value = 100.0
	b.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.05, 0.03, 0.55)
	bg.set_corner_radius_all(7)
	bg.border_color = Color(1, 1, 1, 0.25)
	bg.set_border_width_all(1)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(7)
	fg.shadow_color = Color(color, 0.5)
	fg.shadow_size = 6
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	return b


func set_health(v: float) -> void:
	var tw := create_tween()
	tw.tween_property(_health, "value", v, 0.2)


func flash_damage(strength := 1.0) -> void:
	_vignette.modulate.a = clampf(0.35 + 0.5 * strength, 0.0, 1.0)
	var tw := create_tween()
	tw.tween_property(_vignette, "modulate:a", 0.0, 0.6)


func set_hostage(v: float, show: bool) -> void:
	_hostage_box.visible = show
	_hostage.value = v


func set_time(seconds: float) -> void:
	var s := maxi(ceili(seconds), 0)
	_time.text = "%d:%02d" % [s / 60, s % 60]
	_time.label_settings.font_color = Color(1, 0.35, 0.25) if s <= 20 else Color(1, 0.97, 0.9)


func set_info(level: int, score: int, kills: int) -> void:
	_info.text = "LEVEL %d     SCORE %d     ANTS %d" % [level, score, kills]


func show_message(title: String, sub := "", duration := 3.0) -> void:
	_msg.text = title
	_sub.text = sub
	if _msg_tween:
		_msg_tween.kill()
	_msg_tween = create_tween()
	_msg_tween.set_parallel(true)
	_msg.scale = Vector2.ONE
	_msg_tween.tween_property(_msg, "modulate:a", 1.0, 0.25)
	_msg_tween.tween_property(_sub, "modulate:a", 1.0, 0.25)
	if duration > 0.0:
		_msg_tween.chain().tween_interval(duration)
		_msg_tween.chain().tween_property(_msg, "modulate:a", 0.0, 0.6)
		_msg_tween.parallel().tween_property(_sub, "modulate:a", 0.0, 0.6)


func show_title(on: bool) -> void:
	_title.visible = on
	for c in [_health.get_parent(), _time, _info, _hint]:
		c.visible = not on
