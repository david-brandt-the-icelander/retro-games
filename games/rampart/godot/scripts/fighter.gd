extends "res://scripts/target.gd"
## Interceptor that weaves toward the ship in open space. It cruises at an altitude of its own,
## dives to the ship's altitude for an attack run before it fires, climbs or drops away after
## firing, and jinks up or down when the ship lines up on it and shoots. Between runs it shifts
## to a new cruising altitude every few seconds. Not every run ends in a shot (fire_chance).

const M = preload("res://scripts/mats.gd")

var active: bool = false
var base_x: float = 0.0
var base_y: float = 4.0
var amp_x: float = 3.0
var amp_y: float = 1.0
var freq: float = 1.3
var phase: float = 0.0
var speed: float = 9.0
var fire_chance: float = 0.3
var fire_gap: float = 1.0
var shot_speed: float = 20.0
## How fast it changes altitude on an attack run or a jink, and how likely it is to jink.
var climb_rate: float = 3.0
var evade_chance: float = 0.4
var evade_cooldown: float = 1.6
var attack_lead: float = 1.0
var attack_chance: float = 0.6
var cruise_y: float = 4.0
var cruise_timer: float = 2.0
var attacking: bool = false
var evade_offset: float = 0.0
var evade_target: float = 0.0
var evade_hold: float = 0.0
var evade_cd: float = 0.0
var last_y: float = 0.0
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
	last_y = position.y
	cruise_y = base_y
	cruise_timer = randf_range(1.5, 3.0)
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
	var py: float = p.global_position.y
	var dz: float = global_position.z - pz
	if p.alive:
		base_x = move_toward(base_x, p.global_position.x, 1.4 * delta)
		if attacking:
			# Attack run: dive or climb to the ship's altitude, so the shot lines up.
			base_y = move_toward(base_y, py, climb_rate * delta)
		else:
			cruise_timer -= delta
			if cruise_timer <= 0.0:
				cruise_timer = randf_range(1.8, 3.2)
				cruise_y = randf_range(1.5, 8.5)
			base_y = move_toward(base_y, cruise_y, climb_rate * 0.5 * delta)
		_evade(p, dz, delta)
	position.z += speed * delta
	var nx := base_x + sin(t * freq + phase) * amp_x
	var amp := amp_y * (0.3 if attacking else 1.0)
	var ny := base_y + sin(t * freq * 0.7 + phase * 1.3) * amp + evade_offset
	var vx := (nx - position.x) / maxf(delta, 0.0001)
	position.x = clampf(nx, -10.0, 10.0)
	position.y = clampf(ny, 0.9, 9.0)
	var vy := (position.y - last_y) / maxf(delta, 0.0001)
	last_y = position.y
	body.rotation.z = lerpf(body.rotation.z, clampf(-vx * 0.12, -0.9, 0.9), 1.0 - exp(-6.0 * delta))
	body.rotation.x = lerpf(body.rotation.x, clampf(vy * 0.08, -0.6, 0.6), 1.0 - exp(-6.0 * delta))
	if p.alive and dz < -16.0 and dz > -70.0:
		fire_timer -= delta
		if not attacking and fire_timer <= attack_lead and fire_timer > 0.0:
			if randf() < attack_chance:
				attacking = true
			else:
				fire_timer = randf_range(1.2, 2.6) * fire_gap
		if fire_timer <= 0.0:
			fire_timer = randf_range(1.2, 2.6) * fire_gap
			if attacking:
				attacking = false
				if randf() < fire_chance:
					var dir: Vector3 = (p.global_position + Vector3(0, 0, -p.speed_forward * 0.6) - global_position).normalized()
					Game.spawn_shot(global_position + Vector3(0, 0, 1.4), dir * shot_speed, Color(1.0, 0.3, 0.75))
					Sfx.play("enemy_shot", -14.0, 1.3)
				_break_away(py)
	if dz > 14.0:
		queue_free()


## After firing, peel off to a cruising altitude well clear of the ship's.
func _break_away(py: float) -> void:
	var up := py < 5.0
	if randf() < 0.25:
		up = not up
	var gap := randf_range(2.5, 4.0)
	cruise_y = clampf(py + (gap if up else -gap), 1.5, 8.5)
	cruise_timer = randf_range(1.8, 3.2)


## Jink up or down when the ship has it lined up and is shooting.
func _evade(p, dz: float, delta: float) -> void:
	evade_cd -= delta
	if evade_hold > 0.0:
		evade_hold -= delta
		if evade_hold <= 0.0:
			evade_target = 0.0
	evade_offset = move_toward(evade_offset, evade_target, climb_rate * 1.8 * delta)
	if evade_cd > 0.0 or dz > -6.0 or dz < -60.0:
		return
	var lined_up := absf(p.global_position.x - position.x) < 2.2 and absf(p.global_position.y - position.y) < 1.4
	var shooting: bool = Input.is_action_pressed("fire") or Game.autopilot
	if not (lined_up and shooting):
		return
	evade_cd = evade_cooldown
	if randf() >= evade_chance:
		return
	var y := position.y
	var room_up := 9.0 - y
	var room_down := y - 0.9
	var dir := 1.0 if room_up > room_down else -1.0
	if minf(room_up, room_down) > 2.5 and randf() < 0.5:
		dir = -dir
	var room := room_up if dir > 0.0 else room_down
	evade_target = evade_offset + dir * minf(randf_range(2.2, 3.5), room - 0.2)
	evade_hold = randf_range(0.6, 1.0)
