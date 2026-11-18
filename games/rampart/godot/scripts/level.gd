extends Node3D
## Streams the fortress in 40-unit chunks ahead of the ship and frees them behind it.

signal boss_trigger

const M = preload("res://scripts/mats.gd")
const T = preload("res://scripts/target.gd")
const TurretScript = preload("res://scripts/turret.gd")
const TankScript = preload("res://scripts/fuel_tank.gd")
const RadarScript = preload("res://scripts/radar.gd")
const SiloScript = preload("res://scripts/silo.gd")
const FieldScript = preload("res://scripts/forcefield.gd")
const FighterScript = preload("res://scripts/fighter.gd")
const FLOOR_SHADER = preload("res://shaders/floor.gdshader")

const CHUNK := 40.0
const HALF_W := 12.0
const BUILD_AHEAD := 170.0
const WALL_T := 1.4

var level_num: int = 1
var plan: Array = []
var plan_index: int = 0
var next_z: float = 0.0
var chunks: Array = []
var rng := RandomNumberGenerator.new()
var box_cache: Dictionary = {}
var rock_mesh: SphereMesh

var floor_mat: ShaderMaterial
var wall_mat: StandardMaterial3D
var rib_mat: StandardMaterial3D
var trim_mat: StandardMaterial3D
var trim_dim_mat: StandardMaterial3D
var gap_mat: StandardMaterial3D
var rampart_mat: StandardMaterial3D
var dark_mat: StandardMaterial3D
var red_mat: StandardMaterial3D
var vent_mat: StandardMaterial3D
var rock_mat: StandardMaterial3D


func _ready() -> void:
	floor_mat = ShaderMaterial.new()
	floor_mat.shader = FLOOR_SHADER
	wall_mat = M.metal(Color(0.42, 0.45, 0.52), 0.3, 0.75, true)
	rib_mat = M.metal(Color(0.16, 0.17, 0.2), 0.45, 0.8, true)
	trim_mat = M.glow(Color(0.2, 0.72, 1.0), 4.5)
	trim_dim_mat = M.glow(Color(0.2, 0.6, 1.0), 1.8)
	gap_mat = M.glow(Color(0.3, 1.0, 0.55), 6.0)
	rampart_mat = M.metal(Color(0.3, 0.33, 0.39), 0.38, 0.8)
	dark_mat = M.metal(Color(0.08, 0.09, 0.11), 0.5, 0.75)
	red_mat = M.glow(Color(1.0, 0.2, 0.15), 7.0)
	vent_mat = M.glow(Color(1.0, 0.5, 0.15), 3.0)
	rock_mat = M.metal(Color(0.2, 0.17, 0.16), 0.85, 0.2)
	rock_mesh = T.sphere(1.0, 7)


# --- public -----------------------------------------------------------------

func start(lvl: int, from_z: float) -> void:
	for c in chunks:
		(c["node"] as Node).queue_free()
	chunks.clear()
	rng.randomize()
	level_num = lvl
	plan = ["start", "approach"] + _assault_block(lvl)
	plan_index = 0
	next_z = from_z + 30.0


func next_level(lvl: int) -> void:
	level_num = lvl
	plan = ["approach"] + _assault_block(lvl)
	plan_index = 0


func update(pz: float) -> void:
	while next_z > pz - BUILD_AHEAD:
		_build_next()
	while chunks.size() > 0 and float(chunks[0]["z1"]) > pz + 50.0:
		(chunks[0]["node"] as Node).queue_free()
		chunks.pop_front()
	for c in chunks:
		if c["trigger"] and not c["triggered"] and pz < float(c["z0"]) - 6.0:
			c["triggered"] = true
			boss_trigger.emit()


func section_at(pz: float) -> String:
	for c in chunks:
		if pz <= float(c["z0"]) and pz > float(c["z1"]):
			return c["type"]
	return "space"


func is_floor_at(pz: float) -> bool:
	for c in chunks:
		for f in c["floors"]:
			if pz <= f.x and pz >= f.y:
				return true
	return false


# --- plan --------------------------------------------------------------------

func _ramp(easy: float, hard: float) -> float:
	return Game.ramp(level_num, easy, hard)


func _ramp_i(easy: float, hard: float) -> int:
	return int(round(_ramp(easy, hard)))


## The level gets longer as it gets harder: 3 + 2 fortress chunks and 2 of open space on
## level 1, up to 9 + 8 and 6 by the last level of the ramp.
func _assault_block(lvl: int) -> Array:
	level_num = lvl
	var p: Array = ["gate"]
	for i in _ramp_i(3.0, 9.0):
		p.append("fortress")
	p.append("exit")
	for i in _ramp_i(2.0, 6.0):
		p.append("space")
	p.append("entry")
	p.append("gate")
	for i in _ramp_i(2.0, 8.0):
		p.append("fortress")
	p.append("citadel")
	return p


func _build_next() -> void:
	var type: String = "arena"
	if plan_index < plan.size():
		type = plan[plan_index]
	plan_index += 1
	var z0 := next_z
	var z1 := next_z - CHUNK
	next_z = z1
	var node := Node3D.new()
	add_child(node)
	var rec := {"node": node, "z0": z0, "z1": z1, "type": type, "floors": [], "trigger": false, "triggered": false}
	match type:
		"start":
			_floor(rec, z0, z1, false, false)
		"approach", "arena":
			_floor(rec, z0, z1, false, false)
			_scatter(node, z0 - 6.0, z1 + 4.0, 2, ["tank", "tank", "turret"], true)
		"gate":
			_floor(rec, z0, z1, false, false)
			_gate(node, z0 - 12.0)
			_scatter(node, z0 - 20.0, z1 + 3.0, 2, ["tank", "turret"], true)
		"fortress":
			_floor(rec, z0, z1, false, false)
			_fortress(node, z0, z1)
		"exit":
			_floor(rec, z0, z0 - 22.0, false, true)
			_scatter(node, z0 - 3.0, z0 - 18.0, 2, ["tank", "radar", "turret"], true)
			_space_decor(node, z0 - 22.0, z1)
		"space":
			_space(node, z0, z1)
		"entry":
			_space_decor(node, z0, z0 - 16.0)
			_floor(rec, z0 - 16.0, z1, true, false)
		"citadel":
			_floor(rec, z0, z1, false, false)
			_scatter(node, z0 - 8.0, z1 + 4.0, 2, ["tank"], true)
			rec["trigger"] = true
	chunks.append(rec)


# --- builders ----------------------------------------------------------------

func _box(size: Vector3) -> BoxMesh:
	var key := "%.2f_%.2f_%.2f" % [size.x, size.y, size.z]
	if box_cache.has(key):
		return box_cache[key]
	var b := BoxMesh.new()
	b.size = size
	box_cache[key] = b
	return b


func _mesh(parent: Node, mesh: Mesh, mat: Material, pos: Vector3, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _floor(rec: Dictionary, za: float, zb: float, edge_start: bool, edge_end: bool) -> void:
	var node: Node3D = rec["node"]
	(rec["floors"] as Array).append(Vector2(za, zb))
	var length := za - zb
	var cz := (za + zb) * 0.5
	_mesh(node, _box(Vector3(HALF_W * 2.0, 2.0, length)), floor_mat, Vector3(0, -1.0, cz))
	for s in [-1.0, 1.0]:
		var side: float = s
		_mesh(node, _box(Vector3(2.0, 5.5, length)), rampart_mat, Vector3(side * (HALF_W + 1.0), 0.75, cz))
		_mesh(node, _box(Vector3(0.16, 0.16, length)), trim_mat, Vector3(side * (HALF_W + 0.04), 3.5, cz), false)
		_mesh(node, _box(Vector3(0.06, 0.3, length)), trim_dim_mat, Vector3(side * (HALF_W - 0.02), 1.4, cz), false)
		var pz := za - 5.0
		while pz > zb:
			_mesh(node, _box(Vector3(2.8, 6.6, 1.6)), dark_mat, Vector3(side * (HALF_W + 1.25), 1.3, pz))
			_mesh(node, _box(Vector3(0.5, 0.25, 0.5)), red_mat, Vector3(side * (HALF_W + 1.25), 4.7, pz), false)
			pz -= 10.0
	_floor_decor(node, za, zb)
	if edge_start:
		_mesh(node, _box(Vector3(HALF_W * 2.0 + 4.0, 0.2, 0.3)), trim_mat, Vector3(0, 0.0, za), false)
	if edge_end:
		_mesh(node, _box(Vector3(HALF_W * 2.0 + 4.0, 0.2, 0.3)), trim_mat, Vector3(0, 0.0, zb), false)


func _floor_decor(node: Node3D, za: float, zb: float) -> void:
	var n := 2 + rng.randi_range(0, 3)
	for i in n:
		var sx := snappedf(rng.randf_range(2.0, 5.0), 0.5)
		var sz := snappedf(rng.randf_range(2.0, 6.0), 0.5)
		if za - zb < sz + 1.0:
			return
		var x := rng.randf_range(-10.5 + sx * 0.5, 10.5 - sx * 0.5)
		var z := rng.randf_range(zb + sz * 0.5, za - sz * 0.5)
		_mesh(node, _box(Vector3(sx, 0.3, sz)), dark_mat, Vector3(x, 0.15, z))
		_mesh(node, _box(Vector3(sx * 0.6, 0.04, 0.12)), vent_mat, Vector3(x, 0.31, z - sz * 0.25), false)
		_mesh(node, _box(Vector3(sx * 0.6, 0.04, 0.12)), vent_mat, Vector3(x, 0.31, z + sz * 0.25), false)


func _fortress(node: Node3D, z0: float, z1: float) -> void:
	# Half the chunks on level 1 have no barrier at all; by the end of the ramp most do.
	var oz := z0 - 6.0
	if rng.randf() < _ramp(0.5, 0.88):
		var roll := rng.randf()
		if roll < 0.4:
			_window_wall(node, oz)
		elif roll < 0.65:
			_low_wall(node, oz)
		else:
			_field(node, oz)
	var kinds: Array = ["tank", "tank", "tank", "radar", "turret"]
	if level_num >= 2:
		kinds.append("turret")
	if level_num >= 3:
		kinds.append("silo")
	if level_num >= 5:
		kinds.append_array(["turret", "silo"])
	if level_num >= 8:
		kinds.append_array(["turret", "silo"])
	var count := _ramp_i(2.0, 5.0) + rng.randi_range(0, _ramp_i(1.0, 3.0))
	_scatter(node, z0 - 12.0, z1 + 3.0, count, kinds, true)


func _scatter(node: Node3D, za: float, zb: float, count: int, kinds: Array, ensure_tank: bool) -> void:
	var placed: Array = []
	for i in count:
		var kind: String = kinds[rng.randi() % kinds.size()]
		if ensure_tank and i == 0:
			kind = "tank"
		var pos := Vector3.ZERO
		var ok := false
		for attempt in 12:
			pos = Vector3(rng.randf_range(-8.0, 8.0), 0.0, rng.randf_range(zb, za))
			ok = true
			for q in placed:
				if (q as Vector3).distance_to(pos) < 4.2:
					ok = false
					break
			if ok:
				break
		if not ok:
			continue
		placed.append(pos)
		var obj
		match kind:
			"turret":
				obj = TurretScript.new()
				obj.fire_interval = _ramp(3.8, 1.2)
				obj.shot_speed = _ramp(12.0, 19.0)
			"tank":
				obj = TankScript.new()
			"radar":
				obj = RadarScript.new()
			"silo":
				obj = SiloScript.new()
				obj.lvl = level_num
		obj.position = pos
		node.add_child(obj)


func _window_wall(node: Node3D, z: float) -> void:
	var gw := rng.randf_range(_ramp(7.5, 4.5), _ramp(9.5, 6.0))
	var gx := rng.randf_range(-7.5 + gw * 0.5, 7.5 - gw * 0.5)
	var gh := _ramp(4.8, 2.6)
	var gb := rng.randf_range(0.3, 8.8 - gh)
	_wall(node, z, 10.5, gx, gw, gb, gb + gh)


func _low_wall(node: Node3D, z: float) -> void:
	var h := rng.randf_range(_ramp(1.8, 2.5), _ramp(3.2, 6.5))
	_wall(node, z, h, 0.0, 0.0, 0.0, 0.0)


func _gate(node: Node3D, z: float) -> void:
	var gw := _ramp(10.0, 6.5)
	var spread := _ramp(2.5, 4.5)
	var gx := rng.randf_range(-spread, spread)
	var gh := _ramp(5.5, 3.6)
	var gb := rng.randf_range(0.4, _ramp(2.5, 4.5))
	_wall(node, z, 10.5, gx, gw, gb, gb + gh)
	for s in [-1.0, 1.0]:
		var side: float = s
		_mesh(node, _box(Vector3(3.4, 15.0, 3.4)), wall_mat, Vector3(side * 14.0, 5.5, z))
		_mesh(node, _box(Vector3(3.6, 0.25, 3.6)), trim_mat, Vector3(side * 14.0, 13.0, z), false)
		_mesh(node, _box(Vector3(0.6, 0.6, 0.6)), red_mat, Vector3(side * 14.0, 13.4, z), false)
		_mesh(node, _box(Vector3(0.2, 9.0, 0.2)), trim_dim_mat, Vector3(side * 12.25, 6.0, z + 1.75), false)


func _wall(node: Node3D, z: float, height: float, gx: float, gw: float, gb: float, gt: float) -> void:
	var area := Area3D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	area.monitoring = false
	area.monitorable = true
	node.add_child(area)
	var x0 := -HALF_W - 1.0
	var x1 := HALF_W + 1.0
	var blocks: Array = []
	var gl := gx - gw * 0.5
	var gr := gx + gw * 0.5
	if gw <= 0.0:
		blocks.append([x0, x1, 0.0, height])
	else:
		blocks.append([x0, gl, 0.0, height])
		blocks.append([gr, x1, 0.0, height])
		if gb > 0.05:
			blocks.append([gl, gr, 0.0, gb])
		if gt < height - 0.05:
			blocks.append([gl, gr, gt, height])
	var front := z + WALL_T * 0.5
	for b in blocks:
		var bx0: float = b[0]
		var bx1: float = b[1]
		var by0: float = b[2]
		var by1: float = b[3]
		var size := Vector3(bx1 - bx0, by1 - by0, WALL_T)
		var center := Vector3((bx0 + bx1) * 0.5, (by0 + by1) * 0.5, z)
		_mesh(area, _box(size), wall_mat, center)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = center
		area.add_child(cs)
		_mesh(area, _box(Vector3(size.x, 0.12, 0.12)), trim_mat, Vector3(center.x, by1, front), false)
		# Structural ribs on the full-height blocks
		if by0 < 0.01 and by1 >= height - 0.01:
			var rx := bx0 + 1.5
			while rx < bx1 - 0.8:
				_mesh(area, _box(Vector3(0.35, height, 0.3)), rib_mat, Vector3(rx, height * 0.5, front + 0.1))
				rx += 3.0
	if gw > 0.0:
		var gh := gt - gb
		var gm := (gb + gt) * 0.5
		var fz := front + 0.12
		_mesh(area, _box(Vector3(0.16, gh, 0.12)), gap_mat, Vector3(gl, gm, fz), false)
		_mesh(area, _box(Vector3(0.16, gh, 0.12)), gap_mat, Vector3(gr, gm, fz), false)
		_mesh(area, _box(Vector3(gw, 0.16, 0.12)), gap_mat, Vector3(gx, maxf(gb, 0.08), fz), false)
		_mesh(area, _box(Vector3(gw, 0.16, 0.12)), gap_mat, Vector3(gx, gt, fz), false)
		var lt := OmniLight3D.new()
		lt.light_color = Color(0.3, 1.0, 0.55)
		lt.light_energy = 2.0
		lt.omni_range = 6.0
		lt.position = Vector3(gx, gm, front + 1.0)
		area.add_child(lt)


func _field(node: Node3D, z: float) -> void:
	var f = FieldScript.new()
	var blink_chance := 0.0 if level_num < 3 else _ramp(0.15, 0.4)
	if rng.randf() < blink_chance:
		f.y0 = 0.0
		f.y1 = 10.5
		f.blink = true
		var pd := _ramp(2.6, 1.5)
		f.period = rng.randf_range(pd, pd + 0.5)
		f.phase = rng.randf() * 2.0
	elif rng.randf() < 0.5:
		f.y0 = 0.0
		f.y1 = rng.randf_range(_ramp(1.8, 2.5), _ramp(3.0, 5.5))
	else:
		f.y0 = rng.randf_range(_ramp(4.5, 2.4), _ramp(6.0, 4.6))
		f.y1 = 10.5
	f.position = Vector3(0, 0, z)
	node.add_child(f)


func _space(node: Node3D, z0: float, z1: float) -> void:
	_space_decor(node, z0, z1)
	var n := _ramp_i(1.0, 5.0) + rng.randi_range(0, 1)
	for i in n:
		var f = FighterScript.new()
		var x := rng.randf_range(-6.0, 6.0)
		var y := 3.5
		f.position = Vector3(x, y, rng.randf_range(z1 + 2.0, z0 - 2.0))
		f.base_x = x
		f.base_y = y
		f.phase = rng.randf() * TAU
		f.amp_x = rng.randf_range(_ramp(0.8, 2.0), _ramp(2.0, 4.0))
		f.speed = _ramp(6.0, 13.0)
		f.fire_chance = _ramp(0.1, 0.8)
		f.fire_gap = _ramp(1.7, 1.0)
		f.shot_speed = _ramp(14.0, 22.0)
		node.add_child(f)


func _space_decor(node: Node3D, za: float, zb: float) -> void:
	for i in 3:
		var mi := _mesh(node, rock_mesh, rock_mat, Vector3(rng.randf_range(-45.0, 45.0), rng.randf_range(-45.0, -20.0), rng.randf_range(zb, za)))
		mi.scale = Vector3(rng.randf_range(1.0, 4.0), rng.randf_range(1.0, 3.0), rng.randf_range(1.0, 4.0))
		mi.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
