extends Control
## The tunnels (RULES D.3.4's visual rule, GDD § 8 `tunnel.*`): while the sim is in a tunnel, a
## cleared view with rings rushing outwards. Step k draws rings whose radius starts at
## 8 + (k mod 8) and doubles until it passes 160 (view half-width units), eased between steps by
## the tick's alpha. The launch and docking bay is gold; the jump cycles four cool colours; the
## mis-jump into the Deep turns green and breaks off; the Reach jump cycles warm ones. The HUD
## stays live above it.

const Look := preload("res://src/presentation/ui/look.gd")
const Words := preload("res://src/presentation/text/words.gd")
const JUMP_COLOURS := [Color("#9fc3ff"), Color("#cfe0ff"), Color("#6e9bff"), Color("#f4f6ff")]
const REACH_COLOURS := [Color("#ffc27a"), Color("#ffe8c0"), Color("#ff9a5a"), Color("#c9a25c")]
const DEEP_COLOURS := [Color("#9dff4a"), Color("#4cc38a"), Color("#7a9a6a"), Color("#9dff4a")]

var sim: Node


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	visible = sim != null and String(sim.mode()).begins_with("tunnel")
	if visible:
		queue_redraw()


func _draw() -> void:
	var mode: String = sim.mode()
	draw_rect(Rect2(Vector2.ZERO, size), Look.VOID)
	var step: int = sim.mode_count()
	var k: float = float(step) + sim.alpha()
	var centre := size / 2.0
	var unit := size.y / 192.0
	var bay := mode in ["tunnel_launch", "tunnel_dock"]
	var colours: Array = JUMP_COLOURS
	if mode == "tunnel_galactic":
		colours = REACH_COLOURS
	elif mode == "tunnel_misjump":
		colours = DEEP_COLOURS
	var radius := 8.0 + fmod(k, 8.0)
	var i := 0
	while radius <= 160.0 * 1.5:
		var r := radius * unit
		var colour: Color = Look.GOLD if bay else colours[(i + step) % 4]
		if mode == "tunnel_misjump" and step > 10 and i % 2 == 1:
			colour.a = 0.25
		if bay:
			var points := PackedVector2Array()
			for corner in 9:
				var a := TAU * float(corner) / 8.0 + PI / 8.0
				points.append(centre + Vector2(cos(a), sin(a)) * r)
			draw_polyline(points, colour, 2.0)
		else:
			draw_arc(centre, r, 0, TAU, 64, colour, 2.5)
		radius *= 2.0
		i += 1
	var label := ""
	match mode:
		"tunnel_launch":
			label = "LAUNCHING"
		"tunnel_dock":
			label = "BERTHING"
		"tunnel_galactic":
			label = Words.MESSAGES["reach_jump"]
		_:
			label = "JUMPING"
	Look.text_centre(self, centre.x, size.y - 140, label, 18, Look.DIM, true)
