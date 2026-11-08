extends Node3D
## The spike's flight scene: the player's ship under the orbit camera, near a blooming sun,
## driven by the 12 Hz sim through SimHost. Run with `-- --shot=<file.png>` to save a
## screenshot after a few seconds and quit.

const SHIP_SCENE := preload("res://assets/ships/acnx7_cheetah/acnx7_cheetah.glb")
const SHIP_SCRIPT := preload("res://src/presentation/ships/ship.gd")
const STARFIELD := preload("res://src/presentation/space/starfield.gdshader")
const EXHAUST := preload("res://src/presentation/space/exhaust.gdshader")
const SUN_DIRECTION := Vector3(-0.62, 0.34, -0.71)
const MOUNT_NAMES := ["FRONT", "REAR", "LEFT", "RIGHT"]
## Engine nozzles in the ship's own frame (+X forward): position and radius in metres.
const NOZZLES := [[Vector3(-30.6, 0.45, 0.0), 1.5], [Vector3(-28.9, -0.35, -2.75), 1.0], [Vector3(-28.9, -0.35, 2.75), 1.0]]

@onready var _sim: Node = $SimHost
@onready var _readout: Label = $Hud/Readout
var _ship: Node3D
var _shot_path := ""
var _shot_frames := 150


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
		elif arg.begins_with("--frames="):
			_shot_frames = int(arg.trim_prefix("--frames="))
	_build_environment()
	_build_sun_and_planet()
	_build_ship()
	_sim.ticked.connect(_on_ticked)
	_sim.mount_selected.connect(_on_mount_selected)


func _build_environment() -> void:
	var sky_material := ShaderMaterial.new()
	sky_material.shader = STARFIELD
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.035
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_hdr_threshold = 1.0
	env.glow_intensity = 0.8
	env.glow_bloom = 0.05
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	for level in range(1, 8):
		env.set_glow_level(level - 1, 1.0 if level >= 2 and level <= 6 else 0.0)
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_sun_and_planet() -> void:
	var light := DirectionalLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.78)
	light.light_energy = 2.6
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 400.0
	add_child(light)
	light.look_at_from_position(Vector3.ZERO, -SUN_DIRECTION, Vector3.UP)

	var sun := MeshInstance3D.new()
	var sun_mesh := SphereMesh.new()
	sun_mesh.radius = 60.0
	sun_mesh.height = 120.0
	sun.mesh = sun_mesh
	var sun_material := StandardMaterial3D.new()
	# Unshaded materials ignore emission, so the sun is a black surface that only emits:
	# bright enough (energy 35, well over 1.0) that glow picks it out and nothing else.
	sun_material.albedo_color = Color(0, 0, 0)
	sun_material.disable_receive_shadows = true
	sun_material.emission_enabled = true
	sun_material.emission = Color(1.0, 0.8, 0.55)
	sun_material.emission_energy_multiplier = 35.0
	sun.material_override = sun_material
	sun.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sun.position = SUN_DIRECTION.normalized() * 2000.0
	add_child(sun)

	var planet := MeshInstance3D.new()
	var planet_mesh := SphereMesh.new()
	planet_mesh.radius = 700.0
	planet_mesh.height = 1400.0
	planet_mesh.radial_segments = 96
	planet_mesh.rings = 48
	planet.mesh = planet_mesh
	var planet_material := StandardMaterial3D.new()
	planet_material.albedo_color = Color(0.16, 0.24, 0.34)
	planet_material.roughness = 0.9
	planet_material.rim_enabled = true
	planet_material.rim = 0.6
	planet_material.rim_tint = 0.2
	planet.material_override = planet_material
	planet.position = Vector3(900.0, -1300.0, 1500.0)
	add_child(planet)


func _build_ship() -> void:
	_ship = SHIP_SCENE.instantiate()
	_ship.set_script(SHIP_SCRIPT)
	add_child(_ship)
	for nozzle in NOZZLES:
		_ship.add_child(_plume(nozzle[0], nozzle[1]))
	_ship.set_channel("turrets", 1.0)


func _plume(at: Vector3, radius: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = at
	var cone := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.95
	mesh.bottom_radius = radius * 0.15
	mesh.height = radius * 9.0
	mesh.radial_segments = 24
	mesh.rings = 1
	cone.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = EXHAUST
	cone.material_override = material
	cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The cylinder runs along +Y; turn it to stream aft (-X) from the nozzle.
	cone.rotation = Vector3(0, 0, PI / 2.0)
	cone.position = Vector3(-mesh.height / 2.0, 0, 0)
	holder.add_child(cone)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.5, 0.65, 1.0)
	glow.light_energy = 3.0
	glow.omni_range = radius * 14.0
	glow.position = Vector3(-radius * 1.5, 0, 0)
	holder.add_child(glow)
	return holder


func _on_ticked(tick: int) -> void:
	# The spike drives the rig from the sim's tick: the turrets sweep and the brakes cycle.
	_ship.set_turret_traverse(sin(float(tick) / 30.0) * 70.0)
	_ship.set_channel("brakes", 1.0 if (tick / 96) % 2 == 1 else 0.0)


func _on_mount_selected(mount: int) -> void:
	_readout.text = _readout_text()


func _process(_delta: float) -> void:
	_readout.text = _readout_text()
	if _shot_path != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


func _readout_text() -> String:
	return "TICK %d   MOUNT %s   PARTS %d" % [_sim.tick_count(), MOUNT_NAMES[_sim.active_mount()], _ship.part_count()]
