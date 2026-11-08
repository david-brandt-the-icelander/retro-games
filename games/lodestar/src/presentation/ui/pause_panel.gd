extends Control
## The pause panel (UI-DESIGN § Pause, RULES D.3.12): while the sim is paused, the scene dims and a
## centred panel offers Resume, the auto-centre and damping toggles (the sim's pause-handler
## actions) and Quit to title, which asks first. ↑↓ and `Enter`; `Esc` or `P` resumes.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")

var sim: Node
var selected := 0
var confirming := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	visible = sim != null and sim.paused()
	if not visible:
		confirming = false
	queue_redraw()


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey):
		return false
	var key := event as InputEventKey
	if confirming:
		if key.keycode == KEY_Y:
			sim.press("quit")
		confirming = false
		return true
	match key.keycode:
		KEY_ESCAPE, KEY_P:
			sim.press("resume")
		KEY_UP:
			selected = (selected + 3) % 4
		KEY_DOWN:
			selected = (selected + 1) % 4
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			match selected:
				0:
					sim.press("resume")
				1:
					sim.press("toggle_auto_centre")
				2:
					sim.press("toggle_damping")
				3:
					confirming = true
	return true


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.6))
	var rect := Rect2(size / 2.0 - Vector2(240, 170), Vector2(480, 340))
	Look.panel(self, rect, Look.GOLD)
	Look.text(self, rect.position + Vector2(32, 24), Words.PAUSE_TITLE, 26, Look.GOLD)
	var c: Dictionary = sim.cockpit()
	var states := ["", "ON" if c["auto_centre"] else "OFF", "ON" if c["damping"] else "OFF", ""]
	var y := rect.position.y + 84
	for i in 4:
		var active := i == selected
		if active:
			draw_rect(Rect2(Vector2(rect.position.x + 24, y - 4), Vector2(2, 34)), Look.GOLD)
		Look.text(self, Vector2(rect.position.x + 36, y), Words.PAUSE_ITEMS[i], 22, Look.TEXT if active else Look.DIM)
		Look.text_right(self, rect.end.x - 32, y + 2, states[i], 18, Look.GOLD)
		y += 48
	if confirming:
		var lines := Words.PAUSE_CONFIRM.split(". ")
		Look.text(self, Vector2(rect.position.x + 32, rect.end.y - 52), lines[0] + ".", 13, Look.AMBER)
		Look.text(self, Vector2(rect.position.x + 32, rect.end.y - 32), lines[1] if lines.size() > 1 else "", 13, Look.AMBER)
