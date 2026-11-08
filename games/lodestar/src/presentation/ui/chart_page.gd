extends Control
## The Reach chart and the local chart (UI-DESIGN `03 GALAXY`, `04 LOCAL`; RULES A.6, D.6.6,
## D.6.7). The Reach chart shows all 256 systems at (x, y / 2), the current system's cross and its
## fuel-range circle, the cursor, the selected system and an info card for the system nearest
## the cursor. The local chart shows the neighbourhood at four pixels a unit with RULES A.6.2's
## label layout, which the sim works out.
##
## Arrows move the cursor one unit (`Shift`: eight); held, they repeat six times a second while
## docked (RULES A.6.3). `Enter` selects the system nearest the cursor and shows its distance;
## `Home` brings the cursor back to the pilot; a click puts it where clicked. Moving the cursor
## selects nothing (the hub hands it to the sim before anything that selects).

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const CARD_W := 280.0
const CARD_H := 190.0
## The local chart's grid (RULES A.6.2's screen points) and its centre.
const LOCAL_GRID := Vector2(208, 180)
const LOCAL_ORIGIN := Vector2(0, 0)

var hub: Control
var galaxy_mode := true
var _systems: Array = []
var _systems_galaxy := -1
var _repeat := 0.0


func opened() -> void:
	_repeat = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	if hub.sim.mode() == "docked":
		var dx := int(Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_LEFT))
		var dy := int(Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_UP))
		if dx != 0 or dy != 0:
			_repeat += delta
			if _repeat >= 1.0 / 6.0 + 0.25:
				_repeat = 0.25
				_move(dx, dy)
		else:
			_repeat = 0.0
	queue_redraw()


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	var step := 8 if key.shift_pressed else 1
	match key.keycode:
		KEY_LEFT:
			_move(-step, 0)
		KEY_RIGHT:
			_move(step, 0)
		KEY_UP:
			_move(0, -step)
		KEY_DOWN:
			_move(0, step)
		KEY_ENTER, KEY_KP_ENTER:
			distance()
		KEY_HOME:
			var here: Vector2i = hub.sim.pilot()["position"]
			hub.cursor = here
		_:
			return false
	return true


## The show-distance key (RULES A.6.3, D.9.2 N4): select, then name the system and its distance.
func distance() -> void:
	hub.sim.move_cursor(hub.cursor.x, hub.cursor.y)
	var near: Dictionary = hub.sim.nearest_system(hub.cursor.x, hub.cursor.y)
	var name := Words.word_case(near["name"])
	var d: int = near["distance"]
	hub.show_notice(name if d == 0 else "%s  %s LY" % [name, Words.tenths(d)])
	hub.cursor = near["position"]


## Each axis moves only while it stays within 0..255 (RULES A.6.3).
func _move(dx: int, dy: int) -> void:
	var c: Vector2i = hub.cursor
	if c.x + dx >= 0 and c.x + dx <= 255:
		c.x += dx
	if c.y + dy >= 0 and c.y + dy <= 255:
		c.y += dy
	hub.cursor = c


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = event.position
		if galaxy_mode:
			var s := _galaxy_scale()
			hub.cursor = Vector2i(clampi(int(p.x / s), 0, 255), clampi(int((p.y - 40) / s * 2.0), 0, 255))
		accept_event()


## The Reach chart fills the page's width, with the info card beneath it.
func _galaxy_scale() -> float:
	return minf(size.x / 256.0, (size.y - 90 - CARD_H - 16) / 128.0)


func _draw() -> void:
	if size.x <= CARD_W + 64 or size.y <= 120:
		return
	var pilot: Dictionary = hub.sim.pilot()
	if galaxy_mode:
		_draw_galaxy(pilot)
		var s := _galaxy_scale()
		_draw_card(pilot, Rect2(Vector2(0, 40 + 128 * s + 16), Vector2(size.x, CARD_H)))
	else:
		_draw_local(pilot)
		_draw_card(pilot, Rect2(Vector2(size.x - CARD_W, 40), Vector2(CARD_W, 250)))
	Look.text(self, Vector2(0, size.y - 22), "Arrows move · Shift ×8 · Enter distance · Home back · H jump", 13, Look.DIM, true)


func _draw_galaxy(pilot: Dictionary) -> void:
	var galaxy: int = pilot["galaxy"]
	if galaxy != _systems_galaxy:
		_systems = hub.sim.galaxy_systems()
		_systems_galaxy = galaxy
	Look.text(self, Vector2(0, 0), "%s · Reach %d" % [pilot["reach"], galaxy + 1], 24, Look.TEXT)
	var s := _galaxy_scale()
	var top := 40.0
	var area := Rect2(Vector2(0, top), Vector2(256, 128) * s)
	draw_rect(area, Color(0, 0, 0, 0.35))
	draw_rect(area, Look.RULE, false, 1.0)
	for system in _systems:
		var p: Vector2i = system["position"]
		var at := Vector2(p.x, p.y / 2) * s + Vector2(0, top)
		var economy: int = system["economy"]
		var colour := Color("#9ccf8a") if economy >= 4 else Color("#a9b4c6")
		draw_circle(at, 2.6 if system["dot"] == 2 else 1.6, colour)
	var here: Vector2i = pilot["position"]
	var centre := Vector2(here.x, here.y / 2) * s + Vector2(0, top)
	var fuel: int = pilot["fuel"]
	draw_arc(centre, float(fuel >> 2) * s, 0, TAU, 64, Look.GOOD, 1.5)
	_cross(centre, 7.0 * s, Look.GOLD, 2.0)
	var selected: Vector2i = hub.sim.navigation()["selected"]["position"]
	draw_arc(Vector2(selected.x, selected.y / 2) * s + Vector2(0, top), 9.0, 0, TAU, 24, Look.FOCUS, 1.5)
	var cursor := Vector2(hub.cursor.x, hub.cursor.y / 2) * s + Vector2(0, top)
	_cross(cursor, 4.0 * s, Look.TEXT, 1.5)


func _draw_local(pilot: Dictionary) -> void:
	Look.text(self, Vector2(0, 0), "Local space", 24, Look.TEXT)
	var s := minf((size.x - CARD_W - 24) / LOCAL_GRID.x, (size.y - 80) / LOCAL_GRID.y)
	var origin := Vector2(0, 40) - Vector2(0, 0)
	var area := Rect2(origin, LOCAL_GRID * s)
	draw_rect(area, Color(0, 0, 0, 0.35))
	draw_rect(area, Look.RULE, false, 1.0)
	var centre := origin + Vector2(104, 90) * s
	var fuel: int = pilot["fuel"]
	draw_arc(centre, float(fuel) * s, 0, TAU, 64, Look.GOOD, 1.5)
	_cross(centre, 16.0 * s * 0.5, Look.GOLD, 2.0)
	var selected: int = hub.sim.navigation()["selected"]["index"]
	for entry in hub.sim.local_chart():
		var p: Vector2i = entry["point"]
		var at := origin + Vector2(p) * s
		if not area.has_point(at):
			continue
		draw_circle(at, float(entry["radius"]) * s * 0.6, Look.TEXT if entry["index"] != selected else Look.FOCUS)
		var row: int = entry["label_row"]
		if row >= 0:
			var label_y := origin.y + float(row * 8) * s
			Look.text(self, Vector2(at.x + 10, label_y), Words.word_case(entry["name"]), 15, Look.DIM)
	var c: Vector2i = hub.sim.local_cursor(hub.cursor.x, hub.cursor.y)
	if c.x >= 0:
		_cross(origin + Vector2(c) * s, 8.0 * s * 0.5, Look.TEXT, 1.5)


## The info card: the system nearest the cursor, which the next selection would choose.
func _draw_card(pilot: Dictionary, rect: Rect2) -> void:
	var near: Dictionary = hub.sim.nearest_system(hub.cursor.x, hub.cursor.y)
	Look.panel(self, rect, Look.GOLD)
	var d: int = near["distance"]
	var fuel: int = pilot["fuel"]
	Look.text(self, rect.position + Vector2(16, 14), Words.word_case(near["name"]), 22, Look.TEXT)
	var range_text := "here" if d == 0 else ("%s LY · in range" % Words.tenths(d) if d <= fuel else "%s LY · out of range" % Words.tenths(d))
	Look.text(self, rect.position + Vector2(16, 48), range_text, 15, Look.GOOD if d <= fuel else Look.DANGER, true)
	var wide := rect.size.x > CARD_W * 1.5
	var second := Vector2(rect.size.x / 2.0, 14) if wide else Vector2(16, 82)
	Look.text(self, rect.position + second, near["economy_label"], 15, Look.TEXT)
	Look.text(self, rect.position + second + Vector2(0, 24), near["government_label"], 15, Look.TEXT)
	Look.text(self, rect.position + second + Vector2(0, 48), "Tech level %d" % near["tech_level"], 15, Look.TEXT)
	var third := Vector2(16, 90) if wide else Vector2(16, 166)
	Look.text(self, rect.position + third, "[Enter] select   [H] jump", 13, Look.DIM, true)
	var selected: Dictionary = hub.sim.navigation()["selected"]
	Look.text(self, rect.position + third + Vector2(0, 34), "Selected: " + Words.word_case(selected["name"]), 14, Look.FOCUS)


func _cross(at: Vector2, half: float, colour: Color, width: float) -> void:
	draw_line(at - Vector2(half, 0), at + Vector2(half, 0), colour, width)
	draw_line(at - Vector2(0, half), at + Vector2(0, half), colour, width)
