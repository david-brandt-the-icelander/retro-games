extends CharacterBody3D
class_name Agent
## A field agent. The owning peer simulates movement; everyone else interpolates.

const SPEED := 5.2
const SEND_RATE := 1.0 / 20.0

var peer_id := 1
var display_name := "Agent"
var color := Color.WHITE
var team := 0
var alive := true

var busy_until := 0.0     # searching / setting traps
var stun_until := 0.0
var slow_until := 0.0
var knock := Vector3.ZERO
var bot_input := Vector2.ZERO

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _moving := false
var _send_t := 0.0
var _bob := 0.0
var _punch_t := 0.0

var visual: Node3D
var body_mesh: MeshInstance3D
var fist: MeshInstance3D
var name_label: Label3D
var status_label: Label3D
var _materials: Array[StandardMaterial3D] = []


func setup(id: int, p_name: String, p_color: Color, p_team: int, spawn: Vector3) -> void:
	peer_id = id
	name = str(id)
	display_name = p_name
	color = p_color
	team = p_team
	position = spawn
	_target_pos = spawn


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_build_visual()


func is_local() -> bool:
	return peer_id == Net.my_id


func _m(c: Color, rough: float, metal := 0.0, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_materials.append(m)
	return m


func _part(mesh: Mesh, pos: Vector3, m: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	(parent if parent else visual).add_child(mi)
	return mi


func _build_visual() -> void:
	visual = Node3D.new()
	add_child(visual)
	var coat := _m(color.darkened(0.55).lerp(Color(0.12, 0.12, 0.14), 0.35), 0.65)
	var trim := _m(color, 0.4, 0.2, 0.6)
	var skin := _m(Color(0.86, 0.84, 0.8), 0.45)
	var hat := _m(Color(0.09, 0.09, 0.11), 0.55)
	var visor := _m(color, 0.1, 0.0, 3.5)
	var boots := _m(Color(0.06, 0.06, 0.07), 0.4, 0.3)

	# Trench-coat body (tapered cylinder) + belt
	var body := CylinderMesh.new()
	body.top_radius = 0.3
	body.bottom_radius = 0.42
	body.height = 1.15
	body_mesh = _part(body, Vector3(0, 0.78, 0), coat)
	var belt := CylinderMesh.new()
	belt.top_radius = 0.345
	belt.bottom_radius = 0.355
	belt.height = 0.07
	_part(belt, Vector3(0, 0.88, 0), trim)
	# Collar
	var collar := CylinderMesh.new()
	collar.top_radius = 0.24
	collar.bottom_radius = 0.33
	collar.height = 0.18
	_part(collar, Vector3(0, 1.38, 0), coat)
	# Boots
	for sx in [-0.15, 0.15]:
		var b := BoxMesh.new()
		b.size = Vector3(0.18, 0.16, 0.32)
		_part(b, Vector3(sx, 0.08, 0.04), boots)
	# Head
	var head := SphereMesh.new()
	head.radius = 0.25
	head.height = 0.52
	_part(head, Vector3(0, 1.66, 0), skin)
	# Glowing visor band
	var band := CylinderMesh.new()
	band.top_radius = 0.258
	band.bottom_radius = 0.258
	band.height = 0.08
	band.radial_segments = 32
	_part(band, Vector3(0, 1.69, 0), visor)
	# Hat: brim, crown, coloured band
	var brim := CylinderMesh.new()
	brim.top_radius = 0.46
	brim.bottom_radius = 0.48
	brim.height = 0.035
	brim.radial_segments = 32
	_part(brim, Vector3(0, 1.86, 0), hat)
	var crown := CylinderMesh.new()
	crown.top_radius = 0.22
	crown.bottom_radius = 0.27
	crown.height = 0.24
	crown.radial_segments = 32
	_part(crown, Vector3(0, 1.99, 0), hat)
	var hb := CylinderMesh.new()
	hb.top_radius = 0.272
	hb.bottom_radius = 0.274
	hb.height = 0.055
	hb.radial_segments = 32
	_part(hb, Vector3(0, 1.905, 0), trim)
	# Fist (used for the punch animation)
	var f := SphereMesh.new()
	f.radius = 0.11
	f.height = 0.22
	fist = _part(f, Vector3(0.32, 0.95, 0.15), skin)
	# Backpack gadget with team light (reads well from the top-down camera)
	var pack := BoxMesh.new()
	pack.size = Vector3(0.34, 0.4, 0.14)
	_part(pack, Vector3(0, 1.08, -0.33), hat)
	var led := BoxMesh.new()
	led.size = Vector3(0.24, 0.05, 0.02)
	_part(led, Vector3(0, 1.2, -0.405), visor)

	name_label = Label3D.new()
	name_label.text = display_name
	name_label.font_size = 40
	name_label.outline_size = 10
	name_label.modulate = color.lightened(0.3)
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.no_depth_test = true
	name_label.position = Vector3(0, 2.55, 0)
	add_child(name_label)
	status_label = Label3D.new()
	status_label.font_size = 30
	status_label.outline_size = 8
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.no_depth_test = true
	status_label.position = Vector3(0, 2.25, 0)
	add_child(status_label)


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func can_act() -> bool:
	return alive and now() >= busy_until and now() >= stun_until


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if is_local():
		var input := Vector2.ZERO
		if can_act() and not get_tree().root.gui_get_focus_owner() is LineEdit:
			input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
			if bot_input != Vector2.ZERO:
				input = bot_input
		var speed := SPEED * (0.5 if now() < slow_until else 1.0)
		var dir := Vector3(input.x, 0, input.y)
		velocity = dir * speed + knock
		velocity.y = 0.0
		knock = knock.move_toward(Vector3.ZERO, 18.0 * delta)
		move_and_slide()
		position.y = 0.0
		_moving = dir.length() > 0.1
		if _moving:
			_target_yaw = atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, _target_yaw, 1.0 - exp(-14.0 * delta))
		_send_t -= delta
		if _send_t <= 0.0:
			_send_t = SEND_RATE
			Net.call_others(self, "net_state", [position, visual.rotation.y, _moving], false)
	else:
		position = position.lerp(_target_pos, 1.0 - exp(-15.0 * delta))
		visual.rotation.y = lerp_angle(visual.rotation.y, _target_yaw, 1.0 - exp(-15.0 * delta))
	_animate(delta)


func _animate(delta: float) -> void:
	if _moving:
		_bob += delta * 11.0
	else:
		_bob = lerpf(_bob, roundf(_bob / PI) * PI, 1.0 - exp(-10.0 * delta))
	visual.position.y = absf(sin(_bob)) * 0.07
	visual.rotation.z = sin(_bob) * 0.05
	if _punch_t > 0.0:
		_punch_t -= delta
		var k := sin((1.0 - _punch_t / 0.25) * PI)
		fist.position = Vector3(0.32 - 0.2 * k, 1.05, 0.15 + 0.65 * k)
	else:
		fist.position = Vector3(0.32, 0.95 + absf(sin(_bob)) * 0.04, 0.15)
	if now() < stun_until:
		status_label.text = "STUNNED"
		status_label.modulate = Color(0.5, 0.8, 1.0)
	elif now() < busy_until:
		status_label.text = "…"
		status_label.modulate = Color(1, 1, 1, 0.8)
	elif now() < slow_until:
		status_label.text = "GASSED"
		status_label.modulate = Color(0.5, 1.0, 0.4)
	else:
		status_label.text = ""


func net_state(pos: Vector3, yaw: float, moving: bool) -> void:
	if Net.sender != peer_id:
		return
	_target_pos = pos
	_target_yaw = yaw
	_moving = moving
	if not alive:
		return
	if position.distance_to(pos) > 6.0:
		position = pos


func facing() -> Vector3:
	return Vector3(sin(visual.rotation.y), 0, cos(visual.rotation.y))


func play_punch() -> void:
	_punch_t = 0.25


func apply_hit(from: Vector3, strength: float, stun: float, slow: float) -> void:
	if not is_local():
		return
	var away := position - from
	away.y = 0
	if away.length() < 0.05:
		away = -facing()
	knock = away.normalized() * strength
	stun_until = maxf(stun_until, now() + stun)
	slow_until = maxf(slow_until, now() + slow)


func set_dead() -> void:
	alive = false
	velocity = Vector3.ZERO
	collision_layer = 0
	status_label.text = "ELIMINATED"
	status_label.modulate = Color(1, 0.35, 0.35)
	var tw := create_tween()
	tw.tween_property(visual, "rotation:x", -PI * 0.5, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(visual, "position:y", 0.25, 0.45)
	for m in _materials:
		m.albedo_color = m.albedo_color.darkened(0.5)
		if m.emission_enabled:
			m.emission_energy_multiplier = 0.2


func set_world_visible(v: bool) -> void:
	visual.visible = v
	name_label.visible = v
	status_label.visible = v
