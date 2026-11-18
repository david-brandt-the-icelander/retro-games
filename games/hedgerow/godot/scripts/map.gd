class_name GameMap
extends Node3D
## Hex battlefield: generation, terrain rules (movement, cover, line of sight)
## and the 3D diorama (stepped hex tiles, trees, wheat, houses, church, stream).

const COLS := 22
const ROWS := 16
const LEVEL_H := 0.42
const BASE_Y := -0.75
const R_TOP := 0.9
const R_OUT := 0.985

enum { OPEN, FIELD, WOODS, BUILDING, WATER }
const T_NAMES := ["Open ground", "Wheat field", "Woods", "Buildings", "Stream"]

var tiles: Dictionary = {}
var objectives: Array = []
var rng := RandomNumberGenerator.new()
var terrain_mat: StandardMaterial3D
var _mm: Dictionary = {}
var _meshes: Dictionary = {}
var _overlay: Dictionary = {}
var _ov_mats: Dictionary = {}
var _fill_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _hover: MeshInstance3D
var _flags: Array = []


# =================================================================== generation

func generate(seed_val: int) -> void:
	rng.seed = seed_val
	var n1 := FastNoiseLite.new()
	n1.seed = seed_val
	n1.frequency = 0.09
	var n2 := FastNoiseLite.new()
	n2.seed = seed_val + 7
	n2.frequency = 0.13
	var n3 := FastNoiseLite.new()
	n3.seed = seed_val + 13
	n3.frequency = 0.11
	for row in ROWS:
		for col in COLS:
			var h := Hex.offset_to_axial(col, row)
			var v: float = n1.get_noise_2d(col * 1.0, row * 1.0) * 0.9
			v += _bump(col, row, 17, 4, 2.7, 3.0) + _bump(col, row, 4, 6, 1.7, 2.4) + _bump(col, row, 11, 5, 0.5, 3.0)
			var elev: int = clampi(int(floor(v + 0.3)), 0, 3)
			if row >= 12:
				elev = mini(elev, 1)
			tiles[h] = {"t": OPEN, "elev": elev, "road": false, "obj": -1, "col": col, "row": row, "y": 0.0, "church": false}
	# meandering stream
	var prev := Vector2i(-999, 0)
	for col in COLS:
		var row: int = 10 + int(round(sin(col * 0.42 + 0.5) * 1.3))
		var h := Hex.offset_to_axial(col, row)
		if prev.x == -999:
			_mark_stream(h)
		else:
			for x in Hex.line(prev, h):
				_mark_stream(x)
		prev = h
	# roads
	var village := Hex.offset_to_axial(11, 5)
	_road([Hex.offset_to_axial(10, 15), Hex.offset_to_axial(10, 9), village, Hex.offset_to_axial(12, 0)])
	_road([Hex.offset_to_axial(0, 6), village, Hex.offset_to_axial(21, 3)])
	# village
	for h in tiles:
		var t: Dictionary = tiles[h]
		if Hex.distance(h, village) <= 2 and not t["road"] and t["t"] != WATER and rng.randf() < 0.62:
			t["t"] = BUILDING
	var church := Vector2i(-999, 0)
	for n in Hex.neighbors(village):
		if tiles.has(n) and not tiles[n]["road"]:
			church = n
			break
	tiles[church]["t"] = BUILDING
	tiles[church]["church"] = true
	_add_objective("St. Aubin Church", church)
	# Hill 112 = highest hex near the eastern bump
	var hill := Hex.offset_to_axial(17, 4)
	for h in tiles:
		if Hex.distance(h, Hex.offset_to_axial(17, 4)) <= 3 and int(tiles[h]["elev"]) > int(tiles[hill]["elev"]) and not tiles[h]["road"]:
			hill = h
	tiles[hill]["elev"] = 3
	_add_objective("Hill 112", hill)
	# farm on the western rise
	var farm := Hex.offset_to_axial(4, 6)
	tiles[farm]["t"] = BUILDING
	var fb := 0
	for n in Hex.neighbors(farm):
		if fb < 2 and tiles.has(n) and not tiles[n]["road"] and tiles[n]["t"] != WATER and rng.randf() < 0.6:
			tiles[n]["t"] = BUILDING
			fb += 1
	_add_objective("Ferme Lebrun", farm)
	# woods and fields
	for h in tiles:
		var t: Dictionary = tiles[h]
		if t["road"] or int(t["t"]) != OPEN or int(t["obj"]) >= 0:
			continue
		var col: int = t["col"]
		var row: int = t["row"]
		var w: float = n2.get_noise_2d(col * 1.0, row * 1.0)
		var f: float = n3.get_noise_2d(col * 1.0, row * 1.0)
		if w > 0.2:
			t["t"] = WOODS
		elif f > 0.22 and int(t["elev"]) <= 1:
			t["t"] = FIELD
	for h in tiles:
		var t: Dictionary = tiles[h]
		if int(t["t"]) == WATER:
			t["y"] = -0.16
		else:
			t["y"] = int(t["elev"]) * LEVEL_H + rng.randf_range(0.0, 0.035)


func _bump(c: int, r: int, cx: int, cy: int, amp: float, rad: float) -> float:
	var dc: float = float(c - cx)
	var dr: float = float(r - cy) * 0.9
	return amp * exp(-(dc * dc + dr * dr) / (2.0 * rad * rad))


func _mark_stream(h: Vector2i) -> void:
	if tiles.has(h):
		tiles[h]["t"] = WATER
		tiles[h]["elev"] = 0


func _road(pts: Array) -> void:
	for i in range(pts.size() - 1):
		for h in Hex.line(pts[i], pts[i + 1]):
			if tiles.has(h):
				tiles[h]["road"] = true
				if int(tiles[h]["t"]) != WATER:
					tiles[h]["t"] = OPEN


func _add_objective(nm: String, h: Vector2i) -> void:
	tiles[h]["obj"] = objectives.size()
	objectives.append({"name": nm, "hex": h, "owner": "DE"})


# =================================================================== queries

func has(h: Vector2i) -> bool:
	return tiles.has(h)


func ttype(h: Vector2i) -> int:
	return int(tiles[h]["t"])


func elev(h: Vector2i) -> int:
	return int(tiles[h]["elev"])


func is_road(h: Vector2i) -> bool:
	return bool(tiles[h]["road"])


func is_bridge(h: Vector2i) -> bool:
	return ttype(h) == WATER and is_road(h)


func top_y(h: Vector2i) -> float:
	if is_bridge(h):
		return 0.09
	return float(tiles[h]["y"])


func unit_pos(h: Vector2i) -> Vector3:
	var off: Vector3 = tiles[h].get("bofs", Vector3.ZERO)
	return Hex.to_world(h, top_y(h) + 0.005) - off * 1.05


func tem(h: Vector2i) -> int:
	match ttype(h):
		WOODS:
			return 1
		BUILDING:
			return 2
		WATER:
			return 0 if is_road(h) else -1
	return 0


func concealing(h: Vector2i) -> int:
	## Max distance at which an unrevealed unit in this hex can be spotted (0 = no concealment).
	match ttype(h):
		WOODS, BUILDING:
			return 4
		FIELD:
			return 6
	return 0


func obstacle_height(h: Vector2i) -> float:
	var e: float = float(elev(h))
	var t: int = ttype(h)
	if t == WOODS or t == BUILDING:
		e += 1.0
	return e


func los(a: Vector2i, b: Vector2i) -> bool:
	if a == b:
		return true
	var ha: float = float(elev(a)) + 0.5
	var hb: float = float(elev(b)) + 0.5
	var ln := Hex.line(a, b)
	var n: int = ln.size() - 1
	for i in range(1, n):
		var h: Vector2i = ln[i]
		if not tiles.has(h):
			continue
		var lh: float = lerpf(ha, hb, float(i) / float(n))
		if obstacle_height(h) > lh + 0.01:
			return false
	return true


func move_cost(kind: String, a: Vector2i, b: Vector2i) -> float:
	var veh: bool = kind == "vehicle"
	var tb: int = ttype(b)
	var c := 1.0
	if is_road(a) and is_road(b):
		c = 0.5 if veh else 1.0
	else:
		match tb:
			OPEN:
				c = 1.0
			FIELD:
				c = 1.5 if veh else 1.0
			WOODS:
				c = 3.0 if veh else 2.0
			BUILDING:
				c = 99.0 if veh else 2.0
			WATER:
				if is_road(b):
					c = 99.0 if veh else 1.0
				else:
					c = 99.0 if veh else 3.0
	var climb: int = elev(b) - elev(a)
	if climb > 0:
		c += float(climb)
	return c


func describe(h: Vector2i) -> String:
	var t: int = ttype(h)
	var s: String = T_NAMES[t]
	if is_bridge(h):
		s = "Stone bridge"
	elif is_road(h):
		s = "Road"
	if bool(tiles[h]["church"]):
		s = "Church"
	var txt := "[b]%s[/b]   ·   Elevation %d" % [s, elev(h)]
	var tm: int = tem(h)
	if tm > 0:
		txt += "   ·   Cover [color=#9fe08a]+%d[/color]" % tm
	elif tm < 0:
		txt += "   ·   [color=#ff9a7a]Exposed (wading)[/color]"
	if concealing(h) > 0:
		txt += "   ·   Concealment"
	var oi: int = tiles[h]["obj"]
	if oi >= 0:
		var o: Dictionary = objectives[oi]
		txt += "\n[color=#f0c860]Objective: %s[/color]  (held by %s)" % [o["name"], "US" if o["owner"] == "US" else "Germans"]
	return txt


func bounds() -> Rect2:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for h in tiles:
		var p := Hex.to_world(h)
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	return Rect2(mn, mx - mn)


# =================================================================== visuals

func build_visuals() -> void:
	_make_meshes()
	var noise := FastNoiseLite.new()
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.72, 0.72, 0.72))
	ramp.set_color(1, Color(1.08, 1.08, 1.08))
	tex.color_ramp = ramp
	terrain_mat = StandardMaterial3D.new()
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.vertex_color_is_srgb = true
	terrain_mat.albedo_texture = tex
	terrain_mat.uv1_triplanar = true
	terrain_mat.uv1_scale = Vector3(0.35, 0.35, 0.35)
	terrain_mat.roughness = 0.95

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var water := SurfaceTool.new()
	water.begin(Mesh.PRIMITIVE_TRIANGLES)
	for h in tiles:
		_build_tile(st, water, h)
	# decorative border so the battlefield sits in a wider landscape
	for row in range(-4, ROWS + 4):
		for col in range(-5, COLS + 5):
			if col >= 0 and col < COLS and row >= 0 and row < ROWS:
				continue
			_build_border_tile(st, Hex.offset_to_axial(col, row))
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	add_child(mi)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	cs.shape = mesh.create_trimesh_shape()
	body.add_child(cs)
	add_child(body)

	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.16, 0.30, 0.34, 0.72)
	wm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wm.roughness = 0.06
	wm.metallic = 0.3
	var wn := NoiseTexture2D.new()
	wn.seamless = true
	wn.as_normal_map = true
	wn.bump_strength = 4.0
	var wnn := FastNoiseLite.new()
	wnn.frequency = 0.08
	wn.noise = wnn
	wm.normal_enabled = true
	wm.normal_texture = wn
	wm.uv1_triplanar = true
	wm.uv1_scale = Vector3(0.5, 0.5, 0.5)
	var wmi := MeshInstance3D.new()
	wmi.mesh = water.commit()
	wmi.material_override = wm
	wmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wmi)

	# far ground plane
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.material_override = Models.mat(Color(0.2, 0.26, 0.14), 1.0)
	var b := bounds()
	ground.position = Vector3(b.get_center().x, -0.05, b.get_center().y)
	add_child(ground)

	_flush_multimesh()
	_build_overlays()
	_build_objective_markers()


func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	# Godot treats clockwise triangles (seen from the front) as front faces.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var tv := b
		b = c
		c = tv
		var tc := cb
		cb = cc
		cc = tc
	st.set_normal(n)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(cc)
	st.add_vertex(c)


func _prism(st: SurfaceTool, center: Vector3, top: Color, side_top: Color, side_bot: Color) -> void:
	var bevel := 0.05
	var bev_col := top.darkened(0.18)
	for i in 6:
		var c0 := Hex.corner(i)
		var c1 := Hex.corner((i + 1) % 6)
		var it0 := center + c0 * R_TOP
		var it1 := center + c1 * R_TOP
		var ot0 := center + c0 * R_OUT + Vector3(0, -bevel, 0)
		var ot1 := center + c1 * R_OUT + Vector3(0, -bevel, 0)
		var ob0 := Vector3(ot0.x, BASE_Y, ot0.z)
		var ob1 := Vector3(ot1.x, BASE_Y, ot1.z)
		var tc := top.lightened(0.03)
		_tri(st, center, it0, it1, Vector3.UP, tc, top, top)
		var mid := (c0 + c1).normalized()
		var bn := (mid * bevel + Vector3.UP * (R_OUT - R_TOP)).normalized()
		_tri(st, it0, ot0, ot1, bn, top, bev_col, bev_col)
		_tri(st, it0, ot1, it1, bn, top, bev_col, top)
		_tri(st, ot0, ob0, ob1, mid, side_top, side_bot, side_bot)
		_tri(st, ot0, ob1, ot1, mid, side_top, side_bot, side_top)


func _jit(c: Color, amt: float) -> Color:
	return Color(c.r + rng.randf_range(-amt, amt), c.g + rng.randf_range(-amt, amt), c.b + rng.randf_range(-amt, amt) * 0.5)


func _top_color(t: int, e: int) -> Color:
	var c: Color
	match t:
		FIELD:
			c = Color(0.66, 0.56, 0.28)
		WOODS:
			c = Color(0.22, 0.28, 0.13)
		BUILDING:
			c = Color(0.42, 0.40, 0.33)
		WATER:
			c = Color(0.24, 0.21, 0.15)
		_:
			c = Color(0.33, 0.45, 0.19)
	if t != WATER and t != BUILDING:
		c = c.lerp(Color(0.5, 0.5, 0.3), e * 0.06)
	return c


func _build_tile(st: SurfaceTool, water: SurfaceTool, h: Vector2i) -> void:
	var t: int = ttype(h)
	var e: int = elev(h)
	var y: float = float(tiles[h]["y"])
	var center := Hex.to_world(h, y)
	var top := _jit(_top_color(t, e), 0.025)
	var side_top: Color = Color(0.34, 0.26, 0.17) if e < 2 else Color(0.42, 0.39, 0.34)
	side_top = _jit(side_top, 0.02)
	_prism(st, center, top, side_top, Color(0.13, 0.1, 0.07))
	if t == WATER:
		var wc := Hex.to_world(h, -0.05)
		for i in 6:
			var a := wc + Hex.corner(i, 1.0)
			var b := wc + Hex.corner((i + 1) % 6, 1.0)
			_tri(water, wc, a, b, Vector3.UP, Color.WHITE, Color.WHITE, Color.WHITE)
	if is_road(h):
		_build_road(st, h, y)
	_decorate(h, t, e, center)


func _build_border_tile(st: SurfaceTool, h: Vector2i) -> void:
	var o := Hex.axial_to_offset(h)
	var dist_edge: int = maxi(maxi(-o.x, o.x - (COLS - 1)), maxi(-o.y, o.y - (ROWS - 1)))
	var e: int = 0
	if rng.randf() < 0.25:
		e = 1
	var y: float = e * LEVEL_H * 0.8 + rng.randf_range(0.0, 0.04)
	var center := Hex.to_world(h, y)
	var wood: bool = rng.randf() < 0.38
	var c: Color = Color(0.21, 0.26, 0.12) if wood else Color(0.3, 0.38, 0.18)
	c = _jit(c, 0.02).darkened(0.08 * dist_edge)
	_prism(st, center, c, Color(0.3, 0.24, 0.16), Color(0.12, 0.1, 0.07))
	if wood:
		_trees(center, 4, 0.75)
	elif rng.randf() < 0.5:
		_grass(center, 3)


func _build_road(st: SurfaceTool, h: Vector2i, y: float) -> void:
	if is_bridge(h):
		_build_bridge(h)
		return
	var rc := _jit(Color(0.47, 0.39, 0.27), 0.015)
	var ry := y + 0.012
	var c := Hex.to_world(h, ry)
	for i in 6:
		_tri(st, c, c + Hex.corner(i, 0.3), c + Hex.corner((i + 1) % 6, 0.3), Vector3.UP, rc, rc, rc)
	for i in 6:
		var n: Vector2i = h + Hex.DIRS[i]
		if not tiles.has(n) or not is_road(n):
			continue
		var d := Hex.dir_vector(i)
		var perp := Vector3(-d.z, 0, d.x) * 0.21
		var far := c + d * 0.87
		_tri(st, c + perp, c - perp, far - perp, Vector3.UP, rc, rc, rc)
		_tri(st, c + perp, far - perp, far + perp, Vector3.UP, rc, rc, rc)
	# road leaving the battlefield continues into the border
	var o := Hex.axial_to_offset(h)
	if o.y == 0 or o.y == ROWS - 1 or o.x == 0 or o.x == COLS - 1:
		for i in 6:
			var n2: Vector2i = h + Hex.DIRS[i]
			if tiles.has(n2):
				continue
			var opp: Vector2i = h - Hex.DIRS[i]
			if tiles.has(opp) and is_road(opp):
				var d2 := Hex.dir_vector(i)
				var perp2 := Vector3(-d2.z, 0, d2.x) * 0.21
				var far2 := c + d2 * 3.5
				_tri(st, c + perp2, c - perp2, far2 - perp2, Vector3.UP, rc, rc, rc)
				_tri(st, c + perp2, far2 - perp2, far2 + perp2, Vector3.UP, rc, rc, rc)


func _build_bridge(h: Vector2i) -> void:
	var dirs: Array[int] = []
	for i in 6:
		var n: Vector2i = h + Hex.DIRS[i]
		if tiles.has(n) and is_road(n):
			dirs.append(i)
	var d := Hex.dir_vector(dirs[0] if dirs.size() > 0 else 2)
	var node := Node3D.new()
	node.position = Hex.to_world(h, 0.0)
	node.rotation.y = Hex.yaw_for(d)
	add_child(node)
	var stone := Color(0.55, 0.53, 0.48)
	Models.box(node, Vector3(0.6, 0.12, 2.0), Vector3(0, 0.03, 0), stone, Vector3.ZERO, 0.95)
	Models.box(node, Vector3(0.44, 0.01, 2.0), Vector3(0, 0.095, 0), Color(0.45, 0.38, 0.27), Vector3.ZERO, 1.0)
	for s in [-1.0, 1.0]:
		Models.box(node, Vector3(0.06, 0.1, 1.9), Vector3(s * 0.29, 0.14, 0), stone.darkened(0.08), Vector3.ZERO, 0.95)
	Models.box(node, Vector3(0.5, 0.3, 0.25), Vector3(0, -0.15, 0), stone.darkened(0.15), Vector3.ZERO, 0.95)


# ------------------------------------------------------------------ decoration

func _make_meshes() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.022
	trunk.bottom_radius = 0.035
	trunk.height = 0.3
	trunk.radial_segments = 6
	trunk.rings = 1
	_meshes["trunk"] = trunk
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.2
	cone.height = 0.42
	cone.radial_segments = 8
	cone.rings = 1
	_meshes["cone"] = cone
	var blob := SphereMesh.new()
	blob.radius = 0.2
	blob.height = 0.36
	blob.radial_segments = 8
	blob.rings = 5
	_meshes["blob"] = blob
	var tuft := CylinderMesh.new()
	tuft.top_radius = 0.0
	tuft.bottom_radius = 0.03
	tuft.height = 0.09
	tuft.radial_segments = 4
	tuft.rings = 1
	_meshes["tuft"] = tuft
	var rock := SphereMesh.new()
	rock.radius = 0.5
	rock.height = 1.0
	rock.radial_segments = 6
	rock.rings = 3
	_meshes["rock"] = rock
	var bx := BoxMesh.new()
	bx.size = Vector3.ONE
	_meshes["box"] = bx
	var bush := SphereMesh.new()
	bush.radius = 0.12
	bush.height = 0.2
	bush.radial_segments = 7
	bush.rings = 4
	_meshes["bush"] = bush


func _inst(key: String, pos: Vector3, yaw: float, scl: Vector3, col: Color) -> void:
	if not _mm.has(key):
		_mm[key] = {"x": [], "c": []}
	var b := Basis(Vector3.UP, yaw) * Basis.from_scale(scl)
	_mm[key]["x"].append(Transform3D(b, pos))
	_mm[key]["c"].append(col)


func _flush_multimesh() -> void:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 0.9
	for key in _mm:
		var xs: Array = _mm[key]["x"]
		var cs: Array = _mm[key]["c"]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = _meshes[key]
		mm.instance_count = xs.size()
		for i in xs.size():
			mm.set_instance_transform(i, xs[i])
			mm.set_instance_color(i, cs[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = m
		add_child(mmi)


func _rand_in_hex(rad: float) -> Vector3:
	for k in 20:
		var p := Vector3(rng.randf_range(-rad, rad), 0, rng.randf_range(-rad, rad))
		if Vector2(p.x, p.z).length() < rad:
			return p
	return Vector3.ZERO


func _trees(center: Vector3, n: int, rad: float) -> void:
	for i in n:
		var p := center + _rand_in_hex(rad)
		var s: float = rng.randf_range(0.8, 1.3)
		var trunk_c := Color(0.28, 0.2, 0.13)
		_inst("trunk", p + Vector3(0, 0.15 * s, 0), 0.0, Vector3.ONE * s, trunk_c)
		if rng.randf() < 0.5:
			var g := Color(0.13, 0.24, 0.12).lerp(Color(0.2, 0.3, 0.12), rng.randf())
			_inst("cone", p + Vector3(0, 0.4 * s, 0), rng.randf() * TAU, Vector3(1, 1, 1) * s, g)
			_inst("cone", p + Vector3(0, 0.62 * s, 0), rng.randf() * TAU, Vector3(0.7, 0.75, 0.7) * s, g.lightened(0.05))
		else:
			var g2 := Color(0.22, 0.34, 0.12).lerp(Color(0.32, 0.4, 0.14), rng.randf())
			_inst("blob", p + Vector3(0, 0.45 * s, 0), rng.randf() * TAU, Vector3(1.1, 1.0, 1.1) * s, g2)
			_inst("blob", p + Vector3(rng.randf_range(-0.08, 0.08), 0.6 * s, rng.randf_range(-0.08, 0.08)), 0.0, Vector3(0.75, 0.7, 0.75) * s, g2.lightened(0.06))


func _grass(center: Vector3, n: int) -> void:
	for i in n:
		var p := center + _rand_in_hex(0.8)
		_inst("tuft", p + Vector3(0, 0.04, 0), rng.randf() * TAU, Vector3.ONE * rng.randf_range(0.7, 1.4),
			Color(0.3, 0.45, 0.16).lerp(Color(0.45, 0.5, 0.2), rng.randf()))


func _decorate(h: Vector2i, t: int, e: int, center: Vector3) -> void:
	var road: bool = is_road(h)
	match t:
		WOODS:
			_trees(center, rng.randi_range(5, 7), 0.72)
		OPEN:
			if not road:
				_grass(center, 5)
				if rng.randf() < 0.3:
					var bp := center + _rand_in_hex(0.65)
					_inst("bush", bp + Vector3(0, 0.06, 0), 0.0, Vector3.ONE * rng.randf_range(0.8, 1.5), Color(0.2, 0.32, 0.12))
				if rng.randf() < 0.07 and int(tiles[h]["obj"]) < 0:
					_trees(center, 1, 0.5)
			if e >= 2 and not road:
				for i in rng.randi_range(2, 4):
					var rp := center + _rand_in_hex(0.7)
					var rs := Vector3(rng.randf_range(0.1, 0.22), rng.randf_range(0.06, 0.12), rng.randf_range(0.1, 0.2))
					_inst("rock", rp + Vector3(0, rs.y * 0.3, 0), rng.randf() * TAU, rs, Color(0.48, 0.46, 0.42).darkened(rng.randf() * 0.2))
		FIELD:
			var yaw: float = rng.randi_range(0, 2) * PI / 3.0 + PI / 6.0
			var bas := Basis(Vector3.UP, yaw)
			for k in 7:
				var off: float = -0.66 + k * 0.22
				var ln: float = 2.0 * sqrt(maxf(0.0, 0.78 * 0.78 - off * off))
				if ln < 0.1:
					continue
				var p := center + bas * Vector3(off, 0.035, 0)
				_inst("box", p, yaw, Vector3(0.13, 0.07, ln), Color(0.78, 0.66, 0.32).lerp(Color(0.7, 0.6, 0.3), rng.randf()))
		BUILDING:
			_buildings(h, center)


func _buildings(h: Vector2i, center: Vector3) -> void:
	# Buildings sit on one side of the hex so the occupying unit stays visible.
	var off := Hex.corner(rng.randi_range(0, 5), 0.36)
	tiles[h]["bofs"] = off
	var c := center + off
	var face: float = Hex.yaw_for(off)
	if bool(tiles[h]["church"]):
		var n := Node3D.new()
		n.position = c
		n.rotation.y = face
		add_child(n)
		var stone := Color(0.66, 0.62, 0.54)
		Models.box(n, Vector3(0.66, 0.46, 0.4), Vector3(0.1, 0.23, 0), stone, Vector3.ZERO, 0.95)
		_roof(n, Vector3(0.1, 0.46, 0), 0.72, 0.48, 0.24, Color(0.3, 0.31, 0.34), true)
		Models.box(n, Vector3(0.26, 0.95, 0.26), Vector3(-0.32, 0.475, 0), stone.darkened(0.05), Vector3.ZERO, 0.95)
		var sp := Models.cyl(n, 0.0, 0.2, 0.5, Vector3(-0.32, 1.2, 0), Color(0.3, 0.31, 0.34), Vector3.ZERO, 4)
		sp.rotation = Vector3(0, PI * 0.25, 0)
		for k in 2:
			Models.box(n, Vector3(0.07, 0.18, 0.01), Vector3(0.0 + k * 0.24, 0.25, 0.205), Color(0.15, 0.17, 0.22))
		Models.box(n, Vector3(0.08, 0.13, 0.01), Vector3(-0.32, 0.78, 0.132), Color(0.1, 0.1, 0.1))
		return
	var walls := [Color(0.78, 0.72, 0.6), Color(0.7, 0.66, 0.58), Color(0.6, 0.55, 0.46), Color(0.74, 0.7, 0.64)]
	var roofs := [Color(0.52, 0.24, 0.17), Color(0.3, 0.3, 0.33), Color(0.45, 0.3, 0.2)]
	var w: float = rng.randf_range(0.52, 0.66)
	var d: float = rng.randf_range(0.36, 0.44)
	var hgt: float = rng.randf_range(0.32, 0.44)
	_house(c, face, w, d, hgt, walls[rng.randi() % walls.size()], roofs[rng.randi() % roofs.size()])


func _roof(n: Node3D, base: Vector3, length: float, depth: float, height: float, col: Color, ridge_x: bool) -> void:
	var pm := PrismMesh.new()
	pm.size = Vector3(depth, height, length)
	var mi := Models.add_mesh(n, pm, base + Vector3(0, height * 0.5, 0), Models.mat(col, 0.85))
	if ridge_x:
		mi.rotation.y = PI * 0.5


func _house(pos: Vector3, yaw: float, w: float, d: float, hgt: float, wall: Color, roof: Color) -> void:
	var n := Node3D.new()
	n.position = pos
	n.rotation.y = yaw
	add_child(n)
	Models.box(n, Vector3(w, hgt, d), Vector3(0, hgt * 0.5, 0), wall, Vector3.ZERO, 0.95)
	_roof(n, Vector3(0, hgt, 0), w + 0.1, d + 0.1, 0.26, roof, true)
	Models.box(n, Vector3(0.07, 0.22, 0.07), Vector3(w * 0.3, hgt + 0.18, d * 0.15), wall.darkened(0.2))
	var win := Color(0.12, 0.13, 0.16)
	if w > 0.4:
		for s in [-1.0, 1.0]:
			for k in [-1.0, 1.0]:
				Models.box(n, Vector3(0.09, 0.1, 0.012), Vector3(k * w * 0.27, hgt * 0.62, s * (d * 0.5 + 0.004)), win)
				Models.box(n, Vector3(0.025, 0.1, 0.014), Vector3(k * w * 0.27 + 0.055, hgt * 0.62, s * (d * 0.5 + 0.005)), Color(0.25, 0.32, 0.22))
		Models.box(n, Vector3(0.1, 0.18, 0.012), Vector3(0, 0.09, d * 0.5 + 0.004), Color(0.3, 0.2, 0.12))


# ------------------------------------------------------------------ overlays

func _hex_fill_mesh(r: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		_tri(st, Vector3.ZERO, Hex.corner(i, r), Hex.corner((i + 1) % 6, r), Vector3.UP, Color.WHITE, Color.WHITE, Color.WHITE)
	return st.commit()


func _hex_ring_mesh(r0: float, r1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 6:
		var a0 := Hex.corner(i, r0)
		var a1 := Hex.corner((i + 1) % 6, r0)
		var b0 := Hex.corner(i, r1)
		var b1 := Hex.corner((i + 1) % 6, r1)
		_tri(st, a0, b0, b1, Vector3.UP, Color.WHITE, Color.WHITE, Color.WHITE)
		_tri(st, a0, b1, a1, Vector3.UP, Color.WHITE, Color.WHITE, Color.WHITE)
	return st.commit()


func _ov_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.render_priority = 1
	return m


func _build_overlays() -> void:
	_fill_mesh = _hex_fill_mesh(0.88)
	_ring_mesh = _hex_ring_mesh(0.76, 0.92)
	_ov_mats["move"] = _ov_mat(Color(0.6, 0.85, 1.0, 0.17))
	_ov_mats["path"] = _ov_mat(Color(0.55, 0.9, 1.0, 0.55))
	_ov_mats["target"] = _ov_mat(Color(1.0, 0.25, 0.18, 0.85))
	_ov_mats["blocked"] = _ov_mat(Color(1.0, 0.6, 0.2, 0.45))
	_ov_mats["selected"] = _ov_mat(Color(1.0, 0.85, 0.3, 0.95))
	_ov_mats["hover"] = _ov_mat(Color(1.0, 1.0, 1.0, 0.55))
	_ov_mats["objective"] = _ov_mat(Color(0.95, 0.75, 0.25, 0.6))
	_hover = MeshInstance3D.new()
	_hover.mesh = _hex_ring_mesh(0.86, 0.96)
	_hover.material_override = _ov_mats["hover"]
	_hover.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hover.visible = false
	add_child(_hover)


func _ov_inst(h: Vector2i) -> MeshInstance3D:
	if _overlay.has(h):
		return _overlay[h]
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = Hex.to_world(h, top_y(h) + 0.03)
	add_child(mi)
	_overlay[h] = mi
	return mi


func _set_ov(h: Vector2i, kind: String) -> void:
	if not tiles.has(h):
		return
	var mi := _ov_inst(h)
	mi.mesh = _ring_mesh if kind in ["target", "selected"] else _fill_mesh
	mi.material_override = _ov_mats[kind]
	mi.visible = true


func show_overlays(move_hexes: Array, path: Array, targets: Array, sel: Vector2i) -> void:
	for k in _overlay:
		_overlay[k].visible = false
	for h in move_hexes:
		_set_ov(h, "move")
	for h in path:
		_set_ov(h, "path")
	for h in targets:
		_set_ov(h, "target")
	if tiles.has(sel):
		_set_ov(sel, "selected")


func set_hover(h: Vector2i) -> void:
	if not tiles.has(h):
		_hover.visible = false
		return
	_hover.visible = true
	_hover.position = Hex.to_world(h, top_y(h) + 0.035)


func _build_objective_markers() -> void:
	for i in objectives.size():
		var o: Dictionary = objectives[i]
		var h: Vector2i = o["hex"]
		var ring := MeshInstance3D.new()
		ring.mesh = _hex_ring_mesh(0.9, 0.975)
		ring.material_override = _ov_mats["objective"]
		ring.position = Hex.to_world(h, top_y(h) + 0.02)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		var pole_base := Hex.to_world(h, top_y(h)) + Hex.corner(0, 0.62)
		Models.cyl(self, 0.012, 0.015, 1.25, pole_base + Vector3(0, 0.625, 0), Color(0.3, 0.25, 0.18), Vector3.ZERO, 6)
		var flag := MeshInstance3D.new()
		var fb := BoxMesh.new()
		fb.size = Vector3(0.36, 0.22, 0.012)
		flag.mesh = fb
		flag.position = pole_base + Vector3(-0.19, 1.12, 0)
		add_child(flag)
		var lbl := Label3D.new()
		lbl.text = String(o["name"])
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lbl.font_size = 44
		lbl.pixel_size = 0.0045
		lbl.outline_size = 12
		lbl.modulate = Color(1.0, 0.86, 0.45)
		lbl.position = pole_base + Vector3(0, 1.5, 0)
		lbl.no_depth_test = true
		add_child(lbl)
		_flags.append(flag)
		set_objective_owner(i, String(o["owner"]))


func set_objective_owner(i: int, side: String) -> void:
	objectives[i]["owner"] = side
	if i < _flags.size():
		var c: Color = Color(0.22, 0.42, 0.85) if side == "US" else Color(0.72, 0.13, 0.1)
		_flags[i].material_override = Models.mat(c, 0.8, 0.0, 0.25)
