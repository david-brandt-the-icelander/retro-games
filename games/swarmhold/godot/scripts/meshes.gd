extends RefCounted
## Procedural meshes, textures and materials. Everything in the game is generated
## at runtime, so the project has no binary assets.

static var _cache := {}


static func gradient(offsets: Array, colors: Array) -> Gradient:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	return g


static func noise_texture(seed_val: int, freq: float, ramp: Gradient = null, normal := false,
		bump := 6.0, size := 512, octaves := 5) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed_val
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = size
	t.height = size
	t.seamless = true
	t.noise = n
	if normal:
		t.as_normal_map = true
		t.bump_strength = bump
	elif ramp:
		t.color_ramp = ramp
	return t


static func soft_dot(size := 64) -> GradientTexture2D:
	if _cache.has("soft_dot"):
		return _cache["soft_dot"]
	var t := GradientTexture2D.new()
	t.gradient = gradient([0.0, 0.45, 1.0], [Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = size
	t.height = size
	_cache["soft_dot"] = t
	return t


## A box with rounded (bevelled) edges. Bevels catch the low sun and give the
## city its chunky carved-stone look.
static func rounded_box(size: Vector3, r: float) -> ArrayMesh:
	var key := "rbox_%s_%s" % [size, r]
	if _cache.has(key):
		return _cache[key]
	var h := size * 0.5
	var inner := h - Vector3(r, r, r)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var axes := [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
	for a in 3:
		for s in [-1.0, 1.0]:
			var n: Vector3 = axes[a] * s
			var u: Vector3 = axes[(a + 1) % 3]
			var v: Vector3 = axes[(a + 2) % 3]
			var hu: float = absf(u.dot(h))
			var hv: float = absf(v.dot(h))
			var hn: float = absf(n.dot(h))
			var cu := _coords(hu, r)
			var cv := _coords(hv, r)
			for i in cu.size() - 1:
				for j in cv.size() - 1:
					var quad := []
					for k in [[i, j], [i + 1, j], [i + 1, j + 1], [i, j + 1]]:
						var p: Vector3 = n * hn + u * cu[k[0]] + v * cv[k[1]]
						quad.append(_round(p, inner, r))
					_tri(st, quad[0], quad[1], quad[2], n)
					_tri(st, quad[0], quad[2], quad[3], n)
	var mesh := st.commit()
	_cache[key] = mesh
	return mesh


static func _coords(half: float, r: float) -> Array:
	var inner := half - r
	return [-half, -half + r * 0.35, -inner, inner, half - r * 0.35, half]


static func _round(p: Vector3, inner: Vector3, r: float) -> Array:
	var q := p.clamp(-inner, inner)
	var d := p - q
	var n := d.normalized() if d.length() > 0.00001 else Vector3.UP
	return [q + n * r, n]


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, face_n: Vector3) -> void:
	# Godot treats clockwise triangles as front-facing.
	var cr: Vector3 = (b[0] - a[0]).cross(c[0] - a[0])
	if cr.dot(face_n) > 0.0:
		var tmp := b
		b = c
		c = tmp
	for vtx in [a, b, c]:
		st.set_normal(vtx[1])
		st.add_vertex(vtx[0])


static func sandstone_material() -> StandardMaterial3D:
	if _cache.has("sandstone"):
		return _cache["sandstone"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = noise_texture(11, 0.012, gradient([0.0, 0.45, 0.7, 1.0], [
		Color(0.60, 0.47, 0.34), Color(0.76, 0.62, 0.45), Color(0.83, 0.70, 0.52), Color(0.70, 0.55, 0.40)]))
	m.normal_enabled = true
	m.normal_texture = noise_texture(12, 0.03, null, true, 5.0)
	m.normal_scale = 0.9
	m.roughness = 0.92
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.35, 0.35, 0.35)
	m.vertex_color_use_as_albedo = true
	_cache["sandstone"] = m
	return m


static func sand_material() -> StandardMaterial3D:
	if _cache.has("sand"):
		return _cache["sand"]
	var m := StandardMaterial3D.new()
	m.albedo_texture = noise_texture(21, 0.006, gradient([0.0, 0.5, 1.0], [
		Color(0.66, 0.52, 0.36), Color(0.76, 0.62, 0.44), Color(0.72, 0.57, 0.40)]), false, 6.0, 512, 4)
	m.normal_enabled = true
	m.normal_texture = noise_texture(22, 0.05, null, true, 3.0)
	m.normal_scale = 0.6
	m.roughness = 1.0
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.08, 0.08, 0.08)
	_cache["sand"] = m
	return m


static func unshaded(color: Color, additive := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func sphere(r: float, segs := 24) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = segs / 2
	return s


static func capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = maxf(h, r * 2.0)
	c.radial_segments = 16
	c.rings = 6
	return c


static func cylinder(r_top: float, r_bot: float, h: float, segs := 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return c


static func mesh_instance(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi
