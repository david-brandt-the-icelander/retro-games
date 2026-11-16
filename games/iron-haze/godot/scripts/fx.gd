extends Node
## Visual effects library (autoload "FX"): smoke, fire, explosions, decals, markers.
## Everything is GPU particles driven by procedurally generated textures.

var soft_tex: GradientTexture2D
var scorch_tex: GradientTexture2D
var quad: QuadMesh
var mat_smoke: StandardMaterial3D
var mat_add: StandardMaterial3D
var _pm := {}
var _decals: Array = []


func _ready() -> void:
	soft_tex = _radial(PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)]),
		PackedFloat32Array([0.0, 0.45, 1.0]))
	scorch_tex = _radial(PackedColorArray([Color(0.02, 0.016, 0.012, 0.95), Color(0.04, 0.03, 0.02, 0.75),
		Color(0.05, 0.04, 0.03, 0.0)]), PackedFloat32Array([0.0, 0.55, 1.0]))
	quad = QuadMesh.new()
	mat_smoke = _particle_mat(false)
	mat_add = _particle_mat(true)


func reset() -> void:
	_decals.clear()


func root() -> Node3D:
	return Game.world.fx_root


func free_later(n: Node, t: float) -> void:
	get_tree().create_timer(t, false).timeout.connect(func():
		if is_instance_valid(n):
			n.queue_free())


# ---------------------------------------------------------------- resources

func _radial(colors: PackedColorArray, offsets: PackedFloat32Array) -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = offsets
	g.colors = colors
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 64
	t.height = 64
	return t


func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	t.use_hdr = true
	return t


func _curve(a: float, b: float) -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	var t := CurveTexture.new()
	t.curve = c
	return t


func _particle_mat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	m.proximity_fade_enabled = true
	m.proximity_fade_distance = 0.8
	m.disable_receive_shadows = true
	return m


## Particle process materials, cached by "kind:size[:variant]".
func _process_mat(key: String) -> ParticleProcessMaterial:
	if _pm.has(key):
		return _pm[key]
	var parts := key.split(":")
	var kind := parts[0]
	var s := float(parts[1])
	var variant := parts[2] if parts.size() > 2 else ""
	var p := ParticleProcessMaterial.new()
	p.angle_min = -180.0
	p.angle_max = 180.0
	match kind:
		"smoke":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.25 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 12.0
			p.initial_velocity_min = 1.0 * s
			p.initial_velocity_max = 2.0 * s
			p.gravity = Vector3(0.9, 0.35, 0.35)
			p.damping_min = 0.2
			p.damping_max = 0.5
			p.scale_min = 0.9 * s
			p.scale_max = 1.7 * s
			p.scale_curve = _curve(0.35, 1.0)
			p.angular_velocity_min = -15.0
			p.angular_velocity_max = 15.0
			var c := Color(0.17, 0.16, 0.15) if variant == "d" else Color(0.62, 0.6, 0.57)
			p.color_ramp = _ramp([Color(c, 0.0), Color(c, 0.75), Color(c.lightened(0.25), 0.4), Color(c.lightened(0.4), 0.0)],
				[0.0, 0.08, 0.5, 1.0])
		"fire":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.35 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 1.5 * s
			p.initial_velocity_max = 5.0 * s
			p.gravity = Vector3(0, 2.0, 0)
			p.damping_min = 3.0
			p.damping_max = 5.0
			p.scale_min = 1.2 * s
			p.scale_max = 2.6 * s
			p.scale_curve = _curve(0.45, 1.0)
			p.color_ramp = _ramp([Color(3.0, 2.4, 1.4, 1.0), Color(2.6, 1.0, 0.25, 0.9), Color(0.6, 0.18, 0.05, 0.5),
				Color(0.1, 0.05, 0.03, 0.0)], [0.0, 0.2, 0.55, 1.0])
		"esmoke":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.5 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 70.0
			p.initial_velocity_min = 1.0 * s
			p.initial_velocity_max = 3.5 * s
			p.gravity = Vector3(0.4, 1.0, 0.2)
			p.damping_min = 1.5
			p.damping_max = 2.5
			p.scale_min = 1.6 * s
			p.scale_max = 3.2 * s
			p.scale_curve = _curve(0.4, 1.0)
			p.angular_velocity_min = -20.0
			p.angular_velocity_max = 20.0
			p.color_ramp = _ramp([Color(0.12, 0.1, 0.09, 0.0), Color(0.14, 0.12, 0.1, 0.85), Color(0.3, 0.28, 0.26, 0.45),
				Color(0.4, 0.38, 0.36, 0.0)], [0.0, 0.12, 0.55, 1.0])
		"spark":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.2 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 75.0
			p.initial_velocity_min = 5.0 * sqrt(s)
			p.initial_velocity_max = 14.0 * sqrt(s)
			p.gravity = Vector3(0, -16, 0)
			p.scale_min = 0.08
			p.scale_max = 0.18
			p.color_ramp = _ramp([Color(4.0, 2.6, 1.2, 1.0), Color(2.4, 0.9, 0.2, 1.0), Color(0.6, 0.15, 0.05, 0.0)],
				[0.0, 0.5, 1.0])
		"dirt":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.3 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 40.0
			p.initial_velocity_min = 4.0 * sqrt(s)
			p.initial_velocity_max = 10.0 * sqrt(s)
			p.gravity = Vector3(0, -14, 0)
			p.scale_min = 0.25 * s
			p.scale_max = 0.6 * s
			p.color_ramp = _ramp([Color(0.16, 0.12, 0.08, 1.0), Color(0.2, 0.16, 0.12, 0.8), Color(0.25, 0.2, 0.15, 0.0)],
				[0.0, 0.7, 1.0])
		"flash":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 2.0 * s
			p.scale_min = 0.6 * s
			p.scale_max = 1.2 * s
			p.color_ramp = _ramp([Color(4.0, 3.0, 1.6, 1.0), Color(2.0, 0.8, 0.2, 0.0)], [0.0, 1.0])
		"hit":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			p.direction = Vector3(0, 1, 0)
			p.spread = 60.0
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 3.0
			p.gravity = Vector3(0, -3, 0)
			p.scale_min = 0.3
			p.scale_max = 0.7
			p.color_ramp = _ramp([Color(0.35, 0.3, 0.24, 0.7), Color(0.4, 0.35, 0.3, 0.0)], [0.0, 1.0])
		"trail":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
			p.direction = Vector3(0, 1, 0)
			p.spread = 180.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.4
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_min = 0.4 * s
			p.scale_max = 0.7 * s
			p.scale_curve = _curve(0.5, 1.0)
			p.color_ramp = _ramp([Color(0.5, 0.48, 0.45, 0.6), Color(0.6, 0.58, 0.55, 0.0)], [0.0, 1.0])
		"dust":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			p.emission_box_extents = Vector3(s * 0.5, 0.3, s * 0.5)
			p.direction = Vector3(0, 1, 0)
			p.spread = 30.0
			p.initial_velocity_min = 0.5
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0.3, 0.2, 0.1)
			p.scale_min = 1.0
			p.scale_max = 2.4
			p.scale_curve = _curve(0.4, 1.0)
			p.color_ramp = _ramp([Color(0.5, 0.42, 0.32, 0.0), Color(0.5, 0.42, 0.32, 0.45), Color(0.55, 0.48, 0.4, 0.0)],
				[0.0, 0.2, 1.0])
		"burn":
			p.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.5 * s
			p.direction = Vector3(0, 1, 0)
			p.spread = 15.0
			p.initial_velocity_min = 1.0 * s
			p.initial_velocity_max = 2.4 * s
			p.gravity = Vector3(0, 1.5, 0)
			p.scale_min = 0.6 * s
			p.scale_max = 1.3 * s
			p.scale_curve = _curve(1.0, 0.2)
			p.color_ramp = _ramp([Color(3.0, 1.8, 0.6, 0.0), Color(3.0, 1.4, 0.35, 0.9), Color(1.2, 0.3, 0.05, 0.0)],
				[0.0, 0.15, 1.0])
		_:
			push_warning("Unknown particle kind: " + kind)
	_pm[key] = p
	return p


func _particles(key: String, amount: int, lifetime: float, additive: bool, one_shot: bool) -> GPUParticles3D:
	var g := GPUParticles3D.new()
	g.amount = maxi(amount, 1)
	g.lifetime = lifetime
	g.one_shot = one_shot
	if one_shot:
		g.explosiveness = 0.92
	g.randomness = 0.3
	g.process_material = _process_mat(key)
	g.draw_pass_1 = quad
	g.material_override = mat_add if additive else mat_smoke
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.visibility_aabb = AABB(Vector3(-25, -10, -25), Vector3(50, 60, 50))
	return g


# ---------------------------------------------------------------- continuous emitters

func smoke_emitter(parent: Node3D, pos: Vector3, s: float, dark: bool = true, rate: float = 1.0) -> GPUParticles3D:
	var g := _particles("smoke:%.2f:%s" % [s, "d" if dark else "l"], int(16.0 * rate) + 4, 4.5, false, false)
	g.position = pos
	parent.add_child(g)
	return g


func fire_emitter(parent: Node3D, pos: Vector3, s: float) -> Node3D:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var f := _particles("burn:%.1f" % s, 14, 0.8, true, false)
	holder.add_child(f)
	var sm := _particles("smoke:%.2f:d" % (s * 0.9), 14, 4.0, false, false)
	sm.position = Vector3(0, 0.8 * s, 0)
	holder.add_child(sm)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.2)
	light.light_energy = 1.6
	light.omni_range = 4.0 + 3.0 * s
	holder.add_child(light)
	return holder


func dust_emitter(parent: Node3D, s: float) -> GPUParticles3D:
	var g := _particles("dust:%.1f" % s, int(8 + s * 2), 3.0, false, false)
	g.position = Vector3(0, 0.4, 0)
	parent.add_child(g)
	return g


func trail(parent: Node3D) -> GPUParticles3D:
	var g := _particles("trail:1.0", 40, 1.0, false, false)
	parent.add_child(g)
	return g


# ---------------------------------------------------------------- one-shots

func _burst(key: String, pos: Vector3, amount: int, lifetime: float, additive: bool) -> GPUParticles3D:
	var g := _particles(key, amount, lifetime, additive, true)
	g.position = pos
	root().add_child(g)
	g.emitting = true
	free_later(g, lifetime + 0.6)
	return g


func _flash_light(pos: Vector3, energy: float, rng: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.light_energy = energy
	l.omni_range = rng
	l.position = pos
	root().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur).set_ease(Tween.EASE_OUT)
	tw.tween_callback(l.queue_free)


func explosion(pos: Vector3, s: float, ground: bool = true) -> void:
	s = snappedf(clampf(s, 0.3, 5.0), 0.1)
	_burst("fire:%.1f" % s, pos, 12 + int(6 * s), 0.9, true)
	_burst("esmoke:%.1f" % s, pos + Vector3(0, 0.4 * s, 0), 8 + int(4 * s), 3.4, false)
	_burst("spark:%.1f" % s, pos, 16 + int(10 * s), 1.1, true)
	if ground:
		_burst("dirt:%.1f" % s, pos, 10 + int(4 * s), 1.3, false)
		scorch(pos, s)
	_flash_light(pos + Vector3(0, 1.0, 0), 4.0 + 3.0 * s, 5.0 + 4.0 * s, 0.45)


func muzzle(pos: Vector3, s: float) -> void:
	s = snappedf(s, 0.1)
	_burst("flash:%.1f" % s, pos, 5, 0.14, true)
	if s >= 0.8:
		_flash_light(pos, 3.0 * s, 4.0 * s, 0.1)
		_burst("esmoke:%.1f" % (s * 0.35), pos, 4, 1.6, false)


func impact(weapon: String, pos: Vector3) -> void:
	var gh: float = Game.world.height_at(pos.x, pos.z)
	var on_ground := pos.y - gh < 2.5
	match weapon:
		"rifle":
			_burst("hit:1.0", pos, 4, 0.5, false)
			_burst("spark:0.3", pos, 4, 0.4, true)
		"cannon":
			explosion(pos, 1.0, on_ground)
		"artillery":
			explosion(pos, 1.8, on_ground)
		"bombs":
			explosion(pos, 2.3, on_ground)
		"flak":
			explosion(pos, 0.7, on_ground)


func scorch(pos: Vector3, s: float) -> void:
	if Game.compat:
		return
	var d := Decal.new()
	d.texture_albedo = scorch_tex
	d.size = Vector3(2.8 * s, 4.0, 2.8 * s)
	d.position = pos
	d.rotation.y = randf() * TAU
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.cull_mask = 2
	root().add_child(d)
	_decals.append(d)
	if _decals.size() > 90:
		var old = _decals.pop_front()
		if is_instance_valid(old):
			old.queue_free()


func spark_burst(pos: Vector3) -> void:
	_burst("spark:0.4", pos, 6, 0.6, true)


func order_marker(pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.15
	tm.rings = 32
	tm.ring_segments = 6
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.25, 0)
	mi.scale = Vector3(1.4, 0.4, 1.4)
	root().add_child(mi)
	var tw := mi.create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(0.2, 0.4, 0.2), 0.45)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)


## A destroyed vehicle: burns for a while, then sinks into the ground.
func wreck(v: Node3D) -> void:
	fire_emitter(v, Vector3(0, 1.2, 0), 0.7)
	var tw := v.create_tween()
	tw.tween_interval(14.0)
	tw.tween_property(v, "position:y", v.position.y - 3.0, 3.0)
	tw.tween_callback(v.queue_free)


## A destroyed airship: plunges nose-first, explodes on impact, then smoulders.
func crash(v: Node3D) -> void:
	fire_emitter(v, Vector3(0, 1.0, -2.0), 1.6)
	fire_emitter(v, Vector3(0, 0.5, 3.0), 1.2)
	var ground: float = Game.world.height_at(v.position.x, v.position.z)
	var tw := v.create_tween().set_parallel()
	tw.tween_property(v, "position:y", ground + 1.5, 3.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(v, "rotation:x", v.rotation.x - 0.45, 3.2)
	tw.tween_property(v, "rotation:z", v.rotation.z + 0.3, 3.2)
	tw.chain().tween_callback(func(): explosion(v.position, 3.2, true))
	tw.chain().tween_interval(12.0)
	tw.chain().tween_property(v, "position:y", ground - 6.0, 4.0)
	tw.chain().tween_callback(v.queue_free)
