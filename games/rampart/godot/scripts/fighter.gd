extends "res://scripts/target.gd"
## Interceptor that weaves toward the ship in open space. It weaves only sideways and always
## matches the ship's altitude, so you can line up a shot without the ring.

const M = preload("res://scripts/mats.gd")

var active: bool = false
var base_x: float = 0.0
var base_y: float = 4.0
var amp_x: float = 3.0
var freq: float = 1.3
var phase: float = 0.0
var speed: float = 9.0
var fire_chance: float = 0.3
var fire_gap: float = 1.0
var shot_speed: float = 20.0
var fire_timer: float = 1.5
var t: float = 0.0
var body: Node3D


func _ready() -> void:
	hp = 1
	points = 200
	explosion_size = 1.0
	explosion_color = Color(1.0, 0.3, 0.6)
	setup_collision(Vector3(2.6, 1.5, 2.2))
	fire_timer = randf_range(0.8, 2.5) * fire_gap
	make_visual()
	body = Node3D.new()
	body.rotation.y = PI
	visual.add_child(body)
	var hull := M.metal(Color(0.16, 0.13, 0.19), 0.35, 0.85)
	var plate := M.metal(Color(0.45, 0.42, 0.5), 0.3, 0.85)
	var glow := M.glow(Color(1.0, 0.25, 0.6), 6.0)
	part(box(0.7, 0.36, 1.9), hull, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, body)
	part(cyl(0.0, 0.32, 0.9, 8), plate, Vector3(0, 0, -1.35), Vector3(-PI / 2, 0, 0), Vector3(1, 1, 0.55), body)
	for s in [-1.0, 1.0]:
		var w := part(box(1.5, 0.07, 1.0), plate, Vector3(s * 0.95, 0, 0.1), Vector3(0, s * 0.45, 0), Vector3.ONE, body)
		part(box(0.12, 0.5, 0.9), hull, Vector3(s * 0.75, 0.0, 0.0), Vector3(0, 0, s * 0.2), Vector3.ONE, w)
		part(box(0.05, 0.05, 0.85), glow, Vector3(s * 0.83, 0.26, 0.0), Vector3.ZERO, Vector3.ONE, w)
	part(sphere(0.2, 10), M.glass(Color(0.6, 0.05, 0.2)), Vector3(0, 0.2, -0.4), Vector3.ZERO, Vector3(1, 0.8, 2), body)
	part(sphere(0.24, 10), M.add(Color(1.0, 0.3, 0.7), 5.0, 1), Vector3(0, 0, 1.05), Vector3.ZERO, Vector3(1, 1, 0.6), body)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null or dead:
		return
	var pz: float = p.global_position.z
	if not active:
		if global_position.z > pz - 95.0:
			active = true
		else:
			return
	t += delta
	if p.alive:
		base_x = move_toward(base_x, p.global_position.x, 1.4 * delta)
		base_y = p.global_position.y
	position.z += speed * delta
	var nx := base_x + sin(t * freq + phase) * amp_x
	var vx := (nx - position.x) / maxf(delta, 0.0001)
	position.x = clampf(nx, -10.0, 10.0)
	position.y = clampf(base_y, 0.9, 9.0)
	body.rotation.z = lerpf(body.rotation.z, clampf(-vx * 0.12, -0.9, 0.9), 1.0 - exp(-6.0 * delta))
	var dz: float = global_position.z - pz
	if p.alive and dz < -16.0 and dz > -70.0:
		fire_timer -= delta
		if fire_timer <= 0.0:
			fire_timer = randf_range(1.2, 2.6) * fire_gap
			if randf() < fire_chance:
				var dir: Vector3 = (p.global_position + Vector3(0, 0, -p.speed_forward * 0.6) - global_position).normalized()
				Game.spawn_shot(global_position + Vector3(0, 0, 1.4), dir * shot_speed, Color(1.0, 0.3, 0.75))
				Sfx.play("enemy_shot", -14.0, 1.3)
	if dz > 14.0:
		queue_free()
