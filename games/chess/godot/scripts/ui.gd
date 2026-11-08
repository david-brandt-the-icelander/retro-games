class_name UI
extends RefCounted
## The look: a dark, quiet interface in charcoal and ivory with one warm gold accent; Playfair
## Display italic for titles, Inter for everything else. Helpers build the common pieces.

const BG := Color("0b0c0f")
const CARD := Color("15171c")
const RAISED := Color("1d2026")
const LINE := Color("2b2e36")
const INK := Color("ece8df")
const MUTED := Color("8d919b")
const GOLD := Color("d9b26b")
const GOLD_DARK := Color("a8843f")
const RED := Color("e5566a")
const GREEN := Color("6fcf97")

static var regular: Font = preload("res://fonts/inter-latin-400-normal.woff2")
static var bold: Font = preload("res://fonts/inter-latin-600-normal.woff2")
static var display: Font = preload("res://fonts/playfair-display-latin-600-normal.woff2")
static var italic: Font = preload("res://fonts/playfair-display-latin-400-italic.woff2")


static func box(bg: Color, radius := 12, border := Color(0, 0, 0, 0), pad := Vector4(16, 10, 16, 10)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0:
		s.border_color = border
		s.set_border_width_all(1)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	s.anti_aliasing = true
	return s


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = regular
	t.default_font_size = 16
	t.set_color("font_color", "Label", INK)

	t.set_stylebox("normal", "Button", box(RAISED, 10, LINE))
	t.set_stylebox("hover", "Button", box(Color("262a32"), 10, Color("3b3f4a")))
	t.set_stylebox("pressed", "Button", box(Color("17191e"), 10, LINE))
	t.set_stylebox("disabled", "Button", box(Color("17191e"), 10, LINE))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), 10, GOLD))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_font("font", "Button", bold)
	t.set_font_size("font_size", "Button", 15)

	t.set_type_variation("Primary", "Button")
	t.set_stylebox("normal", "Primary", box(GOLD, 10))
	t.set_stylebox("hover", "Primary", box(Color("e6c27e"), 10))
	t.set_stylebox("pressed", "Primary", box(GOLD_DARK, 10))
	t.set_color("font_color", "Primary", Color("17140e"))
	t.set_color("font_hover_color", "Primary", Color("17140e"))
	t.set_color("font_pressed_color", "Primary", Color("17140e"))

	t.set_type_variation("Ghost", "Button")
	t.set_stylebox("normal", "Ghost", box(Color(0, 0, 0, 0), 10))
	t.set_stylebox("hover", "Ghost", box(Color(1, 1, 1, 0.06), 10))
	t.set_stylebox("pressed", "Ghost", box(Color(1, 1, 1, 0.03), 10))
	t.set_color("font_color", "Ghost", MUTED)

	t.set_type_variation("Danger", "Button")
	t.set_stylebox("normal", "Danger", box(Color(0, 0, 0, 0), 10, Color(RED, 0.6)))
	t.set_stylebox("hover", "Danger", box(Color(RED, 0.15), 10, RED))
	t.set_color("font_color", "Danger", RED)

	t.set_type_variation("Chip", "Button")
	t.set_stylebox("normal", "Chip", box(Color(0, 0, 0, 0), 18, LINE, Vector4(14, 8, 14, 8)))
	t.set_stylebox("hover", "Chip", box(Color(1, 1, 1, 0.05), 18, Color("3b3f4a"), Vector4(14, 8, 14, 8)))
	t.set_stylebox("pressed", "Chip", box(Color(GOLD, 0.16), 18, GOLD, Vector4(14, 8, 14, 8)))
	t.set_color("font_pressed_color", "Chip", GOLD)

	t.set_stylebox("normal", "LineEdit", box(Color("101216"), 10, LINE, Vector4(14, 10, 14, 10)))
	t.set_stylebox("focus", "LineEdit", box(Color(0, 0, 0, 0), 10, GOLD, Vector4(14, 10, 14, 10)))
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_placeholder_color", "LineEdit", Color(MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", GOLD)
	t.set_color("selection_color", "LineEdit", Color(GOLD, 0.3))

	t.set_stylebox("panel", "PanelContainer", box(Color(CARD, 0.94), 18, LINE, Vector4(22, 20, 22, 20)))
	t.set_type_variation("Inset", "PanelContainer")
	t.set_stylebox("panel", "Inset", box(Color("101216"), 12, LINE, Vector4(12, 10, 12, 10)))
	t.set_type_variation("Row", "PanelContainer")
	t.set_stylebox("panel", "Row", box(RAISED, 12, Color(0, 0, 0, 0), Vector4(12, 10, 12, 10)))
	t.set_type_variation("Banner", "PanelContainer")
	t.set_stylebox("panel", "Banner", box(Color(GOLD, 0.12), 12, Color(GOLD, 0.5), Vector4(14, 10, 14, 10)))

	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", italic)
	t.set_font_size("font_size", "Title", 64)
	t.set_color("font_color", "Title", INK)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", display)
	t.set_font_size("font_size", "Heading", 22)
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_font_size("font_size", "Muted", 14)
	t.set_type_variation("Strong", "Label")
	t.set_font("font", "Strong", bold)
	t.set_type_variation("Eyebrow", "Label")
	t.set_font("font", "Eyebrow", bold)
	t.set_font_size("font_size", "Eyebrow", 12)
	t.set_color("font_color", "Eyebrow", GOLD)

	var thin := StyleBoxFlat.new()
	thin.bg_color = Color(1, 1, 1, 0.12)
	thin.set_corner_radius_all(3)
	thin.content_margin_left = 3
	thin.content_margin_right = 3
	var grab := thin.duplicate()
	grab.bg_color = Color(1, 1, 1, 0.22)
	t.set_stylebox("scroll", "VScrollBar", StyleBoxEmpty.new())
	t.set_stylebox("grabber", "VScrollBar", thin)
	t.set_stylebox("grabber_highlight", "VScrollBar", grab)
	t.set_stylebox("grabber_pressed", "VScrollBar", grab)

	var track := box(Color(1, 1, 1, 0.1), 3, Color(0, 0, 0, 0), Vector4(0, 2, 0, 2))
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", box(GOLD, 3, Color(0, 0, 0, 0), Vector4(0, 2, 0, 2)))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(GOLD, 3, Color(0, 0, 0, 0), Vector4(0, 2, 0, 2)))
	var knob := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length()
			knob.set_pixel(x, y, Color(INK, clampf(7.5 - d, 0.0, 1.0)))
	var kt := ImageTexture.create_from_image(knob)
	t.set_icon("grabber", "HSlider", kt)
	t.set_icon("grabber_highlight", "HSlider", kt)

	t.set_stylebox("panel", "PopupMenu", box(RAISED, 10, LINE, Vector4(6, 6, 6, 6)))
	t.set_stylebox("hover", "PopupMenu", box(Color(GOLD, 0.15), 6))
	t.set_stylebox("panel", "TooltipPanel", box(RAISED, 8, LINE, Vector4(10, 6, 10, 6)))
	return t


# ── Building blocks ──

static func label(text: String, variation := "", size := 0) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


static func wrap(text: String, variation := "") -> Label:
	var l := label(text, variation)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 40
	return l


static func button(text: String, on_press: Callable, variation := "") -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	if variation != "":
		b.theme_type_variation = variation
	b.pressed.connect(on_press)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func vbox(gap := 12, kids: Array = []) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", gap)
	for k in kids:
		if k:
			v.add_child(k)
	return v


static func hbox(gap := 12, kids: Array = []) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", gap)
	h.alignment = BoxContainer.ALIGNMENT_BEGIN
	for k in kids:
		if k:
			h.add_child(k)
	return h


static func card(content: Control, variation := "") -> PanelContainer:
	var p := PanelContainer.new()
	if variation != "":
		p.theme_type_variation = variation
	p.add_child(content)
	return p


static func spacer() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func scroll(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	return s


static func clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


## "14:05", or "3 Nov, 14:05" if not today.
static func clock(ms: float) -> String:
	var bias: int = Time.get_time_zone_from_system().bias
	var d := Time.get_datetime_dict_from_unix_time(int(ms / 1000.0) + bias * 60)
	var now := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + bias * 60)
	var hm := "%02d:%02d" % [d.hour, d.minute]
	if d.year == now.year and d.month == now.month and d.day == now.day:
		return hm
	var months := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
	return "%d %s, %s" % [d.day, months[d.month - 1], hm]


## How long something took: "7s", "2m 05s", "3h 10m", "2d 4h".
static func duration(ms: float) -> String:
	var s := int(ms / 1000.0)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm %02ds" % [s / 60, s % 60]
	if s < 86400:
		return "%dh %02dm" % [s / 3600, (s % 3600) / 60]
	return "%dd %dh" % [s / 86400, (s % 86400) / 3600]


static func ago(ms: float) -> String:
	var s := Time.get_unix_time_from_system() - ms / 1000.0
	if s < 60:
		return "just now"
	if s < 3600:
		return "%d min ago" % int(s / 60)
	if s < 86400:
		return "%d h ago" % int(s / 3600)
	return clock(ms)


## "No moves yet", "1 move", "12 moves": counted the chess way, a move by each side being one.
static func moves_text(plies: int) -> String:
	var n := (plies + 1) / 2
	return "No moves yet" if n == 0 else ("1 move" if n == 1 else "%d moves" % n)


## A small dot in a side's colour.
static func side_dot(white: bool, size := 10) -> Control:
	var c := Panel.new()
	c.custom_minimum_size = Vector2(size, size)
	var s := box(Color("ece6d8") if white else Color("1d1e24"), size, Color("5a5d66"), Vector4.ZERO)
	c.add_theme_stylebox_override("panel", s)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return c
