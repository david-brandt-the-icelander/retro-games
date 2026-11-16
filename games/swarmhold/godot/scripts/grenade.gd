extends RigidBody3D

const Meshes = preload("res://scripts/meshes.gd")

var main: Node
var fuse := 1.7
var _done := false
var _blink: MeshInstance3D
var _blink_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("grenades")
	collision_layer = 16
	collision_mask = 1 | 4
	mass = 0.5
	contact_monitor = true
	max_contacts_reported = 4
	continuous_cd = true
	angular_damp = 1.5
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.35
	pm.friction = 0.7
	physics_material_override = pm
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.16
	cs.shape = sh
	add_child(cs)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.27, 0.16)
	m.metallic = 0.6
	m.roughness = 0.35
	Meshes.mesh_instance(Meshes.sphere(0.17, 16), m, self, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.15, 1))
	var cap := StandardMaterial3D.new()
	cap.albedo_color = Color(0.6, 0.6, 0.62)
	cap.metallic = 0.9
	cap.roughness = 0.3
	Meshes.mesh_instance(Meshes.cylinder(0.06, 0.07, 0.09, 10), cap, self, Vector3(0, 0.2, 0))
	_blink_mat = StandardMaterial3D.new()
	_blink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_blink_mat.albedo_color = Color(1.0, 0.2, 0.1)
	_blink = Meshes.mesh_instance(Meshes.sphere(0.04, 8), _blink_mat, self, Vector3(0, 0.25, 0))
	body_entered.connect(_on_body)


func _process(delta: float) -> void:
	fuse -= delta
	var rate := lerpf(4.0, 22.0, clampf(1.0 - fuse / 1.7, 0.0, 1.0))
	_blink.visible = sin(Time.get_ticks_msec() * 0.001 * rate * TAU) > 0.0
	if fuse <= 0.0:
		explode()


func _on_body(b: Node) -> void:
	if b.is_in_group("ants"):
		explode()


func explode() -> void:
	if _done:
		return
	_done = true
	main.explode_at(global_position)
	queue_free()
