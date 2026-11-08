extends Control
## The pilot page (UI-DESIGN `06 PILOT`, RULES D.6.2): the pilot's name, the current and the
## selected system, condition, fuel and cash, legal standing, rank and kills, and the equipment
## in RULES' order. Docked, `S` saves the pilot under a name (RULES A.8.2, D.6.12): letters and
## digits, up to seven, `Enter` to save, `Esc` to cancel; an empty name saves nothing.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")

var hub: Control
var galaxy_mode := false
var _entry: LineEdit
var _result := ""


func _ready() -> void:
	_entry = LineEdit.new()
	_entry.max_length = 7
	_entry.placeholder_text = Words.PROMPT_NAME
	_entry.visible = false
	_entry.add_theme_font_override("font", Look.mono())
	_entry.add_theme_font_size_override("font_size", 20)
	_entry.text_changed.connect(_on_text_changed)
	_entry.text_submitted.connect(_on_submitted)
	# `Esc` ends the line edit's editing itself, without the key reaching the page.
	_entry.focus_exited.connect(_close_entry)
	if _entry.has_signal("editing_toggled"):
		_entry.connect("editing_toggled", func(on: bool) -> void:
			if not on:
				_close_entry())
	add_child(_entry)


func opened() -> void:
	_result = ""
	_entry.visible = false


func editing() -> bool:
	return _entry.visible


func _process(_delta: float) -> void:
	if visible:
		_entry.position = Vector2(size.x - 330, size.y - 110)
		_entry.size = Vector2(200, 40)
		queue_redraw()


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if editing():
		if key.keycode == KEY_ESCAPE:
			_entry.visible = false
			_entry.release_focus()
		return true
	if key.keycode == KEY_S and hub.sim.mode() == "docked":
		start_save()
		return true
	return false


## Opens the name entry, holding the pilot's present name.
func start_save() -> void:
	_entry.text = hub.sim.pilot()["name"]
	_entry.visible = true
	_entry.grab_focus()
	if _entry.has_method("edit"):
		_entry.call("edit")
	_entry.select_all()


## Saves under `name` at once (the script runner uses it too).
func save(name: String) -> String:
	var outcome: String = hub.sim.save_pilot(name)
	_result = Words.SAVE_RESULTS.get(outcome, outcome)
	return outcome


func _close_entry() -> void:
	if _entry.visible:
		_entry.visible = false
		_entry.release_focus()


func _on_text_changed(text: String) -> void:
	var clean := ""
	for c in text.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			clean += c
	if clean != text:
		var caret := _entry.caret_column
		_entry.text = clean
		_entry.caret_column = mini(caret, clean.length())


func _on_submitted(text: String) -> void:
	save(text)
	_entry.visible = false
	_entry.release_focus()


func _draw() -> void:
	var pilot: Dictionary = hub.sim.pilot()
	var nav: Dictionary = hub.sim.navigation()
	var c: Dictionary = hub.sim.cockpit()
	Look.text(self, Vector2(0, 0), "Pilot %s" % pilot["name"], 28, Look.TEXT)
	var rank: int = pilot["rank"]
	var condition: int = c["condition"]
	var here: String = nav["current_name"]
	var rows := [
		["Present system", Words.word_case(here) if here != "" else "—"],
		["Jump target", Words.word_case(nav["selected"]["name"])],
		["Condition", Words.CONDITIONS[condition]],
		["Fuel", "%s LY" % Words.tenths(pilot["fuel"])],
		["Cash", "%s SC" % Words.cash(pilot["cash"])],
		["Legal standing", Words.LEGAL[pilot["legal_index"]]],
		["Rank", Words.RANKS[rank]],
		["Kills", str(pilot["kills"])],
	]
	var y := 56.0
	for row in rows:
		Look.text(self, Vector2(0, y), row[0], 16, Look.DIM)
		var colour: Color = Look.CONDITION[condition] if row[0] == "Condition" else Look.TEXT
		Look.text(self, Vector2(220, y - 2), row[1], 19, colour)
		y += 36
	# Rank chevrons: one per rank above the first.
	for i in rank:
		var at := Vector2(420 + i * 18, 128 + 36 * 4 + 38)
		draw_polyline(PackedVector2Array([at + Vector2(0, 0), at + Vector2(7, -7), at + Vector2(14, 0)]), Look.GOLD, 2.0)
	var x := size.x * 0.58
	Look.text(self, Vector2(x, 56), "EQUIPMENT", 13, Look.GOLD, true)
	var ey := 84.0
	for line in pilot["equipment"]:
		Look.text(self, Vector2(x, ey), line, 17, Look.TEXT)
		ey += 28
	if hub.sim.mode() == "docked":
		var ky := size.y - 104
		if editing():
			Look.text(self, Vector2(size.x - 460, ky + 8), Words.PROMPT_NAME, 16, Look.DIM)
		else:
			var kx := size.x - 330
			kx += Look.key_chip(self, Vector2(kx, ky + 8), "S") + 8
			Look.text(self, Vector2(kx, ky + 10), "Save pilot", 16, Look.TEXT)
		if _result != "":
			Look.text(self, Vector2(size.x - 330, ky + 52), _result, 15, Look.GOOD if _result == Words.SAVE_RESULTS["saved"] else Look.AMBER)
