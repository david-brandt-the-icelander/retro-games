extends "res://scripts/target.gd"
## Rotating sensor dish — high value target.

const M = preload("res://scripts/mats.gd")

var dish: Node3D
var blink: MeshInstance3D
var t: float = 0.0


func _ready() -> void:
	hp = 2
	points = 1000
	explosion_size = 1.3
	explosion_color = Color(0.4, 1.0, 0.6)
	popup_color = Color(0.5, 1.0, 0.7)
	setup_collision(Vector3(2.6, 3.2, 2.6), Vector3(0, 1.6, 0))
	make_visual()
	var dark := M.metal(Color(0.18, 0.2, 0.23), 0.45, 0.85)
	var light := M.metal(Color(0.75, 0.78, 0.82), 0.25, 0.85)
	part(box(1.7, 0.7, 1.7), dark, Vector3(0, 0.35, 0))
	part(cyl(0.16, 0.2, 1.4, 10), dark, Vector3(0, 1.4, 0))
	dish = Node3D.new()
	dish.position.y = 2.1
	visual.add_child(dish)
	var bowl := part(cyl(1.35, 0.25, 0.4, 24), light, Vector3(0, 0.2, 0), Vector3(0.95, 0, 0), Vector3.ONE, dish)
	part(cyl(0.04, 0.04, 1.1, 6), dark, Vector3(0, 0.55, 0.0), Vector3.ZERO, Vector3.ONE, bowl)
	part(sphere(0.12, 8), M.glow(Color(0.3, 1.0, 0.55), 8.0), Vector3(0, 1.1, 0), Vector3.ZERO, Vector3.ONE, bowl)
	blink = part(sphere(0.1, 8), M.glow(Color(0.3, 1.0, 0.55), 8.0), Vector3(0.75, 0.75, 0.75))


func _process(delta: float) -> void:
	t += delta
	dish.rotation.y += delta * 1.6
	blink.visible = fmod(t, 0.8) < 0.15
