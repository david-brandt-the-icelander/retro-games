extends "res://scripts/target.gd"
## The Warden's vulnerable reactor core.

var boss: Node3D


func _ready() -> void:
	points = 0
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.35
	cs.shape = sh
	add_child(cs)


func hit(dmg: int) -> void:
	if dead or boss == null or boss.dying:
		return
	hp -= dmg
	boss.on_core_hit()
	if hp <= 0:
		dead = true
		boss.begin_death()
