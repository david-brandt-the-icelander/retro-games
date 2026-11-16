extends "res://scripts/entity.gd"
## Structures: construction, production queues, income, defensive weapons.

var complete := false
var progress := 0.0
var queue: Array = []
var prod_t := 0.0
var rally := Vector3.ZERO
var exit_point := Vector3.ZERO
var well = null
var size := 4.0
var anim_t := 0.0
var beam: Node3D = null
var gear: Node3D = null
var radar: Node3D = null
var beacon: Node3D = null
var dust: GPUParticles3D = null


func _ready() -> void:
	def = Game.BUILDINGS[kind]
	is_building = true
	size = float(def["size"])
	radius = size * 0.62
	rotation.y = Game.facing_yaw(position)
	visual = Models.build_building(kind, team)
	add_child(visual)
	_setup_common()
	var out := Vector3(-sin(rotation.y), 0.0, -cos(rotation.y))
	exit_point = position + out * (size * 0.5 + 2.8)
	rally = exit_point + out * 5.0
	beam = visual.find_child("Beam", true, false) as Node3D
	gear = visual.find_child("Gear", true, false) as Node3D
	radar = visual.find_child("Radar", true, false) as Node3D
	beacon = visual.find_child("Beacon", true, false) as Node3D
	anim_t = randf() * 10.0
	if complete:
		_finish(false)
	else:
		hp = max_hp * 0.1
		visual.scale = Vector3(1.0, 0.04, 1.0)
		dust = FX.dust_emitter(self, size)


func produces() -> Array:
	return def.get("produces", [])


## Called every physics frame by a constructor working on this structure.
func construct(delta: float) -> void:
	if not complete:
		var rate := delta / float(def["time"])
		progress = minf(1.0, progress + rate)
		hp = minf(max_hp, hp + max_hp * 0.9 * rate)
		visual.scale = Vector3(1.0, lerpf(0.04, 1.0, progress), 1.0)
		if progress >= 1.0:
			_finish(true)
	else:
		hp = minf(max_hp, hp + max_hp * 0.04 * delta)


func _finish(announce: bool) -> void:
	complete = true
	progress = 1.0
	visual.scale = Vector3.ONE
	if dust:
		dust.emitting = false
		FX.free_later(dust, 3.5)
		dust = null
	for m in visual.find_children("Smoke*", "Node3D", true, false):
		FX.smoke_emitter(m, Vector3.ZERO, float(m.get_meta("s", 1.0)), true, 1.0)
	if announce and team == Game.PLAYER:
		Game.notify("%s complete" % display_name())


func enqueue(k: String) -> bool:
	if not complete or queue.size() >= 6:
		return false
	var cost: int = Game.UNITS[k]["cost"]
	if Game.fuel[team] < cost:
		if team == Game.PLAYER:
			Game.notify("Insufficient fuel")
		return false
	Game.fuel[team] -= cost
	queue.append(k)
	return true


func cancel_last() -> void:
	if queue.is_empty():
		return
	var k: String = queue.pop_back()
	Game.fuel[team] += float(Game.UNITS[k]["cost"])
	if queue.is_empty():
		prod_t = 0.0


func production_ratio() -> float:
	if queue.is_empty():
		return 0.0
	return prod_t / float(Game.UNITS[queue[0]]["time"])


func queued(k: String) -> int:
	return queue.count(k)


func _process(delta: float) -> void:
	if dead or not complete:
		return
	anim_t += delta
	if beam:
		beam.rotation.x = sin(anim_t * 1.8) * 0.3
	if gear:
		gear.rotation.y += delta * 0.9
	if radar:
		radar.rotation.y += delta * 1.1
	if beacon:
		beacon.visible = fmod(anim_t, 1.6) < 0.25
	if not queue.is_empty():
		prod_t += delta
		if prod_t >= float(Game.UNITS[queue[0]]["time"]):
			prod_t = 0.0
			_spawn(queue.pop_front())
	if has_weapon():
		weapon_cd -= delta
		scan_cd -= delta
		if not Game.alive(auto_target) or not in_range(auto_target):
			auto_target = null
			if scan_cd <= 0.0:
				scan_cd = 0.4
				auto_target = find_target(0.0)
		var aimed := aim_turret(auto_target, delta)
		if auto_target != null and aimed and weapon_cd <= 0.0:
			fire_at(auto_target)


func _spawn(k: String) -> void:
	var p := exit_point
	if k == "zeppelin":
		p = position
	p += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0))
	var u = Game.world.spawn_unit(k, team, p, rotation.y)
	u.cmd_move(rally + Vector3(randf_range(-2.5, 2.5), 0.0, randf_range(-2.5, 2.5)))


func _start_burning() -> void:
	FX.fire_emitter(self, Vector3(randf_range(-1, 1), bar_height() * 0.45, randf_range(-1, 1)), clampf(size * 0.18, 0.6, 1.4))


func _on_death() -> void:
	var s := clampf(size * 0.4, 1.5, 3.6)
	FX.explosion(position + Vector3(0, 1.5, 0), s, true)
	for i in 3:
		var p := position + Vector3(randf_range(-size, size) * 0.4, randf_range(1.0, bar_height() * 0.6), randf_range(-size, size) * 0.4)
		get_tree().create_timer(0.25 + i * 0.3, false).timeout.connect(FX.explosion.bind(p, s * 0.7, false))
	var r := Models.rubble(size)
	r.position = position
	r.rotation = rotation
	Game.world.fx_root.add_child(r)
	var sm := FX.smoke_emitter(r, Vector3(0, 1.0, 0), clampf(size * 0.3, 1.0, 2.5), true, 0.8)
	FX.free_later(sm, 40.0)
	if well != null:
		well["owner"] = null
