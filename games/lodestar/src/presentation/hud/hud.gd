extends Control
## The flight HUD (UI-DESIGN § Flight HUD, RULES D.7 and D.8), drawn plainly: four quiet corners,
## two thin side instruments, the ticker at the top and the reticle on the active mount's axis.
## It reads the sim's snapshots and the space scene's interpolated objects every frame and
## writes nothing.
##
## Top left: the current system, the target and its distance, the safe-zone badge and the jump
## countdown. Top centre: the timed message. Top right: the camera hint. Left edge: the speed
## tape. Right edge: the roll and pitch indicators. Bottom left: the scanner with the heading
## pip, then the weapons row. Bottom right: shields, energy banks, heat, altitude and fuel. A
## thin frame in the condition's colour runs round the screen.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const MOUNT_AXES := [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
## The scanner's range: a cube 16384 sim units on each side of the player (RULES D.8).
const SCANNER_RANGE := 16384.0 * 0.2
const SCANNER_SIZE := Vector2(320, 230)
const STATUS_SIZE := Vector2(380, 230)

var sim: Node
var space: Node
## A persistent notice (RULES D.9.2 N1–N4 and the hop's refusal) and how long it has left.
var notice := ""
var notice_time := 0.0
## Launches this session, for the key hints shown on the first three.
var launches := 0
var _tick := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_notice(text: String, seconds: float = 4.0) -> void:
	notice = text
	notice_time = seconds


func _process(delta: float) -> void:
	if sim == null:
		return
	if not sim.paused():
		notice_time = maxf(notice_time - delta, 0.0)
	_tick = sim.tick_count()
	queue_redraw()


func _draw() -> void:
	if sim == null:
		return
	var mode: String = sim.mode()
	var flying := mode in ["flight", "dying", "escape"]
	if not (flying or mode.begins_with("tunnel")):
		return
	var c: Dictionary = sim.cockpit()
	var pilot: Dictionary = sim.pilot()
	var view := size
	var condition: int = c["condition"]
	draw_rect(Rect2(Vector2(2, 2), view - Vector2(4, 4)), Color(Look.CONDITION[condition], 0.3), false, 1.0)
	_draw_location(c)
	_draw_status(c, pilot, Vector2(view.x - 32 - STATUS_SIZE.x, view.y - 32 - STATUS_SIZE.y))
	if mode.begins_with("tunnel"):
		return
	_draw_ticker(c, view)
	_draw_camera_hint(view)
	_draw_speed(c, view)
	_draw_rates(c, view)
	var scanner_at := Vector2(32, view.y - 32 - SCANNER_SIZE.y)
	_draw_scanner(c, scanner_at)
	_draw_weapons(c, pilot, Vector2(scanner_at.x + SCANNER_SIZE.x + 24, view.y - 76))
	if mode == "flight" and sim.screen() == "space":
		_draw_reticle(c, pilot)
		if launches <= 3:
			Look.text_centre(self, view.x / 2.0, view.y - 50, Words.KEY_HINTS, 14, Look.DIM, true)
	if notice_time > 0.0 and notice != "":
		Look.text_centre(self, view.x / 2.0, view.y - 96, notice, 20, Look.TEXT, true)
	if mode == "dying":
		Look.panel(self, Rect2(Vector2(view.x / 2.0 - 300, view.y / 2.0 - 176), Vector2(600, 136)))
		Look.text_centre(self, view.x / 2.0, view.y / 2.0 - 160, Words.NOTE_DEATH, 40, Look.DANGER, true)
		var epitaph: String = Words.EPITAPHS.get(String(sim.death_cause()), "")
		Look.text_centre(self, view.x / 2.0, view.y / 2.0 - 104, epitaph, 20, Look.TEXT)
		var record := "%s · %d kills" % [Words.RANKS[pilot["rank"]], pilot["kills"]]
		Look.text_centre(self, view.x / 2.0, view.y / 2.0 - 74, record, 16, Look.DIM)


func _draw_location(c: Dictionary) -> void:
	var nav: Dictionary = sim.navigation()
	var here: String = nav["current_name"]
	var name := Words.word_case(here) if here != "" else "—"
	Look.text(self, Vector2(32, 28), name, 22, Look.TEXT)
	if c["station_present"]:
		var x := 32 + Look.text_width(name, 22) + 14
		draw_rect(Rect2(Vector2(x, 30), Vector2(104, 24)), Look.GOLD)
		Look.text(self, Vector2(x + 8, 32), "SAFE ZONE", 15, Look.VOID, true)
	var selected: Dictionary = nav["selected"]
	var line := "→ %s  %s LY" % [Words.word_case(selected["name"]), Words.tenths(selected["distance"])]
	Look.text(self, Vector2(32, 60), line, 16, Look.DIM, true)
	var countdown: int = c["countdown"]
	if countdown > 0:
		Look.text(self, Vector2(32, 92), "%5d" % countdown, 34, Look.AMBER, true)
		var where: String = c["countdown_target"]
		var label := "REACH JUMP" if c["countdown_galactic"] else "JUMP " + where
		Look.text(self, Vector2(160, 104), label, 15, Look.AMBER, true)


func _draw_ticker(c: Dictionary, view: Vector2) -> void:
	var id: String = c["message"]
	var timer: int = c["message_timer"]
	if id == "" or timer <= 0:
		return
	var text := Words.message(id, c["message_detail"])
	var urgent := id in Words.URGENT
	var w := maxf(Look.text_width(text, 22, true) + 48, 260)
	var rect := Rect2(Vector2(view.x / 2.0 - w / 2.0, 40), Vector2(w, 36))
	var fade := clampf(float(timer) / 4.0, 0.0, 1.0)
	draw_rect(rect, Color(Look.GLASS, 0.85 * fade))
	draw_rect(rect, Color(Look.DANGER if urgent else Look.RULE, fade), false, 1.0)
	Look.text_centre(self, view.x / 2.0, 45, text, 22, Color(Look.DANGER if urgent else Look.TEXT, fade), true)


func _draw_camera_hint(view: Vector2) -> void:
	var cam = space.camera
	if cam.idle > 3.0:
		return
	var text := "%s · %.1f×" % ["FOLLOW" if cam.follow else "ORBIT", cam.zoom]
	Look.text_right(self, view.x - 32, 32, text, 15, Look.DIM)


func _draw_speed(c: Dictionary, view: Vector2) -> void:
	var speed: int = c["speed"]
	var top := view.y * 420.0 / 1080.0
	var bottom := view.y * 660.0 / 1080.0
	var x := 72.0
	Look.text(self, Vector2(x - 12, top - 34), "%d" % speed, 22, Look.TEXT, true)
	var danger := speed >= 28
	for i in 24:
		var y := bottom - (bottom - top) * float(i) / 23.0
		var lit := float(i) < float(speed) / 40.0 * 24.0
		var colour := Look.RULE
		if lit:
			colour = Look.AMBER if danger else Look.TEXT
		draw_line(Vector2(x, y), Vector2(x + (14 if i % 4 == 0 else 8), y), colour, 2.0)
	Look.text(self, Vector2(x - 12, bottom + 8), "SPD", 13, Look.DIM, true)


func _draw_rates(c: Dictionary, view: Vector2) -> void:
	var x := view.x - 112.0
	_rate(Vector2(x, view.y * 470.0 / 1080.0), "ROLL", clampf(c["roll_angle"] / 0.125, -1.0, 1.0))
	_rate(Vector2(x, view.y * 590.0 / 1080.0), "PITCH", clampf(c["pitch_angle"] / 0.0315, -1.0, 1.0))


func _rate(at: Vector2, label: String, value: float) -> void:
	draw_arc(at, 42, deg_to_rad(-135), deg_to_rad(-45), 24, Look.RULE, 3.0)
	draw_line(at + Vector2(0, -38), at + Vector2(0, -48), Look.DIM, 1.0)
	var angle := deg_to_rad(-90.0 + 45.0 * value)
	draw_line(at + Vector2(cos(angle), sin(angle)) * 36, at + Vector2(cos(angle), sin(angle)) * 50, Look.GOLD, 3.0)
	Look.text_centre(self, at.x, at.y - 30, label, 13, Look.DIM, true)


func _draw_scanner(c: Dictionary, at: Vector2) -> void:
	var rect := Rect2(at, SCANNER_SIZE)
	Look.panel(self, rect)
	var centre := at + Vector2(SCANNER_SIZE.x / 2.0, SCANNER_SIZE.y / 2.0 + 8)
	var rx := SCANNER_SIZE.x / 2.0 - 24
	var ry := rx * 0.42
	var rim: Color = Look.CONDITION[c["condition"]]
	_ellipse(centre, rx, ry, Color(rim, 0.9), 1.5)
	_ellipse(centre, rx * 0.5, ry * 0.5, Look.RULE, 1.0)
	draw_line(centre - Vector2(rx, 0), centre + Vector2(rx, 0), Look.RULE, 1.0)
	draw_line(centre - Vector2(0, ry), centre + Vector2(0, ry), Look.RULE, 1.0)
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -5), centre + Vector2(4, 4), centre + Vector2(-4, 4)]), Look.GOLD)
	var heading_target := {}
	for o in space.drawn_objects():
		var kind: int = o["kind"]
		var p: Vector3 = o["position"]
		if kind == 8 or (kind in [128, 130] and heading_target.is_empty()):
			heading_target = o
		if kind >= 128 or o["killed"] or o["exploding"]:
			continue
		if absf(p.x) >= SCANNER_RANGE or absf(p.y) >= SCANNER_RANGE or absf(p.z) >= SCANNER_RANGE:
			continue
		var base := centre + Vector2(p.x / SCANNER_RANGE * rx, p.z / SCANNER_RANGE * ry)
		var blip := base - Vector2(0, p.y / SCANNER_RANGE * ry * 1.4)
		var colour := Look.TEXT
		if kind == 9:
			colour = Look.DANGER if o["hostile_missile"] else Look.GOOD
		elif kind == 8:
			colour = Look.GOLD
		colour.a = 0.55 if p.z > 0.0 else 1.0
		draw_colored_polygon(PackedVector2Array([blip + Vector2(0, -4), blip + Vector2(4, 0), blip + Vector2(0, 4), blip + Vector2(-4, 0)]), colour)
		if absf(p.y) > SCANNER_RANGE * 0.04:
			var up := p.y > 0.0
			var tip := blip + Vector2(8, -3 if up else 3)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -3 if up else 3), tip + Vector2(3, 0), tip + Vector2(-3, 0)]), colour)
	if not heading_target.is_empty() and not c["misjump"]:
		var d: Vector3 = (heading_target["position"] as Vector3).normalized()
		var pip := centre + Vector2(d.x * rx, -d.y * ry)
		if d.z <= 0.0:
			draw_circle(pip, 5.0, Look.AMBER)
		else:
			draw_arc(pip, 4.0, 0, TAU, 12, Look.TEXT, 1.5)
	var label := "SPINDLE" if heading_target.get("kind", 0) == 8 else "PLANET"
	Look.text(self, at + Vector2(12, 8), "SCAN", 13, Look.GOLD, true)
	if not heading_target.is_empty() and not c["misjump"]:
		Look.text_right(self, rect.end.x - 12, at.y + 8, "◆ " + label, 13, Look.DIM)


func _ellipse(centre: Vector2, rx: float, ry: float, colour: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 49:
		var a := TAU * float(i) / 48.0
		points.append(centre + Vector2(cos(a) * rx, sin(a) * ry))
	draw_polyline(points, colour, width)


func _draw_weapons(c: Dictionary, pilot: Dictionary, at: Vector2) -> void:
	var missiles: int = pilot["missiles"]
	var x := at.x
	for i in 4:
		var centre := Vector2(x + 10, at.y + 12)
		if i < missiles:
			var colour := Look.TEXT
			if i == 0 and c["missile_target"] >= 0:
				colour = Look.DANGER
			elif i == 0 and c["missile_armed"]:
				colour = Look.AMBER
			draw_circle(centre, 8.0, colour)
		else:
			draw_arc(centre, 8.0, 0, TAU, 16, Look.RULE, 1.5)
		x += 24
	x += 16
	var fitted: Dictionary = pilot["fitted"]
	x = _badge(Vector2(x, at.y), "SCR", fitted["ecm"], c["ecm_timer"] > 0)
	x = _badge(Vector2(x, at.y), "NOVA", fitted["area_blast"], c["area_blast"] > 0)
	_badge(Vector2(x, at.y), "BOAT", fitted["escape_pod"], false)


func _badge(at: Vector2, label: String, fitted: bool, active: bool) -> float:
	var w := Look.text_width(label, 14, true) + 16
	var rect := Rect2(at, Vector2(w, 24))
	if active:
		draw_rect(rect, Look.AMBER)
		Look.text(self, at + Vector2(8, 3), label, 14, Look.VOID, true)
	elif fitted:
		draw_rect(rect, Look.GOLD)
		Look.text(self, at + Vector2(8, 3), label, 14, Look.VOID, true)
	else:
		draw_rect(rect, Look.RULE, false, 1.0)
		Look.text(self, at + Vector2(8, 3), label, 14, Look.DIM, true)
	return at.x + w + 8


func _draw_status(c: Dictionary, pilot: Dictionary, at: Vector2) -> void:
	var rect := Rect2(at, STATUS_SIZE)
	Look.panel(self, rect)
	var flash := Look.flash_on(_tick)
	# Shields: two halves of a ring, fore on top, around a small ship mark.
	var centre := at + Vector2(64, 76)
	var fore: int = c["fore_shield"]
	var aft: int = c["aft_shield"]
	draw_arc(centre, 44, deg_to_rad(200), deg_to_rad(340), 24, Look.RULE, 6.0)
	draw_arc(centre, 44, deg_to_rad(20), deg_to_rad(160), 24, Look.RULE, 6.0)
	draw_arc(centre, 44, deg_to_rad(270 - 70 * fore / 255.0), deg_to_rad(270 + 70 * fore / 255.0), 24, _danger_colour(fore < 48, flash, Color("#9fe3ff")), 6.0)
	draw_arc(centre, 44, deg_to_rad(90 - 70 * aft / 255.0), deg_to_rad(90 + 70 * aft / 255.0), 24, _danger_colour(aft < 48, flash, Color("#9fe3ff")), 6.0)
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -16), centre + Vector2(10, 12), centre + Vector2(-10, 12)]), Look.GOLD)
	Look.text_centre(self, centre.x, at.y + 10, "FORE", 12, Look.DIM, true)
	Look.text_centre(self, centre.x, at.y + 128, "AFT", 12, Look.DIM, true)
	# Four energy banks: the bottom one fills first (RULES D.7).
	var e: int = c["energy"] >> 2
	for bank in 4:
		var share := clampi(e - 16 * bank, 0, 16)
		var cell := Rect2(at + Vector2(16 + 30 * bank, 160), Vector2(24, 52))
		draw_rect(cell, Look.RULE, false, 1.0)
		var h := 50.0 * minf(15.0, share) / 15.0
		var low := share < 3 and share > 0
		draw_rect(Rect2(cell.position + Vector2(1, 51 - h), Vector2(22, h)), _danger_colour(low, flash, Look.TEXT))
	Look.text(self, at + Vector2(16, 214), "ENERGY %d" % c["energy"], 12, Look.DIM, true)
	# Heat, altitude and fuel.
	var x := at.x + 150
	var w := STATUS_SIZE.x - 168
	var cabin: int = c["cabin_temperature"]
	var laser: int = c["laser_temperature"]
	Look.bar(self, Rect2(Vector2(x, at.y + 12), Vector2(w, 30)), "HULL HEAT", cabin / 255.0, "%d" % cabin, _danger_colour(cabin >= 176, flash, Look.TEXT))
	Look.bar(self, Rect2(Vector2(x, at.y + 60), Vector2(w, 30)), "LASER HEAT", laser / 255.0, "%d" % laser, _danger_colour(laser >= 176, flash, Look.TEXT))
	var altitude: int = c["altitude"]
	Look.bar(self, Rect2(Vector2(x, at.y + 108), Vector2(w, 30)), "ALTITUDE", altitude / 255.0, "%d" % altitude, Look.TEXT)
	var fuel: int = pilot["fuel"]
	Look.text(self, Vector2(x, at.y + 160), "FUEL", 14, Look.DIM)
	Look.text_right(self, x + w, at.y + 154, Words.tenths(fuel) + " LY", 24, _danger_colour(fuel < 12, flash, Look.TEXT))
	var condition: int = c["condition"]
	Look.text(self, Vector2(x, at.y + 196), Words.CONDITIONS[condition].to_upper(), 14, Look.CONDITION[condition], true)


func _danger_colour(danger: bool, flash: bool, normal: Color) -> Color:
	return Look.DANGER if danger and flash else normal


func _draw_reticle(c: Dictionary, pilot: Dictionary) -> void:
	var mount: int = c["active_mount"]
	var lasers: PackedInt32Array = pilot["lasers"]
	var camera: Camera3D = space.camera
	var aim: Vector3 = MOUNT_AXES[mount] * 800.0
	var in_line := {}
	for o in space.drawn_objects():
		if o["in_sights"] and o["kind"] < 128:
			in_line = o
			aim = o["position"]
			break
	for o in space.drawn_objects():
		if o["locked"]:
			var p: Vector3 = o["position"]
			if not camera.is_position_behind(p):
				var at := camera.unproject_position(p)
				draw_arc(at, 26, 0, TAU, 32, Look.DANGER, 2.0)
	if camera.is_position_behind(aim):
		return
	var centre := camera.unproject_position(aim)
	var colour := Look.GOLD if lasers[mount] != 0 else Look.DIM
	draw_arc(centre, 14, 0, TAU, 32, colour, 1.5)
	for tick in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_line(centre + tick * 16, centre + tick * 24, colour, 1.5)
	if c["missile_armed"] and c["missile_target"] < 0:
		var turn := float(Time.get_ticks_msec() % 1000) / 1000.0 * TAU
		draw_arc(centre, 30, turn, turn + PI * 1.5, 24, Look.AMBER, 2.0)
	if not in_line.is_empty():
		draw_circle(centre, 5.0, colour)
		for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var p: Vector2 = centre + corner * 34
			draw_line(p, p - Vector2(corner.x * 10, 0), colour, 2.0)
			draw_line(p, p - Vector2(0, corner.y * 10), colour, 2.0)
		Look.text_centre(self, centre.x, centre.y - 58, "IN LINE OF FIRE", 13, colour, true)
	Look.text_centre(self, centre.x, centre.y + (40 if not in_line.is_empty() else 30), Words.MOUNT_TAGS[mount], 14, colour, true)
