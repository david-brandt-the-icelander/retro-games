extends Control
## The hold page (UI-DESIGN `07 HOLD`, RULES D.6.3): fuel and cash, the hold's capacity with a
## bar, and one line per goods item carried with its quantity and unit.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")

var hub: Control
var galaxy_mode := false


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var pilot: Dictionary = hub.sim.pilot()
	var rows: Array = hub.sim.market_rows()
	Look.text(self, Vector2(0, 0), "Hold", 24, Look.TEXT)
	Look.text(self, Vector2(0, 50), "Fuel", 16, Look.DIM)
	Look.text(self, Vector2(160, 48), "%s LY" % Words.tenths(pilot["fuel"]), 20, Look.TEXT, true)
	Look.text(self, Vector2(0, 84), "Cash", 16, Look.DIM)
	Look.text(self, Vector2(160, 82), "%s SC" % Words.cash(pilot["cash"]), 20, Look.TEXT, true)
	var hold: int = pilot["hold"]
	var used: int = pilot["hold_used"]
	var label := "Hold %d t%s" % [hold, " (sponsons)" if pilot["fitted"]["hold_extension"] else ""]
	Look.bar(self, Rect2(Vector2(0, 124), Vector2(size.x * 0.6, 30)), label, float(used) / float(maxi(hold, 1)), "%d / %d t" % [used, hold], Look.AMBER if used >= hold else Look.TEXT)
	var y := 184.0
	var cargo: PackedInt64Array = pilot["cargo"]
	var any := false
	for row in rows:
		var n: int = cargo[row["item"]]
		if n <= 0:
			continue
		any = true
		Look.text(self, Vector2(0, y), row["name"], 18, Look.TEXT)
		Look.text_right(self, size.x * 0.5, y, "%d %s" % [n, row["unit"]], 18, Look.TEXT)
		y += 32
	if not any:
		Look.text(self, Vector2(0, y), "Empty.", 18, Look.DIM)
