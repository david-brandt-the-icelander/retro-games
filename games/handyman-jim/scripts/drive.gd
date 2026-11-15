extends Node2D
## Top-down driving around Marshfield. The van is deliberately too fast.

const ACCEL := 210.0
const BRAKE := 330.0
const REVERSE_MAX := -90.0
const MAX_SPEED := 250.0
const COAST := 70.0
const ZOOM := 0.6           # < 1 shows more of town
const STEER := 2.7
const VAN_R := 11.0

var main: Node
var cam: Camera2D
var t := 0.0
var van_pos := Vector2()
var van_angle := 0.0
var van_speed := 0.0
var van_vel := Vector2()
var trees: Array = []       # [pos, r]
var objs: Array = []        # decor + event objects
var cars: Array = []
var peds: Array = []
var zones: Array = []       # slippery curds {pos, r, ttl}
var in_box := Vector2i(-1, -1)
var prompt_place: Dictionary = {}
var hit_cool := 0.0
var event_timer := 25.0
var wall_cool := 0.0
var current_lot := ""      # the driveway/lot the van is parked in ("" on the road)
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(Town.W)
	cam.limit_bottom = int(Town.H)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 8.0
	cam.zoom = Vector2(ZOOM, ZOOM)
	add_child(cam)
	_build_scenery()
	for i in 12:
		_spawn_car("car")
	_spawn_car("cop")
	for i in 18:
		_spawn_ped()

func activate(place_id: String) -> void:
	var p := Town.place(place_id)
	var lot: Rect2 = p.lot
	van_pos = lot.get_center()
	van_angle = -PI / 2 if p.side == "t" else PI / 2
	van_speed = 0.0
	van_vel = Vector2.ZERO
	in_box = Vector2i(-1, -1)
	current_lot = lot_at(van_pos)
	cam.enabled = true
	cam.make_current()
	cam.position = van_pos
	cam.reset_smoothing()
	visible = true

func deactivate() -> void:
	cam.enabled = false
	visible = false

## Daily reset of knocked-over trash cans etc.
func reset_day() -> void:
	objs = objs.filter(func(o): return o.static)
	for o in objs:
		o.alive = true
	zones.clear()
	for p in peds:
		p.alive = true

func _build_scenery() -> void:
	for p in Town.places():
		var r: Rect2 = p.rect
		if p.kind == "park":
			for i in 7:
				trees.append([r.position + Vector2(rng.randf_range(15, r.size.x - 15), rng.randf_range(15, r.size.y - 15)), rng.randf_range(10, 16)])
		elif p.kind == "house":
			var lot: Rect2 = p.lot
			var edge := lot.position.y + 6 if p.side == "t" else lot.end.y - 6
			objs.append(_obj("trash", Vector2(lot.position.x + 14, edge), 5, true))
			objs.append(_obj("mailbox", Vector2(lot.end.x - 14, edge), 4, true))
	# back yards between rows of buildings
	for col in 3:
		for row in 2:
			var x0: float = Town.ROADS_X[col] + 70
			var y0: float = Town.ROADS_Y[row] + 56 + 210
			var y1: float = Town.ROADS_Y[row + 1] - 56 - 210
			for i in 6:
				trees.append([Vector2(x0 + 30 + i * 100 + rng.randf_range(-10, 10), rng.randf_range(y0 + 15, y1 - 15)), rng.randf_range(12, 20)])
	# woods around the edge of town
	var xs := [Town.ROADS_X[0] - 120, Town.ROADS_X[-1] + 120]
	for x in xs:
		var y := 20.0
		while y < Town.H:
			trees.append([Vector2(x + rng.randf_range(-50, 50), y), rng.randf_range(18, 28)])
			y += 45
	# hydrants at a few corners
	for rx in Town.ROADS_X:
		for ry in Town.ROADS_Y:
			if rng.randf() < 0.6:
				objs.append(_obj("hydrant", Vector2(rx + Town.RW + 6, ry + Town.RW + 6), 4, true))

func _obj(kind: String, pos: Vector2, r: float, is_static: bool) -> Dictionary:
	return {"kind": kind, "pos": pos, "r": r, "alive": true, "static": is_static,
		"vel": Vector2.ZERO, "ttl": 90.0}

# ---------------------------------------------------------------- traffic

const CAR_COLORS := [Pal.BLUE, Pal.RED, Pal.LGRAY, Pal.CYAN, Pal.BROWN, Pal.MAGENTA, Pal.GREEN, Pal.YELLOW]

func _lane_pos(horizontal: bool, road: int, fwd: int, along: float) -> Vector2:
	if horizontal:
		return Vector2(along, Town.ROADS_Y[road] + 20.0 * fwd)
	return Vector2(Town.ROADS_X[road] - 20.0 * fwd, along)

func _spawn_car(kind: String) -> void:
	var horizontal := rng.randf() < 0.5
	var fwd := 1 if rng.randf() < 0.5 else -1
	var road := rng.randi_range(0, (Town.ROADS_Y.size() if horizontal else Town.ROADS_X.size()) - 1)
	var along := rng.randf_range(300, 2300) if horizontal else rng.randf_range(300, 1600)
	var dir := Vector2(fwd, 0) if horizontal else Vector2(0, fwd)
	cars.append({"kind": kind, "pos": _lane_pos(horizontal, road, fwd, along), "dir": dir,
		"h": horizontal, "road": road, "speed": 0.0, "max": rng.randf_range(90, 140),
		"color": Pal.WHITE if kind == "cop" else CAR_COLORS[rng.randi_range(0, CAR_COLORS.size() - 1)],
		"cool": 0.0})

func _update_cars(dt: float) -> void:
	for c in cars:
		c.cool = maxf(0.0, c.cool - dt)
		var target: float = c.max
		var along: float = c.pos.x if c.h else c.pos.y
		var fwd: float = c.dir.x if c.h else c.dir.y
		var lines: Array = Town.ROADS_X if c.h else Town.ROADS_Y
		# red light ahead?
		for i in lines.size():
			var stop: float = lines[i] - fwd * (Town.RW + 22)
			var dist: float = (stop - along) * fwd
			if dist > 0 and dist < 60:
				var ii: int = i if c.h else c.road
				var jj: int = c.road if c.h else i
				if Town.light(ii, jj, "EW" if c.h else "NS", t) != "G":
					target = 0.0
		# something in front?
		for o in cars:
			if o != c and _ahead(c, o.pos, 48):
				target = 0.0
		if _ahead(c, van_pos, 52):
			target = 0.0
		for p in peds:
			if p.alive and _ahead(c, p.pos, 40, 16):
				target = 0.0
		if c.cool > 0:
			target = 0.0
		c.speed = move_toward(c.speed, target, (160.0 if target > c.speed else 400.0) * dt)
		c.pos += c.dir * c.speed * dt
		# end of the road: U-turn into the other lane
		var lo: float = (Town.ROADS_X[0] if c.h else Town.ROADS_Y[0]) - 10
		var hi: float = (Town.ROADS_X[-1] if c.h else Town.ROADS_Y[-1]) + 10
		along = c.pos.x if c.h else c.pos.y
		if (fwd > 0 and along > hi) or (fwd < 0 and along < lo):
			c.dir = -c.dir
			c.pos = _lane_pos(c.h, c.road, -int(fwd), along)

func _ahead(c: Dictionary, p: Vector2, dist: float, lateral: float = 12.0) -> bool:
	var d: Vector2 = p - c.pos
	var a := d.dot(c.dir)
	var lat: float = absf(d.cross(c.dir))
	return a > 0 and a < dist and lat < lateral

# ---------------------------------------------------------------- pedestrians

const SHIRTS := [Pal.LRED, Pal.YELLOW, Pal.LGREEN, Pal.LBLUE, Pal.LMAGENTA, Pal.WHITE, Pal.GREEN]

func _spawn_ped(kind: String = "ped", pos: Vector2 = Vector2.INF, dir: Vector2 = Vector2.ZERO) -> void:
	if pos == Vector2.INF:
		var horizontal := rng.randf() < 0.5
		if horizontal:
			var ry: float = Town.ROADS_Y[rng.randi_range(0, 2)] + (48.0 if rng.randf() < 0.5 else -48.0)
			pos = Vector2(rng.randf_range(300, 2300), ry)
			dir = Vector2(1 if rng.randf() < 0.5 else -1, 0)
		else:
			var rx: float = Town.ROADS_X[rng.randi_range(0, 3)] + (48.0 if rng.randf() < 0.5 else -48.0)
			pos = Vector2(rx, rng.randf_range(300, 1600))
			dir = Vector2(0, 1 if rng.randf() < 0.5 else -1)
	var shirt: Color = Pal.GREEN if kind == "fan" else SHIRTS[rng.randi_range(0, SHIRTS.size() - 1)]
	peds.append({"kind": kind, "pos": pos, "dir": dir, "speed": rng.randf_range(16, 30),
		"shirt": shirt, "alive": true, "phase": rng.randf() * 6.0, "ttl": 999.0 if kind == "ped" else 80.0})

func _update_peds(dt: float) -> void:
	var lo := Vector2(Town.ROADS_X[0] - 48, Town.ROADS_Y[0] - 48)
	var hi := Vector2(Town.ROADS_X[-1] + 48, Town.ROADS_Y[-1] + 48)
	for p in peds:
		if not p.alive:
			continue
		p.ttl -= dt
		p.phase += dt * 8.0
		var old: Vector2 = p.pos
		p.pos += p.dir * p.speed * dt
		if p.kind == "fan":
			continue
		# reached a sidewalk corner? maybe turn
		var corners: Array = []
		var horiz: bool = p.dir.y == 0
		for v in (Town.ROADS_X if horiz else Town.ROADS_Y):
			corners.append(v - 48.0)
			corners.append(v + 48.0)
		for cval in corners:
			var a: float = old.x if horiz else old.y
			var b: float = p.pos.x if horiz else p.pos.y
			if (a - cval) * (b - cval) <= 0 and a != b and rng.randf() < 0.35:
				if horiz:
					p.pos.x = cval
					p.dir = Vector2(0, 1 if rng.randf() < 0.5 else -1)
				else:
					p.pos.y = cval
					p.dir = Vector2(1 if rng.randf() < 0.5 else -1, 0)
				break
		if p.pos.x < lo.x or p.pos.x > hi.x or p.pos.y < lo.y or p.pos.y > hi.y:
			p.pos = old
			p.dir = -p.dir
	peds = peds.filter(func(p): return p.ttl > 0)

# ---------------------------------------------------------------- the van

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	if Game.modal or main.hud.paused():
		queue_redraw()
		return
	hit_cool = maxf(0.0, hit_cool - dt)
	wall_cool = maxf(0.0, wall_cool - dt)
	_update_cars(dt)
	_update_peds(dt)
	_update_events(dt)
	_update_van(dt)
	_check_hits()
	_check_lights()
	_check_prompt()
	var act_horn := Game.free_input() and Input.is_action_just_pressed("act") and prompt_place.is_empty()
	if Game.free_input() and Input.is_action_just_pressed("horn") or act_horn:
		Sfx.horn()
		Game.say("*HOOOONK*  (somewhere, a dog barks back)")
		for p in peds:
			if p.pos.distance_to(van_pos) < 120:
				p.speed = 60.0
	cam.position = van_pos + van_vel * 0.5
	queue_redraw()

func _update_van(dt: float) -> void:
	var grip := 7.0
	var slippery := false
	for z in zones:
		if van_pos.distance_to(z.pos) < z.r:
			grip = 0.8
			slippery = true
	var on_road := Town.on_road(van_pos)
	if Game.gas <= 0.0:
		_out_of_gas()
		return
	if Input.is_action_pressed("up"):
		van_speed += ACCEL * dt
	elif Input.is_action_pressed("down"):
		van_speed -= (BRAKE if van_speed > 0 else 150.0) * dt
	else:
		van_speed = move_toward(van_speed, 0.0, COAST * dt)
	var top := MAX_SPEED if on_road else MAX_SPEED * 0.55
	if not on_road and van_speed > top:
		van_speed = move_toward(van_speed, top, 300.0 * dt)
	van_speed = clampf(van_speed, REVERSE_MAX, MAX_SPEED)
	var steer := 0.0
	if Input.is_action_pressed("left"):
		steer -= 1.0
	if Input.is_action_pressed("right"):
		steer += 1.0
	# steering needs motion, and at full tilt it gets twitchy
	var authority := clampf(absf(van_speed) / 80.0, 0.0, 1.0) * (1.0 + van_speed / MAX_SPEED * 0.3)
	van_angle += steer * STEER * authority * signf(van_speed) * dt
	var want := Vector2.from_angle(van_angle) * van_speed
	van_vel = van_vel.lerp(want, clampf(grip * dt, 0.0, 1.0))
	if slippery and absf(van_speed) > 80 and rng.randf() < 0.02:
		Game.say("SQUEAK SQUEAK. The curds have you sliding!")
	var old := van_pos
	var step := van_vel * dt
	van_pos += step
	Game.gas -= step.length() / Data.PX_PER_GALLON
	# rolling into a driveway or parking lot brings the van to a stop
	var lot := lot_at(van_pos)
	if lot != current_lot:
		current_lot = lot
		if lot != "":
			van_speed = 0.0
			van_vel = Vector2.ZERO
	if _blocked(van_pos):
		van_pos = old
		if absf(van_speed) > 110 and wall_cool <= 0:
			_fine("wall")
			wall_cool = 2.0
		van_speed *= -0.3
		van_vel *= -0.3

## id of the driveway / parking lot under p, or "".
func lot_at(p: Vector2) -> String:
	for pl in Town.places():
		if pl.kind != "park" and (pl.lot as Rect2).has_point(p):
			return pl.id
	return ""

func _blocked(p: Vector2) -> bool:
	if p.x < Town.ROADS_X[0] - 70 or p.x > Town.ROADS_X[-1] + 70 or p.y < 12 or p.y > Town.H - 12:
		return true
	for pl in Town.places():
		if pl.kind != "park" and (pl.rect as Rect2).grow(VAN_R - 4).has_point(p):
			return true
	for tr in trees:
		if p.distance_to(tr[0]) < tr[1] * 0.6 + VAN_R:
			return true
	return false

func _out_of_gas() -> void:
	van_speed = 0.0
	van_vel = Vector2.ZERO
	main.dialog.message(["Sputter... cough... the van is out of gas.",
		"Earl's Towing hauls you to the Gas-N-Grub. $120 and 45 minutes of Earl's opinions."],
		func():
			Game.charge(120, "tow")
			Game.advance(45)
			Game.gas = 3.0
			activate("gas"))

func _fine(kind: String) -> void:
	var h: Array = Data.HITS[kind]
	if h[1]:
		main.arrest(h[2], h[0])
	else:
		Game.charge(h[0], h[2].split(".")[0])

func _check_hits() -> void:
	var spd := van_vel.length()
	for o in objs:
		if o.alive and van_pos.distance_to(o.pos) < o.r + VAN_R and spd > 25:
			o.alive = false
			if o.kind != "curds":
				_fine(o.kind)
	for p in peds:
		if p.alive and van_pos.distance_to(p.pos) < 4 + VAN_R:
			if spd > 55:
				p.alive = false
				_fine("fan" if p.kind == "fan" else "ped")
				return
			elif hit_cool <= 0:
				hit_cool = 2.0
				Game.say("Pedestrian: \"HEY! WATCH IT, YA HOSER!\"")
				p.pos += (p.pos - van_pos).normalized() * 8
	for c in cars:
		if van_pos.distance_to(c.pos) < 13 + VAN_R and c.cool <= 0:
			c.cool = 2.0
			van_pos -= van_vel.normalized() * 6
			if c.kind == "cop" and spd > 90:
				_fine("cop")
				return
			elif c.kind == "cop":
				Game.charge(100, "Officer Brekke: 'Careless driving, Jim.'")
			elif spd > 50:
				_fine("car")
			else:
				Game.say("Bump. The other driver gives you the Wisconsin wave. Sort of.")
			van_speed *= -0.3
			van_vel *= -0.3

func _check_lights() -> void:
	var box := Vector2i(-1, -1)
	for i in Town.ROADS_X.size():
		for j in Town.ROADS_Y.size():
			if absf(van_pos.x - Town.ROADS_X[i]) < Town.RW and absf(van_pos.y - Town.ROADS_Y[j]) < Town.RW:
				box = Vector2i(i, j)
	if box != in_box and box.x >= 0 and van_vel.length() > 40:
		var axis := "EW" if absf(van_vel.x) > absf(van_vel.y) else "NS"
		if Town.light(box.x, box.y, axis, t) == "R":
			var cop_near := false
			for c in cars:
				if c.kind == "cop" and c.pos.distance_to(van_pos) < 450:
					cop_near = true
			if cop_near or rng.randf() < 0.3:
				Game.tickets_today += 1
				if Game.tickets_today >= 3:
					main.arrest("Third red light today. Officer Brekke has had ENOUGH of you.", 350)
				else:
					Game.charge(90, "Red light ticket #%d (3 and you're jailed)" % Game.tickets_today)
			else:
				Game.say("You ran a red! Nobody saw... this time.")
	in_box = box

func _check_prompt() -> void:
	prompt_place = {}
	if absf(van_speed) > 45:
		return
	for p in Town.places():
		if p.kind != "park" and (p.lot as Rect2).has_point(van_pos):
			prompt_place = p
	if not prompt_place.is_empty() and Game.free_input() and Input.is_action_just_pressed("act"):
		van_speed = 0.0
		van_vel = Vector2.ZERO
		main.enter_place(prompt_place)

# ---------------------------------------------------------------- road events

func _update_events(dt: float) -> void:
	event_timer -= dt
	if event_timer <= 0:
		event_timer = rng.randf_range(30, 55)
		_spawn_event(Data.ROAD_EVENTS[rng.randi_range(0, Data.ROAD_EVENTS.size() - 1)])
	for o in objs:
		if o.static:
			continue
		o.ttl -= dt
		if o.kind == "cow" and rng.randf() < dt * 0.5:
			o.vel = Vector2.from_angle(rng.randf() * TAU) * 18.0
		if o.kind == "deer" and not o.has("decided") and o.pos.distance_to(van_pos) < 110:
			o["decided"] = true
			if rng.randf() < 0.5:
				o.vel = Vector2.from_angle(rng.randf() * TAU) * 150.0
				Game.say("The deer BOLTS. Wisconsin luck!")
		var np: Vector2 = o.pos + o.vel * dt
		if o.kind == "cow" and not Town.on_road(np):
			o.vel = -o.vel
		else:
			o.pos = np
	objs = objs.filter(func(o): return o.static or o.ttl > 0)
	for z in zones:
		z.ttl -= dt
	zones = zones.filter(func(z): return z.ttl > 0)

func _spawn_event(ev: Array) -> void:
	var ahead := van_pos + Vector2.from_angle(van_angle) * 300.0
	var best := INF
	var horizontal := true
	var spot := Vector2()
	for ry in Town.ROADS_Y:
		var d: float = absf(ahead.y - ry)
		if d < best:
			best = d
			horizontal = true
			spot = Vector2(clampf(ahead.x, Town.ROADS_X[0], Town.ROADS_X[-1]), ry)
	for rx in Town.ROADS_X:
		var d: float = absf(ahead.x - rx)
		if d < best:
			best = d
			horizontal = false
			spot = Vector2(rx, clampf(ahead.y, Town.ROADS_Y[0], Town.ROADS_Y[-1]))
	var along := Vector2(1, 0) if horizontal else Vector2(0, 1)
	var across := Vector2(0, 1) if horizontal else Vector2(1, 0)
	Game.say(ev[0])
	match ev[1]:
		"cow", "deer":
			objs.append(_obj(ev[1], spot, 10, false))
		"mower":
			var o := _obj("mower", spot + across * 20, 8, false)
			o.vel = along * 22.0
			objs.append(o)
		"curds":
			zones.append({"pos": spot, "r": 75.0, "ttl": 70.0})
		"goose":
			for i in ev[2]:
				var o := _obj("goose", spot - across * 44 + along * (i * 14 - 28), 4, false)
				o.vel = across * 12.0
				o.ttl = 18.0
				objs.append(o)
		"cone":
			for i in ev[2]:
				objs.append(_obj("cone", spot + along * (i * 26 - 65) + across * 18, 4, false))
		"fan":
			for i in ev[2]:
				var start: Vector2 = spot - across * 56 + along * (i * 16 - 40)
				_spawn_ped("fan", start, across)
				peds[-1].ttl = 14.0
				peds[-1].speed = 10.0

# ---------------------------------------------------------------- drawing

const ROOF := {"shop": Pal.RED, "gas": Pal.YELLOW, "hardware": Pal.LRED, "bank": Pal.LGRAY,
	"police": Pal.BLUE, "tavern": Pal.BROWN, "plumbing": Pal.LBLUE, "electric": Pal.YELLOW,
	"lumber": Pal.BROWN, "farm": Pal.RED}

func _draw() -> void:
	Art.dfill(self, Rect2(0, 0, Town.W, Town.H), Pal.GREEN, Pal.LGREEN)
	var x0: float = Town.ROADS_X[0] - Town.RW
	var x1: float = Town.ROADS_X[-1] + Town.RW
	var y0: float = Town.ROADS_Y[0] - Town.RW
	var y1: float = Town.ROADS_Y[-1] + Town.RW
	var sw := Town.SW
	# sidewalks
	for ry in Town.ROADS_Y:
		Art.shape(self, Rect2(x0 - sw, ry - Town.RW - sw, x1 - x0 + sw * 2, (Town.RW + sw) * 2), Pal.LGRAY)
	for rx in Town.ROADS_X:
		Art.shape(self, Rect2(rx - Town.RW - sw, y0 - sw, (Town.RW + sw) * 2, y1 - y0 + sw * 2), Pal.LGRAY)
	# asphalt
	for ry in Town.ROADS_Y:
		Art.dfill(self, Rect2(x0, ry - Town.RW, x1 - x0, Town.RW * 2), Pal.DGRAY, Pal.BLACK)
	for rx in Town.ROADS_X:
		Art.dfill(self, Rect2(rx - Town.RW, y0, Town.RW * 2, y1 - y0), Pal.DGRAY, Pal.BLACK)
	# centre dashes (skip intersections)
	for ry in Town.ROADS_Y:
		var x := x0
		while x < x1:
			if not _near_any(x, Town.ROADS_X, Town.RW + 10):
				Art.shape(self, Rect2(x, ry - 1, 14, 2), Pal.YELLOW)
			x += 28
	for rx in Town.ROADS_X:
		var y := y0
		while y < y1:
			if not _near_any(y, Town.ROADS_Y, Town.RW + 10):
				Art.shape(self, Rect2(rx - 1, y, 2, 14), Pal.YELLOW)
			y += 28
	# crosswalk stripes
	for rx in Town.ROADS_X:
		for ry in Town.ROADS_Y:
			for k in 6:
				var o := -Town.RW + 4 + k * 13
				for s in [-1, 1]:
					Art.shape(self, Rect2(rx + o, ry + s * (Town.RW + 4) - 3, 7, 6), Pal.WHITE)
					Art.shape(self, Rect2(rx + s * (Town.RW + 4) - 3, ry + o, 6, 7), Pal.WHITE)
	for z in zones:
		Art.circ(self, z.pos, z.r, Color(Pal.YELLOW, 0.55))
		for k in 14:
			Art.shape(self, Rect2(z.pos + Vector2.from_angle(k * 2.3) * fmod(k * 17.0, z.r), Vector2(4, 3)), Pal.WHITE)
	_draw_places()
	for tr in trees:
		Art.tree_top(self, tr[0], tr[1])
	_draw_objs()
	for p in peds:
		if p.alive:
			_draw_ped(p)
	for c in cars:
		Art.vehicle_top(self, c.pos, c.dir.angle(), c.color, c.kind, t)
	Art.vehicle_top(self, van_pos, van_angle, Pal.WHITE, "van")
	_draw_lights()

func _near_any(v: float, arr: Array, d: float) -> bool:
	for a in arr:
		if absf(v - a) < d:
			return true
	return false

func _draw_places() -> void:
	for p in Town.places():
		var r: Rect2 = p.rect
		var lot: Rect2 = p.lot
		if p.kind == "park":
			Art.dfill(self, r.grow(4), Pal.GREEN, Pal.GREEN)
			Art.text_shadow(self, r.get_center() + Vector2(-22, 6), "PARK", Pal.WHITE, 16)
			continue
		if p.kind == "house":
			Art.shape(self, lot.grow_individual(-80, 0, -80, 0), Pal.LGRAY)   # driveway
			Art.shape(self, r, Color(0, 0, 0, 0.4), true)
			Art.shape(self, Rect2(r.position + Vector2(-3, -3), r.size), p.roof)
			Art.shape(self, Rect2(r.position.x - 3, r.get_center().y - 5, r.size.x, 4), Pal.BLACK)
			var j := Game.job_for_house(p.id)
			var label := "%d" % p.number
			if not j.is_empty():
				label = "#%d %s" % [j.num, Game.last_name(j).to_upper()]
				var blink := int(t * 3) % 2 == 0
				Art.shape(self, lot, Color(Pal.YELLOW, 0.35 if blink else 0.15))
			Art.text_shadow(self, Vector2(r.position.x + 8, r.position.y + 24), label, Pal.WHITE, 18)
		else:
			Art.dfill(self, lot, Pal.DGRAY, Pal.LGRAY)
			for k in 5:
				Art.shape(self, Rect2(lot.position.x + 10 + k * 44, lot.position.y + 6, 2, lot.size.y - 12), Pal.YELLOW)
			Art.shape(self, Rect2(r.position + Vector2(4, 4), r.size), Color(0, 0, 0, 0.4))
			Art.shape(self, r, ROOF.get(p.kind, Pal.LGRAY))
			Art.shape(self, r.grow(-8), Color(1, 1, 1, 0.12))
			Art.text_shadow(self, Vector2(r.position.x + 8, r.get_center().y + 7), p.name, Pal.WHITE, 18)

func _draw_objs() -> void:
	for o in objs:
		var p: Vector2 = o.pos
		match o.kind:
			"trash":
				if o.alive:
					Art.shape(self, Rect2(p - Vector2(4, 4), Vector2(8, 8)), Pal.DGRAY)
					Art.shape(self, Rect2(p - Vector2(3, 3), Vector2(6, 6)), Pal.LGRAY)
				else:
					Art.shape(self, Rect2(p + Vector2(-6, 0), Vector2(10, 4)), Pal.DGRAY)
			"mailbox":
				if o.alive:
					Art.shape(self, Rect2(p - Vector2(3, 4), Vector2(6, 8)), Pal.BLUE)
			"hydrant":
				if o.alive:
					Art.circ(self, p, 4, Pal.RED)
				else:
					Art.circ(self, p, 14 + sin(t * 9) * 2, Color(Pal.LCYAN, 0.6))
			"cone":
				if o.alive:
					draw_colored_polygon(PackedVector2Array([p + Vector2(0, -5), p + Vector2(4, 4), p + Vector2(-4, 4)]), Pal.LRED)
			"cow":
				if o.alive:
					Art.shape(self, Rect2(p - Vector2(10, 6), Vector2(20, 12)), Pal.WHITE)
					Art.shape(self, Rect2(p - Vector2(6, 4), Vector2(6, 5)), Pal.BLACK)
					Art.shape(self, Rect2(p + Vector2(3, 0), Vector2(5, 4)), Pal.BLACK)
					Art.shape(self, Rect2(p + Vector2(10, -3), Vector2(5, 6)), Pal.LMAGENTA)
			"goose":
				if o.alive:
					Art.circ(self, p, 3, Pal.LGRAY)
					Art.shape(self, Rect2(p + Vector2(-1, -6), Vector2(2, 4)), Pal.BLACK)
			"mower":
				if o.alive:
					Art.shape(self, Rect2(p - Vector2(8, 6), Vector2(16, 12)), Pal.GREEN)
					Art.shape(self, Rect2(p - Vector2(3, 3), Vector2(6, 6)), Pal.YELLOW)
					Art.circ(self, p + Vector2(-2, 0), 2.5, Color8(255, 170, 85))
			"deer":
				if o.alive:
					Art.shape(self, Rect2(p - Vector2(9, 4), Vector2(18, 8)), Pal.BROWN)
					Art.shape(self, Rect2(p + Vector2(8, -3), Vector2(5, 6)), Pal.BROWN)
					draw_line(p + Vector2(11, -3), p + Vector2(15, -9), Pal.YELLOW, 1)
					draw_line(p + Vector2(11, 3), p + Vector2(15, 9), Pal.YELLOW, 1)

func _draw_ped(p: Dictionary) -> void:
	var pos: Vector2 = p.pos
	var bob := sin(p.phase) * 1.5
	Art.circ(self, pos + Vector2(1, 1), 4, Color(0, 0, 0, 0.3))
	Art.circ(self, pos, 3.5, p.shirt)
	Art.circ(self, pos + p.dir * 1.5 + Vector2(bob * 0.3, 0), 2.2, Color8(255, 170, 85))
	if p.kind == "fan":
		Art.shape(self, Rect2(pos - Vector2(3, 3), Vector2(6, 3)), Pal.YELLOW)

func _draw_lights() -> void:
	for i in Town.ROADS_X.size():
		for j in Town.ROADS_Y.size():
			var c := Vector2(Town.ROADS_X[i], Town.ROADS_Y[j])
			var ew := Town.light(i, j, "EW", t)
			var ns := Town.light(i, j, "NS", t)
			for s in [-1, 1]:
				_lamp(c + Vector2(s * (Town.RW + 10), -s * (Town.RW + 10)), ew, true)
				_lamp(c + Vector2(s * (Town.RW + 10), s * (Town.RW + 10)), ns, false)

## Horizontal housings govern east-west traffic, vertical ones north-south.
func _lamp(p: Vector2, st: String, horizontal: bool) -> void:
	var sz := Vector2(16, 7) if horizontal else Vector2(7, 16)
	Art.shape(self, Rect2(p - sz / 2, sz), Pal.BLACK)
	var col := Pal.LGREEN if st == "G" else (Pal.YELLOW if st == "Y" else Pal.LRED)
	var off := Vector2(4, 0) if horizontal else Vector2(0, 4)
	Art.circ(self, p - off, 2.5, col if st == "R" else Pal.DGRAY)
	Art.circ(self, p + off, 2.5, col if st != "R" else Pal.DGRAY)
