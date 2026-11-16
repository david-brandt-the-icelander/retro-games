extends Control
## Top-down radar of the arena showing every trail and rider.

var game: Node


func _process(_delta: float) -> void:
	queue_redraw()


func _to_map(p: Vector2, half: float) -> Vector2:
	return (p + Vector2(half, half)) / (half * 2.0) * size


func _draw() -> void:
	if game == null:
		return
	var half: float = game.ARENA_HALF
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(0.01, 0.04, 0.09, 0.6))
	# Grid.
	for i in range(1, 5):
		var x := size.x * i / 5.0
		var y := size.y * i / 5.0
		draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.3, 0.6, 1.0, 0.08), 1.0)
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.3, 0.6, 1.0, 0.08), 1.0)
	draw_rect(rect, Color(0.45, 0.75, 1.0, 0.7), false, 2.0)

	for c in game.cycles:
		if not is_instance_valid(c) or not c.collidable:
			continue
		var pts := PackedVector2Array()
		for p in c.trail_points:
			pts.append(_to_map(p, half))
		pts.append(_to_map(Vector2(c.position.x, c.position.z), half))
		var col: Color = c.color
		if not c.alive:
			col.a = 0.35
		if pts.size() >= 2:
			draw_polyline(pts, col, 2.0, true)
		if c.alive:
			var head := pts[pts.size() - 1]
			draw_circle(head, 6.0 if c.is_player else 4.5, Color(col.r, col.g, col.b, 0.25))
			draw_circle(head, 3.0, Color.WHITE if c.is_player else col)
