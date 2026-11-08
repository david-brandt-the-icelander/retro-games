class_name Board3D
extends Node3D
## The 3D table: board, pieces, lights and camera. Shows positions, animates moves, and lets the
## player move by clicking (a piece, then a square) or dragging. The camera sits behind the
## player's side and can be turned by dragging the empty table, and zoomed with the wheel.

signal move_made(uci: String)
signal promotion_needed(from_sq: int, to_sq: int)

const LIFT := 0.14
const WHITE_PIECE := Color("e0d8c6")
const BLACK_PIECE := Color("1d1e24")
const GOLD := Color("d9b26b")

var movable := -1                   ## the side the player may move: 0 white, 1 black, -1 nobody
var board_pos: Chess.Position = Chess.start()
var _nodes := {}                    ## square → MeshInstance3D
var _selected := -1
var _targets: Array[int] = []
var _last := -1                     ## the last move, as an int, or -1
var _drag := {}                     ## {from, start, moved}
var _press := Vector2.ZERO
var _orbiting := false

var _pivot := Node3D.new()
var _camera := Camera3D.new()
var _yaw := 0.0
var _yaw_target := 0.0
var _pitch := deg_to_rad(52.0)
var _dist := 12.6
var _dist_target := 12.6
var facing := 0                    ## the side the camera is behind
var showcase := false               ## turns slowly, for the title screen

var _mat := {}
var _hints := Node3D.new()
var _marks := Node3D.new()
var _check_mark: MeshInstance3D
var _t := 0.0


func _ready() -> void:
	_build_world()
	_build_board()
	add_child(_hints)
	add_child(_marks)
	_pivot.add_child(_camera)
	add_child(_pivot)
	_camera.fov = 34.0
	_camera.current = true
	_place_camera()
	show_position(Chess.start(), -1, false)


# ── Building the scene ──

func _material(color: Color, rough: float, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	return m


func _glow(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	return m


func _build_world() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("2a2f3a")
	sm.sky_horizon_color = Color("5a5248")
	sm.ground_horizon_color = Color("3a342e")
	sm.ground_bottom_color = Color("0c0d10")
	sm.sun_angle_max = 30.0
	sky.sky_material = sm
	env.sky = sky
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("0b0c0f")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58, -32, 0)
	key.light_color = Color("fff1dc")
	key.light_energy = 1.15
	key.shadow_enabled = true
	key.shadow_blur = 1.6
	key.directional_shadow_max_distance = 30.0
	key.shadow_bias = 0.03
	add_child(key)

	var rim := OmniLight3D.new()
	rim.position = Vector3(-6, 5, -7)
	rim.light_color = Color("8fb3ff")
	rim.light_energy = 1.4
	rim.omni_range = 22.0
	add_child(rim)

	var warm := OmniLight3D.new()
	warm.position = Vector3(7, 4, 6)
	warm.light_color = Color("ffcf8a")
	warm.light_energy = 0.7
	warm.omni_range = 20.0
	add_child(warm)

	var table := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	table.mesh = plane
	table.position.y = -0.42
	table.material_override = _material(Color("121317"), 0.55)
	add_child(table)

	_mat.white = _material(WHITE_PIECE, 0.3)
	_mat.black = _material(BLACK_PIECE, 0.18, 0.35)
	_mat.selected = _glow(GOLD, 0.55)
	_mat.last = _glow(GOLD, 0.22)
	_mat.hint = _glow(GOLD, 0.75)
	_mat.check = _glow(Color("ff3b4e"), 0.5)
	_mat.hint.emission_enabled = true


func _build_board() -> void:
	var frame := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(9.5, 0.4, 9.5)
	frame.mesh = box
	frame.position.y = -0.22
	frame.material_override = _material(Color("17181d"), 0.16, 0.2)
	add_child(frame)
	# A thin gold inlay around the squares.
	var gold := _material(GOLD, 0.3, 1.0)
	for i in 4:
		var bar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(8.32, 0.012, 0.035) if i < 2 else Vector3(0.035, 0.012, 8.32)
		bar.mesh = bm
		var o := 4.13 * (1 if i % 2 == 0 else -1)
		bar.position = Vector3(0, -0.015, o) if i < 2 else Vector3(o, -0.015, 0)
		bar.material_override = gold
		add_child(bar)
	var light := _material(Color("b3ab9b"), 0.55)
	var dark := _material(Color("353a42"), 0.26, 0.15)
	var sq_mesh := BoxMesh.new()
	sq_mesh.size = Vector3(1, 0.04, 1)
	for sq in 64:
		var m := MeshInstance3D.new()
		m.mesh = sq_mesh
		m.position = square_center(sq) + Vector3(0, -0.02, 0)
		m.material_override = light if (sq % 8 + sq / 8) % 2 == 1 else dark
		add_child(m)
	# Coordinates in the frame.
	var font: Font = load("res://fonts/inter-latin-600-normal.woff2")
	for i in 8:
		for side in [-1, 1]:
			var file := _label(Chess.FILES[i], font)
			file.position = Vector3(i - 3.5, 0.0, side * 4.45)
			add_child(file)
			var rank := _label(str(i + 1), font)
			rank.position = Vector3(side * 4.45, 0.0, 3.5 - i)
			add_child(rank)
	_check_mark = MeshInstance3D.new()
	var cm := PlaneMesh.new()
	cm.size = Vector2(0.96, 0.96)
	_check_mark.mesh = cm
	_check_mark.material_override = _mat.check
	_check_mark.visible = false
	add_child(_check_mark)


func _label(text: String, font: Font) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font = font
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = Color(GOLD, 0.75)
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.position.y = 0.002
	return l


# ── Geometry ──

static func square_center(sq: int) -> Vector3:
	return Vector3(sq % 8 - 3.5, 0, 3.5 - sq / 8)


func _square_at(p: Vector3) -> int:
	var f := floori(p.x + 4.0)
	var r := floori(4.0 - p.z)
	if f < 0 or f > 7 or r < 0 or r > 7:
		return -1
	return r * 8 + f


func _ray(screen: Vector2) -> Array:
	return [_camera.project_ray_origin(screen), _camera.project_ray_normal(screen)]


## The square the pointer is over: a piece it touches first, otherwise the board under it.
func _pick(screen: Vector2) -> int:
	var r := _ray(screen)
	var o: Vector3 = r[0]
	var d: Vector3 = r[1]
	var best := INF
	var best_sq := -1
	for sq in _nodes:
		var c := square_center(sq)
		var h := 0.75 + 0.1 * (board_pos.board[sq] & 7)
		# The ray against an upright cylinder around the piece.
		var ox := o.x - c.x
		var oz := o.z - c.z
		var a := d.x * d.x + d.z * d.z
		var b := 2.0 * (ox * d.x + oz * d.z)
		var cc := ox * ox + oz * oz - 0.3 * 0.3
		var disc := b * b - 4.0 * a * cc
		if disc < 0 or a < 1e-6:
			continue
		var t := (-b - sqrt(disc)) / (2.0 * a)
		var y := o.y + d.y * t
		if t > 0 and y >= 0 and y <= h and t < best:
			best = t
			best_sq = sq
	if best_sq >= 0:
		return best_sq
	return _square_at(_on_board(screen, 0.0))


func _on_board(screen: Vector2, height: float) -> Vector3:
	var r := _ray(screen)
	var d: Vector3 = r[1]
	if absf(d.y) < 1e-5:
		return Vector3(99, 0, 99)
	var t: float = (height - r[0].y) / d.y
	return r[0] + d * t


# ── Showing positions ──

## Shows a position. `last` is the move that led to it (an int from Chess, or -1); with `animate`,
## it glides into place and what it captured sinks away.
func show_position(pos: Chess.Position, last: int, animate: bool) -> void:
	var before := board_pos
	board_pos = pos
	_last = last
	_deselect()
	if animate and last >= 0:
		var from := Chess.move_from(last)
		var to := Chess.move_to(last)
		var flags := Chess.move_flags(last)
		var captured := to + (-8 if before.white else 8) if flags & Chess.F_EP else to
		if flags & Chess.F_CAPTURE and _nodes.has(captured):
			_sink(_nodes[captured])
			_nodes.erase(captured)
		if _nodes.has(from):
			var node: MeshInstance3D = _nodes[from]
			_nodes.erase(from)
			_nodes[to] = node
			_glide(node, square_center(to), true)
		if flags & Chess.F_CASTLE:
			var rf := from + 3 if to > from else from - 4
			var rt := from + 1 if to > from else from - 1
			if _nodes.has(rf):
				var rook: MeshInstance3D = _nodes[rf]
				_nodes.erase(rf)
				_nodes[rt] = rook
				_glide(rook, square_center(rt), false)
		if flags & Chess.F_CAPTURE:
			Sfx.play("capture")
		else:
			Sfx.play("move")
	_sync()
	_marks_update()


## Makes the pieces on the table match the position, adding and removing without animation.
func _sync() -> void:
	for sq in _nodes.keys():
		var node: MeshInstance3D = _nodes[sq]
		if node.get_meta("piece") != board_pos.board[sq]:
			node.queue_free()
			_nodes.erase(sq)
	for sq in 64:
		var piece := board_pos.board[sq]
		if piece == Chess.EMPTY or _nodes.has(sq):
			continue
		var node := MeshInstance3D.new()
		node.mesh = PieceMeshes.mesh(piece & 7)
		node.material_override = _mat.black if Chess.is_black(piece) else _mat.white
		node.set_meta("piece", piece)
		node.position = square_center(sq)
		# Knights look ahead and in toward the middle, so their profile shows.
		if piece & 7 == Chess.KNIGHT:
			var toward_center := 1.0 if sq % 8 < 4 else -1.0
			var ahead := deg_to_rad(38.0) * (-1.0 if Chess.is_black(piece) else 1.0)
			node.rotation.y = ahead if toward_center > 0 else PI - ahead
		add_child(node)
		_nodes[sq] = node


func _glide(node: Node3D, to: Vector3, hop: bool) -> void:
	var from := node.position
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var e := ease(t, -2.2)
		node.position = from.lerp(to, e) + Vector3(0, sin(t * PI) * (0.55 if hop else 0.15), 0), 0.0, 1.0, 0.38)


func _sink(node: MeshInstance3D) -> void:
	var m: StandardMaterial3D = (node.material_override as StandardMaterial3D).duplicate()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.material_override = m
	var tw := create_tween().set_parallel()
	tw.tween_property(node, "position:y", -0.9, 0.5).set_delay(0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.45).set_delay(0.2)
	tw.chain().tween_callback(node.queue_free)


func _flat(mat: Material, sq: int, size := 1.0, y := 0.003) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	m.mesh = pm
	m.material_override = mat
	m.position = square_center(sq) + Vector3(0, y, 0)
	return m


func _marks_update() -> void:
	for c in _marks.get_children():
		c.queue_free()
	if _last >= 0:
		_marks.add_child(_flat(_mat.last, Chess.move_from(_last)))
		_marks.add_child(_flat(_mat.last, Chess.move_to(_last)))
	var k := Chess.king_square(board_pos, board_pos.white)
	_check_mark.visible = Chess.in_check(board_pos) and k >= 0
	if _check_mark.visible:
		_check_mark.position = square_center(k) + Vector3(0, 0.004, 0)


# ── Selecting and moving ──

func _can_pick(sq: int) -> bool:
	var piece := board_pos.board[sq]
	if movable < 0 or piece == Chess.EMPTY:
		return false
	var white_piece := not Chess.is_black(piece)
	return white_piece == (movable == 0) and board_pos.white == white_piece


func _select(sq: int) -> void:
	_deselect()
	_selected = sq
	_targets = []
	for m in Chess.legal_moves(board_pos):
		if Chess.move_from(m) == sq:
			_targets.append(m)
	var node: Node3D = _nodes.get(sq)
	if node:
		create_tween().tween_property(node, "position:y", LIFT, 0.12).set_trans(Tween.TRANS_QUAD)
	_hints.add_child(_flat(_mat.selected, sq, 0.98, 0.004))
	var seen := {}
	for m in _targets:
		var to := Chess.move_to(m)
		if seen.has(to):
			continue
		seen[to] = true
		var h := MeshInstance3D.new()
		if Chess.move_flags(m) & Chess.F_CAPTURE:
			var ring := TorusMesh.new()
			ring.inner_radius = 0.36
			ring.outer_radius = 0.44
			ring.rings = 32
			h.mesh = ring
		else:
			var dot := CylinderMesh.new()
			dot.top_radius = 0.11
			dot.bottom_radius = 0.11
			dot.height = 0.01
			h.mesh = dot
		h.material_override = _mat.hint
		h.position = square_center(to) + Vector3(0, 0.01, 0)
		_hints.add_child(h)
	Sfx.play("select")


func _deselect() -> void:
	if _selected >= 0 and _nodes.has(_selected):
		var node: Node3D = _nodes[_selected]
		create_tween().tween_property(node, "position:y", 0.0, 0.12)
	_selected = -1
	_targets = []
	for c in _hints.get_children():
		c.queue_free()


## Tries to move the selected piece to `to`. True if it was one of its moves.
func _try(to: int) -> bool:
	var options := _targets.filter(func(m: int) -> bool: return Chess.move_to(m) == to)
	if options.is_empty():
		return false
	var from := _selected
	if Chess.move_promo(options[0]) != 0:
		promotion_needed.emit(from, to)
		return true
	_deselect()
	move_made.emit(Chess.uci(options[0]))
	return true


## Finishes a promotion with "q", "r", "b" or "n" (or cancels it with "").
func finish_promotion(from_sq: int, to_sq: int, piece: String) -> void:
	_deselect()
	if piece != "":
		move_made.emit(Chess.square_name(from_sq) + Chess.square_name(to_sq) + piece)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_dist_target = clampf(_dist_target - 0.6, 8.0, 18.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_dist_target = clampf(_dist_target + 0.6, 8.0, 18.0)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_orbiting = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press = mb.position
				_down(mb.position)
			else:
				_up(mb.position)
				_orbiting = false
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if not _drag.is_empty():
			if (mm.position - _press).length() > 6.0:
				_drag.moved = true
			if _drag.moved and _nodes.has(_drag.from):
				var p := _on_board(mm.position, LIFT + 0.2)
				var node: Node3D = _nodes[_drag.from]
				node.position = Vector3(clampf(p.x, -4.3, 4.3), LIFT + 0.2, clampf(p.z, -4.3, 4.3))
		elif _orbiting:
			_yaw_target -= mm.relative.x * 0.006
			_pitch = clampf(_pitch + mm.relative.y * 0.004, deg_to_rad(28), deg_to_rad(82))


func _down(screen: Vector2) -> void:
	var sq := _pick(screen)
	if sq < 0:
		_deselect()
		_orbiting = true
		return
	if _selected >= 0 and sq != _selected and _try(sq):
		return
	if _can_pick(sq):
		if _selected != sq:
			_select(sq)
		_drag = {from = sq, moved = false}
	else:
		if _selected >= 0:
			Sfx.play("illegal")
		_deselect()
		_orbiting = true


func _up(screen: Vector2) -> void:
	if _drag.is_empty():
		return
	var d := _drag
	_drag = {}
	if not d.moved:
		return
	var sq := _square_at(_on_board(screen, 0.0))
	if sq >= 0 and sq != d.from and _try(sq):
		return
	# Not a move: back to its square.
	if _nodes.has(d.from):
		_glide(_nodes[d.from], square_center(d.from) + Vector3(0, LIFT, 0), false)


# ── The camera ──

## Puts the camera behind white (0) or black (1).
func face(side: int, instant := false) -> void:
	facing = side
	_yaw_target = 0.0 if side == 0 else PI
	# Turn the short way round.
	while _yaw_target - _yaw > PI:
		_yaw_target -= TAU
	while _yaw_target - _yaw < -PI:
		_yaw_target += TAU
	if instant:
		_yaw = _yaw_target
	_place_camera()


## Shifts the board across the screen (positive: to the left), and sets how far away the camera is.
func frame_offset(fraction: float, distance := 12.6) -> void:
	_dist_target = distance
	create_tween().tween_property(_camera, "h_offset", fraction * distance * 0.62, 0.6).set_trans(Tween.TRANS_CUBIC)


func _place_camera() -> void:
	_pivot.rotation = Vector3(0, _yaw, 0)
	_camera.position = Vector3(0, sin(_pitch) * _dist, cos(_pitch) * _dist)
	_camera.look_at(Vector3.ZERO, Vector3.UP)


func _process(delta: float) -> void:
	_t += delta
	if showcase:
		_yaw_target += delta * 0.08
	_yaw = lerpf(_yaw, _yaw_target, 1.0 - exp(-delta * 5.0))
	_dist = lerpf(_dist, _dist_target, 1.0 - exp(-delta * 6.0))
	_place_camera()
	if _check_mark.visible:
		(_check_mark.material_override as StandardMaterial3D).albedo_color.a = 0.35 + 0.2 * sin(_t * 5.0)
