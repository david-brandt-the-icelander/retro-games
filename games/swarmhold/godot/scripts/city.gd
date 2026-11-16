extends Node3D
## The walled city: a grid of stacked stone blocks, generated per level.
## Also provides grid queries and path fields for the ants and the hostage.

const Meshes = preload("res://scripts/meshes.gd")

const N := 56          # grid size (cells), includes desert around the walls
const W0 := 8          # wall ring, inclusive
const W1 := 47
const CELL := 2.0      # metres per cell
const BH := 1.0        # block height
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var heights := PackedInt32Array()
var rng := RandomNumberGenerator.new()
var start_cell := Vector2i()
var hostage_cell := Vector2i()
var nest_cells: Array[Vector2i] = []
var exit_points: Array[Vector3] = []
var _level_root: Node3D


func idx(c: Vector2i) -> int:
	return c.y * N + c.x


func inside_grid(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < N and c.y < N


func h_at(c: Vector2i) -> int:
	return heights[idx(c)] if inside_grid(c) else 0


func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / CELL + N * 0.5), floori(p.z / CELL + N * 0.5))


func cell_center(c: Vector2i) -> Vector3:
	return Vector3((c.x - N * 0.5 + 0.5) * CELL, h_at(c) * BH, (c.y - N * 0.5 + 0.5) * CELL)


func inside_walls(c: Vector2i) -> bool:
	return c.x > W0 and c.x < W1 and c.y > W0 and c.y < W1


func is_outside(p: Vector3) -> bool:
	var c := cell_of(p)
	return c.x < W0 or c.x > W1 or c.y < W0 or c.y > W1


func surface_y(p: Vector3) -> float:
	return h_at(cell_of(p)) * BH


# ---------------------------------------------------------------- generation

func generate(seed_val: int, level: int) -> void:
	rng.seed = seed_val
	heights.resize(N * N)
	heights.fill(0)
	var mid := (W0 + W1) / 2

	# Outer wall with four gates.
	for i in range(W0, W1 + 1):
		for c in [Vector2i(i, W0), Vector2i(i, W1), Vector2i(W0, i), Vector2i(W1, i)]:
			heights[idx(c)] = 3
	var reserve := {}
	for g in [[Vector2i(mid, W0), Vector2i(0, 1)], [Vector2i(mid, W1), Vector2i(0, -1)],
			[Vector2i(W0, mid), Vector2i(1, 0)], [Vector2i(W1, mid), Vector2i(-1, 0)]]:
		var side: Vector2i = Vector2i(absi(g[1].y), absi(g[1].x))
		for k in 4:
			for w in 2:
				var c: Vector2i = g[0] + g[1] * k + side * w
				heights[idx(c)] = 0
				reserve[c] = true
		var out: Vector2i = g[0] - g[1] * 3
		exit_points.append(cell_center(out) + Vector3(side.x, 0, side.y) * CELL * 0.5)

	# Wall towers at the corners and beside the gates.
	for c in [Vector2i(W0, W0), Vector2i(W1, W0), Vector2i(W0, W1), Vector2i(W1, W1)]:
		heights[idx(c)] = 5
	for c in [Vector2i(mid - 1, W0), Vector2i(mid + 2, W0), Vector2i(mid - 1, W1), Vector2i(mid + 2, W1),
			Vector2i(W0, mid - 1), Vector2i(W0, mid + 2), Vector2i(W1, mid - 1), Vector2i(W1, mid + 2)]:
		heights[idx(c)] = 4

	# Buildings, pyramids and staircases inside the walls.
	var count := 46 + level * 4
	for k in count:
		var pyramid := rng.randf() < 0.25
		var w := rng.randi_range(3, 6) if pyramid else rng.randi_range(1, 4)
		var d := w if pyramid else rng.randi_range(1, 4)
		var x := rng.randi_range(W0 + 2, W1 - 1 - w)
		var z := rng.randi_range(W0 + 2, W1 - 1 - d)
		var h := rng.randi_range(1, 3 + mini(level, 3))
		for i in w:
			for j in d:
				var c := Vector2i(x + i, z + j)
				if reserve.has(c):
					continue
				var hh := h
				if pyramid:
					hh = 1 + mini(mini(i, w - 1 - i), mini(j, d - 1 - j))
				heights[idx(c)] = maxi(heights[idx(c)], hh)
	for k in 12:
		var c := Vector2i(rng.randi_range(W0 + 3, W1 - 3), rng.randi_range(W0 + 3, W1 - 3))
		var dir: Vector2i = DIRS[rng.randi() % 4]
		for s in rng.randi_range(3, 5):
			var cc := c + dir * s
			if inside_walls(cc) and not reserve.has(cc):
				heights[idx(cc)] = s + 1

	# Rubble steps on the outside of the wall, so it can be climbed over.
	for k in 6:
		var t := rng.randi_range(W0 + 3, W1 - 3)
		if absi(t - mid) < 4:
			continue
		var side := rng.randi() % 4
		var wall_c: Vector2i = [Vector2i(t, W0), Vector2i(t, W1), Vector2i(W0, t), Vector2i(W1, t)][side]
		var outward: Vector2i = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)][side]
		heights[idx(wall_c + outward)] = 2
		heights[idx(wall_c + outward * 2)] = 1
		heights[idx(wall_c - outward)] = maxi(heights[idx(wall_c - outward)], 2)

	start_cell = Vector2i(mid, W1 + 4)

	# Hostage: far from the start, ideally up high, and able to get back out.
	var fwd := reach_from(start_cell)
	var back := flow_to(start_cell)
	var best := -1.0
	for z in range(W0 + 1, W1):
		for x in range(W0 + 1, W1):
			var c := Vector2i(x, z)
			var i := idx(c)
			if fwd[i] < 0 or back[i] < 0:
				continue
			var score := fwd[i] + 4.0 * h_at(c) + rng.randf() * 8.0
			if score > best:
				best = score
				hostage_cell = c

	# Ant nests: ground cells deep inside, away from the hostage.
	nest_cells.clear()
	var tries := 0
	while nest_cells.size() < 3 and tries < 2000:
		tries += 1
		var c := Vector2i(rng.randi_range(W0 + 2, W1 - 2), rng.randi_range(W0 + 2, W1 - 6))
		if h_at(c) != 0 or back[idx(c)] < 0 or fwd[idx(c)] < 10:
			continue
		if (c - hostage_cell).length() < 7:
			continue
		var ok := true
		for o in nest_cells:
			if (c - o).length() < 9:
				ok = false
		if ok:
			nest_cells.append(c)


## Distance field from `from`, moving with a climb limit of one block.
func reach_from(from: Vector2i, climb := 1) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(N * N)
	dist.fill(-1)
	var q: Array[Vector2i] = [from]
	dist[idx(from)] = 0
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if not inside_grid(n) or dist[idx(n)] >= 0:
				continue
			if h_at(n) - h_at(c) > climb:
				continue
			dist[idx(n)] = dist[idx(c)] + 1
			q.append(n)
	return dist


## Distance field *towards* `target`: steps needed for a walker that can climb
## one block to get from each cell to the target. Used by the ants.
func flow_to(target: Vector2i, climb := 1) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(N * N)
	dist.fill(-1)
	if not inside_grid(target):
		return dist
	var q: Array[Vector2i] = [target]
	dist[idx(target)] = 0
	var head := 0
	while head < q.size():
		var c := q[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = c + d
			if not inside_grid(n) or dist[idx(n)] >= 0:
				continue
			if h_at(c) - h_at(n) > climb:
				continue
			dist[idx(n)] = dist[idx(c)] + 1
			q.append(n)
	return dist


# ------------------------------------------------------------------- visuals

func build() -> void:
	if _level_root:
		_level_root.queue_free()
	_level_root = Node3D.new()
	add_child(_level_root)

	var block := Meshes.rounded_box(Vector3(CELL - 0.04, BH - 0.03, CELL - 0.04), 0.09)
	var total := 0
	for v in heights:
		total += v
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = block
	mm.instance_count = total
	var k := 0
	for z in N:
		for x in N:
			var c := Vector2i(x, z)
			var h := heights[idx(c)]
			var wall := not inside_walls(c) and x >= W0 and x <= W1 and z >= W0 and z <= W1
			for y in h:
				var pos := Vector3((x - N * 0.5 + 0.5) * CELL, y * BH + BH * 0.5, (z - N * 0.5 + 0.5) * CELL)
				var jitter := Vector3(rng.randf_range(-0.02, 0.02), 0, rng.randf_range(-0.02, 0.02))
				mm.set_instance_transform(k, Transform3D(Basis(), pos + jitter))
				# Baked occlusion: lower courses are darker, as if shaded by their neighbours.
				var t := rng.randf_range(0.88, 1.06) * (0.8 + 0.2 * minf(y, 3.0) / 3.0) * (1.0 + 0.02 * y)
				var col := Color(t, t * 0.97, t * 0.93)
				if wall:
					col = Color(t * 0.96, t * 0.86, t * 0.78)
				mm.set_instance_color(k, col)
				k += 1
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Meshes.sandstone_material()
	_level_root.add_child(mmi)

	var body := StaticBody3D.new()
	body.collision_layer = 1
	_level_root.add_child(body)
	for z in N:
		for x in N:
			var h := heights[z * N + x]
			if h == 0:
				continue
			var cs := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(CELL, h * BH, CELL)
			cs.shape = box
			cs.position = Vector3((x - N * 0.5 + 0.5) * CELL, h * BH * 0.5, (z - N * 0.5 + 0.5) * CELL)
			body.add_child(cs)

	_build_ground_ao()
	_build_nests()


## Ambient occlusion on the sand around buildings, baked into a texture and
## multiplied over the ground. Stands in for SSAO, which WebGL builds lack.
func _build_ground_ao() -> void:
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for z in N:
		for x in N:
			var v := minf(heights[z * N + x], 3.0) / 3.0
			v = 0.0 if heights[z * N + x] == 0 else 0.55 + 0.45 * v
			img.set_pixel(x, z, Color(v, v, v))
	img.resize(N * 8, N * 8, Image.INTERPOLATE_NEAREST)
	img.resize(N * 2, N * 2, Image.INTERPOLATE_LANCZOS)
	img.resize(N, N, Image.INTERPOLATE_BILINEAR)
	img.resize(N * 8, N * 8, Image.INTERPOLATE_CUBIC)
	var src := img.get_data()
	var data := PackedByteArray()
	data.resize(src.size() / 3 * 4)
	for i in src.size() / 3:
		data[i * 4] = 18
		data[i * 4 + 1] = 10
		data[i * 4 + 2] = 4
		data[i * 4 + 3] = int(255.0 * 0.5 * pow(src[i * 3] / 255.0, 0.8))
	img = Image.create_from_data(N * 8, N * 8, false, Image.FORMAT_RGBA8, data)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var plane := PlaneMesh.new()
	plane.size = Vector2(N * CELL, N * CELL)
	var mi := MeshInstance3D.new()
	mi.mesh = plane
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 0.012
	_level_root.add_child(mi)


func _build_nests() -> void:
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color(0.36, 0.25, 0.17)
	soil.roughness = 1.0
	soil.normal_enabled = true
	soil.normal_texture = Meshes.noise_texture(31, 0.08, null, true, 8.0, 256)
	soil.uv1_triplanar = true
	var hole := StandardMaterial3D.new()
	hole.albedo_color = Color(0.02, 0.015, 0.01)
	hole.roughness = 1.0
	for c in nest_cells:
		var p := cell_center(c)
		Meshes.mesh_instance(Meshes.sphere(1.0, 32), soil, _level_root, p + Vector3(0, -0.15, 0),
				Vector3.ZERO, Vector3(1.25, 0.5, 1.25))
		Meshes.mesh_instance(Meshes.cylinder(0.42, 0.42, 0.04, 20), hole, _level_root, p + Vector3(0, 0.33, 0),
				Vector3(0.12, 0, 0))
		for i in 7:
			var a := rng.randf() * TAU
			var r := rng.randf_range(1.3, 1.9)
			Meshes.mesh_instance(Meshes.sphere(rng.randf_range(0.12, 0.25), 10), soil, _level_root,
					p + Vector3(cos(a) * r, 0.02, sin(a) * r), Vector3.ZERO, Vector3(1, 0.6, 1))


## Desert floor and distant scenery. Built once.
func build_terrain() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(600, 600)
	ground.mesh = plane
	ground.material_override = Meshes.sand_material()
	add_child(ground)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 2, 600)
	cs.shape = box
	cs.position.y = -1.0
	body.add_child(cs)
	add_child(body)

	# Dunes and rocks beyond the play area.
	var r2 := RandomNumberGenerator.new()
	r2.seed = 7
	var rock := StandardMaterial3D.new()
	rock.albedo_color = Color(0.55, 0.40, 0.29)
	rock.roughness = 0.95
	rock.normal_enabled = true
	rock.normal_texture = Meshes.noise_texture(41, 0.05, null, true, 10.0, 256)
	rock.uv1_triplanar = true
	for i in 46:
		var a := r2.randf() * TAU
		var s := r2.randf_range(10, 30)
		var d := r2.randf_range(70, 160) + s * 2.4
		Meshes.mesh_instance(Meshes.sphere(1.0, 48), Meshes.sand_material(), self,
				Vector3(cos(a) * d, -s * 0.9, sin(a) * d), Vector3(0, r2.randf() * TAU, 0),
				Vector3(s * r2.randf_range(1.4, 2.4), s, s * 1.2))
	for i in 60:
		var a := r2.randf() * TAU
		var d := r2.randf_range(62, 140)
		var s := r2.randf_range(0.4, 2.6)
		Meshes.mesh_instance(Meshes.sphere(1.0, 10), rock, self,
				Vector3(cos(a) * d, s * 0.2, sin(a) * d), Vector3(r2.randf(), r2.randf() * TAU, r2.randf()),
				Vector3(s * r2.randf_range(0.8, 1.6), s * r2.randf_range(0.5, 1.0), s))
	# A few mesas on the horizon.
	for i in 7:
		var a := r2.randf() * TAU
		var d := r2.randf_range(190, 260)
		var s := r2.randf_range(14, 30)
		Meshes.mesh_instance(Meshes.cylinder(s * 0.8, s, r2.randf_range(14, 34), 9), rock, self,
				Vector3(cos(a) * d, 4, sin(a) * d), Vector3(0, r2.randf(), 0))
