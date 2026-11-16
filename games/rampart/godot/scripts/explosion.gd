extends Node3D
## One-shot explosion: streak sparks, fireball, debris, flash light and shock ring.

const M = preload("res://scripts/mats.gd")

static var _spark_mesh: Mesh
static var _ball_mesh: Mesh
static var _debris_mesh: Mesh
static var _ring_mesh: Mesh

var size: float = 1.0
var color: Color = Color(1.0, 0.55, 0.2)
var spark_only: bool = false
var t: float = 0.0
var life: float = 2.2
var light: OmniLight3D
var ring: MeshInstance3D
var ring_mat: ShaderMaterial


static func _init_meshes() -> void:
	if _spark_mesh != null:
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.035
	cm.bottom_radius = 0.035
	cm.height = 0.8
	cm.radial_segments = 4
	cm.rings = 1
	cm.material = M.add(Color(1, 1, 1, 1), 5.0, 0, true)
	_spark_mesh = cm
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 12
	sm.rings = 6
	sm.material = M.add(Color(1, 1, 1, 1), 3.0, 1, true)
	_ball_mesh = sm
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.12, 0.34)
	bm.material = M.metal(Color(0.25, 0.25, 0.28), 0.6, 0.7)
	_debris_mesh = bm
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_ring_mesh = pm


func _particles(amount: int, lifetime: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = 180.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25 * size
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p


func _ready() -> void:
	_init_meshes()
	var s := maxf(size, 0.5)

	var sparks := _particles(10 if spark_only else int(16 * size) + 10, 0.5 if spark_only else 1.0)
	sparks.mesh = _spark_mesh
	sparks.particle_flag_align_y = true
	sparks.initial_velocity_min = 5.0 * s
	sparks.initial_velocity_max = 17.0 * s
	sparks.gravity = Vector3(0, -14, 0)
	sparks.damping_min = 1.0
	sparks.damping_max = 3.0
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	sparks.color_ramp = M.gradient([Color(1, 1, 0.9, 1), Color(color.r, color.g, color.b, 1), Color(color.r * 0.6, color.g * 0.2, color.b * 0.1, 0)])
	sparks.emitting = true

	if spark_only:
		life = 0.7
		return

	var ball := _particles(int(6 + 5 * size), 0.8)
	ball.mesh = _ball_mesh
	ball.initial_velocity_min = 0.5 * s
	ball.initial_velocity_max = 3.5 * s
	ball.gravity = Vector3(0, 2.0, 0)
	ball.emission_sphere_radius = 0.45 * size
	ball.scale_amount_min = 0.7 * size
	ball.scale_amount_max = 1.4 * size
	ball.scale_amount_curve = M.curve(0.5, 1.6)
	ball.color_ramp = M.gradient([Color(1, 0.95, 0.75, 1), Color(color.r, color.g, color.b, 0.9), Color(color.r * 0.5, color.g * 0.2, color.b * 0.2, 0.45), Color(0.1, 0.02, 0.02, 0)])
	ball.emitting = true

	var debris := _particles(int(4 * size) + 2, 1.4)
	debris.mesh = _debris_mesh
	debris.initial_velocity_min = 5.0 * s
	debris.initial_velocity_max = 12.0 * s
	debris.gravity = Vector3(0, -22, 0)
	debris.scale_amount_min = 0.7
	debris.scale_amount_max = 1.6
	debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	debris.emitting = true

	light = OmniLight3D.new()
	light.light_color = color.lightened(0.3)
	light.light_energy = 6.0 * size
	light.omni_range = 5.0 + 5.0 * size
	light.position.y = 0.5
	add_child(light)

	ring = MeshInstance3D.new()
	ring.mesh = _ring_mesh
	ring_mat = M.add(color, 3.0, 3).duplicate()
	ring.material_override = ring_mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)

	Sfx.play("explosion" if size >= 1.0 else "small_boom", -4.0 + minf(size, 3.0) * 2.0, randf_range(0.85, 1.1) / sqrt(maxf(size, 0.6)))


func _process(delta: float) -> void:
	t += delta
	if light:
		light.light_energy = 6.0 * size * maxf(0.0, 1.0 - t / 0.45)
	if ring:
		var k := clampf(t / 0.55, 0.0, 1.0)
		var sc := 0.5 + k * 9.0 * size
		ring.scale = Vector3(sc, 1.0, sc)
		ring_mat.set_shader_parameter("color", Color(color.r, color.g, color.b, 1.0 - k))
	if t > life:
		queue_free()
