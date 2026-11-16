class_name Unit
extends Node3D
## A playing piece on the board: state, 3D model and animations.

const SIDE_COL := {"US": Color(0.35, 0.62, 1.0), "DE": Color(1.0, 0.38, 0.3)}

var type_id := ""
var d: Dictionary = {}
var side := "US"
var hex := Vector2i.ZERO
var steps := 1
var status := "ok"          # ok / pinned / broken
var moved := false
var fired := false
var opfire_ready := false
var revealed := false
var hits_taken := 0
var alive := true
var anchor := -1
var facing_yaw := 0.0
var model: Node3D
var turret: Node3D
var barrel: Node3D
var muzzle: Node3D
var label: Label3D
var ring: MeshInstance3D
var body: StaticBody3D


func setup(tid: String, at_hex: Vector2i, pos: Vector3, yaw: float) -> void:
	type_id = tid
	d = UnitData.TYPES[tid]
	side = String(d["side"])
	hex = at_hex
	steps = int(d["steps"])
	position = pos
	facing_yaw = yaw
	_build_model()
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.52
	tm.outer_radius = 0.58
	tm.rings = 36
	tm.ring_segments = 6
	ring.mesh = tm
	ring.scale = Vector3(1, 0.2, 1)
	ring.position.y = 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	label.pixel_size = 0.0035
	label.outline_size = 10
	label.no_depth_test = true
	label.position = Vector3(0, 0.95 if is_vehicle() else 0.72, 0)
	add_child(label)
	body = StaticBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45
	sh.height = 0.6
	cs.shape = sh
	cs.position.y = 0.3
	body.add_child(cs)
	body.set_meta("unit", self)
	add_child(body)
	refresh()


func _build_model() -> void:
	if model != null:
		model.queue_free()
	model = Models.build(String(d["model"]), side, steps)
	add_child(model)
	model.rotation.y = facing_yaw
	turret = model.find_child("Turret", true, false) as Node3D
	barrel = model.find_child("Barrel", true, false) as Node3D
	muzzle = model.find_child("Muzzle", true, false) as Node3D


func is_vehicle() -> bool:
	return String(d["kind"]) == "vehicle"


func has_at() -> bool:
	return int(d["at_pen"]) > 0


func fp() -> int:
	var b: int = int(d["fp"])
	if steps < int(d["steps"]):
		b = int(round(b * 0.6))
	return b


func value() -> float:
	return float(d["value"]) * (0.7 if steps < int(d["steps"]) else 1.0)


func can_move() -> bool:
	return alive and not moved and not fired and status == "ok"


func can_fire() -> bool:
	return alive and not fired and status != "broken"


func facing_vector() -> Vector3:
	return Vector3(-sin(facing_yaw), 0, -cos(facing_yaw))


func display_name() -> String:
	return String(d["name"])


func refresh() -> void:
	if not alive:
		return
	var txt := String(d["short"])
	if steps < int(d["steps"]):
		txt += " (½)"
	var col: Color = SIDE_COL[side].lerp(Color.WHITE, 0.55)
	match status:
		"pinned":
			txt += "\nPINNED" if not is_vehicle() else "\nSHAKEN"
			col = Color(1.0, 0.85, 0.35)
		"broken":
			txt += "\nBROKEN"
			col = Color(1.0, 0.5, 0.2)
	label.text = txt
	label.modulate = col
	var spent := fired or status == "broken"
	var rc: Color = SIDE_COL[side]
	if spent:
		rc = Color(0.45, 0.45, 0.45)
	ring.material_override = Models.mat(rc, 0.5, 0.0, 1.4 if not spent else 0.2)


func _turn_to(yaw: float, t: float) -> void:
	var target: float = facing_yaw + wrapf(yaw - facing_yaw, -PI, PI)
	var tw := create_tween()
	tw.tween_property(model, "rotation:y", target, t).set_trans(Tween.TRANS_SINE)
	await tw.finished
	facing_yaw = wrapf(target, -PI, PI)
	model.rotation.y = facing_yaw


func move_along(points: Array[Vector3]) -> void:
	var step_t: float = 0.22 if is_vehicle() else 0.3
	for p in points:
		var dir: Vector3 = p - position
		dir.y = 0
		if dir.length() > 0.01:
			var want: float = atan2(-dir.x, -dir.z)
			if absf(wrapf(want - facing_yaw, -PI, PI)) > 0.05:
				await _turn_to(want, 0.14)
		var tw := create_tween()
		tw.tween_property(self, "position", p, step_t).set_trans(Tween.TRANS_SINE if not is_vehicle() else Tween.TRANS_LINEAR)
		if not is_vehicle():
			var bob := create_tween()
			bob.tween_property(model, "position:y", 0.04, step_t * 0.5)
			bob.tween_property(model, "position:y", 0.0, step_t * 0.5)
		await tw.finished


func aim_at(world_pos: Vector3) -> void:
	var v: Vector3 = world_pos - global_position
	v.y = 0
	if v.length() < 0.01:
		return
	var want: float = atan2(-v.x, -v.z)
	if bool(d["turret"]) and turret != null:
		var local: float = wrapf(want - facing_yaw, -PI, PI)
		var cur: float = turret.rotation.y
		var tgt: float = cur + wrapf(local - cur, -PI, PI)
		var tw := create_tween()
		tw.tween_property(turret, "rotation:y", tgt, 0.4).set_trans(Tween.TRANS_SINE)
		await tw.finished
	else:
		await _turn_to(want, 0.3)


func _recoil() -> void:
	if barrel == null:
		return
	var z0: float = barrel.position.z
	var tw := create_tween()
	tw.tween_property(barrel, "position:z", z0 + 0.07, 0.05)
	tw.tween_property(barrel, "position:z", z0, 0.35).set_trans(Tween.TRANS_SINE)


func fire_fx(target_pos: Vector3, at_mode: bool, fx_root: Node3D) -> void:
	var kind: String = String(d["kind"])
	var origin: Vector3 = muzzle.global_position if muzzle != null else global_position + Vector3(0, 0.22, 0)
	if kind == "vehicle" or kind == "gun":
		FX.muzzle_flash(fx_root, origin, 1.0)
		_recoil()
		await FX.tracer(fx_root, origin, target_pos, Color(1.0, 0.75, 0.35), 0.16, 0.03)
		if not at_mode and kind == "vehicle":
			for i in 5:
				var o := global_position + Vector3(0, 0.32, 0)
				FX.tracer(fx_root, o, target_pos + Vector3(randf_range(-0.3, 0.3), randf_range(0.0, 0.15), randf_range(-0.3, 0.3)),
					Color(1.0, 0.85, 0.45), 0.12, 0.01)
				await get_tree().create_timer(0.05).timeout
		return
	if String(d["model"]) == "bazooka" and at_mode:
		FX.muzzle_flash(fx_root, global_position + Vector3(0, 0.22, 0), 0.6)
		FX.particles(fx_root, global_position + Vector3(0, 0.2, 0.25), Color(0.7, 0.68, 0.64, 0.7), Color(0.7, 0.7, 0.7, 0.0), 10, 0.35, 1.0, 1.0, 0.2, 30.0, false)
		await FX.tracer(fx_root, global_position + Vector3(0, 0.24, 0), target_pos, Color(1.0, 0.55, 0.25), 0.32, 0.03)
		return
	var n: int = 11 if String(d["model"]) == "mg" else 7
	for i in n:
		var o2 := global_position + Vector3(randf_range(-0.25, 0.25), 0.18, randf_range(-0.25, 0.25))
		FX.muzzle_flash(fx_root, o2, 0.22)
		FX.tracer(fx_root, o2, target_pos + Vector3(randf_range(-0.35, 0.35), randf_range(0.0, 0.2), randf_range(-0.35, 0.35)),
			Color(1.0, 0.9, 0.5), 0.14, 0.01)
		await get_tree().create_timer(0.045).timeout
	await get_tree().create_timer(0.15).timeout


func take_step() -> bool:
	## Returns true if the unit survives the step loss.
	steps -= 1
	if steps <= 0:
		return false
	_build_model()
	refresh()
	return true


func eliminate() -> void:
	alive = false
	label.visible = false
	ring.visible = false
	body.queue_free()
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3(1.0, 0.05, 1.0), 0.6).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(func() -> void: model.visible = false)


func make_wreck(fx_root: Node3D) -> void:
	alive = false
	label.visible = false
	ring.visible = false
	body.queue_free()
	var burnt := Models.mat(Color(0.09, 0.085, 0.08), 1.0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = burnt
	if turret != null and bool(d["turret"]):
		turret.rotation.y += randf_range(-0.7, 0.7)
		turret.rotation.z = randf_range(-0.12, 0.12)
		turret.position.y += 0.03
	if barrel != null:
		barrel.rotation.x = randf_range(-0.2, -0.05)
	FX.smoke_column(fx_root, global_position + Vector3(0, 0.35, 0))
