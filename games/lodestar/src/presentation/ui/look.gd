extends RefCounted
## The plain look every panel and the HUD share: the art bible's palette (ART-BIBLE § Palette),
## two fonts and a few drawing helpers. Sizes are at the 1920 × 1080 reference; the window's
## canvas_items stretch scales them.
##
## Use it with `const Look = preload("res://src/presentation/ui/look.gd")`.

const VOID := Color("#0b0c0f")
const GLASS := Color(0.063, 0.067, 0.082, 0.93)
const RULE := Color("#2a2c33")
const TEXT := Color("#e4e4e7")
const DIM := Color("#8d9099")
const GOLD := Color("#c9a25c")
const GOLD_DEEP := Color("#6b5631")
const FOCUS := Color("#9fc3ff")
const AMBER := Color("#e8a33d")
const DANGER := Color("#e5484d")
const GOOD := Color("#4cc38a")
## Condition colours by code 0..3 (UI-DESIGN § Flight HUD, Scanner).
const CONDITION := [GOLD, FOCUS, AMBER, DANGER]

static var _sans: Font
static var _mono: Font


static func sans() -> Font:
	if _sans == null:
		_sans = ThemeDB.fallback_font
	return _sans


static func mono() -> Font:
	if _mono == null:
		var font := SystemFont.new()
		font.font_names = PackedStringArray(["JetBrains Mono", "DejaVu Sans Mono", "Menlo", "Consolas", "Liberation Mono", "monospace"])
		_mono = font
	return _mono


## A glass panel with a 1 px border.
static func panel(canvas: CanvasItem, rect: Rect2, border: Color = RULE) -> void:
	canvas.draw_rect(rect, GLASS)
	canvas.draw_rect(rect, border, false, 1.0)


## Text with its top-left corner at `at`.
static func text(canvas: CanvasItem, at: Vector2, s: String, size: int = 20, color: Color = TEXT, mono_font: bool = false) -> void:
	var font := mono() if mono_font else sans()
	canvas.draw_string(font, at + Vector2(0, font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Text right-aligned so that it ends at `right_x`.
static func text_right(canvas: CanvasItem, right_x: float, y: float, s: String, size: int = 20, color: Color = TEXT, mono_font: bool = true) -> void:
	var font := mono() if mono_font else sans()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(right_x - w, y + font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


## Text centred on `centre_x`.
static func text_centre(canvas: CanvasItem, centre_x: float, y: float, s: String, size: int = 20, color: Color = TEXT, mono_font: bool = false) -> void:
	var font := mono() if mono_font else sans()
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	canvas.draw_string(font, Vector2(centre_x - w / 2.0, y + font.get_ascent(size)), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func text_width(s: String, size: int = 20, mono_font: bool = false) -> float:
	var font := mono() if mono_font else sans()
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## An eyebrow: a two-digit number on a Gold-deep chip, then the label in Gold (`01 MARKET`).
static func eyebrow(canvas: CanvasItem, at: Vector2, number: int, label: String) -> void:
	var chip := Rect2(at, Vector2(34, 24))
	canvas.draw_rect(chip, GOLD_DEEP)
	text(canvas, at + Vector2(6, 2), "%02d" % number, 16, TEXT, true)
	text(canvas, at + Vector2(44, 2), label, 16, GOLD)


## A bar gauge: label above, figure right, a 4 px track and its fill (UI-DESIGN § Components).
static func bar(canvas: CanvasItem, rect: Rect2, label: String, fraction: float, figure: String, color: Color = TEXT) -> void:
	text(canvas, rect.position, label, 14, DIM)
	text_right(canvas, rect.end.x, rect.position.y, figure, 14, color)
	var track := Rect2(rect.position + Vector2(0, 22), Vector2(rect.size.x, 4))
	canvas.draw_rect(track, RULE)
	canvas.draw_rect(Rect2(track.position, Vector2(track.size.x * clampf(fraction, 0.0, 1.0), 4)), color)


## A key chip: `[Enter]`.
static func key_chip(canvas: CanvasItem, at: Vector2, key: String) -> float:
	var w := text_width(key, 14, true) + 12
	canvas.draw_rect(Rect2(at, Vector2(w, 22)), RULE, false, 1.0)
	text(canvas, at + Vector2(6, 2), key, 14, DIM, true)
	return w


## Flashing for danger bars: 8 ticks on, 8 off (RULES D.7.2).
static func flash_on(tick: int) -> bool:
	return (tick >> 3) & 1 == 0
