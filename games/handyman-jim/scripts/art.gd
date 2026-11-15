class_name Art
## Shared drawing helpers in a cartoon style: rounded shapes with dark ink outlines,
## soft gradients, big-headed characters. All colours come from Pal.

const INK := Color(0.165, 0.133, 0.188, 0.9)
const OUT := 1.3            # outline width in logical pixels (2.6px on a 1280x800 window)

static var _dither_cache := {}

static func dither(c1: Color, c2: Color) -> ImageTexture:
	var key := c1.to_html() + c2.to_html()
	if _dither_cache.has(key):
		return _dither_cache[key]
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, c1)
	img.set_pixel(1, 1, c1)
	img.set_pixel(1, 0, c2)
	img.set_pixel(0, 1, c2)
	var tex := ImageTexture.create_from_image(img)
	_dither_cache[key] = tex
	return tex

## Soft vertical gradient between two palette colours (used for grass, walls, floors, water).
static func dfill(ci: CanvasItem, r: Rect2, c1: Color, c2: Color) -> void:
	var top := c1.lerp(c2, 0.45)
	var bot := c1.lerp(c2, 0.1).darkened(0.06)
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bot, bot]))

static func rr_points(r: Rect2, rad: float) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.45)
	if rad < 0.75:
		return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	var pts := PackedVector2Array()
	var corners := [[r.end.x - rad, r.position.y + rad, -PI / 2], [r.end.x - rad, r.end.y - rad, 0.0],
		[r.position.x + rad, r.end.y - rad, PI / 2], [r.position.x + rad, r.position.y + rad, PI]]
	for c in corners:
		for k in 5:
			var a: float = c[2] + k * (PI / 2) / 4.0
			pts.append(Vector2(c[0], c[1]) + Vector2.from_angle(a) * rad)
	return pts

static func outline(ci: CanvasItem, pts: PackedVector2Array, w: float = OUT, col: Color = INK) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, w, true)

## Rounded rectangle with an ink outline.
static func rrect(ci: CanvasItem, r: Rect2, fill: Color, rad: float = 4.0, line: bool = true) -> void:
	if r.size.x <= 0 or r.size.y <= 0:
		return
	var pts := rr_points(r, rad)
	ci.draw_colored_polygon(pts, fill)
	if line:
		outline(ci, pts, OUT, Color(INK, INK.a * fill.a))

## Drop-in for draw_rect: big backdrops and thin strips stay plain, objects get the cartoon treatment.
static func shape(ci: CanvasItem, r: Rect2, col: Color, _filled: bool = true) -> void:
	r = r.abs()
	if r.size.x >= 480 or r.size.y >= 230 or r.size.x <= 4 or r.size.y <= 4:
		ci.draw_rect(r, col)
	else:
		rrect(ci, r, col, minf(5.0, minf(r.size.x, r.size.y) * 0.3))

static func ellipse_points(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, fill: Color, line: bool = true, w: float = OUT) -> void:
	var pts := ellipse_points(c, rx, ry, clampi(int(maxf(rx, ry) * 1.5), 12, 40))
	ci.draw_colored_polygon(pts, fill)
	if line:
		outline(ci, pts, w, Color(INK, INK.a * fill.a))

## Drop-in for draw_circle with an outline.
static func circ(ci: CanvasItem, c: Vector2, r: float, fill: Color) -> void:
	ellipse(ci, c, r, r, fill, r >= 2.5)

static func circ_w(ci: CanvasItem, c: Vector2, r: float, fill: Color, w: float) -> void:
	ellipse(ci, c, r, r, fill, true, w)

## A thick limb: ink line under a coloured line, both with round ends.
static func limb(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	ci.draw_line(a, b, INK, w + OUT * 2, true)
	ci.draw_circle(a, (w + OUT * 2) / 2, INK)
	ci.draw_circle(b, (w + OUT * 2) / 2, INK)
	ci.draw_line(a, b, col, w, true)
	ci.draw_circle(a, w / 2, col)
	ci.draw_circle(b, w / 2, col)

static func text(ci: CanvasItem, pos: Vector2, s: String, col: Color = Pal.WHITE,
		size: int = 12, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	ci.draw_string(Game.font, pos, s, align, width, size, col)

static func text_shadow(ci: CanvasItem, pos: Vector2, s: String, col: Color = Pal.WHITE,
		size: int = 12, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1) -> void:
	ci.draw_string_outline(Game.font, pos, s, align, width, size, 3, Pal.BLACK)
	ci.draw_string(Game.font, pos, s, align, width, size, col)

## Speech-bubble style panel used by dialogs.
static func box(ci: CanvasItem, r: Rect2, fill: Color = Pal.WHITE, border: Color = Pal.RED) -> void:
	ci.draw_colored_polygon(rr_points(Rect2(r.position + Vector2(4, 5), r.size), 12), Color(0, 0, 0, 0.35))
	ci.draw_colored_polygon(rr_points(r, 12), border)
	ci.draw_colored_polygon(rr_points(r.grow(-4), 9), fill)
	outline(ci, rr_points(r, 12), 2.0, INK)

const SKIN := Color("f2b48a")

## Cartoon person, feet at `feet`, about 50*s tall. facing = 1 right / -1 left.
static func person(ci: CanvasItem, feet: Vector2, s: float, shirt: Color, pants: Color,
		hat: Color, skin: Color = SKIN, hair: Color = Pal.BROWN,
		beard: bool = false, facing: int = 1, phase: float = 0.0) -> void:
	var x := feet.x
	var y := feet.y
	var f := float(facing)
	var swing := sin(phase) * 4.0 * s
	ci.draw_colored_polygon(ellipse_points(Vector2(x, y), 11 * s, 2.5 * s), Color(0, 0, 0, 0.25))
	# legs and shoes
	limb(ci, Vector2(x - 3 * s, y - 18 * s), Vector2(x - 3 * s + swing, y - 3 * s), 4.5 * s, pants)
	limb(ci, Vector2(x + 3 * s, y - 18 * s), Vector2(x + 3 * s - swing, y - 3 * s), 4.5 * s, pants)
	ellipse(ci, Vector2(x - 3 * s + swing + f * 1.5 * s, y - 1.8 * s), 3.8 * s, 2.2 * s, Pal.BLACK)
	ellipse(ci, Vector2(x + 3 * s - swing + f * 1.5 * s, y - 1.8 * s), 3.8 * s, 2.2 * s, Pal.BLACK)
	# back arm, body, front arm
	limb(ci, Vector2(x - f * 4 * s, y - 32 * s), Vector2(x - f * 5 * s - swing * 0.6, y - 21 * s), 3.5 * s, shirt.darkened(0.15))
	rrect(ci, Rect2(x - 7.5 * s, y - 37 * s, 15 * s, 21 * s), shirt, 6 * s)
	limb(ci, Vector2(x + f * 4 * s, y - 32 * s), Vector2(x + f * 6 * s + swing * 0.6, y - 21 * s), 3.5 * s, shirt)
	circ(ci, Vector2(x + f * 6 * s + swing * 0.6, y - 20 * s), 2.3 * s, skin)
	# big round head
	var hc := Vector2(x + f * 1 * s, y - 45 * s)
	if not beard:
		ellipse(ci, hc + Vector2(-f * 1.5 * s, -2 * s), 8.2 * s, 7 * s, hair)
	circ(ci, hc, 7.5 * s, skin)
	circ(ci, hc + Vector2(f * 7.3 * s, 1 * s), 2.2 * s, skin)          # nose
	ellipse(ci, hc + Vector2(-f * 4.5 * s, 0.5 * s), 1.6 * s, 2.2 * s, skin)   # ear
	# eye: white with a pupil looking where we're facing
	ellipse(ci, hc + Vector2(f * 3.2 * s, -1.8 * s), 2.2 * s, 2.7 * s, Pal.WHITE)
	ci.draw_circle(hc + Vector2(f * 3.9 * s, -1.5 * s), 1.1 * s, Pal.BLACK)
	if beard:
		var bp := PackedVector2Array()
		for k in 13:
			var a := PI * 0.02 + PI * 0.96 * k / 12.0
			bp.append(hc + Vector2(cos(a) * 8.0 * s, sin(a) * 8.5 * s + 2.5 * s))
		# cheeks show above the beard line (points run left to right to keep the polygon simple)
		var c1 := hc + Vector2(-f * 3 * s, 4.5 * s)
		var c2 := hc + Vector2(f * 5 * s, 3.5 * s)
		bp.append(hc + Vector2(-7.5 * s, 1.5 * s))
		bp.append(c1 if c1.x < c2.x else c2)
		bp.append(c2 if c1.x < c2.x else c1)
		bp.append(hc + Vector2(7.5 * s, 1.5 * s))
		ci.draw_colored_polygon(bp, hair)
		outline(ci, bp, OUT, INK)
		circ(ci, hc + Vector2(f * 7.3 * s, 1 * s), 2.2 * s, skin)      # nose sits on the beard
		ci.draw_arc(hc + Vector2(f * 3.5 * s, 5 * s), 1.8 * s, 0.2, 2.9, 8, Pal.BLACK, 0.9 * s, true)   # grin
	else:
		ci.draw_arc(hc + Vector2(f * 3 * s, 3 * s), 2.2 * s, 0.3, 2.6, 8, Pal.BLACK, 0.9 * s, true)
	if hat.a > 0:
		var dome := PackedVector2Array()
		for k in 13:
			dome.append(hc + Vector2(0, -4 * s) + Vector2.from_angle(PI + PI * k / 12.0) * Vector2(8 * s, 6.5 * s))
		ci.draw_colored_polygon(dome, hat)
		outline(ci, dome, OUT, INK)
		rrect(ci, Rect2(hc.x + (2.0 if f > 0 else -12.0) * s, hc.y - 5.5 * s, 10 * s, 2.4 * s), hat.darkened(0.15), 1.2 * s)

const BLOND := Color("ffe11a")         # bright yellow hair

const JIM_SKIN := Color("ffdcc4")     # fair, a little sunburnt
const SHORTS := Color("4f7fc4")       # faded denim

## Handyman Jim: blond and balding, fair-skinned, beer belly in a white T-shirt, denim shorts,
## white sneakers, blue eyes and a big grin. Clean-shaven.
static func jim(ci: CanvasItem, feet: Vector2, s: float, facing: int, phase: float) -> void:
	var x := feet.x
	var y := feet.y
	var f := float(facing)
	var swing := sin(phase) * 4.0 * s
	ci.draw_colored_polygon(ellipse_points(Vector2(x, y), 13 * s, 2.8 * s), Color(0, 0, 0, 0.25))
	# bare legs, white sneakers, then denim shorts from the hips to mid-thigh
	for side in [-1.0, 1.0]:
		var hip := Vector2(x + side * 3.5 * s, y - 14 * s)
		var foot := Vector2(x + side * 3.5 * s - side * swing, y - 3 * s)
		limb(ci, hip, foot, 4.2 * s, JIM_SKIN)
		ellipse(ci, foot + Vector2(f * 1.6 * s, 1.2 * s), 4.4 * s, 2.5 * s, Pal.WHITE)          # sneaker
	var shorts := PackedVector2Array([Vector2(x - 8.5 * s, y - 19 * s), Vector2(x + 8.5 * s, y - 19 * s),
		Vector2(x + 8 * s, y - 9.5 * s), Vector2(x + 0.8 * s, y - 9.5 * s), Vector2(x, y - 12 * s),
		Vector2(x - 0.8 * s, y - 9.5 * s), Vector2(x - 8 * s, y - 9.5 * s)])
	ci.draw_colored_polygon(shorts, SHORTS)
	outline(ci, shorts, OUT)
	# back arm, T-shirt torso, the beer belly pushing the shirt out the front
	var back_hand := Vector2(x - f * 6 * s - swing * 0.6, y - 21 * s)
	limb(ci, Vector2(x - f * 5 * s, y - 32 * s), back_hand, 3.6 * s, JIM_SKIN.darkened(0.08))
	limb(ci, Vector2(x - f * 5 * s, y - 33 * s), Vector2(x - f * 5.4 * s, y - 28 * s), 4.4 * s, Pal.WHITE.darkened(0.06))
	rrect(ci, Rect2(x - 8 * s, y - 37 * s, 16 * s, 19 * s), Pal.WHITE, 6 * s)
	ellipse(ci, Vector2(x + f * 2.5 * s, y - 24 * s), 11 * s, 8.5 * s, Pal.WHITE)   # hangs over the waistband
	ci.draw_colored_polygon(ellipse_points(Vector2(x + f * 5.5 * s, y - 26 * s), 3.5 * s, 2.6 * s), Color(1, 1, 1, 0.6))  # belly shine
	ci.draw_arc(Vector2(x + f * 6 * s, y - 20 * s), 1.4 * s, 0, TAU, 10, Pal.LGRAY, 0.8 * s, true)                      # belly button through the shirt
	# front arm: short sleeve, then bare forearm resting on the belly
	var hand := Vector2(x + f * 9.5 * s + swing * 0.5, y - 22 * s)
	limb(ci, Vector2(x + f * 5 * s, y - 33 * s), hand, 3.6 * s, JIM_SKIN)
	limb(ci, Vector2(x + f * 5 * s, y - 33 * s), Vector2(x + f * 6.5 * s, y - 28.5 * s), 4.4 * s, Pal.WHITE)
	circ(ci, hand + Vector2(0, 1 * s), 2.5 * s, JIM_SKIN)
	# head: big and round, a shiny bald patch on top, lots of blond hair round it.
	# Face lines are thin and scale with Jim, so his face never looks heavily inked.
	var fw := clampf(0.16 * s, 0.35, 0.9)      # face line width
	var hc := Vector2(x + f * 1 * s, y - 45.5 * s)
	# thick blond hair behind the head: shows round the back and sides
	ellipse(ci, hc + Vector2(-f * 2.4 * s, 1.6 * s), 8.4 * s, 8.0 * s, BLOND, true, fw)
	circ_w(ci, hc, 8 * s, JIM_SKIN, fw)
	ci.draw_colored_polygon(ellipse_points(hc + Vector2(f * 0.6 * s, -5.6 * s), 3.0 * s, 1.4 * s), Color(1, 1, 1, 0.6))  # shiny bald patch
	# a full fringe over the back of the head down past the ear
	ellipse(ci, hc + Vector2(-f * 4.6 * s, 1.0 * s), 3.8 * s, 6.2 * s, BLOND, false)
	# a generous comb-over swept across the top, stopping short of the shiny patch
	for k in 4:
		var a := hc + Vector2(-f * (6.2 - k * 0.6) * s, (-2.6 - k * 1.0) * s)
		var b := hc + Vector2(f * (0.8 + k * 0.7) * s, (-6.2 - k * 0.3) * s)
		ci.draw_line(a, b, BLOND.darkened(0.08), 0.55 * s, true)
	ellipse(ci, hc + Vector2(-f * 4.4 * s, 0.9 * s), 1.7 * s, 2.4 * s, JIM_SKIN, true, fw)   # ear
	# blue eye with a highlight, bushy blond eyebrow
	ellipse(ci, hc + Vector2(f * 3.4 * s, -1.6 * s), 2.4 * s, 2.8 * s, Pal.WHITE, true, fw)
	ci.draw_circle(hc + Vector2(f * 4.0 * s, -1.3 * s), 1.4 * s, Color("3b8fe0"))
	ci.draw_circle(hc + Vector2(f * 4.2 * s, -1.2 * s), 0.7 * s, Pal.BLACK)
	ci.draw_circle(hc + Vector2(f * 3.6 * s, -1.9 * s), 0.4 * s, Pal.WHITE)
	ci.draw_line(hc + Vector2(f * 1.5 * s, -5.0 * s), hc + Vector2(f * 5.3 * s, -5.5 * s), BLOND.darkened(0.12), 1.3 * s, true)
	# rosy cheek, round nose and a big clean-shaven toothy grin
	ci.draw_circle(hc + Vector2(f * 1.5 * s, 2.5 * s), 1.9 * s, Color(1, 0.45, 0.45, 0.35))
	circ_w(ci, hc + Vector2(f * 7.6 * s, 1.2 * s), 2.3 * s, JIM_SKIN.darkened(0.05), fw)
	var grin := PackedVector2Array()
	for k in 9:
		var ang := 0.15 + (PI - 0.3) * k / 8.0
		grin.append(hc + Vector2(f * 3.8 * s, 3.4 * s) + Vector2(cos(ang) * 3.6 * s, sin(ang) * 2.6 * s))
	ci.draw_colored_polygon(grin, Pal.WHITE)
	outline(ci, grin, fw)
	ci.draw_line(grin[0], grin[8], Pal.BLACK, fw, true)

## Top-down vehicle centred on pos, pointing along angle (0 = +x).
static func vehicle_top(ci: CanvasItem, pos: Vector2, angle: float, body: Color,
		kind: String = "car", t: float = 0.0) -> void:
	ci.draw_set_transform(pos + Vector2(2, 3), angle, Vector2.ONE)
	var L := 30.0 if kind != "van" else 36.0
	var W := 16.0 if kind != "van" else 19.0
	ci.draw_colored_polygon(rr_points(Rect2(-L / 2, -W / 2, L, W), 6), Color(0, 0, 0, 0.3))   # shadow
	ci.draw_set_transform(pos, angle, Vector2.ONE)
	for wx in [-L / 2 + 6, L / 2 - 7]:
		rrect(ci, Rect2(wx - 3, -W / 2 - 2, 6, 3), Pal.BLACK, 1.5, false)
		rrect(ci, Rect2(wx - 3, W / 2 - 1, 6, 3), Pal.BLACK, 1.5, false)
	rrect(ci, Rect2(-L / 2, -W / 2, L, W), body, 6)
	ci.draw_colored_polygon(rr_points(Rect2(-L / 2 + 3, -W / 2 + 2, L - 10, W * 0.35), 3), Color(1, 1, 1, 0.25))  # shine
	if kind == "van":
		rrect(ci, Rect2(-L / 2 + 1, -2, L - 10, 4), Pal.RED, 2, false)
		rrect(ci, Rect2(L / 2 - 10, -W / 2 + 2.5, 6, W - 5), Pal.LCYAN, 2.5)
		for lx in [-L / 2 + 4, -L / 2 + 9]:
			ci.draw_line(Vector2(lx, -W / 2 + 3), Vector2(lx, W / 2 - 3), Pal.DGRAY, 1.5, true)
	else:
		rrect(ci, Rect2(L / 2 - 12, -W / 2 + 2.5, 6, W - 5), Pal.LCYAN, 2.5)
		rrect(ci, Rect2(-L / 2 + 3, -W / 2 + 2.5, 5, W - 5), Pal.LCYAN, 2.5)
	if kind == "cop":
		var blink := int(t * 6.0) % 2 == 0
		rrect(ci, Rect2(-L / 2 + 1, -W / 2 + 1, 6, W - 2), Pal.BLACK, 2, false)
		rrect(ci, Rect2(L / 2 - 6, -W / 2 + 1, 5, W - 2), Pal.BLACK, 2, false)
		circ(ci, Vector2(0, -3.5), 3.2, Pal.LRED if blink else Pal.RED)
		circ(ci, Vector2(0, 3.5), 3.2, Pal.BLUE if blink else Pal.LBLUE)
	circ(ci, Vector2(L / 2 - 1.5, -W / 2 + 3), 1.8, Pal.YELLOW)
	circ(ci, Vector2(L / 2 - 1.5, W / 2 - 3), 1.8, Pal.YELLOW)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

## Side view of Jim's van, wheels on ground line at pos.y, front facing right.
static func van_side(ci: CanvasItem, pos: Vector2, s: float = 1.0) -> void:
	var x := pos.x
	var y := pos.y
	ci.draw_colored_polygon(ellipse_points(Vector2(x + 60 * s, y - 1 * s), 66 * s, 5 * s), Color(0, 0, 0, 0.25))
	var body := PackedVector2Array([Vector2(x, y - 14 * s), Vector2(x, y - 62 * s), Vector2(x + 90 * s, y - 62 * s),
		Vector2(x + 104 * s, y - 50 * s), Vector2(x + 120 * s, y - 40 * s), Vector2(x + 122 * s, y - 14 * s)])
	ci.draw_colored_polygon(body, Pal.WHITE)
	outline(ci, body, OUT * 1.4)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x + 92 * s, y - 58 * s), Vector2(x + 103 * s, y - 48 * s),
		Vector2(x + 103 * s, y - 40 * s), Vector2(x + 92 * s, y - 40 * s)]), Pal.LCYAN)
	rrect(ci, Rect2(x, y - 33 * s, 121 * s, 6 * s), Pal.RED, 2, false)
	ci.draw_line(Vector2(x + 4 * s, y - 68 * s), Vector2(x + 86 * s, y - 68 * s), Pal.DGRAY, 2.5 * s, true)  # ladder rack
	for i in 6:
		ci.draw_line(Vector2(x + (8 + i * 14) * s, y - 70 * s), Vector2(x + (8 + i * 14) * s, y - 62 * s), Pal.DGRAY, 1.5 * s, true)
	text(ci, Vector2(x + 6 * s, y - 40 * s), "HANDYMAN JIM", Pal.BLUE, int(11 * s))
	text(ci, Vector2(x + 8 * s, y - 17 * s), "WE FIX DUMB", Pal.RED, int(8 * s))
	for wx in [20, 96]:
		circ(ci, Vector2(x + wx * s, y - 8 * s), 9.5 * s, Pal.BLACK)
		circ(ci, Vector2(x + wx * s, y - 8 * s), 4.5 * s, Pal.LGRAY)

static func tree_top(ci: CanvasItem, pos: Vector2, r: float) -> void:
	ci.draw_colored_polygon(ellipse_points(pos + Vector2(4, 5), r, r), Color(0, 0, 0, 0.25))
	for k in 5:
		var o := Vector2.from_angle(k * TAU / 5 + r) * r * 0.45
		circ(ci, pos + o, r * 0.62, Pal.GREEN)
	ci.draw_circle(pos, r * 0.6, Pal.GREEN)
	ci.draw_circle(pos + Vector2(-r * 0.25, -r * 0.3), r * 0.35, Pal.LGREEN)

## Side-view leafy tree for scenes: a puffy cartoon canopy on a trunk.
static func tree_side(ci: CanvasItem, base: Vector2, h: float) -> void:
	rrect(ci, Rect2(base.x - h * 0.04, base.y - h * 0.5, h * 0.08, h * 0.5), Pal.BROWN, 3)
	var blobs := [[0.0, -0.66, 0.26], [-0.2, -0.55, 0.2], [0.2, -0.56, 0.2], [-0.1, -0.8, 0.18], [0.12, -0.78, 0.18]]
	for b in blobs:
		circ(ci, base + Vector2(b[0] * h, b[1] * h), b[2] * h, Pal.GREEN)
	for b in blobs:
		ci.draw_circle(base + Vector2(b[0] * h, b[1] * h), b[2] * h - 1.5, Pal.GREEN)
	ci.draw_circle(base + Vector2(-0.1 * h, -0.8 * h), 0.09 * h, Pal.LGREEN)
	ci.draw_circle(base + Vector2(-0.22 * h, -0.58 * h), 0.07 * h, Pal.LGREEN)

## Duke the dog: a round grey mutt with a wagging tail.
static func dog(ci: CanvasItem, feet: Vector2, s: float, t: float) -> void:
	var wag := sin(t * 10.0) * 4.0 * s
	limb(ci, Vector2(feet.x - 11 * s, feet.y - 11 * s), Vector2(feet.x - 17 * s, feet.y - 17 * s + wag), 2.2 * s, Pal.LGRAY)
	for lx in [-8, -3, 4, 8]:
		limb(ci, Vector2(feet.x + lx * s, feet.y - 8 * s), Vector2(feet.x + lx * s, feet.y - 1.5 * s), 2.4 * s, Pal.LGRAY)
	ellipse(ci, Vector2(feet.x - 1 * s, feet.y - 10 * s), 12 * s, 6 * s, Pal.LGRAY)
	circ(ci, Vector2(feet.x + 11 * s, feet.y - 16 * s), 5.5 * s, Pal.LGRAY)
	ellipse(ci, Vector2(feet.x + 16 * s, feet.y - 14.5 * s), 3.5 * s, 2.5 * s, Pal.LGRAY)
	ci.draw_circle(Vector2(feet.x + 19 * s, feet.y - 15 * s), 1.4 * s, Pal.BLACK)
	ellipse(ci, Vector2(feet.x + 8.5 * s, feet.y - 17 * s), 2.2 * s, 4 * s, Pal.DGRAY)   # floppy ear
	ci.draw_circle(Vector2(feet.x + 13 * s, feet.y - 18 * s), 1.1 * s, Pal.BLACK)

static func beer(ci: CanvasItem, base: Vector2, s: float = 1.0) -> void:
	ci.draw_arc(Vector2(base.x + 7 * s, base.y - 7 * s), 3 * s, -PI / 2, PI / 2, 8, Pal.LGRAY, 1.5 * s, true)
	rrect(ci, Rect2(base.x, base.y - 13 * s, 7 * s, 13 * s), Pal.YELLOW, 1.5 * s)
	ellipse(ci, Vector2(base.x + 3.5 * s, base.y - 13.5 * s), 4.5 * s, 2.5 * s, Pal.WHITE)

## Optional AI-art override: res://art/rooms/<key>.png drawn instead of code art.
static func try_png(ci: CanvasItem, key: String, r: Rect2) -> bool:
	var path := "res://art/rooms/%s.png" % key
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		ci.draw_texture_rect(tex, r, false)
		return true
	return false
