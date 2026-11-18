class_name Walker
extends Node3D
## A band of followers on foot. `strength` is how many people it carries.

var team := 0
var strength := 1
var gp := Vector2.ZERO          # continuous grid position (x, z)
var target := Vector2.ZERO
var think := 0.0
var champion := false
var foe: Node3D = null          # Walker or Settlement currently being fought
var hit_t := 0.0
var moving := false

var _body := MeshInstance3D.new()
var _head := MeshInstance3D.new()
var _halo: MeshInstance3D = null
var _label := Label3D.new()
var _bob := 0.0
var _shown := -1

static var _mats := {}
static var _cap_mesh: CapsuleMesh
static var _head_mesh: SphereMesh


static func team_color(t: int) -> Color:
	return Color(0.12, 0.42, 1.0) if t == 0 else Color(0.95, 0.16, 0.12)


static func mat(key: String, col: Color, emit := 0.0) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.roughness = 0.55
		if emit > 0.0:
			m.emission_enabled = true
			m.emission = col
			m.emission_energy_multiplier = emit
		_mats[key] = m
	return _mats[key]


func setup(t: int, s: int, p: Vector2) -> Walker:
	team = t
	strength = s
	gp = p
	target = p
	think = randf() * 0.4
	return self


func _ready() -> void:
	if _cap_mesh == null:
		_cap_mesh = CapsuleMesh.new()
		_cap_mesh.radius = 0.11
		_cap_mesh.height = 0.42
		_cap_mesh.radial_segments = 10
		_cap_mesh.rings = 3
		_head_mesh = SphereMesh.new()
		_head_mesh.radius = 0.085
		_head_mesh.height = 0.17
		_head_mesh.radial_segments = 10
		_head_mesh.rings = 5
	_body.mesh = _cap_mesh
	_body.material_override = mat("team%d" % team, team_color(team))
	_body.position.y = 0.21
	add_child(_body)
	_head.mesh = _head_mesh
	_head.material_override = mat("skin", Color(0.96, 0.82, 0.68))
	_head.position.y = 0.5
	add_child(_head)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0007
	_label.font_size = 26
	_label.outline_size = 8
	_label.modulate = team_color(team).lightened(0.6)
	_label.position.y = 0.9
	_label.visibility_range_end = 26.0
	add_child(_label)
	refresh()


func make_champion() -> void:
	champion = true
	_halo = MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.13
	tor.outer_radius = 0.18
	_halo.mesh = tor
	_halo.material_override = mat("halo", Color(1.0, 0.82, 0.3), 3.0)
	_halo.position.y = 0.72
	add_child(_halo)
	refresh()


func refresh() -> void:
	if _shown == strength:
		return
	_shown = strength
	var s := 0.85 + minf(strength, 80.0) / 55.0
	if champion:
		s *= 1.35
	_body.scale = Vector3(s, s, s)
	_head.scale = Vector3(s, s, s)
	_head.position.y = 0.5 * s
	_label.position.y = 0.9 * s + 0.1
	_label.text = ("★ %d" if champion else "%d") % strength


func animate(delta: float, terrain: Terrain) -> void:
	position = terrain.world_pos(gp)
	var dir := target - gp
	if moving and dir.length() > 0.05:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.y), minf(1.0, delta * 10.0))
		_bob += delta * 13.0
		_body.position.y = 0.21 * _body.scale.y + absf(sin(_bob)) * 0.07
	elif foe != null:
		_bob += delta * 22.0
		_body.rotation.x = sin(_bob) * 0.35
	else:
		_body.position.y = 0.21 * _body.scale.y
		_body.rotation.x = 0.0
	if _halo:
		_halo.rotation.y += delta * 2.0
