extends "res://scripts/target.gd"
## Ground cannon that tracks the ship and lobs leading shots.

const M = preload("res://scripts/mats.gd")

var head: Node3D
var barrel: Node3D
var muzzle: Node3D
var fire_interval: float = 2.4
var timer: float = 1.0
var shot_speed: float = 17.0


func _ready() -> void:
	hp = 2
	points = 150
	explosion_size = 1.1
	setup_collision(Vector3(2.0, 2.8, 2.0), Vector3(0, 1.4, 0))
	timer = randf_range(0.4, fire_interval)
	make_visual()
	var dark := M.metal(Color(0.2, 0.22, 0.26), 0.45, 0.85)
	part(cyl(0.95, 1.2, 0.6, 16), dark, Vector3(0, 0.3, 0))
	var tm := TorusMesh.new()
	tm.inner_radius = 0.95
	tm.outer_radius = 1.06
	tm.rings = 24
	tm.ring_segments = 6
	part(tm, M.glow(Color(1.0, 0.28, 0.18), 5.0), Vector3(0, 0.62, 0))
	head = Node3D.new()
	head.position.y = 1.05
	visual.add_child(head)
	part(sphere(0.62), M.metal(Color(0.55, 0.57, 0.62), 0.3, 0.9), Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.8, 1), head)
	part(box(1.3, 0.18, 0.5), dark, Vector3(0, -0.15, 0), Vector3.ZERO, Vector3.ONE, head)
	barrel = Node3D.new()
	barrel.position.y = 0.1
	head.add_child(barrel)
	for s in [-0.2, 0.2]:
		part(cyl(0.09, 0.12, 1.3, 8), M.metal(Color(0.12, 0.12, 0.14), 0.5, 0.9), Vector3(s, 0, -0.75), Vector3(-PI / 2, 0, 0), Vector3.ONE, barrel)
		part(sphere(0.07, 6), M.glow(Color(1.0, 0.5, 0.2), 6.0), Vector3(s, 0, -1.42), Vector3.ZERO, Vector3.ONE, barrel)
	muzzle = Node3D.new()
	muzzle.position.z = -1.5
	barrel.add_child(muzzle)
	part(sphere(0.15, 8), M.glow(Color(1.0, 0.12, 0.08), 9.0), Vector3(0, 0.3, -0.48), Vector3.ZERO, Vector3.ONE, head)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or not p.alive or dead:
		return
	var dz: float = global_position.z - p.global_position.z
	if dz > -3.0 or dz < -65.0:
		return
	var aim := _lead(p)
	var to: Vector3 = aim - head.global_position
	head.rotation.y = lerp_angle(head.rotation.y, atan2(-to.x, -to.z), 1.0 - exp(-8.0 * delta))
	barrel.rotation.x = atan2(to.y, Vector2(to.x, to.z).length())
	if dz < -52.0 or dz > -9.0:
		return
	timer -= delta
	if timer <= 0.0:
		timer = fire_interval * randf_range(0.85, 1.15)
		var dir: Vector3 = (aim - muzzle.global_position).normalized()
		Game.spawn_shot(muzzle.global_position, dir * shot_speed)
		Sfx.play("enemy_shot", -16.0, randf_range(0.9, 1.1))


func _lead(p) -> Vector3:
	var pos: Vector3 = p.global_position
	var sp: float = p.speed_forward
	var t := 0.0
	for i in 3:
		var aim := pos + Vector3(0, 0, -sp * t)
		t = aim.distance_to(global_position + Vector3(0, 1.2, 0)) / shot_speed
	return pos + Vector3(0, 0, -sp * t)
