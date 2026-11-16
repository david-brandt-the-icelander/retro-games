extends Node3D
## Base class for every unit and structure on the battlefield.

signal died(entity)

const Models := preload("res://scripts/models.gd")

var team := 0
var kind := ""
var def: Dictionary = {}
var hp := 1.0
var max_hp := 1.0
var radius := 1.0
var is_building := false
var is_air := false
var dead := false
var visual: Node3D
var sel_ring: MeshInstance3D
var weapon_cd := 0.0
var scan_cd := 0.0
var auto_target = null
var turret: Node3D = null
var barrel: Node3D = null
var muzzle: Node3D = null
var barrel_rest := Vector3.ZERO
var burning := false


func _setup_common() -> void:
	max_hp = float(def["hp"])
	hp = max_hp
	sel_ring = Models.selection_ring(radius, team, is_building)
	sel_ring.visible = false
	add_child(sel_ring)
	turret = visual.find_child("Turret", true, false) as Node3D
	barrel = visual.find_child("Barrel", true, false) as Node3D
	muzzle = visual.find_child("Muzzle", true, false) as Node3D
	if barrel:
		barrel_rest = barrel.position
	Game.register(self)


func set_selected(v: bool) -> void:
	if sel_ring:
		sel_ring.visible = v


func is_selected() -> bool:
	return sel_ring != null and sel_ring.visible


func display_name() -> String:
	return String(def["name"])


func armor_type() -> String:
	if is_building:
		return "building"
	return String(def["armor"])


func has_weapon() -> bool:
	return def.has("weapon")


func weapon_range() -> float:
	return float(def.get("range", 0.0))


func bar_height() -> float:
	return float(def.get("bar_h", 3.0))


func aim_height() -> float:
	if is_building:
		return bar_height() * 0.35
	if is_air:
		return 0.0
	return 0.9


func flat_dist(other) -> float:
	var op: Vector3 = other.position
	return Vector2(op.x - position.x, op.z - position.z).length()


func in_range(other) -> bool:
	var d := flat_dist(other) - float(other.radius) * 0.8
	if d > weapon_range():
		return false
	if d < float(def.get("min_range", 0.0)) - 2.0:
		return false
	return true


func find_target(extra: float = 0.0):
	var best = null
	var best_score := INF
	var reach := weapon_range() + extra
	var min_r := float(def.get("min_range", 0.0))
	var prefers_air := bool(def.get("hits_air", false))
	for e in Game.query(position, reach + 2.0):
		if e.team == team or e.dead or not Game.can_hit(def, e):
			continue
		var d := flat_dist(e) - float(e.radius) * 0.8
		if d > reach or d < min_r:
			continue
		var score := d
		if e.is_building:
			score += 20.0
		if prefers_air and e.is_air:
			score -= 15.0
		if score < best_score:
			best_score = score
			best = e
	return best


func muzzle_pos() -> Vector3:
	if muzzle:
		return muzzle.global_position
	return global_position + Vector3(0, 1.2, 0)


## Rotates the turret (if any) toward the target; returns true once aimed.
func aim_turret(tgt, delta: float) -> bool:
	if turret == null:
		return true
	var goal := 0.0
	if tgt != null:
		var parent := turret.get_parent() as Node3D
		var lp := parent.to_local(tgt.global_position)
		goal = atan2(-(lp.x - turret.position.x), -(lp.z - turret.position.z))
	turret.rotation.y = Game.turn_toward(turret.rotation.y, goal, 2.8 * delta)
	return absf(Game.ang_diff(turret.rotation.y, goal)) < 0.12


func fire_at(tgt) -> void:
	weapon_cd = float(def["rate"]) * randf_range(0.9, 1.1)
	Game.world.fire_weapon(self, tgt)
	if barrel:
		var tw := create_tween()
		tw.tween_property(barrel, "position", barrel_rest + Vector3(0, 0, 0.45), 0.05)
		tw.tween_property(barrel, "position", barrel_rest, 0.35).set_ease(Tween.EASE_OUT)


func take_damage(amount: float, attacker = null) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		die()
		return
	_on_damaged(attacker)
	if not burning and hp < max_hp * 0.35:
		burning = true
		_start_burning()


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0.0
	Game.unregister(self)
	died.emit(self)
	_on_death()
	queue_free()


func _on_damaged(_attacker) -> void:
	pass


func _start_burning() -> void:
	pass


func _on_death() -> void:
	pass
