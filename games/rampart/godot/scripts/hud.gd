extends CanvasLayer
## Heads-up display, title screen, game-over and pause overlays.

const CYAN := Color(0.35, 0.9, 1.0)
const AMBER := Color(1.0, 0.72, 0.25)
const RED := Color(1.0, 0.3, 0.32)
const PINK := Color(1.0, 0.35, 0.8)
const WHITE := Color(0.92, 0.96, 1.0)

var font: FontVariation
var font_bold: FontVariation
var root: Control
var game_ui: Control
var score_label: Label
var hi_label: Label
var level_label: Label
var lives_label: Label
var section_label: Label
var fuel_bar: ProgressBar
var fuel_fill: StyleBoxFlat
var fuel_label: Label
var alt_bar: ProgressBar
var alt_label: Label
var msg_label: Label
var sub_label: Label
var boss_box: Control
var boss_bar: ProgressBar
var title_ui: Control
var press_label: Label
var title_hi: Label
var over_ui: Control
var over_score: Label
var pause_ui: Control
var msg_time: float = 0.0
var t: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	font = FontVariation.new()
	font.base_font = ThemeDB.fallback_font
	font.spacing_glyph = 2
	font_bold = FontVariation.new()
	font_bold.base_font = ThemeDB.fallback_font
	font_bold.spacing_glyph = 6
	font_bold.variation_embolden = 0.9
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_game_ui()
	_build_title()
	_build_over()
	_build_pause()


# --- helpers -----------------------------------------------------------------

func _label(parent: Control, text: String, size: int, color: Color, bold: bool = false, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", maxi(4, size / 8))
	l.add_theme_color_override("font_shadow_color", Color(color.r, color.g, color.b, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", 0)
	l.add_theme_constant_override("shadow_outline_size", maxi(6, size / 4))
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _place(c: Control, al: float, at: float, ar: float, ab: float, ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _bar(parent: Control, fill_color: Color) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.min_value = 0.0
	b.max_value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.05, 0.09, 0.65)
	bg.border_color = Color(fill_color, 0.55)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(4)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill_color
	fg.set_corner_radius_all(3)
	fg.shadow_color = Color(fill_color, 0.5)
	fg.shadow_size = 8
	b.add_theme_stylebox_override("background", bg)
	b.add_theme_stylebox_override("fill", fg)
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(b)
	return b


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(c)
	return c


# --- build -------------------------------------------------------------------

func _build_game_ui() -> void:
	game_ui = _layer()
	var cap := _label(game_ui, "SCORE", 14, Color(CYAN, 0.7))
	_place(cap, 0, 0, 0, 0, 36, 22, 400, 40)
	score_label = _label(game_ui, "0000000", 40, WHITE, true)
	_place(score_label, 0, 0, 0, 0, 34, 38, 500, 90)
	hi_label = _label(game_ui, "HI 0000000", 16, Color(CYAN, 0.8))
	_place(hi_label, 0, 0, 0, 0, 36, 90, 400, 112)

	level_label = _label(game_ui, "LEVEL 1", 22, WHITE, true, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(level_label, 1, 0, 1, 0, -420, 26, -36, 56)
	lives_label = _label(game_ui, "SHIPS 3", 18, CYAN, false, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(lives_label, 1, 0, 1, 0, -420, 60, -36, 84)
	section_label = _label(game_ui, "APPROACH", 14, Color(CYAN, 0.7), false, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(section_label, 1, 0, 1, 0, -420, 88, -36, 108)

	fuel_bar = _bar(game_ui, AMBER)
	_place(fuel_bar, 0.5, 1, 0.5, 1, -280, -58, 280, -40)
	fuel_fill = fuel_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fuel_label = _label(game_ui, "FUEL", 15, AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(fuel_label, 0.5, 1, 0.5, 1, -280, -86, 280, -62)

	alt_bar = _bar(game_ui, CYAN)
	alt_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_place(alt_bar, 0, 0.5, 0, 0.5, 44, -170, 64, 170)
	var ac := _label(game_ui, "ALT", 15, CYAN, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(ac, 0, 0.5, 0, 0.5, 14, -200, 94, -176)
	alt_label = _label(game_ui, "0.0", 15, WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(alt_label, 0, 0.5, 0, 0.5, 14, 176, 94, 200)
	for i in 5:
		var tick := ColorRect.new()
		tick.color = Color(CYAN, 0.5)
		tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var y := -170.0 + 340.0 * i / 4.0
		_place(tick, 0, 0.5, 0, 0.5, 68, y - 1, 78, y + 1)
		game_ui.add_child(tick)

	msg_label = _label(game_ui, "", 64, WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(msg_label, 0, 0.3, 1, 0.3, 0, -50, 0, 30)
	sub_label = _label(game_ui, "", 20, CYAN, false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(sub_label, 0, 0.3, 1, 0.3, 0, 36, 0, 64)

	boss_box = Control.new()
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(boss_box, 0.5, 0, 0.5, 0, -300, 30, 300, 80)
	game_ui.add_child(boss_box)
	var bl := _label(boss_box, "THE WARDEN", 15, PINK, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(bl, 0, 0, 1, 0, 0, 0, 0, 22)
	boss_bar = _bar(boss_box, PINK)
	_place(boss_bar, 0, 0, 1, 0, 0, 28, 0, 42)
	boss_box.visible = false


func _build_title() -> void:
	title_ui = _layer()
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.01, 0.03, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_ui.add_child(shade)
	var name_lbl := _label(title_ui, "RAMPART", 150, CYAN, true, HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.add_theme_color_override("font_shadow_color", Color(0.2, 0.7, 1.0, 0.55))
	name_lbl.add_theme_constant_override("shadow_outline_size", 40)
	_place(name_lbl, 0, 0.22, 1, 0.22, 0, -40, 0, 150)
	var tag := _label(title_ui, "ASSAULT ON THE ORBITAL CITADEL", 22, WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(tag, 0, 0.22, 1, 0.22, 0, 150, 0, 180)
	var how := _label(title_ui,
		"Fly through the fortress, threading gaps in walls and force fields.\n"
		+ "Read your altitude from the target ring below you and the ALT gauge.\n"
		+ "Shoot fuel tanks to stay airborne. Destroy the Warden at the citadel.",
		17, Color(WHITE, 0.85), false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(how, 0, 0.55, 1, 0.55, 0, -10, 0, 70)
	var keys := _label(title_ui, "ARROWS / WASD  steer & climb      SPACE  fire      P  pause", 16, CYAN, false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(keys, 0, 0.55, 1, 0.55, 0, 86, 0, 110)
	press_label = _label(title_ui, "PRESS ENTER TO LAUNCH", 28, AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(press_label, 0, 0.8, 1, 0.8, 0, 0, 0, 40)
	title_hi = _label(title_ui, "", 16, Color(CYAN, 0.8), false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(title_hi, 0, 0.8, 1, 0.8, 0, 52, 0, 74)


func _build_over() -> void:
	over_ui = _layer()
	var l := _label(over_ui, "GAME OVER", 96, RED, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(l, 0, 0.35, 1, 0.35, 0, -60, 0, 60)
	over_score = _label(over_ui, "", 26, WHITE, false, HORIZONTAL_ALIGNMENT_CENTER)
	_place(over_score, 0, 0.35, 1, 0.35, 0, 70, 0, 104)
	var p := _label(over_ui, "PRESS ENTER TO FLY AGAIN", 22, AMBER, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(p, 0, 0.35, 1, 0.35, 0, 130, 0, 160)
	over_ui.visible = false


func _build_pause() -> void:
	pause_ui = _layer()
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.5)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_ui.add_child(shade)
	var l := _label(pause_ui, "PAUSED", 80, WHITE, true, HORIZONTAL_ALIGNMENT_CENTER)
	_place(l, 0, 0.45, 1, 0.45, 0, -50, 0, 50)
	pause_ui.visible = false


# --- state -------------------------------------------------------------------

func show_title() -> void:
	title_ui.visible = true
	game_ui.visible = false
	over_ui.visible = false
	title_hi.text = "HIGH SCORE  %07d" % Game.hi_score


func show_game() -> void:
	title_ui.visible = false
	game_ui.visible = true
	over_ui.visible = false


func show_game_over() -> void:
	over_ui.visible = true
	over_score.text = "SCORE %07d      BEST %07d" % [Game.score, Game.hi_score]
	msg_label.text = ""
	sub_label.text = ""


func message(text: String, sub: String = "", duration: float = 2.0) -> void:
	msg_label.text = text
	sub_label.text = sub
	msg_time = duration
	msg_label.modulate.a = 1.0
	sub_label.modulate.a = 1.0


func set_section(s: String) -> void:
	section_label.text = s


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and (Game.state == Game.State.PLAYING or Game.state == Game.State.DYING):
		get_tree().paused = not get_tree().paused
		pause_ui.visible = get_tree().paused
		get_viewport().set_input_as_handled()


func update_hud(alt: float, boss_ratio: float) -> void:
	score_label.text = "%07d" % Game.score
	hi_label.text = "HI %07d" % Game.hi_score
	level_label.text = "LEVEL %d" % Game.level
	lives_label.text = "SHIPS %d" % maxi(Game.lives, 0)
	fuel_bar.value = Game.fuel
	var low := Game.fuel < 25.0
	var c := RED if low else AMBER
	if low and fmod(t, 0.5) < 0.25:
		c = Color(1, 0.85, 0.85)
	fuel_fill.bg_color = c
	fuel_label.text = "LOW FUEL" if low else "FUEL"
	fuel_label.add_theme_color_override("font_color", c)
	alt_bar.value = clampf((alt - 0.9) / (9.0 - 0.9), 0.0, 1.0) * 100.0
	alt_label.text = "%.1f" % alt
	boss_box.visible = boss_ratio >= 0.0
	if boss_ratio >= 0.0:
		boss_bar.value = boss_ratio * 100.0


func _process(delta: float) -> void:
	t += delta
	press_label.modulate.a = 0.55 + 0.45 * sin(t * 4.0)
	if msg_time > 0.0 and not get_tree().paused:
		msg_time -= delta
		var a := clampf(msg_time / 0.4, 0.0, 1.0)
		msg_label.modulate.a = a
		sub_label.modulate.a = a
