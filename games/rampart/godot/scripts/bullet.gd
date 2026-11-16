extends Area3D
## Player laser bolt or hostile energy shell.

const M = preload("res://scripts/mats.gd")

var velocity: Vector3 = Vector3.ZERO
var life: float = 1.1
var hostile: bool = false
var big: bool = false
var color: Color = Color(0.45, 0.95, 1.0)
var done: bool = false


func _ready() -> void:
	var cs := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if hostile:
		collision_layer = 16
		collision_mask = 0
		monitoring = false
		monitorable = true
		var r := 0.42 if big else 0.32
		var sh := SphereShape3D.new()
		sh.radius = r + 0.03
		cs.shape = sh
		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		sm.radial_segments = 12
		sm.rings = 6
		mi.mesh = sm
		mi.material_override = M.add(color, 4.0, 1)
		var core := MeshInstance3D.new()
		var sm2 := SphereMesh.new()
		sm2.radius = r * 0.45
		sm2.height = r * 0.9
		sm2.radial_segments = 8
		sm2.rings = 4
		core.mesh = sm2
		core.material_override = M.add(Color(1.0, 0.95, 0.9), 3.0, 0)
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(core)
		add_to_group("enemy_shot")
	else:
		collision_layer = 2
		collision_mask = 4 | 8
		monitoring = true
		monitorable = false
		var bx := BoxShape3D.new()
		bx.size = Vector3(0.35, 0.5, 1.6)
		cs.shape = bx
		var cm := CylinderMesh.new()
		cm.top_radius = 0.055
		cm.bottom_radius = 0.055
		cm.height = 1.6
		cm.radial_segments = 6
		cm.rings = 1
		mi.mesh = cm
		mi.rotation.x = PI / 2.0
		mi.material_override = M.add(color, 7.0, 0)
		area_entered.connect(_on_area_entered)
	add_child(cs)
	add_child(mi)


func _process(delta: float) -> void:
	position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()


func _on_area_entered(a: Area3D) -> void:
	if done:
		return
	done = true
	if a.has_method("hit"):
		a.hit(1)
	else:
		Game.spawn_spark(global_position)
		Sfx.play("ricochet", -12.0, randf_range(0.9, 1.2))
	queue_free()
