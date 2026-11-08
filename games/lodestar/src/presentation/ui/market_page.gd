extends Control
## The market page (UI-DESIGN `01 MARKET`, RULES deliberate difference 12): the 17 goods with
## unit, price here, available and in hold, and a trend mark where this economy pays above the
## middle. Docked, the selected row holds a quantity stepper: ↑↓ pick, ←→ change the quantity
## (`Shift` by 10), the keypad's digits type it (the top row switches tabs), `B` buys and `N` sells that many. The stepper stays within
## the sim's limits (availability, hold room and cash for a buy; the cargo held for a sale). In
## flight the page is the read-only price list (RULES D.6.4).

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const ROW := 30.0

var hub: Control
var galaxy_mode := false
var selected := 0
var quantity := 1
var _result := ""
var _result_colour := Look.TEXT


func opened() -> void:
	_result = ""


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _docked() -> bool:
	return hub.sim.mode() == "docked"


func handle_key(event: InputEvent) -> bool:
	if not (event is InputEventKey) or not _docked():
		return false
	var key := event as InputEventKey
	var rows: Array = hub.sim.market_rows()
	var row: Dictionary = rows[selected]
	var step := 10 if key.shift_pressed else 1
	match key.keycode:
		KEY_UP:
			selected = (selected + rows.size() - 1) % rows.size()
			quantity = 1
		KEY_DOWN:
			selected = (selected + 1) % rows.size()
			quantity = 1
		KEY_LEFT:
			quantity = maxi(quantity - step, 0)
		KEY_RIGHT:
			quantity = mini(quantity + step, maxi(int(row["max_buy"]), int(row["max_sell"])))
		KEY_B:
			hub.sim.buy(row["item"], quantity)
		KEY_N:
			hub.sim.sell(row["item"], quantity)
		KEY_BACKSPACE:
			quantity = quantity / 10
		_:
			if key.keycode >= KEY_KP_0 and key.keycode <= KEY_KP_9:
				quantity = mini(quantity * 10 + (key.keycode - KEY_KP_0), 999)
			else:
				return false
	return true


func on_sim_event(kind: String, data: Dictionary) -> void:
	if kind != "bought" and kind != "sold":
		return
	if data["ok"]:
		var verb := "Bought" if kind == "bought" else "Sold"
		_result = "%s %d · %s" % [verb, data["quantity"], Words.CASH_LEFT % Words.cash(hub.sim.pilot()["cash"])]
		_result_colour = Look.GOOD
	else:
		_result = Words.TRADE_REFUSED.get(data["refused"], "Refused")
		_result_colour = Look.DANGER


func _draw() -> void:
	var rows: Array = hub.sim.market_rows()
	var docked := _docked()
	var w := size.x
	var name: String = Words.word_case(hub.sim.navigation()["current_name"])
	Look.text(self, Vector2(0, 0), "Market at %s" % name, 24, Look.TEXT)
	var heads := ["ITEM", "UNIT", "PRICE", "FOR SALE", "IN HOLD"]
	var cols := [0.0, w * 0.40, w * 0.62, w * 0.80, w]
	var y := 44.0
	Look.text(self, Vector2(16, y), heads[0], 13, Look.DIM, true)
	Look.text(self, Vector2(cols[1], y), heads[1], 13, Look.DIM, true)
	for i in [2, 3, 4]:
		Look.text_right(self, cols[i] - 8, y, heads[i], 13, Look.DIM)
	y += 24
	for row in rows:
		var index: int = row["item"]
		var is_selected: bool = docked and index == selected
		if is_selected:
			draw_rect(Rect2(Vector2(0, y - 3), Vector2(w, ROW - 2)), Color(Look.GOLD_DEEP, 0.3))
			draw_rect(Rect2(Vector2(0, y - 3), Vector2(2, ROW - 2)), Look.GOLD)
		var available: int = row["available"]
		var colour := Look.TEXT if available > 0 or row["held"] > 0 else Look.DIM
		Look.text(self, Vector2(16, y + 3), row["name"], 17, colour)
		if row["dear_here"]:
			Look.text(self, Vector2(cols[1] - 34, y + 4), "▲", 14, Look.GOOD)
		Look.text(self, Vector2(cols[1], y + 4), row["unit"], 16, Look.DIM, true)
		Look.text_right(self, cols[2] - 8, y + 3, Words.cash(row["price"]), 17, colour)
		Look.text_right(self, cols[3] - 8, y + 3, str(available) if available > 0 else "—", 17, colour)
		var held: int = row["held"]
		Look.text_right(self, cols[4] - 8, y + 3, str(held) if held > 0 else "", 17, Look.GOLD)
		y += ROW
	if not docked:
		return
	var row: Dictionary = rows[selected]
	var price: int = row["price"]
	var stepper_y := y + 14
	draw_line(Vector2(0, stepper_y - 6), Vector2(w, stepper_y - 6), Look.RULE, 1.0)
	var over_buy := quantity > int(row["max_buy"])
	var over_sell := quantity > int(row["max_sell"])
	Look.text(self, Vector2(16, stepper_y + 6), String(row["name"]), 18, Look.TEXT)
	var stepper := "−  %3d  +  %s" % [quantity, row["unit"]]
	Look.text(self, Vector2(w * 0.36, stepper_y + 4), stepper, 20, Look.DANGER if over_buy and over_sell else Look.TEXT, true)
	Look.text_right(self, w - 8, stepper_y + 6, "Total %s SC" % Words.cash(price * quantity), 18, Look.TEXT)
	var keys_y := stepper_y + 44
	var x := 16.0
	x += Look.key_chip(self, Vector2(x, keys_y), "B") + 8
	Look.text(self, Vector2(x, keys_y + 2), "Buy (up to %d)" % row["max_buy"], 15, Look.DIM if over_buy else Look.TEXT)
	x += 170
	x += Look.key_chip(self, Vector2(x, keys_y), "N") + 8
	Look.text(self, Vector2(x, keys_y + 2), "Sell (up to %d)" % row["max_sell"], 15, Look.DIM if over_sell else Look.TEXT)
	x += 170
	x += Look.key_chip(self, Vector2(x, keys_y), "←→") + 8
	Look.text(self, Vector2(x, keys_y + 2), "Quantity, Shift ×10", 15, Look.DIM)
	if _result != "":
		Look.text(self, Vector2(16, keys_y + 36), _result, 16, _result_colour, true)
