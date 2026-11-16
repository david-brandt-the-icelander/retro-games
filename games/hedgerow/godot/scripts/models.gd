class_name Models
extends RefCounted
## Procedural 3D miniatures: tanks, guns and infantry built from primitives.

static var _mats: Dictionary = {}
static var _star: ArrayMesh

const OLIVE := Color(0.29, 0.32, 0.19)
const DUNKELGELB := Color(0.70, 0.60, 0.38)
const GUNMETAL := Color(0.16, 0.16, 0.15)


static func mat(c: Color, rough: float = 0.8, metal: float = 0.0, emissive: float = 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%.2f" % [c.to_html(), rough, metal, emissive]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	_mats[key] = m
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, rough: float = 0.8, metal: float = 0.0) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return add_mesh(parent, b, pos, mat(c, rough, metal), rot)


static func cyl(parent: Node3D, top_r: float, bot_r: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, segs: int = 16, rough: float = 0.8, metal: float = 0.0) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = h
	cm.radial_segments = segs
	cm.rings = 1
	return add_mesh(parent, cm, pos, mat(c, rough, metal), rot)


static func sphere(parent: Node3D, r: float, pos: Vector3, c: Color, scl: Vector3 = Vector3.ONE, hemi: bool = false, rough: float = 0.8) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r if hemi else r * 2.0
	sm.is_hemisphere = hemi
	sm.radial_segments = 14
	sm.rings = 7
	return add_mesh(parent, sm, pos, mat(c, rough), Vector3.ZERO, scl)


static func capsule(parent: Node3D, r: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var cm := CapsuleMesh.new()
	cm.radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 3
	return add_mesh(parent, cm, pos, mat(c, 0.9), rot, scl)


static func wedge(parent: Node3D, run: float, rise: float, width: float, pos: Vector3, c: Color) -> MeshInstance3D:
	# Right-triangle prism: vertical face at the back (+Z), slope descending toward -Z.
	var pm := PrismMesh.new()
	pm.left_to_right = 1.0
	pm.size = Vector3(run, rise, width)
	return add_mesh(parent, pm, pos, mat(c, 0.75), Vector3(0, -PI * 0.5, 0))


static func star_mesh() -> ArrayMesh:
	if _star != null:
		return _star
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a: float = -PI * 0.5 + i * PI / 5.0
		var r: float = 1.0 if i % 2 == 0 else 0.4
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0.0))
	for i in 10:
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.set_normal(Vector3.BACK)
		st.add_vertex(pts[i])
		st.set_normal(Vector3.BACK)
		st.add_vertex(pts[(i + 1) % 10])
	_star = st.commit()
	return _star


static func _decal_mat(c: Color) -> StandardMaterial3D:
	var key := "decal" + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[key] = m
	return m


static func us_star(parent: Node3D, pos: Vector3, side_sign: float, size: float) -> void:
	var mi := add_mesh(parent, star_mesh(), pos, _decal_mat(Color(0.92, 0.92, 0.88)), Vector3(0, side_sign * PI * 0.5, 0), Vector3.ONE * size)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func balkenkreuz(parent: Node3D, pos: Vector3, side_sign: float) -> void:
	var w := Color(0.9, 0.9, 0.88)
	var k := Color(0.05, 0.05, 0.05)
	box(parent, Vector3(0.004, 0.034, 0.15), pos, w)
	box(parent, Vector3(0.004, 0.15, 0.034), pos, w)
	var p2 := pos + Vector3(side_sign * 0.002, 0, 0)
	box(parent, Vector3(0.006, 0.016, 0.13), p2, k)
	box(parent, Vector3(0.006, 0.13, 0.016), p2, k)


# ------------------------------------------------------------------ vehicles

static func _veh_cfg(model: String) -> Dictionary:
	match model:
		"sherman":
			return {"len": 1.05, "wid": 0.6, "h": 0.2, "upper": 0.72, "col": OLIVE, "turret": "sherman", "tz": 0.0,
				"bl": 0.42, "br": 0.026, "brake": false, "wheels": 6, "wr": 0.075, "skirts": false, "camo": false}
		"m10":
			return {"len": 1.1, "wid": 0.62, "h": 0.17, "upper": 0.66, "col": OLIVE.lightened(0.04), "turret": "open", "tz": 0.02,
				"bl": 0.62, "br": 0.028, "brake": false, "wheels": 6, "wr": 0.075, "skirts": false, "camo": false}
		"pz4":
			return {"len": 1.02, "wid": 0.56, "h": 0.2, "upper": 0.86, "col": DUNKELGELB, "turret": "box", "tz": 0.0,
				"bl": 0.6, "br": 0.024, "brake": true, "wheels": 8, "wr": 0.052, "skirts": true, "camo": true}
		"panther":
			return {"len": 1.22, "wid": 0.66, "h": 0.22, "upper": 0.62, "col": DUNKELGELB.lightened(0.03), "turret": "panther", "tz": 0.06,
				"bl": 0.86, "br": 0.026, "brake": true, "wheels": 8, "wr": 0.085, "skirts": false, "camo": true}
		"stug":
			return {"len": 1.0, "wid": 0.56, "h": 0.13, "upper": 0.84, "col": DUNKELGELB.darkened(0.04), "turret": "casemate", "tz": -0.06,
				"bl": 0.52, "br": 0.024, "brake": true, "wheels": 6, "wr": 0.06, "skirts": true, "camo": true}
	return {}


static func build_vehicle(model: String, side: String) -> Node3D:
	var p: Dictionary = _veh_cfg(model)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var root := Node3D.new()
	var L: float = p["len"]
	var W: float = p["wid"]
	var H: float = p["h"]
	var col: Color = p["col"]
	var dark: Color = col.darkened(0.3)
	var hull := Node3D.new()
	hull.name = "Hull"
	root.add_child(hull)
	var track := Color(0.12, 0.11, 0.10)
	var tw := 0.13
	for sx in [-1.0, 1.0]:
		var tx: float = sx * (W * 0.5 - tw * 0.5)
		box(hull, Vector3(tw, 0.15, L * 0.96), Vector3(tx, 0.085, 0.0), track, Vector3.ZERO, 0.95, 0.2)
		var n: int = p["wheels"]
		var wr: float = p["wr"]
		for i in n:
			var z: float = lerpf(-L * 0.36, L * 0.36, float(i) / float(n - 1))
			cyl(hull, wr, wr, 0.025, Vector3(tx + sx * (tw * 0.5 + 0.004), 0.075, z), Color(0.2, 0.2, 0.18), Vector3(0, 0, PI * 0.5), 10)
		cyl(hull, 0.06, 0.06, 0.03, Vector3(tx + sx * (tw * 0.5 + 0.006), 0.12, -L * 0.45), Color(0.18, 0.18, 0.16), Vector3(0, 0, PI * 0.5), 10, 0.6, 0.4)
		cyl(hull, 0.05, 0.05, 0.03, Vector3(tx + sx * (tw * 0.5 + 0.006), 0.11, L * 0.45), Color(0.18, 0.18, 0.16), Vector3(0, 0, PI * 0.5), 10)
		box(hull, Vector3(tw + 0.02, 0.012, L * 0.98), Vector3(tx, 0.185, 0.0), col.darkened(0.1))
		if p["skirts"]:
			box(hull, Vector3(0.012, 0.12, L * 0.78), Vector3(sx * (W * 0.5 + 0.02), 0.17, 0.02), col.darkened(0.05))
	box(hull, Vector3(W - 2.0 * tw + 0.02, 0.12, L * 0.9), Vector3(0, 0.13, 0), dark)
	# upper hull
	var up_len: float = L * float(p["upper"])
	var zb: float = L * 0.46
	var zf: float = zb - up_len
	var top_y: float = 0.19 + H
	box(hull, Vector3(W, H, up_len), Vector3(0, 0.19 + H * 0.5, (zb + zf) * 0.5), col, Vector3.ZERO, 0.72)
	var run: float = zf + L * 0.47
	if run > 0.02:
		var rise: float = top_y - 0.11
		wedge(hull, run, rise, W, Vector3(0, 0.11 + rise * 0.5, zf - run * 0.5), col)
	# engine deck & details
	box(hull, Vector3(W * 0.55, 0.012, L * 0.2), Vector3(0, top_y + 0.006, zb - L * 0.13), col.darkened(0.2))
	box(hull, Vector3(0.05, 0.03, 0.03), Vector3(-W * 0.3, top_y - 0.02, -L * 0.47), Color(0.1, 0.1, 0.1))
	box(hull, Vector3(0.18, 0.025, 0.04), Vector3(W * 0.22, top_y + 0.012, zb - 0.05), Color(0.25, 0.2, 0.14))
	if side == "US":
		cyl(hull, 0.012, 0.012, 0.12, Vector3(W * 0.25, top_y + 0.01, zf + 0.03), GUNMETAL, Vector3(PI * 0.5, 0, 0), 6)
	# camouflage
	if p["camo"]:
		var camo := [Color(0.30, 0.36, 0.20), Color(0.44, 0.27, 0.17)]
		for i in 9:
			var cc: Color = camo[i % 2]
			box(hull, Vector3(rng.randf_range(0.08, 0.22), 0.006, rng.randf_range(0.1, 0.26)),
				Vector3(rng.randf_range(-W * 0.35, W * 0.35), top_y + 0.004, rng.randf_range(zf + 0.05, zb - 0.05)), cc)
		for i in 6:
			var cc2: Color = camo[i % 2]
			var sx2: float = 1.0 if i % 2 == 0 else -1.0
			box(hull, Vector3(0.006, rng.randf_range(0.04, H * 0.8), rng.randf_range(0.1, 0.25)),
				Vector3(sx2 * (W * 0.5 + 0.002), 0.19 + H * 0.5, rng.randf_range(zf + 0.05, zb - 0.05)), cc2)
	# national markings
	var mz: float = (zb + zf) * 0.5 + 0.08
	for s in [-1.0, 1.0]:
		var mp := Vector3(s * (W * 0.5 + 0.004), 0.19 + H * 0.55, mz)
		if side == "US":
			us_star(hull, mp, s, 0.075)
		else:
			balkenkreuz(hull, mp, s)
	# turret
	var tur := Node3D.new()
	tur.name = "Turret"
	tur.position = Vector3(0, top_y, float(p["tz"]))
	root.add_child(tur)
	var bl: float = p["bl"]
	var br: float = p["br"]
	var bpiv := Vector3(0, 0.08, -0.22)
	match String(p["turret"]):
		"sherman":
			cyl(tur, 0.2, 0.23, 0.13, Vector3(0, 0.065, 0.02), col, Vector3.ZERO, 22, 0.7)
			sphere(tur, 0.2, Vector3(0, 0.125, 0.02), col, Vector3(1.0, 0.42, 1.05), true, 0.7)
			box(tur, Vector3(0.22, 0.1, 0.16), Vector3(0, 0.075, 0.2), col.darkened(0.05))
			box(tur, Vector3(0.2, 0.11, 0.06), Vector3(0, 0.075, -0.2), col.darkened(0.08))
			cyl(tur, 0.05, 0.055, 0.05, Vector3(0.08, 0.2, 0.06), col.darkened(0.1), Vector3.ZERO, 10)
			cyl(tur, 0.009, 0.009, 0.22, Vector3(0.08, 0.255, -0.04), GUNMETAL, Vector3(PI * 0.5, 0, 0), 6)
			for s in [-1.0, 1.0]:
				us_star(tur, Vector3(s * 0.232, 0.07, 0.04), s, 0.05)
			bpiv = Vector3(0, 0.075, -0.23)
		"open":
			cyl(tur, 0.21, 0.25, 0.15, Vector3(0, 0.075, 0), col, Vector3.ZERO, 5, 0.7)
			cyl(tur, 0.19, 0.19, 0.01, Vector3(0, 0.13, 0), Color(0.12, 0.12, 0.1), Vector3.ZERO, 5)
			box(tur, Vector3(0.32, 0.1, 0.16), Vector3(0, 0.07, 0.27), col.darkened(0.08))
			box(tur, Vector3(0.14, 0.1, 0.08), Vector3(0, 0.07, -0.22), col.darkened(0.08))
			cyl(tur, 0.01, 0.01, 0.2, Vector3(0.12, 0.2, 0.1), GUNMETAL, Vector3(PI * 0.5, 0, 0), 6)
			bpiv = Vector3(0, 0.07, -0.25)
		"box":
			box(tur, Vector3(0.34, 0.16, 0.42), Vector3(0, 0.08, 0.03), col, Vector3.ZERO, 0.72)
			box(tur, Vector3(0.16, 0.1, 0.05), Vector3(0, 0.08, -0.2), col.darkened(0.08))
			cyl(tur, 0.05, 0.055, 0.05, Vector3(0, 0.18, 0.16), col.darkened(0.1), Vector3.ZERO, 12)
			for s in [-1.0, 1.0]:
				box(tur, Vector3(0.01, 0.13, 0.48), Vector3(s * 0.23, 0.07, 0.05), col.darkened(0.04))
			box(tur, Vector3(0.47, 0.13, 0.01), Vector3(0, 0.07, 0.29), col.darkened(0.04))
			bpiv = Vector3(0, 0.08, -0.22)
		"panther":
			box(tur, Vector3(0.38, 0.17, 0.46), Vector3(0, 0.085, 0.06), col, Vector3.ZERO, 0.72)
			cyl(tur, 0.075, 0.075, 0.24, Vector3(0, 0.085, -0.18), col.darkened(0.06), Vector3(0, 0, PI * 0.5), 14)
			cyl(tur, 0.055, 0.06, 0.06, Vector3(-0.1, 0.19, 0.16), col.darkened(0.1), Vector3.ZERO, 12)
			box(tur, Vector3(0.3, 0.02, 0.08), Vector3(0, 0.18, -0.02), col.darkened(0.15))
			bpiv = Vector3(0, 0.085, -0.25)
		"casemate":
			tur.position = Vector3(0, top_y, float(p["tz"]))
			box(tur, Vector3(W * 0.82, 0.15, 0.5), Vector3(0, 0.075, 0.02), col, Vector3.ZERO, 0.72)
			sphere(tur, 0.075, Vector3(0.05, 0.08, -0.24), col.darkened(0.06), Vector3(1.0, 0.85, 1.2))
			cyl(tur, 0.05, 0.055, 0.05, Vector3(-0.12, 0.17, 0.08), col.darkened(0.1), Vector3.ZERO, 12)
			box(tur, Vector3(0.06, 0.03, 0.14), Vector3(0.12, 0.165, 0.0), GUNMETAL)
			bpiv = Vector3(0.05, 0.08, -0.29)
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	barrel.position = bpiv
	tur.add_child(barrel)
	cyl(barrel, br, br * 1.25, bl, Vector3(0, 0, -bl * 0.5), col.darkened(0.12), Vector3(PI * 0.5, 0, 0), 10, 0.6, 0.3)
	if p["brake"]:
		cyl(barrel, br * 1.7, br * 1.7, 0.06, Vector3(0, 0, -bl), col.darkened(0.2), Vector3(PI * 0.5, 0, 0), 10, 0.6, 0.3)
	var muz := Marker3D.new()
	muz.name = "Muzzle"
	muz.position = Vector3(0, 0, -bl - 0.05)
	barrel.add_child(muz)
	# camo on turret
	if p["camo"]:
		var camo2 := [Color(0.30, 0.36, 0.20), Color(0.44, 0.27, 0.17)]
		for i in 3:
			box(tur, Vector3(rng.randf_range(0.06, 0.14), 0.006, rng.randf_range(0.08, 0.16)),
				Vector3(rng.randf_range(-0.1, 0.1), 0.172, rng.randf_range(-0.1, 0.15)), camo2[i % 2])
	return root


# ------------------------------------------------------------------ infantry

static func soldier(parent: Node3D, pos: Vector3, yaw: float, side: String, pose: String, weapon: String) -> Node3D:
	var s := Node3D.new()
	s.position = pos
	s.rotation.y = yaw
	parent.add_child(s)
	var us := side == "US"
	var tunic: Color = Color(0.43, 0.40, 0.27) if us else Color(0.37, 0.40, 0.34)
	var trousers: Color = Color(0.40, 0.37, 0.27) if us else Color(0.33, 0.35, 0.31)
	var helm: Color = Color(0.29, 0.32, 0.20) if us else Color(0.30, 0.32, 0.30)
	var skin := Color(0.86, 0.68, 0.55)
	var boots := Color(0.16, 0.12, 0.09)
	var wood := Color(0.33, 0.21, 0.12)
	var head := Vector3.ZERO
	var torso_y := 0.0
	match pose:
		"prone":
			capsule(s, 0.04, 0.17, Vector3(0, 0.035, 0.0), tunic, Vector3(PI * 0.5, 0, 0), Vector3(1.15, 1.0, 0.8))
			box(s, Vector3(0.07, 0.035, 0.16), Vector3(0, 0.022, 0.15), trousers)
			box(s, Vector3(0.07, 0.03, 0.04), Vector3(0, 0.02, 0.24), boots)
			box(s, Vector3(0.07, 0.035, 0.06), Vector3(0, 0.07, 0.04), Color(0.3, 0.27, 0.18))
			head = Vector3(0, 0.06, -0.11)
		"kneel":
			box(s, Vector3(0.075, 0.05, 0.11), Vector3(0, 0.035, 0.03), trousers)
			box(s, Vector3(0.03, 0.08, 0.03), Vector3(0.025, 0.04, -0.03), trousers)
			box(s, Vector3(0.035, 0.02, 0.06), Vector3(-0.02, 0.01, 0.09), boots)
			torso_y = 0.135
			capsule(s, 0.04, 0.15, Vector3(0, torso_y, 0.0), tunic, Vector3(-0.15, 0, 0), Vector3(1.15, 1.0, 0.8))
			head = Vector3(0, 0.235, -0.015)
		_:
			for lx in [-0.021, 0.021]:
				box(s, Vector3(0.03, 0.13, 0.035), Vector3(lx, 0.065, 0), trousers)
				box(s, Vector3(0.032, 0.025, 0.05), Vector3(lx, 0.012, -0.006), boots)
			torso_y = 0.19
			capsule(s, 0.04, 0.15, Vector3(0, torso_y, 0), tunic, Vector3.ZERO, Vector3(1.15, 1.0, 0.8))
			head = Vector3(0, 0.29, 0)
	if pose != "prone":
		box(s, Vector3(0.065, 0.075, 0.035), Vector3(0, torso_y + 0.01, 0.045), Color(0.33, 0.30, 0.2))
		for ax in [-1.0, 1.0]:
			box(s, Vector3(0.024, 0.1, 0.024), Vector3(ax * 0.05, torso_y + 0.01, -0.03), tunic, Vector3(-0.9, 0, 0))
	sphere(s, 0.03, head, skin)
	if us:
		sphere(s, 0.038, head + Vector3(0, 0.006, 0), helm, Vector3(1.0, 0.85, 1.05), true, 0.6)
		cyl(s, 0.041, 0.042, 0.006, head + Vector3(0, 0.006, 0), helm, Vector3.ZERO, 12)
	else:
		sphere(s, 0.039, head + Vector3(0, 0.008, 0), helm, Vector3(1.05, 0.95, 1.1), true, 0.6)
		cyl(s, 0.041, 0.05, 0.022, head + Vector3(0, -0.002, 0.004), helm, Vector3.ZERO, 12)
	var wy: float = torso_y + 0.04 if pose != "prone" else 0.05
	var wz: float = -0.08 if pose != "prone" else -0.2
	match weapon:
		"rifle":
			box(s, Vector3(0.012, 0.016, 0.19), Vector3(0.03, wy, wz), wood, Vector3(0.08, 0, 0))
			box(s, Vector3(0.007, 0.007, 0.08), Vector3(0.03, wy + 0.008, wz - 0.11), GUNMETAL)
		"smg":
			box(s, Vector3(0.014, 0.03, 0.13), Vector3(0.03, wy, wz + 0.02), GUNMETAL)
		"tube":
			var tc: Color = Color(0.3, 0.33, 0.2) if us else Color(0.55, 0.5, 0.34)
			var tlen: float = 0.3 if us else 0.34
			cyl(s, 0.018, 0.02, tlen, Vector3(0.045, torso_y + 0.075, -0.03), tc, Vector3(PI * 0.5, 0, 0), 10)
			if not us:
				box(s, Vector3(0.09, 0.08, 0.006), Vector3(0.045, torso_y + 0.085, -0.1), tc)
	return s


static func build_infantry(model: String, side: String, steps: int) -> Node3D:
	var root := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match model:
		"squad":
			var spots := [
				[Vector3(0.0, 0, -0.18), "kneel", "rifle"],
				[Vector3(-0.27, 0, -0.02), "stand", "rifle"],
				[Vector3(0.27, 0, -0.04), "kneel", "rifle"],
				[Vector3(-0.1, 0, 0.24), "stand", "smg"],
				[Vector3(0.2, 0, 0.26), "prone", "rifle"],
			]
			var n: int = 5 if steps >= 2 else 3
			for i in n:
				var j := Vector3(rng.randf_range(-0.04, 0.04), 0, rng.randf_range(-0.04, 0.04))
				soldier(root, spots[i][0] + j, rng.randf_range(-0.35, 0.35), side, spots[i][1], spots[i][2])
		"mg":
			soldier(root, Vector3(0, 0, 0.08), 0.0, side, "prone", "none")
			var mg := Node3D.new()
			mg.position = Vector3(0, 0, -0.1)
			root.add_child(mg)
			box(mg, Vector3(0.045, 0.05, 0.12), Vector3(0, 0.07, 0.0), GUNMETAL, Vector3.ZERO, 0.5, 0.5)
			box(mg, Vector3(0.016, 0.016, 0.22), Vector3(0, 0.075, -0.15), GUNMETAL, Vector3.ZERO, 0.5, 0.5)
			box(mg, Vector3(0.03, 0.035, 0.05), Vector3(0, 0.065, 0.08), Color(0.25, 0.18, 0.1))
			for lx in [-1.0, 1.0]:
				box(mg, Vector3(0.01, 0.09, 0.01), Vector3(lx * 0.04, 0.035, -0.02), GUNMETAL, Vector3(0.3, 0, lx * 0.35))
			box(mg, Vector3(0.01, 0.08, 0.01), Vector3(0, 0.035, 0.05), GUNMETAL, Vector3(-0.4, 0, 0))
			soldier(root, Vector3(0.24, 0, 0.12), -0.3, side, "kneel", "none")
			box(root, Vector3(0.07, 0.05, 0.04), Vector3(0.14, 0.025, 0.02), Color(0.28, 0.3, 0.2))
			if side == "DE":
				soldier(root, Vector3(-0.25, 0, 0.18), 0.4, side, "kneel", "rifle")
		"bazooka":
			soldier(root, Vector3(0, 0, -0.02), 0.0, side, "kneel", "tube")
			soldier(root, Vector3(0.24, 0, 0.14), -0.25, side, "kneel", "rifle")
			box(root, Vector3(0.05, 0.04, 0.12), Vector3(0.12, 0.02, 0.2), Color(0.3, 0.3, 0.22))
		"atgun":
			return build_gun(side)
	return root


static func build_gun(side: String) -> Node3D:
	var root := Node3D.new()
	var us := side == "US"
	var col: Color = OLIVE if us else Color(0.58, 0.53, 0.38)
	var tire := Color(0.1, 0.1, 0.1)
	var g := Node3D.new()
	g.name = "Turret"
	root.add_child(g)
	for sx in [-1.0, 1.0]:
		cyl(g, 0.1, 0.1, 0.045, Vector3(sx * 0.22, 0.1, 0.02), tire, Vector3(0, 0, PI * 0.5), 16, 0.95)
		cyl(g, 0.05, 0.05, 0.05, Vector3(sx * 0.22, 0.1, 0.02), col.darkened(0.1), Vector3(0, 0, PI * 0.5), 10)
		box(g, Vector3(0.04, 0.04, 0.55), Vector3(sx * 0.12, 0.05, 0.3), col, Vector3(-0.12, sx * 0.28, 0))
	box(g, Vector3(0.42, 0.04, 0.05), Vector3(0, 0.1, 0.02), col.darkened(0.1))
	box(g, Vector3(0.09, 0.09, 0.32), Vector3(0, 0.16, -0.02), col)
	box(g, Vector3(0.48, 0.24, 0.014), Vector3(0, 0.22, -0.1), col, Vector3(0.14, 0, 0), 0.7)
	if not us:
		box(g, Vector3(0.48, 0.1, 0.014), Vector3(0, 0.36, -0.12), col, Vector3(0.14, 0, 0), 0.7)
	var barrel := Node3D.new()
	barrel.name = "Barrel"
	barrel.position = Vector3(0, 0.18, -0.12)
	g.add_child(barrel)
	var bl: float = 0.5 if us else 0.62
	cyl(barrel, 0.022, 0.03, bl, Vector3(0, 0, -bl * 0.5), col.darkened(0.12), Vector3(PI * 0.5, 0, 0), 10, 0.6, 0.3)
	if not us:
		cyl(barrel, 0.04, 0.04, 0.06, Vector3(0, 0, -bl), col.darkened(0.2), Vector3(PI * 0.5, 0, 0), 10)
	var muz := Marker3D.new()
	muz.name = "Muzzle"
	muz.position = Vector3(0, 0, -bl - 0.05)
	barrel.add_child(muz)
	soldier(root, Vector3(-0.3, 0, 0.12), 0.2, side, "kneel", "none")
	soldier(root, Vector3(0.3, 0, 0.2), -0.3, side, "kneel", "none")
	soldier(root, Vector3(0.05, 0, 0.5), 0.0, side, "stand", "rifle")
	box(root, Vector3(0.12, 0.06, 0.06), Vector3(0.22, 0.03, 0.4), Color(0.3, 0.28, 0.18))
	return root


static func build(model: String, side: String, steps: int) -> Node3D:
	if model in ["sherman", "m10", "pz4", "panther", "stug"]:
		return build_vehicle(model, side)
	return build_infantry(model, side, steps)
