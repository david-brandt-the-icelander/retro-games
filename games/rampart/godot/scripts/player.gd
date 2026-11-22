extends Node3D
## The player's strike craft.

signal died

const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const BulletScript = preload("res://scripts/bullet.gd")

const MIN_X := -8.5
const MAX_X := 8.5
const MIN_Y := 0.9
const MAX_Y := 9.0

var speed_forward: float = 15.0
var lateral_speed: float = 12.0
var climb_speed: float = 7.5
var vel: Vector2 = Vector2.ZERO
var fire_cd: float = 0.0
var alive: bool = false
var invuln: float = 0.0
var over_floor: bool = true
var gun_side: float = 1.0

var model: Node3D
var area: Area3D
var marker: MeshInstance3D
var beam: MeshInstance3D
var trails: Array = []
var engine_light: OmniLight3D


func _ready() -> void:
	_build_model()
	area = Area3D.new()
	area.collision_layer = 1
	area.collision_mask = 4 | 8 | 16
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.5, 0.55, 2.0)
	cs.shape = bs
	area.add_child(cs)
	add_child(area)
	area.area_entered.connect(_on_area_entered)

	# Altitude aids: a target ring on the deck below and a faint beam to it.
	marker = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.4, 2.4)
	marker.mesh = pm
	marker.material_override = M.add(Color(0.25, 0.9, 1.0, 0.9), 2.5, 3)
	marker.top_level = true
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marker)
	beam = MeshInstance3D.new()
	beam.mesh = T.cyl(0.02, 0.02, 1.0, 6)
	beam.material_override = M.add(Color(0.25, 0.9, 1.0, 0.35), 1.5, 0)
	beam.top_level = true
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)


func _part(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if parent == null:
		parent = model
	parent.add_child(mi)
	return mi


func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	var hull := M.metal(Color(0.6, 0.64, 0.72), 0.3, 0.8)
	var dark := M.metal(Color(0.12, 0.13, 0.16), 0.45, 0.8)
	var accent := M.glow(Color(0.15, 0.75, 1.0), 6.0)
	var warm := M.glow(Color(1.0, 0.55, 0.15), 5.0)

	_part(T.box(0.72, 0.32, 2.0), hull, Vector3(0, 0, 0.1))
	_part(T.box(0.38, 0.2, 1.7), dark, Vector3(0, 0.2, 0.35))
	_part(T.cyl(0.0, 0.37, 1.35, 8), hull, Vector3(0, 0, -1.55), Vector3(-PI / 2, 0, 0), Vector3(1, 1, 0.5))
	_part(T.box(0.06, 0.06, 1.2), accent, Vector3(0, 0.17, -0.9))
	_part(T.sphere(0.26, 14), M.glass(Color(0.08, 0.35, 0.55)), Vector3(0, 0.2, -0.55), Vector3.ZERO, Vector3(1, 0.85, 2.2))

	for s in [-1.0, 1.0]:
		var wing := _part(T.box(1.9, 0.07, 1.15), hull, Vector3(s * 1.15, -0.03, 0.45), Vector3(0, -s * 0.42, 0))
		_part(T.box(1.9, 0.045, 0.07), accent, Vector3(0, 0.03, -0.55), Vector3.ZERO, Vector3.ONE, wing)
		_part(T.box(1.2, 0.08, 0.5), dark, Vector3(-s * 0.2, 0.04, 0.2), Vector3.ZERO, Vector3.ONE, wing)
		_part(T.box(0.07, 0.45, 0.7), hull, Vector3(s * 0.95, 0.2, 0.15), Vector3(0, 0, -s * 0.12), Vector3.ONE, wing)
		_part(T.sphere(0.06, 6), warm, Vector3(s * 0.97, 0.45, -0.1), Vector3.ZERO, Vector3.ONE, wing)
		_part(T.cyl(0.05, 0.05, 0.8, 6), dark, Vector3(s * 0.62, -0.06, -0.6), Vector3(PI / 2, 0, 0), Vector3.ONE, wing)
		_part(T.cyl(0.17, 0.21, 0.85, 12), dark, Vector3(s * 0.42, 0.0, 0.95), Vector3(PI / 2, 0, 0))
		_part(T.box(0.06, 0.55, 0.75), hull, Vector3(s * 0.3, 0.38, 1.0), Vector3(0, 0, s * 0.28))
		_part(T.sphere(0.16, 10), M.add(Color(0.35, 0.85, 1.0), 3.5, 1), Vector3(s * 0.42, 0, 1.4), Vector3.ZERO, Vector3(1, 1, 0.6))
		trails.append(_make_trail(Vector3(s * 0.42, 0, 1.45)))

	engine_light = OmniLight3D.new()
	engine_light.light_color = Color(0.35, 0.8, 1.0)
	engine_light.light_energy = 1.6
	engine_light.omni_range = 4.5
	engine_light.position = Vector3(0, 0.2, 1.9)
	model.add_child(engine_light)


func _make_trail(pos: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 48
	p.lifetime = 0.4
	p.local_coords = false
	p.direction = Vector3(0, 0, 1)
	p.spread = 3.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3.ZERO
	var sm := T.sphere(0.13, 6)
	sm.material = M.add(Color(1, 1, 1), 2.2, 1, true)
	p.mesh = sm
	p.color_ramp = M.gradient([Color(0.75, 0.95, 1.0, 1.0), Color(0.15, 0.5, 1.0, 0.7), Color(0.05, 0.1, 0.6, 0.0)])
	p.scale_amount_curve = M.curve(1.0, 0.15)
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(p)
	p.emitting = true
	return p


func reset_to(pos: Vector3) -> void:
	position = pos
	vel = Vector2.ZERO
	model.rotation = Vector3.ZERO


func set_active(on: bool) -> void:
	alive = on
	invuln = 0.0
	model.visible = on
	for tr in trails:
		tr.emitting = on


func respawn() -> void:
	position.x = 0.0
	position.y = 3.5
	vel = Vector2.ZERO
	set_active(true)
	invuln = 2.5


func _process(delta: float) -> void:
	position.z -= speed_forward * delta
	if alive:
		_steer(delta)
	marker.visible = alive and over_floor
	beam.visible = marker.visible
	if marker.visible:
		marker.global_position = Vector3(position.x, 0.04, position.z)
		var k := 1.0 - (position.y - MIN_Y) / (MAX_Y - MIN_Y) * 0.4
		marker.scale = Vector3(k, 1, k)
		beam.global_position = Vector3(position.x, position.y * 0.5, position.z)
		beam.scale = Vector3(1, maxf(position.y - 0.2, 0.01), 1)


func _steer(delta: float) -> void:
	var ix := Input.get_axis("move_left", "move_right")
	var iy := Input.get_axis("descend", "climb")
	if Game.autopilot:
		var tt := Time.get_ticks_msec() * 0.001
		ix = sin(tt * 0.9) * 0.8
		iy = sin(tt * 0.55)
		invuln = maxf(invuln, 0.01)
	var want := Vector2(ix * lateral_speed, iy * climb_speed)
	vel = vel.lerp(want, 1.0 - exp(-9.0 * delta))
	position.x = clampf(position.x + vel.x * delta, MIN_X, MAX_X)
	position.y = clampf(position.y + vel.y * delta, MIN_Y, MAX_Y)
	model.rotation.z = lerpf(model.rotation.z, -vel.x / lateral_speed * 0.6, 1.0 - exp(-10.0 * delta))
	model.rotation.x = lerpf(model.rotation.x, vel.y / climb_speed * 0.28, 1.0 - exp(-10.0 * delta))

	fire_cd -= delta
	if (Input.is_action_pressed("fire") or Game.autopilot) and fire_cd <= 0.0:
		_fire()

	if invuln > 0.0:
		invuln -= delta
		model.visible = Game.autopilot or invuln <= 0.0 or fmod(invuln, 0.16) > 0.08

	Game.fuel -= delta * Game.ramp(Game.level, 1.1, 2.4)
	if Game.autopilot:
		Game.fuel = maxf(Game.fuel, 30.0)
	if Game.fuel <= 0.0:
		Game.fuel = 0.0
		die()


func _fire() -> void:
	fire_cd = 0.11
	gun_side = -gun_side
	var b = BulletScript.new()
	b.velocity = Vector3(0, 0, -(speed_forward + 55.0))
	b.position = global_position + Vector3(0.62 * gun_side, -0.05, -1.3)
	Game.world.add_child(b)
	Sfx.play("laser", -13.0, randf_range(0.95, 1.06))


func _on_area_entered(_a: Area3D) -> void:
	if not alive or invuln > 0.0 or Game.autopilot:
		return
	die()


func die() -> void:
	if not alive:
		return
	alive = false
	model.visible = false
	for tr in trails:
		tr.emitting = false
	Game.spawn_explosion(global_position, 1.9, Color(0.35, 0.8, 1.0))
	Game.spawn_explosion(global_position, 1.3, Color(1.0, 0.55, 0.2))
	Game.shake(0.9)
	died.emit()
