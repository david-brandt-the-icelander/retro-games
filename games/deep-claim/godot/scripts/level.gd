class_name Level
extends Node2D
## One asteroid shaft: builds collision from the ASCII map, draws every tile procedurally and
## handles ore, hazards, crumbling ledges, conveyors, drones, rockfall, the buggy and the exit tunnel.
##
## Map legend:
##   #  rock        =  crumbling ledge     <  >  conveyors     ^  crystal shards
##   r  rare earth  p  precious metal      b  building material
##   B  buggy start D  exit-tunnel door (right wall)
##   g  crawler bot f  security drone (horizontal)   v  proximity mine (vertical)

signal ore_taken(remaining: int, pos: Vector2, mat: Dictionary)
signal all_ore_taken(pos: Vector2)
signal player_killed(reason: String)
signal exit_reached
signal tile_crumbled(pos: Vector2)
signal rock_landed(pos: Vector2, big: bool)

## symbol, name, credits, colour
const MATERIALS := {
	"r": [["Nd", "Neodymium", 350, Color(0.78, 0.5, 1.0)], ["Dy", "Dysprosium", 450, Color(0.6, 1.0, 0.45)],
		["Tb", "Terbium", 450, Color(0.35, 1.0, 0.8)], ["Eu", "Europium", 500, Color(1.0, 0.45, 0.6)]],
	"p": [["Pt", "Platinum", 600, Color(0.9, 0.92, 0.98)], ["Pd", "Palladium", 550, Color(0.78, 0.82, 0.88)],
		["Ir", "Iridium", 800, Color(0.6, 0.72, 1.0)], ["Rh", "Rhodium", 900, Color(1.0, 0.78, 0.85)],
		["Au", "Gold", 500, Color(1.0, 0.8, 0.3)]],
	"b": [["Ti", "Titanium", 220, Color(0.55, 0.72, 0.9)], ["Al", "Aluminium", 150, Color(0.86, 0.88, 0.92)],
		["FeNi", "Nickel-iron", 120, Color(0.8, 0.5, 0.35)]],
}

const T := 32
const CONVEYOR_SPEED := 95.0
const SOLID := "#<>=D"

var W := 40
var H := 20
var grid: Array = []
var tint := Color.WHITE
var level_name := ""
var collapse_time := 120.0
var collapse_frac := 1.0
var ore: Array[Dictionary] = []
var ore_lights: Array[PointLight2D] = []
var ore_total := 0
var crumble := {}
var door_cells: Array[Vector2i] = []
var door_body: StaticBody2D
var door_open := false
var door_t := 0.0
var door_light: PointLight2D
var buggy_start := Vector2()
var guardians: Array[Guardian] = []
var player: Player
var buggy: Buggy
var rocks: Array[Dictionary] = []
var debris: Array[Dictionary] = []
var cracks: Array[PackedVector2Array] = []
var _rock_timer := 2.0
var _debris_timer := 0.0
var font: Font
var active := true
var t := 0.0
var _static_layer: Node2D


func setup(data: Dictionary) -> void:
	level_name = data["name"]
	collapse_time = data["collapse"]
	tint = data["tint"]
	var rows: Array = data["map"]
	H = rows.size()
	W = (rows[0] as String).length()
	grid.clear()
	for y in H:
		var row: Array = []
		var s: String = rows[y]
		for x in W:
			row.append(s[x])
		grid.append(row)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	font = ThemeDB.fallback_font
	_static_layer = Node2D.new()
	_static_layer.z_index = -1
	_static_layer.draw.connect(_draw_static)
	add_child(_static_layer)

	var kind_count := {"r": hash(level_name) % 7, "p": hash(level_name) % 5, "b": hash(level_name) % 3}
	for y in H:
		for x in W:
			var c: String = grid[y][x]
			var center := Vector2(x * T + T * 0.5, y * T + T * 0.5)
			match c:
				"r", "p", "b":
					var list: Array = MATERIALS[c]
					var m: Array = list[int(kind_count[c]) % list.size()]
					kind_count[c] = int(kind_count[c]) + 1
					ore.append({"pos": center, "kind": c, "mat": {"sym": m[0], "name": m[1], "value": m[2], "color": m[3]},
							"phase": _hash(y, x) * TAU})
					grid[y][x] = "."
				"B":
					buggy_start = Vector2(x * T + T, y * T + T - Buggy.HALF.y)
					grid[y][x] = "."
				"D":
					door_cells.append(Vector2i(x, y))
				"g", "f", "v":
					var gd := Guardian.new()
					gd.setup(c, self)
					gd.position = Vector2(center.x, y * T + T - 12) if c == "g" else center
					guardians.append(gd)
					grid[y][x] = "."
	_build_colliders()
	_build_cracks()
	ore_total = ore.size()
	for o in ore:
		var col: Color = o["mat"]["color"]
		var l := Fx.make_light(col, 0.5, 0.5)
		l.position = o["pos"]
		add_child(l)
		ore_lights.append(l)
	door_light = Fx.make_light(Color(1.0, 0.3, 0.2), 0.6, 1.0)
	door_light.position = Vector2(W * T - T * 1.5, 18 * T)
	add_child(door_light)
	for gd in guardians:
		add_child(gd)
	buggy = Buggy.new()
	buggy.level = self
	buggy.position = buggy_start
	buggy.occupied = true
	add_child(buggy)
	player = Player.new()
	player.level = self
	player.position = buggy_start
	add_child(player)
	player.set_in_buggy(true)


# ------------------------------------------------------------------ grid queries

func cell(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= W or y >= H:
		return "#"
	return grid[y][x]


func is_solid(x: int, y: int) -> bool:
	return SOLID.contains(cell(x, y))


func _feet_cells(p: Player) -> Array[Vector2i]:
	var fy := int(floor((p.global_position.y + Player.HALF.y + 2.0) / T))
	var a := Vector2i(int(floor((p.global_position.x - Player.HALF.x + 1.0) / T)), fy)
	var b := Vector2i(int(floor((p.global_position.x + Player.HALF.x - 1.0) / T)), fy)
	if a == b:
		return [a]
	return [a, b]


func conveyor_under(p: Player) -> float:
	for c in _feet_cells(p):
		match cell(c.x, c.y):
			"<":
				return -CONVEYOR_SPEED
			">":
				return CONVEYOR_SPEED
	return 0.0


func stand_on(p: Player, delta: float) -> void:
	for c in _feet_cells(p):
		if crumble.has(c) and c.y < H - 1:
			var entry: Dictionary = crumble[c]
			entry["hp"] = float(entry["hp"]) - delta * 1.7
			if entry["hp"] <= 0.0:
				(entry["body"] as Node).queue_free()
				crumble.erase(c)
				grid[c.y][c.x] = "."
				tile_crumbled.emit(Vector2(c.x * T + T * 0.5, c.y * T + T * 0.5))


# ------------------------------------------------------------------ collision

func _build_colliders() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for y in H:
		var x := 0
		while x < W:
			var c := cell(x, y)
			if c == "#" or c == "<" or c == ">":
				var x0 := x
				while x < W and (cell(x, y) == "#" or cell(x, y) == "<" or cell(x, y) == ">"):
					x += 1
				_add_rect(body, Rect2(x0 * T, y * T, (x - x0) * T, T))
			else:
				if c == "=":
					var cb := StaticBody2D.new()
					add_child(cb)
					_add_rect(cb, Rect2(x * T, y * T, T, 16))
					crumble[Vector2i(x, y)] = {"body": cb, "hp": 1.0}
				x += 1
	door_body = StaticBody2D.new()
	add_child(door_body)
	for c in door_cells:
		_add_rect(door_body, Rect2(c.x * T, c.y * T, T, T))
	# the tunnel beyond the door: floor and roof so the buggy can drive off-screen
	_add_rect(body, Rect2(W * T, (H - 1) * T, T * 6, T))
	_add_rect(body, Rect2(W * T, 16 * T, T * 6, T))
	# an airlock field that only stops the astronaut: you leave by buggy, not on foot
	var field := StaticBody2D.new()
	field.collision_layer = 8
	field.collision_mask = 0
	add_child(field)
	_add_rect(field, Rect2((W - 1) * T + 8, 17 * T, 8, T * 2))


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.get_center()
	body.add_child(cs)


# ------------------------------------------------------------------ gameplay

func buggy_in_reach() -> bool:
	return not player.in_buggy and player.is_on_floor() and player.rect().grow(10.0).intersects(buggy.rect())


func toggle_buggy() -> bool:
	if player.in_buggy:
		if absf(buggy.vx) > 40.0:
			return false
		var px := clampf(buggy.position.x - 18.0 * buggy.facing, T * 1.5, (W - 1.5) * T)
		player.position = Vector2(px, buggy.position.y + Buggy.HALF.y - Player.HALF.y - 1.0)
		player.facing = buggy.facing
		player.set_in_buggy(false)
		buggy.occupied = false
		return true
	if buggy_in_reach():
		player.set_in_buggy(true)
		buggy.occupied = true
		return true
	return false


func open_door() -> void:
	door_open = true
	door_body.queue_free()
	for c in door_cells:
		grid[c.y][c.x] = "."
	door_light.color = Color(0.3, 1.0, 0.5)


func _physics_process(delta: float) -> void:
	t += delta
	if door_open:
		door_t = minf(1.0, door_t + delta * 1.5)
	_update_collapse(delta)
	queue_redraw()
	if not active or player == null or not player.alive:
		return
	if buggy.position.x > W * T + 40.0:
		active = false
		exit_reached.emit()
		return
	if player.in_buggy:
		player.position = buggy.position
		return
	var pr := player.rect()
	for i in range(ore.size() - 1, -1, -1):
		var pos: Vector2 = ore[i]["pos"]
		if Rect2(pos - Vector2(11, 11), Vector2(22, 22)).intersects(pr):
			var o: Dictionary = ore[i]
			ore.remove_at(i)
			ore_lights[i].queue_free()
			ore_lights.remove_at(i)
			buggy.cargo.append(o["mat"]["color"])
			ore_taken.emit(ore.size(), pos, o["mat"])
			if ore.is_empty():
				open_door()
				all_ore_taken.emit(door_light.position)
	var hurt := pr.grow(-3.0)
	var x0 := int(floor(pr.position.x / T))
	var x1 := int(floor(pr.end.x / T))
	var y0 := int(floor(pr.position.y / T))
	var y1 := int(floor(pr.end.y / T))
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			if cell(x, y) == "^" and Rect2(x * T + 5, y * T + 14, T - 10, T - 14).intersects(hurt):
				_kill("SUIT TORN ON CRYSTAL SHARDS")
				return
	for gd in guardians:
		if gd.hit_rect().intersects(hurt):
			_kill("CAUGHT BY A ROGUE MACHINE")
			return
	for r in rocks:
		if float(r["warn"]) <= 0.0 and Rect2(r["pos"] - Vector2(r["size"], r["size"]), Vector2(r["size"], r["size"]) * 2.0).intersects(hurt):
			_kill("CRUSHED BY ROCKFALL")
			return


func _kill(reason: String) -> void:
	if not active:
		return
	active = false
	player_killed.emit(reason)


# ------------------------------------------------------------------ collapse

func _build_cracks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(level_name)
	for i in 9:
		var p := Vector2(rng.randf_range(60, W * T - 60), T)
		var line := PackedVector2Array([p])
		for k in rng.randi_range(4, 8):
			p += Vector2(rng.randf_range(-26, 26), rng.randf_range(10, 34))
			line.append(p)
		cracks.append(line)


func _update_collapse(delta: float) -> void:
	var danger := 1.0 - collapse_frac
	# falling grit, more and more of it
	_debris_timer -= delta
	if _debris_timer <= 0.0:
		_debris_timer = lerpf(0.5, 0.03, danger)
		debris.append({"pos": Vector2(randf_range(T, (W - 1) * T), T + 2), "vy": randf_range(20, 80), "s": randf_range(1.0, 2.5)})
	for i in range(debris.size() - 1, -1, -1):
		var d: Dictionary = debris[i]
		d["vy"] = float(d["vy"]) + 500.0 * delta
		d["pos"] = (d["pos"] as Vector2) + Vector2(0, float(d["vy"]) * delta)
		var p: Vector2 = d["pos"]
		if is_solid(int(p.x / T), int(p.y / T)):
			debris.remove_at(i)
	# rockfall in the last 45 % of the timer
	if active and collapse_frac < 0.45:
		_rock_timer -= delta
		if _rock_timer <= 0.0:
			var k := clampf((0.45 - collapse_frac) / 0.45, 0.0, 1.0)
			_rock_timer = lerpf(2.4, 0.35, k) * randf_range(0.7, 1.3)
			spawn_rock(0.8, randf_range(7.0, 12.0))
	for i in range(rocks.size() - 1, -1, -1):
		var r: Dictionary = rocks[i]
		if float(r["warn"]) > 0.0:
			r["warn"] = float(r["warn"]) - delta
			continue
		r["vy"] = float(r["vy"]) + 1500.0 * delta
		r["rot"] = float(r["rot"]) + delta * 4.0
		var p: Vector2 = r["pos"] + Vector2(0, float(r["vy"]) * delta)
		r["pos"] = p
		var sz: float = r["size"]
		var hit := is_solid(int(p.x / T), int((p.y + sz) / T)) or buggy.rect().has_point(p + Vector2(0, sz))
		if hit or p.y > H * T:
			rocks.remove_at(i)
			rock_landed.emit(p, sz > 11.0)


func spawn_rock(warn: float, size: float, x: float = -1.0) -> void:
	if x < 0.0:
		for attempt in 8:
			x = randf_range(T * 1.5, (W - 1.5) * T)
			if not is_solid(int(x / T), 1):
				break
	rocks.append({"pos": Vector2(x, T + size), "vy": 0.0, "warn": warn, "size": size, "rot": randf() * TAU,
			"seed": randi()})


func cave_in() -> void:
	for i in 34:
		spawn_rock(randf_range(0.0, 0.5), randf_range(9.0, 16.0), (i + randf()) * (W * T) / 34.0)


# ------------------------------------------------------------------ drawing

func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h % 10000) / 10000.0


func _draw_static() -> void:
	var L := _static_layer
	var rock_a := Color(0.13, 0.13, 0.18).lerp(tint, 0.1)
	var rock_b := Color(0.2, 0.2, 0.26).lerp(tint, 0.14)
	var edge := Color(tint.r * 2.2, tint.g * 2.2, tint.b * 2.2)
	for y in H:
		for x in W:
			if cell(x, y) != "#":
				continue
			var r := Rect2(x * T, y * T, T, T)
			var h := _hash(x, y)
			L.draw_rect(r, rock_a.lerp(rock_b, h))
			# chiselled facets
			var p := Vector2(x * T, y * T)
			L.draw_colored_polygon(PackedVector2Array([p + Vector2(2, 2), p + Vector2(18 + h * 10, 3), p + Vector2(10, 16 + h * 8)]),
					rock_b.lightened(0.06 + h * 0.05))
			L.draw_colored_polygon(PackedVector2Array([p + Vector2(30, 30), p + Vector2(12 + h * 8, 29), p + Vector2(29, 12 + h * 6)]),
					rock_a.darkened(0.25))
			if h > 0.82:
				L.draw_circle(p + Vector2(8 + h * 14, 20), 1.8, Color(tint.r * 1.6, tint.g * 1.6, tint.b * 1.6))
			var top_open := not is_solid(x, y - 1)
			var bottom_open := not is_solid(x, y + 1)
			if top_open:
				L.draw_rect(Rect2(x * T, y * T, T, 5), rock_b.lightened(0.25))
				L.draw_rect(Rect2(x * T, y * T, T, 2), edge)
			if bottom_open:
				L.draw_rect(Rect2(x * T, y * T + T - 4, T, 4), rock_a.darkened(0.4))
			if not is_solid(x - 1, y):
				L.draw_rect(Rect2(x * T, y * T, 2, T), rock_b.lightened(0.12))
			if not is_solid(x + 1, y):
				L.draw_rect(Rect2(x * T + T - 2, y * T, 2, T), rock_a.darkened(0.35))


func _draw() -> void:
	# conveyors, crumbling ledges and spikes are animated, so they live in the dynamic layer
	for y in H:
		for x in W:
			var c := cell(x, y)
			match c:
				"<", ">":
					_draw_conveyor(x, y, -1.0 if c == "<" else 1.0)
				"=":
					_draw_crumble(x, y)
				"^":
					_draw_spikes(x, y)
	for o in ore:
		_draw_ore(o)
	_draw_door()
	_draw_collapse()


func _draw_conveyor(x: int, y: int, d: float) -> void:
	var p := Vector2(x * T, y * T)
	draw_rect(Rect2(p, Vector2(T, T)), Color(0.1, 0.11, 0.14))
	draw_rect(Rect2(p + Vector2(0, 3), Vector2(T, 12)), Color(0.2, 0.22, 0.27))
	var off := fposmod(t * CONVEYOR_SPEED * d, 16.0)
	for k in range(-1, 3):
		var cx := p.x + k * 16.0 + off
		if cx < p.x - 4 or cx > p.x + T - 4:
			continue
		var a := Vector2(cx, p.y + 5)
		var tip := Vector2(cx + 5.0 * d, p.y + 9)
		var b := Vector2(cx, p.y + 13)
		draw_polyline(PackedVector2Array([a, tip, b]), Color(1.8, 1.3, 0.35), 2.0)
	draw_rect(Rect2(p, Vector2(T, 2)), Color(0.5, 0.52, 0.6))
	for k in 2:
		var rc := p + Vector2(8 + k * 16, 23)
		draw_circle(rc, 6.0, Color(0.06, 0.06, 0.08))
		draw_circle(rc, 4.5, Color(0.32, 0.34, 0.4))
		var ang := t * 9.0 * d + k
		draw_line(rc, rc + Vector2(cos(ang), sin(ang)) * 4.0, Color(0.08, 0.08, 0.1), 2.0)


func _draw_crumble(x: int, y: int) -> void:
	var hp := 1.0
	var key := Vector2i(x, y)
	if crumble.has(key):
		hp = crumble[key]["hp"]
	var shake := Vector2.ZERO
	if hp < 1.0:
		shake = Vector2(sin(t * 70.0 + x) * 1.5, cos(t * 60.0 + y) * 1.0) * (1.0 - hp) * 2.0
	var p := Vector2(x * T, y * T) + shake
	var thick := lerpf(8.0, 16.0, hp)
	var base := Color(0.45, 0.33, 0.2).lerp(Color(0.25, 0.15, 0.1), 1.0 - hp)
	draw_rect(Rect2(p, Vector2(T, thick)), base)
	draw_rect(Rect2(p, Vector2(T, 2)), Color(1.4, 1.0, 0.5) * (0.5 + 0.5 * hp))
	for k in 4:
		var h := _hash(x * 4 + k, y)
		draw_rect(Rect2(p + Vector2(k * 8 + 1, thick), Vector2(6, (4.0 + h * 6.0) * hp)), base.darkened(0.2))
	if hp < 0.75:
		draw_line(p + Vector2(6, 2), p + Vector2(13, thick - 1), Color(0.05, 0.03, 0.02), 1.5)
	if hp < 0.4:
		draw_line(p + Vector2(22, 2), p + Vector2(17, thick - 1), Color(0.05, 0.03, 0.02), 1.5)


func _draw_spikes(x: int, y: int) -> void:
	var p := Vector2(x * T, y * T + T)
	var pulse := 0.75 + 0.25 * sin(t * 3.0 + x * 0.7)
	var glow := Color(2.6 * pulse, 0.35, 0.9 * pulse)
	var shards := [[4.0, 12.0, 14.0], [11.0, 20.0, 24.0], [19.0, 28.0, 17.0]]
	for s in shards:
		var a: float = s[0]
		var b: float = s[1]
		var hgt: float = s[2]
		var mid := (a + b) * 0.5
		draw_colored_polygon(PackedVector2Array([p + Vector2(a, 0), p + Vector2(mid, -hgt), p + Vector2(b, 0)]), Color(0.35, 0.05, 0.18))
		draw_colored_polygon(PackedVector2Array([p + Vector2(mid, -hgt), p + Vector2(b, 0), p + Vector2(mid + 1, 0)]), Color(0.6, 0.1, 0.3))
		draw_line(p + Vector2(mid, -hgt), p + Vector2(mid, -hgt + 5), glow, 2.0)


func _draw_ore(o: Dictionary) -> void:
	var ph: float = o["phase"]
	var c: Vector2 = o["pos"] + Vector2(0, sin(t * 2.0 + ph) * 2.5)
	var m: Dictionary = o["mat"]
	var col: Color = m["color"]
	var hot := Color(col.r * 2.6, col.g * 2.6, col.b * 2.6)
	var ink := Color(0.03, 0.03, 0.06)
	draw_circle(c, 14.0, Color(col.r, col.g, col.b, 0.07))
	match String(o["kind"]):
		"r":
			# rare-earth crystal cluster
			for k in 3:
				var a := -0.5 + k * 0.5
				var tip := c + Vector2(sin(a) * 11.0, -cos(a) * 12.0 - (2.0 if k == 1 else 0.0))
				var base := c + Vector2((k - 1) * 5.0, 7)
				var side := Vector2(3.5, 0)
				draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), col.darkened(0.15))
				draw_colored_polygon(PackedVector2Array([tip, base + side, base]), hot)
			draw_rect(Rect2(c.x - 9, c.y + 6, 18, 4), Color(0.25, 0.22, 0.24))
		"p":
			# precious-metal nugget with a travelling glint
			var pts := PackedVector2Array()
			for k in 9:
				var a := k * TAU / 9.0
				var r := 9.0 + sin(a * 3.0 + ph) * 2.0
				pts.append(c + Vector2(cos(a) * r, sin(a) * r * 0.8))
			draw_colored_polygon(pts, col.darkened(0.25))
			draw_circle(c + Vector2(-2, -2), 5.5, col)
			var g := fmod(t * 0.8 + ph, 2.0)
			if g < 1.0:
				var gx := lerpf(-8.0, 8.0, g)
				draw_line(c + Vector2(gx - 2, -6), c + Vector2(gx + 2, 4), Color(3.5, 3.5, 3.5), 2.0)
		"b":
			# building material ingot
			var top := PackedVector2Array([c + Vector2(-11, -2), c + Vector2(-7, -8), c + Vector2(11, -8), c + Vector2(7, -2)])
			draw_rect(Rect2(c.x - 11, c.y - 2, 18, 9), col.darkened(0.3))
			draw_colored_polygon(top, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(7, -2), c + Vector2(11, -8), c + Vector2(11, 1), c + Vector2(7, 7)]), col.darkened(0.45))
			draw_line(c + Vector2(-6, -6), c + Vector2(6, -6), hot, 1.5)
	var sym: String = m["sym"]
	draw_string_outline(font, c + Vector2(-20, -14), sym, HORIZONTAL_ALIGNMENT_CENTER, 40, 11, 4, ink)
	draw_string(font, c + Vector2(-20, -14), sym, HORIZONTAL_ALIGNMENT_CENTER, 40, 11, Color(col.r * 1.8, col.g * 1.8, col.b * 1.8))


func _draw_door() -> void:
	if door_cells.is_empty():
		return
	var x := door_cells[0].x * T
	var y0 := 17 * T
	# dark tunnel mouth behind
	draw_rect(Rect2(x, y0, T, T * 2), Color(0.01, 0.01, 0.02))
	for k in 4:
		var lx := x + 4 + k * 8 - fposmod(t * 30.0, 8.0)
		draw_rect(Rect2(lx, y0 + 3, 2, 2), Color(0.3, 1.2, 0.5) if door_open else Color(0.4, 0.1, 0.05))
	var h := T * 2 * (1.0 - door_t)
	if h > 1.0:
		draw_rect(Rect2(x + 2, y0, T - 4, h), Color(0.3, 0.31, 0.35))
		var stripes := int(h / 10.0)
		for i in stripes:
			var sy := y0 + h - 10.0 - i * 10.0
			draw_colored_polygon(PackedVector2Array([Vector2(x + 2, sy), Vector2(x + 12, sy), Vector2(x + 2, sy + 6)]), Color(1.0, 0.75, 0.1))
		draw_rect(Rect2(x + 2, y0 + h - 3, T - 4, 3), Color(0.1, 0.1, 0.12))
	var lamp := Color(0.4, 3.0, 1.0) if door_open else Color(3.0 * (0.6 + 0.4 * sin(t * 5.0)), 0.4, 0.2)
	draw_circle(Vector2(x - 6, y0 - 6), 3.5, lamp)
	if door_open:
		draw_rect(Rect2(x + 10, y0, 3, T * 2), Color(0.3, 1.6, 2.0, 0.25 + 0.15 * sin(t * 9.0)))


func _draw_collapse() -> void:
	var danger := 1.0 - collapse_frac
	if danger > 0.25:
		var a := clampf((danger - 0.25) / 0.6, 0.0, 1.0)
		for line in cracks:
			var n := maxi(2, int(line.size() * a))
			draw_polyline(line.slice(0, n), Color(0.02, 0.01, 0.01, 0.85), 2.5)
			if a > 0.6:
				draw_polyline(line.slice(0, n), Color(2.0, 0.5, 0.2, (a - 0.6) * 0.6), 1.0)
	for d in debris:
		draw_rect(Rect2(d["pos"], Vector2(d["s"], d["s"])), Color(0.55, 0.5, 0.45, 0.8))
	for r in rocks:
		var p: Vector2 = r["pos"]
		var sz: float = r["size"]
		if float(r["warn"]) > 0.0:
			# warning trickle and dust where the rock is about to break loose
			var w := 1.0 - float(r["warn"])
			for k in 4:
				var yy := T + fposmod(t * 160.0 + k * 13.0, 60.0 * w + 4.0)
				draw_rect(Rect2(p.x - 2 + k, yy, 2, 2), Color(0.6, 0.55, 0.5, 0.9))
			draw_line(Vector2(p.x - sz, T + 1), Vector2(p.x + sz, T + 1), Color(2.0, 0.6, 0.2, 0.5 + 0.5 * sin(t * 30.0)), 2.0)
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = int(r["seed"])
		var pts := PackedVector2Array()
		for k in 7:
			var a := float(r["rot"]) + k * TAU / 7.0
			pts.append(p + Vector2(cos(a), sin(a)) * sz * rng.randf_range(0.75, 1.15))
		draw_colored_polygon(pts, Color(0.3, 0.27, 0.26))
		pts.append(pts[0])
		draw_polyline(pts, Color(0.06, 0.05, 0.05), 2.0)
