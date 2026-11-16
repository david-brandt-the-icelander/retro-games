extends Node2D
## Horizontal laser bolt that wraps around the screen.

const W = preload("res://scripts/world.gd")

const SPEED := 1500.0
const MAX_LEN := 240.0

var dir := 1
var head_x := 0.0
var length := 0.0
var life := 0.5
var color := Color(2, 2, 2)
var dead := false


func setup(pos: Vector2, d: int, c: Color) -> void:
	position = Vector2(0, pos.y)
	head_x = pos.x
	dir = d
	color = c


func _ready() -> void:
	z_index = 6


func step(delta: float) -> void:
	head_x += dir * SPEED * delta
	length = minf(length + SPEED * delta, MAX_LEN)
	life -= delta
	if life <= 0.0:
		dead = true
	queue_redraw()


func tail_x() -> float:
	return head_x - dir * length


func hits(r: Rect2) -> bool:
	if position.y < r.position.y - 3.0 or position.y > r.end.y + 3.0:
		return false
	var a := minf(head_x, tail_x())
	var b := maxf(head_x, tail_x())
	for o in [-W.WIDTH, 0.0, W.WIDTH]:
		if b + o >= r.position.x and a + o <= r.end.x:
			return true
	return false


func _draw() -> void:
	var fade := clampf(life * 4.0, 0.0, 1.0)
	for o in [-W.WIDTH, 0.0, W.WIDTH]:
		var h := Vector2(head_x + o, 0)
		var tl := Vector2(tail_x() + o, 0)
		draw_line(tl, h, Color(color.r, color.g, color.b, 0.22 * fade), 8.0)
		draw_line(tl.lerp(h, 0.35), h, Color(color.r, color.g, color.b, 0.9 * fade), 2.5)
		draw_line(h - Vector2(dir * 34.0, 0), h, Color(2.6, 2.6, 2.6, fade), 2.0)
