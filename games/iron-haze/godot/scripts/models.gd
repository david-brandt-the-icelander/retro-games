extends RefCounted
## Procedural model library. Every unit, structure and prop is assembled from primitives
## with PBR materials, so the project ships with zero external art assets.

static var _mats := {}
static var _meshes := {}
static var _noise_tex: NoiseTexture2D = null
static var _grime_tex: NoiseTexture2D = null


# ================================================================ materials

static func _noise() -> NoiseTexture2D:
	if _noise_tex == null:
		_noise_tex = _gray_noise(0.06, 4, 0.55)
	return _noise_tex


static func _grime() -> NoiseTexture2D:
	if _grime_tex == null:
		_grime_tex = _gray_noise(0.025, 5, 0.66)
	return _grime_tex


static func _gray_noise(freq: float, octaves: int, low: float) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.noise = n
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 1.0])
	g.colors = PackedColorArray([Color(low, low, low), Color(1, 1, 1)])
	t.color_ramp = g
	return t


static func _std(c: Color, metallic: float, rough: float, textured: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	if textured:
		m.albedo_texture = _grime()
		m.roughness_texture = _noise()
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.5, 0.5, 0.5)
	return m


static func _emit(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func mat(n: String) -> Material:
	if _mats.has(n):
		return _mats[n]
	var m: StandardMaterial3D
	match n:
		"steel": m = _std(Color(0.30, 0.31, 0.32), 0.85, 0.5)
		"darksteel": m = _std(Color(0.13, 0.13, 0.14), 0.8, 0.55)
		"brass": m = _std(Color(0.80, 0.60, 0.30), 1.0, 0.32)
		"copper": m = _std(Color(0.74, 0.42, 0.25), 1.0, 0.38)
		"rust": m = _std(Color(0.36, 0.19, 0.11), 0.25, 0.9)
		"rubber": m = _std(Color(0.05, 0.05, 0.05), 0.0, 0.95, false)
		"concrete": m = _std(Color(0.58, 0.55, 0.50), 0.0, 0.9)
		"darkconcrete": m = _std(Color(0.29, 0.28, 0.26), 0.0, 0.95)
		"brick": m = _std(Color(0.40, 0.19, 0.13), 0.0, 0.9)
		"canvas": m = _std(Color(0.64, 0.60, 0.50), 0.0, 0.8)
		"olive": m = _std(Color(0.28, 0.30, 0.20), 0.3, 0.7)
		"wood": m = _std(Color(0.30, 0.22, 0.15), 0.0, 0.85)
		"charwood": m = _std(Color(0.10, 0.085, 0.07), 0.0, 0.95)
		"charred": m = _std(Color(0.055, 0.05, 0.045), 0.2, 0.95)
		"sandbag": m = _std(Color(0.50, 0.45, 0.34), 0.0, 1.0)
		"rock": m = _std(Color(0.34, 0.32, 0.29), 0.0, 0.92)
		"oil": m = _std(Color(0.01, 0.01, 0.012), 0.4, 0.04, false)
		"glow": m = _emit(Color(1.0, 0.68, 0.3), 6.0)
		"window": m = _emit(Color(1.0, 0.70, 0.36), 2.4)
		"red": m = _emit(Color(1.0, 0.12, 0.08), 9.0)
		"green": m = _emit(Color(0.2, 1.0, 0.3), 7.0)
		"lens": m = _emit(Color(0.45, 1.0, 0.55), 4.0)
		"tracer": m = _emit(Color(1.0, 0.85, 0.45), 10.0)
		"tracer_hot": m = _emit(Color(1.0, 0.55, 0.2), 14.0)
		_: m = _std(Color.MAGENTA, 0.0, 1.0, false)
	_mats[n] = m
	return m


static func team_mat(team: int, dark: bool = false) -> Material:
	var key := "team%d_%s" % [team, "d" if dark else "l"]
	if not _mats.has(key):
		var c: Color = Game.TEAM_COLORS[team]
		if dark:
			c = c.darkened(0.5)
		_mats[key] = _std(c, 0.55, 0.45)
	return _mats[key]


static func team_glow(team: int) -> Material:
	var key := "teamglow%d" % team
	if not _mats.has(key):
		var c: Color = Game.TEAM_UI_COLORS[team]
		_mats[key] = _emit(c, 5.0)
	return _mats[key]


# ================================================================ geometry helpers

static func _box_mesh(s: Vector3) -> BoxMesh:
	var key := "b%.2f_%.2f_%.2f" % [s.x, s.y, s.z]
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = s
		_meshes[key] = m
	return _meshes[key]


static func _cyl_mesh(top: float, bottom: float, h: float, segs: int) -> CylinderMesh:
	var key := "c%.2f_%.2f_%.2f_%d" % [top, bottom, h, segs]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = segs
		m.rings = 1
		_meshes[key] = m
	return _meshes[key]


static func _sphere_mesh(r: float, segs: int) -> SphereMesh:
	var key := "s%.2f_%d" % [r, segs]
	if not _meshes.has(key):
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = segs
		m.rings = maxi(segs / 2, 4)
		_meshes[key] = m
	return _meshes[key]


static func _capsule_mesh(r: float, h: float) -> CapsuleMesh:
	var key := "k%.2f_%.2f" % [r, h]
	if not _meshes.has(key):
		var m := CapsuleMesh.new()
		m.radius = r
		m.height = h
		m.radial_segments = 32
		m.rings = 10
		_meshes[key] = m
	return _meshes[key]


static func _torus_mesh(inner: float, outer: float, rings: int = 32, segs: int = 8) -> TorusMesh:
	var key := "t%.2f_%.2f_%d_%d" % [inner, outer, rings, segs]
	if not _meshes.has(key):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = rings
		m.ring_segments = segs
		_meshes[key] = m
	return _meshes[key]


static func add(parent: Node3D, m: Mesh, material: Material, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, s: Vector3, material: Material, pos: Vector3 = Vector3.ZERO,
		rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	return add(parent, _box_mesh(s), material, pos, rot)


static func cyl(parent: Node3D, top: float, bottom: float, h: float, material: Material,
		pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO, segs: int = 16) -> MeshInstance3D:
	return add(parent, _cyl_mesh(top, bottom, h, segs), material, pos, rot)


static func sphere(parent: Node3D, r: float, material: Material, pos: Vector3 = Vector3.ZERO,
		scl: Vector3 = Vector3.ONE, segs: int = 16) -> MeshInstance3D:
	return add(parent, _sphere_mesh(r, segs), material, pos, Vector3.ZERO, scl)


static func node(parent: Node3D, n: String, pos: Vector3 = Vector3.ZERO, rot: Vector3 = Vector3.ZERO) -> Node3D:
	var x := Node3D.new()
	x.name = n
	x.position = pos
	x.rotation_degrees = rot
	parent.add_child(x)
	return x


static func marker(parent: Node3D, n: String, pos: Vector3, s: float = 1.0) -> Marker3D:
	var m := Marker3D.new()
	m.name = n
	m.position = pos
	m.set_meta("s", s)
	parent.add_child(m)
	return m


# ================================================================ units

static func build_unit(kind: String, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match kind:
		"constructor": _constructor(root, team)
		"trooper":
			_trooper(root, team)
			root.scale = Vector3.ONE * 1.35
		"tank": _tank(root, team)
		"howitzer": _howitzer(root, team)
		"zeppelin": _zeppelin(root, team)
	return root


static func _wheels(root: Node3D, zs: Array, x: float, r: float, y: float) -> void:
	for z in zs:
		for s in [-1.0, 1.0]:
			cyl(root, r, r, 0.34, mat("rubber"), Vector3(x * s, y, z), Vector3(0, 0, 90), 14)
			cyl(root, r * 0.45, r * 0.45, 0.36, mat("brass"), Vector3(x * s, y, z), Vector3(0, 0, 90), 8)


static func _tracks(root: Node3D, team: int, length: float, x: float, wheels: int) -> void:
	for s in [-1.0, 1.0]:
		box(root, Vector3(0.72, 0.85, length), mat("rubber"), Vector3(x * s, 0.45, 0))
		for i in wheels:
			var z := -length * 0.38 + i * (length * 0.76 / float(wheels - 1))
			cyl(root, 0.34, 0.34, 0.06, mat("steel"), Vector3((x + 0.38) * s, 0.42, z), Vector3(0, 0, 90), 12)
			cyl(root, 0.12, 0.12, 0.08, mat("brass"), Vector3((x + 0.41) * s, 0.42, z), Vector3(0, 0, 90), 8)
		box(root, Vector3(0.9, 0.08, length + 0.2), team_mat(team), Vector3(x * s, 0.92, 0))


static func _constructor(root: Node3D, team: int) -> void:
	var paint := team_mat(team)
	var brass := mat("brass")
	box(root, Vector3(2.0, 0.35, 3.8), mat("darksteel"), Vector3(0, 0.62, 0))
	_wheels(root, [-1.25, 0.0, 1.25], 1.0, 0.44, 0.44)
	box(root, Vector3(1.9, 1.05, 1.15), paint, Vector3(0, 1.3, -1.25))
	box(root, Vector3(1.7, 0.32, 0.06), mat("window"), Vector3(0, 1.5, -1.84))
	box(root, Vector3(2.0, 0.12, 1.25), brass, Vector3(0, 1.86, -1.25))
	box(root, Vector3(1.95, 0.55, 2.3), mat("olive"), Vector3(0, 1.05, 0.65))
	cyl(root, 0.45, 0.45, 1.3, mat("copper"), Vector3(0, 1.75, 0.15), Vector3(90, 0, 0), 16)
	for z in [-0.35, 0.15, 0.65]:
		cyl(root, 0.47, 0.47, 0.08, brass, Vector3(0, 1.75, z), Vector3(90, 0, 0), 16)
	cyl(root, 0.12, 0.16, 1.1, brass, Vector3(0.6, 2.0, -0.5), Vector3.ZERO, 10)
	marker(root, "Exhaust0", Vector3(0.6, 2.6, -0.5))
	var crane := node(root, "Crane", Vector3(0, 1.35, 1.3))
	cyl(crane, 0.32, 0.38, 0.4, brass, Vector3(0, 0.2, 0), Vector3.ZERO, 12)
	var arm := node(crane, "Arm", Vector3(0, 0.4, 0), Vector3(32, 0, 0))
	box(arm, Vector3(0.22, 0.22, 3.0), mat("steel"), Vector3(0, 0, -1.5))
	box(arm, Vector3(0.26, 0.05, 3.0), paint, Vector3(0, 0.13, -1.5))
	cyl(root, 0.03, 0.03, 1.4, mat("darksteel"), Vector3(0, 2.6, -1.0), Vector3.ZERO, 6)
	sphere(root, 0.12, mat("glow"), Vector3(-0.65, 1.0, -1.86), Vector3.ONE, 8)
	sphere(root, 0.12, mat("glow"), Vector3(0.65, 1.0, -1.86), Vector3.ONE, 8)
	sphere(root, 0.1, team_glow(team), Vector3(0, 1.98, -1.25), Vector3.ONE, 8)


static func _tank(root: Node3D, team: int) -> void:
	var paint := team_mat(team)
	var brass := mat("brass")
	var dark := mat("darksteel")
	_tracks(root, team, 4.3, 1.18, 5)
	box(root, Vector3(1.75, 0.7, 3.9), paint, Vector3(0, 1.0, 0.05))
	box(root, Vector3(1.75, 0.5, 0.9), paint, Vector3(0, 0.95, -2.0), Vector3(-32, 0, 0))
	box(root, Vector3(1.8, 0.07, 0.07), brass, Vector3(0, 1.37, -1.85))
	box(root, Vector3(0.07, 0.07, 3.8), brass, Vector3(-0.88, 1.37, 0.05))
	box(root, Vector3(0.07, 0.07, 3.8), brass, Vector3(0.88, 1.37, 0.05))
	box(root, Vector3(1.4, 0.12, 1.1), dark, Vector3(0, 1.4, 1.35))
	for i in 2:
		var x := -0.55 + i * 1.1
		cyl(root, 0.09, 0.12, 0.85, brass, Vector3(x, 1.7, 1.85), Vector3.ZERO, 10)
		marker(root, "Exhaust%d" % i, Vector3(x, 2.15, 1.85))
	sphere(root, 0.11, mat("glow"), Vector3(-0.62, 1.15, -2.42), Vector3.ONE, 8)
	sphere(root, 0.11, mat("glow"), Vector3(0.62, 1.15, -2.42), Vector3.ONE, 8)
	var turret := node(root, "Turret", Vector3(0, 1.36, 0.15))
	cyl(turret, 0.82, 1.0, 0.62, paint, Vector3(0, 0.31, 0), Vector3.ZERO, 8)
	cyl(turret, 0.86, 0.86, 0.07, brass, Vector3(0, 0.63, 0), Vector3.ZERO, 8)
	box(turret, Vector3(0.72, 0.5, 0.45), dark, Vector3(0, 0.33, -0.92))
	cyl(turret, 0.26, 0.3, 0.3, brass, Vector3(0.35, 0.78, 0.25), Vector3.ZERO, 10)
	sphere(turret, 0.06, team_glow(team), Vector3(0.35, 0.96, 0.25), Vector3.ONE, 6)
	cyl(turret, 0.015, 0.015, 1.8, dark, Vector3(-0.5, 1.5, 0.5), Vector3.ZERO, 4)
	var barrel := node(turret, "Barrel", Vector3(0, 0.33, -1.0))
	cyl(barrel, 0.1, 0.13, 2.6, mat("steel"), Vector3(0, 0, -1.3), Vector3(90, 0, 0), 12)
	cyl(barrel, 0.17, 0.17, 0.4, dark, Vector3(0, 0, -2.6), Vector3(90, 0, 0), 12)
	marker(barrel, "Muzzle", Vector3(0, 0, -2.9))


static func _howitzer(root: Node3D, team: int) -> void:
	var paint := team_mat(team)
	var brass := mat("brass")
	var dark := mat("darksteel")
	_tracks(root, team, 4.6, 1.2, 6)
	box(root, Vector3(1.8, 0.6, 4.3), paint, Vector3(0, 0.95, 0.0))
	box(root, Vector3(1.9, 0.14, 2.4), dark, Vector3(0, 1.3, 0.9))
	box(root, Vector3(1.6, 0.6, 1.0), paint, Vector3(0, 1.45, -1.6))
	box(root, Vector3(1.4, 0.2, 0.06), mat("window"), Vector3(0, 1.55, -2.12))
	for i in 2:
		var x := -0.6 + i * 1.2
		box(root, Vector3(0.45, 0.35, 0.6), mat("wood"), Vector3(x, 1.55, 2.0))
		cyl(root, 0.09, 0.12, 0.8, brass, Vector3(x * 1.3, 1.6, 1.7), Vector3.ZERO, 10)
		marker(root, "Exhaust%d" % i, Vector3(x * 1.3, 2.05, 1.7))
	var turret := node(root, "Turret", Vector3(0, 1.38, 0.7))
	cyl(turret, 0.55, 0.65, 0.35, dark, Vector3(0, 0.17, 0), Vector3.ZERO, 12)
	box(turret, Vector3(1.6, 1.0, 0.1), paint, Vector3(0, 0.75, -0.75))
	box(turret, Vector3(0.1, 0.8, 1.0), paint, Vector3(-0.8, 0.65, -0.3), Vector3(0, 15, 0))
	box(turret, Vector3(0.1, 0.8, 1.0), paint, Vector3(0.8, 0.65, -0.3), Vector3(0, -15, 0))
	box(turret, Vector3(1.65, 0.07, 0.12), brass, Vector3(0, 1.25, -0.75))
	var barrel := node(turret, "Barrel", Vector3(0, 0.75, -0.2), Vector3(26, 0, 0))
	cyl(barrel, 0.14, 0.22, 4.8, mat("steel"), Vector3(0, 0, -2.0), Vector3(90, 0, 0), 14)
	cyl(barrel, 0.26, 0.26, 1.0, dark, Vector3(0, 0, 0.1), Vector3(90, 0, 0), 14)
	for s in [-1.0, 1.0]:
		cyl(barrel, 0.08, 0.08, 1.6, brass, Vector3(0.24 * s, -0.12, -0.5), Vector3(90, 0, 0), 8)
	cyl(barrel, 0.22, 0.22, 0.45, dark, Vector3(0, 0, -4.35), Vector3(90, 0, 0), 12)
	marker(barrel, "Muzzle", Vector3(0, 0, -4.7))


static func _trooper(root: Node3D, team: int) -> void:
	var offsets := [Vector3(0, 0, -0.55), Vector3(-0.65, 0, 0.45), Vector3(0.65, 0, 0.45)]
	for i in 3:
		var m := node(root, "Member%d" % i, offsets[i])
		_soldier(m, team)


static func _soldier(m: Node3D, team: int) -> void:
	var coat := team_mat(team, true)
	box(m, Vector3(0.14, 0.55, 0.16), mat("darksteel"), Vector3(-0.1, 0.28, 0))
	box(m, Vector3(0.14, 0.55, 0.16), mat("darksteel"), Vector3(0.1, 0.28, 0))
	cyl(m, 0.19, 0.3, 0.78, coat, Vector3(0, 0.84, 0), Vector3.ZERO, 10)
	cyl(m, 0.215, 0.215, 0.06, mat("brass"), Vector3(0, 0.92, 0), Vector3.ZERO, 10)
	box(m, Vector3(0.3, 0.36, 0.16), mat("canvas"), Vector3(0, 1.02, 0.2))
	box(m, Vector3(0.1, 0.45, 0.12), coat, Vector3(-0.24, 1.0, -0.08), Vector3(-25, 0, 8))
	box(m, Vector3(0.1, 0.45, 0.12), coat, Vector3(0.24, 1.0, -0.12), Vector3(-45, 0, -8))
	sphere(m, 0.15, mat("darksteel"), Vector3(0, 1.36, 0), Vector3.ONE, 10)
	sphere(m, 0.04, mat("lens"), Vector3(-0.065, 1.39, -0.13), Vector3.ONE, 6)
	sphere(m, 0.04, mat("lens"), Vector3(0.065, 1.39, -0.13), Vector3.ONE, 6)
	cyl(m, 0.05, 0.065, 0.16, mat("brass"), Vector3(0, 1.27, -0.17), Vector3(90, 0, 0), 8)
	sphere(m, 0.21, mat("steel"), Vector3(0, 1.47, 0), Vector3(1, 0.45, 1), 12)
	box(m, Vector3(0.05, 0.06, 0.95), mat("wood"), Vector3(0.2, 1.05, -0.3), Vector3(-12, 0, 0))


static func _zeppelin(root: Node3D, team: int) -> void:
	var paint := team_mat(team)
	var brass := mat("brass")
	var hull := node(root, "Hull")
	add(hull, _capsule_mesh(2.1, 15.0), mat("canvas"), Vector3.ZERO, Vector3(90, 0, 0))
	for z in [-5.0, -2.5, 0.0, 2.5, 5.0]:
		add(hull, _torus_mesh(2.07, 2.17, 40, 6), brass, Vector3(0, 0, z), Vector3(90, 0, 0))
	cyl(hull, 2.14, 2.14, 1.3, paint, Vector3(0, 0, -3.75), Vector3(90, 0, 0), 32)
	cyl(hull, 2.14, 2.14, 0.5, paint, Vector3(0, 0, 3.75), Vector3(90, 0, 0), 32)
	for i in 4:
		var f := node(hull, "Fin%d" % i, Vector3(0, 0, 6.0), Vector3(0, 0, i * 90.0))
		box(f, Vector3(0.14, 2.0, 2.8), paint, Vector3(0, 2.4, 0.4))
		box(f, Vector3(0.18, 0.12, 2.9), brass, Vector3(0, 3.4, 0.4))
	sphere(hull, 0.4, brass, Vector3(0, 0, -7.5), Vector3.ONE, 12)
	box(hull, Vector3(1.3, 1.0, 4.6), mat("darksteel"), Vector3(0, -2.75, -0.5))
	box(hull, Vector3(1.34, 0.24, 3.8), mat("window"), Vector3(0, -2.62, -0.6))
	box(hull, Vector3(1.0, 0.2, 2.0), brass, Vector3(0, -3.3, -0.5))
	for z in [-2.2, 1.2]:
		box(hull, Vector3(0.1, 1.0, 0.1), mat("steel"), Vector3(-0.5, -1.9, z), Vector3(0, 0, -12))
		box(hull, Vector3(0.1, 1.0, 0.1), mat("steel"), Vector3(0.5, -1.9, z), Vector3(0, 0, 12))
	for i in 2:
		var s := -1.0 if i == 0 else 1.0
		box(hull, Vector3(1.6, 0.12, 0.5), mat("steel"), Vector3(s * 1.9, -1.5, 1.8))
		cyl(hull, 0.38, 0.3, 1.7, brass, Vector3(s * 2.6, -1.5, 1.8), Vector3(90, 0, 0), 14)
		var prop := node(hull, "Prop%d" % i, Vector3(s * 2.6, -1.5, 2.72))
		box(prop, Vector3(0.14, 2.0, 0.05), mat("wood"))
		box(prop, Vector3(2.0, 0.14, 0.05), mat("wood"))
	sphere(hull, 0.14, mat("red"), Vector3(-2.1, 0.3, -1.0), Vector3.ONE, 8)
	sphere(hull, 0.14, mat("green"), Vector3(2.1, 0.3, -1.0), Vector3.ONE, 8)
	marker(hull, "Muzzle", Vector3(0, -3.4, -0.5))


# ================================================================ structures

static func build_building(kind: String, team: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	match kind:
		"hq": _hq(root, team)
		"derrick": _derrick(root, team)
		"barracks": _barracks(root, team)
		"factory": _factory(root, team)
		"dock": _dock(root, team)
		"flak": _flak(root, team)
	return root


static func _hq(root: Node3D, team: int) -> void:
	var con := mat("concrete")
	var brass := mat("brass")
	var win := mat("window")
	var paint := team_mat(team)
	box(root, Vector3(10.0, 4.0, 10.0), mat("darkconcrete"), Vector3(0, -1.2, 0))
	box(root, Vector3(7.6, 4.2, 7.6), con, Vector3(0, 2.9, 0))
	box(root, Vector3(5.2, 3.2, 5.2), con, Vector3(0, 6.6, 0))
	box(root, Vector3(3.4, 3.0, 3.4), con, Vector3(0, 9.7, 0))
	box(root, Vector3(2.0, 2.4, 2.0), con, Vector3(0, 12.4, 0))
	box(root, Vector3(7.9, 0.22, 7.9), brass, Vector3(0, 5.05, 0))
	box(root, Vector3(5.5, 0.2, 5.5), brass, Vector3(0, 8.25, 0))
	box(root, Vector3(3.7, 0.2, 3.7), brass, Vector3(0, 11.25, 0))
	box(root, Vector3(2.3, 0.2, 2.3), brass, Vector3(0, 13.65, 0))
	for i in 4:
		var f := node(root, "Face%d" % i, Vector3.ZERO, Vector3(0, i * 90.0, 0))
		box(f, Vector3(6.2, 0.35, 0.06), win, Vector3(0, 2.4, -3.82))
		box(f, Vector3(6.2, 0.35, 0.06), win, Vector3(0, 3.9, -3.82))
		for k in 5:
			box(f, Vector3(0.24, 4.2, 0.3), brass, Vector3(-3.0 + k * 1.5, 2.9, -3.86))
		box(f, Vector3(1.3, 2.6, 0.08), paint, Vector3(0, 6.7, -2.65))
		box(f, Vector3(1.2, 0.3, 0.06), win, Vector3(-1.7, 7.2, -2.62))
		box(f, Vector3(1.2, 0.3, 0.06), win, Vector3(1.7, 7.2, -2.62))
		box(f, Vector3(2.4, 0.3, 0.06), win, Vector3(0, 10.2, -1.72))
		box(f, Vector3(0.08, 2.2, 0.08), brass, Vector3(-0.6, 12.4, -1.03))
		box(f, Vector3(0.08, 2.2, 0.08), brass, Vector3(0.6, 12.4, -1.03))
	cyl(root, 0.0, 0.45, 4.5, brass, Vector3(0, 15.9, 0), Vector3.ZERO, 8)
	var beacon := sphere(root, 0.3, mat("red"), Vector3(0, 18.25, 0), Vector3.ONE, 10)
	beacon.name = "Beacon"
	box(root, Vector3(2.2, 2.0, 0.6), mat("darksteel"), Vector3(0, 1.8, -3.9))
	box(root, Vector3(2.8, 0.2, 1.3), brass, Vector3(0, 2.95, -4.2))
	sphere(root, 0.16, mat("glow"), Vector3(0, 2.7, -4.4), Vector3.ONE, 8)
	var n := 0
	for p in [Vector3(-3.0, 0, 2.9), Vector3(3.0, 0, 2.9)]:
		cyl(root, 0.45, 0.6, 7.5, mat("brick"), p + Vector3(0, 4.55, 0), Vector3.ZERO, 12)
		cyl(root, 0.6, 0.6, 0.25, brass, p + Vector3(0, 7.2, 0), Vector3.ZERO, 12)
		cyl(root, 0.52, 0.52, 0.2, mat("darksteel"), p + Vector3(0, 8.3, 0), Vector3.ZERO, 12)
		marker(root, "Smoke%d" % n, p + Vector3(0, 8.5, 0), 1.3)
		n += 1
	var radar := node(root, "Radar", Vector3(1.9, 8.35, 1.9))
	cyl(radar, 0.15, 0.2, 0.6, mat("steel"), Vector3(0, 0.3, 0), Vector3.ZERO, 8)
	box(radar, Vector3(2.0, 0.6, 0.06), mat("steel"), Vector3(0, 0.75, 0))
	box(radar, Vector3(2.1, 0.07, 0.1), brass, Vector3(0, 1.08, 0))
	for k in 6:
		var sx := -4.3 + k * 0.62 if k < 3 else 2.06 + (k - 3) * 0.62
		add(root, _capsule_mesh(0.24, 0.95), mat("sandbag"), Vector3(sx, 1.05, -5.0), Vector3(0, 0, 90))
		add(root, _capsule_mesh(0.24, 0.95), mat("sandbag"), Vector3(sx + 0.3, 1.45, -5.0), Vector3(0, 0, 90))


static func _derrick(root: Node3D, team: int) -> void:
	box(root, Vector3(3.6, 2.0, 3.6), mat("darkconcrete"), Vector3(0, -0.7, 0))
	box(root, Vector3(0.22, 3.4, 0.22), mat("steel"), Vector3(-0.45, 1.95, 0.3), Vector3(0, 0, -8))
	box(root, Vector3(0.22, 3.4, 0.22), mat("steel"), Vector3(0.45, 1.95, 0.3), Vector3(0, 0, 8))
	box(root, Vector3(1.2, 0.15, 0.15), mat("brass"), Vector3(0, 2.2, 0.3))
	var beam := node(root, "Beam", Vector3(0, 3.6, 0.3))
	box(beam, Vector3(0.3, 0.45, 4.4), team_mat(team), Vector3(0, 0, -0.3))
	box(beam, Vector3(0.36, 1.3, 0.55), mat("steel"), Vector3(0, -0.35, -2.55))
	cyl(beam, 0.03, 0.03, 2.6, mat("darksteel"), Vector3(0, -1.6, -2.78), Vector3.ZERO, 6)
	box(beam, Vector3(0.9, 0.75, 0.55), mat("rust"), Vector3(0, -0.55, 1.75))
	box(root, Vector3(1.0, 0.9, 0.9), mat("rust"), Vector3(0, 0.75, 1.4))
	cyl(root, 0.35, 0.35, 0.5, mat("copper"), Vector3(0.65, 0.8, 1.4), Vector3(0, 0, 90), 12)
	cyl(root, 0.25, 0.25, 0.6, mat("brass"), Vector3(0, 0.6, -2.45), Vector3.ZERO, 10)
	cyl(root, 0.72, 0.72, 1.8, mat("steel"), Vector3(1.2, 1.2, -0.9), Vector3.ZERO, 16)
	cyl(root, 0.74, 0.74, 0.08, mat("brass"), Vector3(1.2, 1.7, -0.9), Vector3.ZERO, 16)
	cyl(root, 0.74, 0.74, 0.08, mat("brass"), Vector3(1.2, 0.7, -0.9), Vector3.ZERO, 16)
	sphere(root, 0.1, mat("glow"), Vector3(-1.4, 1.2, 1.4), Vector3.ONE, 8)


static func _barracks(root: Node3D, team: int) -> void:
	box(root, Vector3(6.8, 2.0, 6.8), mat("darkconcrete"), Vector3(0, -0.7, 0))
	cyl(root, 2.6, 2.6, 5.6, mat("olive"), Vector3(0, 0.3, 0.3), Vector3(90, 0, 0), 22)
	for k in 5:
		cyl(root, 2.66, 2.66, 0.12, mat("darksteel"), Vector3(0, 0.3, -2.1 + k * 1.2), Vector3(90, 0, 0), 22)
	cyl(root, 2.55, 2.55, 0.15, mat("darkconcrete"), Vector3(0, 0.3, -2.5), Vector3(90, 0, 0), 22)
	box(root, Vector3(1.3, 1.9, 0.12), mat("darksteel"), Vector3(0, 1.25, -2.6))
	box(root, Vector3(1.6, 0.12, 0.5), mat("brass"), Vector3(0, 2.3, -2.75))
	sphere(root, 0.14, mat("glow"), Vector3(0, 2.15, -2.8), Vector3.ONE, 8)
	for s in [-1.0, 1.0]:
		box(root, Vector3(0.6, 0.35, 0.06), mat("window"), Vector3(1.4 * s, 1.0, -2.6))
	cyl(root, 0.18, 0.22, 1.8, mat("rust"), Vector3(1.3, 2.7, 1.6), Vector3.ZERO, 10)
	marker(root, "Smoke0", Vector3(1.3, 3.7, 1.6), 0.7)
	for k in 8:
		var x := -3.0 + (k % 4) * 0.62
		if k >= 4:
			x = 1.15 + (k % 4) * 0.62
		add(root, _capsule_mesh(0.22, 0.9), mat("sandbag"), Vector3(x, 0.5, -3.15), Vector3(0, 0, 90))
	cyl(root, 0.05, 0.05, 5.0, mat("steel"), Vector3(-2.9, 2.8, -2.9), Vector3.ZERO, 6)
	box(root, Vector3(1.0, 0.6, 0.04), team_mat(team), Vector3(-2.38, 4.9, -2.9))


static func _factory(root: Node3D, team: int) -> void:
	var brass := mat("brass")
	var dark := mat("darksteel")
	box(root, Vector3(9.4, 2.0, 9.4), mat("darkconcrete"), Vector3(0, -0.7, 0))
	box(root, Vector3(8.6, 4.8, 7.0), mat("brick"), Vector3(0, 2.7, 0.6))
	for k in 3:
		var z := -2.2 + k * 2.3
		box(root, Vector3(8.7, 0.16, 2.55), mat("steel"), Vector3(0, 5.7, z + 0.15), Vector3(-26, 0, 0))
		box(root, Vector3(8.5, 1.05, 0.06), mat("window"), Vector3(0, 5.65, z + 1.32))
	box(root, Vector3(5.2, 4.0, 0.3), team_mat(team), Vector3(0, 2.3, -2.95))
	box(root, Vector3(4.4, 3.4, 0.2), dark, Vector3(0, 2.0, -3.05))
	for k in 8:
		box(root, Vector3(0.55, 0.3, 0.05), brass if k % 2 == 0 else dark, Vector3(-1.93 + k * 0.55, 4.0, -3.12))
	sphere(root, 0.18, mat("glow"), Vector3(-2.8, 4.5, -3.15), Vector3.ONE, 8)
	sphere(root, 0.18, mat("glow"), Vector3(2.8, 4.5, -3.15), Vector3.ONE, 8)
	var n := 0
	for p in [Vector3(-3.0, 0, 3.3), Vector3(3.0, 0, 3.3)]:
		cyl(root, 0.55, 0.78, 11.0, mat("brick"), p + Vector3(0, 5.8, 0), Vector3.ZERO, 14)
		cyl(root, 0.62, 0.62, 0.25, brass, p + Vector3(0, 8.0, 0), Vector3.ZERO, 14)
		cyl(root, 0.6, 0.6, 0.35, dark, p + Vector3(0, 11.2, 0), Vector3.ZERO, 14)
		marker(root, "Smoke%d" % n, p + Vector3(0, 11.5, 0), 1.6)
		n += 1
	var mount := node(root, "GearMount", Vector3(4.45, 3.0, 0.6), Vector3(0, 0, 90))
	var gear := node(mount, "Gear")
	cyl(gear, 1.3, 1.3, 0.22, brass, Vector3.ZERO, Vector3.ZERO, 20)
	for t in 10:
		var a := t * TAU / 10.0
		box(gear, Vector3(0.38, 0.22, 0.34), brass, Vector3(cos(a) * 1.42, 0, sin(a) * 1.42), Vector3(0, -rad_to_deg(a), 0))
	cyl(gear, 0.35, 0.35, 0.36, dark, Vector3.ZERO, Vector3.ZERO, 10)
	cyl(root, 0.18, 0.18, 6.6, mat("copper"), Vector3(-4.45, 4.3, 0.6), Vector3(90, 0, 0), 10)
	cyl(root, 0.18, 0.18, 4.2, mat("copper"), Vector3(-4.45, 2.2, 3.9), Vector3.ZERO, 10)


static func _dock(root: Node3D, team: int) -> void:
	var brass := mat("brass")
	var steel := mat("steel")
	box(root, Vector3(7.2, 2.0, 7.2), mat("darkconcrete"), Vector3(0, -0.7, 0))
	for p in [Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(-0.8, 0.8), Vector2(0.8, 0.8)]:
		box(root, Vector3(0.18, 15.0, 0.18), steel, Vector3(p.x, 7.8, p.y))
	for h in [2.5, 5.0, 7.5, 10.0, 12.5, 14.8]:
		add(root, _torus_mesh(1.0, 1.18, 4, 4), brass, Vector3(0, h, 0), Vector3(0, 45, 0))
	for i in 4:
		var f := node(root, "Brace%d" % i, Vector3.ZERO, Vector3(0, i * 90.0, 0))
		for h in [3.75, 8.75, 13.6]:
			box(f, Vector3(0.08, 3.0, 0.08), steel, Vector3(0, h, -0.82), Vector3(0, 0, 32))
	cyl(root, 1.7, 1.7, 0.25, mat("darksteel"), Vector3(0, 15.4, 0), Vector3.ZERO, 12)
	cyl(root, 0.15, 0.55, 1.1, brass, Vector3(0, 16.05, 0), Vector3.ZERO, 12)
	var beacon := sphere(root, 0.26, mat("red"), Vector3(0, 16.8, 0), Vector3.ONE, 10)
	beacon.name = "Beacon"
	for k in 4:
		var a := k * TAU / 4.0 + PI / 4.0
		sphere(root, 0.14, mat("glow"), Vector3(cos(a) * 1.55, 15.65, sin(a) * 1.55), Vector3.ONE, 8)
	box(root, Vector3(3.0, 2.4, 2.6), mat("olive"), Vector3(1.9, 1.5, 1.9))
	box(root, Vector3(3.2, 0.2, 2.8), team_mat(team), Vector3(1.9, 2.8, 1.9))
	box(root, Vector3(1.2, 0.5, 0.06), mat("window"), Vector3(1.9, 1.8, 0.58))
	for z in [-1.9, 0.4]:
		sphere(root, 0.9, mat("copper"), Vector3(-2.2, 1.3, z), Vector3.ONE, 16)
		cyl(root, 0.08, 0.08, 1.0, steel, Vector3(-2.2, 0.5, z), Vector3.ZERO, 6)
	cyl(root, 0.05, 0.05, 4.0, steel, Vector3(2.8, 2.0, -2.8), Vector3.ZERO, 6)
	box(root, Vector3(0.9, 0.55, 0.04), team_mat(team), Vector3(3.28, 3.7, -2.8))


static func _flak(root: Node3D, team: int) -> void:
	box(root, Vector3(3.8, 2.0, 3.8), mat("darkconcrete"), Vector3(0, -0.7, 0))
	cyl(root, 1.4, 1.75, 4.2, mat("concrete"), Vector3(0, 2.4, 0), Vector3.ZERO, 8)
	cyl(root, 1.95, 1.95, 0.3, mat("darkconcrete"), Vector3(0, 4.6, 0), Vector3.ZERO, 8)
	add(root, _torus_mesh(1.82, 1.92, 8, 4), mat("brass"), Vector3(0, 5.05, 0))
	for i in 4:
		var f := node(root, "Slit%d" % i, Vector3.ZERO, Vector3(0, i * 90.0 + 22.5, 0))
		box(f, Vector3(0.6, 0.15, 0.05), mat("window"), Vector3(0, 2.8, -1.57))
	var turret := node(root, "Turret", Vector3(0, 4.75, 0))
	cyl(turret, 0.7, 0.8, 0.5, mat("steel"), Vector3(0, 0.25, 0), Vector3.ZERO, 12)
	box(turret, Vector3(1.6, 0.9, 0.12), team_mat(team), Vector3(0, 0.75, -0.6))
	box(turret, Vector3(1.65, 0.07, 0.15), mat("brass"), Vector3(0, 1.22, -0.6))
	var barrel := node(turret, "Barrel", Vector3(0, 0.85, -0.2), Vector3(35, 0, 0))
	for bx in [-0.16, 0.16]:
		for by in [-0.12, 0.12]:
			cyl(barrel, 0.055, 0.07, 2.4, mat("darksteel"), Vector3(bx, by, -1.1), Vector3(90, 0, 0), 8)
	marker(barrel, "Muzzle", Vector3(0, 0, -2.4))


# ================================================================ misc

static func rubble(size: float) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	box(root, Vector3(size * 0.9, 1.2, size * 0.9), mat("charred"), Vector3(0, -0.45, 0))
	var k := clampf(size / 6.0, 0.6, 1.4)
	for i in int(size * 2.5):
		var s := Vector3(snappedf(rng.randf_range(0.4, 1.6), 0.2), snappedf(rng.randf_range(0.3, 1.0), 0.2),
			snappedf(rng.randf_range(0.4, 1.6), 0.2)) * k
		var p := Vector3(rng.randf_range(-size * 0.42, size * 0.42), s.y * 0.3, rng.randf_range(-size * 0.42, size * 0.42))
		var m := mat("charred") if i % 3 == 0 else mat("darkconcrete")
		box(root, s, m, p, Vector3(rng.randf_range(-25, 25), rng.randf_range(0, 180), rng.randf_range(-25, 25)))
	for i in 3:
		box(root, Vector3(0.15, 0.15, snappedf(size * 0.5, 0.5)), mat("rust"),
			Vector3(rng.randf_range(-size * 0.3, size * 0.3), 0.6, rng.randf_range(-size * 0.3, size * 0.3)),
			Vector3(rng.randf_range(-35, 35), rng.randf_range(0, 180), 0))
	return root


static func selection_ring(r: float, team: int, building: bool) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var rr := r * (1.0 if building else 1.05)
	var tm := TorusMesh.new()
	tm.inner_radius = rr
	tm.outer_radius = rr + (0.3 if building else 0.18)
	tm.rings = 48
	tm.ring_segments = 4
	mi.mesh = tm
	var key := "ring%d" % team
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(0.45, 1.0, 0.5) if team == Game.PLAYER else Color(1.0, 0.35, 0.3)
		m.no_depth_test = true
		m.render_priority = 1
		_mats[key] = m
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.3, 1)
	mi.position.y = 0.15
	return mi


static func projectile_mesh(weapon: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	match weapon:
		"rifle":
			mi.mesh = _box_mesh(Vector3(0.05, 0.05, 1.1))
			mi.material_override = mat("tracer")
		"cannon":
			mi.mesh = _box_mesh(Vector3(0.14, 0.14, 1.6))
			mi.material_override = mat("tracer_hot")
		"flak":
			mi.mesh = _sphere_mesh(0.13, 8)
			mi.material_override = mat("tracer")
		"artillery":
			mi.mesh = _sphere_mesh(0.26, 10)
			mi.material_override = mat("tracer_hot")
		_:
			mi.mesh = _capsule_mesh(0.22, 1.0)
			mi.material_override = mat("darksteel")
			mi.rotation_degrees = Vector3(90, 0, 0)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi


static func _meshes_in(root: Node) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false)


static func char_visual(root: Node3D) -> void:
	for mi in _meshes_in(root):
		mi.material_override = mat("charred")


static func make_ghost(root: Node3D, valid: bool) -> void:
	var key := "ghost_ok" if valid else "ghost_bad"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.4, 1.0, 0.5, 0.35) if valid else Color(1.0, 0.25, 0.2, 0.35)
		_mats[key] = m
	for mi in _meshes_in(root):
		mi.material_override = _mats[key]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
