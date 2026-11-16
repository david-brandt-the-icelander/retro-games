extends RefCounted
class_name FX
## One-shot particle + light effects built from code.


static func _particles(parent: Node3D, pos: Vector3, amount: int, life: float, mesh_radius: float,
		color_a: Color, color_b: Color, vel: Vector2, spread: float, gravity: Vector3,
		emission_energy: float, scale_curve := true) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.92
	p.position = pos
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = spread
	pm.initial_velocity_min = vel.x
	pm.initial_velocity_max = vel.y
	pm.gravity = gravity
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.4
	var grad := Gradient.new()
	grad.set_color(0, color_a)
	grad.set_color(1, color_b)
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	pm.color_ramp = gt
	if scale_curve:
		var c := Curve.new()
		c.add_point(Vector2(0, 0.4))
		c.add_point(Vector2(0.2, 1.0))
		c.add_point(Vector2(1, 0.0))
		var ct := CurveTexture.new()
		ct.curve = c
		pm.scale_curve = ct
	p.process_material = pm
	var sm := SphereMesh.new()
	sm.radius = mesh_radius
	sm.height = mesh_radius * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		mat.albedo_color = Color(emission_energy, emission_energy, emission_energy, 1.0)
	sm.material = mat
	p.draw_pass_1 = sm
	parent.add_child(p)
	p.emitting = true
	parent.get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)
	return p


static func _flash(parent: Node3D, pos: Vector3, color: Color, energy: float, rng: float, time: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos + Vector3(0, 1.0, 0)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, time).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


static func explosion(parent: Node3D, pos: Vector3) -> void:
	_particles(parent, pos + Vector3(0, 0.6, 0), 48, 0.9, 0.35,
		Color(1.0, 0.85, 0.4, 1.0), Color(0.15, 0.1, 0.08, 0.0), Vector2(3, 9), 80.0,
		Vector3(0, 2.0, 0), 4.0)
	_particles(parent, pos + Vector3(0, 0.4, 0), 24, 2.0, 0.6,
		Color(0.35, 0.3, 0.28, 0.8), Color(0.1, 0.1, 0.1, 0.0), Vector2(1, 3), 70.0,
		Vector3(0, 1.5, 0), 0.0)
	_flash(parent, pos, Color(1.0, 0.6, 0.25), 12.0, 9.0, 0.6)


static func gas(parent: Node3D, pos: Vector3) -> void:
	_particles(parent, pos + Vector3(0, 0.5, 0), 40, 2.6, 0.55,
		Color(0.5, 1.0, 0.35, 0.65), Color(0.2, 0.6, 0.15, 0.0), Vector2(0.5, 2.5), 90.0,
		Vector3(0, 0.4, 0), 1.5)
	_flash(parent, pos, Color(0.4, 1.0, 0.3), 4.0, 6.0, 1.6)


static func shock(parent: Node3D, pos: Vector3) -> void:
	_particles(parent, pos + Vector3(0, 0.3, 0), 60, 0.5, 0.06,
		Color(0.8, 0.95, 1.0, 1.0), Color(0.2, 0.5, 1.0, 0.0), Vector2(4, 10), 70.0,
		Vector3(0, -9.8, 0), 6.0, false)
	_flash(parent, pos, Color(0.5, 0.75, 1.0), 10.0, 6.0, 0.35)


static func punch(parent: Node3D, pos: Vector3) -> void:
	_particles(parent, pos + Vector3(0, 1.1, 0), 14, 0.35, 0.07,
		Color(1, 1, 1, 1), Color(1, 0.9, 0.6, 0), Vector2(2, 5), 60.0, Vector3.ZERO, 3.0, false)


static func sparkle(parent: Node3D, pos: Vector3, color: Color) -> void:
	_particles(parent, pos + Vector3(0, 1.0, 0), 30, 1.2, 0.05,
		Color(color.r, color.g, color.b, 1.0), Color(color.r, color.g, color.b, 0.0), Vector2(1, 3), 50.0,
		Vector3(0, 2.0, 0), 4.0, false)


static func float_text(parent: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.outline_size = 12
	l.modulate = color
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 2.4, 0)
	parent.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.4, 1.6).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.6).set_delay(0.6)
	tw.tween_callback(l.queue_free)
