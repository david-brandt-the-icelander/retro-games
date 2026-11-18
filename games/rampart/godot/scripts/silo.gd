extends Node3D
## Floor hatch that fires a missile straight up as the ship approaches.

const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const MissileScript = preload("res://scripts/missile.gd")

var lvl: int = 1
var launched: bool = false
var trigger_dist: float = -20.0
var ring_mat: StandardMaterial3D
var doors: Array = []
var t: float = 0.0


func _ready() -> void:
	trigger_dist = -randf_range(15.0, 23.0)
	_mesh(T.cyl(1.25, 1.35, 0.16, 20), M.metal(Color(0.12, 0.13, 0.15), 0.5, 0.8), Vector3(0, 0.08, 0))
	ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.2, 0.1, 0.0)
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(1.0, 0.5, 0.1)
	ring_mat.emission_energy_multiplier = 3.0
	var tm := TorusMesh.new()
	tm.inner_radius = 1.12
	tm.outer_radius = 1.22
	tm.rings = 24
	tm.ring_segments = 6
	_mesh(tm, ring_mat, Vector3(0, 0.17, 0))
	for s in [-1.0, 1.0]:
		var d := _mesh(T.box(0.95, 0.08, 1.9), M.metal(Color(0.85, 0.7, 0.15), 0.4, 0.6), Vector3(s * 0.48, 0.2, 0))
		doors.append(d)
	for i in 4:
		var a := i * PI / 2.0 + PI / 4.0
		_mesh(T.box(0.25, 0.05, 0.6), M.glow(Color(1.0, 0.4, 0.1), 4.0), Vector3(cos(a) * 1.5, 0.03, sin(a) * 1.5), Vector3(0, -a, 0))


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	t += delta
	var p = Game.player
	if p == null:
		return
	var dz: float = global_position.z - p.global_position.z
	if not launched:
		var armed := dz > -45.0 and dz < 0.0
		ring_mat.emission_energy_multiplier = (3.0 + 4.0 * float(fmod(t, 0.4) < 0.2)) if armed else 2.0
		if p.alive and dz > trigger_dist and dz < 0.0:
			_launch()


func _launch() -> void:
	launched = true
	for d in doors:
		var tw := create_tween()
		tw.tween_property(d, "position:x", d.position.x * 3.0, 0.25)
	var m = MissileScript.new()
	m.speed = 7.0 + 0.6 * lvl
	m.position = global_position + Vector3(0, 0.3, 0)
	get_parent().add_child(m)
	Sfx.play("launch", -6.0)
