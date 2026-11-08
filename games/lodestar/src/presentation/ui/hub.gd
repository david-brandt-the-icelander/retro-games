extends Control
## The panel host (UI-DESIGN § Docked: the station hub, § In-flight panels): one glass panel that
## shows the page for the sim's screen. Docked, it sits on the right with a tab bar
## (`01 MARKET` … `07 HOLD`) and a bar beneath with the station, credits, cargo space and
## Launch; in flight, the same pages open over the space view with the HUD still below.
##
## The sim owns which screen shows: switching a tab presses `show_screen`, and the hub follows
## `sim.screen()`. Keys reach it through `handle_key` from the game scene.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const PAGES := {
	"market": preload("res://src/presentation/ui/market_page.gd"),
	"equipment": preload("res://src/presentation/ui/equip_page.gd"),
	"galaxy": preload("res://src/presentation/ui/chart_page.gd"),
	"local": preload("res://src/presentation/ui/chart_page.gd"),
	"system": preload("res://src/presentation/ui/system_page.gd"),
	"status": preload("res://src/presentation/ui/pilot_page.gd"),
	"inventory": preload("res://src/presentation/ui/hold_page.gd"),
}
## The docked tabs in order, by the sim's screen names.
const TABS := ["market", "equipment", "galaxy", "local", "system", "status", "inventory"]
## Flight screen keys (docs/DESIGN.md § Keyboard controls) and the screen each opens.
const SCREEN_KEYS := {
	"screen_galaxy": "galaxy", "screen_local": "local", "screen_system": "system",
	"screen_market": "market", "screen_status": "status", "screen_inventory": "inventory",
}

var sim: Node
## The chart cursor the charts move, kept here so moving it selects nothing (RULES A.6.3).
var cursor := Vector2i(-1, -1)
var _pages := {}
var _screen := ""
var _docked := false
var _notice := ""
var _notice_time := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for screen in PAGES:
		var page: Control = PAGES[screen].new()
		page.name = screen.capitalize()
		page.set("hub", self)
		page.set("galaxy_mode", screen == "galaxy")
		page.visible = false
		add_child(page)
		_pages[screen] = page


## The page on show, or null.
func current_page() -> Control:
	return _pages.get(_screen)


func show_notice(text: String, seconds: float = 3.0) -> void:
	_notice = text
	_notice_time = seconds


## Puts the presentation's chart cursor into the sim, which selects the nearest system (RULES
## A.5.1). Called before anything that selects: the distance key, hyperspace, the system-data
## and status screens.
func sync_cursor() -> void:
	if cursor.x >= 0:
		var sim_cursor: Vector2i = sim.navigation()["cursor"]
		if sim_cursor != cursor:
			sim.move_cursor(cursor.x, cursor.y)


## Shows a screen through the sim (selecting from the cursor first where the screen selects).
func open(screen: String) -> void:
	if screen in ["system", "status"]:
		sync_cursor()
	sim.show_screen(screen)


func _process(delta: float) -> void:
	if sim == null:
		return
	var mode: String = sim.mode()
	var screen: String = sim.screen()
	_docked = mode == "docked"
	var on_show := (_docked or mode in ["flight", "dying", "escape"]) and screen != "space" and PAGES.has(screen)
	visible = on_show and not sim.paused()
	if not on_show:
		screen = ""
	if screen != _screen:
		if _pages.has(_screen):
			_pages[_screen].visible = false
		_screen = screen
		if _pages.has(_screen):
			var page: Control = _pages[_screen]
			page.visible = true
			if page.has_method("opened"):
				page.call("opened")
	if cursor.x < 0 or mode == "title":
		cursor = sim.navigation()["cursor"]
	_notice_time = maxf(_notice_time - delta, 0.0)
	var rect := panel_rect()
	for page in _pages.values():
		var top := 76.0 if _docked else 64.0
		page.position = rect.position + Vector2(24, top)
		page.size = rect.size - Vector2(48, top + 24)
	queue_redraw()


## Where the panel sits: on the right while docked (x 1008–1888 at 1920 wide), and over the
## middle of the flight view, clear of the HUD's corners, in flight.
func panel_rect() -> Rect2:
	var view := size
	if _docked:
		return Rect2(Vector2(view.x - 32 - 880, 96), Vector2(880, view.y - 96 - 160))
	return Rect2(Vector2(view.x / 2.0 - 560, 120), Vector2(1120, view.y - 120 - 300))


func _draw() -> void:
	if _screen == "":
		return
	var rect := panel_rect()
	Look.panel(self, rect)
	var condition: int = sim.cockpit()["condition"]
	if not _docked and condition == 3:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4)), Look.DANGER)
	if _docked:
		var x := rect.position.x + 24
		for i in TABS.size():
			var label: String = Words.TABS[i]
			var active: bool = TABS[i] == _screen
			Look.text(self, Vector2(x, rect.position.y + 20), "%02d" % (i + 1), 14, Look.GOLD if active else Look.DIM, true)
			Look.text(self, Vector2(x + 26, rect.position.y + 20), label, 15, Look.GOLD if active else Look.DIM)
			var w := 26 + Look.text_width(label, 15) + 22
			if active:
				draw_rect(Rect2(Vector2(x, rect.position.y + 46), Vector2(w - 22, 2)), Look.GOLD)
			x += w
		draw_line(Vector2(rect.position.x, rect.position.y + 56), Vector2(rect.end.x, rect.position.y + 56), Look.RULE, 1.0)
		_draw_bottom_bar(rect)
	else:
		var index := TABS.find(_screen) + 1
		var title: String = Words.TABS[index - 1]
		if _screen == "market":
			title = "PRICES"
		Look.eyebrow(self, rect.position + Vector2(24, 20), index, title)
		Look.text_right(self, rect.end.x - 24, rect.position.y + 22, "[Esc] CLOSE", 14, Look.DIM)
	if _notice_time > 0.0:
		Look.text_right(self, rect.end.x - 24, rect.end.y - 40, _notice, 18, Look.AMBER, true)


func _draw_bottom_bar(panel: Rect2) -> void:
	var bar := Rect2(Vector2(panel.position.x, panel.end.y + 16), Vector2(panel.size.x, 64))
	Look.panel(self, bar)
	var nav: Dictionary = sim.navigation()
	var pilot: Dictionary = sim.pilot()
	var here := Words.word_case(nav["current_name"])
	Look.text(self, bar.position + Vector2(20, 10), here + " Spindle", 20, Look.TEXT)
	Look.text(self, bar.position + Vector2(20, 36), String(pilot["reach"]) + " · berthed", 14, Look.DIM)
	var used: int = pilot["hold_used"]
	var hold: int = pilot["hold"]
	var money := "%s SC" % Words.cash(pilot["cash"])
	var space_left := "%d t free" % maxi(hold - used, 0)
	var right := bar.end.x - 20
	var launch := "[L] " + Words.LAUNCH
	var lw := Look.text_width(launch, 16, true) + 28
	var button := Rect2(Vector2(right - lw, bar.position.y + 12), Vector2(lw, 40))
	draw_rect(button, Look.GOLD, false, 1.5)
	Look.text(self, button.position + Vector2(14, 10), launch, 16, Look.GOLD, true)
	right -= lw + 24
	Look.text_right(self, right, bar.position.y + 10, money, 20, Look.TEXT)
	Look.text_right(self, right, bar.position.y + 36, space_left, 14, Look.DIM)


## A key while the hub shows. Returns true when it was used.
func handle_key(event: InputEvent) -> bool:
	if _screen == "":
		return false
	var page: Control = current_page()
	if page != null and page.has_method("handle_key") and page.call("handle_key", event):
		return true
	if _docked:
		return _docked_key(event)
	return false


func _docked_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	var index := TABS.find(_screen)
	if key.keycode >= KEY_1 and key.keycode <= KEY_7:
		open(TABS[key.keycode - KEY_1])
		return true
	if key.keycode == KEY_Q or key.keycode == KEY_TAB and key.shift_pressed:
		open(TABS[(index + TABS.size() - 1) % TABS.size()])
		return true
	if key.keycode == KEY_E or key.keycode == KEY_TAB:
		open(TABS[(index + 1) % TABS.size()])
		return true
	return false


## Shows the result of a trade or purchase the page asked for.
func on_sim_event(kind: String, data: Dictionary) -> void:
	var page: Control = current_page()
	if page != null and page.has_method("on_sim_event"):
		page.call("on_sim_event", kind, data)
