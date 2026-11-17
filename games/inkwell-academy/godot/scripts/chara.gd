class_name Chara
extends Node2D
## A cut-out character: SVG body parts on a small bone rig, animated procedurally
## (walk cycle, sitting, being knocked flat, idle breathing).

static var RIG := {}

# --- simulation state (driven by main.gd)
var id := ""
var cname := ""
var kind := "pupil"          # player | pupil | teacher
var title := ""
var floor_i := 2
var wx := 0.0
var wy := 0.0
var dir := 1
var state := "idle"          # idle | walk | stairs | sit | down
var speed := 230.0
var base_speed := 230.0
var stair = null
var st := 0.0
var stair_dir := 1
var target = null
var arrived := true
var wait_until := 0.0
var down_until := 0.0
var special := ""
var moved := 0.0
var catch_cd := 0.0
var next_bully := 25.0
var chase_until := 0.0
var tell_until := 0.0
var cool := 0.0
var desk := 0
var fire_cd := 0.0
var accent := Color.WHITE
var height_px := 104.0

# --- rig
var r := {}
var body: Node2D
var hip: Node2D
var torso: Sprite2D
var head: Node2D
var gown: Node2D
var arm_b: Node2D
var arm_f: Node2D
var thigh_b: Node2D
var thigh_f: Node2D
var shin_b: Node2D
var shin_f: Node2D
var shadow: Sprite2D
var stars: Node2D
var phase := 0.0
var amp := 0.0
var sitk := 0.0
var fall := 0.0
var clock := 0.0
var hip_h := 54.0
var bubble: Node2D = null
var bubble_until := 0.0
var face_lock := 0.0


func build(def: Dictionary) -> void:
	for k in def:
		set(k, def[k])
	base_speed = speed
	if RIG.is_empty():
		RIG = JSON.parse_string(FileAccess.get_file_as_string("res://art/rig.json"))
	r = RIG[id]
	var sc: float = r["scale"]
	hip_h = float(r["thigh"]) + float(r["shin"])
	height_px = (hip_h + float(r["torsoH"]) + 52.0) * sc
	shadow = Sprite2D.new()
	shadow.texture = load("res://art/shadow.svg")
	shadow.scale = Vector2(0.75, 0.9) * (1.15 if kind == "teacher" else 0.85)
	shadow.position = Vector2(0, -2)
	add_child(shadow)
	body = Node2D.new()
	body.scale = Vector2(sc, sc)
	add_child(body)
	hip = Node2D.new()
	hip.position = Vector2(0, -hip_h)
	body.add_child(hip)
	var th: float = r["torsoH"]
	var shoulder := Vector2(0, -th + 7)
	if r["parts"].has("gown"):
		gown = _joint(hip, "gown", shoulder + Vector2(-2, -3))
	arm_b = _joint(hip, "arm", shoulder + Vector2(-3, 0), true)
	thigh_b = _joint(hip, "thigh", Vector2(-3, 0), true)
	shin_b = _joint(thigh_b, "shin", Vector2(0, float(r["thigh"])), true)
	thigh_f = _joint(hip, "thigh", Vector2(3, 0))
	shin_f = _joint(thigh_f, "shin", Vector2(0, float(r["thigh"])))
	head = _joint(hip, "head", Vector2(1, -th + 6))
	var tnode := _joint(hip, "torso", Vector2.ZERO)
	torso = tnode.get_child(0)
	arm_f = _joint(hip, "arm", shoulder + Vector2(3, 0))
	stars = Node2D.new()
	stars.visible = false
	add_child(stars)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = load("res://art/star.svg")
		s.scale = Vector2(0.45, 0.45)
		stars.add_child(s)
	position = Vector2(wx, wy)


func _joint(parent: Node2D, part: String, pos: Vector2, back := false) -> Node2D:
	var j := Node2D.new()
	j.position = pos
	parent.add_child(j)
	var s := Sprite2D.new()
	s.texture = load("res://art/chars/%s_%s.svg" % [id, part])
	s.centered = false
	var pv: Array = r["parts"][part]
	s.scale = Vector2(0.5, 0.5)
	s.offset = Vector2(-pv[0] * 2.0, -pv[1] * 2.0)
	if back:
		s.modulate = Color(0.78, 0.78, 0.86)
	j.add_child(s)
	return j


func animate(dt: float, now: float) -> void:
	clock += dt
	position = Vector2(roundf(wx), roundf(wy))
	var walking := moved > 0.05
	amp = move_toward(amp, 1.0 if walking else 0.0, dt * 8.0)
	if walking:
		phase += moved / (hip_h * float(r["scale"]) * 1.55) * PI
	sitk = move_toward(sitk, 1.0 if state == "sit" else 0.0, dt * 6.0)
	var falling := state == "down"
	fall = move_toward(fall, 1.0 if falling else 0.0, dt * (6.0 if falling else 3.0))
	var sw := sin(phase)
	var a := deg_to_rad(32.0) * amp
	var tf := -sw * a
	var tb := sw * a
	var kf := maxf(0.0, sin(phase - 1.2)) * 0.9 * amp
	var kb := maxf(0.0, -sin(phase - 1.2)) * 0.9 * amp
	var seat := float(r["shin"]) * 0.92
	thigh_f.rotation = lerpf(tf, -PI / 2.0 + 0.08, sitk)
	thigh_b.rotation = lerpf(tb, -PI / 2.0 - 0.04, sitk)
	shin_f.rotation = lerpf(kf, PI / 2.0 - 0.1, sitk)
	shin_b.rotation = lerpf(kb, PI / 2.0 + 0.05, sitk)
	var bob := absf(cos(phase)) * 3.0 * amp
	var breathe := sin(clock * 2.3) * 0.8 * (1.0 - amp)
	hip.position.y = lerpf(-hip_h - bob, -seat, sitk)
	torso.scale.y = 0.5 * (1.0 + 0.012 * sin(clock * 2.3) * (1.0 - amp))
	head.position.y = -float(r["torsoH"]) + 6.0 + breathe * 0.4
	head.rotation = sin(clock * 1.3) * 0.03 * (1.0 - amp)
	arm_f.rotation = lerpf(sw * a * 0.85 + sin(clock * 2.3) * 0.02, -1.05, sitk)
	arm_b.rotation = lerpf(-sw * a * 0.85, -0.95, sitk)
	if gown:
		gown.rotation = -amp * 0.06 - sitk * 0.1
	# knocked flat
	var e := ease(fall, 0.4)
	body.rotation = -PI / 2.0 * e * dir
	body.position.y = -e * 14.0
	body.scale.x = float(r["scale"]) * dir
	shadow.scale.x = (0.75 + e * 0.9) * (1.15 if kind == "teacher" else 0.85)
	shadow.position.x = -e * 34.0 * dir
	stars.visible = fall > 0.6
	if stars.visible:
		var hp := head.global_position - global_position + Vector2(0, -26)
		stars.position = hp
		for i in stars.get_child_count():
			var ang := clock * 4.0 + i * TAU / 3.0
			var s: Sprite2D = stars.get_child(i)
			s.position = Vector2(cos(ang) * 30.0, sin(ang) * 9.0)
			s.rotation = clock * 3.0
			s.z_index = 1 if sin(ang) > 0 else -1
	# blink the player while dazed
	if kind == "player" and falling:
		modulate.a = 0.55 + 0.45 * absf(sin(now * 12.0))
	else:
		modulate.a = 1.0


func head_top() -> float:
	if state == "down":
		return wy - 46.0
	if state == "sit":
		return wy - height_px + float(r["shin"]) * 0.6 * float(r["scale"])
	return wy - height_px
