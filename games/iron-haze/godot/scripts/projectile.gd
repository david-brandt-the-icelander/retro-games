extends Node3D
## Bullets, shells, flak bursts, artillery rounds and bombs.

const Models := preload("res://scripts/models.gd")

var weapon := "cannon"
var team := 0
var shooter = null
var target = null
var target_pos := Vector3.ZERO
var aim_offset := Vector3.ZERO
var start := Vector3.ZERO
var damage := 10.0
var splash := 0.0
var duration := 0.5
var arc := 0.0
var homing := true
var t := 0.0
var trail: GPUParticles3D = null


func _ready() -> void:
	position = start
	add_child(Models.projectile_mesh(weapon))
	if weapon == "artillery" or weapon == "bombs":
		trail = FX.trail(self)


func _process(delta: float) -> void:
	t += delta
	if homing and Game.alive(target):
		var tp: Vector3 = target.position
		target_pos = tp + aim_offset
	var k := clampf(t / duration, 0.0, 1.0)
	var pos := start.lerp(target_pos, k)
	if weapon == "bombs":
		pos.y = lerpf(start.y, target_pos.y, k * k)
	pos.y += arc * 4.0 * k * (1.0 - k)
	var dir := pos - position
	position = pos
	if dir.length_squared() > 0.000001:
		var up := Vector3.UP
		if absf(dir.normalized().y) > 0.98:
			up = Vector3.RIGHT
		look_at(global_position + dir, up)
	if k >= 1.0:
		_impact()


func _impact() -> void:
	if splash > 0.0:
		for e in Game.query(position, splash):
			if e.team == team:
				continue
			var ep: Vector3 = e.position
			if absf(ep.y - position.y) > splash + 3.0:
				continue
			var d := Vector2(ep.x - position.x, ep.z - position.z).length()
			var f := clampf(1.0 - d / (splash + float(e.radius)), 0.3, 1.0)
			e.take_damage(damage * f * Game.damage_mult(weapon, e), shooter)
	elif Game.alive(target):
		target.take_damage(damage * Game.damage_mult(weapon, target), shooter)
	FX.impact(weapon, position)
	if trail != null and is_instance_valid(trail):
		trail.emitting = false
		trail.reparent(Game.world.fx_root, true)
		FX.free_later(trail, 1.5)
	queue_free()
