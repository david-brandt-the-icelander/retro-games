extends Control
## The equipment page (UI-DESIGN `02 EQUIP`, RULES deliberate difference 12): the items this
## system's tech level offers, with prices and a one-line effect, and the fitted equipment beside
## them. ↑↓ pick and `Enter` buys; a laser first asks which mount (←→ or 1–4, `Enter` to fit,
## `Esc` to go back). The sim checks the cash, the limits and the refunds; a refusal shows its
## notice and the page stays open.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const ROW := 46.0

var hub: Control
var galaxy_mode := false
var selected := 0
## The mount picker: -1 closed, else the mount 0..3 on offer.
var picking := -1
var _result := ""
var _result_colour := Look.TEXT


func opened() -> void:
	_result = ""
	picking = -1


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey) or hub.sim.mode() != "docked":
		return false
	var key := event as InputEventKey
	var rows: Array = hub.sim.equipment_rows()
	if rows.is_empty():
		return false
	selected = clampi(selected, 0, rows.size() - 1)
	var row: Dictionary = rows[selected]
	if picking >= 0:
		match key.keycode:
			KEY_LEFT:
				picking = (picking + 3) % 4
			KEY_RIGHT:
				picking = (picking + 1) % 4
			KEY_1, KEY_2, KEY_3, KEY_4:
				picking = key.keycode - KEY_1
			KEY_ENTER, KEY_KP_ENTER:
				hub.sim.equip(row["item"], picking)
				picking = -1
			KEY_ESCAPE:
				picking = -1
			_:
				return false
		return true
	match key.keycode:
		KEY_UP:
			selected = (selected + rows.size() - 1) % rows.size()
		KEY_DOWN:
			selected = (selected + 1) % rows.size()
		KEY_ENTER, KEY_KP_ENTER:
			if row["laser"]:
				picking = 0
			else:
				hub.sim.equip(row["item"], -1)
		_:
			return false
	return true


func on_sim_event(kind: String, data: Dictionary) -> void:
	if kind != "equipped":
		return
	if data["ok"]:
		_result = "%s · %s" % [Words.EQUIP_BOUGHT % data["name"], Words.CASH_LEFT % Words.cash(hub.sim.pilot()["cash"])]
		_result_colour = Look.GOOD
	else:
		var refused: String = data["refused"]
		var rows: Array = hub.sim.equipment_rows()
		var name: String = rows[selected]["name"] if selected < rows.size() else ""
		if refused == "at_limit" and rows[selected]["item"] == 1:
			_result = Words.MISSILES_FULL
		elif refused == "at_limit":
			_result = Words.EQUIP_REFUSED["at_limit"] % name
		else:
			_result = Words.EQUIP_REFUSED.get(refused, "Refused")
		_result_colour = Look.DANGER


func _draw() -> void:
	var rows: Array = hub.sim.equipment_rows()
	var pilot: Dictionary = hub.sim.pilot()
	var here: Dictionary = hub.sim.navigation()["here"]
	var w := size.x
	var list_w := w * 0.64
	Look.text(self, Vector2(0, 0), "Fitting bay", 24, Look.TEXT)
	Look.text_right(self, list_w, 6, "Tech level %d" % here["tech_level"], 14, Look.DIM)
	var y := 44.0
	for i in rows.size():
		var row: Dictionary = rows[i]
		if i == selected:
			draw_rect(Rect2(Vector2(0, y - 3), Vector2(list_w, ROW - 4)), Color(Look.GOLD_DEEP, 0.3))
			draw_rect(Rect2(Vector2(0, y - 3), Vector2(2, ROW - 4)), Look.GOLD)
		var price: int = row["price"]
		var affordable: bool = price <= int(pilot["cash"])
		Look.text(self, Vector2(16, y), row["name"], 18, Look.TEXT if affordable else Look.DIM)
		Look.text(self, Vector2(16, y + 22), Words.EQUIP_EFFECTS[row["item"]], 12, Look.DIM)
		Look.text_right(self, list_w - 12, y, Words.cash(price), 18, Look.TEXT if affordable else Look.DIM)
		var fitted: String = row["fitted"]
		if fitted != "":
			Look.text_right(self, list_w - 12, y + 22, fitted, 12, Look.GOLD)
		y += ROW
	# Fitted equipment, as the status screen lists it.
	var x := list_w + 32
	Look.text(self, Vector2(x, 44), "FITTED", 13, Look.GOLD, true)
	var fy := 72.0
	for line in pilot["equipment"]:
		Look.text(self, Vector2(x, fy), line, 15, Look.TEXT)
		fy += 24
	Look.text(self, Vector2(x, fy + 8), "Darts: %d of 4" % pilot["missiles"], 15, Look.TEXT)
	if pilot["fitted"]["escape_pod"]:
		Look.text(self, Vector2(x, fy + 32), "Lifeboat", 15, Look.TEXT)
	var keys_y := maxf(y + 12, 44 + ROW * 12 + 8)
	var kx := 16.0
	kx += Look.key_chip(self, Vector2(kx, keys_y), "Enter") + 8
	Look.text(self, Vector2(kx, keys_y + 2), "Buy", 15, Look.TEXT)
	if _result != "":
		Look.text(self, Vector2(16, keys_y + 34), _result, 16, _result_colour, true)
	if picking >= 0:
		_draw_mount_picker(rows[selected], pilot)


## The mount question (RULES D.6.11 N21) as a small picker over the ship's outline.
func _draw_mount_picker(row: Dictionary, pilot: Dictionary) -> void:
	var rect := Rect2(Vector2(size.x / 2.0 - 260, 140), Vector2(520, 300))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
	Look.panel(self, rect, Look.GOLD)
	Look.text(self, rect.position + Vector2(24, 20), "%s · %s" % [row["name"], Words.PROMPT_MOUNT], 18, Look.TEXT)
	var centre := rect.position + Vector2(rect.size.x / 2.0, 170)
	draw_colored_polygon(PackedVector2Array([centre + Vector2(0, -50), centre + Vector2(30, 40), centre + Vector2(-30, 40)]), Look.RULE)
	var spots := [Vector2(0, -90), Vector2(0, 80), Vector2(-150, 0), Vector2(150, 0)]
	var names: PackedStringArray = hub.sim.mount_names()
	var lasers: PackedInt32Array = pilot["lasers"]
	for m in 4:
		var at: Vector2 = centre + spots[m]
		var colour := Look.GOLD if m == picking else Look.DIM
		var kind := ""
		if lasers[m] != 0:
			kind = " (lance)" if lasers[m] & 0x80 else " (repeater)"
		Look.text_centre(self, at.x, at.y - 10, "%d %s%s" % [m + 1, names[m], kind], 16, colour)
	Look.text_centre(self, centre.x, rect.end.y - 34, "←→ or 1–4 · Enter fits · Esc back", 13, Look.DIM, true)
