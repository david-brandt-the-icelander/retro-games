extends Area3D
## Energy barrier spanning the fortress between two pylons.

const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const FIELD_SHADER = preload("res://shaders/forcefield.gdshader")

var y0: float = 0.0
var y1: float = 4.0
var blink: bool = false
var period: float = 1.6
var phase: float = 0.0
var t: float = 0.0
var on: bool = true
var band: MeshInstance3D
var mat: ShaderMaterial
var emitters: Array = []
var light: OmniLight3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	monitorable = true
	var h := y1 - y0
	var mid := (y0 + y1) * 0.5
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(26.0, h, 0.6)
	cs.shape = bs
	cs.position.y = mid
	add_child(cs)

	mat = ShaderMaterial.new()
	mat.shader = FIELD_SHADER
	band = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(24.6, h)
	band.mesh = qm
	band.material_override = mat
	band.position.y = mid
	band.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(band)

	var pylon := M.metal(Color(0.2, 0.2, 0.24), 0.4, 0.85, true)
	var em := M.glow(Color(1.0, 0.25, 0.45), 7.0)
	for s in [-1.0, 1.0]:
		_mesh(T.box(1.2, 11.5, 1.2), pylon, Vector3(s * 12.9, 5.0, 0))
		for y in [y0, y1]:
			var e := _mesh(T.box(0.5, 0.25, 0.9), em, Vector3(s * 12.25, clampf(y, 0.15, 10.4), 0))
			emitters.append(e)
		_mesh(T.box(0.3, 0.3, 0.3), M.glow(Color(1.0, 0.2, 0.15), 8.0), Vector3(s * 12.9, 10.9, 0))
	for y in [y0, y1]:
		if y > 0.1 and y < 10.4:
			var beam := _mesh(T.cyl(0.05, 0.05, 24.6, 6), M.add(Color(1.0, 0.4, 0.6), 6.0, 0), Vector3(0, y, 0), Vector3(0, 0, PI / 2))
			emitters.append(beam)
	light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.5)
	light.light_energy = 2.0
	light.omni_range = 9.0
	light.position.y = mid
	add_child(light)


func _mesh(mesh: Mesh, m: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	if m is ShaderMaterial:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _process(delta: float) -> void:
	if not blink:
		return
	t += delta
	var cyc := fmod(t + phase, period)
	var want := cyc < period * 0.55
	# Flicker warning just before the field comes back on.
	var warn := not want and cyc > period - 0.3
	band.visible = want or (warn and fmod(t, 0.08) < 0.04)
	mat.set_shader_parameter("flicker", 1.0 if want else 0.35)
	light.visible = want
	if want != on:
		on = want
		set_deferred("monitorable", on)
