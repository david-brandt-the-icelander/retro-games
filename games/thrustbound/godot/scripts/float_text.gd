extends Node2D
## Floating score pop-up.

var text := ""
var t := 0.0
var color := Color(1, 1, 1)
var font: Font


func setup(s: String, pos: Vector2, c: Color) -> void:
	text = s
	position = pos
	color = c


func _ready() -> void:
	z_index = 20
	font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	t += delta
	position.y -= 42.0 * delta
	queue_redraw()
	if t > 1.0:
		queue_free()


func _draw() -> void:
	var a := clampf(1.5 - t * 1.5, 0.0, 1.0)
	draw_string_outline(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, 5, Color(0, 0, 0, 0.6 * a))
	draw_string(font, Vector2(-60, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 120, 18, Color(color.r, color.g, color.b, a))
