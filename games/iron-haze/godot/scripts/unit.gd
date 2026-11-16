extends "res://scripts/entity.gd"
## Mobile units: vehicles, infantry squads and airships.

enum State { IDLE, MOVE, ATTACK, ATTACK_MOVE, BUILD }

var state: int = State.IDLE
var move_target := Vector3.ZERO
var attack_target = null
var build_target = null
var leash := false
var velocity := Vector3.ZERO
var speed := 5.0
var heading := 0.0
var is_vehicle := true
var moving := false
var anim_t := 0.0
var bob_phase := 0.0
var squad: Array = []
var props: Array = []
var exhausts: Array = []
var crane: Node3D = null
var stuck_t := 0.0
var last_dist := INF
var engage_cd := 0.0
var building_now := false


func _ready() -> void:
	def = Game.UNITS[kind]
	radius = float(def["radius"])
	speed = float(def["speed"])
	is_air = bool(def.get("air", false))
	is_vehicle = kind != "trooper" and not is_air
	visual = Models.build_unit(kind, team)
	add_child(visual)
	_setup_common()
	for n in visual.find_children("Member*", "Node3D", true, false):
		squad.append(n)
	for n in visual.find_children("Prop*", "Node3D", true, false):
		props.append(n)
	crane = visual.find_child("Crane", true, false) as Node3D
	for m in visual.find_children("Exhaust*", "Node3D", true, false):
		exhausts.append(FX.smoke_emitter(m, Vector3.ZERO, 0.45, true, 0.5))
	bob_phase = randf() * TAU
	if is_air:
		position.y = Game.world.height_at(position.x, position.z) + Game.AIR_ALTITUDE
	_apply_orientation(1.0)


# ---------------------------------------------------------------- commands

func is_idle() -> bool:
	return state == State.IDLE


func state_text() -> String:
	match state:
		State.MOVE: return "Moving"
		State.ATTACK: return "Attacking"
		State.ATTACK_MOVE: return "Engaging" if Game.alive(attack_target) else "Attack-moving"
		State.BUILD: return "Constructing" if building_now else "En route to site"
	return "Idle"


func cmd_move(p: Vector3) -> void:
	state = State.MOVE
	move_target = p
	attack_target = null
	build_target = null
	leash = false
	_reset_progress()


func cmd_attack(t) -> void:
	if not Game.alive(t):
		return
	if not Game.can_hit(def, t):
		cmd_move(t.position)
		return
	state = State.ATTACK
	attack_target = t
	build_target = null
	leash = false
	_reset_progress()


func cmd_attack_move(p: Vector3) -> void:
	if not has_weapon():
		cmd_move(p)
		return
	state = State.ATTACK_MOVE
	move_target = p
	attack_target = null
	build_target = null
	leash = false
	_reset_progress()


func cmd_build(b) -> void:
	if kind != "constructor":
		cmd_move(b.position)
		return
	state = State.BUILD
	build_target = b
	attack_target = null
	_reset_progress()


func cmd_stop() -> void:
	state = State.IDLE
	attack_target = null
	build_target = null
	leash = false


func _engage(t) -> void:
	state = State.ATTACK_MOVE
	move_target = position
	attack_target = t
	leash = true
	_reset_progress()


func _reset_progress() -> void:
	stuck_t = 0.0
	last_dist = INF


# ---------------------------------------------------------------- simulation

func _physics_process(delta: float) -> void:
	if dead:
		return
	weapon_cd -= delta
	scan_cd -= delta
	engage_cd -= delta
	building_now = false
	var desired := Vector3.ZERO
	var fire_target = null
	var stationary_fire: bool = kind == "howitzer"
	match state:
		State.IDLE:
			if has_weapon():
				fire_target = _acquire()
				if fire_target == null and engage_cd <= 0.0:
					engage_cd = 0.8
					var t = find_target(7.0)
					if t != null:
						_engage(t)
		State.MOVE:
			desired = _steer_to(move_target, null)
			if _arrived(move_target, delta):
				state = State.IDLE
				desired = Vector3.ZERO
			elif not stationary_fire:
				fire_target = _acquire()
		State.ATTACK:
			if not Game.alive(attack_target):
				attack_target = null
				state = State.IDLE
			elif in_range(attack_target):
				fire_target = attack_target
			else:
				desired = _steer_to(attack_target.position, attack_target)
		State.ATTACK_MOVE:
			if leash and Game.alive(attack_target) and flat_dist_to(move_target) > 28.0 and not in_range(attack_target):
				attack_target = null
			if not Game.alive(attack_target):
				attack_target = null
				if scan_cd <= 0.0:
					scan_cd = 0.4
					attack_target = find_target(8.0)
			if Game.alive(attack_target):
				if in_range(attack_target):
					fire_target = attack_target
				else:
					desired = _steer_to(attack_target.position, attack_target)
			else:
				desired = _steer_to(move_target, null)
				if _arrived(move_target, delta):
					state = State.IDLE
					leash = false
		State.BUILD:
			if not Game.alive(build_target) or (build_target.complete and build_target.hp >= build_target.max_hp):
				build_target = null
				state = State.IDLE
			elif flat_dist(build_target) <= float(build_target.radius) + radius + 2.0:
				build_target.construct(delta)
				building_now = true
				_face(build_target.position, delta)
			else:
				desired = _steer_to(build_target.position, build_target)
	_move(desired, delta)
	if fire_target != null and has_weapon():
		var aimed := true
		if turret != null:
			aimed = aim_turret(fire_target, delta)
		elif not is_air and velocity.length() < 0.6:
			_face(fire_target.position, delta)
		if stationary_fire and velocity.length() > 0.8:
			aimed = false
		if aimed and weapon_cd <= 0.0:
			fire_at(fire_target)
	elif turret != null:
		aim_turret(null, delta)


func _acquire():
	if Game.alive(auto_target) and in_range(auto_target):
		return auto_target
	auto_target = null
	if scan_cd <= 0.0:
		scan_cd = 0.3 + randf() * 0.2
		auto_target = find_target(0.0)
	return auto_target


func flat_dist_to(p: Vector3) -> float:
	return Vector2(p.x - position.x, p.z - position.z).length()


func _yaw_to(p: Vector3) -> float:
	return atan2(-(p.x - position.x), -(p.z - position.z))


func _face(p: Vector3, delta: float) -> void:
	heading = Game.turn_toward(heading, _yaw_to(p), 3.0 * delta)


func _steer_to(p: Vector3, ignore) -> Vector3:
	var to := Vector2(p.x - position.x, p.z - position.z)
	var d := to.length()
	if d < 0.05:
		return Vector3.ZERO
	var dir := to / d
	var v := dir * speed * clampf(d / 2.5, 0.35, 1.0)
	if not is_air:
		for o in Game.query(position, radius + 12.0):
			if o == self or not o.is_building or o == ignore:
				continue
			v += _avoid_force(Vector2(o.position.x, o.position.z), float(o.radius), dir)
		for o in Game.obstacles_near(position):
			v += _avoid_force(o["pos"], float(o["r"]), dir)
		if v.length() > speed:
			v = v.normalized() * speed
	return Vector3(v.x, 0.0, v.y)


func _avoid_force(c: Vector2, r: float, dir: Vector2) -> Vector2:
	var off := Vector2(position.x - c.x, position.z - c.y)
	var d := off.length()
	var min_d := r + radius + 0.3
	if d > min_d + 4.5 or d < 0.001:
		return Vector2.ZERO
	var n := off / d
	if dir.dot(-n) < -0.1:
		return Vector2.ZERO
	var w := clampf(1.0 - (d - min_d) / 4.5, 0.0, 1.0)
	var tang := Vector2(-n.y, n.x)
	if tang.dot(dir) < 0.0:
		tang = -tang
	return (tang * 1.3 + n * 0.5) * speed * w


func _arrived(p: Vector3, delta: float) -> bool:
	var d := flat_dist_to(p)
	if d < maxf(0.7, radius * 0.6):
		return true
	if d < last_dist - 0.08:
		last_dist = d
		stuck_t = 0.0
	else:
		stuck_t += delta
	if stuck_t > 1.2 and d < 3.0 + radius * 2.5:
		return true
	return stuck_t > 5.0


func _move(desired: Vector3, delta: float) -> void:
	var accel := 3.5 if is_vehicle else (1.2 if is_air else 9.0)
	velocity = velocity.lerp(desired, 1.0 - exp(-accel * delta))
	var spd := velocity.length()
	moving = spd > 0.4
	var step := velocity * delta
	if spd > 0.15:
		var dirv := velocity / spd
		var turn := 2.4 if is_vehicle else (0.9 if is_air else 10.0)
		heading = Game.turn_toward(heading, atan2(-dirv.x, -dirv.z), turn * delta)
		if is_vehicle:
			var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
			var align := clampf(fwd.dot(dirv), 0.0, 1.0)
			step = fwd * spd * align * delta
	position += step
	var push := Vector2.ZERO
	for o in Game.query(position, radius + 3.0):
		if o == self or o.is_building or o.is_air != is_air:
			continue
		var off := Vector2(position.x - o.position.x, position.z - o.position.z)
		var d := off.length()
		var md: float = (radius + float(o.radius)) * 0.85
		if d < md:
			if d < 0.01:
				off = Vector2(randf() - 0.5, randf() - 0.5)
				d = 0.01
			push += off.normalized() * (md - d)
	var k := minf(1.0, 5.0 * delta)
	position.x += push.x * k
	position.z += push.y * k
	if not is_air:
		for o in Game.query(position, radius + 8.0):
			if o.is_building and o != self:
				_push_out(Vector2(o.position.x, o.position.z), float(o.radius))
		for o in Game.obstacles_near(position):
			_push_out(o["pos"], float(o["r"]))
	position.x = clampf(position.x, -Game.MAP_HALF, Game.MAP_HALF)
	position.z = clampf(position.z, -Game.MAP_HALF, Game.MAP_HALF)
	_apply_orientation(delta)


func _push_out(c: Vector2, r: float) -> void:
	var off := Vector2(position.x - c.x, position.z - c.y)
	var d := off.length()
	var md := r + radius * 0.8
	if d >= md:
		return
	if d < 0.01:
		off = Vector2(1, 0)
		d = 1.0
	var n := off / d
	position.x = c.x + n.x * md
	position.z = c.y + n.y * md


func _apply_orientation(delta: float) -> void:
	var gh: float = Game.world.height_at(position.x, position.z)
	if is_air:
		var target_y := gh + Game.AIR_ALTITUDE + sin(anim_t * 0.7 + bob_phase) * 0.4
		position.y = lerpf(position.y, target_y, clampf(2.0 * delta, 0.0, 1.0))
		transform.basis = Basis.from_euler(Vector3(0.0, heading, 0.0))
		if sel_ring:
			sel_ring.position.y = gh - position.y + 0.15
	else:
		position.y = gh
		if is_vehicle:
			transform.basis = _terrain_basis()
		else:
			transform.basis = Basis(Vector3.UP, heading)


func _terrain_basis() -> Basis:
	var n: Vector3 = Game.world.normal_at(position.x, position.z)
	var z := Vector3(sin(heading), 0.0, cos(heading))
	var x := n.cross(z).normalized()
	z = x.cross(n).normalized()
	return Basis(x, n, z)


# ---------------------------------------------------------------- presentation

func _process(delta: float) -> void:
	if dead:
		return
	anim_t += delta
	for p in props:
		p.rotation.z += delta * 16.0
	for i in squad.size():
		var m: Node3D = squad[i]
		var target_y := 0.0
		if moving:
			target_y = absf(sin(anim_t * 9.0 + i * 1.9)) * 0.14
		m.position.y = lerpf(m.position.y, target_y, clampf(12.0 * delta, 0.0, 1.0))
	if crane:
		var goal := sin(anim_t * 1.3) * 0.7 if building_now else 0.0
		crane.rotation.y = lerpf(crane.rotation.y, goal, clampf(3.0 * delta, 0.0, 1.0))
		if building_now and Game.alive(build_target) and randf() < delta * 5.0:
			var bp: Vector3 = build_target.position
			FX.spark_burst(bp + Vector3(randf_range(-2, 2), randf_range(0.5, 2.5), randf_range(-2, 2)))
	for e in exhausts:
		if is_instance_valid(e):
			e.amount_ratio = 1.0 if moving else 0.35


func squad_muzzles() -> Array:
	var out := []
	var fwd := -global_transform.basis.z.normalized()
	for m in squad:
		var mp: Vector3 = m.global_position
		out.append(mp + Vector3(0, 1.35, 0) + fwd * 0.6)
	if out.is_empty():
		out.append(muzzle_pos())
	return out


func _on_damaged(attacker) -> void:
	if state == State.IDLE and has_weapon() and Game.alive(attacker) and Game.can_hit(def, attacker):
		_engage(attacker)


func _start_burning() -> void:
	if kind != "trooper":
		FX.fire_emitter(visual, Vector3(0, 1.6 if not is_air else 0.5, 0.5), 0.5)


func _on_death() -> void:
	if kind == "trooper":
		FX.explosion(position + Vector3(0, 0.6, 0), 0.6, false)
		return
	for p in visual.find_children("*", "GPUParticles3D", true, false):
		p.emitting = false
	visual.reparent(Game.world.fx_root, true)
	Models.char_visual(visual)
	if is_air:
		FX.crash(visual)
	else:
		FX.explosion(position + Vector3(0, 1.0, 0), 1.7, true)
		FX.wreck(visual)
