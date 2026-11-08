class_name PieceMeshes
extends RefCounted
## The pieces, built from code: turned (lathe) profiles for the round pieces, plus crenellations,
## a crown and a cross, and a faceted, extruded head for the knight. One square is 1 unit wide.

const SEGMENTS := 48
static var _cache := {}


## The mesh for a piece type (Chess.PAWN … Chess.KING), made once.
static func mesh(type: int) -> ArrayMesh:
	if not _cache.has(type):
		_cache[type] = _build(type)
	return _cache[type]


## A foot shared by every piece: a wide, softly chamfered base.
static func _foot(r := 0.36) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, 0), Vector2(r, 0), Vector2(r, 0.035), Vector2(r - 0.01, 0.055), Vector2(r - 0.03, 0.07),
		Vector2(r - 0.03, 0.07), Vector2(r - 0.05, 0.095), Vector2(r - 0.07, 0.12),
	])


static func _arc(center_y: float, radius: float, from_deg: float, to_deg: float, steps := 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		out.append(Vector2(cos(a) * radius, center_y + sin(a) * radius))
	return out


static func _build(type: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match type:
		Chess.PAWN:
			var p := _foot(0.32)
			p.append_array([Vector2(0.22, 0.15), Vector2(0.15, 0.2), Vector2(0.11, 0.3), Vector2(0.09, 0.4),
				Vector2(0.15, 0.43), Vector2(0.16, 0.455), Vector2(0.15, 0.475), Vector2(0.08, 0.49)])
			p.append_array(_arc(0.6, 0.135, -55, 90, 12))
			_lathe(st, p)
		Chess.ROOK:
			var p := _foot(0.36)
			p.append_array([Vector2(0.26, 0.15), Vector2(0.21, 0.2), Vector2(0.19, 0.3), Vector2(0.185, 0.55),
				Vector2(0.21, 0.58), Vector2(0.255, 0.6), Vector2(0.255, 0.6), Vector2(0.255, 0.74), Vector2(0.255, 0.74),
				Vector2(0.17, 0.74), Vector2(0.17, 0.74), Vector2(0.17, 0.71), Vector2(0, 0.71)])
			_lathe(st, p)
			# Six merlons around the top.
			for i in 6:
				var a := TAU * i / 6.0
				_box(st, Vector3(cos(a) * 0.212, 0.79, sin(a) * 0.212), Vector3(0.085, 0.1, 0.13), a)
		Chess.BISHOP:
			var p := _foot(0.34)
			p.append_array([Vector2(0.24, 0.15), Vector2(0.15, 0.22), Vector2(0.11, 0.35), Vector2(0.095, 0.52),
				Vector2(0.17, 0.56), Vector2(0.175, 0.585), Vector2(0.16, 0.6), Vector2(0.1, 0.615),
				Vector2(0.135, 0.66), Vector2(0.158, 0.72), Vector2(0.15, 0.79), Vector2(0.12, 0.86),
				Vector2(0.075, 0.915), Vector2(0.035, 0.94)])
			p.append_array(_arc(0.975, 0.045, -50, 90, 8))
			_lathe(st, p)
		Chess.QUEEN:
			var p := _foot(0.37)
			p.append_array([Vector2(0.27, 0.15), Vector2(0.17, 0.24), Vector2(0.125, 0.4), Vector2(0.11, 0.62),
				Vector2(0.19, 0.67), Vector2(0.2, 0.7), Vector2(0.185, 0.72), Vector2(0.115, 0.74),
				Vector2(0.13, 0.82), Vector2(0.2, 0.96), Vector2(0.215, 0.99), Vector2(0.2, 1.0),
				Vector2(0.15, 0.99), Vector2(0.1, 1.03), Vector2(0.05, 1.05)])
			p.append_array(_arc(1.09, 0.05, -50, 90, 8))
			_lathe(st, p)
			for i in 9:
				var a := TAU * i / 9.0
				_sphere(st, Vector3(cos(a) * 0.2, 1.015, sin(a) * 0.2), 0.03)
		Chess.KING:
			var p := _foot(0.38)
			p.append_array([Vector2(0.28, 0.15), Vector2(0.18, 0.25), Vector2(0.13, 0.42), Vector2(0.115, 0.68),
				Vector2(0.2, 0.73), Vector2(0.21, 0.76), Vector2(0.195, 0.78), Vector2(0.12, 0.8),
				Vector2(0.135, 0.88), Vector2(0.19, 1.04), Vector2(0.19, 1.04), Vector2(0.19, 1.07), Vector2(0.19, 1.07),
				Vector2(0.15, 1.1), Vector2(0.08, 1.13), Vector2(0.0, 1.14)])
			_lathe(st, p)
			_box(st, Vector3(0, 1.25, 0), Vector3(0.06, 0.24, 0.06), 0)
			_box(st, Vector3(0, 1.27, 0), Vector3(0.17, 0.06, 0.06), 0)
		Chess.KNIGHT:
			_lathe(st, _foot(0.36) + PackedVector2Array([Vector2(0.27, 0.15), Vector2(0.24, 0.19), Vector2(0, 0.19)]))
			_knight_head(st)
	return st.commit()


## Turns a profile (radius, height) around the vertical axis.
static func _lathe(st: SurfaceTool, profile: PackedVector2Array) -> void:
	var rings: Array[PackedVector3Array] = []
	for pt in profile:
		var ring := PackedVector3Array()
		for i in SEGMENTS + 1:
			var a := TAU * i / SEGMENTS
			ring.append(Vector3(cos(a) * pt.x, pt.y, sin(a) * pt.x))
		rings.append(ring)
	# Smooth normals from the profile's slope; a point repeated in the profile makes a crisp edge.
	var normals: Array[Vector2] = []
	for k in profile.size():
		var prev := profile[max(k - 1, 0)]
		var next := profile[min(k + 1, profile.size() - 1)]
		if k > 0 and profile[k] == profile[k - 1]:
			prev = profile[k]
		if k < profile.size() - 1 and profile[k] == profile[k + 1]:
			next = profile[k]
		var t := (next - prev)
		if t.length() < 1e-6:
			t = profile[min(k + 1, profile.size() - 1)] - profile[max(k - 1, 0)]
		normals.append(Vector2(t.y, -t.x).normalized())
	for j in rings.size() - 1:
		if profile[j] == profile[j + 1]:
			continue
		# Normals for the segment's two ends: at a repeated (crisp) point, use the segment's own slope.
		var seg := profile[j + 1] - profile[j]
		var flat := Vector2(seg.y, -seg.x).normalized()
		var n0 := flat if (j > 0 and profile[j] == profile[j - 1]) else normals[j]
		var n1 := flat if (j + 2 < profile.size() and profile[j + 1] == profile[j + 2]) else normals[j + 1]
		for i in SEGMENTS:
			var a0 := TAU * i / SEGMENTS
			var a1 := TAU * (i + 1) / SEGMENTS
			var va := rings[j][i]
			var vb := rings[j][i + 1]
			var vc := rings[j + 1][i + 1]
			var vd := rings[j + 1][i]
			var na := Vector3(cos(a0) * n0.x, n0.y, sin(a0) * n0.x)
			var nb := Vector3(cos(a1) * n0.x, n0.y, sin(a1) * n0.x)
			var nc := Vector3(cos(a1) * n1.x, n1.y, sin(a1) * n1.x)
			var nd := Vector3(cos(a0) * n1.x, n1.y, sin(a0) * n1.x)
			_smooth_tri(st, [va, vb, vc], [na, nb, nc])
			_smooth_tri(st, [va, vc, vd], [na, nc, nd])


## A triangle with a normal per corner, wound to face the way the normals point.
static func _smooth_tri(st: SurfaceTool, v: Array, n: Array) -> void:
	var avg: Vector3 = n[0] + n[1] + n[2]
	var order := [0, 1, 2]
	if (v[1] - v[0]).cross(v[2] - v[0]).dot(avg) > 0:
		order = [0, 2, 1]
	for k in order:
		st.set_normal(n[k])
		st.add_vertex(v[k])


static func _box(st: SurfaceTool, center: Vector3, size: Vector3, angle: float) -> void:
	var basis := Basis(Vector3.UP, -angle)
	var h := size / 2.0
	var corners := []
	for z in [-1, 1]:
		for y in [-1, 1]:
			for x in [-1, 1]:
				corners.append(center + basis * Vector3(x * h.x, y * h.y, z * h.z))
	# Corner index: x + 2y + 4z (0 or 1 each).
	var faces := [[0, 4, 6, 2], [1, 3, 7, 5], [0, 1, 5, 4], [2, 6, 7, 3], [0, 2, 3, 1], [4, 5, 7, 6]]
	for f in faces:
		_flat_quad(st, corners[f[0]], corners[f[1]], corners[f[2]], corners[f[3]], center)


## A quad with its own vertices, so it shades flat, facing away from `inside`.
static func _flat_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, inside: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot((a + c) / 2.0 - inside) < 0:
		n = -n
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## A triangle facing `n`. Godot draws the side whose vertices run clockwise.
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	if (b - a).cross(c - a).dot(n) > 0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.add_vertex(v)


static func _sphere(st: SurfaceTool, c: Vector3, r: float) -> void:
	var rings := 6
	var segs := 10
	for j in rings:
		for i in segs:
			var pts := []
			for dj in [0, 1]:
				for di in [0, 1]:
					var th: float = PI * (j + dj) / rings
					var ph: float = TAU * (i + di) / segs
					pts.append(c + Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph)) * r)
			_smooth_tri(st, [pts[0], pts[1], pts[3]], [(pts[0] - c).normalized(), (pts[1] - c).normalized(), (pts[3] - c).normalized()])
			_smooth_tri(st, [pts[0], pts[3], pts[2]], [(pts[0] - c).normalized(), (pts[3] - c).normalized(), (pts[2] - c).normalized()])


## The knight's head: oval cross-sections swept along a spine that rises up the neck and turns
## forward and down to the muzzle (facing +X), with ears and a mane.
static func _knight_head(st: SurfaceTool) -> void:
	var p0 := Vector2(0.0, 0.17)
	var p1 := Vector2(-0.09, 0.6)
	var p2 := Vector2(0.0, 0.92)
	var p3 := Vector2(0.36, 0.66)
	var steps := 26
	var ring := 28
	var centers: Array[Vector2] = []
	var tangents: Array[Vector2] = []
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		centers.append(u * u * u * p0 + 3 * u * u * t * p1 + 3 * u * t * t * p2 + t * t * t * p3)
		tangents.append((3 * u * u * (p1 - p0) + 6 * u * t * (p2 - p1) + 3 * t * t * (p3 - p2)).normalized())
	# Half-depth (front to back, in the profile) and half-width (side to side) along the spine.
	var depth := func(t: float) -> float:
		return 0.2 + 0.05 * exp(-pow((t - 0.12) / 0.12, 2)) - 0.11 * smoothstep(0.35, 1.0, t)
	var width := func(t: float) -> float:
		return 0.135 - 0.05 * smoothstep(0.3, 1.0, t)
	var rings: Array = []
	var norms: Array = []
	for i in steps + 1:
		var t := float(i) / steps
		var c := centers[i]
		var tg := tangents[i]
		var n2 := Vector2(-tg.y, tg.x)          # in the profile, perpendicular to the spine (towards the back)
		var a: float = depth.call(t)
		var b: float = width.call(t)
		var pts := PackedVector3Array()
		var ns := PackedVector3Array()
		for k in ring + 1:
			var th := TAU * k / ring
			var off := n2 * a * cos(th)
			pts.append(Vector3(c.x + off.x, c.y + off.y, b * sin(th)))
			var nn := Vector3(n2.x * cos(th) / a, n2.y * cos(th) / a, sin(th) / b)
			ns.append(nn.normalized())
		rings.append(pts)
		norms.append(ns)
	for i in steps:
		for k in ring:
			_smooth_tri(st, [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1]], [norms[i][k], norms[i][k + 1], norms[i + 1][k + 1]])
			_smooth_tri(st, [rings[i][k], rings[i + 1][k + 1], rings[i + 1][k]], [norms[i][k], norms[i + 1][k + 1], norms[i + 1][k]])
	# Round off the muzzle.
	var tip := centers[steps] + tangents[steps] * 0.05
	var tip3 := Vector3(tip.x, tip.y, 0)
	for k in ring:
		var a3: Vector3 = rings[steps][k]
		var b3: Vector3 = rings[steps][k + 1]
		var dir := Vector3(tangents[steps].x, tangents[steps].y, 0)
		_smooth_tri(st, [a3, b3, tip3], [norms[steps][k], norms[steps][k + 1], dir])
	# Ears, on top at the back of the head.
	var head_t := 18
	var hc := centers[head_t]
	var back := Vector2(-tangents[head_t].y, tangents[head_t].x)
	for side in [-1.0, 1.0]:
		var base := Vector3(hc.x + back.x * 0.05, hc.y + back.y * 0.05 + 0.06, side * 0.045)
		_cone(st, base, Vector3(-0.04, 0.14, side * 0.015), 0.035)
	# A mane down the back of the neck.
	for i in range(3, 17):
		var t := float(i) / steps
		var c := centers[i]
		var tg := tangents[i]
		var bk := Vector2(-tg.y, tg.x)
		var at: Vector2 = c + bk * (float(depth.call(t)) - 0.012)
		_box(st, Vector3(at.x, at.y, 0), Vector3(0.05, 0.035, 0.05), 0)


## A cone from `base` along `axis`, `r` wide at the base.
static func _cone(st: SurfaceTool, base: Vector3, axis: Vector3, r: float) -> void:
	var up := axis.normalized()
	var side := up.cross(Vector3.FORWARD).normalized()
	var other := up.cross(side).normalized()
	var tip := base + axis
	var seg := 10
	for k in seg:
		var a0 := TAU * k / seg
		var a1 := TAU * (k + 1) / seg
		var v0 := base + (side * cos(a0) + other * sin(a0)) * r
		var v1 := base + (side * cos(a1) + other * sin(a1)) * r
		_smooth_tri(st, [v0, v1, tip], [(v0 - base).normalized(), (v1 - base).normalized(), up])
