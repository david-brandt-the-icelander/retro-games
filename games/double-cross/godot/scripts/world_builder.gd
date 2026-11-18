extends RefCounted
class_name WorldBuilder
## Turns a generated layout into lit, collidable 3D geometry built from primitives.

const WALL_H := 2.6
const WALL_T := 0.3

var layout: Dictionary
var theme: Dictionary
var root: Node3D
var room_lights: Array = []        # OmniLight3D per room
var furniture_nodes: Array = []    # Node3D per furniture entry
var door_nodes: Array = []         # Node3D per door
var exit_node: Node3D
var _mats := {}


func build(p_layout: Dictionary, parent: Node3D) -> void:
	layout = p_layout
	theme = layout.theme
	root = Node3D.new()
	root.name = "World"
	parent.add_child(root)
	_environment()
	for i in layout.rooms.size():
		_room(i)
	_walls()
	for i in layout.furniture.size():
		furniture_nodes.append(_furniture(layout.furniture[i]))
	for d in layout.doors:
		door_nodes.append(_door_marker(d))
	if not layout.exit.is_empty():
		_exit()


# ------------------------------------------------------------------ materials

func mat(key: String, color: Color, rough := 0.6, metal := 0.0, emission := Color.BLACK, emit_energy := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emit_energy
	_mats[key] = m
	return m


func _noise_tex(freq: float, normal := false, seamless := true) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.frequency = freq
	n.fractal_octaves = 4
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = seamless
	t.as_normal_map = normal
	if normal:
		t.bump_strength = 4.0
	return t


func _floor_mat() -> StandardMaterial3D:
	if _mats.has("floor"):
		return _mats.floor
	var m := StandardMaterial3D.new()
	m.albedo_color = theme.floor
	m.roughness = maxf(0.3, theme.floor_rough)
	m.metallic = theme.get("floor_metal", 0.0)
	var tex := _noise_tex(0.02 if theme.floor_grain else 0.008)
	var grad := Gradient.new()
	grad.set_color(0, Color(0.78, 0.78, 0.78))
	grad.set_color(1, Color(1.1, 1.1, 1.1))
	tex.color_ramp = grad
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = _noise_tex(0.05, true)
	m.normal_scale = 0.12
	m.uv1_scale = Vector3(1.5, 12.0, 1.0) if theme.floor_grain else Vector3(2, 2, 1)
	_mats.floor = m
	return m


func _environment() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme.ambient
	env.ambient_light_energy = 0.3
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 2.0
		env.ssil_enabled = true
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.08
	env.glow_hdr_threshold = 1.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 1.1
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 35, 0)
	sun.light_energy = 0.08
	sun.light_color = theme.light
	sun.shadow_enabled = true
	root.add_child(sun)

	# Dark ground plane surrounding the building
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	ground.position = Vector3(20, -0.05, 20)
	ground.material_override = mat("void", Color(0.04, 0.045, 0.06), 1.0)
	root.add_child(ground)


# ------------------------------------------------------------------ rooms

func _room(i: int) -> void:
	var r: Dictionary = layout.rooms[i]
	var s := Maps.ROOM_SIZE
	var floor_mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(s, 0.1, s)
	floor_mi.mesh = bm
	floor_mi.position = r.center + Vector3(0, -0.05, 0)
	floor_mi.material_override = _floor_mat()
	root.add_child(floor_mi)
	_static_box(r.center + Vector3(0, -0.25, 0), Vector3(s, 0.5, s))

	# Rug for a little variety
	if i % 2 == 0:
		var rug := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(3.6, 0.02, 2.4)
		rug.mesh = rm
		rug.position = r.center + Vector3(0, 0.01, 0)
		rug.material_override = mat("rug", theme.fabric.darkened(0.25), 0.95)
		root.add_child(rug)

	var light := OmniLight3D.new()
	light.position = r.center + Vector3(0.6, WALL_H + 1.6, -0.8)
	light.light_size = 0.6
	light.light_specular = 0.35
	light.light_color = theme.light
	light.light_energy = theme.light_energy
	light.omni_range = 7.8
	light.omni_attenuation = 0.8
	light.shadow_enabled = false  # only the room you're in casts shadows (game.gd)
	light.shadow_bias = 0.05
	root.add_child(light)
	room_lights.append(light)



func _walls() -> void:
	var door_lookup := {}
	for d in layout.doors:
		door_lookup[_k(d.pos)] = true
	var s := Maps.ROOM_SIZE
	var half := s * 0.5
	for i in layout.rooms.size():
		var r: Dictionary = layout.rooms[i]
		var c: Vector2i = r.cell
		# Each room owns its south + east walls; north/west only on the outside.
		var sides := [[Vector2i(0, 1), true], [Vector2i(1, 0), true],
			[Vector2i(0, -1), not layout.cell_to_room.has(c + Vector2i(0, -1))],
			[Vector2i(-1, 0), not layout.cell_to_room.has(c + Vector2i(-1, 0))]]
		for side in sides:
			if not side[1]:
				continue
			var d: Vector2i = side[0]
			var mid: Vector3 = r.center + Vector3(d.x, 0, d.y) * half
			var along_x := d.y != 0  # wall runs along X when it faces N/S
			var gap := 0.0
			if door_lookup.has(_k(mid)):
				gap = Maps.DOOR_WIDTH
			if not layout.exit.is_empty() and layout.exit.room == i and Vector3(d.x, 0, d.y).is_equal_approx(layout.exit.normal):
				gap = Maps.DOOR_WIDTH + 0.4
			_wall_segment(mid, along_x, s + WALL_T, gap)


func _wall_segment(mid: Vector3, along_x: bool, length: float, gap: float) -> void:
	var wall_mat := mat("wall", theme.wall, 0.75)
	var trim_mat := mat("trim", theme.trim, 0.4, 0.3)
	var pieces := []
	if gap <= 0.0:
		pieces.append([0.0, length])
	else:
		var seg := (length - gap) * 0.5
		pieces.append([-(gap + seg) * 0.5, seg])
		pieces.append([(gap + seg) * 0.5, seg])
	for p in pieces:
		var offset: float = p[0]
		var l: float = p[1]
		var pos := mid + (Vector3(offset, 0, 0) if along_x else Vector3(0, 0, offset))
		var size := Vector3(l, WALL_H, WALL_T) if along_x else Vector3(WALL_T, WALL_H, l)
		_mesh_box(pos + Vector3(0, WALL_H * 0.5, 0), size, wall_mat)
		# Trim cap + skirting
		var cap := Vector3(size.x + 0.04, 0.08, size.z + 0.04)
		_mesh_box(pos + Vector3(0, WALL_H + 0.04, 0), cap, trim_mat)
		_mesh_box(pos + Vector3(0, 0.08, 0), Vector3(size.x + 0.06, 0.16, size.z + 0.06), trim_mat)
		_static_box(pos + Vector3(0, WALL_H * 0.5, 0), size)


func _k(v: Vector3) -> String:
	return "%d,%d" % [roundi(v.x * 2), roundi(v.z * 2)]


# ------------------------------------------------------------------ helpers

func _mesh_box(pos: Vector3, size: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	(parent if parent else root).add_child(mi)
	return mi


func _mesh(mesh: Mesh, pos: Vector3, m: Material, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _static_box(pos: Vector3, size: Vector3, parent: Node3D = null) -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.position = pos
	(parent if parent else root).add_child(body)


func _cyl(r_top: float, r_bot: float, h: float, segs := 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	return c


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


# ------------------------------------------------------------------ furniture

func _furniture(f: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = f.pos
	n.rotation.y = f.rot
	root.add_child(n)
	var wood := mat("wood", theme.wood, 0.5)
	var wood_dark := mat("wood_dark", theme.wood.darkened(0.35), 0.55)
	var fabric := mat("fabric", theme.fabric, 0.9)
	var metal := mat("metal", Color(0.55, 0.58, 0.62), 0.3, 0.85)
	var dark_metal := mat("dmetal", Color(0.18, 0.2, 0.23), 0.35, 0.8)
	var brass := mat("brass", theme.trim, 0.3, 0.9)
	var footprint := Vector3(1.6, 1.0, 0.8)
	match f.type:
		"desk":
			_mesh_box(Vector3(0, 0.76, 0), Vector3(1.7, 0.08, 0.85), wood, n)
			for sx in [-0.75, 0.75]:
				_mesh_box(Vector3(sx, 0.36, 0), Vector3(0.12, 0.72, 0.75), wood_dark, n)
			_mesh_box(Vector3(0.45, 0.55, 0.0), Vector3(0.6, 0.35, 0.7), wood_dark, n)
			_mesh_box(Vector3(-0.3, 0.92, -0.15), Vector3(0.55, 0.32, 0.04), dark_metal, n)  # monitor
			_mesh_box(Vector3(-0.3, 0.92, -0.125), Vector3(0.5, 0.27, 0.01),
				mat("screen", Color(0.2, 0.6, 0.9), 0.2, 0.0, Color(0.2, 0.6, 1.0), 1.6), n)
			_mesh_box(Vector3(0.4, 0.82, 0.1), Vector3(0.3, 0.04, 0.22), mat("paper", Color(0.92, 0.9, 0.84), 0.9), n)
			footprint = Vector3(1.7, 0.9, 0.85)
		"bookshelf":
			_mesh_box(Vector3(0, 1.05, 0), Vector3(1.6, 2.1, 0.45), wood_dark, n)
			var colors := [Color(0.6, 0.15, 0.12), Color(0.15, 0.3, 0.5), Color(0.75, 0.6, 0.3), Color(0.2, 0.4, 0.25)]
			for row in 4:
				_mesh_box(Vector3(0, 0.3 + row * 0.48, 0.05), Vector3(1.5, 0.04, 0.4), wood, n)
				var x := -0.68
				var k := row
				while x < 0.62:
					var w := 0.06 + float((k * 7) % 5) * 0.02
					var h := 0.28 + float((k * 3) % 4) * 0.03
					_mesh_box(Vector3(x + w * 0.5, 0.32 + row * 0.48 + h * 0.5, 0.08), Vector3(w, h, 0.28),
						mat("book%d" % (k % 4), colors[k % 4], 0.8), n)
					x += w + 0.015
					k += 1
			footprint = Vector3(1.6, 2.1, 0.45)
		"sofa":
			_mesh_box(Vector3(0, 0.25, 0.05), Vector3(1.9, 0.4, 0.85), fabric, n)
			_mesh_box(Vector3(0, 0.62, -0.32), Vector3(1.9, 0.6, 0.22), fabric, n)
			for sx in [-0.88, 0.88]:
				_mesh_box(Vector3(sx, 0.5, 0.05), Vector3(0.2, 0.35, 0.85), fabric, n)
			for sx in [-0.45, 0.45]:
				_mesh_box(Vector3(sx, 0.5, 0.08), Vector3(0.82, 0.12, 0.65), mat("cushion", theme.fabric.lightened(0.12), 0.95), n)
			footprint = Vector3(1.9, 0.9, 0.9)
		"cabinet":
			_mesh_box(Vector3(0, 0.65, 0), Vector3(0.9, 1.3, 0.6), metal, n)
			for row in 3:
				_mesh_box(Vector3(0, 0.25 + row * 0.42, 0.31), Vector3(0.8, 0.36, 0.02), mat("cab_front", Color(0.45, 0.48, 0.52), 0.35, 0.7), n)
				_mesh_box(Vector3(0, 0.33 + row * 0.42, 0.33), Vector3(0.25, 0.04, 0.03), brass, n)
			footprint = Vector3(0.9, 1.3, 0.6)
		"dresser":
			_mesh_box(Vector3(0, 0.5, 0), Vector3(1.4, 1.0, 0.55), wood, n)
			for row in 3:
				for sx in [-0.34, 0.34]:
					_mesh_box(Vector3(sx, 0.2 + row * 0.3, 0.28), Vector3(0.62, 0.24, 0.02), wood_dark, n)
					_mesh_box(Vector3(sx, 0.2 + row * 0.3, 0.3), Vector3(0.1, 0.04, 0.03), brass, n)
			_mesh(_cyl(0.06, 0.12, 0.35), Vector3(0.45, 1.18, 0), brass, n)
			_mesh(_cyl(0.18, 0.22, 0.2), Vector3(0.45, 1.45, 0),
				mat("shade", Color(1, 0.92, 0.75), 0.6, 0.0, theme.light, 1.2), n)
			footprint = Vector3(1.4, 1.0, 0.55)
		"safe":
			_mesh_box(Vector3(0, 0.5, 0), Vector3(0.9, 1.0, 0.8), dark_metal, n)
			var dial := _mesh(_cyl(0.12, 0.12, 0.05), Vector3(0.15, 0.55, 0.42), brass, n)
			dial.rotation.x = PI * 0.5
			_mesh_box(Vector3(-0.2, 0.55, 0.42), Vector3(0.06, 0.35, 0.04), metal, n)
			footprint = Vector3(0.9, 1.0, 0.8)
		"plant":
			_mesh(_cyl(0.3, 0.22, 0.5), Vector3(0, 0.25, 0), mat("pot", Color(0.75, 0.42, 0.3), 0.8), n)
			var leaf := mat("leaf", Color(0.15, 0.45, 0.18), 0.7)
			for i in 6:
				var s := SphereMesh.new()
				s.radius = 0.32 - i * 0.025
				s.height = s.radius * 2.0
				var a := i * 1.3
				_mesh(s, Vector3(cos(a) * 0.15, 0.75 + i * 0.12, sin(a) * 0.15), leaf, n)
			footprint = Vector3(0.6, 1.2, 0.6)
		"table":
			_mesh(_cyl(0.85, 0.85, 0.06, 40), Vector3(0, 0.75, 0), wood, n)
			_mesh(_cyl(0.08, 0.08, 0.72), Vector3(0, 0.36, 0), wood_dark, n)
			_mesh(_cyl(0.4, 0.45, 0.05), Vector3(0, 0.025, 0), wood_dark, n)
			_mesh(_cyl(0.06, 0.08, 0.14), Vector3(0.25, 0.85, 0.1),
				mat("vase", Color(0.9, 0.9, 0.95), 0.1, 0.0), n)
			footprint = Vector3(1.6, 0.8, 1.6)
		"luggage":
			_mesh_box(Vector3(-0.3, 0.38, 0), Vector3(0.55, 0.76, 0.3), mat("lug1", Color(0.55, 0.3, 0.15), 0.6), n)
			_mesh_box(Vector3(0.35, 0.3, 0.05), Vector3(0.6, 0.6, 0.35), mat("lug2", Color(0.15, 0.2, 0.3), 0.5), n)
			_mesh_box(Vector3(-0.3, 0.82, 0), Vector3(0.2, 0.1, 0.04), brass, n)
			footprint = Vector3(1.3, 0.8, 0.5)
		"locker":
			for sx in [-0.42, 0.0, 0.42]:
				_mesh_box(Vector3(sx, 1.0, 0), Vector3(0.4, 2.0, 0.55), mat("locker", Color(0.3, 0.42, 0.55), 0.4, 0.7), n)
				for v in 3:
					_mesh_box(Vector3(sx, 1.7 - v * 0.06, 0.28), Vector3(0.25, 0.02, 0.01), dark_metal, n)
			footprint = Vector3(1.3, 2.0, 0.55)
		"crate":
			_mesh_box(Vector3(-0.35, 0.4, 0), Vector3(0.8, 0.8, 0.8), mat("crate", Color(0.55, 0.42, 0.25), 0.85), n)
			_mesh_box(Vector3(0.45, 0.3, 0.05), Vector3(0.6, 0.6, 0.6), mat("crate2", Color(0.2, 0.35, 0.25), 0.6, 0.3), n)
			_mesh_box(Vector3(-0.3, 0.95, 0.0), Vector3(0.55, 0.3, 0.55), mat("crate", Color(0.55, 0.42, 0.25), 0.85), n)
			footprint = Vector3(1.6, 1.1, 0.8)
		"server":
			_mesh_box(Vector3(0, 1.0, 0), Vector3(0.9, 2.0, 0.8), dark_metal, n)
			for v in 8:
				var led := Color(0.2, 1.0, 0.5) if v % 3 else Color(1.0, 0.5, 0.1)
				_mesh_box(Vector3(-0.25, 0.3 + v * 0.22, 0.41), Vector3(0.05, 0.03, 0.01),
					mat("led%d" % (v % 3), led, 0.2, 0.0, led, 4.0), n)
				_mesh_box(Vector3(0.1, 0.3 + v * 0.22, 0.405), Vector3(0.5, 0.12, 0.01), metal, n)
			footprint = Vector3(0.9, 2.0, 0.8)
	_static_box(Vector3(0, footprint.y * 0.5, 0), footprint, n)
	n.set_meta("footprint", footprint)
	return n


func _door_marker(d: Dictionary) -> Node3D:
	var n := Node3D.new()
	n.position = d.pos
	root.add_child(n)
	# Threshold strip
	var size := Vector3(WALL_T + 0.3, 0.03, Maps.DOOR_WIDTH) if d.axis == "x" else Vector3(Maps.DOOR_WIDTH, 0.03, WALL_T + 0.3)
	_mesh_box(Vector3(0, 0.015, 0), size, mat("threshold", theme.trim.darkened(0.2), 0.4, 0.6), n)
	return n


func _exit() -> void:
	var e: Dictionary = layout.exit
	exit_node = Node3D.new()
	root.add_child(exit_node)
	exit_node.look_at_from_position(e.pos, e.pos - e.normal, Vector3.UP)
	var glow := mat("exitglow", Color(0.2, 1.0, 0.5), 0.2, 0.0, Color(0.2, 1.0, 0.55), 3.0)
	var w := Maps.DOOR_WIDTH + 0.4
	for sx in [-w * 0.5, w * 0.5]:
		_mesh_box(Vector3(sx, WALL_H * 0.5, 0), Vector3(0.12, WALL_H, 0.4), glow, exit_node)
	_mesh_box(Vector3(0, WALL_H, 0), Vector3(w + 0.12, 0.12, 0.4), glow, exit_node)
	var field := StandardMaterial3D.new()
	field.albedo_color = Color(0.2, 1.0, 0.5, 0.18)
	field.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	field.emission_enabled = true
	field.emission = Color(0.2, 1.0, 0.5)
	field.emission_energy_multiplier = 0.6
	field.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	field.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mesh_box(Vector3(0, WALL_H * 0.5, 0), Vector3(w, WALL_H, 0.04), field, exit_node)
	_static_box(Vector3(0, WALL_H * 0.5, 0), Vector3(w, WALL_H, 0.3), exit_node)
	var lbl := Label3D.new()
	lbl.text = "EXTRACTION"
	lbl.font_size = 72
	lbl.outline_size = 12
	lbl.modulate = Color(0.4, 1.0, 0.6)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, WALL_H + 0.6, 0)
	exit_node.add_child(lbl)
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 1.0, 0.55)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.position = Vector3(0, 1.2, 0.8)
	exit_node.add_child(light)
