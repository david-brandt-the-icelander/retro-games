extends CharacterBody3D
## A giant ant. Follows the city's flow field towards the player, climbs one
## block at a time by jumping, bites anything it reaches.

const Meshes = preload("res://scripts/meshes.gd")
const DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var main: Node
var city: Node
var speed := 4.4
var gravity := 22.0
var dead := false

var _visual: Node3D
var _legs: Array = []
var _antennae: Array[Node3D] = []
var _mandibles: Array[Node3D] = []
var _phase := 0.0
var _t := 0.0
var _dead_t := 0.0
var _bite_cd := 0.5
var _bite_anim := 0.0
var _jump_cd := 0.0
var _stuck_t := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _emerge := 1.0
var _yaw := 0.0


func _ready() -> void:
	add_to_group("ants")
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.6
	cap.height = 1.3
	cs.shape = cap
	cs.position.y = 0.65
	add_child(cs)
	_build()
	_yaw = randf() * TAU


func _build() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var shade := randf()
	var base := Color(0.20, 0.06, 0.035).lerp(Color(0.07, 0.045, 0.035), shade)
	var body := StandardMaterial3D.new()
	body.albedo_color = base
	body.metallic = 0.25
	body.roughness = 0.3
	body.clearcoat_enabled = true
	body.clearcoat = 1.0
	body.clearcoat_roughness = 0.12
	body.rim_enabled = true
	body.rim = 0.35
	body.rim_tint = 0.6
	var leg := StandardMaterial3D.new()
	leg.albedo_color = base.darkened(0.35)
	leg.metallic = 0.2
	leg.roughness = 0.4
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.02, 0.0, 0.0)
	eye.roughness = 0.05
	eye.metallic = 0.6
	eye.emission_enabled = true
	eye.emission = Color(1.0, 0.12, 0.04)
	eye.emission_energy_multiplier = 1.6

	var V := _visual
	Meshes.mesh_instance(Meshes.sphere(0.5, 28), body, V, Vector3(0, 0.88, 0.98), Vector3(0.3, 0, 0), Vector3(0.88, 0.78, 1.28))
	Meshes.mesh_instance(Meshes.sphere(0.14, 12), body, V, Vector3(0, 0.74, 0.36))
	Meshes.mesh_instance(Meshes.sphere(0.28, 20), body, V, Vector3(0, 0.76, 0.0), Vector3(-0.15, 0, 0), Vector3(0.8, 0.78, 1.55))
	Meshes.mesh_instance(Meshes.sphere(0.32, 22), body, V, Vector3(0, 0.86, -0.6), Vector3(0.2, 0, 0), Vector3(1.0, 0.86, 1.05))
	for sx in [-1.0, 1.0]:
		Meshes.mesh_instance(Meshes.sphere(0.1, 14), eye, V, Vector3(sx * 0.24, 0.94, -0.68), Vector3.ZERO, Vector3(0.7, 1.0, 1.1))
		var mp := Node3D.new()
		mp.position = Vector3(sx * 0.12, 0.72, -0.84)
		V.add_child(mp)
		Meshes.mesh_instance(Meshes.capsule(0.045, 0.42), leg, mp, Vector3(0, 0, -0.18), Vector3(PI / 2, 0, 0))
		_mandibles.append(mp)
		var ap := Node3D.new()
		ap.position = Vector3(sx * 0.11, 1.08, -0.74)
		ap.rotation = Vector3(-0.55, 0, -sx * 0.35)
		V.add_child(ap)
		Meshes.mesh_instance(Meshes.cylinder(0.02, 0.028, 0.5, 6), leg, ap, Vector3(0, 0.25, 0))
		var ap2 := Node3D.new()
		ap2.position = Vector3(0, 0.5, 0)
		ap2.rotation = Vector3(-1.25, 0, 0)
		ap.add_child(ap2)
		Meshes.mesh_instance(Meshes.cylinder(0.014, 0.02, 0.5, 6), leg, ap2, Vector3(0, 0.25, 0))
		_antennae.append(ap)
	var zs := [-0.24, 0.0, 0.24]
	for i in 3:
		for side in [-1, 1]:
			var hip := Node3D.new()
			hip.position = Vector3(side * 0.16, 0.74, zs[i])
			V.add_child(hip)
			var femur := Node3D.new()
			hip.add_child(femur)
			Meshes.mesh_instance(Meshes.capsule(0.05, 0.66), leg, femur, Vector3(0.3, 0, 0), Vector3(0, 0, PI / 2))
			var knee := Node3D.new()
			knee.position = Vector3(0.6, 0, 0)
			femur.add_child(knee)
			Meshes.mesh_instance(Meshes.sphere(0.065, 10), leg, knee)
			Meshes.mesh_instance(Meshes.capsule(0.038, 1.1), leg, knee, Vector3(0.52, 0, 0), Vector3(0, 0, PI / 2))
			var base_yaw: float = [0.6, 0.0, -0.6][i] * side
			var group := (i + (1 if side > 0 else 0)) % 2
			_legs.append({"hip": hip, "femur": femur, "knee": knee, "side": side, "base": base_yaw, "off": group * PI})


func _pose_legs(lift_amp: float, swing_amp: float, curl := 0.0) -> void:
	for L in _legs:
		var side: float = L.side
		var ph: float = _phase + L.off
		var lift := maxf(0.0, cos(ph)) * lift_amp
		L.hip.rotation.y = L.base + side * sin(ph) * swing_amp
		var th1 := 0.55 + lift + curl
		var th2 := -2.05 - lift * 0.5 - curl * 0.9
		L.femur.rotation.z = th1 if side > 0 else PI - th1
		L.knee.rotation.z = th2 if side > 0 else -th2


func _physics_process(delta: float) -> void:
	_t += delta
	if dead:
		_dead_update(delta)
		return
	if _emerge > 0.0:
		_emerge -= delta
		_visual.position.y = -maxf(_emerge, 0.0) * 1.3
	_bite_cd -= delta
	_jump_cd -= delta

	var player: Node3D = main.player
	var to_p := player.global_position - global_position
	var desired := Vector3.ZERO
	var climb := false
	var my_c: Vector2i = city.cell_of(global_position)
	if to_p.length() < 2.4 and absf(to_p.y) < 1.2:
		desired = Vector3(to_p.x, 0, to_p.z)
	else:
		var flow: PackedInt32Array = main.flow
		var n1 := _best_neighbor(flow, my_c)
		if n1 != my_c:
			var tgt := n1
			var n2 := _best_neighbor(flow, n1)
			if n2 != n1 and city.h_at(n2) == city.h_at(n1) and city.h_at(n1) == city.h_at(my_c):
				tgt = n2
			desired = city.cell_center(tgt) - global_position
			desired.y = 0.0
			climb = city.h_at(n1) > city.h_at(my_c)
		elif flow[city.idx(my_c)] == 0 or flow[city.idx(my_c)] < 0 and to_p.length() < 12.0:
			desired = Vector3(to_p.x, 0, to_p.z)
			climb = to_p.y > 0.5
		else:
			_wander_t -= delta
			if _wander_t <= 0.0:
				_wander_t = randf_range(1.0, 3.0)
				_wander = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			desired = _wander

	var sep := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("ants"):
		if other == self:
			continue
		var d: Vector3 = global_position - other.global_position
		d.y = 0.0
		var l := d.length()
		if l < 2.0 and l > 0.01:
			sep += d / l * (2.0 - l)

	var move := Vector3.ZERO
	if desired.length() > 0.05:
		move = desired.normalized() * speed
	move += sep * 2.5
	if _emerge > 0.0:
		move = Vector3.ZERO
	velocity.x = move_toward(velocity.x, move.x, 28.0 * delta)
	velocity.z = move_toward(velocity.z, move.z, 28.0 * delta)
	velocity.y -= gravity * delta

	var hv := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and desired.length() > 0.05 and hv < 0.8:
		_stuck_t += delta
	else:
		_stuck_t = 0.0
	if is_on_floor() and _jump_cd <= 0.0 and ((climb and is_on_wall()) or _stuck_t > 0.8):
		velocity.y = 8.0
		_jump_cd = 0.7
		_stuck_t = 0.0
	move_and_slide()

	if hv > 0.3:
		_yaw = lerp_angle(_yaw, atan2(-velocity.x, -velocity.z), 1.0 - exp(-8.0 * delta))
	if to_p.length() < 3.0:
		_yaw = lerp_angle(_yaw, atan2(-to_p.x, -to_p.z), 1.0 - exp(-10.0 * delta))
	_visual.rotation.y = _yaw
	_visual.rotation.x = lerpf(_visual.rotation.x, 0.0 if is_on_floor() else -0.35, 1.0 - exp(-8.0 * delta))

	_phase += delta * (hv * 3.4 + 0.5)
	if is_on_floor():
		_pose_legs(0.35 * clampf(hv / 2.0, 0.0, 1.0), 0.38 * clampf(hv / 2.0, 0.0, 1.0))
	else:
		_pose_legs(0.0, 0.0, 0.25)
	for i in _antennae.size():
		_antennae[i].rotation.x = -0.55 + sin(_t * 5.0 + i * 1.7) * 0.18
	_bite_anim = maxf(_bite_anim - delta * 4.0, 0.0)
	for i in _mandibles.size():
		var s := 1.0 if i == 0 else -1.0
		_mandibles[i].rotation.y = s * (-0.35 + sin(_bite_anim * PI) * 0.9 + sin(_t * 9.0) * 0.06)

	if _bite_cd <= 0.0 and _emerge <= 0.0:
		var targets: Array = [player]
		if main.hostage and main.hostage.following:
			targets.append(main.hostage)
		for tgt in targets:
			var d: Vector3 = tgt.global_position - global_position
			if Vector2(d.x, d.z).length() < 2.0 and absf(d.y) < 1.3:
				tgt.hurt(9.0 + main.level, global_position)
				_bite_cd = 0.9
				_bite_anim = 1.0
				break


func _best_neighbor(flow: PackedInt32Array, c: Vector2i) -> Vector2i:
	if not city.inside_grid(c):
		return c
	var best: int = flow[city.idx(c)]
	var best_c := c
	for d in DIRS:
		var n: Vector2i = c + d
		if not city.inside_grid(n):
			continue
		var nd: int = flow[city.idx(n)]
		if nd < 0 or city.h_at(n) - city.h_at(c) > 1:
			continue
		if best < 0 or nd < best:
			best = nd
			best_c = n
	return best_c


func die(from: Vector3) -> void:
	if dead:
		return
	dead = true
	remove_from_group("ants")
	collision_layer = 0
	collision_mask = 1
	var push := global_position - from
	push.y = 0.0
	velocity = push.normalized() * 5.0 + Vector3.UP * 9.0
	main.on_ant_killed(self)


func _dead_update(delta: float) -> void:
	_dead_t += delta
	velocity.x = move_toward(velocity.x, 0.0, 4.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 4.0 * delta)
	velocity.y -= gravity * delta
	move_and_slide()
	var k := 1.0 - exp(-7.0 * delta)
	_visual.rotation.z = lerpf(_visual.rotation.z, PI, k)
	_visual.rotation.x = lerpf(_visual.rotation.x, 0.0, k)
	var twitch := sin(_t * 30.0) * 0.25 * maxf(0.0, 1.0 - _dead_t / 2.5)
	_phase += delta * 14.0 * maxf(0.0, 1.0 - _dead_t / 2.0)
	_pose_legs(0.1, 0.15, 0.9 + twitch)
	if _dead_t < 4.0:
		_visual.position.y = lerpf(_visual.position.y, 1.45, k)
	else:
		_visual.position.y -= delta * 0.6
	if _dead_t > 7.0:
		queue_free()
