extends Node3D
## "The Warden" — the citadel's guardian. Its armour petals open
## periodically to expose the reactor core.

signal defeated

const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const CoreScript = preload("res://scripts/boss_core.gd")

var lvl: int = 1
var hp_max: int = 30
var core
var core_mat: StandardMaterial3D
var halo: MeshInstance3D
var petals: Array = []
var petal_closed: Array = []
var petal_open: Array = []
var ring_a: Node3D
var ring_b: Node3D
var pods: Array = []
var light: OmniLight3D
var t: float = 0.0
var open: bool = false
var open_amount: float = 0.0
var phase_timer: float = 3.0
var fire_timer: float = 1.5
var burst_timer: float = 2.5
var pod_index: int = 0
var dist: float = 90.0
var target_dist: float = 23.0
var dying: bool = false
var death_t: float = 0.0
var next_boom: float = 0.0
var flash: float = 0.0


func _ready() -> void:
	hp_max = 22 + 6 * lvl
	var dark := M.metal(Color(0.13, 0.12, 0.16), 0.35, 0.9)
	var mid := M.metal(Color(0.32, 0.3, 0.38), 0.3, 0.9)
	var pink := Color(1.0, 0.25, 0.75)

	core = CoreScript.new()
	core.boss = self
	core.hp = hp_max
	add_child(core)
	core_mat = StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.4, 0.05, 0.3)
	core_mat.emission_enabled = true
	core_mat.emission = pink
	core_mat.emission_energy_multiplier = 3.0
	_mesh(self, T.sphere(1.3, 24), core_mat, Vector3.ZERO)
	halo = _mesh(self, T.sphere(2.1, 20), M.add(pink, 0.7, 1), Vector3.ZERO)

	# Back plate and spikes
	_mesh(self, T.cyl(3.6, 3.8, 0.8, 32), dark, Vector3(0, 0, -1.7), Vector3(PI / 2, 0, 0))
	_mesh(self, T.cyl(2.4, 2.6, 0.5, 32), mid, Vector3(0, 0, -1.1), Vector3(PI / 2, 0, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 3.65
	rim.outer_radius = 3.85
	rim.rings = 48
	rim.ring_segments = 8
	_mesh(self, rim, M.glow(pink, 5.0), Vector3(0, 0, -1.3), Vector3(PI / 2, 0, 0))
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		_mesh(self, T.cyl(0.0, 0.38, 1.8, 8), mid, Vector3(cos(a) * 4.5, sin(a) * 4.5, -1.7), Vector3(0, 0, a - PI / 2))

	# Rotating rings
	ring_a = Node3D.new()
	add_child(ring_a)
	var ta := TorusMesh.new()
	ta.inner_radius = 5.0
	ta.outer_radius = 5.35
	ta.rings = 64
	ta.ring_segments = 8
	_mesh(ring_a, ta, mid, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	for i in 6:
		var a := TAU * i / 6.0
		_mesh(ring_a, T.box(0.6, 0.6, 0.5), M.glow(Color(0.4, 0.8, 1.0), 6.0), Vector3(cos(a) * 5.18, sin(a) * 5.18, 0))
	ring_b = Node3D.new()
	add_child(ring_b)
	var tb := TorusMesh.new()
	tb.inner_radius = 5.9
	tb.outer_radius = 6.05
	tb.rings = 64
	tb.ring_segments = 6
	_mesh(ring_b, tb, M.glow(pink, 2.5), Vector3.ZERO, Vector3(PI / 2 + 0.5, 0, 0))

	# Side cannon pods
	for s in [-1.0, 1.0]:
		var pod := Node3D.new()
		pod.position = Vector3(s * 4.4, -0.8, 0.2)
		add_child(pod)
		_mesh(pod, T.box(1.3, 1.1, 2.6), dark, Vector3.ZERO)
		_mesh(pod, T.cyl(0.25, 0.3, 1.0, 10), mid, Vector3(0, 0, 1.6), Vector3(PI / 2, 0, 0))
		_mesh(pod, T.sphere(0.24, 10), M.glow(pink, 8.0), Vector3(0, 0, 2.15))
		pods.append(pod)

	# Armour petals (block shots while closed)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var a := Area3D.new()
			a.collision_layer = 8
			a.collision_mask = 0
			a.monitoring = false
			a.monitorable = true
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(1.8, 1.8, 0.7)
			cs.shape = bs
			a.add_child(cs)
			_mesh(a, T.box(1.75, 1.75, 0.5), mid, Vector3.ZERO, Vector3(0, 0, 0))
			_mesh(a, T.box(1.4, 1.4, 0.1), dark, Vector3(0, 0, 0.28))
			_mesh(a, T.box(0.08, 1.75, 0.08), M.glow(Color(0.4, 0.8, 1.0), 5.0), Vector3(-sx * 0.86, 0, 0.27))
			_mesh(a, T.box(1.75, 0.08, 0.08), M.glow(Color(0.4, 0.8, 1.0), 5.0), Vector3(0, -sy * 0.86, 0.27))
			var closed := Vector3(sx * 0.88, sy * 0.88, 1.75)
			var opened := Vector3(sx * 2.6, sy * 2.6, 1.0)
			a.position = closed
			add_child(a)
			petals.append(a)
			petal_closed.append(closed)
			petal_open.append(opened)

	light = OmniLight3D.new()
	light.light_color = pink
	light.light_energy = 4.0
	light.omni_range = 20.0
	light.position.z = 2.5
	add_child(light)


func _mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	if mat is ShaderMaterial:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func health_ratio() -> float:
	if core == null or not is_instance_valid(core):
		return 0.0
	return clampf(float(core.hp) / float(hp_max), 0.0, 1.0)


func _process(delta: float) -> void:
	var p = Game.player
	if p == null:
		return
	t += delta
	dist = move_toward(dist, target_dist, delta * 22.0)
	position = Vector3(sin(t * 0.55) * 4.0, 4.8 + sin(t * 0.83) * 2.4, p.global_position.z - dist)
	ring_a.rotation.z += delta * 0.9
	ring_b.rotation.y += delta * 0.6
	ring_b.rotation.z -= delta * 0.3
	if dying:
		_update_death(delta)
		return

	phase_timer -= delta
	if phase_timer <= 0.0:
		open = not open
		phase_timer = 2.7 if open else 3.3
		if open:
			Sfx.play("boss_open", -4.0)
	open_amount = move_toward(open_amount, 1.0 if open else 0.0, delta * 3.5)
	var e := ease(open_amount, -2.0)
	for i in petals.size():
		petals[i].position = petal_closed[i].lerp(petal_open[i], e)
	flash = maxf(0.0, flash - delta * 6.0)
	core_mat.emission_energy_multiplier = 2.5 + open_amount * 5.0 + sin(t * 9.0) * 0.8 + flash * 12.0
	halo.scale = Vector3.ONE * (1.0 + open_amount * 0.25 + sin(t * 5.0) * 0.04)
	light.light_energy = 3.0 + open_amount * 4.0 + flash * 6.0

	if dist > target_dist + 4.0 or not p.alive:
		return
	var sp: float = p.speed_forward
	fire_timer -= delta
	if fire_timer <= 0.0:
		fire_timer = maxf(0.4, 1.05 - lvl * 0.1)
		var pod: Node3D = pods[pod_index]
		pod_index = (pod_index + 1) % pods.size()
		var from := pod.global_position + Vector3(0, 0, 2.3)
		var ppos: Vector3 = p.global_position
		var rel: Vector3 = (ppos - from).normalized() * 17.0
		Game.spawn_shot(from, rel + Vector3(0, 0, -sp), Color(1.0, 0.3, 0.8))
		Sfx.play("enemy_shot", -12.0, 0.8)
	if not open:
		burst_timer -= delta
		if burst_timer <= 0.0:
			burst_timer = maxf(1.8, 3.2 - lvl * 0.25)
			var n := 8 + 2 * mini(lvl, 4)
			for i in n:
				var a := TAU * i / n + t
				var rel := Vector3(cos(a) * 4.0, sin(a) * 4.0, 13.0)
				Game.spawn_shot(global_position + Vector3(0, 0, 2.0), rel + Vector3(0, 0, -sp), Color(0.5, 0.8, 1.0), true)
			Sfx.play("enemy_shot", -8.0, 0.55)


func on_core_hit() -> void:
	flash = 1.0
	Sfx.play("boss_hit", -6.0, randf_range(0.9, 1.1))
	Game.spawn_spark(global_position + Vector3(0, 0, 1.3), Color(1.0, 0.5, 0.9))
	Game.add_score(25)


func begin_death() -> void:
	dying = true
	death_t = 0.0
	for a in petals:
		a.set_deferred("monitorable", false)
	core.set_deferred("monitorable", false)
	for s in get_tree().get_nodes_in_group("enemy_shot"):
		s.queue_free()


func _update_death(delta: float) -> void:
	death_t += delta
	next_boom -= delta
	core_mat.emission_energy_multiplier = 8.0 + death_t * 10.0
	halo.scale = Vector3.ONE * (1.0 + death_t * 0.8)
	Game.shake(0.25)
	if next_boom <= 0.0:
		next_boom = 0.16
		var off := Vector3(randf_range(-4.5, 4.5), randf_range(-3.5, 3.5), randf_range(-1.5, 2.0))
		var col := Color(1.0, 0.35, 0.8) if randf() < 0.5 else Color(1.0, 0.6, 0.25)
		Game.spawn_explosion(global_position + off, randf_range(0.8, 1.6), col)
	if death_t > 2.4:
		var bonus := 5000 * lvl
		Game.add_score(bonus)
		Game.spawn_explosion(global_position, 4.0, Color(1.0, 0.4, 0.85))
		Game.spawn_explosion(global_position + Vector3(0, 0, 1), 3.0, Color(1.0, 0.75, 0.35))
		Game.popup(global_position + Vector3(0, 3, 0), "+%d" % bonus, Color(1.0, 0.6, 0.95))
		Game.shake(1.6)
		defeated.emit()
		queue_free()
