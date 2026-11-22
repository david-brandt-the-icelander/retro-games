class_name Models
extends RefCounted
## Procedural low-poly models for units and cities (no external assets).

static var _mats := {}
static var _meshes := {}

const SKIN := Color("e0b48c")
const WOOD := Color("7a5534")
const STEEL := Color("b8c2cc")
const DARK := Color("2d3138")
const CLOTH := Color("d9cfb8")
const HORSE := Color("6b4a32")
const STONE := Color("c9c1b2")
const ROOF := Color("a8483a")

static func mat(c: Color, rough := 0.65, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var key := "%s_%.2f_%.2f_%.2f" % [c.to_html(), rough, metal, emit]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[key] = m
	return m

static func box(size: Vector3) -> Mesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _meshes[key]

static func cyl(top: float, bottom: float, height: float, seg := 8) -> Mesh:
	var key := "cyl%.3f_%.3f_%.3f_%d" % [top, bottom, height, seg]
	if not _meshes.has(key):
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = seg
		c.rings = 1
		_meshes[key] = c
	return _meshes[key]

static func sphere(r: float, seg := 8, rings := 5) -> Mesh:
	var key := "sph%.3f_%d_%d" % [r, seg, rings]
	if not _meshes.has(key):
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * 2.0
		s.radial_segments = seg
		s.rings = rings
		_meshes[key] = s
	return _meshes[key]

static func capsule(r: float, hgt: float) -> Mesh:
	var key := "cap%.3f_%.3f" % [r, hgt]
	if not _meshes.has(key):
		var s := CapsuleMesh.new()
		s.radius = r
		s.height = hgt
		s.radial_segments = 8
		s.rings = 2
		_meshes[key] = s
	return _meshes[key]

static func prism(size: Vector3) -> Mesh:
	var key := "pri%s" % size
	if not _meshes.has(key):
		var p := PrismMesh.new()
		p.size = size
		_meshes[key] = p
	return _meshes[key]

static func add(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi

# ---------------------------------------------------------------- units

static func person(parent: Node3D, pos: Vector3, team: Color, weapon: String, era := 0) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var tm := mat(team, 0.55)
	add(n, box(Vector3(0.06, 0.1, 0.05)), mat(DARK), Vector3(0, 0.05, 0))
	add(n, capsule(0.045, 0.15), tm, Vector3(0, 0.15, 0))
	add(n, sphere(0.035), mat(SKIN), Vector3(0, 0.255, 0))
	match weapon:
		"club":
			add(n, cyl(0.012, 0.02, 0.15, 5), mat(WOOD), Vector3(0.06, 0.16, 0.02), Vector3(0.4, 0, 0))
		"spear":
			add(n, cyl(0.007, 0.007, 0.32, 4), mat(WOOD), Vector3(0.055, 0.2, 0))
			add(n, cyl(0.0, 0.016, 0.05, 4), mat(STEEL, 0.3, 0.8), Vector3(0.055, 0.38, 0))
			add(n, cyl(0.055, 0.055, 0.012, 10), mat(team.darkened(0.3)), Vector3(-0.05, 0.15, 0.02), Vector3(0, 0, PI / 2))
		"sword":
			add(n, box(Vector3(0.012, 0.13, 0.025)), mat(STEEL, 0.25, 0.9), Vector3(0.06, 0.18, 0.02), Vector3(0.3, 0, 0))
			add(n, box(Vector3(0.012, 0.11, 0.08)), mat(team.darkened(0.35)), Vector3(-0.055, 0.15, 0.01))
			add(n, sphere(0.04, 8, 4), mat(STEEL, 0.3, 0.8), Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 0.7, 1))
		"bow":
			add(n, cyl(0.006, 0.006, 0.2, 4), mat(WOOD), Vector3(0.06, 0.17, 0.0), Vector3(0, 0, 0.25))
		"crossbow":
			add(n, box(Vector3(0.14, 0.02, 0.03)), mat(WOOD), Vector3(0.0, 0.17, 0.06))
			add(n, box(Vector3(0.02, 0.02, 0.12)), mat(WOOD), Vector3(0.0, 0.17, 0.05))
		"musket", "rifle":
			add(n, cyl(0.008, 0.01, 0.26, 5), mat(DARK, 0.4, 0.6), Vector3(0.05, 0.2, 0.02), Vector3(0.15, 0, 0))
			add(n, cyl(0.035, 0.04, 0.035, 8), mat(team.darkened(0.4) if weapon == "musket" else Color("4d5a3a")), Vector3(0, 0.29, 0))
		"pick":
			add(n, cyl(0.008, 0.008, 0.18, 4), mat(WOOD), Vector3(0.06, 0.18, 0), Vector3(0, 0, 0.5))
			add(n, box(Vector3(0.1, 0.015, 0.015)), mat(STEEL, 0.4, 0.7), Vector3(0.1, 0.25, 0), Vector3(0, 0, 0.5))
		"staff":
			add(n, cyl(0.008, 0.008, 0.3, 4), mat(WOOD), Vector3(0.06, 0.18, 0))
	return n

static func horse(parent: Node3D, pos: Vector3, team: Color, armored := false) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var hm := mat(HORSE if not armored else Color("4a4a52"))
	add(n, box(Vector3(0.07, 0.08, 0.2)), hm, Vector3(0, 0.12, 0))
	add(n, box(Vector3(0.05, 0.1, 0.06)), hm, Vector3(0, 0.19, 0.11), Vector3(-0.5, 0, 0))
	add(n, box(Vector3(0.045, 0.045, 0.08)), hm, Vector3(0, 0.23, 0.15))
	for lx in [-0.025, 0.025]:
		for lz in [-0.07, 0.07]:
			add(n, box(Vector3(0.02, 0.09, 0.02)), hm, Vector3(lx, 0.045, lz))
	if armored:
		add(n, box(Vector3(0.08, 0.05, 0.16)), mat(team, 0.5), Vector3(0, 0.14, 0))
	var rider := person(n, Vector3(0, 0.12, -0.01), team, "spear" if armored else "sword")
	rider.scale = Vector3.ONE * 0.85
	return n

static func base_disc(parent: Node3D, team: Color) -> void:
	add(parent, cyl(0.28, 0.30, 0.025, 6), mat(team.darkened(0.25), 0.4, 0.0, 0.35), Vector3(0, 0.0125, 0), Vector3(0, PI / 6, 0))
	add(parent, cyl(0.24, 0.24, 0.028, 6), mat(team.lerp(Color(0.92, 0.9, 0.86), 0.6), 0.7), Vector3(0, 0.016, 0), Vector3(0, PI / 6, 0))

static func unit_model(model: String, team: Color) -> Node3D:
	var root := Node3D.new()
	base_disc(root, team)
	var trio := [Vector3(-0.1, 0.03, 0.05), Vector3(0.1, 0.03, 0.05), Vector3(0.0, 0.03, -0.1)]
	match model:
		"club", "spear", "sword", "bow", "crossbow", "musket", "rifle":
			for p in trio:
				person(root, p, team, model)
		"scout":
			person(root, Vector3(0.0, 0.03, 0.0), team, "staff")
			var dog := Node3D.new()
			dog.position = Vector3(0.12, 0.03, 0.06)
			root.add_child(dog)
			add(dog, box(Vector3(0.04, 0.04, 0.1)), mat(Color("8a6b4a")), Vector3(0, 0.05, 0))
			add(dog, box(Vector3(0.035, 0.035, 0.04)), mat(Color("8a6b4a")), Vector3(0, 0.08, 0.06))
		"horse":
			horse(root, Vector3(-0.1, 0.03, 0.04), team)
			horse(root, Vector3(0.12, 0.03, -0.06), team)
		"knight":
			horse(root, Vector3(-0.1, 0.03, 0.04), team, true)
			horse(root, Vector3(0.12, 0.03, -0.06), team, true)
		"catapult":
			var c := Node3D.new()
			c.position = Vector3(0, 0.03, 0)
			root.add_child(c)
			add(c, box(Vector3(0.16, 0.05, 0.26)), mat(WOOD), Vector3(0, 0.06, 0))
			add(c, box(Vector3(0.025, 0.025, 0.3)), mat(WOOD), Vector3(0, 0.15, -0.02), Vector3(0.7, 0, 0))
			add(c, sphere(0.03), mat(STONE), Vector3(0, 0.25, -0.12))
			for wx in [-0.09, 0.09]:
				for wz in [-0.09, 0.09]:
					add(c, cyl(0.04, 0.04, 0.02, 8), mat(DARK), Vector3(wx, 0.04, wz), Vector3(0, 0, PI / 2))
			person(root, Vector3(0.18, 0.03, 0.12), team, "")
		"cannon", "artillery":
			var c := Node3D.new()
			c.position = Vector3(0, 0.03, 0)
			root.add_child(c)
			var barrel := 0.3 if model == "cannon" else 0.4
			add(c, cyl(0.03, 0.04, barrel, 10), mat(DARK if model == "cannon" else Color("4c5a3c"), 0.35, 0.8), Vector3(0, 0.1, -0.05), Vector3(-1.3, 0, 0))
			add(c, box(Vector3(0.12, 0.05, 0.16)), mat(WOOD if model == "cannon" else Color("4c5a3c")), Vector3(0, 0.06, 0.06))
			for wx in [-0.08, 0.08]:
				add(c, cyl(0.06, 0.06, 0.02, 10), mat(WOOD.darkened(0.2)), Vector3(wx, 0.06, 0.04), Vector3(0, 0, PI / 2))
			person(root, Vector3(0.18, 0.03, 0.12), team, "")
			person(root, Vector3(-0.18, 0.03, 0.12), team, "")
		"tank":
			var t := Node3D.new()
			t.position = Vector3(0, 0.03, 0)
			root.add_child(t)
			var body := Color("56643f")
			add(t, box(Vector3(0.24, 0.07, 0.36)), mat(body, 0.6, 0.2), Vector3(0, 0.08, 0))
			for tx in [-0.13, 0.13]:
				add(t, box(Vector3(0.06, 0.07, 0.38)), mat(DARK, 0.8), Vector3(tx, 0.06, 0))
			add(t, cyl(0.08, 0.09, 0.06, 10), mat(body, 0.6, 0.2), Vector3(0, 0.15, 0.02))
			add(t, cyl(0.015, 0.015, 0.25, 8), mat(DARK, 0.4, 0.6), Vector3(0, 0.155, -0.14), Vector3(PI / 2, 0, 0))
			add(t, box(Vector3(0.1, 0.012, 0.06)), mat(team, 0.4, 0.0, 0.4), Vector3(0, 0.185, 0.03))
		"settler":
			var wagon := Node3D.new()
			wagon.position = Vector3(0.02, 0.03, -0.02)
			root.add_child(wagon)
			add(wagon, box(Vector3(0.14, 0.05, 0.22)), mat(WOOD), Vector3(0, 0.08, 0))
			add(wagon, cyl(0.075, 0.075, 0.2, 8), mat(CLOTH), Vector3(0, 0.12, 0), Vector3(PI / 2, 0, 0), Vector3(1, 1, 1))
			for wx in [-0.08, 0.08]:
				for wz in [-0.07, 0.07]:
					add(wagon, cyl(0.035, 0.035, 0.015, 8), mat(DARK), Vector3(wx, 0.045, wz), Vector3(0, 0, PI / 2))
			person(root, Vector3(0.17, 0.03, 0.1), team, "staff")
			person(root, Vector3(-0.17, 0.03, 0.12), team, "")
		"worker":
			person(root, Vector3(-0.06, 0.03, 0.02), team, "pick")
			add(root, box(Vector3(0.08, 0.06, 0.08)), mat(WOOD), Vector3(0.12, 0.06, -0.05))
	return root

# ---------------------------------------------------------------- cities

static func house(parent: Node3D, pos: Vector3, rot: float, scale: float, wall: Color, roof: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	add(n, box(Vector3(0.16, 0.12, 0.2)), mat(wall, 0.8), Vector3(0, 0.06, 0))
	add(n, prism(Vector3(0.19, 0.09, 0.22)), mat(roof, 0.7), Vector3(0, 0.165, 0))

static func tower(parent: Node3D, pos: Vector3, h: float, wall: Color, roof: Color) -> void:
	add(parent, cyl(0.07, 0.08, h, 8), mat(wall, 0.8), pos + Vector3(0, h / 2, 0))
	add(parent, cyl(0.0, 0.1, 0.14, 8), mat(roof, 0.7), pos + Vector3(0, h + 0.07, 0))

static func modern_block(parent: Node3D, pos: Vector3, rot: float, hgt: float, team: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = rot
	parent.add_child(n)
	add(n, box(Vector3(0.14, hgt, 0.14)), mat(Color("c8ccd2"), 0.35, 0.3), Vector3(0, hgt / 2, 0))
	add(n, box(Vector3(0.145, 0.015, 0.145)), mat(team, 0.4, 0.0, 0.6), Vector3(0, hgt * 0.7, 0))
	add(n, box(Vector3(0.145, hgt * 0.9, 0.02)), mat(Color("6fa6d9"), 0.1, 0.6), Vector3(0, hgt * 0.5, 0.065))
