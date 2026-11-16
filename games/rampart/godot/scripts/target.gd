extends Area3D
## Base class for anything the player can shoot.

var hp: int = 1
var points: int = 100
var explosion_size: float = 1.0
var explosion_color: Color = Color(1.0, 0.55, 0.2)
var popup_color: Color = Color(1.0, 0.85, 0.4)
var dead: bool = false
var visual: Node3D


func setup_collision(size: Vector3, offset: Vector3 = Vector3.ZERO) -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = offset
	add_child(cs)


func make_visual() -> Node3D:
	visual = Node3D.new()
	add_child(visual)
	return visual


func part(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	if parent == null:
		parent = visual
	parent.add_child(mi)
	return mi


func hit(dmg: int) -> void:
	if dead:
		return
	hp -= dmg
	if hp <= 0:
		destroy()
	else:
		Sfx.play("hit", -8.0, randf_range(0.9, 1.1))
		Game.spawn_spark(global_position + explosion_offset())
		if visual:
			visual.scale = Vector3.ONE * 1.12
			var tw := create_tween()
			tw.tween_property(visual, "scale", Vector3.ONE, 0.15)


func destroy() -> void:
	if dead:
		return
	dead = true
	Game.add_score(points)
	Game.spawn_explosion(global_position + explosion_offset(), explosion_size, explosion_color)
	if points > 0:
		Game.popup(global_position + explosion_offset() + Vector3(0, 2.0, 0), str(points), popup_color)
	_on_destroyed()
	queue_free()


func explosion_offset() -> Vector3:
	return Vector3(0, 1.0, 0)


func _on_destroyed() -> void:
	pass


static func cyl(top: float, bottom: float, height: float, segs: int = 12) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = height
	c.radial_segments = segs
	c.rings = 1
	return c


static func box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b


static func sphere(r: float, segs: int = 16) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = maxi(segs / 2, 3)
	return s
