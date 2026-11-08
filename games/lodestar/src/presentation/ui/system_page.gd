extends Control
## The system data page (UI-DESIGN `05 SYSTEM`, RULES D.6.5): the selected system's distance,
## economy, government, tech level, population, inhabitants, productivity and radius, with a
## plain turning planet on the left and a two-line description made only from the data.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")

var hub: Control
var galaxy_mode := false
var _turn := 0.0


func _process(delta: float) -> void:
	if visible:
		_turn += delta * 0.3
		queue_redraw()


func _draw() -> void:
	var s: Dictionary = hub.sim.system_data()
	Look.text(self, Vector2(0, 0), Words.word_case(s["name"]), 30, Look.TEXT)
	# The planet: a disc, its night side and a band that turns (the rendered planet is later work).
	var centre := Vector2(170, 260)
	var radius := 120.0
	var farm: bool = int(s["economy"]) >= 4
	var colour := Color("#3f6a4a") if farm else Color("#4a5566")
	draw_circle(centre, radius, colour)
	for i in 5:
		var y := centre.y - radius + 40 + i * 40
		var half := sqrt(maxf(radius * radius - (y - centre.y) * (y - centre.y), 0.0))
		var shift := sin(_turn + i) * half * 0.3
		draw_line(Vector2(centre.x - half * 0.8 + shift, y), Vector2(centre.x + half * 0.5 + shift, y), colour.lightened(0.15), 6.0)
	draw_arc(centre, radius, 0, TAU, 64, Look.RULE, 2.0)
	var x := 360.0
	var y := 64.0
	var rows := []
	var d: int = s["distance"]
	if d > 0:
		rows.append(["distance", "%s LY" % Words.tenths(d)])
	rows.append(["economy", s["economy_label"]])
	rows.append(["government", s["government_label"]])
	rows.append(["tech", str(s["tech_level"])])
	rows.append(["population", "%s billion" % Words.tenths(s["population"])])
	rows.append(["inhabitants", "(%s)" % s["inhabitants"]])
	rows.append(["productivity", "%s M SC" % Words.thousands(s["productivity"])])
	rows.append(["radius", "%s km" % Words.thousands(s["radius"])])
	for row in rows:
		Look.text(self, Vector2(x, y), Words.DATA_LABELS[row[0]], 15, Look.DIM)
		Look.text(self, Vector2(x + 170, y - 2), row[1], 19, Look.TEXT)
		y += 40
	var blurb := Words.system_blurb(s).split("\n")
	y += 20
	for line in blurb:
		Look.text(self, Vector2(x, y), line, 16, Look.DIM)
		y += 26
