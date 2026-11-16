extends Node3D
## World builder: lighting, atmosphere, terrain, props, spawning and weapon dispatch.

const UnitScript := preload("res://scripts/unit.gd")
const BuildingScript := preload("res://scripts/building.gd")
const ProjectileScript := preload("res://scripts/projectile.gd")
const Models := preload("res://scripts/models.gd")
const RTSCamera := preload("res://scripts/rts_camera.gd")
const PlayerController := preload("res://scripts/player_controller.gd")
const HUD := preload("res://scripts/hud.gd")
const EnemyAI := preload("res://scripts/enemy_ai.gd")
const TerrainShader := preload("res://shaders/terrain.gdshader")

const TERRAIN_HALF := 175.0
const TERRAIN_RES := 250
const BASES := [Vector2(-78, 78), Vector2(78, -78)]
## Oil wells on the player's half; mirrored for the enemy, plus one in the centre.
const WELLS_A := [Vector2(-60, 58), Vector2(-92, 54), Vector2(-56, 95), Vector2(-28, 30),
	Vector2(-50, 12), Vector2(-8, 62), Vector2(-34, -28)]
const ROAD := [Vector2(-78, 78), Vector2(-50, 52), Vector2(-14, 20), Vector2(14, -20),
	Vector2(50, -52), Vector2(78, -78)]

var heights := PackedFloat32Array()
var grid_step := 1.0
var noise := FastNoiseLite.new()
var noise_fine := FastNoiseLite.new()
var craters: Array = []
var base_heights: Array = [0.0, 0.0]
var well_points: Array = []
var entities_root: Node3D
var fx_root: Node3D
var camera_rig: Node3D
var controller: Node
var hud: CanvasLayer
var ai: Node
var env: Environment
var sun: DirectionalLight3D
var minimap_texture: ImageTexture
var rng := RandomNumberGenerator.new()
var high_quality := true
var _shot_path := ""
var _shot_t := 0.0
var _report := false
var _report_t := 0.0


func _ready() -> void:
	Game.reset()
	FX.reset()
	Game.world = self
	Game.compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	if Game.compat:
		high_quality = false
	rng.seed = 20261115
	entities_root = Node3D.new()
	entities_root.name = "Entities"
	add_child(entities_root)
	fx_root = Node3D.new()
	fx_root.name = "FX"
	add_child(fx_root)
	_setup_environment()
	_compute_wells()
	_setup_terrain()
	_setup_wells()
	_setup_props()
	_build_minimap()
	camera_rig = RTSCamera.new()
	camera_rig.name = "CameraRig"
	add_child(camera_rig)
	_setup_ambient_particles()
	controller = PlayerController.new()
	controller.name = "PlayerController"
	add_child(controller)
	hud = HUD.new()
	add_child(hud)
	ai = EnemyAI.new()
	ai.name = "EnemyAI"
	add_child(ai)
	_spawn_start()
	var b: Vector2 = BASES[0]
	camera_rig.focus(Vector3(b.x + 12.0, 0.0, b.y - 12.0), true)
	_parse_args()


# ================================================================ atmosphere

func _setup_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.30, 0.33, 0.38)
	sky_mat.sky_horizon_color = Color(0.86, 0.60, 0.38)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.55, 0.42, 0.30)
	sky_mat.ground_bottom_color = Color(0.14, 0.11, 0.09)
	sky_mat.sun_angle_max = 25.0
	sky_mat.sun_curve = 0.08
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.92
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_strength = 1.0
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 2.2
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.56, 0.42)
	env.fog_light_energy = 0.9
	env.fog_sun_scatter = 0.35
	env.fog_density = 0.0012
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.25
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0032
	env.volumetric_fog_albedo = Color(0.88, 0.76, 0.64)
	env.volumetric_fog_anisotropy = 0.55
	env.volumetric_fog_length = 160.0
	env.volumetric_fog_ambient_inject = 0.15
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.12
	env.adjustment_saturation = 0.92
	if Game.compat:
		# The web build's renderer has no volumetric fog or SSAO: a denser plain fog carries the haze instead.
		env.volumetric_fog_enabled = false
		env.ssao_enabled = false
		env.fog_density = 0.0042
		env.fog_aerial_perspective = 0.4
		env.tonemap_exposure = 1.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-36.0, -72.0, 0.0)
	sun.light_color = Color(1.0, 0.80, 0.60)
	sun.light_energy = 2.0
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_blur = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 150.0 if Game.compat else 220.0
	sun.light_volumetric_fog_energy = 1.6
	add_child(sun)


func toggle_quality() -> void:
	if Game.compat:
		Game.notify("The browser build has one graphics setting; download the desktop build for volumetric haze")
		return
	high_quality = not high_quality
	env.volumetric_fog_enabled = high_quality
	env.ssao_enabled = high_quality
	sun.directional_shadow_max_distance = 220.0 if high_quality else 120.0
	Game.notify("Graphics: %s" % ("High" if high_quality else "Performance"))


func _setup_ambient_particles() -> void:
	var ash := GPUParticles3D.new()
	ash.amount = 450
	ash.lifetime = 10.0
	ash.preprocess = 10.0
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(70, 18, 70)
	pm.direction = Vector3(1, -0.3, 0.4)
	pm.spread = 30.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 1.6
	pm.gravity = Vector3(0.2, -0.25, 0.1)
	pm.scale_min = 0.05
	pm.scale_max = 0.14
	pm.color = Color(0.75, 0.70, 0.62, 0.5)
	ash.process_material = pm
	ash.draw_pass_1 = FX.quad
	ash.material_override = FX.mat_smoke
	ash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ash.visibility_aabb = AABB(Vector3(-100, -50, -100), Vector3(200, 100, 200))
	ash.position = Vector3(0, 12, 0)
	camera_rig.add_child(ash)

	var embers := GPUParticles3D.new()
	embers.amount = 70
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	var em := pm.duplicate() as ParticleProcessMaterial
	em.gravity = Vector3(0.3, 0.25, 0.1)
	em.scale_min = 0.04
	em.scale_max = 0.09
	em.color = Color(3.0, 1.2, 0.35, 1.0)
	embers.process_material = em
	embers.draw_pass_1 = FX.quad
	embers.material_override = FX.mat_add
	embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	embers.visibility_aabb = ash.visibility_aabb
	embers.position = Vector3(0, 6, 0)
	camera_rig.add_child(embers)


# ================================================================ terrain

func _compute_wells() -> void:
	well_points.clear()
	for w in WELLS_A:
		well_points.append(w)
		well_points.append(-w)
	well_points.append(Vector2.ZERO)


func _road_dist(p: Vector2) -> float:
	var best := INF
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func _raw_height(x: float, z: float) -> float:
	var h := noise.get_noise_2d(x, z) * 7.0 + noise_fine.get_noise_2d(x, z) * 0.5
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(108.0, 150.0, edge) * (16.0 + 10.0 * noise.get_noise_2d(x * 3.0, z * 3.0))
	var p := Vector2(x, z)
	for c in craters:
		var cr: float = c.z
		var dx: float = x - c.x
		var dz: float = z - c.y
		if absf(dx) > cr * 1.8 or absf(dz) > cr * 1.8:
			continue
		var t := sqrt(dx * dx + dz * dz) / cr
		if t < 1.0:
			h -= (1.0 - t * t) * cr * 0.32
		h += exp(-pow((t - 1.0) * 3.5, 2.0)) * cr * 0.12
	h = lerpf(h, h * 0.35, 1.0 - smoothstep(3.0, 7.0, _road_dist(p)))
	for i in 2:
		var b: Vector2 = BASES[i]
		var f := 1.0 - smoothstep(26.0, 46.0, p.distance_to(b))
		h = lerpf(h, base_heights[i], f)
	return h


func _ground_paint(x: float, z: float) -> Color:
	if absf(x) > Game.MAP_HALF + 20.0 or absf(z) > Game.MAP_HALF + 20.0:
		return Color(0, 0, 0, 1)
	var p := Vector2(x, z)
	var scorch := 0.0
	for c in craters:
		var d := p.distance_to(Vector2(c.x, c.y))
		var rr: float = c.z * 1.4
		if d < rr:
			scorch = maxf(scorch, 1.0 - d / rr)
	var oil := 0.0
	for w in well_points:
		var d := p.distance_to(w)
		if d < 6.5:
			oil = maxf(oil, 1.0 - d / 6.5)
	var gravel := 0.0
	for b in BASES:
		gravel = maxf(gravel, 1.0 - smoothstep(16.0, 32.0, p.distance_to(b)))
	gravel = maxf(gravel, (1.0 - smoothstep(2.0, 4.5, _road_dist(p))) * 0.9)
	return Color(scorch, oil, gravel, 1.0)


func _setup_terrain() -> void:
	noise.seed = 1913
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.0075
	noise.fractal_octaves = 4
	noise_fine.seed = 77
	noise_fine.frequency = 0.06
	for i in 2:
		var b: Vector2 = BASES[i]
		base_heights[i] = noise.get_noise_2d(b.x, b.y) * 7.0
	var tries := 0
	while craters.size() < 34 and tries < 500:
		tries += 1
		var p := Vector2(rng.randf_range(-108, 108), rng.randf_range(-108, 108))
		if p.distance_to(BASES[0]) < 44.0 or p.distance_to(BASES[1]) < 44.0:
			continue
		var bad := _road_dist(p) < 7.0
		for w in well_points:
			if p.distance_to(w) < 10.0:
				bad = true
		if not bad:
			craters.append(Vector3(p.x, p.y, rng.randf_range(2.2, 5.5)))

	var n := TERRAIN_RES + 1
	grid_step = TERRAIN_HALF * 2.0 / TERRAIN_RES
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = _raw_height(-TERRAIN_HALF + i * grid_step, -TERRAIN_HALF + j * grid_step)

	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var tans := PackedFloat32Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(n * n)
	norms.resize(n * n)
	tans.resize(n * n * 4)
	cols.resize(n * n)
	idx.resize(TERRAIN_RES * TERRAIN_RES * 6)
	for j in n:
		for i in n:
			var k := j * n + i
			var x := -TERRAIN_HALF + i * grid_step
			var z := -TERRAIN_HALF + j * grid_step
			verts[k] = Vector3(x, heights[k], z)
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, TERRAIN_RES)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, TERRAIN_RES) * n + i]
			norms[k] = Vector3(hl - hr, 2.0 * grid_step, hd - hu).normalized()
			var tan := Vector3(2.0 * grid_step, hr - hl, 0.0).normalized()
			tans[k * 4] = tan.x
			tans[k * 4 + 1] = tan.y
			tans[k * 4 + 2] = tan.z
			tans[k * 4 + 3] = 1.0
			cols[k] = _ground_paint(x, z)
	var t := 0
	for j in TERRAIN_RES:
		for i in TERRAIN_RES:
			var a := j * n + i
			idx[t] = a
			idx[t + 1] = a + 1
			idx[t + 2] = a + n
			idx[t + 3] = a + 1
			idx[t + 4] = a + n + 1
			idx[t + 5] = a + n
			t += 6
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TANGENT] = tans
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = mesh
	mi.material_override = _terrain_material()
	mi.layers = 3
	add_child(mi)


func _noise_tex(freq: float, octaves: int, seed_v: int, normal_map: bool = false,
		ntype: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> NoiseTexture2D:
	var fn := FastNoiseLite.new()
	fn.noise_type = ntype
	fn.frequency = freq
	fn.fractal_octaves = octaves
	fn.seed = seed_v
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.noise = fn
	if normal_map:
		t.as_normal_map = true
		t.bump_strength = 3.0
	return t


func _terrain_material() -> ShaderMaterial:
	var sm := ShaderMaterial.new()
	sm.shader = TerrainShader
	sm.set_shader_parameter("macro_noise", _noise_tex(0.012, 5, 3))
	sm.set_shader_parameter("detail_noise", _noise_tex(0.05, 3, 9))
	sm.set_shader_parameter("detail_normal", _noise_tex(0.04, 3, 21, true, FastNoiseLite.TYPE_CELLULAR))
	return sm


func height_at(x: float, z: float) -> float:
	var fx := (x + TERRAIN_HALF) / grid_step
	var fz := (z + TERRAIN_HALF) / grid_step
	var i := clampi(floori(fx), 0, TERRAIN_RES - 1)
	var j := clampi(floori(fz), 0, TERRAIN_RES - 1)
	var tx := clampf(fx - i, 0.0, 1.0)
	var tz := clampf(fz - j, 0.0, 1.0)
	var n := TERRAIN_RES + 1
	var h00 := heights[j * n + i]
	var h10 := heights[j * n + i + 1]
	var h01 := heights[(j + 1) * n + i]
	var h11 := heights[(j + 1) * n + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func normal_at(x: float, z: float) -> Vector3:
	var e := 1.2
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e,
		height_at(x, z - e) - height_at(x, z + e)).normalized()


func _build_minimap() -> void:
	var s := 160
	var img := Image.create(s, s, false, Image.FORMAT_RGB8)
	var light_dir := Vector3(-0.5, 0.75, 0.45).normalized()
	for y in s:
		for x in s:
			var wx := -Game.MAP_HALF + (x + 0.5) / s * Game.MAP_HALF * 2.0
			var wz := -Game.MAP_HALF + (y + 0.5) / s * Game.MAP_HALF * 2.0
			var h := height_at(wx, wz)
			var shade := clampf(normal_at(wx, wz).dot(light_dir) * 1.15, 0.3, 1.15)
			var paint := _ground_paint(wx, wz)
			var c := Color(0.27, 0.25, 0.16).lerp(Color(0.42, 0.37, 0.27), clampf((h + 5.0) / 14.0, 0.0, 1.0))
			c = c.lerp(Color(0.52, 0.49, 0.43), paint.b * 0.7)
			c = c.lerp(Color(0.12, 0.10, 0.08), paint.r * 0.6)
			c = c.lerp(Color(0.03, 0.03, 0.03), smoothstep(0.3, 0.6, paint.g))
			img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	minimap_texture = ImageTexture.create_from_image(img)


# ================================================================ props

func _setup_wells() -> void:
	for w in well_points:
		var p := Vector3(w.x, height_at(w.x, w.y), w.y)
		Game.wells.append({"pos": p, "owner": null})
		var head := Node3D.new()
		head.position = p
		add_child(head)
		Models.cyl(head, 0.3, 0.36, 0.7, Models.mat("rust"), Vector3(0, 0.3, 0), Vector3.ZERO, 10)
		Models.add(head, Models._torus_mesh(0.3, 0.42, 16, 6), Models.mat("brass"), Vector3(0, 0.72, 0))
		Models.cyl(head, 0.1, 0.1, 0.9, Models.mat("rust"), Vector3(0.45, 0.25, 0), Vector3(0, 0, 90), 8)


func _is_clear(p: Vector2, margin: float) -> bool:
	for b in BASES:
		if p.distance_to(b) < 36.0 + margin:
			return false
	for w in well_points:
		if p.distance_to(w) < 6.0 + margin:
			return false
	return _road_dist(p) >= 4.5 + margin


func _inside(p: Vector2) -> bool:
	return absf(p.x) < Game.MAP_HALF and absf(p.y) < Game.MAP_HALF


func _setup_props() -> void:
	_scatter_rocks()
	_scatter_grass()
	_place_trees()
	_place_tank_traps()
	_place_ruins()
	_place_telegraph_poles()
	_place_background_industry()


func _scatter_rocks() -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 1.5
	sm.radial_segments = 7
	sm.rings = 4
	var xforms: Array = []
	var tries := 0
	while xforms.size() < 240 and tries < 4000:
		tries += 1
		var p := Vector2(rng.randf_range(-168, 168), rng.randf_range(-168, 168))
		var inside := _inside(p)
		if inside and not _is_clear(p, 2.0):
			continue
		var s := rng.randf_range(0.4, 1.3)
		if not inside:
			s *= 2.0
		elif rng.randf() < 0.15:
			s *= 2.0
		var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
		basis = basis.scaled(Vector3(s * rng.randf_range(0.8, 1.5), s * rng.randf_range(0.5, 0.9), s * rng.randf_range(0.8, 1.4)))
		var h := height_at(p.x, p.y)
		xforms.append(Transform3D(basis, Vector3(p.x, h - s * 0.15, p.y)))
		if inside and s > 1.0:
			Game.add_obstacle(Vector3(p.x, h, p.y), s * 1.1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = sm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Models.mat("rock")
	add_child(mmi)


func _scatter_grass() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.09
	cm.height = 0.9
	cm.radial_segments = 3
	cm.rings = 0
	var xforms: Array = []
	var colors: Array = []
	var tries := 0
	while xforms.size() < 9000 and tries < 3000:
		tries += 1
		var c := Vector2(rng.randf_range(-140, 140), rng.randf_range(-140, 140))
		if _road_dist(c) < 3.5 or c.distance_to(BASES[0]) < 22.0 or c.distance_to(BASES[1]) < 22.0:
			continue
		var tint := Color(0.40, 0.38, 0.19).lerp(Color(0.56, 0.47, 0.27), rng.randf())
		for k in 12:
			var p := c + Vector2(rng.randf_range(-0.9, 0.9), rng.randf_range(-0.9, 0.9))
			var s := rng.randf_range(0.5, 1.4)
			var basis := Basis.from_euler(Vector3(rng.randf_range(-0.4, 0.4), rng.randf() * TAU, rng.randf_range(-0.4, 0.4)))
			xforms.append(Transform3D(basis.scaled(Vector3(s, s, s)), Vector3(p.x, height_at(p.x, p.y) + 0.35 * s, p.y)))
			colors.append(tint.darkened(rng.randf_range(0.0, 0.25)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = cm
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
		mm.set_instance_color(i, colors[i])
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _place_trees() -> void:
	var placed := 0
	var tries := 0
	var wood := Models.mat("charwood")
	while placed < 60 and tries < 3000:
		tries += 1
		var p := Vector2(rng.randf_range(-155, 155), rng.randf_range(-155, 155))
		var inside := _inside(p)
		if inside and not _is_clear(p, 4.0):
			continue
		var tree := Node3D.new()
		tree.position = Vector3(p.x, height_at(p.x, p.y) - 0.2, p.y)
		tree.rotation.y = rng.randf() * TAU
		add_child(tree)
		var hgt := rng.randf_range(3.5, 7.0)
		Models.cyl(tree, 0.08, 0.28, hgt, wood, Vector3(0, hgt * 0.5, 0), Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)), 7)
		for b in rng.randi_range(2, 4):
			var bl := rng.randf_range(1.2, 2.6)
			var br := Node3D.new()
			br.position = Vector3(0, hgt * rng.randf_range(0.45, 0.85), 0)
			br.rotation = Vector3(0, rng.randf() * TAU, deg_to_rad(rng.randf_range(35, 65)))
			tree.add_child(br)
			Models.cyl(br, 0.02, 0.08, bl, wood, Vector3(0, bl * 0.5, 0), Vector3.ZERO, 5)
		if inside:
			Game.add_obstacle(tree.position, 0.8)
		placed += 1


func _hedgehog(p: Vector2) -> void:
	var h := Node3D.new()
	h.position = Vector3(p.x, height_at(p.x, p.y) + 0.55, p.y)
	h.rotation.y = rng.randf() * TAU
	add_child(h)
	for i in 3:
		var piv := Models.node(h, "B%d" % i, Vector3.ZERO, Vector3(0, i * 120.0, 0))
		Models.box(piv, Vector3(0.16, 0.16, 2.0), Models.mat("rust"), Vector3.ZERO, Vector3(50, 0, 0))
	Game.add_obstacle(h.position, 1.0)


func _place_tank_traps() -> void:
	var lines := [[Vector2(-64, -6), Vector2(-14, 44)], [Vector2(-34, -10), Vector2(-6, 18)]]
	for line in lines:
		for sgn in [1.0, -1.0]:
			var a: Vector2 = line[0] * sgn
			var b: Vector2 = line[1] * sgn
			var count := int(a.distance_to(b) / 3.4)
			for i in count:
				var p := a.lerp(b, float(i) / float(count)) + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(-0.6, 0.6))
				if _is_clear(p, 1.5) and rng.randf() > 0.15:
					_hedgehog(p)


func _place_ruins() -> void:
	var sites := [Vector2(-26, -46), Vector2(-98, -18), Vector2(-70, 20)]
	for base_p in sites:
		for sgn in [1.0, -1.0]:
			var c: Vector2 = base_p * sgn
			if not _is_clear(c, 6.0):
				continue
			var ruin := Node3D.new()
			ruin.position = Vector3(c.x, height_at(c.x, c.y) - 0.3, c.y)
			ruin.rotation.y = rng.randf() * TAU
			add_child(ruin)
			var walls := [[Vector3(0, 0, -3), 0.0, 8.0], [Vector3(0, 0, 3), 0.0, 8.0], [Vector3(-4, 0, 0), 90.0, 6.0], [Vector3(4, 0, 0), 90.0, 6.0]]
			for w in walls:
				var length: float = w[2]
				var segs := int(length / 2.0)
				for k in segs:
					if rng.randf() < 0.3:
						continue
					var hgt := rng.randf_range(0.8, 3.4)
					var along := -length * 0.5 + (k + 0.5) * 2.0
					var wp: Vector3 = w[0]
					var off := Vector3(along, 0, 0) if w[1] == 0.0 else Vector3(0, 0, along)
					var seg := Models.box(ruin, Vector3(2.0, hgt, 0.5), Models.mat("brick"), wp + off + Vector3(0, hgt * 0.5, 0), Vector3(0, w[1], 0))
					Game.add_obstacle(seg.global_position, 1.3)
			for k in 3:
				Models.box(ruin, Vector3(0.2, 0.2, rng.randf_range(2.0, 5.0)), Models.mat("charwood"),
					Vector3(rng.randf_range(-3, 3), 0.6, rng.randf_range(-2, 2)), Vector3(rng.randf_range(-20, 20), rng.randf() * 180.0, 0))


func _place_telegraph_poles() -> void:
	var tops: Array = []
	var spacing := 15.0
	var acc := 0.0
	for i in ROAD.size() - 1:
		var a: Vector2 = ROAD[i]
		var b: Vector2 = ROAD[i + 1]
		var seg_len := a.distance_to(b)
		var dir := (b - a) / seg_len
		var side := Vector2(-dir.y, dir.x) * 6.0
		while acc < seg_len:
			var p: Vector2 = a + dir * acc + side
			if p.distance_to(BASES[0]) > 20.0 and p.distance_to(BASES[1]) > 20.0:
				var g := height_at(p.x, p.y)
				var pole := Node3D.new()
				pole.position = Vector3(p.x, g, p.y)
				pole.rotation.y = atan2(-dir.x, -dir.y)
				add_child(pole)
				Models.cyl(pole, 0.12, 0.16, 7.0, Models.mat("wood"), Vector3(0, 3.5, 0), Vector3.ZERO, 8)
				Models.box(pole, Vector3(1.8, 0.14, 0.14), Models.mat("wood"), Vector3(0, 6.6, 0), Vector3(0, 90, 0))
				for s in [-0.75, 0.75]:
					Models.cyl(pole, 0.05, 0.06, 0.18, Models.mat("brass"), Vector3(0, 6.78, s), Vector3.ZERO, 6)
				Game.add_obstacle(pole.position, 0.4)
				tops.append(pole)
			acc += spacing
		acc -= seg_len
	var wire_mat := Models.mat("darksteel")
	for i in tops.size() - 1:
		var pa: Node3D = tops[i]
		var pb: Node3D = tops[i + 1]
		if pa.position.distance_to(pb.position) > spacing * 1.6:
			continue
		for s in [-0.75, 0.75]:
			var a3: Vector3 = pa.to_global(Vector3(0, 6.85, s))
			var b3: Vector3 = pb.to_global(Vector3(0, 6.85, s))
			var mid := (a3 + b3) * 0.5 - Vector3(0, 0.5, 0)
			for seg in [[a3, mid], [mid, b3]]:
				var s0: Vector3 = seg[0]
				var s1: Vector3 = seg[1]
				var holder := Node3D.new()
				add_child(holder)
				holder.position = (s0 + s1) * 0.5
				holder.look_at(s1, Vector3.UP)
				var w := Models.cyl(holder, 0.025, 0.025, s0.distance_to(s1), wire_mat, Vector3.ZERO, Vector3(90, 0, 0), 4)
				w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _place_background_industry() -> void:
	for i in 12:
		var ang := i * TAU / 12.0 + rng.randf_range(-0.15, 0.15)
		var r := rng.randf_range(150.0, 165.0)
		var p := Vector2(cos(ang) * r, sin(ang) * r)
		var site := Node3D.new()
		site.position = Vector3(p.x, height_at(p.x, p.y), p.y)
		site.rotation.y = rng.randf() * TAU
		add_child(site)
		var block := Vector3(rng.randf_range(14, 26), rng.randf_range(8, 16), rng.randf_range(10, 18))
		Models.box(site, block, Models.mat("darkconcrete"), Vector3(0, block.y * 0.5 - 1.0, 0))
		Models.box(site, Vector3(block.x * 0.9, 0.6, 0.1), Models.mat("window"), Vector3(0, block.y * 0.55, -block.z * 0.5 - 0.06))
		for k in rng.randi_range(1, 3):
			var ch := rng.randf_range(22.0, 36.0)
			var cp := Vector3(rng.randf_range(-6, 6), ch * 0.5, rng.randf_range(-4, 4))
			Models.cyl(site, 1.0, 1.5, ch, Models.mat("brick"), cp, Vector3.ZERO, 12)
			Models.sphere(site, 0.35, Models.mat("red"), cp + Vector3(0, ch * 0.5 + 0.4, 0), Vector3.ONE, 8)
			FX.smoke_emitter(site, cp + Vector3(0, ch * 0.5 + 0.6, 0), 3.2, true, 0.9)


# ================================================================ spawning & combat

func spawn_unit(kind: String, team: int, pos: Vector3, yaw: float = 0.0):
	var u := UnitScript.new()
	u.kind = kind
	u.team = team
	u.heading = yaw
	pos.y = height_at(pos.x, pos.z)
	u.position = pos
	entities_root.add_child(u)
	return u


func spawn_building(kind: String, team: int, pos: Vector3, complete: bool = false):
	var b := BuildingScript.new()
	b.kind = kind
	b.team = team
	b.complete = complete
	pos.y = height_at(pos.x, pos.z)
	b.position = pos
	entities_root.add_child(b)
	return b


func _spawn_start() -> void:
	for t in 2:
		var b: Vector2 = BASES[t]
		var hq = spawn_building("hq", t, Vector3(b.x, 0, b.y), true)
		var hp: Vector3 = hq.position
		var out := Vector3(-b.x, 0, -b.y).normalized()
		var side := Vector3(out.z, 0, -out.x)
		var yaw := Game.facing_yaw(hp)
		spawn_unit("constructor", t, hp + out * 9.5 + side * 4.0, yaw)
		spawn_unit("trooper", t, hp + out * 11.0 - side * 3.5, yaw)
		spawn_unit("trooper", t, hp + out * 13.5 - side * 0.5, yaw)
		spawn_unit("tank", t, hp + out * 13.0 + side * 6.0, yaw)


func fire_weapon(shooter, tgt) -> void:
	var d: Dictionary = shooter.def
	var w: String = d["weapon"]
	var dmg: float = d["damage"]
	var splash: float = d.get("splash", 0.0)
	var tp: Vector3 = tgt.position
	var aim: Vector3 = tp + Vector3(0, tgt.aim_height(), 0)
	match w:
		"rifle":
			var origins: Array = shooter.squad_muzzles() if shooter.has_method("squad_muzzles") else [shooter.muzzle_pos()]
			for o in origins:
				var jit := Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.4), randf_range(-0.4, 0.4))
				_launch(shooter, tgt, w, o, aim + jit, dmg / origins.size(), 0.0, 95.0, 0.0, true)
				FX.muzzle(o, 0.3)
		"cannon":
			var from: Vector3 = shooter.muzzle_pos()
			FX.muzzle(from, 1.0)
			_launch(shooter, tgt, w, from, aim, dmg, 0.0, 80.0, 0.0, true)
		"flak":
			var from: Vector3 = shooter.muzzle_pos()
			FX.muzzle(from, 0.8)
			var jit := Vector3(randf_range(-1.2, 1.2), randf_range(-0.8, 0.8), randf_range(-1.2, 1.2))
			_launch(shooter, tgt, w, from, aim + jit, dmg, splash, 90.0, 0.0, true)
		"artillery":
			var from: Vector3 = shooter.muzzle_pos()
			FX.muzzle(from, 1.7)
			var dest := tp + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
			dest.y = height_at(dest.x, dest.z)
			var dist := from.distance_to(dest)
			var p = _launch(shooter, null, w, from, dest, dmg, splash, 1.0, dist * 0.32, false)
			p.duration = clampf(dist / 20.0, 1.0, 2.4)
		"bombs":
			var from: Vector3 = shooter.muzzle_pos()
			for i in 3:
				var dest := tp + Vector3(randf_range(-1.8, 1.8), 0.0, randf_range(-1.8, 1.8))
				dest.y = height_at(dest.x, dest.z)
				var p = _launch(shooter, null, w, from + Vector3(0, -0.2 * i, 0), dest, dmg / 3.0, splash, 1.0, 0.0, false)
				p.duration = 1.1 + i * 0.2


func _launch(shooter, tgt, weapon: String, from: Vector3, to: Vector3, dmg: float, splash: float,
		spd: float, arc: float, homing: bool):
	var p := ProjectileScript.new()
	p.weapon = weapon
	p.team = shooter.team
	p.shooter = shooter
	p.target = tgt
	p.start = from
	p.target_pos = to
	if tgt != null:
		var tpos: Vector3 = tgt.position
		p.aim_offset = to - tpos
	p.damage = dmg
	p.splash = splash
	p.arc = arc
	p.homing = homing
	p.duration = maxf(from.distance_to(to) / spd, 0.05)
	fx_root.add_child(p)
	return p


# ================================================================ debug / capture

func _parse_args() -> void:
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--shot="):
			_shot_path = a.substr(7)
			if _shot_t <= 0.0:
				_shot_t = 4.0
		elif a.begins_with("--shotdelay="):
			_shot_t = float(a.substr(12))
		elif a == "--demo":
			_setup_demo()
		elif a == "--gallery":
			_setup_gallery()
		elif a == "--aivsai":
			var bot := EnemyAI.new()
			bot.team = Game.PLAYER
			add_child(bot)
		elif a.begins_with("--select="):
			var want := a.substr(9)
			for e in Game.entities:
				if e.team == Game.PLAYER and e.kind == want:
					controller._set_selection([e])
					break
		elif a == "--report":
			_report = true
		elif a.begins_with("--cam="):
			var v := a.substr(6).split(",")
			camera_rig.focus(Vector3(float(v[0]), 0, float(v[1])), true)
			if v.size() > 2:
				camera_rig.target_zoom = float(v[2])
				camera_rig.zoom = float(v[2])


## Spawns one of everything around the player's HQ for screenshots.
func _setup_gallery() -> void:
	var spots := {"barracks": Vector3(-92, 0, 64), "factory": Vector3(-64, 0, 90), "dock": Vector3(-98, 0, 92),
		"flak": Vector3(-66, 0, 70)}
	for k in spots:
		var p: Vector3 = spots[k]
		spawn_building(k, 0, p, true)
	var w = Game.free_well_near(Vector3(-60, 0, 58), 3.0)
	if w != null:
		var d = spawn_building("derrick", 0, w["pos"], true)
		w["owner"] = d
		d.well = w
	var kinds := ["tank", "howitzer", "trooper", "constructor", "tank", "trooper"]
	for i in kinds.size():
		spawn_unit(kinds[i], 0, Vector3(-74 + i * 4.5, 0, 66 - (i % 2) * 4.0), Game.facing_yaw(Vector3(-78, 0, 78)))
	spawn_unit("zeppelin", 0, Vector3(-70, 0, 76), deg_to_rad(-60))


## Spawns two armies in the middle of the map for a quick look at combat.
func _setup_demo() -> void:
	var p_kinds := ["tank", "tank", "tank", "trooper", "trooper", "howitzer", "zeppelin"]
	var e_kinds := ["tank", "tank", "trooper", "trooper", "trooper", "howitzer", "zeppelin"]
	for i in p_kinds.size():
		var u = spawn_unit(p_kinds[i], 0, Vector3(-22 + (i % 4) * 5.0, 0, 22 + int(i / 4) * 6.0), Game.facing_yaw(Vector3(-20, 0, 20)))
		u.cmd_attack_move(Vector3(20, 0, -20))
	for i in e_kinds.size():
		var u = spawn_unit(e_kinds[i], 1, Vector3(22 - (i % 4) * 5.0, 0, -22 - int(i / 4) * 6.0), Game.facing_yaw(Vector3(20, 0, -20)))
		u.cmd_attack_move(Vector3(-20, 0, 20))
	camera_rig.focus(Vector3(0, 0, 0), true)


func _process(delta: float) -> void:
	if _report:
		_report_t -= delta
		if _report_t <= 0.0:
			_report_t = 15.0
			var parts := []
			for t in 2:
				var b := {}
				for e in Game.entities:
					if e.team == t:
						b[e.kind] = int(b.get(e.kind, 0)) + 1
				parts.append("T%d fuel=%d %s" % [t, int(Game.fuel[t]), str(b)])
			print("[%5.0fs] %s" % [Game.elapsed, " | ".join(parts)])
			if Game.game_over:
				print("GAME OVER winner=%d" % Game.winner)
				get_tree().quit()
	if _shot_path != "":
		_shot_t -= delta
		if _shot_t <= 0.0:
			var img := get_viewport().get_texture().get_image()
			if img:
				img.save_png(_shot_path)
			_shot_path = ""
			get_tree().quit()
