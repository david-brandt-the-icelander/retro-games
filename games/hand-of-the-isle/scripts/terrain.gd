class_name Terrain
extends Node3D
## Integer heightmap on an N x N tile grid. Adjacent vertices never differ by
## more than one step, so raising one corner drags its neighbours up with it.

const N := 48
const HSTEP := 0.5
const MAX_H := 14
const BASE_Y := -1.6
const BLIGHT_SWAMP := 1
const BLIGHT_ROCK := 2

var h := PackedInt32Array()
var water_level := 1
var blight := {}            # Vector2i tile -> BLIGHT_*
var influence := PackedByteArray()  # per tile, bit 1 = team 0, bit 2 = team 1
var dirty := true
var reveal_all := false

var _mesh := MeshInstance3D.new()
var _trees := MultiMeshInstance3D.new()
var _water := MeshInstance3D.new()
var _water_mat := StandardMaterial3D.new()
var _time := 0.0
var _water_y := 1.0
var _inf_img: Image
var _inf_tex: ImageTexture


func _ready() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/terrain.gdshader")
	_inf_img = Image.create(N, N, false, Image.FORMAT_L8)
	_inf_img.fill(Color.BLACK)
	_inf_tex = ImageTexture.create_from_image(_inf_img)
	mat.set_shader_parameter("influence_tex", _inf_tex)
	mat.set_shader_parameter("board_size", float(N))
	_mesh.material_override = mat
	add_child(_mesh)

	var tree := CylinderMesh.new()
	tree.top_radius = 0.0
	tree.bottom_radius = 0.28
	tree.height = 0.85
	tree.radial_segments = 6
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.16, 0.36, 0.2)
	tmat.roughness = 0.8
	tmat.vertex_color_use_as_albedo = true
	tree.material = tmat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = tree
	_trees.multimesh = mm
	add_child(_trees)

	var wbox := BoxMesh.new()
	wbox.size = Vector3(N, 1, N)
	_water.mesh = wbox
	_water_mat.albedo_color = Color(0.06, 0.32, 0.58, 0.82)
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.metallic = 0.25
	_water_mat.roughness = 0.08
	_water_mat.emission_enabled = true
	_water_mat.emission = Color(0.02, 0.12, 0.2)
	_water.material_override = _water_mat
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


func _process(delta: float) -> void:
	_time += delta
	if dirty:
		rebuild()
	_water_y = lerpf(_water_y, float(water_level), minf(1.0, delta * 1.5))
	var top := _water_y * HSTEP + 0.14 + sin(_time * 1.3) * 0.03
	_water.scale = Vector3(1, top - BASE_Y, 1)
	_water.position = Vector3(N * 0.5, (top + BASE_Y) * 0.5, N * 0.5)


# ---------------------------------------------------------------- generation
func generate(seed_value: int) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.05
	noise.fractal_octaves = 4
	h.resize((N + 1) * (N + 1))
	var c := N * 0.5
	for z in N + 1:
		for x in N + 1:
			var d := Vector2(x - c, (z - c) * 1.25).length() / c
			var v := noise.get_noise_2d(x, z) * 0.5 + 0.5
			var fall := clampf(1.15 - pow(d, 2.4), 0.0, 1.0)
			h[idx(x, z)] = clampi(int(round(v * 10.0 * fall + fall * 1.2)), 0, MAX_H)
	_relax()
	blight.clear()
	influence.resize(N * N)
	influence.fill(0)
	water_level = 1
	_water_y = 1.0
	dirty = true


func _relax() -> void:
	var changed := true
	while changed:
		changed = false
		for z in N + 1:
			for x in N + 1:
				var hv := h[idx(x, z)]
				for o in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]:
					var qx: int = x + o.x
					var qz: int = z + o.y
					if qx > N or qz < 0 or qz > N:
						continue
					var hq := h[idx(qx, qz)]
					if hq > hv + 1:
						h[idx(qx, qz)] = hv + 1
						changed = true
					elif hv > hq + 1:
						h[idx(x, z)] = hq + 1
						hv = hq + 1
						changed = true


func set_influence(inf: PackedByteArray) -> void:
	influence = inf
	for z in N:
		for x in N:
			_inf_img.set_pixel(x, z, Color.WHITE if reveal_all or inf[z * N + x] & 1 else Color.BLACK)
	_inf_tex.update(_inf_img)


# ------------------------------------------------------------------- queries
func idx(x: int, z: int) -> int:
	return z * (N + 1) + x


func vh(x: int, z: int) -> int:
	return h[idx(clampi(x, 0, N), clampi(z, 0, N))]


func in_tiles(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < N and t.y < N


func tile_min(t: Vector2i) -> int:
	return mini(mini(vh(t.x, t.y), vh(t.x + 1, t.y)), mini(vh(t.x, t.y + 1), vh(t.x + 1, t.y + 1)))


func tile_max(t: Vector2i) -> int:
	return maxi(maxi(vh(t.x, t.y), vh(t.x + 1, t.y)), maxi(vh(t.x, t.y + 1), vh(t.x + 1, t.y + 1)))


func tile_flat(t: Vector2i) -> bool:
	return tile_min(t) == tile_max(t)


func tile_water(t: Vector2i) -> bool:
	return not in_tiles(t) or tile_max(t) <= water_level


func tile_buildable(t: Vector2i) -> bool:
	return in_tiles(t) and tile_flat(t) and not tile_water(t) and not blight.has(t)


func has_influence(t: Vector2i, team: int) -> bool:
	return in_tiles(t) and (influence[t.y * N + t.x] & (1 << team)) != 0


## World-space ground height, matching the mesh triangulation exactly.
func height_at(p: Vector2) -> float:
	var x := clampf(p.x, 0.0, N - 0.001)
	var z := clampf(p.y, 0.0, N - 0.001)
	var ix := int(x)
	var iz := int(z)
	var fx := x - ix
	var fz := z - iz
	var a := float(vh(ix, iz))
	var b := float(vh(ix + 1, iz))
	var c := float(vh(ix, iz + 1))
	var d := float(vh(ix + 1, iz + 1))
	var y: float
	if fx >= fz:
		y = a + (b - a) * fx + (d - b) * fz
	else:
		y = a + (c - a) * fz + (d - c) * fx
	return y * HSTEP


func world_pos(p: Vector2) -> Vector3:
	return Vector3(p.x, height_at(p), p.y)


## Ray-march the heightfield. Returns null when the ray misses the board.
func raycast(from: Vector3, dir: Vector3) -> Variant:
	var t := 0.0
	var prev := from
	while t < 260.0:
		t += 0.35
		var p := from + dir * t
		var inside := p.x >= 0 and p.z >= 0 and p.x <= N and p.z <= N
		if inside and p.y <= height_at(Vector2(p.x, p.z)):
			var lo := prev
			var hi := p
			for i in 12:
				var mid := (lo + hi) * 0.5
				if mid.y <= height_at(Vector2(mid.x, mid.z)):
					hi = mid
				else:
					lo = mid
			return hi
		if p.y < BASE_Y - 2.0:
			return null
		prev = p
	return null


# ----------------------------------------------------------------- sculpting
func raise_vertex(x: int, z: int) -> bool:
	return _shift(x, z, 1)


func lower_vertex(x: int, z: int) -> bool:
	return _shift(x, z, -1)


func _shift(x: int, z: int, s: int) -> bool:
	if x < 0 or z < 0 or x > N or z > N:
		return false
	var nh := h[idx(x, z)] + s
	if nh < 0 or nh > MAX_H:
		return false
	h[idx(x, z)] = nh
	var stack: Array[Vector2i] = [Vector2i(x, z)]
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		var hp := h[idx(p.x, p.y)]
		_clear_blight_around(p)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var qx := p.x + dx
				var qz := p.y + dz
				if (dx == 0 and dz == 0) or qx < 0 or qz < 0 or qx > N or qz > N:
					continue
				var hq := h[idx(qx, qz)]
				if s > 0 and hq < hp - 1:
					h[idx(qx, qz)] = hp - 1
					stack.append(Vector2i(qx, qz))
				elif s < 0 and hq > hp + 1:
					h[idx(qx, qz)] = hp + 1
					stack.append(Vector2i(qx, qz))
	dirty = true
	return true


func _clear_blight_around(v: Vector2i) -> void:
	for t in [v, v - Vector2i(1, 0), v - Vector2i(0, 1), v - Vector2i(1, 1)]:
		blight.erase(t)


## Move every corner of a tile one step toward `target`. Returns steps spent.
func flatten_tile_step(t: Vector2i, target: int) -> int:
	var spent := 0
	for c in [t, t + Vector2i(1, 0), t + Vector2i(0, 1), t + Vector2i(1, 1)]:
		var hv := vh(c.x, c.y)
		if hv < target and raise_vertex(c.x, c.y):
			spent += 1
		elif hv > target and lower_vertex(c.x, c.y):
			spent += 1
	return spent


# ------------------------------------------------------------------ meshing
func _tile_color(t: Vector2i) -> Color:
	var mn := tile_min(t)
	var mx := tile_max(t)
	var rel := (mn + mx) * 0.5 - water_level
	var col: Color
	if mx <= water_level:
		col = Color(0.3, 0.36, 0.4)
	elif mn <= water_level:
		col = Color(0.86, 0.79, 0.55)
	elif rel < 3.5:
		col = Color(0.42, 0.66, 0.31)
	elif rel < 6.0:
		col = Color(0.32, 0.53, 0.26)
	elif rel < 8.5:
		col = Color(0.5, 0.47, 0.42)
	else:
		col = Color(0.93, 0.94, 0.97)
	if mn != mx:
		col = col.darkened(0.16)
	var b: int = blight.get(t, 0)
	if b == BLIGHT_SWAMP:
		col = Color(0.24, 0.27, 0.13)
	elif b == BLIGHT_ROCK:
		col = Color(0.3, 0.27, 0.27)
	var hsh := float(((t.x * 73856093) ^ (t.y * 19349663)) & 1023) / 1023.0
	col = col.lightened((hsh - 0.5) * 0.06) if hsh > 0.5 else col.darkened((0.5 - hsh) * 0.06)
	return col


func rebuild() -> void:
	dirty = false
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in N:
		for x in N:
			var t := Vector2i(x, z)
			var col := _tile_color(t)
			var a := Vector3(x, vh(x, z) * HSTEP, z)
			var b := Vector3(x + 1, vh(x + 1, z) * HSTEP, z)
			var c := Vector3(x, vh(x, z + 1) * HSTEP, z + 1)
			var d := Vector3(x + 1, vh(x + 1, z + 1) * HSTEP, z + 1)
			st.set_color(col)
			for v in [a, b, d, a, d, c]:
				st.add_vertex(v)
	var soil := Color(0.36, 0.25, 0.17)
	for i in N:
		_skirt(st, Vector3(i, vh(i, 0) * HSTEP, 0), Vector3(i + 1, vh(i + 1, 0) * HSTEP, 0), soil)
		_skirt(st, Vector3(N, vh(N, i) * HSTEP, i), Vector3(N, vh(N, i + 1) * HSTEP, i + 1), soil)
		_skirt(st, Vector3(i + 1, vh(i + 1, N) * HSTEP, N), Vector3(i, vh(i, N) * HSTEP, N), soil)
		_skirt(st, Vector3(0, vh(0, i + 1) * HSTEP, i + 1), Vector3(0, vh(0, i) * HSTEP, i), soil)
	st.generate_normals()
	_mesh.mesh = st.commit()
	_rebuild_trees()


func _skirt(st: SurfaceTool, p: Vector3, q: Vector3, col: Color) -> void:
	var pb := Vector3(p.x, BASE_Y, p.z)
	var qb := Vector3(q.x, BASE_Y, q.z)
	st.set_color(col)
	for v in [p, pb, q, q, pb, qb]:
		st.add_vertex(v)


func _rebuild_trees() -> void:
	var xf: Array[Transform3D] = []
	var cols: Array[Color] = []
	for z in N:
		for x in N:
			var t := Vector2i(x, z)
			if tile_flat(t) or tile_water(t) or blight.has(t) or tile_min(t) <= water_level:
				continue
			var rel := tile_max(t) - water_level
			if rel > 8:
				continue
			var hs := (x * 92821 + z * 68917) % 100
			if hs > 38:
				continue
			var p := Vector2(x + 0.3 + (hs % 5) * 0.1, z + 0.3 + (hs % 7) * 0.06)
			var s := 0.75 + (hs % 9) * 0.07
			var basis := Basis().scaled(Vector3(s, s, s))
			xf.append(Transform3D(basis, world_pos(p) + Vector3(0, 0.38 * s, 0)))
			cols.append(Color(1, 1, 1).darkened((hs % 4) * 0.08))
	var mm := _trees.multimesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i])
