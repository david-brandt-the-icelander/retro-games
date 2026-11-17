class_name UiTheme
extends RefCounted
## Builds the shared dark glassy UI theme.

const ACCENT := Color("f2c14e")
const TEXT := Color("e9edf3")
const MUTED := Color("9aa6b5")
const PANEL := Color(0.07, 0.09, 0.13, 0.9)
const GOLD := Color("ffd166")
const SCIENCE := Color("6fc3ff")
const FOOD := Color("8fe388")
const PROD := Color("ffa45c")

static func sb(bg: Color, radius := 10, border := Color(1, 1, 1, 0.07), bw := 1, pad := 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(bw)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	s.anti_aliasing = true
	return s

static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", sb(PANEL, 12))
	t.set_stylebox("panel", "Panel", sb(PANEL, 12))
	var b_normal := sb(Color(1, 1, 1, 0.06), 8, Color(1, 1, 1, 0.08), 1, 12)
	b_normal.shadow_size = 0
	var b_hover := sb(Color(1, 1, 1, 0.13), 8, Color(1, 1, 1, 0.18), 1, 12)
	b_hover.shadow_size = 0
	var b_press := sb(Color(ACCENT, 0.35), 8, ACCENT, 1, 12)
	b_press.shadow_size = 0
	var b_dis := sb(Color(1, 1, 1, 0.025), 8, Color(1, 1, 1, 0.04), 1, 12)
	b_dis.shadow_size = 0
	t.set_stylebox("normal", "Button", b_normal)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("disabled", "Button", b_dis)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.3))
	var le := sb(Color(0, 0, 0, 0.35), 8, Color(1, 1, 1, 0.12), 1, 10)
	le.shadow_size = 0
	t.set_stylebox("normal", "LineEdit", le)
	var lef := sb(Color(0, 0, 0, 0.45), 8, ACCENT, 1, 10)
	lef.shadow_size = 0
	t.set_stylebox("focus", "LineEdit", lef)
	t.set_color("font_color", "LineEdit", TEXT)
	var pb_bg := sb(Color(1, 1, 1, 0.08), 4, Color(0, 0, 0, 0), 0, 0)
	pb_bg.shadow_size = 0
	var pb_fg := sb(SCIENCE, 4, Color(0, 0, 0, 0), 0, 0)
	pb_fg.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fg)
	t.set_font_size("font_size", "ProgressBar", 11)
	var tip := sb(Color(0.05, 0.06, 0.09, 0.96), 8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_stylebox("normal", "OptionButton", b_normal)
	t.set_stylebox("hover", "OptionButton", b_hover)
	t.set_stylebox("pressed", "OptionButton", b_press)
	t.set_stylebox("focus", "OptionButton", StyleBoxEmpty.new())
	t.set_stylebox("panel", "PopupMenu", sb(Color(0.08, 0.1, 0.14, 0.98), 8))
	return t

static func label(text: String, size := 15, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

static func button(text: String, cb: Callable, size := 15) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	return b

static func bar(color: Color, h := 8) -> ProgressBar:
	var p := ProgressBar.new()
	p.show_percentage = false
	p.custom_minimum_size = Vector2(0, h)
	var fg := sb(color, 4, Color(0, 0, 0, 0), 0, 0)
	fg.shadow_size = 0
	p.add_theme_stylebox_override("fill", fg)
	return p
