class_name WorldView
extends Node3D
## Renders the game world for the local player: terrain, water, decorations,
## borders, fog of war, units, cities and selection overlays.

const WALL_BOTTOM := -0.9

var game: Game
var pid := 0
var reveal_all := false

var terrain_mat: ShaderMaterial
var water_mat: ShaderMaterial
var decor_mats: Array = []
var fog_img: Image
var fog_tex: ImageTexture
var explored := PackedByteArray()
var visible_now := PackedByteArray()

var h_center := PackedFloat32Array()
var h_edge := PackedFloat32Array()

var unit_views := {}   ## id -> Node3D
var unit_state := {}   ## id -> {pos, owner, type}
var city_views := {}   ## id -> Node3D
var city_sig := {}

var improvements_root: Node3D
var _improvement_sig := ""
var border_mi: MeshInstance3D
var overlay: Node3D
var hover_mi: MeshInstance3D
var select_mi: MeshInstance3D
var reach_mmi: MultiMeshInstance3D
var target_root: Node3D
var path_root: Node3D
var fx_root: Node3D

var _fill_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _time := 0.0

# ================================================================ setup

func setup(g: Game, local_pid: int) -> void:
	game = g
	pid = local_pid
	explored.resize(g.w * g.h)
	visible_now.resize(g.w * g.h)
	fog_img = Image.create(g.w, g.h, false, Image.FORMAT_RGBA8)
	fog_img.fill(Color(0, 0, 0, 1))
	fog_tex = ImageTexture.create_from_image(fog_img)
	_compute_heights()
	_make_materials()
	_build_terrain()
	_build_water()
	_build_decor()
	improvements_root = Node3D.new()
	add_child(improvements_root)
	border_mi = MeshInstance3D.new()
	border_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(border_mi)
	fx_root = Node3D.new()
	add_child(fx_root)
	_build_overlays()
	game.event_applied.connect(_on_event)
	refresh_all()

func _make_materials() -> void:
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = load("res://shaders/terrain.gdshader")
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://shaders/water.gdshader")
	for m in [terrain_mat, water_mat]:
		m.set_shader_parameter("fog_tex", fog_tex)
		m.set_shader_parameter("map_size", Vector2(game.w, game.h))

func _decor_mat(emission := 0.0, sway := 0.0, bob := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/decor.gdshader")
	m.set_shader_parameter("fog_tex", fog_tex)
	m.set_shader_parameter("map_size", Vector2(game.w, game.h))
	m.set_shader_parameter("emission", emission)
	m.set_shader_parameter("sway", sway)
	m.set_shader_parameter("bob", bob)
	decor_mats.append(m)
	return m

# ================================================================ heights

func _tile_rng(i: int, salt: int = 0) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(i * 7919 + salt * 104729 + 17)
	return r

func _compute_heights() -> void:
	var n := game.w * game.h
	h_center.resize(n)
	h_edge.resize(n)
	for i in n:
		var t: int = game.terrain[i]
		var base: float = Defs.TERRAIN[t].height
		h_edge[i] = base
		h_center[i] = base
		if game.hills[i] == 1:
			h_center[i] = base + 0.34
		elif t == Defs.MOUNTAIN:
			h_center[i] = base + 0.2

func tile_top(c: Vector2i) -> float:
	if not game.in_bounds(c):
		return 0.0
	var i := game.idx(c)
	if game.is_water(c):
		return 0.02
	return h_center[i]

func surface_point(c: Vector2i, offset: Vector3) -> Vector3:
	## Height on a tile at a local offset (approximates the mound profile).
	var p := Hex.to_world(c) + offset
	var i := game.idx(c)
	var r := clampf(Vector2(offset.x, offset.z).length(), 0.0, 1.0)
	var y: float
	if r < 0.55:
		y = lerpf(h_center[i], lerpf(h_center[i], h_edge[i], 0.4), r / 0.55)
	else:
		y = lerpf(lerpf(h_center[i], h_edge[i], 0.4), h_edge[i], (r - 0.55) / 0.45)
	if game.is_water(c):
		y = maxf(y, 0.0)
	p.y = y
	return p

# ================================================================ terrain mesh

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()

func _tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, hint: Vector3) -> void:
	var nrm := (b - a).cross(c - a)
	if nrm.dot(hint) > 0.0:
		# Godot treats clockwise triangles as front faces.
		var t := b; b = c; c = t
		var tc := cb; cb = cc; cc = tc
	else:
		nrm = -nrm
	nrm = nrm.normalized()
	if hint == Vector3.UP:
		# Soften the faceting on tile tops.
		nrm = (nrm + Vector3.UP * 1.5).normalized()
	_v.append(a); _v.append(b); _v.append(c)
	_n.append(nrm); _n.append(nrm); _n.append(nrm)
	_c.append(ca); _c.append(cb); _c.append(cc)

func _build_terrain() -> void:
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_c = PackedColorArray()
	for y in game.h:
		for x in game.w:
			_add_tile(Vector2i(x, y))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _v
	arr[Mesh.ARRAY_NORMAL] = _n
	arr[Mesh.ARRAY_COLOR] = _c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = terrain_mat
	mi.name = "Terrain"
	add_child(mi)
	_v = PackedVector3Array()
	_n = PackedVector3Array()
	_c = PackedColorArray()

func _add_tile(c: Vector2i) -> void:
	var i := game.idx(c)
	var t: int = game.terrain[i]
	var r := _tile_rng(i)
	var p := Hex.to_world(c)
	var base: Color = Defs.TERRAIN[t].color
	base = base.lightened(r.randf_range(-0.04, 0.05)) if r.randf() < 0.5 else base.darkened(r.randf_range(0.0, 0.06))
	if game.forest[i] == 1:
		base = base.darkened(0.18)
	if game.hills[i] == 1:
		base = base.lerp(Color("8d7e5a"), 0.2)
	var water := game.is_water(c)
	var coastal := false
	if not water:
		for nb in game.neighbors(c):
			if game.is_water(nb):
				coastal = true
				break
	var edge_col := base
	if coastal and t != Defs.SNOW and t != Defs.MOUNTAIN:
		edge_col = Defs.SAND_COLOR
	var he := h_edge[i]
	var hc := h_center[i]
	var hi := lerpf(hc, he, 0.4)
	var center := p + Vector3(0, hc, 0)
	var inner := []
	var outer := []
	for k in 6:
		var jitter := r.randf_range(-0.025, 0.025) if not water else 0.0
		inner.append(p + Hex.corner(k, 0.55) + Vector3(0, hi + jitter, 0))
		outer.append(p + Hex.corner(k, 1.0) + Vector3(0, he, 0))
	var inner_col := base.lerp(edge_col, 0.25)
	var top_c := base.lightened(0.04) if game.hills[i] == 1 else base
	for k in 6:
		var k2 := (k + 1) % 6
		_tri(center, inner[k], inner[k2], top_c, inner_col, inner_col, Vector3.UP)
		_tri(inner[k], outer[k], outer[k2], inner_col, edge_col, edge_col, Vector3.UP)
		_tri(inner[k], outer[k2], inner[k2], inner_col, edge_col, inner_col, Vector3.UP)
	# Side walls
	var wall_col := base.darkened(0.35).lerp(Color("5b4a3a"), 0.35 if not water else 0.0)
	if coastal:
		wall_col = Defs.SAND_COLOR.darkened(0.25)
	for k in 6:
		var k2 := (k + 1) % 6
		var a: Vector3 = outer[k]
		var b: Vector3 = outer[k2]
		var a2 := Vector3(a.x, WALL_BOTTOM, a.z)
		var b2 := Vector3(b.x, WALL_BOTTOM, b.z)
		var out := ((a + b) * 0.5 - p)
		out.y = 0
		var deep := wall_col.darkened(0.45)
		_tri(a, b, b2, wall_col, wall_col, deep, out)
		_tri(a, b2, a2, wall_col, deep, deep, out)

func _build_water() -> void:
	var size := Hex.to_world(Vector2i(game.w, game.h))
	var pm := PlaneMesh.new()
	var margin := 30.0
	pm.size = Vector2(size.x + margin * 2, size.z + margin * 2)
	pm.subdivide_width = int(pm.size.x * 2)
	pm.subdivide_depth = int(pm.size.y * 2)
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position = Vector3(size.x * 0.5 - 0.8, 0.0, size.z * 0.5 - 0.8)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Water"
	add_child(mi)
	# Dark floor far below so the area outside the map isn't empty.
	var floor_mi := MeshInstance3D.new()
	var fm := PlaneMesh.new()
	fm.size = pm.size * 3.0
	floor_mi.mesh = fm
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color("070a10")
	floor_mi.material_override = floor_mat
	floor_mi.position = mi.position + Vector3(0, -1.0, 0)
	add_child(floor_mi)

# ================================================================ decorations

func _mm(mesh: Mesh, xforms: Array, colors: Array, m: Material, shadows := true) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for k in xforms.size():
		mm.set_instance_transform(k, xforms[k])
		mm.set_instance_color(k, colors[k])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	if not shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

func _build_decor() -> void:
	var trunk_x := []; var trunk_c := []
	var cone_x := []; var cone_c := []
	var ball_x := []; var ball_c := []
	var rock_x := []; var rock_c := []
	var snow_x := []; var snow_c := []
	var gem_x := []; var gem_c := []
	var pebble_x := []; var pebble_c := []
	for y in game.h:
		for x in game.w:
			var c := Vector2i(x, y)
			var i := game.idx(c)
			var r := _tile_rng(i, 1)
			var t: int = game.terrain[i]
			if game.forest[i] == 1:
				var pine := t == Defs.TUNDRA or t == Defs.SNOW or game.hills[i] == 1 or (t == Defs.PLAINS and r.randf() < 0.5)
				var count := r.randi_range(5, 7)
				for k in count:
					var a := r.randf() * TAU
					var d := sqrt(r.randf()) * 0.72
					var off := Vector3(cos(a) * d, 0, sin(a) * d)
					var sp := surface_point(c, off)
					var s := r.randf_range(0.8, 1.25)
					var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.3), s))
					trunk_x.append(Transform3D(basis, sp + Vector3(0, 0.06 * s, 0)))
					trunk_c.append(Color("6b4b33"))
					var leaf := Color("2f6b33") if pine else Color("4f8f3a")
					leaf = leaf.lightened(r.randf_range(-0.08, 0.12))
					if t == Defs.TUNDRA or t == Defs.SNOW:
						leaf = Color("2c5640").lightened(r.randf_range(-0.05, 0.1))
					if pine:
						cone_x.append(Transform3D(basis, sp + Vector3(0, 0.27 * s, 0)))
						cone_c.append(leaf)
					else:
						ball_x.append(Transform3D(basis, sp + Vector3(0, 0.24 * s, 0)))
						ball_c.append(leaf)
			if t == Defs.MOUNTAIN:
				var peaks := [[Vector3(0, 0, 0), 1.0], [Vector3(0.38, 0, 0.22), 0.6], [Vector3(-0.32, 0, 0.28), 0.55], [Vector3(-0.05, 0, -0.42), 0.5]]
				for pk in peaks:
					var off: Vector3 = pk[0] + Vector3(r.randf_range(-0.08, 0.08), 0, r.randf_range(-0.08, 0.08))
					var s: float = pk[1] * r.randf_range(0.85, 1.15)
					var sp := surface_point(c, off)
					var basis := Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3(s, s * r.randf_range(0.9, 1.25), s))
					var top := sp + basis * Vector3(0, 0.45, 0)
					rock_x.append(Transform3D(basis, top))
					rock_c.append(Color("7a736c").lightened(r.randf_range(-0.08, 0.08)))
					if s > 0.62:
						snow_x.append(Transform3D(basis, sp + basis * Vector3(0, 0.9 - 0.16, 0)))
						snow_c.append(Color("f3f6fa"))
			elif t == Defs.DESERT and r.randf() < 0.5:
				for k in 3:
					var off := Vector3(r.randf_range(-0.6, 0.6), 0, r.randf_range(-0.5, 0.5))
					var sp := surface_point(c, off)
					pebble_x.append(Transform3D(Basis.from_scale(Vector3(1.4, 0.5, 1.0) * r.randf_range(0.5, 1.0)), sp))
					pebble_c.append(Color("c9a96e"))
			var res: String = game.resource[i]
			if res != "":
				var sp := surface_point(c, Vector3(0.42, 0, 0.3))
				sp.y = maxf(sp.y, 0.05) + 0.22
				gem_x.append(Transform3D(Basis(Vector3.UP, 0.4), sp))
				gem_c.append(Defs.RESOURCES[res].color)
	var tree_mat := _decor_mat(0.0, 0.08)
	add_child(_mm(Models.cyl(0.018, 0.026, 0.12, 5), trunk_x, trunk_c, tree_mat))
	add_child(_mm(Models.cyl(0.0, 0.13, 0.32, 6), cone_x, cone_c, tree_mat))
	add_child(_mm(Models.sphere(0.13, 7, 4), ball_x, ball_c, tree_mat))
	var rock_mat := _decor_mat()
	add_child(_mm(Models.cyl(0.0, 0.55, 0.9, 6), rock_x, rock_c, rock_mat))
	add_child(_mm(Models.cyl(0.0, 0.21, 0.33, 6), snow_x, snow_c, rock_mat))
	add_child(_mm(Models.sphere(0.07, 4, 2), pebble_x, pebble_c, rock_mat, false))
	add_child(_mm(Models.sphere(0.075, 4, 2), gem_x, gem_c, _decor_mat(1.6, 0.0, 0.03), false))

func _rebuild_improvements() -> void:
	var sig := ""
	for i in game.improvement.size():
		if game.improvement[i] != "":
			sig += "%d%s;" % [i, game.improvement[i]]
	if sig == _improvement_sig:
		return
	_improvement_sig = sig
	for ch in improvements_root.get_children():
		ch.queue_free()
	var row_x := []; var row_c := []
	var mine_x := []; var mine_c := []
	var tent_x := []; var tent_c := []
	for i in game.improvement.size():
		var imp: String = game.improvement[i]
		if imp == "":
			continue
		var c := Vector2i(i % game.w, i / game.w)
		match imp:
			"farm":
				for k in 4:
					var off := Vector3(-0.15 + 0.13 * k - 0.1, 0, 0.0)
					var sp := surface_point(c, Vector3(off.x, 0, -0.2))
					row_x.append(Transform3D(Basis(Vector3.UP, 0.5), sp + Vector3(0, 0.015, 0)))
					row_c.append(Color("e6c84a") if k % 2 == 0 else Color("a8c94a"))
			"mine":
				var sp := surface_point(c, Vector3(-0.3, 0, -0.25))
				mine_x.append(Transform3D(Basis(), sp + Vector3(0, 0.05, 0)))
				mine_c.append(Color("4a3f36"))
			"trading_post":
				var sp := surface_point(c, Vector3(-0.3, 0, -0.25))
				tent_x.append(Transform3D(Basis(Vector3.UP, 0.3), sp + Vector3(0, 0.07, 0)))
				tent_c.append(Color("e8dcc0"))
	var m := _decor_mat()
	if not row_x.is_empty():
		improvements_root.add_child(_mm(Models.box(Vector3(0.09, 0.03, 0.55)), row_x, row_c, m, false))
	if not mine_x.is_empty():
		improvements_root.add_child(_mm(Models.box(Vector3(0.16, 0.1, 0.12)), mine_x, mine_c, m))
	if not tent_x.is_empty():
		improvements_root.add_child(_mm(Models.prism(Vector3(0.2, 0.14, 0.18)), tent_x, tent_c, m))

# ================================================================ borders

func _rebuild_borders() -> void:
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in game.tile_owner.size():
		var o: int = game.tile_owner[i]
		if o < 0 or (explored[i] == 0 and not reveal_all):
			continue
		var c := Vector2i(i % game.w, i / game.w)
		var col: Color = game.player(o).color
		var p := Hex.to_world(c)
		var y := (h_edge[i] if not game.is_water(c) else 0.0) + 0.035
		for n in Hex.neighbors(c):
			if game.in_bounds(n) and game.tile_owner[game.idx(n)] == o:
				continue
			var q := Hex.to_world(n)
			var mid := (p + q) * 0.5
			var dir := (q - p).normalized()
			var perp := Vector3(-dir.z, 0, dir.x)
			var a := mid + perp * 0.5
			var b := mid - perp * 0.5
			a.y = y; b.y = y
			var ai := p.lerp(a, 0.78); ai.y = y
			var bi := p.lerp(b, 0.78); bi.y = y
			var al := p.lerp(a, 0.955); al.y = y + 0.002
			var bl := p.lerp(b, 0.955); bl.y = y + 0.002
			var c0 := Color(col, 0.55)
			var c1 := Color(col, 0.0)
			# soft inner glow
			for v in [a, b, bi, a, bi, ai]:
				verts.append(v)
			cols.append_array([c0, c0, c1, c0, c1, c1])
			# crisp line
			var cl := Color(col.lightened(0.25), 1.0)
			for v in [a, b, bl, a, bl, al]:
				verts.append(v)
			cols.append_array([cl, cl, cl, cl, cl, cl])
	if verts.is_empty():
		border_mi.mesh = null
		return
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	border_mi.mesh = mesh
	if border_mi.material_override == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.render_priority = 1
		border_mi.material_override = m

# ================================================================ fog

func update_fog() -> void:
	var me := game.player(pid)
	if not me.alive or game.finished:
		reveal_all = true
	visible_now = game.visible_tiles(pid)
	for i in visible_now.size():
		if visible_now[i] == 1:
			explored[i] = 1
	for i in visible_now.size():
		var v := 1.0 if (visible_now[i] == 1 or reveal_all) else (0.5 if explored[i] == 1 else 0.0)
		fog_img.set_pixel(i % game.w, i / game.w, Color(v, 0, 0, 1))
	fog_tex.update(fog_img)

func is_visible_tile(c: Vector2i) -> bool:
	return reveal_all or (game.in_bounds(c) and visible_now[game.idx(c)] == 1)

func is_explored(c: Vector2i) -> bool:
	return reveal_all or (game.in_bounds(c) and explored[game.idx(c)] == 1)

# ================================================================ overlays

func _hex_fill_mesh(radius: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	for k in 6:
		verts.append(Vector3.ZERO)
		verts.append(Hex.corner((k + 1) % 6, radius))
		verts.append(Hex.corner(k, radius))
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _hex_ring_mesh(r0: float, r1: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	for k in 6:
		var k2 := (k + 1) % 6
		var a := Hex.corner(k, r0)
		var b := Hex.corner(k2, r0)
		var c := Hex.corner(k, r1)
		var d := Hex.corner(k2, r1)
		verts.append_array([a, d, c, a, b, d])
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

func _overlay_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.render_priority = 2
	return m

func _build_overlays() -> void:
	_fill_mesh = _hex_fill_mesh(0.9)
	_ring_mesh = _hex_ring_mesh(0.8, 0.95)
	overlay = Node3D.new()
	add_child(overlay)
	hover_mi = MeshInstance3D.new()
	hover_mi.mesh = _ring_mesh
	hover_mi.material_override = _overlay_mat(Color(1, 1, 1, 0.55))
	hover_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(hover_mi)
	select_mi = MeshInstance3D.new()
	select_mi.mesh = _ring_mesh
	select_mi.material_override = _overlay_mat(Color(1.0, 0.85, 0.3, 0.9))
	select_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	select_mi.visible = false
	overlay.add_child(select_mi)
	reach_mmi = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _fill_mesh
	reach_mmi.multimesh = mm
	reach_mmi.material_override = _overlay_mat(Color(0.35, 0.75, 1.0, 0.22))
	reach_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.add_child(reach_mmi)
	target_root = Node3D.new()
	overlay.add_child(target_root)
	path_root = Node3D.new()
	overlay.add_child(path_root)

func set_hover(c: Vector2i) -> void:
	hover_mi.visible = game.in_bounds(c) and is_explored(c)
	if hover_mi.visible:
		hover_mi.position = Hex.to_world(c) + Vector3(0, maxf(tile_top(c), h_edge[game.idx(c)]) + 0.05, 0)

func set_selection(c: Vector2i) -> void:
	select_mi.visible = c.x >= 0
	if select_mi.visible:
		select_mi.position = Hex.to_world(c) + Vector3(0, maxf(tile_top(c), 0.02) + 0.06, 0)

func show_reach(tiles: Dictionary, targets: Array) -> void:
	var mm := reach_mmi.multimesh
	mm.instance_count = tiles.size()
	var k := 0
	for t in tiles:
		mm.set_instance_transform(k, Transform3D(Basis(), Hex.to_world(t) + Vector3(0, maxf(h_edge[game.idx(t)], 0.0) + 0.04, 0)))
		k += 1
	for ch in target_root.get_children():
		ch.queue_free()
	for t in targets:
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh
		mi.material_override = _overlay_mat(Color(1.0, 0.25, 0.2, 0.85))
		mi.position = Hex.to_world(t) + Vector3(0, maxf(tile_top(t), 0.02) + 0.07, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		target_root.add_child(mi)

func clear_reach() -> void:
	show_reach({}, [])

func show_path(path: Array, turns: Array) -> void:
	for ch in path_root.get_children():
		ch.queue_free()
	var dot_mat := _overlay_mat(Color(1, 1, 1, 0.9))
	for k in path.size():
		var t: Vector2i = path[k]
		var mi := MeshInstance3D.new()
		mi.mesh = Models.sphere(0.06, 8, 4)
		mi.material_override = dot_mat
		mi.position = Hex.to_world(t) + Vector3(0, maxf(tile_top(t), 0.02) + 0.12, 0)
		path_root.add_child(mi)
		var last := k == path.size() - 1
		if last or (k + 1 < turns.size() and turns[k + 1] != turns[k]):
			var lbl := Label3D.new()
			lbl.text = str(turns[k])
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			lbl.font_size = 40
			lbl.outline_size = 10
			lbl.pixel_size = 0.006
			lbl.position = mi.position + Vector3(0, 0.25, 0)
			path_root.add_child(lbl)

func clear_path() -> void:
	for ch in path_root.get_children():
		ch.queue_free()

# ================================================================ units & cities

var _occ := {}

func _unit_world_pos(u) -> Vector3:
	var p := Hex.to_world(u.pos)
	p.y = maxf(tile_top(u.pos), 0.0)
	var has_city := game.city_at.has(u.pos)
	var other: bool = _occ.get(u.pos, []).size() > 1 if not _occ.is_empty() else game.units_at(u.pos).size() > 1
	if has_city:
		p += Vector3(0.0, 0.0, 0.5) if not u.is_civilian() else Vector3(-0.42, 0, 0.32)
		p.y = surface_point(u.pos, Vector3(0, 0, 0.5)).y
	elif other and u.is_civilian():
		p += Vector3(0.3, 0, 0.22)
		p.y = surface_point(u.pos, Vector3(0.3, 0, 0.22)).y
	elif other:
		p += Vector3(-0.15, 0, -0.1)
	return p

func _make_unit_view(u) -> Node3D:
	var v := Node3D.new()
	var model := Models.unit_model(u.def().model, game.player(u.owner).color)
	model.name = "Model"
	model.scale = Vector3.ONE * 1.55
	v.add_child(model)
	# Health bar
	var bar := Node3D.new()
	bar.name = "Bar"
	bar.position = Vector3(0, 0.78, 0)
	v.add_child(bar)
	var bg := MeshInstance3D.new()
	bg.mesh = Models.box(Vector3(0.42, 0.05, 0.01))
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.albedo_color = Color(0, 0, 0, 0.7)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bgm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bgm.billboard_keep_scale = true
	bgm.no_depth_test = true
	bg.material_override = bgm
	bar.add_child(bg)
	var fg := MeshInstance3D.new()
	fg.name = "Fill"
	fg.mesh = Models.box(Vector3(0.4, 0.035, 0.012))
	var fgm := bgm.duplicate()
	fgm.albedo_color = Color("5be37d")
	fgm.render_priority = 1
	fg.material_override = fgm
	bar.add_child(fg)
	# Status icon (fortified / sleeping / building)
	var icon := Label3D.new()
	icon.name = "Icon"
	icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon.no_depth_test = true
	icon.font_size = 36
	icon.outline_size = 8
	icon.pixel_size = 0.005
	icon.position = Vector3(0.38, 0.6, 0)
	v.add_child(icon)
	add_child(v)
	return v

func _update_unit_view(v: Node3D, u) -> void:
	var bar: Node3D = v.get_node("Bar")
	bar.visible = u.hp < 100
	var fill: MeshInstance3D = bar.get_node("Fill")
	var f := clampf(u.hp / 100.0, 0.0, 1.0)
	fill.scale = Vector3(f, 1, 1)
	fill.position.x = -0.2 * (1.0 - f)
	(fill.material_override as StandardMaterial3D).albedo_color = Color("5be37d").lerp(Color("ff4a3d"), 1.0 - f)
	var icon: Label3D = v.get_node("Icon")
	var txt := ""
	if u.fortified: txt = "⛨"
	elif u.sleeping: txt = "z"
	elif u.build_kind != "": txt = "⚒%d" % u.build_left
	elif u.veteran: txt = "★"
	icon.text = txt
	icon.modulate = Color(1, 1, 1) if u.owner == pid else game.player(u.owner).color.lightened(0.4)

func sync_units(animate_path: Dictionary = {}) -> void:
	_occ = game.build_occ()
	var seen := {}
	for u in game.units.values():
		seen[u.id] = true
		var v: Node3D = unit_views.get(u.id)
		var st: Dictionary = unit_state.get(u.id, {})
		if v == null or st.get("owner", -1) != u.owner or st.get("type", "") != u.type:
			if v != null:
				v.queue_free()
			v = _make_unit_view(u)
			unit_views[u.id] = v
			v.position = _unit_world_pos(u)
			unit_state[u.id] = {"pos": u.pos, "owner": u.owner, "type": u.type}
		var target := _unit_world_pos(u)
		if animate_path.has(u.id) and v.visible:
			_walk(v, u, animate_path[u.id])
		elif v.position.distance_to(target) > 0.01 and not v.has_meta("walking"):
			v.position = target
		unit_state[u.id].pos = u.pos
		v.visible = u.owner == pid or is_visible_tile(u.pos)
		_update_unit_view(v, u)
	for id in unit_views.keys():
		if not seen.has(id):
			var v: Node3D = unit_views[id]
			_fade_out(v)
			unit_views.erase(id)
			unit_state.erase(id)

func _walk(v: Node3D, u, path: Array) -> void:
	v.set_meta("walking", true)
	var tw := v.create_tween()
	var prev := v.position
	for k in path.size():
		var step: Vector2i = path[k]
		var p := Hex.to_world(step)
		p.y = maxf(tile_top(step), 0.0)
		if k == path.size() - 1:
			p = _unit_world_pos(u)
		var dir := p - prev
		dir.y = 0
		if dir.length() > 0.01:
			var yaw := atan2(-dir.x, -dir.z)
			tw.tween_property(v.get_node("Model"), "rotation:y", yaw, 0.06)
		tw.tween_property(v, "position", p, 0.16).set_trans(Tween.TRANS_SINE)
		prev = p
	tw.tween_callback(v.remove_meta.bind("walking"))

func _fade_out(v: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(v, "scale", Vector3(0.01, 0.01, 0.01), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(v.queue_free)

func _city_signature(c) -> String:
	return "%d|%d|%s|%d|%s|%s|%d" % [c.owner, c.pop, ",".join(c.buildings), c.hp, c.production, str(c.capital), game.player(c.owner).techs.size() / 6]

func sync_cities() -> void:
	var seen := {}
	for c in game.cities.values():
		seen[c.id] = true
		var known := is_explored(c.pos)
		var v: Node3D = city_views.get(c.id)
		var sig := _city_signature(c)
		if v == null or city_sig.get(c.id, "") != sig:
			if v != null:
				v.queue_free()
			v = _build_city(c)
			city_views[c.id] = v
			city_sig[c.id] = sig
		v.visible = known
		_update_city_label(v, c)
	for id in city_views.keys():
		if not seen.has(id):
			city_views[id].queue_free()
			city_views.erase(id)

func _build_city(c) -> Node3D:
	var root := Node3D.new()
	root.position = Hex.to_world(c.pos)
	add_child(root)
	var r := RandomNumberGenerator.new()
	r.seed = c.id * 9973 + c.pop
	var team: Color = game.player(c.owner).color
	var techs: int = game.player(c.owner).techs.size()
	var modern := techs >= 18
	var y0 := surface_point(c.pos, Vector3.ZERO).y
	# Plaza
	Models.add(root, Models.cyl(0.62, 0.66, 0.06, 6), Models.mat(Color("b8ad98"), 0.9), Vector3(0, y0 + 0.01, 0), Vector3(0, PI / 6, 0))
	Models.add(root, Models.cyl(0.2, 0.2, 0.065, 12), Models.mat(Color("d7cfbf"), 0.8), Vector3(0, y0 + 0.02, -0.05))
	var wall := Color("eae1cf")
	var roof := ROOF_FOR(team)
	var count := mini(4 + c.pop * 2, 16)
	var placed := []
	for k in count:
		var tries := 0
		while tries < 20:
			tries += 1
			var a := r.randf() * TAU
			var d := r.randf_range(0.25, 0.62)
			var p := Vector3(cos(a) * d, 0, sin(a) * d * 0.9)
			if p.z > 0.28 and absf(p.x) < 0.3:
				continue  # keep the front free for the garrison
			var ok := true
			for q in placed:
				if q.distance_to(p) < 0.17:
					ok = false
					break
			if ok:
				placed.append(p)
				p.y = y0 + 0.02
				if modern and r.randf() < 0.55:
					Models.modern_block(root, p, r.randf() * TAU, r.randf_range(0.2, 0.5), team)
				else:
					Models.house(root, p, r.randf() * TAU, r.randf_range(0.75, 1.1), wall.darkened(r.randf() * 0.12), roof.darkened(r.randf() * 0.15))
				break
	# Landmark
	if c.capital:
		Models.tower(root, Vector3(0, y0, -0.05), 0.42, Color("f2ead8"), team.darkened(0.15))
		var flag := Models.add(root, Models.box(Vector3(0.12, 0.07, 0.005)), Models.mat(team, 0.5, 0.0, 0.3), Vector3(0.06, y0 + 0.66, -0.05))
		flag.name = "Flag"
		Models.add(root, Models.cyl(0.006, 0.006, 0.2, 4), Models.mat(Models.DARK), Vector3(0, y0 + 0.6, -0.05))
	else:
		Models.add(root, Models.cyl(0.1, 0.12, 0.16, 8), Models.mat(Color("ece4d2"), 0.7), Vector3(0, y0 + 0.08, -0.05))
		Models.add(root, Models.sphere(0.1, 10, 5), Models.mat(team.lightened(0.15), 0.4), Vector3(0, y0 + 0.17, -0.05), Vector3.ZERO, Vector3(1, 0.7, 1))
	if c.buildings.has("walls") or c.buildings.has("castle"):
		var stone := Color("a39c90") if not c.buildings.has("castle") else Color("8f8a83")
		for k in 6:
			var a := Hex.corner(k, 0.78)
			var b := Hex.corner((k + 1) % 6, 0.78)
			var mid := (a + b) * 0.5
			if k == 1:
				continue  # gate
			var seg := Models.add(root, Models.box(Vector3(0.78, 0.13, 0.05)), Models.mat(stone, 0.9), mid + Vector3(0, y0 + 0.065, 0))
			seg.look_at_from_position(seg.position, seg.position + (b - a), Vector3.UP)
			seg.rotate_object_local(Vector3.UP, PI / 2)
			Models.tower(root, a + Vector3(0, y0, 0), 0.2, stone, stone.darkened(0.3))
	# Label
	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = false
	lbl.font_size = 34
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0.04, 0.05, 0.08, 0.95)
	lbl.pixel_size = 0.006
	lbl.line_spacing = -6
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.position = Vector3(0, y0 + 0.85, 0)
	lbl.render_priority = 5
	lbl.outline_render_priority = 4
	root.add_child(lbl)
	return root

static func ROOF_FOR(team: Color) -> Color:
	return Models.ROOF.lerp(team, 0.35)

func _update_city_label(v: Node3D, c) -> void:
	var lbl: Label3D = v.get_node("Label")
	var star := "★ " if c.capital else ""
	lbl.modulate = game.player(c.owner).color.lightened(0.35)
	var s := ""
	if c.owner == pid:
		if c.production == "":
			s = "⚠ choose production"
		else:
			var t := game.turns_to_build(c)
			s = "%s%s" % [Defs.item_name(c.production), (" · %d" % t) if t > 0 else ""]
	else:
		s = game.player(c.owner).civ_name()
	if c.hp < c.max_hp():
		s += "   ♥ %d%%" % int(100.0 * c.hp / c.max_hp())
	lbl.text = "%s%s  %d\n%s" % [star, c.name.to_upper(), c.pop, s]

# ================================================================ events & effects

func refresh_all() -> void:
	update_fog()
	_rebuild_borders()
	_rebuild_improvements()
	sync_cities()
	sync_units()

var _dirty := false
var _dirty_borders := false
var _dirty_improvements := false
var _pending_paths := {}

func _on_event(ev: Dictionary) -> void:
	match ev.t:
		"move":
			if _pending_paths.has(ev.u):
				_pending_paths[ev.u] = _pending_paths[ev.u] + ev.path
			else:
				_pending_paths[ev.u] = ev.path
			if ev.get("capture", -1) >= 0:
				_dirty_borders = true
		"attack":
			_attack_fx(ev)
			_dirty_borders = true
		"city_attack":
			if game.cities.has(ev.c):
				var c = game.cities[ev.c]
				var target := Hex.to_world(c.pos)
				if unit_views.has(ev.u):
					target = unit_views[ev.u].position
				if is_visible_tile(c.pos):
					_projectile(Hex.to_world(c.pos) + Vector3(0, 0.6, 0), target + Vector3(0, 0.2, 0), Color(1, 0.6, 0.2))
					_popup(target + Vector3(0, 0.5, 0), "-%d" % ev.dmg, Color(1, 0.4, 0.3))
		"found", "new_turn", "drop":
			_dirty_borders = true
			_dirty_improvements = true
	_dirty = true

func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	update_fog()
	if _dirty_borders:
		_rebuild_borders()
		_dirty_borders = false
	if _dirty_improvements:
		_rebuild_improvements()
		_dirty_improvements = false
	sync_cities()
	sync_units(_pending_paths)
	_pending_paths = {}

func _attack_fx(ev: Dictionary) -> void:
	var a_view: Node3D = unit_views.get(ev.u)
	var tgt: Vector3 = Hex.to_world(ev.target)
	tgt.y = maxf(tile_top(ev.target), 0.0)
	if a_view == null:
		return
	if not (is_visible_tile(ev.target) or (game.units.has(ev.u) and is_visible_tile(game.units[ev.u].pos))):
		return
	var unit_def: Dictionary = Defs.UNITS.get(unit_state.get(ev.u, {}).get("type", "warrior"), Defs.UNITS.warrior)
	var ranged: bool = unit_def.rstr > 0
	var from := a_view.position
	var dir := tgt - from
	dir.y = 0
	if dir.length() > 0.01:
		a_view.get_node("Model").rotation.y = atan2(-dir.x, -dir.z)
	if ranged:
		_projectile(from + Vector3(0, 0.3, 0), tgt + Vector3(0, 0.2, 0), Color(1, 0.9, 0.5))
	else:
		var tw := create_tween()
		tw.tween_property(a_view, "position", from.lerp(tgt, 0.45), 0.12)
		tw.tween_property(a_view, "position", from, 0.18)
	_popup(tgt + Vector3(0, 0.6, 0), "-%d" % ev.dmg_def, Color(1, 0.35, 0.3))
	if ev.dmg_att > 0:
		_popup(from + Vector3(0, 0.6, 0), "-%d" % ev.dmg_att, Color(1, 0.7, 0.3))
	_burst(tgt + Vector3(0, 0.25, 0))

func _popup(p: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.modulate = col
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = 52
	l.outline_size = 12
	l.pixel_size = 0.006
	l.position = p
	l.render_priority = 6
	fx_root.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position", p + Vector3(0, 0.6, 0), 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

func _projectile(from: Vector3, to: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = Models.sphere(0.04, 6, 3)
	mi.material_override = Models.mat(col, 0.3, 0.0, 3.0)
	mi.position = from
	fx_root.add_child(mi)
	var tw := create_tween()
	var mid := (from + to) * 0.5 + Vector3(0, from.distance_to(to) * 0.35, 0)
	var arc := func(t: float) -> void:
		mi.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t)
	tw.tween_method(arc, 0.0, 1.0, 0.4)
	tw.tween_callback(mi.queue_free)

func _burst(p: Vector3) -> void:
	var parts := CPUParticles3D.new()
	parts.one_shot = true
	parts.emitting = true
	parts.amount = 18
	parts.lifetime = 0.6
	parts.explosiveness = 1.0
	parts.direction = Vector3.UP
	parts.spread = 70.0
	parts.initial_velocity_min = 0.6
	parts.initial_velocity_max = 1.4
	parts.gravity = Vector3(0, -2.5, 0)
	parts.scale_amount_min = 0.5
	parts.scale_amount_max = 1.0
	var m := Models.sphere(0.025, 4, 2)
	parts.mesh = m
	parts.material_override = Models.mat(Color(1, 0.75, 0.35), 0.5, 0.0, 2.5)
	parts.position = p
	fx_root.add_child(parts)
	get_tree().create_timer(1.2).timeout.connect(parts.queue_free)

func _process(delta: float) -> void:
	flush()
	_time += delta
	if select_mi and select_mi.visible:
		var s := 1.0 + sin(_time * 4.0) * 0.04
		select_mi.scale = Vector3(s, 1, s)
