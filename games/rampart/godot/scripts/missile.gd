extends "res://scripts/target.gd"
## Vertical-launch missile from a silo. Rises through every altitude band.

const M = preload("res://scripts/mats.gd")

var speed: float = 7.5


func _ready() -> void:
	hp = 1
	points = 250
	explosion_size = 0.9
	setup_collision(Vector3(1.0, 2.3, 1.0))
	make_visual()
	var body := M.metal(Color(0.88, 0.88, 0.92), 0.3, 0.6)
	part(cyl(0.22, 0.24, 1.6, 12), body, Vector3.ZERO)
	part(cyl(0.0, 0.22, 0.55, 12), M.glow(Color(1.0, 0.2, 0.15), 5.0), Vector3(0, 1.07, 0))
	for i in 4:
		var a := i * PI / 2.0
		part(box(0.04, 0.5, 0.45), M.metal(Color(0.6, 0.1, 0.1), 0.4, 0.6), Vector3(cos(a) * 0.3, -0.55, sin(a) * 0.3), Vector3(0, -a, 0))
	part(sphere(0.3, 10), M.add(Color(1.0, 0.6, 0.2), 4.0, 1), Vector3(0, -0.95, 0), Vector3.ZERO, Vector3(1, 1.6, 1))
	var flame := CPUParticles3D.new()
	flame.amount = 40
	flame.lifetime = 0.5
	flame.local_coords = false
	flame.direction = Vector3.DOWN
	flame.spread = 12.0
	flame.initial_velocity_min = 3.0
	flame.initial_velocity_max = 6.0
	flame.gravity = Vector3.ZERO
	var fm := sphere(0.18, 6)
	fm.material = M.add(Color(1, 1, 1), 3.0, 1, true)
	flame.mesh = fm
	flame.scale_amount_curve = M.curve(1.0, 2.5)
	flame.color_ramp = M.gradient([Color(1, 0.9, 0.6, 1), Color(1, 0.4, 0.1, 0.7), Color(0.3, 0.3, 0.35, 0)])
	flame.position.y = -1.0
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	flame.emitting = true


func explosion_offset() -> Vector3:
	return Vector3.ZERO


func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y > 22.0:
		queue_free()
