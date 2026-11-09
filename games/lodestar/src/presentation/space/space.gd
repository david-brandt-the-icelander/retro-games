extends Node3D
## The 3D picture: the player's ship at the origin under the orbit camera, and every object of
## the sim's bubble drawn where the sim puts it, interpolated between ticks (docs/DESIGN.md
## § Architecture). Plain looks: every ship is a Cheetah stand-in scaled and tinted by role, the
## station a drum and ring, the planet and the sun spheres drawn as scaled impostors, lasers as
## glowing beams and explosions as fading spheres. Docked, the ship sits on a pad in a dim hangar;
## on the title it turns slowly in front of the star.
##
## The game scene calls `setup(sim)` once; everything else happens each frame from the sim's
## snapshots. Nothing here writes to the sim.

const SHIP_SCENE := preload("res://assets/ships/acnx7_cheetah/acnx7_cheetah.glb")
const SHIP_SCRIPT := preload("res://src/presentation/ships/ship.gd")
const STARFIELD := preload("res://src/presentation/space/starfield.gdshader")
const EXHAUST := preload("res://src/presentation/space/exhaust.gdshader")
const OrbitCamera := preload("res://src/presentation/space/orbit_camera.gd")

## The Cheetah model's length in metres; stand-ins are scaled from it.
const CHEETAH_LENGTH := 59.0
## Stand-in lengths in metres by type, about three times the GDD § 5.5 hit radius.
const SHIP_LENGTHS := {1: 30.0, 2: 38.0, 3: 36.0, 4: 58.0, 5: 49.0, 6: 62.0, 7: 49.0, 12: 22.0}
## The player's hull (type 7, the Grey Wolf hauler, until its model exists).
const PLAYER_LENGTH := 49.0
## Stand-in tints (ART-BIBLE § Ships, stand-in tints): pirates rust, police grey, aliens olive.
const TINTS := {1: Color("#d69a88"), 3: Color("#d69a88"), 4: Color("#d69a88"), 2: Color("#c9d4e0"), 6: Color("#7a9a6a"), 12: Color("#7a9a6a")}
## Exhaust colours (ART-BIBLE § Palette).
const EXHAUST_CIVIL := Color("#6e9bff")
const EXHAUST_PIRATE := Color("#ff7a2e")
const EXHAUST_POLICE := Color("#dde8ff")
const EXHAUST_ALIEN := Color("#9dff4a")
const LASER_OWN := Color("#7cffa0")
const LASER_HOSTILE := Color("#ff5a3c")
## Planet, station and sun sizes in metres (RULES B.11.1: planet radius 24576 sim units; the
## station's hit radius 150; the sun is drawn inside the radius where it burns).
const PLANET_RADIUS := 4915.0
const SUN_RADIUS := 3600.0
const STATION_RADIUS := 30.0
## Nozzles in the Cheetah's own frame (+X forward), position and radius in metres.
const NOZZLES := [[Vector3(-30.6, 0.45, 0.0), 1.5], [Vector3(-28.9, -0.35, -2.75), 1.0], [Vector3(-28.9, -0.35, 2.75), 1.0]]
const DUST_COUNT := 160
const DUST_RANGE := 1200.0

var camera: Camera3D
var _sim: Node
var _player: Node3D
var _player_plumes: Array[Node3D] = []
var _pod: MeshInstance3D
## The player's own fireball while dying (RULES D.3.10: 61 ticks).
var _wreck: MeshInstance3D
## A weak light from the camera so hulls on the night side still read (plain looks).
var _fill: DirectionalLight3D
var _hangar: Node3D
var _light: DirectionalLight3D
var _env: Environment
## The orientation of space relative to the ship: turned by the sim's roll and pitch each frame,
## so the sky and the sun's light hold still in space while the universe turns around the ship.
var _space := Basis.IDENTITY
var _sun_dir_space := Vector3(-0.62, 0.34, -0.71).normalized()
var _nodes := {}
var _beams: Array = []
var _dust: MultiMeshInstance3D
var _dust_points: PackedVector3Array = []
var _last_mode := ""
var _title_spin := 0.0


func setup(sim: Node) -> void:
	_sim = sim
	_sim.sim_event.connect(_on_sim_event)
	_sim.ticked.connect(_on_ticked)
	_sim.mount_selected.connect(func(mount: int) -> void: camera.behind_mount(mount))


func _ready() -> void:
	camera = Camera3D.new()
	camera.set_script(OrbitCamera)
	camera.ship_length = PLAYER_LENGTH
	add_child(camera)
	camera.current = true
	_build_environment()
	_build_player()
	_build_hangar()
	_build_dust()


func _build_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = STARFIELD
	var sky := Sky.new()
	sky.sky_material = sky_material
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 0.3
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX
	_env.glow_enabled = true
	_env.glow_hdr_threshold = 1.0
	_env.glow_intensity = 0.8
	_env.glow_bloom = 0.05
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in range(1, 8):
		_env.set_glow_level(level - 1, 1.0 if level >= 2 and level <= 6 else 0.0)
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)
	_light = DirectionalLight3D.new()
	_light.light_color = Color(1.0, 0.9, 0.78)
	_light.light_energy = 2.4
	_light.shadow_enabled = true
	_light.directional_shadow_max_distance = 400.0
	add_child(_light)
	_fill = DirectionalLight3D.new()
	_fill.light_color = Color("#9fc3ff")
	_fill.light_energy = 0.35
	_fill.shadow_enabled = false
	add_child(_fill)


func _build_player() -> void:
	# The holder turns on the title; the model keeps the import's turn to −Z forward.
	_player = Node3D.new()
	add_child(_player)
	var model := _ship_model(PLAYER_LENGTH, Color.WHITE)
	_player.add_child(model)
	for nozzle in NOZZLES:
		var plume := _plume(nozzle[0], nozzle[1], EXHAUST_CIVIL)
		model.add_child(plume)
		_player_plumes.append(plume)
	_pod = MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 1.8
	capsule.height = 6.0
	_pod.mesh = capsule
	_pod.rotation = Vector3(PI / 2.0, 0, 0)
	_pod.material_override = _plain(Color("#c9a25c"), 0.4, Color("#ffe2b0"), 0.6)
	_pod.visible = false
	add_child(_pod)
	_wreck = _sphere(1.0, _plain(Color.BLACK, 1.0, Color(1.0, 0.45, 0.15), 3.0), 24)
	_wreck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wreck.visible = false
	add_child(_wreck)


func _build_hangar() -> void:
	_hangar = Node3D.new()
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(110, 2, 110)
	pad.mesh = box
	pad.position = Vector3(0, -9, 0)
	pad.material_override = _plain(Color("#2a2c33"), 0.8)
	_hangar.add_child(pad)
	var deck := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(900, 900)
	deck.mesh = plane
	deck.position = Vector3(0, -10.2, 0)
	deck.material_override = _plain(Color("#121318"), 0.9)
	_hangar.add_child(deck)
	for i in 4:
		var lamp := OmniLight3D.new()
		lamp.light_color = Color("#ffe2b0")
		lamp.light_energy = 2.5
		lamp.omni_range = 140.0
		lamp.position = Vector3(-50 + 100 * (i % 2), 45, -50 + 100 * (i / 2))
		_hangar.add_child(lamp)
		var bulb := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 1.2
		sphere.height = 2.4
		bulb.mesh = sphere
		bulb.material_override = _plain(Color.BLACK, 1.0, Color("#ffe2b0"), 6.0)
		bulb.position = lamp.position
		_hangar.add_child(bulb)
	_hangar.visible = false
	add_child(_hangar)


func _build_dust() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.25
	mesh.height = 0.5
	mesh.radial_segments = 4
	mesh.rings = 2
	mesh.material = _plain(Color.BLACK, 1.0, Color("#cfd8ff"), 1.4)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = DUST_COUNT
	_dust = MultiMeshInstance3D.new()
	_dust.multimesh = multimesh
	_dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_dust)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in DUST_COUNT:
		_dust_points.append(Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * DUST_RANGE)


func _process(delta: float) -> void:
	if _sim == null:
		return
	var mode: String = _sim.mode()
	var cockpit: Dictionary = _sim.cockpit()
	var flying := mode in ["flight", "dying", "escape"]
	var paused: bool = _sim.paused()
	camera.anchored = flying
	camera.mount = cockpit["active_mount"]
	if mode != _last_mode:
		_enter_mode(mode)
	if flying and not paused:
		var roll: float = cockpit["roll_angle"]
		var pitch: float = cockpit["pitch_angle"]
		camera.turn_with_universe(roll, pitch, delta)
		_turn_space(roll * delta * 12.0, pitch * delta * 12.0)
		_move_dust(delta, cockpit["speed"], roll, pitch)
	_dust.visible = flying
	_hangar.visible = mode == "docked"
	_player.visible = mode != "escape" and mode != "dying"
	_pod.visible = mode == "escape"
	_wreck.visible = mode == "dying"
	if mode == "dying":
		var k := clampf(1.0 - float(_sim.mode_count()) / 61.0, 0.0, 1.0)
		_wreck.scale = Vector3.ONE * PLAYER_LENGTH * (0.2 + 0.45 * k)
		_wreck.transparency = k
	if mode == "title":
		_title_spin += delta * 0.25
		_player.rotation = Vector3(0.08, _title_spin, 0)
	else:
		_player.rotation = Vector3.ZERO
	var speed: float = cockpit["speed"] if flying else (8.0 if mode == "title" else 0.0)
	for plume in _player_plumes:
		plume.visible = speed > 0.0
		plume.scale = Vector3(0.6 + speed / 40.0, 1.0, 1.0)
	_draw_objects(flying)
	camera.limit = _clear_distance() if flying else INF
	camera.h_offset = 0.0 if flying else (0.22 if mode == "docked" else 0.3) * camera.zoom * PLAYER_LENGTH
	_update_light()


func _enter_mode(mode: String) -> void:
	_last_mode = mode
	if mode == "title":
		camera.set_view(Vector3(-0.55, 0.18, -0.8), 2.2)
	elif mode == "docked":
		camera.set_view(Vector3(0.75, 0.32, -0.55), 2.0)
	elif mode.begins_with("tunnel"):
		camera.behind_mount(0, true)
	if mode in ["title", "docked"] or mode.begins_with("tunnel"):
		_clear_objects()


## Space turns with the universe: the same rotation the sim gives every object.
func _turn_space(roll: float, pitch: float) -> void:
	var x := _space.x
	var y := _space.y
	var z := _space.z
	_space = Basis(_turn(x, roll, pitch), _turn(y, roll, pitch), _turn(z, roll, pitch)).orthonormalized()
	_env.sky_rotation = _space.get_euler()


func _turn(v: Vector3, roll: float, pitch: float) -> Vector3:
	var x := v.x
	var y := v.y
	var z := -v.z
	y -= roll * x
	x += roll * y
	y -= pitch * z
	z += pitch * y
	return Vector3(x, y, -z)


func _move_dust(delta: float, speed: float, roll: float, pitch: float) -> void:
	var share := delta * 12.0
	var forward := speed * share * 0.2
	for i in DUST_COUNT:
		var p := _turn(_dust_points[i], roll * share, pitch * share)
		p.z += forward
		if p.z > DUST_RANGE:
			p.z -= 2.0 * DUST_RANGE
		for axis in 3:
			if absf(p[axis]) > DUST_RANGE:
				p[axis] = -signf(p[axis]) * DUST_RANGE
		_dust_points[i] = p
		_dust.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))


func _update_light() -> void:
	_fill.global_transform = camera.global_transform
	var sun_dir := _space * _sun_dir_space
	for slot in _nodes:
		if _nodes[slot]["kind"] == 129:
			var node: Node3D = _nodes[slot]["node"]
			if node.position.length() > 1.0:
				sun_dir = node.position.normalized()
				_sun_dir_space = _space.inverse() * sun_dir
	if _last_mode == "docked":
		sun_dir = Vector3(0.3, 1.0, 0.2).normalized()
	_light.look_at_from_position(Vector3.ZERO, -sun_dir, Vector3.UP if absf(sun_dir.y) < 0.95 else Vector3.RIGHT)


# ---- The bubble's objects ----

func _draw_objects(flying: bool) -> void:
	if not flying:
		return
	var seen := {}
	for o in _sim.objects():
		var slot: int = o["slot"]
		var kind: int = o["kind"]
		seen[slot] = true
		if not _nodes.has(slot) or _nodes[slot]["kind"] != kind:
			if _nodes.has(slot):
				_nodes[slot]["node"].queue_free()
			_nodes[slot] = {"kind": kind, "node": _make_object(kind)}
		var entry: Dictionary = _nodes[slot]
		var node: Node3D = entry["node"]
		var position: Vector3 = o["position"]
		var basis: Basis = o["basis"]
		if kind >= 128:
			_place_body(node, kind, position)
		else:
			node.transform = Transform3D(basis, position)
			_explode(entry, o)
		entry["data"] = o
	for slot in _nodes.keys():
		if not seen.has(slot):
			_nodes[slot]["node"].queue_free()
			_nodes.erase(slot)


## How far the camera can be from the ship before an object's bounding sphere comes between
## them or holds the camera inside it.
func _clear_distance() -> float:
	var direction: Vector3 = camera.direction()
	var clear := INF
	for slot in _nodes:
		var entry: Dictionary = _nodes[slot]
		var kind: int = entry["kind"]
		if kind >= 128 or not entry.has("data"):
			continue
		var radius: float = STATION_RADIUS * 1.5 if kind == 8 else SHIP_LENGTHS.get(kind, 8.0) * 0.5
		var p: Vector3 = entry["node"].position
		var along := p.dot(direction)
		if along > 0.0 and (p - direction * along).length() < radius:
			clear = minf(clear, along - radius)
	return clear


func _clear_objects() -> void:
	for slot in _nodes:
		_nodes[slot]["node"].queue_free()
	_nodes.clear()


## The object at `slot` as last drawn (position in metres, flags), or empty.
func object_at(slot: int) -> Dictionary:
	return _nodes[slot].get("data", {}) if _nodes.has(slot) else {}


## Every object drawn this frame, by slot.
func drawn_objects() -> Array:
	var out := []
	for slot in _nodes:
		if _nodes[slot].has("data"):
			out.append(_nodes[slot]["data"])
	return out


## Planets and the sun: beyond 2 km they are drawn nearer and smaller by the same factor, so
## their angular size is exact and the depth buffer stays sane (DESIGN § Coordinates).
func _place_body(node: Node3D, kind: int, position: Vector3) -> void:
	var radius := SUN_RADIUS if kind == 129 else PLANET_RADIUS
	var distance := position.length()
	var shown := distance
	if distance > 2000.0:
		shown = 2000.0 + 6000.0 * (distance - 2000.0) / (distance - 2000.0 + 30000.0)
	var factor := shown / maxf(distance, 0.001)
	node.position = position * factor
	node.scale = Vector3.ONE * radius * factor


func _make_object(kind: int) -> Node3D:
	var node: Node3D
	match kind:
		128, 130:
			node = _sphere(1.0, _plain(Color("#2c4256") if kind == 128 else Color("#56462c"), 0.9), 96)
			if kind == 130:
				var ring := MeshInstance3D.new()
				var torus := TorusMesh.new()
				torus.inner_radius = 1.35
				torus.outer_radius = 1.9
				ring.mesh = torus
				ring.scale = Vector3(1, 0.04, 1)
				ring.rotation = Vector3(0.3, 0, 0.2)
				ring.material_override = _plain(Color("#8d7a5a"), 0.9)
				node.add_child(ring)
		129:
			node = _sphere(1.0, _plain(Color.BLACK, 1.0, Color(1.0, 0.82, 0.58), 34.0), 48)
			(node as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		8:
			node = _station()
		9:
			node = _missile()
		10:
			node = _sphere(7.5, _plain(Color("#6b6560"), 1.0), 8)
			node.scale = Vector3(1.0, 0.75, 0.9)
		11:
			var crate := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(3.2, 3.2, 4.4)
			crate.mesh = box
			crate.material_override = _plain(Color("#b8862e"), 0.6)
			node = crate
		13:
			var pod := MeshInstance3D.new()
			var capsule := CapsuleMesh.new()
			capsule.radius = 1.4
			capsule.height = 4.0
			pod.mesh = capsule
			pod.rotation = Vector3(PI / 2.0, 0, 0)
			pod.material_override = _plain(Color("#c9a25c"), 0.5, Color("#ffe2b0"), 0.5)
			node = Node3D.new()
			node.add_child(pod)
		_:
			var length: float = SHIP_LENGTHS.get(kind, 40.0)
			node = _ship_model(length, TINTS.get(kind, Color.WHITE))
			var colour := EXHAUST_CIVIL
			if kind in [1, 3, 4]:
				colour = EXHAUST_PIRATE
			elif kind == 2:
				colour = EXHAUST_POLICE
			elif kind in [6, 12]:
				colour = EXHAUST_ALIEN
			node.add_child(_plume(NOZZLES[0][0], NOZZLES[0][1], colour))
	var holder := Node3D.new()
	holder.add_child(node)
	holder.set_meta("model", node)
	var cloud := _sphere(1.0, _plain(Color.BLACK, 1.0, Color(1.0, 0.55, 0.2), 12.0), 16)
	cloud.name = "Cloud"
	cloud.visible = false
	(cloud as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(cloud)
	add_child(holder)
	return holder


## While exploding, the model hides and a fireball grows and fades with the sim's cloud counter
## (RULES C.12: 60 ticks).
func _explode(entry: Dictionary, o: Dictionary) -> void:
	var holder: Node3D = entry["node"]
	var model: Node3D = holder.get_meta("model")
	var cloud := holder.get_node("Cloud") as MeshInstance3D
	var exploding: bool = o["exploding"]
	model.visible = not exploding
	cloud.visible = exploding
	if exploding:
		var k := clampf((float(o["cloud"]) - 18.0) / 240.0, 0.0, 1.0)
		var size: float = SHIP_LENGTHS.get(int(o["kind"]), 12.0)
		cloud.scale = Vector3.ONE * size * (0.25 + 0.9 * k)
		cloud.transparency = k
	if model.has_method("set_channel"):
		model.call("set_channel", "turrets", 1.0 if o["firing"] else 0.0)


func _station() -> Node3D:
	var root := Node3D.new()
	var drum := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = STATION_RADIUS * 0.8
	cylinder.bottom_radius = STATION_RADIUS * 0.8
	cylinder.height = 26.0
	cylinder.radial_segments = 32
	drum.mesh = cylinder
	drum.rotation = Vector3(PI / 2.0, 0, 0)
	drum.material_override = _plain(Color("#8f8a80"), 0.7)
	root.add_child(drum)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = STATION_RADIUS * 1.15
	torus.outer_radius = STATION_RADIUS * 1.35
	torus.rings = 48
	ring.mesh = torus
	ring.rotation = Vector3(PI / 2.0, 0, 0)
	ring.material_override = _plain(Color("#6d6a64"), 0.8)
	root.add_child(ring)
	for spoke in 4:
		var bar := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(2.0, STATION_RADIUS * 2.5, 2.0)
		bar.mesh = box
		bar.rotation = Vector3(0, 0, spoke * PI / 4.0)
		bar.material_override = _plain(Color("#5a5852"), 0.8)
		root.add_child(bar)
	# The docking slot on the face the nose points out of, long along the roof (RULES B.12.2).
	var slot := MeshInstance3D.new()
	var slot_box := BoxMesh.new()
	slot_box.size = Vector3(5.0, 16.0, 1.0)
	slot.mesh = slot_box
	slot.position = Vector3(0, 0, -13.2)
	slot.material_override = _plain(Color.BLACK, 1.0, Color("#9fc3ff"), 2.5)
	root.add_child(slot)
	return root


func _missile() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 6.0
	body.mesh = cylinder
	body.rotation = Vector3(PI / 2.0, 0, 0)
	body.material_override = _plain(Color("#b9bcc4"), 0.4)
	root.add_child(body)
	var seeker := _sphere(0.7, _plain(Color.BLACK, 1.0, Color("#ff5a3c"), 6.0), 8)
	seeker.position = Vector3(0, 0, -3.2)
	root.add_child(seeker)
	var flame := _sphere(0.8, _plain(Color.BLACK, 1.0, Color("#ffc27a"), 8.0), 8)
	flame.position = Vector3(0, 0, 3.4)
	flame.scale = Vector3(1, 1, 2.5)
	root.add_child(flame)
	return root


func _ship_model(length: float, tint: Color) -> Node3D:
	var ship: Node3D = SHIP_SCENE.instantiate()
	ship.set_script(SHIP_SCRIPT)
	ship.scale = Vector3.ONE * (length / CHEETAH_LENGTH)
	if tint != Color.WHITE:
		var overlay := StandardMaterial3D.new()
		overlay.albedo_color = tint
		overlay.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		overlay.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		for mesh in ship.find_children("*", "MeshInstance3D", true, false):
			(mesh as MeshInstance3D).material_overlay = overlay
	return ship


func _sphere(radius: float, material: Material, segments: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 4)
	instance.mesh = mesh
	instance.material_override = material
	return instance


func _plain(albedo: Color, roughness: float, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = roughness
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	return m


func _plume(at: Vector3, radius: float, colour: Color) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.95
	mesh.bottom_radius = radius * 0.15
	mesh.height = radius * 9.0
	mesh.radial_segments = 16
	mesh.rings = 1
	cone.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = EXHAUST
	material.set_shader_parameter("core", Vector3(colour.r, colour.g, colour.b))
	cone.material_override = material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# In the model's own frame (+X forward): the cylinder runs along +Y; turn it to stream aft
	# (−X) from the nozzle.
	cone.rotation = Vector3(0, 0, PI / 2.0)
	cone.position = Vector3(-mesh.height / 2.0, 0, 0)
	holder.add_child(cone)
	return holder


# ---- Lasers ----

func _on_sim_event(kind: String, data: Dictionary) -> void:
	if kind == "laser_fired":
		_fire_own_laser()


func _fire_own_laser() -> void:
	var mount: int = _sim.active_mount()
	var axis: Vector3 = OrbitCamera.MOUNT_AXES[mount]
	var target := axis * 3000.0
	for o in _sim.objects():
		if o["in_sights"]:
			target = o["position"]
			break
	var start := axis * PLAYER_LENGTH * 0.45
	_add_beam(start, target, LASER_OWN)


func _add_beam(from: Vector3, to: Vector3, colour: Color) -> void:
	var beam := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.35
	mesh.bottom_radius = 0.35
	mesh.height = 1.0
	mesh.radial_segments = 6
	mesh.rings = 1
	beam.mesh = mesh
	beam.material_override = _plain(Color.BLACK, 1.0, colour, 7.0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var length := from.distance_to(to)
	var mid := (from + to) / 2.0
	var dir := (to - from).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(dir, up)
	# The cylinder's axis is +Y: turn it onto the look direction (−Z of the looking basis).
	basis = basis * Basis(Vector3.RIGHT, PI / 2.0)
	beam.transform = Transform3D(basis.scaled_local(Vector3(1, length, 1)), mid)
	add_child(beam)
	_beams.append([beam, _sim.tick_count()])


## Beams last until the next tick (RULES D.4.1: the lines show for the tick the laser fired in).
## Each tick, a ship firing at the player draws a hostile beam toward the ship (ART-BIBLE).
func _on_ticked(tick: int) -> void:
	for beam in _beams:
		if beam[1] < tick:
			beam[0].queue_free()
	_beams = _beams.filter(func(b: Array) -> bool: return b[1] >= tick)
	for o in _sim.objects():
		if o["firing"] and not o["exploding"] and o["kind"] < 128:
			var aim := Vector3(randf_range(-4, 4), randf_range(-2, 2), randf_range(-4, 4))
			_add_beam(o["position"], aim, LASER_HOSTILE)
