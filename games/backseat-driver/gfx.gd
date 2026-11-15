extends RefCounted
## Small drawing helpers. `c` is the CanvasItem that is currently inside _draw().

const W := 1280.0
const H := 720.0
const HORIZON := 285.0
const ROAD_B := 600.0

var c: CanvasItem
var font: Font


func _init(canvas: CanvasItem) -> void:
	c = canvas
	font = ThemeDB.fallback_font


## Ground point at lateral offset x (world px at scale 1) and screen-scale s.
func P(x: float, s: float) -> Vector2:
	return Vector2(W * 0.5 + x * s, HORIZON + (ROAD_B - HORIZON) * s)


## Approach progress 0..1 -> screen scale (quadratic so things rush in).
func scale_of(d: float) -> float:
	return 0.03 + d * d


func el(ctr: Vector2, rx: float, ry: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a: float = TAU * float(i) / 20.0
		pts.append(ctr + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, col)


func rc(ctr: Vector2, w: float, h: float, col: Color) -> void:
	c.draw_rect(Rect2(ctr - Vector2(w, h) * 0.5, Vector2(w, h)), col)


func poly(pts: Array, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array(pts), col)


func line(a: Vector2, b: Vector2, col: Color, w: float) -> void:
	c.draw_line(a, b, col, maxf(1.0, w))


func txt(s: String, pos: Vector2, fs: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0, shadow: bool = true) -> void:
	if shadow:
		c.draw_string(font, pos + Vector2(2, 2), s, align, width, fs, Color(0, 0, 0, 0.7))
	c.draw_string(font, pos, s, align, width, fs, col)


## Rounded-ish panel with an outline.
func panel(r: Rect2, fill: Color, edge: Color) -> void:
	c.draw_rect(r, fill)
	c.draw_rect(r, edge, false, 3.0)


## A speech bubble. Returns its height so callers can stack things under it.
func bubble(pos: Vector2, text: String, width: float, fill: Color, ink: Color, fs: int = 18) -> float:
	var sz: Vector2 = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, fs)
	var r := Rect2(pos, Vector2(width + 24.0, sz.y + 20.0))
	panel(r, fill, ink)
	c.draw_multiline_string(font, pos + Vector2(12, 10 + font.get_ascent(fs)), text, HORIZONTAL_ALIGNMENT_LEFT, width, fs, -1, ink)
	return r.size.y


## A simple stick-and-block person. g = feet, h = total height in px.
func person(g: Vector2, h: float, shirt: Color, skin: Color, walk: float, hair: Color) -> void:
	var sw: float = sin(walk) * h * 0.12
	var legc := Color("2b2b3a")
	var hip: Vector2 = g + Vector2(0, -h * 0.45)
	line(hip, g + Vector2(sw, 0), legc, h * 0.09)
	line(hip, g + Vector2(-sw, 0), legc, h * 0.09)
	rc(g + Vector2(0, -h * 0.65), h * 0.28, h * 0.4, shirt)
	line(g + Vector2(0, -h * 0.8), g + Vector2(sw * 1.3, -h * 0.55), skin, h * 0.07)
	line(g + Vector2(0, -h * 0.8), g + Vector2(-sw * 1.3, -h * 0.55), skin, h * 0.07)
	c.draw_circle(g + Vector2(0, -h * 0.9), h * 0.1, skin)
	el(g + Vector2(0, -h * 0.96), h * 0.1, h * 0.055, hair)


## A road sign plate. shape: diamond / octagon / circle / rect.
func sign_plate(shape: String, ctr: Vector2, size: float, col: Color, ink: Color, glyph: String) -> void:
	var r: float = size * 0.5
	var pts: Array = []
	match shape:
		"diamond":
			var k: float = r * 1.3
			pts = [ctr + Vector2(0, -k), ctr + Vector2(k, 0), ctr + Vector2(0, k), ctr + Vector2(-k, 0)]
		"octagon":
			for i in 8:
				var a: float = PI / 8.0 + float(i) * PI / 4.0
				pts.append(ctr + Vector2(cos(a), sin(a)) * r * 1.15)
		"circle":
			for i in 24:
				var a2: float = TAU * float(i) / 24.0
				pts.append(ctr + Vector2(cos(a2), sin(a2)) * r * 1.1)
		_:
			pts = [ctr + Vector2(-r * 1.15, -r * 0.95), ctr + Vector2(r * 1.15, -r * 0.95), ctr + Vector2(r * 1.15, r * 0.95), ctr + Vector2(-r * 1.15, r * 0.95)]
	poly(pts, col)
	var loop: Array = pts.duplicate()
	loop.append(pts[0])
	c.draw_polyline(PackedVector2Array(loop), Color("111111"), maxf(1.0, size * 0.04))
	if size < 34.0:
		return
	var lines: PackedStringArray = glyph.split("\n")
	var fs: int = int(size * (0.3 if glyph.length() <= 4 else 0.2))
	for i in lines.size():
		var y: float = ctr.y + (float(i) - float(lines.size() - 1) * 0.5) * float(fs) * 1.1 + float(fs) * 0.35
		txt(lines[i], Vector2(ctr.x - r * 1.1, y), fs, ink, HORIZONTAL_ALIGNMENT_CENTER, r * 2.2, false)
