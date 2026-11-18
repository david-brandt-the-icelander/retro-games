extends Label3D
## Floating score text.

var t: float = 0.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	pixel_size = 0.012
	font_size = 56
	outline_size = 14
	outline_modulate = Color(0, 0, 0, 0.75)
	render_priority = 10


func _process(delta: float) -> void:
	t += delta
	position.y += delta * 2.5
	modulate.a = clampf(1.4 - t, 0.0, 1.0)
	if t > 1.4:
		queue_free()
