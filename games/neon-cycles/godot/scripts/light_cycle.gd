class_name LightCycle
extends Node3D
## A single light cycle: movement on a 90-degree grid, trail walls, AI driving,
## procedural model and crash effects. Collision is resolved by the game (main.gd)
## using axis-aligned rectangles in the XZ plane, which is exact for this game.

signal crashed(cycle: LightCycle)

const WALL_HEIGHT := 1.5
const WALL_THICK := 0.14
const HIT_RADIUS := 0.3
const FRONT_OFFSET := 1.15
const BASE_SPEED := 26.0
const BOOST_SPEED := 44.0
const BOOST_DRAIN := 0.45
const BOOST_REGEN := 0.18
const MIN_TURN_GAP := 0.09  # seconds between turns (prevents accidental U-turn into own trail)

const WALL_SHADER := preload("res://shaders/light_wall.gdshader")

var game: Node
var color := Color(0, 0.85, 1)
var is_player := false
var display_name := ""
var dir := Vector3.FORWARD
var speed := BASE_SPEED
var alive := true
var active := false
var boosting := false
var boost_energy := 1.0
var collidable := true

## Finished trail segments as collision rects (XZ plane, already grown by hit radius).
var walls: Array[Rect2] = []
## Turn points for the minimap (XZ).
var trail_points := PackedVector2Array()

var _seg_start := Vector3.ZERO
var _current_wall: MeshInstance3D
var _wall_meshes: Array[MeshInstance3D] = []
var _trail_root: Node3D
var _trail_mat: ShaderMaterial
var _model: Node3D
var _light: OmniLight3D
var _visual_yaw := 0.0
var _lean := 0.0
var _turn_cooldown := 0.0
var _ai_timer := 0.0
var _ai_turn_bias := 1
var _rng := RandomNumberGenerator.new()
var _wheels: Array[Node3D] = []


func setup(p_game: Node, p_color: Color, p_pos: Vector3, p_dir: Vector3, p_player: bool, p_name: String, trail_parent: Node3D) -> void:
	game = p_game
	color = p_color
	is_player = p_player
	display_name = p_name
	dir = p_dir
	position = p_pos
	_rng.randomize()
	_ai_turn_bias = 1 if _rng.randf() < 0.5 else -1

	_trail_mat = ShaderMaterial.new()
	_trail_mat.shader = WALL_SHADER
	_trail_mat.set_shader_parameter("wall_color", color)
	_trail_mat.set_shader_parameter("energy", 1.25)
	_trail_mat.set_shader_parameter("fade", 1.0)

	_trail_root = Node3D.new()
	_trail_root.name = "Trail_" + p_name
	trail_parent.add_child(_trail_root)

	_build_model()
	_visual_yaw = _yaw_for(dir)
	_model.rotation.y = _visual_yaw
	_seg_start = position
	trail_points.append(Vector2(position.x, position.z))
	_start_wall()


# --------------------------------------------------------------------------
# Simulation
# --------------------------------------------------------------------------

## Reads input (player) or decides (AI). Called by the game each physics tick.
func think(delta: float) -> void:
	_turn_cooldown -= delta
	if is_player:
		if Input.is_action_just_pressed("turn_left"):
			turn(1)
		elif Input.is_action_just_pressed("turn_right"):
			turn(-1)
		boosting = Input.is_action_pressed("boost") and boost_energy > 0.02
	else:
		_ai_think(delta)


## Moves forward and returns [front_before, front_after] for swept collision.
func advance(delta: float) -> Array[Vector3]:
	var target_speed := BOOST_SPEED if boosting else BASE_SPEED
	speed = move_toward(speed, target_speed, 60.0 * delta)
	if boosting:
		boost_energy = max(0.0, boost_energy - BOOST_DRAIN * delta)
		if boost_energy <= 0.0:
			boosting = false
	else:
		boost_energy = min(1.0, boost_energy + BOOST_REGEN * delta)

	var f0 := position + dir * FRONT_OFFSET
	position += dir * speed * delta
	var f1 := position + dir * FRONT_OFFSET
	_update_current_wall()
	return [f0, f1]


func turn(sign_dir: int) -> void:
	if not alive or not active or _turn_cooldown > 0.0:
		return
	_turn_cooldown = MIN_TURN_GAP
	_finish_wall()
	dir = dir.rotated(Vector3.UP, sign_dir * PI * 0.5).round()
	_seg_start = position
	trail_points.append(Vector2(position.x, position.z))
	_start_wall()
	_lean = clamp(_lean + sign_dir * 0.55, -0.7, 0.7)
	if is_player and game.get("sfx") != null:
		game.sfx.play("turn", -2.0)


## Collision rect of the live (growing) trail segment.
func current_rect() -> Rect2:
	return _segment_rect(_seg_start, position)


func _segment_rect(a: Vector3, b: Vector3) -> Rect2:
	var r := HIT_RADIUS + WALL_THICK * 0.5
	var mn := Vector2(min(a.x, b.x), min(a.z, b.z))
	var mx := Vector2(max(a.x, b.x), max(a.z, b.z))
	return Rect2(mn, mx - mn).grow(r)


# --------------------------------------------------------------------------
# Trail walls
# --------------------------------------------------------------------------

func _start_wall() -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	mi.mesh = box
	mi.material_override = _trail_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_root.add_child(mi)
	_current_wall = mi
	_wall_meshes.append(mi)
	_update_current_wall()


func _update_current_wall() -> void:
	if _current_wall == null:
		return
	var a := _seg_start
	var b := position
	var mid := (a + b) * 0.5
	_current_wall.position = Vector3(mid.x, WALL_HEIGHT * 0.5, mid.z)
	_current_wall.scale = Vector3(
		max(abs(b.x - a.x), 0.0) + WALL_THICK,
		WALL_HEIGHT,
		max(abs(b.z - a.z), 0.0) + WALL_THICK)


func _finish_wall() -> void:
	_update_current_wall()
	walls.append(_segment_rect(_seg_start, position))


# --------------------------------------------------------------------------
# AI
# --------------------------------------------------------------------------

func _ai_think(delta: float) -> void:
	_ai_timer -= delta
	if _ai_timer > 0.0 or not active:
		return
	_ai_timer = 0.03 + _rng.randf() * 0.04

	var p := Vector2(position.x, position.z)
	var f := Vector2(dir.x, dir.z)
	var left3 := dir.rotated(Vector3.UP, PI * 0.5).round()
	var l := Vector2(left3.x, left3.z)
	var r := -l

	var ahead: float = game.ray_distance(p + f * FRONT_OFFSET, f, 120.0)
	var left_d: float = game.ray_distance(p + l * 1.2, l, 120.0)
	var right_d: float = game.ray_distance(p + r * 1.2, r, 120.0)

	var danger := speed * 0.32 + 2.5
	if ahead < danger:
		if left_d < 2.0 and right_d < 2.0:
			return  # boxed in, nothing to do
		if abs(left_d - right_d) < 3.0:
			turn(_ai_turn_bias)
		else:
			turn(1 if left_d > right_d else -1)
		return

	# Opportunistic turns keep the AI unpredictable and use open space.
	if _rng.randf() < 0.012:
		var best := 1 if left_d > right_d else -1
		if max(left_d, right_d) > 18.0:
			turn(best)
			return

	# Try to cut across the player's path when close and to the side.
	var target: LightCycle = game.player
	if target != null and target != self and target.alive and _rng.randf() < 0.06:
		var to_t := Vector2(target.position.x, target.position.z) - p
		var tf := Vector2(target.dir.x, target.dir.z)
		if to_t.length() < 30.0 and to_t.dot(f) < 2.0 and tf.dot(f) > 0.5:
			var side := 1 if to_t.dot(l) > 0.0 else -1
			var side_free := left_d if side == 1 else right_d
			if side_free > 12.0:
				turn(side)
				return

	boosting = ahead > 60.0 and boost_energy > 0.5 and _rng.randf() < 0.5


# --------------------------------------------------------------------------
# Visuals
# --------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not alive:
		return
	var target := _yaw_for(dir)
	_visual_yaw = lerp_angle(_visual_yaw, target, 1.0 - exp(-16.0 * delta))
	_lean = move_toward(_lean, 0.0, 2.2 * delta)
	_model.rotation = Vector3(0, _visual_yaw, _lean)
	var spin := speed * delta / 0.5
	for w in _wheels:
		w.rotate_object_local(Vector3.RIGHT, -spin)
	_light.light_energy = 2.2 + (1.4 if boosting else 0.0)


func _yaw_for(d: Vector3) -> float:
	return atan2(-d.x, -d.z)


func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	return m


func _build_model() -> void:
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)

	var hull := StandardMaterial3D.new()
	hull.albedo_color = Color(0.03, 0.035, 0.05)
	hull.metallic = 1.0
	hull.roughness = 0.12
	hull.clearcoat_enabled = true
	hull.clearcoat = 1.0
	hull.rim_enabled = true
	hull.rim = 0.4
	hull.rim_tint = 0.8

	var glow := _emissive(color, 5.0)
	var glow_soft := _emissive(color, 2.0)

	# Main body: elongated capsule lying along Z.
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.36
	cap.height = 2.7
	cap.radial_segments = 32
	cap.rings = 12
	body.mesh = cap
	body.material_override = hull
	body.rotation.x = PI * 0.5
	body.scale = Vector3(1.0, 1.0, 0.78)
	body.position = Vector3(0, 0.6, 0)
	_model.add_child(body)

	# Canopy.
	var canopy := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.5
	sph.height = 1.0
	canopy.mesh = sph
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.02, 0.02, 0.03)
	glass.metallic = 0.6
	glass.roughness = 0.02
	glass.emission_enabled = true
	glass.emission = color.darkened(0.6)
	glass.emission_energy_multiplier = 0.6
	canopy.material_override = glass
	canopy.scale = Vector3(0.55, 0.42, 1.5)
	canopy.position = Vector3(0, 0.9, -0.15)
	_model.add_child(canopy)

	# Side light strips.
	for sx in [-1.0, 1.0]:
		var strip := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.04, 0.05, 2.1)
		strip.mesh = sb
		strip.material_override = glow
		strip.position = Vector3(0.29 * sx, 0.62, 0.05)
		_model.add_child(strip)

	# Tail light & nose.
	var tail := MeshInstance3D.new()
	var tb := BoxMesh.new()
	tb.size = Vector3(0.5, 0.08, 0.06)
	tail.mesh = tb
	tail.material_override = glow
	tail.position = Vector3(0, 0.72, 1.36)
	_model.add_child(tail)

	# Wheels: glowing rims with dark hubs and spokes so rotation reads.
	for wz in [-1.0, 1.05]:
		var wheel := Node3D.new()
		wheel.position = Vector3(0, 0.5, wz)
		_model.add_child(wheel)
		_wheels.append(wheel)

		var rim := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.36
		tor.outer_radius = 0.5
		tor.rings = 40
		tor.ring_segments = 12
		rim.mesh = tor
		rim.material_override = glow
		rim.rotation.z = PI * 0.5
		wheel.add_child(rim)

		var hub := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.37
		cyl.bottom_radius = 0.37
		cyl.height = 0.16
		cyl.radial_segments = 32
		hub.mesh = cyl
		hub.material_override = hull
		hub.rotation.z = PI * 0.5
		wheel.add_child(hub)

		for i in 3:
			var spoke := MeshInstance3D.new()
			var spb := BoxMesh.new()
			spb.size = Vector3(0.18, 0.66, 0.05)
			spoke.mesh = spb
			spoke.material_override = glow_soft
			spoke.rotation.x = i * PI / 3.0
			wheel.add_child(spoke)

	_light = OmniLight3D.new()
	_light.light_color = color
	_light.light_energy = 2.2
	_light.omni_range = 7.0
	_light.omni_attenuation = 1.4
	_light.position = Vector3(0, 0.9, 0)
	_model.add_child(_light)


# --------------------------------------------------------------------------
# Death
# --------------------------------------------------------------------------

func crash() -> void:
	if not alive:
		return
	alive = false
	active = false
	boosting = false
	_finish_wall()
	_model.visible = false
	_spawn_explosion()
	_derez_trail()
	crashed.emit(self)


func _spawn_explosion() -> void:
	var fx := Node3D.new()
	get_parent().add_child(fx)
	fx.global_position = global_position + Vector3(0, 0.6, 0)

	# Shards.
	var shards := GPUParticles3D.new()
	shards.amount = 220
	shards.lifetime = 1.6
	shards.one_shot = true
	shards.explosiveness = 0.95
	shards.fixed_fps = 0
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 5.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -14, 0)
	pm.damping_min = 2.0
	pm.damping_max = 6.0
	pm.angular_velocity_min = -720.0
	pm.angular_velocity_max = 720.0
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(0.7, 0.6))
	curve.add_point(Vector2(1, 0))
	var ct := CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	shards.process_material = pm
	var shard_mesh := BoxMesh.new()
	shard_mesh.size = Vector3(0.14, 0.14, 0.28)
	shard_mesh.material = _emissive(color, 7.0)
	shards.draw_pass_1 = shard_mesh
	fx.add_child(shards)
	shards.emitting = true

	# Expanding shock ring.
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 64
	ring.mesh = tor
	var ring_mat := _emissive(color.lightened(0.3), 8.0)
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = ring_mat
	ring.position.y = -0.4
	fx.add_child(ring)

	# Flash.
	var flash := OmniLight3D.new()
	flash.light_color = color.lightened(0.4)
	flash.light_energy = 14.0
	flash.omni_range = 26.0
	fx.add_child(flash)

	var tw := fx.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(14, 1, 14), 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(ring_mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_property(ring_mat, "emission_energy_multiplier", 0.0, 0.8)
	tw.tween_property(flash, "light_energy", 0.0, 0.9).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_callback(fx.queue_free)


func _derez_trail() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_interval(0.35)
	for mi in _wall_meshes:
		if is_instance_valid(mi):
			tw.tween_property(mi, "scale:y", 0.0, 1.1).set_delay(0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
			tw.tween_property(mi, "position:y", 0.0, 1.1).set_delay(0.35).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): _trail_mat.set_shader_parameter("fade", v), 1.0, 0.0, 1.3).set_delay(0.35)
	tw.chain().tween_callback(func():
		collidable = false
		walls.clear()
		if is_instance_valid(_trail_root):
			_trail_root.queue_free())


func cleanup() -> void:
	if is_instance_valid(_trail_root):
		_trail_root.queue_free()
	queue_free()
