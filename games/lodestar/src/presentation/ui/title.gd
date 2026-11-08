extends Control
## The title (UI-DESIGN § Title, RULES D.3.1): the game's name, a strapline and a menu on the
## right third, over the ship turning in front of the star. ↑↓ and `Enter`.
##
## - **Continue** starts the last saved or loaded pilot (the start pilot until one is saved).
## - **Load pilot** lists the saved pilots and takes a typed name (letters and digits, up to
##   seven; empty means the last saved pilot), loads it and starts.
## - **About** shows the credit line the GDD requires.
## - **Quit** closes the game.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")

var sim: Node
var selected := 0
## `menu`, `load` or `about`.
var page := "menu"
var _entry: LineEdit
var _names: PackedStringArray = []
var _picked := -1
var _error := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_entry = LineEdit.new()
	_entry.max_length = 7
	_entry.placeholder_text = Words.PROMPT_NAME
	_entry.visible = false
	_entry.add_theme_font_override("font", Look.mono())
	_entry.add_theme_font_size_override("font_size", 22)
	_entry.text_changed.connect(_on_text_changed)
	_entry.text_submitted.connect(func(text: String) -> void: load_and_start(text))
	add_child(_entry)


func _menu() -> Array:
	return [Words.MENU_CONTINUE, Words.MENU_LOAD, Words.MENU_ABOUT, Words.MENU_QUIT]


func _process(_delta: float) -> void:
	visible = sim != null and sim.mode() == "title" and not sim.paused()
	if not visible:
		page = "menu"
		_entry.visible = false
		return
	var x := _column_x()
	_entry.position = Vector2(x, 470)
	_entry.size = Vector2(260, 44)
	queue_redraw()


func _column_x() -> float:
	return size.x - 32 - 620


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	match page:
		"menu":
			match key.keycode:
				KEY_UP:
					selected = (selected + 3) % 4
				KEY_DOWN:
					selected = (selected + 1) % 4
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_choose(selected)
				_:
					return false
		"load":
			match key.keycode:
				KEY_ESCAPE:
					_close_load()
				KEY_UP:
					_picked = maxi(_picked - 1, 0)
					if _names.size() > 0:
						_entry.text = _names[_picked]
				KEY_DOWN:
					_picked = mini(_picked + 1, _names.size() - 1)
					if _names.size() > 0:
						_entry.text = _names[_picked]
				_:
					return _entry.has_focus()
		"about":
			page = "menu"
	return true


func _choose(index: int) -> void:
	match index:
		0:
			sim.press("start")
		1:
			page = "load"
			_error = ""
			_names = sim.pilot_names()
			_picked = -1
			_entry.text = ""
			_entry.visible = true
			_entry.grab_focus()
		2:
			page = "about"
		3:
			get_tree().quit()


## Loads the pilot named `name` (empty: the last saved one) and starts, or says why not.
func load_and_start(name: String) -> String:
	var error: String = sim.load_pilot(name)
	if error == "":
		_close_load()
		sim.press("start")
	else:
		_error = Words.LOAD_ERRORS.get(error, error)
	return error


func _close_load() -> void:
	page = "menu"
	_entry.visible = false
	_entry.release_focus()


func _on_text_changed(text: String) -> void:
	var clean := ""
	for c in text.to_upper():
		if (c >= "A" and c <= "Z") or (c >= "0" and c <= "9"):
			clean += c
	if clean != text:
		_entry.text = clean
		_entry.caret_column = clean.length()


func _draw() -> void:
	var x := _column_x()
	var rect := Rect2(Vector2(x - 40, 180), Vector2(660, size.y - 360))
	draw_rect(rect, Color(Look.GLASS, 0.55))
	Look.text(self, Vector2(x, 230), Words.TITLE, 72, Look.GOLD)
	Look.text(self, Vector2(x, 320), Words.STRAPLINE, 18, Look.DIM)
	var pilot: Dictionary = sim.pilot()
	match page:
		"menu":
			var y := 400.0
			var items := _menu()
			for i in items.size():
				var label: String = items[i]
				if i == 0:
					label += "  ·  " + String(pilot["name"])
				var active := i == selected
				if active:
					draw_rect(Rect2(Vector2(x - 12, y - 4), Vector2(2, 36)), Look.GOLD)
				Look.text(self, Vector2(x, y), label, 26, Look.TEXT if active else Look.DIM)
				y += 52
			Look.text(self, Vector2(x, y + 20), "↑↓  Enter", 14, Look.DIM, true)
		"load":
			Look.text(self, Vector2(x, 410), Words.MENU_LOAD, 26, Look.TEXT)
			var y := 540.0
			if _names.is_empty():
				Look.text(self, Vector2(x, y), Words.LOAD_EMPTY, 16, Look.DIM)
			for i in _names.size():
				Look.text(self, Vector2(x, y), _names[i], 18, Look.GOLD if i == _picked else Look.TEXT, true)
				y += 28
			if _error != "":
				Look.text(self, Vector2(x + 280, 480), _error, 15, Look.DANGER)
			Look.text(self, Vector2(x, size.y - 220), "Type a name or ↑↓ · Enter loads · Esc back", 14, Look.DIM, true)
		"about":
			var y := 410.0
			for line in _wrap(Words.ABOUT, 52) + [""] + _wrap(Words.CREDIT, 52):
				Look.text(self, Vector2(x, y), line, 17, Look.TEXT)
				y += 28
			Look.text(self, Vector2(x, y + 20), "Any key", 14, Look.DIM, true)
	Look.text(self, Vector2(32, size.y - 48), Words.FOOTER, 14, Look.DIM)


func _wrap(text: String, width: int) -> Array:
	var lines := []
	var line := ""
	for word in text.split(" "):
		if line.length() + word.length() + 1 > width and line != "":
			lines.append(line)
			line = word
		else:
			line = word if line == "" else line + " " + word
	if line != "":
		lines.append(line)
	return lines
