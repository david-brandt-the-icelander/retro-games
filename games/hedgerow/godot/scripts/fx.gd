class_name FX
extends RefCounted
## Particle and light effects: muzzle flashes, tracers, explosions, smoke.


static func _pmat(emissive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	if emissive:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func particles(parent: Node3D, pos: Vector3, c0: Color, c1: Color, amount: int, size: float, vel: float,
		life: float, grav: float, spread: float, emissive: bool, persist: bool = false) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _pmat(emissive)
	p.mesh = q
	p.amount = maxi(amount, 1)
	p.lifetime = life
	p.one_shot = not persist
	p.explosiveness = 0.0 if persist else 0.85
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = vel * 0.4
	p.initial_velocity_max = vel
	p.gravity = Vector3(0, grav, 0)
	p.damping_min = 0.5
	p.damping_max = 1.5
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	var curve := Curve.new()
	curve.max_value = 3.0
	curve.add_point(Vector2(0.0, 0.5))
	curve.add_point(Vector2(1.0, 2.0))
	p.scale_amount_curve = curve
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	p.color_ramp = g
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	if not persist:
		var t := p.get_tree().create_timer(life + 0.8)
		t.timeout.connect(p.queue_free)
	return p


static func flash_light(parent: Node3D, pos: Vector3, energy: float, rng: float, dur: float, col: Color = Color(1.0, 0.7, 0.35)) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


static func muzzle_flash(parent: Node3D, pos: Vector3, strength: float = 1.0) -> void:
	flash_light(parent, pos, 6.0 * strength, 1.5 + 2.0 * strength, 0.18)
	particles(parent, pos, Color(2.0, 1.5, 0.7, 1.0), Color(1.0, 0.35, 0.1, 0.0), int(6 * strength) + 2,
		0.06 + 0.12 * strength, 1.2, 0.15, 0.0, 35.0, true)
	if strength > 0.5:
		particles(parent, pos, Color(0.65, 0.63, 0.6, 0.55), Color(0.7, 0.7, 0.7, 0.0), 5, 0.3 * strength, 0.5, 1.2, 0.35, 60.0, false)


static func tracer(parent: Node3D, from: Vector3, to: Vector3, col: Color, dur: float, thick: float) -> Signal:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = thick
	cm.height = maxf(0.25, thick * 10.0)
	cm.radial_segments = 6
	cm.rings = 1
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(col.r * 3.0, col.g * 3.0, col.b * 3.0)
	cm.material = m
	mi.mesh = cm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	var dir: Vector3 = (to - from).normalized()
	var b := Basis.IDENTITY
	if absf(dir.dot(Vector3.UP)) < 0.999:
		b = Basis(Quaternion(Vector3.UP, dir))
	mi.global_transform = Transform3D(b, from)
	var tw := mi.create_tween()
	tw.tween_property(mi, "global_position", to, dur)
	tw.tween_callback(mi.queue_free)
	return tw.finished


static func dust(parent: Node3D, pos: Vector3, strength: float = 1.0) -> void:
	particles(parent, pos, Color(0.45, 0.38, 0.28, 0.85), Color(0.55, 0.5, 0.42, 0.0), int(8 * strength) + 2,
		0.25 * strength + 0.1, 1.8 * strength, 1.1, -1.0, 55.0, false)
	particles(parent, pos, Color(0.25, 0.2, 0.15, 1.0), Color(0.25, 0.2, 0.15, 0.0), int(6 * strength),
		0.05, 3.0 * strength, 0.8, -9.0, 45.0, false)
	if strength > 1.0:
		flash_light(parent, pos + Vector3(0, 0.2, 0), 3.0, 2.5, 0.25)


static func sparks(parent: Node3D, pos: Vector3) -> void:
	flash_light(parent, pos, 4.0, 2.0, 0.15, Color(1.0, 0.85, 0.5))
	particles(parent, pos, Color(3.0, 2.4, 1.2, 1.0), Color(1.0, 0.4, 0.1, 0.0), 18, 0.04, 4.0, 0.5, -8.0, 80.0, true)


static func explosion(parent: Node3D, pos: Vector3) -> void:
	flash_light(parent, pos + Vector3(0, 0.4, 0), 12.0, 6.0, 0.6)
	particles(parent, pos + Vector3(0, 0.2, 0), Color(2.6, 1.5, 0.5, 1.0), Color(0.8, 0.2, 0.05, 0.0), 28, 0.35, 2.6, 0.7, 1.0, 70.0, true)
	particles(parent, pos + Vector3(0, 0.2, 0), Color(0.12, 0.1, 0.08, 1.0), Color(0.12, 0.1, 0.08, 0.0), 16, 0.07, 4.5, 1.2, -9.0, 50.0, false)
	particles(parent, pos + Vector3(0, 0.3, 0), Color(0.22, 0.21, 0.2, 0.85), Color(0.5, 0.5, 0.5, 0.0), 16, 0.7, 1.1, 2.4, 0.5, 60.0, false)


static func smoke_column(parent: Node3D, pos: Vector3) -> void:
	particles(parent, pos, Color(0.12, 0.11, 0.1, 0.75), Color(0.45, 0.45, 0.45, 0.0), 26, 0.55, 0.5, 4.5, 0.35, 12.0, false, true)
	particles(parent, pos, Color(2.4, 1.2, 0.3, 0.9), Color(0.8, 0.2, 0.05, 0.0), 10, 0.18, 0.4, 0.6, 0.6, 20.0, true, true)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 1.2
	l.omni_range = 2.0
	parent.add_child(l)
	l.global_position = pos + Vector3(0, 0.15, 0)
