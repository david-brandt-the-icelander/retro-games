extends CharacterBody3D

const Humanoid = preload("res://scripts/humanoid.gd")
const Meshes = preload("res://scripts/meshes.gd")

signal health_changed(value: float)
signal died

var main: Node
var speed := 6.6
var accel := 45.0
var jump_v := 7.9
var gravity := 22.0
var health := 100.0
var alive := true
var control_enabled := false
var facing := 0.0
var trail: Array[Vector3] = []

var _model
var _coyote := 0.0
var _hurt_cd := 0.0
var _charge := -1.0
var _throw_cd := 0.0
var _aim: MeshInstance3D
var _aim_mesh: ImmediateMesh
var _arrow: Node3D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 4
	floor_snap_length = 0.25
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	_model = Humanoid.new()
	add_child(_model)
	_model.build(Color(0.08, 0.42, 0.52), Color(0.20, 0.21, 0.26), Color(0.92, 0.74, 0.60), Color(0.22, 0.13, 0.07), true)

	_aim_mesh = ImmediateMesh.new()
	_aim = MeshInstance3D.new()
	_aim.mesh = _aim_mesh
	_aim.top_level = true
	_aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim.material_override = Meshes.unshaded(Color(1.0, 0.85, 0.4, 0.75), true)
	add_child(_aim)

	_arrow = Node3D.new()
	_arrow.position.y = 2.55
	add_child(_arrow)
	var am := StandardMaterial3D.new()
	am.albedo_color = Color(1.0, 0.8, 0.3)
	am.emission_enabled = true
	am.emission = Color(1.0, 0.65, 0.2)
	am.emission_energy_multiplier = 2.0
	var arrow_mesh := Meshes.mesh_instance(Meshes.cylinder(0.0, 0.22, 0.55, 3), am, _arrow,
			Vector3(0, 0, -0.35), Vector3(-PI / 2, 0, 0), Vector3(1, 1, 0.35))
	arrow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func reset(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	health = 100.0
	alive = true
	facing = 0.0
	trail.clear()
	_charge = -1.0
	_aim_mesh.clear_surfaces()
	_model.rotation = Vector3.ZERO
	health_changed.emit(health)


func forward_dir() -> Vector3:
	return Vector3(-sin(facing), 0, -cos(facing))


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if control_enabled and alive:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var yaw: float = main.cam_yaw
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var dir := right * input.x - fwd * input.y
	if dir.length() > 1.0:
		dir = dir.normalized()
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if is_on_floor():
		_coyote = 0.12
	else:
		_coyote -= delta
	velocity.y -= gravity * delta
	if control_enabled and alive and Input.is_action_just_pressed("jump") and _coyote > 0.0:
		velocity.y = jump_v
		_coyote = 0.0
	move_and_slide()

	if not alive:
		_model.rotation.x = lerpf(_model.rotation.x, -PI / 2, 1.0 - exp(-6.0 * delta))
		_model.position.y = lerpf(_model.position.y, 0.25, 1.0 - exp(-6.0 * delta))
		return
	_model.position.y = 0.0
	if dir.length() > 0.1:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), 1.0 - exp(-14.0 * delta))
	_model.rotation.y = facing
	_model.animate(Vector2(velocity.x, velocity.z).length() / speed, delta, is_on_floor())

	if trail.is_empty() or trail.back().distance_to(global_position) > 0.6:
		trail.append(global_position)
		if trail.size() > 400:
			trail.pop_front()

	_hurt_cd -= delta
	_throw_cd -= delta
	if control_enabled:
		if Input.is_action_just_pressed("throw") and _throw_cd <= 0.0:
			_charge = 0.0
		if _charge >= 0.0:
			_charge = minf(_charge + delta * 1.3, 1.0)
			_draw_aim()
			if not Input.is_action_pressed("throw"):
				_throw()

	var obj: Vector3 = main.objective_position()
	var d := obj - global_position
	_arrow.visible = Vector2(d.x, d.z).length() > 4.0 and control_enabled
	_arrow.global_rotation = Vector3(0, atan2(-d.x, -d.z), 0)
	_arrow.position.y = 2.55 + sin(Time.get_ticks_msec() * 0.005) * 0.08


func _throw_velocity() -> Vector3:
	var power := lerpf(5.0, 15.0, _charge)
	return forward_dir() * power + Vector3.UP * lerpf(4.0, 6.5, _charge)


func _throw_origin() -> Vector3:
	return global_position + Vector3(0, 1.7, 0) + forward_dir() * 0.4


func _draw_aim() -> void:
	_aim_mesh.clear_surfaces()
	var g: float = main.GRENADE_GRAVITY
	var p := _throw_origin()
	var v := _throw_velocity()
	var city = main.city
	var pts: Array[Vector3] = []
	for i in 60:
		pts.append(p)
		v.y -= g * 0.03
		p += v * 0.03
		if p.y < city.surface_y(p):
			pts.append(p)
			break
	if pts.size() < 2:
		return
	_aim_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var side := (b - a).cross(Vector3.UP).normalized() * 0.06
		if i % 2 == 1:
			continue
		for q in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_aim_mesh.surface_add_vertex(q)
	_aim_mesh.surface_end()


func _throw() -> void:
	main.spawn_grenade(_throw_origin(), _throw_velocity())
	_charge = -1.0
	_throw_cd = 0.45
	_aim_mesh.clear_surfaces()
	_model.throw_t = 0.35


func hurt(amount: float, from: Vector3) -> void:
	if not alive or _hurt_cd > 0.0:
		return
	_hurt_cd = 0.35
	health = maxf(health - amount, 0.0)
	var push := global_position - from
	push.y = 0.0
	velocity += push.normalized() * 6.0 + Vector3.UP * 3.0
	_model.flash()
	health_changed.emit(health)
	if health <= 0.0:
		alive = false
		_aim_mesh.clear_surfaces()
		died.emit()
