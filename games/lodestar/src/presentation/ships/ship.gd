extends Node3D
## A rigged ship: poses its moving parts from channels (docs/DESIGN.md § Animation). Each
## channel has a target from 0 to 1 and eases toward it every frame.

const RATES := {"turrets": 3.5, "brakes": 3.0}

var _targets := {"turrets": 0.0, "brakes": 0.0}
var _values := {"turrets": 0.0, "brakes": 0.0}
var _traverse_target := 0.0
var _traverse := 0.0
var _parts := {}
var _rest := {}


func _ready() -> void:
	for node in find_children("*", "Node3D", true, false):
		if node.has_meta("rig_kind"):
			var kind: String = node.get_meta("rig_kind")
			if not _parts.has(kind):
				_parts[kind] = []
			_parts[kind].append(node)
			_rest[node] = node.transform


func set_channel(channel: String, value: float) -> void:
	_targets[channel] = clampf(value, 0.0, 1.0)


func set_turret_traverse(degrees: float) -> void:
	_traverse_target = clampf(degrees, -150.0, 150.0)


func part_count() -> int:
	var n := 0
	for kind in _parts:
		n += _parts[kind].size()
	return n


func _process(delta: float) -> void:
	for channel in _values:
		var rate: float = RATES[channel]
		_values[channel] += (_targets[channel] - _values[channel]) * (1.0 - exp(-rate * delta))
	_traverse += (_traverse_target - _traverse) * (1.0 - exp(-4.0 * delta))

	var deployed: float = _values["turrets"]
	var braking: float = _values["brakes"]
	for node in _parts.get("turret", []):
		var rest: Transform3D = _rest[node]
		var rise: Vector3 = Vector3.UP * (1.0 - deployed) * -1.15
		node.transform = Transform3D(rest.basis * Basis(Vector3.UP, deg_to_rad(_traverse) * deployed), rest.origin + rest.basis * rise)
	for node in _parts.get("brake", []):
		var rest: Transform3D = _rest[node]
		var sign_value: float = float(node.get_meta("rig_sign", 1.0))
		node.transform = Transform3D(rest.basis * Basis(Vector3.RIGHT, sign_value * braking * deg_to_rad(55.0)), rest.origin)
