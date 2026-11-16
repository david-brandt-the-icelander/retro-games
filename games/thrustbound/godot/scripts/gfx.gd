extends RefCounted
## Procedural drawing helpers. Colours above 1.0 are HDR and bloom via the glow pass.

static var _soft: Texture2D
static var _fade: Curve


static func soft() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_soft = t
	return _soft


static func fade_curve() -> Curve:
	if _fade == null:
		_fade = Curve.new()
		_fade.add_point(Vector2(0, 1))
		_fade.add_point(Vector2(1, 0))
	return _fade


static func ramp(colors: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(colors.size() - 1))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	return g


## Multiply rgb only (keeps alpha).
static func hdr(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func with_alpha(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


static func glow(ci: CanvasItem, pos: Vector2, radius: float, color: Color) -> void:
	ci.draw_texture_rect(soft(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, color)


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var p := pts.duplicate()
	p.append(pts[0])
	return p


## Cylinder-ish horizontal shading: light band at ~35% across.
static func hgrad_rect(ci: CanvasItem, r: Rect2, edge: Color, mid: Color) -> void:
	var x0 := r.position.x
	var x1 := r.position.x + r.size.x * 0.35
	var x2 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	var dark := edge.darkened(0.4)
	ci.draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]),
		PackedColorArray([edge, mid, mid, edge]))
	ci.draw_polygon(PackedVector2Array([Vector2(x1, y0), Vector2(x2, y0), Vector2(x2, y1), Vector2(x1, y1)]),
		PackedColorArray([mid, dark, dark, mid]))


static func vgrad_rect(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


static func model(i: int) -> Dictionary:
	match i % 4:
		0:
			return {"body": Color(0.92, 0.93, 0.97), "accent": Color(0.9, 0.22, 0.28), "fuel": Color(0.6, 2.4, 1.0)}
		1:
			return {"body": Color(0.72, 0.78, 0.86), "accent": Color(0.15, 0.55, 0.95), "fuel": Color(0.4, 1.6, 2.6)}
		2:
			return {"body": Color(0.95, 0.82, 0.55), "accent": Color(0.45, 0.2, 0.7), "fuel": Color(2.2, 0.6, 2.4)}
		_:
			return {"body": Color(0.42, 0.45, 0.52), "accent": Color(0.55, 0.9, 0.2), "fuel": Color(2.6, 1.6, 0.4)}


## One rocket segment (0 = engine, 1 = mid, 2 = nose) centred at c. fill = fuel level 0..1.
static func draw_segment(ci: CanvasItem, index: int, model_i: int, c: Vector2, fill: float) -> void:
	var m := model(model_i)
	var body: Color = m["body"]
	var accent: Color = m["accent"]
	var fuelc: Color = m["fuel"]
	var hw := 20.0
	var hh := W_SEG_H * 0.5
	var r := Rect2(c.x - hw, c.y - hh, hw * 2.0, hh * 2.0)
	var outline := Color(0.05, 0.05, 0.1, 0.45)
	var channel := Rect2()
	match index:
		0:
			# fins
			for s in [-1.0, 1.0]:
				var fin := PackedVector2Array([
					Vector2(c.x + s * 18.0, c.y - 8.0),
					Vector2(c.x + s * 34.0, c.y + 22.0),
					Vector2(c.x + s * 34.0, c.y + 33.0),
					Vector2(c.x + s * 18.0, c.y + 24.0),
				])
				ci.draw_colored_polygon(fin, accent.darkened(0.15 if s < 0 else 0.4))
			# nozzle
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(c.x - 11, c.y + 25), Vector2(c.x + 11, c.y + 25),
				Vector2(c.x + 15, c.y + 31), Vector2(c.x - 15, c.y + 31)]), Color(0.22, 0.23, 0.28))
			ci.draw_rect(Rect2(c.x - 15, c.y + 29, 30, 2), Color(0.5, 0.5, 0.55))
			hgrad_rect(ci, r, body.darkened(0.25), body)
			ci.draw_rect(Rect2(c.x - hw, c.y + 12, hw * 2.0, 6), accent)
			ci.draw_rect(Rect2(c.x - hw, c.y + 12, hw * 2.0, 2), accent.lightened(0.3))
			for k in 4:
				ci.draw_circle(Vector2(c.x - 14 + k * 9.3, c.y - 20), 1.2, body.darkened(0.45))
			channel = Rect2(c.x + 8, c.y - 19, 5, 28)
		1:
			hgrad_rect(ci, r, body.darkened(0.25), body)
			ci.draw_rect(Rect2(c.x - hw, c.y - hh, hw * 2.0, 3), body.darkened(0.35))
			ci.draw_rect(Rect2(c.x - hw, c.y + hh - 3, hw * 2.0, 3), body.darkened(0.35))
			# porthole
			var pc := Vector2(c.x - 4, c.y - 6)
			ci.draw_circle(pc, 10.5, Color(0.2, 0.21, 0.27))
			ci.draw_circle(pc, 7.5, Color(0.12, 0.45, 0.9))
			ci.draw_circle(pc + Vector2(1.5, 1.5), 5.0, Color(0.08, 0.25, 0.55))
			ci.draw_circle(pc + Vector2(-2.5, -2.5), 2.2, Color(1.6, 1.9, 2.2))
			ci.draw_rect(Rect2(c.x - hw, c.y + 12, hw * 2.0, 4), accent)
			channel = Rect2(c.x + 9, c.y - 21, 5, 42)
		2:
			var pts := PackedVector2Array()
			var steps := 14
			for i in steps + 1:
				var u := float(i) / float(steps)
				var y := c.y + hh - u * (hh * 2.0 + 8.0)
				pts.append(Vector2(c.x - hw * sqrt(1.0 - u * 0.985), y))
			for i in range(steps, -1, -1):
				var u := float(i) / float(steps)
				var y := c.y + hh - u * (hh * 2.0 + 8.0)
				pts.append(Vector2(c.x + hw * sqrt(1.0 - u * 0.985), y))
			ci.draw_colored_polygon(pts, body)
			# shade right half
			var shade := PackedVector2Array()
			for i in steps + 1:
				var u := float(i) / float(steps)
				var y := c.y + hh - u * (hh * 2.0 + 8.0)
				shade.append(Vector2(c.x + hw * 0.3 * sqrt(1.0 - u * 0.985), y))
			for i in range(steps, -1, -1):
				var u := float(i) / float(steps)
				var y := c.y + hh - u * (hh * 2.0 + 8.0)
				shade.append(Vector2(c.x + hw * sqrt(1.0 - u * 0.985), y))
			ci.draw_colored_polygon(shade, Color(0, 0, 0, 0.22))
			ci.draw_polyline(closed(pts), outline, 1.0, true)
			ci.draw_rect(Rect2(c.x - hw, c.y + hh - 9, hw * 2.0, 5), accent)
			ci.draw_circle(Vector2(c.x, c.y - hh - 7), 2.5, hdr(accent, 2.6))
			channel = Rect2(c.x + 4, c.y - 4, 4, 18)
	if index != 2:
		ci.draw_rect(r, outline, false, 1.0)
	# fuel gauge channel
	ci.draw_rect(channel, Color(0.06, 0.06, 0.1))
	if fill > 0.0:
		var h := channel.size.y * clampf(fill, 0.0, 1.0)
		ci.draw_rect(Rect2(channel.position.x, channel.end.y - h, channel.size.x, h), fuelc)


const W_SEG_H := 54.0
