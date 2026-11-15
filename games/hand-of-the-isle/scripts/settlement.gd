class_name Settlement
extends Node3D
## A dwelling. Its tier (hut / house / castle) is set by how much flat,
## unclaimed land surrounds it: a 1x1, 3x3 or 5x5 footprint.

const CAP := [0, 6, 18, 44]
const NAMES := ["", "Hut", "House", "Castle"]

var team := 0
var tile := Vector2i.ZERO
var tier := 1
var pop := 1.0
var base_h := 0
var foe_count := 0

var _model := Node3D.new()
var _label := Label3D.new()
var _built := 0
var _shown := -1
var _grow := 0.0


func setup(t: int, at: Vector2i, people: int, height: int) -> Settlement:
	team = t
	tile = at
	pop = people
	base_h = height
	position = Vector3(at.x + 0.5, height * Terrain.HSTEP, at.y + 0.5)
	return self


func capacity() -> int:
	return CAP[tier]


func radius() -> int:
	return tier - 1


func _ready() -> void:
	add_child(_model)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.fixed_size = true
	_label.pixel_size = 0.0008
	_label.font_size = 28
	_label.outline_size = 9
	_label.modulate = Walker.team_color(team).lightened(0.55)
	_label.visibility_range_end = 48.0
	add_child(_label)
	_build()
	refresh()
	_model.scale = Vector3(0.2, 0.2, 0.2)


func _process(delta: float) -> void:
	_model.scale = _model.scale.lerp(Vector3.ONE, minf(1.0, delta * 6.0))


func set_tier(t: int) -> void:
	if t == tier:
		return
	tier = t
	_build()
	_model.scale = Vector3(0.6, 0.6, 0.6)
	_shown = -1
	refresh()


func refresh() -> void:
	var p := int(pop)
	if p == _shown and _built == tier:
		return
	_shown = p
	_label.text = "%d/%d" % [p, capacity()]
	_label.position.y = [0.0, 1.25, 1.9, 3.3][tier]


func _box(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = pos
	_model.add_child(mi)


func _roof(size: Vector3, pos: Vector3, m: Material) -> void:
	var mi := MeshInstance3D.new()
	var p := PrismMesh.new()
	p.size = size
	mi.mesh = p
	mi.material_override = m
	mi.position = pos
	_model.add_child(mi)


func _tower(pos: Vector3, height: float, wall: Material, roof: Material) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.32
	c.bottom_radius = 0.36
	c.height = height
	c.radial_segments = 10
	mi.mesh = c
	mi.material_override = wall
	mi.position = pos + Vector3(0, height * 0.5, 0)
	_model.add_child(mi)
	var cone := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.45
	cm.height = 0.7
	cm.radial_segments = 10
	cone.mesh = cm
	cone.material_override = roof
	cone.position = pos + Vector3(0, height + 0.35, 0)
	_model.add_child(cone)


func _build() -> void:
	_built = tier
	for c in _model.get_children():
		c.queue_free()
	var wall := Walker.mat("wall", Color(0.93, 0.88, 0.78))
	var roof := Walker.mat("roof%d" % team, Walker.team_color(team).darkened(0.1))
	var wood := Walker.mat("wood", Color(0.42, 0.3, 0.2))
	var glow := Walker.mat("window", Color(1.0, 0.82, 0.45), 2.2)
	match tier:
		1:
			_box(Vector3(0.56, 0.36, 0.56), Vector3(0, 0.18, 0), wall)
			_roof(Vector3(0.7, 0.32, 0.66), Vector3(0, 0.52, 0), roof)
			_box(Vector3(0.14, 0.2, 0.02), Vector3(0, 0.1, 0.285), wood)
		2:
			_box(Vector3(1.5, 0.7, 1.1), Vector3(0, 0.35, 0), wall)
			_roof(Vector3(1.7, 0.55, 1.3), Vector3(0, 0.98, 0), roof)
			_box(Vector3(0.9, 0.5, 0.8), Vector3(0.75, 0.25, 0.7), wall)
			_roof(Vector3(1.0, 0.4, 0.9), Vector3(0.75, 0.7, 0.7), roof)
			_box(Vector3(0.18, 0.5, 0.18), Vector3(-0.45, 1.1, -0.2), wood)
			_box(Vector3(0.22, 0.2, 0.02), Vector3(-0.35, 0.4, 0.555), glow)
			_box(Vector3(0.22, 0.2, 0.02), Vector3(0.35, 0.4, 0.555), glow)
		3:
			var stone := Walker.mat("stone", Color(0.78, 0.76, 0.72))
			_box(Vector3(1.8, 1.6, 1.8), Vector3(0, 0.8, 0), stone)
			_roof(Vector3(1.9, 0.8, 1.9), Vector3(0, 2.0, 0), roof)
			for s in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				_tower(Vector3(s.x * 1.75, 0, s.y * 1.75), 1.9, stone, roof)
			_box(Vector3(3.5, 0.6, 0.3), Vector3(0, 0.3, -1.75), stone)
			_box(Vector3(3.5, 0.6, 0.3), Vector3(0, 0.3, 1.75), stone)
			_box(Vector3(0.3, 0.6, 3.5), Vector3(-1.75, 0.3, 0), stone)
			_box(Vector3(0.3, 0.6, 3.5), Vector3(1.75, 0.3, 0), stone)
			for i in 3:
				_box(Vector3(0.25, 0.3, 0.02), Vector3(-0.5 + i * 0.5, 1.1, 0.905), glow)
	var top: float = [0.0, 0.68, 1.3, 2.4][tier]
	_box(Vector3(0.04, 0.6, 0.04), Vector3(0, top + 0.3, 0), wood)
	_box(Vector3(0.3, 0.18, 0.02), Vector3(0.16, top + 0.5, 0), Walker.mat("flag%d" % team, Walker.team_color(team), 1.2))
