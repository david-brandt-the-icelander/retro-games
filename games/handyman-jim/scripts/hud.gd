extends Node2D
## Status bar, job list, toasts, minimap, destination arrows and the map-and-jobs planner.

var main: Node
var toasts: Array = []    # [text, ttl]
var planner := false      # map + job board, one screen; the game is frozen while it's up
var t := 0.0

func _ready() -> void:
	Game.toast.connect(_on_toast)

func _on_toast(s: String) -> void:
	toasts.append([s, 5.0])
	if toasts.size() > 4:
		toasts.pop_front()

func _process(dt: float) -> void:
	t += dt
	for ts in toasts:
		ts[1] -= dt
	toasts = toasts.filter(func(ts): return ts[1] > 0)
	var live: bool = main.mode in ["drive", "room"] and Game.free_input()
	if live and (Input.is_action_just_pressed("jobs") or Input.is_action_just_pressed("map")):
		planner = not planner
	elif live and planner and Input.is_action_just_pressed("cancel"):
		planner = false
	if not main.mode in ["drive", "room"]:
		planner = false
	queue_redraw()

func _draw() -> void:
	if not main.mode in ["drive", "room"]:
		toasts.clear()
		return
	draw_rect(Rect2(0, 0, 640, 15), Pal.BLUE)
	var late := Game.minute > Data.DAY_END - 60
	var clock := "%s  %s  WEEK %d" % [Game.day_name().substr(0, 3).to_upper(), Game.clock_text(), Game.week]
	Art.text(self, Vector2(4, 12), clock, Pal.LRED if late and int(t * 2) % 2 == 0 else Pal.WHITE, 12)
	Art.text(self, Vector2(190, 12), "CASH $%d" % Game.cash, Pal.LGREEN, 12)
	Art.text(self, Vector2(300, 12), "DEBT $%d" % Game.debt, Pal.LRED if Game.debt > 0 else Pal.WHITE, 12)
	Art.text(self, Vector2(440, 12), "GAS", Pal.WHITE, 12)
	var frac := clampf(Game.gas / Data.TANK_SIZE, 0, 1)
	draw_rect(Rect2(470, 4, 60, 8), Pal.BLACK)
	draw_rect(Rect2(470, 4, 60 * frac, 8), Pal.LGREEN if frac > 0.25 else Pal.LRED)
	Art.text(self, Vector2(546, 12), "ENTER map/jobs", Pal.LCYAN, 10)
	_draw_job_list()
	if main.mode == "drive":
		_draw_minimap()
		_draw_arrows()
		var pp: Dictionary = main.drive.prompt_place
		if not pp.is_empty():
			var what: String = pp.name
			if pp.kind == "house":
				var j := Game.job_for_house(pp.id)
				what = ("the %s place (job #%d)" % [Game.last_name(j), j.num]) if not j.is_empty() else "%d %s" % [pp.number, pp.street]
			Art.text_shadow(self, Vector2(0, 300), "[SPACE] Go to " + what, Pal.YELLOW, 14, HORIZONTAL_ALIGNMENT_CENTER, 640)
		var spd := int(main.drive.van_vel.length() / 5.0)
		Art.text_shadow(self, Vector2(6, 392), "%d MPH" % spd, Pal.LRED if spd > 45 else Pal.WHITE, 12)
	_draw_toasts()
	if planner:
		_draw_planner()

func _draw_job_list() -> void:
	var y := 28.0
	for j in Game.jobs:
		var left := int(j.deadline - Game.minute)
		var s := "#%d %s  %s  mats %s" % [j.num, Game.last_name(j), ("%d min" % left) if left > 0 else "LATE!", Game.mats_have_count(j)]
		draw_rect(Rect2(384, y - 11, 254, 14), Color(0, 0, 0, 0.6))
		Art.text(self, Vector2(388, y), s, Pal.LRED if left < 15 else Pal.WHITE, 11)
		y += 15

func _draw_toasts() -> void:
	var y := 340.0
	for ts in toasts:
		var w := Game.font.get_string_size(ts[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_rect(Rect2(320 - w / 2 - 6, y - 12, w + 12, 16), Color(0, 0, 0, 0.75))
		Art.text(self, Vector2(0, y), ts[0], Pal.YELLOW, 12, HORIZONTAL_ALIGNMENT_CENTER, 640)
		y += 17
		if y > 395:
			break

const MM := Rect2(466, 246, 170, 124)

## The whole game is frozen while the planner is open.
func paused() -> bool:
	return planner

## store id -> Array of "2 x Drywall Sheet" lines the current jobs still need from it.
func needed_stores() -> Dictionary:
	var out := {}
	for j in Game.jobs:
		var miss := Game.missing(j)
		for item in miss:
			for st in Data.STORES:
				if Data.STORES[st].stock.has(item):
					if not out.has(st):
						out[st] = []
					var line := "%d x %s  $%d" % [miss[item], Data.ITEMS[item][0], Game.price(st, item)]
					if Game.sales.has("%s:%s" % [st, item]):
						line += " SALE"
					out[st].append(line)
	return out

func _mm(p: Vector2, r: Rect2 = MM) -> Vector2:
	return r.position + Vector2(p.x / Town.W * r.size.x, p.y / Town.H * r.size.y)

## Streets, places, the job and the van drawn into rectangle r. big = labels and names.
func _draw_map(r: Rect2, big: bool) -> void:
	Art.rrect(self, r.grow(3), Pal.WHITE, 8)
	draw_rect(r, Color("dcefc8"))
	var need := needed_stores()
	var rw := 7.0 if big else 3.5
	for i in Town.ROADS_Y.size():
		var ry: float = Town.ROADS_Y[i]
		draw_line(_mm(Vector2(Town.ROADS_X[0], ry), r), _mm(Vector2(Town.ROADS_X[-1], ry), r), Pal.DGRAY, rw)
	for i in Town.ROADS_X.size():
		var rx: float = Town.ROADS_X[i]
		draw_line(_mm(Vector2(rx, Town.ROADS_Y[0]), r), _mm(Vector2(rx, Town.ROADS_Y[-1]), r), Pal.DGRAY, rw)
	if big:
		for i in Town.ROADS_Y.size():
			var a := _mm(Vector2(Town.ROADS_X[0] + 330, Town.ROADS_Y[i]), r)
			Art.text_shadow(self, a + Vector2(0, -6), Town.STREETS_Y[i], Pal.WHITE, 10)
		for i in Town.ROADS_X.size():
			var a := _mm(Vector2(Town.ROADS_X[i], Town.ROADS_Y[0] + 420), r)
			draw_set_transform(a + Vector2(-6, 0), -PI / 2, Vector2.ONE)
			Art.text_shadow(self, Vector2.ZERO, Town.STREETS_X[i], Pal.WHITE, 10)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var blink := int(t * 3) % 2 == 0
	for p in Town.places():
		var c := _mm((p.rect as Rect2).get_center(), r)
		if p.kind == "house":
			if big:
				draw_rect(Rect2(c - Vector2(4, 3), Vector2(8, 6)), Pal.LGRAY)
			continue
		if p.kind == "park":
			continue
		var wanted := need.has(p.kind)
		var col := Pal.RED if p.kind == "shop" else (Pal.YELLOW if wanted and blink else Pal.BLUE)
		var sz := Vector2(56, 14) if big else Vector2(12, 10)
		Art.rrect(self, Rect2(c - sz / 2, sz), col, 3)
		var tc := Pal.BLACK if col == Pal.YELLOW else Pal.WHITE
		if big:
			var short: String = p.name.replace("THE ", "").substr(0, 11)
			Art.text(self, c + Vector2(-27, 4), short, tc, 8)
		else:
			Art.text(self, c + Vector2(-3, 4), _abbr(p.kind), tc, 8)
	for j in Game.jobs:
		var c := _mm((Town.place(j.house).rect as Rect2).get_center(), r)
		Art.circ(self, c, 7.0 if big else 5.0, Pal.LRED if blink else Pal.YELLOW)
		Art.text(self, c + Vector2(-3, 4), str(j.num), Pal.BLACK, 9)
	# the van, as an arrow pointing the way it faces
	var v := _mm(main.drive.van_pos, r)
	var dir := Vector2.from_angle(main.drive.van_angle)
	var k := 7.0 if big else 5.0
	var tri := PackedVector2Array([v + dir * k, v + dir.orthogonal() * k * 0.6 - dir * k * 0.6, v - dir.orthogonal() * k * 0.6 - dir * k * 0.6])
	draw_colored_polygon(tri, Pal.WHITE)
	Art.outline(self, tri)

func _draw_minimap() -> void:
	_draw_map(MM, false)
	if not needed_stores().is_empty():
		Art.text_shadow(self, MM.position + Vector2(4, -6), "flashing = sells what you need (Enter)", Pal.YELLOW, 9)

func _abbr(kind: String) -> String:
	return {"shop": "J", "gas": "G", "hardware": "H", "bank": "$", "police": "P", "tavern": "T",
		"plumbing": "W", "electric": "E", "lumber": "L", "farm": "F"}.get(kind, "?")

func _draw_arrows() -> void:
	var center: Vector2 = main.drive.cam.get_screen_center_position()
	for j in Game.jobs:
		var target := (Town.place(j.house).lot as Rect2).get_center()
		var d := target - center
		var half: Vector2 = Vector2(300, 180) / main.drive.cam.zoom
		if absf(d.x) < half.x and absf(d.y) < half.y:
			continue
		var dir := d.normalized()
		var p := Vector2(320, 200) + dir * Vector2(290, 160)
		var tip := p + dir * 10
		draw_colored_polygon(PackedVector2Array([tip, p + dir.orthogonal() * 7, p - dir.orthogonal() * 7]), Pal.YELLOW)
		Art.text_shadow(self, p - dir * 12 + Vector2(-4, 4), str(j.num), Pal.YELLOW, 12)



## The planner (Enter): town map on the left, the job and where to buy each part on
## the right, today's sales underneath. The whole game is frozen while it is open.
func _draw_planner() -> void:
	Art.box(self, Rect2(6, 18, 628, 378), Pal.WHITE, Pal.BLUE)
	Art.text(self, Vector2(18, 38), "MAP & JOBS - %s %s   (Enter closes, game paused)" % [Game.day_name(), Game.clock_text()], Pal.BLUE, 12)
	var mr := Rect2(18, 48, 300, 238)
	_draw_map(mr, true)
	# today's sales under the map
	var y := mr.end.y + 18
	Art.text(self, Vector2(18, y), "TODAY'S SALES", Pal.RED, 11)
	y += 13
	for k in Game.sales:
		var parts: PackedStringArray = k.split(":")
		Art.text(self, Vector2(24, y), "%s: %s %d%% off" % [Data.STORES[parts[0]].name, Data.ITEMS[parts[1]][0], int(Game.sales[k] * 100)], Pal.BLACK, 10)
		y += 12
	# the job and its parts
	var x := 334.0
	y = 56.0
	if Game.jobs.is_empty():
		Art.text(self, Vector2(x, y), "No job right now.", Pal.BLACK, 12)
		Art.text(self, Vector2(x, y + 15), "The phone will ring. It always rings.", Pal.DGRAY, 11)
		return
	for j in Game.jobs:
		var left := int(j.deadline - Game.minute)
		Art.text(self, Vector2(x, y), "#%d %s" % [j.num, j.tpl.customer], Pal.RED, 12)
		y += 14
		Art.text(self, Vector2(x, y), "%s - pays $%d - %s" % [Game.address(j), j.tpl.pay,
			("due in %d min" % left) if left > 0 else "LATE, half pay"], Pal.BLACK, 10)
		y += 15
		for item in j.tpl.mats:
			var need: int = j.tpl.mats[item]
			var ok := Game.have(item) >= need
			Art.text(self, Vector2(x + 4, y), "%s %d x %s  (have %d)" % ["[x]" if ok else "[ ]", need, Data.ITEMS[item][0], Game.have(item)],
				Pal.GREEN if ok else Pal.BLACK, 11)
			y += 13
		y += 8
	var need_st := needed_stores()
	Art.text(self, Vector2(x, y), "WHERE TO BUY" if not need_st.is_empty() else "You've got everything - go fix it!", Pal.BLUE if not need_st.is_empty() else Pal.GREEN, 11)
	y += 14
	for st in need_st:
		Art.text(self, Vector2(x, y), Data.STORES[st].name, Pal.BLUE, 10)
		y += 12
		for line in need_st[st]:
			Art.text(self, Vector2(x + 8, y), line, Pal.RED if line.ends_with("SALE") else Pal.BLACK, 10)
			y += 11
		y += 3
		if y > 380:
			break
