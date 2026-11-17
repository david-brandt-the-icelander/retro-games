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
var state := "idle"          # idle | walk | stairs | sit | floor | down
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
var seat := -9               # the desk it is trying to sit at; -9 means its own, -1 means none free
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
var next_speak := 0.0        # teachers: when to say the next thing
var used := {}               # messages already said, so a teacher never repeats himself
var last_said := ""
var punch_p := -1.0          # 0..1 through a punch, -1 when not punching
var fire_p := -1.0           # 0..1 through firing the pea-shooter, -1 when not firing
var floork := 0.0
var to_floor := false        # when the fall ends, stay sitting on the floor
var shooter: Node2D
const PUNCH_SECS := 0.42
const FIRE_SECS := 0.5


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
	# the pea-shooter: a short tube held in the front hand, shown only while firing
	shooter = Node2D.new()
	shooter.visible = false
	arm_f.add_child(shooter)
	var tube := Polygon2D.new()
	var hand := float(r["arm"]) - 6.0
	tube.polygon = PackedVector2Array([Vector2(-2.6, hand), Vector2(2.6, hand), Vector2(2.6, hand + 44.0), Vector2(-2.6, hand + 44.0)])
	tube.color = Color("8a5a2b")
	shooter.add_child(tube)
	var mouth := Polygon2D.new()
	mouth.polygon = PackedVector2Array([Vector2(-3.4, hand + 36.0), Vector2(3.4, hand + 36.0), Vector2(3.4, hand + 44.0), Vector2(-3.4, hand + 44.0)])
	mouth.color = Color("3b2a17")
	shooter.add_child(mouth)
	stars = Node2D.new()
	stars.visible = false
	add_child(stars)
	for i in 3:
		var s := Sprite2D.new()
		s.texture = load("res://art/star.svg")
		s.scale = Vector2(0.45, 0.45)
		stars.add_child(s)
	position = Vector2(wx, wy)


func start_punch() -> void:
	punch_p = 0.0


func start_fire() -> void:
	fire_p = 0.0


## True from the moment the fist is at full stretch until it starts to come back.
func punch_landed() -> bool:
	return punch_p >= 0.3 and punch_p < 0.6


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
	floork = move_toward(floork, 1.0 if state == "floor" else 0.0, dt * 5.0)
	if punch_p >= 0.0:
		punch_p += dt / PUNCH_SECS
		if punch_p >= 1.0:
			punch_p = -1.0
	if fire_p >= 0.0:
		fire_p += dt / FIRE_SECS
		if fire_p >= 1.0:
			fire_p = -1.0
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
	# sitting on the floor: legs straight out in front, bottom on the ground
	thigh_f.rotation = lerpf(thigh_f.rotation, -PI / 2.0 + 0.08, floork)
	thigh_b.rotation = lerpf(thigh_b.rotation, -PI / 2.0 - 0.04, floork)
	shin_f.rotation = lerpf(shin_f.rotation, 0.06, floork)
	shin_b.rotation = lerpf(shin_b.rotation, -0.02, floork)
	hip.position.y = lerpf(lerpf(-hip_h - bob, -seat, sitk), -3.0, floork)
	torso.scale.y = 0.5 * (1.0 + 0.012 * sin(clock * 2.3) * (1.0 - amp))
	head.position.y = -float(r["torsoH"]) + 6.0 + breathe * 0.4
	head.rotation = sin(clock * 1.3) * 0.03 * (1.0 - amp)
	arm_f.rotation = lerpf(sw * a * 0.85 + sin(clock * 2.3) * 0.02, -1.05, sitk)
	arm_b.rotation = lerpf(-sw * a * 0.85, -0.95, sitk)
	arm_f.rotation = lerpf(arm_f.rotation, -0.5, floork)
	arm_b.rotation = lerpf(arm_b.rotation, -0.3, floork)
	var lunge := 0.0
	shooter.visible = fire_p >= 0.0
	if fire_p >= 0.0:
		# raise the pea-shooter to the lips, puff, then lower it
		var up := clampf(fire_p / 0.2, 0.0, 1.0) if fire_p < 0.7 else clampf((1.0 - fire_p) / 0.3, 0.0, 1.0)
		arm_f.rotation = lerpf(arm_f.rotation, -1.5, ease(up, 0.5))
		arm_b.rotation = lerpf(arm_b.rotation, -0.6, up)
		# the recoil of the puff, as the pea leaves
		if fire_p > 0.18 and fire_p < 0.38:
			lunge = -3.0 * sin((fire_p - 0.18) / 0.2 * PI)
	if punch_p >= 0.0:
		var pa := punch_p
		var swing := 0.0
		if pa < 0.3:        # wind up: fist drawn back, body leans away
			swing = lerpf(0.0, 1.0, pa / 0.3)
			arm_f.rotation = lerpf(arm_f.rotation, 1.1, swing)
			arm_b.rotation = lerpf(arm_b.rotation, -0.9, swing)
			lunge = -5.0 * swing
		elif pa < 0.6:      # the blow: arm snaps out straight, body lunges
			var k := (pa - 0.3) / 0.3
			arm_f.rotation = lerpf(1.1, -1.55, ease(k, 0.3))
			arm_b.rotation = lerpf(-0.9, 0.5, k)
			lunge = lerpf(-5.0, 15.0, ease(k, 0.3))
		else:               # recover
			var k2 := (pa - 0.6) / 0.4
			arm_f.rotation = lerpf(-1.55, arm_f.rotation, ease(k2, 2.0))
			arm_b.rotation = lerpf(0.5, arm_b.rotation, k2)
			lunge = lerpf(15.0, 0.0, k2)
	if gown:
		gown.rotation = -amp * 0.06 - sitk * 0.1
	# knocked flat
	var e := ease(fall, 0.4)
	body.rotation = -PI / 2.0 * e * dir
	body.position.y = -e * 14.0
	body.position.x = lunge * dir
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
	if kind == "player":
		z_index = 11 if state == "floor" else 2   # on the floor Pip is in front of the desks, not behind
	if kind == "player" and falling:
		modulate.a = 0.55 + 0.45 * absf(sin(now * 12.0))
	else:
		modulate.a = 1.0


func head_top() -> float:
	if state == "down":
		return wy - 46.0
	if state == "floor":
		return wy - height_px * 0.55
	if state == "sit":
		return wy - height_px + float(r["shin"]) * 0.6 * float(r["scale"])
	return wy - height_px
