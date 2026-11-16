extends "res://scripts/target.gd"
## Shoot these to refuel.

const M = preload("res://scripts/mats.gd")

var band_mat: StandardMaterial3D
var t: float = 0.0


func _ready() -> void:
	hp = 1
	points = 300
	explosion_size = 1.2
	explosion_color = Color(1.0, 0.75, 0.2)
	popup_color = Color(0.5, 1.0, 0.6)
	setup_collision(Vector3(2.0, 2.8, 2.0), Vector3(0, 1.4, 0))
	make_visual()
	var shell := M.metal(Color(0.86, 0.84, 0.78), 0.35, 0.55)
	part(cyl(0.85, 0.85, 1.9, 20), shell, Vector3(0, 0.95, 0))
	var dome := SphereMesh.new()
	dome.radius = 0.85
	dome.height = 0.85
	dome.is_hemisphere = true
	dome.radial_segments = 20
	dome.rings = 6
	part(dome, shell, Vector3(0, 1.9, 0))
	band_mat = StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.3, 0.2, 0.05)
	band_mat.emission_enabled = true
	band_mat.emission = Color(1.0, 0.68, 0.15)
	band_mat.emission_energy_multiplier = 4.0
	for y in [0.55, 1.35]:
		part(cyl(0.88, 0.88, 0.16, 20), band_mat, Vector3(0, y, 0))
	part(cyl(1.05, 1.15, 0.2, 16), M.metal(Color(0.15, 0.16, 0.19), 0.5, 0.8), Vector3(0, 0.1, 0))
	var lbl := Label3D.new()
	lbl.text = "FUEL"
	lbl.font_size = 44
	lbl.pixel_size = 0.01
	lbl.outline_size = 0
	lbl.modulate = Color(0.12, 0.1, 0.08)
	var a := deg_to_rad(-45.0)
	lbl.rotation.y = a
	lbl.position = Vector3(sin(a) * 0.87, 0.95, cos(a) * 0.87)
	visual.add_child(lbl)


func _process(delta: float) -> void:
	t += delta
	band_mat.emission_energy_multiplier = 3.0 + 1.5 * sin(t * 5.0)


func _on_destroyed() -> void:
	Game.add_fuel(22.0)
	Sfx.play("pickup", -4.0)
	Game.popup(global_position + Vector3(0, 4.2, 0), "+FUEL", Color(0.5, 1.0, 0.6))
