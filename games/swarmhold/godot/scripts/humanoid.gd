extends Node3D
## A simple stylised person built from capsules, with a procedural walk cycle.
## Faces -Z.

const Meshes = preload("res://scripts/meshes.gd")

var torso: Node3D
var larm: Node3D
var rarm: Node3D
var lleg: Node3D
var rleg: Node3D
var phase := 0.0
var t := 0.0
var waving := false
var throw_t := 0.0
var flash_t := 0.0
var _mats: Array[StandardMaterial3D] = []


func _mat(c: Color, rough := 0.65) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.rim_enabled = true
	m.rim = 0.25
	_mats.append(m)
	return m


func build(shirt: Color, pants: Color, skin: Color, hair: Color, backpack := false) -> void:
	var ms := _mat(shirt)
	var mp := _mat(pants, 0.8)
	var mk := _mat(skin, 0.5)
	var mh := _mat(hair, 0.85)
	var mb := _mat(Color(0.16, 0.12, 0.09), 0.6)
	torso = Node3D.new()
	add_child(torso)
	Meshes.mesh_instance(Meshes.capsule(0.2, 0.72), ms, torso, Vector3(0, 1.3, 0), Vector3.ZERO, Vector3(1.15, 1, 0.78))
	Meshes.mesh_instance(Meshes.capsule(0.17, 0.42), mp, torso, Vector3(0, 0.99, 0), Vector3.ZERO, Vector3(1.2, 1, 0.82))
	Meshes.mesh_instance(Meshes.cylinder(0.205, 0.205, 0.07, 16), mb, torso, Vector3(0, 1.08, 0), Vector3.ZERO, Vector3(1.16, 1, 0.8))
	Meshes.mesh_instance(Meshes.capsule(0.065, 0.16), mk, torso, Vector3(0, 1.62, 0))
	Meshes.mesh_instance(Meshes.sphere(0.14), mk, torso, Vector3(0, 1.76, 0), Vector3.ZERO, Vector3(0.95, 1.08, 1.0))
	Meshes.mesh_instance(Meshes.sphere(0.148), mh, torso, Vector3(0, 1.81, 0.035), Vector3.ZERO, Vector3(1.0, 0.82, 0.98))
	if backpack:
		Meshes.mesh_instance(Meshes.capsule(0.15, 0.42), mb, torso, Vector3(0, 1.3, 0.2), Vector3.ZERO, Vector3(1.2, 1, 0.7))
		for sx in [-1, 1]:
			Meshes.mesh_instance(Meshes.sphere(0.06), _mat(Color(0.2, 0.32, 0.12), 0.5), torso, Vector3(sx * 0.12, 1.12, 0.3))
	larm = _limb(Vector3(-0.28, 1.53, 0), 0.068, 0.6, ms, mk, false)
	rarm = _limb(Vector3(0.28, 1.53, 0), 0.068, 0.6, ms, mk, false)
	lleg = _limb(Vector3(-0.11, 0.96, 0), 0.085, 0.88, mp, mb, true)
	rleg = _limb(Vector3(0.11, 0.96, 0), 0.085, 0.88, mp, mb, true)


func _limb(pos: Vector3, r: float, length: float, mat: Material, end_mat: Material, foot: bool) -> Node3D:
	var p := Node3D.new()
	p.position = pos
	torso.add_child(p)
	Meshes.mesh_instance(Meshes.capsule(r, length), mat, p, Vector3(0, -length * 0.5, 0))
	if foot:
		var b := BoxMesh.new()
		b.size = Vector3(0.15, 0.09, 0.28)
		Meshes.mesh_instance(b, end_mat, p, Vector3(0, -length + 0.0, -0.05))
	else:
		Meshes.mesh_instance(Meshes.sphere(r * 1.2), end_mat, p, Vector3(0, -length - 0.02, 0))
	return p


func animate(spd: float, delta: float, on_floor: bool) -> void:
	t += delta
	var s := clampf(spd, 0.0, 1.2)
	phase += delta * (2.0 + 9.0 * s)
	var sw := sin(phase) * 0.8 * s
	var k := 1.0 - exp(-14.0 * delta)
	if on_floor:
		lleg.rotation.x = lerpf(lleg.rotation.x, sw, k)
		rleg.rotation.x = lerpf(rleg.rotation.x, -sw, k)
		larm.rotation.x = lerpf(larm.rotation.x, -sw * 0.9, k)
		rarm.rotation.x = lerpf(rarm.rotation.x, sw * 0.9, k)
		torso.position.y = absf(sin(phase)) * 0.06 * s + sin(t * 2.0) * 0.006
		torso.rotation.x = lerpf(torso.rotation.x, -0.12 * s, k)
	else:
		lleg.rotation.x = lerpf(lleg.rotation.x, -0.7, k)
		rleg.rotation.x = lerpf(rleg.rotation.x, 0.35, k)
		larm.rotation.x = lerpf(larm.rotation.x, -1.6, k)
		rarm.rotation.x = lerpf(rarm.rotation.x, -1.3, k)
	larm.rotation.z = -0.08
	rarm.rotation.z = 0.08
	if waving:
		rarm.rotation.z = 2.6 + sin(t * 9.0) * 0.35
		rarm.rotation.x = 0.0
		larm.rotation.z = -0.35 - sin(t * 9.0 + 1.0) * 0.2
	if throw_t > 0.0:
		throw_t -= delta
		var f := 1.0 - throw_t / 0.35
		rarm.rotation.x = lerpf(-2.8, 0.6, f)
	if flash_t > 0.0:
		flash_t -= delta
	var e := maxf(flash_t, 0.0) / 0.25
	for m in _mats:
		m.emission_enabled = e > 0.0
		m.emission = Color(1.0, 0.12, 0.08) * e


func flash() -> void:
	flash_t = 0.25
