extends RefCounted
## Explosion and dust effects.

const Meshes = preload("res://scripts/meshes.gd")


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _ramp(offsets: Array, colors: Array) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = Meshes.gradient(offsets, colors)
	return t


static func _billboard(additive: bool, shaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	if not shaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Meshes.soft_dot()
	return m


static func _emitter(root: Node3D, amount: int, life: float, pm: ParticleProcessMaterial, mesh: Mesh) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = true
	p.explosiveness = 0.95
	p.process_material = pm
	p.draw_pass_1 = mesh
	p.visibility_aabb = AABB(Vector3(-12, -4, -12), Vector3(24, 20, 24))
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(p)
	p.emitting = true
	return p


static func explosion(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos

	# Fireball
	var fire := ParticleProcessMaterial.new()
	fire.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = 0.5
	fire.direction = Vector3.UP
	fire.spread = 180.0
	fire.initial_velocity_min = 3.0
	fire.initial_velocity_max = 9.0
	fire.gravity = Vector3(0, 3, 0)
	fire.damping_min = 7.0
	fire.damping_max = 11.0
	fire.scale_min = 1.0
	fire.scale_max = 2.0
	fire.scale_curve = _curve([Vector2(0, 0.5), Vector2(0.15, 1.0), Vector2(1, 0.3)])
	fire.color_ramp = _ramp([0.0, 0.2, 0.5, 1.0], [Color(1, 0.95, 0.75, 1), Color(1, 0.55, 0.12, 1),
			Color(0.55, 0.14, 0.04, 0.7), Color(0.1, 0.05, 0.03, 0)])
	var q := QuadMesh.new()
	q.size = Vector2(1.6, 1.6)
	q.material = _billboard(true)
	_emitter(root, 48, 0.9, fire, q)

	# Smoke, lit by the sun
	var smoke := ParticleProcessMaterial.new()
	smoke.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	smoke.emission_sphere_radius = 0.8
	smoke.direction = Vector3.UP
	smoke.spread = 70.0
	smoke.initial_velocity_min = 1.0
	smoke.initial_velocity_max = 3.5
	smoke.gravity = Vector3(0.6, 1.4, 0)
	smoke.damping_min = 1.0
	smoke.damping_max = 2.0
	smoke.scale_min = 1.2
	smoke.scale_max = 2.2
	smoke.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.0)])
	smoke.color_ramp = _ramp([0.0, 0.15, 1.0], [Color(0.3, 0.27, 0.24, 0), Color(0.34, 0.31, 0.28, 0.75), Color(0.6, 0.56, 0.5, 0)])
	var sq := QuadMesh.new()
	sq.size = Vector2(2.6, 2.6)
	sq.material = _billboard(false, true)
	var sp := _emitter(root, 26, 2.8, smoke, sq)
	sp.explosiveness = 0.75

	# Stone and sand debris
	var deb := ParticleProcessMaterial.new()
	deb.direction = Vector3.UP
	deb.spread = 55.0
	deb.initial_velocity_min = 6.0
	deb.initial_velocity_max = 13.0
	deb.gravity = Vector3(0, -22, 0)
	deb.angular_velocity_min = -720.0
	deb.angular_velocity_max = 720.0
	deb.scale_min = 0.5
	deb.scale_max = 1.4
	deb.scale_curve = _curve([Vector2(0, 1), Vector2(0.8, 1), Vector2(1, 0)])
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.12, 0.16)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.55, 0.42, 0.3)
	dm.roughness = 1.0
	bm.material = dm
	_emitter(root, 26, 1.3, deb, bm)

	# Flash sphere and light
	var flash := Meshes.mesh_instance(Meshes.sphere(1.0, 20), Meshes.unshaded(Color(1.0, 0.75, 0.4, 0.9), true), root)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flash.scale = Vector3.ONE * 0.3
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = 12.0
	light.omni_range = 11.0
	light.position.y = 0.8
	root.add_child(light)

	# Scorch mark: a multiply-blended quad on whatever surface is below.
	var sg := GradientTexture2D.new()
	sg.gradient = Meshes.gradient([0.0, 0.45, 1.0], [Color(0.05, 0.035, 0.025, 0.8), Color(0.08, 0.06, 0.04, 0.45), Color(0.1, 0.08, 0.05, 0)])
	sg.fill = GradientTexture2D.FILL_RADIAL
	sg.fill_from = Vector2(0.5, 0.5)
	sg.fill_to = Vector2(1.0, 0.5)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_texture = sg
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var plane := PlaneMesh.new()
	plane.size = Vector2(4.5, 4.5)
	var decal := MeshInstance3D.new()
	decal.mesh = plane
	decal.material_override = sm
	decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(decal)
	var floor_y := pos.y
	var space := root.get_world_3d().direct_space_state
	var q2 := PhysicsRayQueryParameters3D.create(pos + Vector3.UP * 0.5, pos + Vector3.DOWN * 6.0, 1)
	var hit := space.intersect_ray(q2)
	if hit:
		floor_y = hit.position.y
	decal.global_position = Vector3(pos.x, floor_y + 0.02, pos.z)

	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(flash, "scale", Vector3.ONE * 3.8, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(flash.material_override, "albedo_color:a", 0.0, 0.3)
	tw.tween_property(light, "light_energy", 0.0, 0.7).set_ease(Tween.EASE_OUT)
	tw.chain().tween_callback(root.queue_free).set_delay(3.0)
	var dt := decal.create_tween()
	dt.tween_interval(8.0)
	dt.tween_property(decal, "scale", Vector3(0.01, 1, 0.01), 3.0).set_ease(Tween.EASE_IN)
	dt.tween_callback(decal.queue_free)


static func dust(parent: Node, pos: Vector3, amount := 14) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.6
	pm.direction = Vector3.UP
	pm.spread = 80.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.5
	pm.gravity = Vector3(0, 0.3, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 1.0)])
	pm.color_ramp = _ramp([0.0, 0.2, 1.0], [Color(0.8, 0.68, 0.5, 0), Color(0.8, 0.68, 0.5, 0.55), Color(0.85, 0.75, 0.6, 0)])
	var q := QuadMesh.new()
	q.size = Vector2(1.4, 1.4)
	q.material = _billboard(false, true)
	_emitter(root, amount, 1.6, pm, q)
	var tw := root.create_tween()
	tw.tween_interval(2.0)
	tw.tween_callback(root.queue_free)
