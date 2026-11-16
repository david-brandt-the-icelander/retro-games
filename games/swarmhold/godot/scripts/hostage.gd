extends CharacterBody3D
## The person to rescue. Waits and waves until reached, then follows the
## player's footsteps, jumping where the player jumped.

const Humanoid = preload("res://scripts/humanoid.gd")
const Meshes = preload("res://scripts/meshes.gd")

var main: Node
var following := false
var health := 100.0
var speed := 7.0
var gravity := 22.0

var _model
var _beacon: Node3D
var _hurt_cd := 0.0
var _stuck_t := 0.0
var _yaw := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.25
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	_model = Humanoid.new()
	add_child(_model)
	_model.build(Color(0.85, 0.30, 0.22), Color(0.88, 0.84, 0.74), Color(0.62, 0.43, 0.30), Color(0.08, 0.06, 0.05))
	_model.waving = true

	_beacon = Node3D.new()
	add_child(_beacon)
	var beam := Meshes.mesh_instance(Meshes.cylinder(0.5, 0.5, 40.0, 24), Meshes.unshaded(Color(1.0, 0.75, 0.35, 0.10), true),
			_beacon, Vector3(0, 20.0, 0))
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var core := Meshes.mesh_instance(Meshes.cylinder(0.12, 0.12, 40.0, 12), Meshes.unshaded(Color(1.0, 0.85, 0.5, 0.25), true),
			_beacon, Vector3(0, 20.0, 0))
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.75, 0.4)
	light.light_energy = 2.5
	light.omni_range = 6.0
	light.position.y = 2.2
	_beacon.add_child(light)


func start_following() -> void:
	following = true
	_model.waving = false
	_beacon.visible = false
	main.player.trail.clear()


func _physics_process(delta: float) -> void:
	_hurt_cd -= delta
	velocity.y -= gravity * delta
	var player: Node3D = main.player
	var desired := Vector3.ZERO
	var target_y := global_position.y
	if following:
		var trail: Array = player.trail
		while trail.size() > 0 and _flat(trail[0] - global_position) < 0.75:
			trail.pop_front()
		var to_p := player.global_position - global_position
		if trail.size() > 2:
			desired = trail[0] - global_position
			target_y = trail[0].y
		elif _flat(to_p) > 2.2:
			desired = to_p
			target_y = player.global_position.y
		desired.y = 0.0
		if _flat(to_p) < 1.8 and absf(to_p.y) < 0.6:
			desired = Vector3.ZERO
	else:
		var to_p := player.global_position - global_position
		if _flat(to_p) < 10.0:
			_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-4.0 * delta))

	var move := desired.normalized() * speed if desired.length() > 0.05 else Vector3.ZERO
	velocity.x = move_toward(velocity.x, move.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 40.0 * delta)
	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and desired.length() > 0.05 and hv < 1.0:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if is_on_floor() and ((target_y > global_position.y + 0.45 and (is_on_wall() or _flat(desired) < 1.6)) or _stuck_t > 0.5):
		velocity.y = 7.9
		_stuck_t = 0.0
	move_and_slide()
	# Last resort if wedged somewhere: hop to the next footstep.
	if following and _stuck_t > 2.5 and player.trail.size() > 0:
		global_position = player.trail[0] + Vector3.UP * 0.2
		_stuck_t = 0.0

	if hv > 0.3:
		_yaw = lerp_angle(_yaw, atan2(-velocity.x, -velocity.z), 1.0 - exp(-12.0 * delta))
	_model.rotation.y = _yaw
	_model.animate(hv / speed, delta, is_on_floor())


func _flat(v: Vector3) -> float:
	return Vector2(v.x, v.z).length()


func hurt(amount: float, from: Vector3) -> void:
	if _hurt_cd > 0.0 or health <= 0.0:
		return
	_hurt_cd = 0.35
	health = maxf(health - amount, 0.0)
	var push := global_position - from
	push.y = 0.0
	velocity += push.normalized() * 5.0 + Vector3.UP * 2.5
	_model.flash()
	main.on_hostage_hurt(health)
