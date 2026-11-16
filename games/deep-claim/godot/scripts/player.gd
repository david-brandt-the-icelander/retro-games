class_name Player
extends CharacterBody2D
## The miner: a space-suited astronaut with an oxygen supply and a jetpack.
## Tap jump to hop; keep holding (or press again in mid-air) to fire the jetpack.

signal jumped
signal landed(impact: float)
signal jet_changed(on: bool)

const SPEED := 215.0
const ACCEL := 2000.0
const AIR_ACCEL := 1400.0
const GRAVITY := 1300.0
const JUMP_V := 560.0
const MAX_FALL := 800.0
const JET_ACCEL := 2700.0
const JET_MAX_UP := 250.0
const JET_DELAY := 0.22
const FUEL_RATE := 0.26        # full tank = ~3.8 s of thrust
const COYOTE := 0.09
const BUFFER := 0.12
const HALF := Vector2(9, 15)

var level: Level
var oxygen := 1.0
var fuel := 1.0
var vx := 0.0
var coyote := 0.0
var buffer := 0.0
var since_jump := 99.0
var jet_armed := false
var jetting := false
var facing := 1.0
var alive := true
var frozen := false
var in_buggy := false
var walk_t := 0.0
var squash := Vector2.ONE
var _was_floor := true
var _fall_speed := 0.0
var _shape: CollisionShape2D
var lamp: PointLight2D
var flame: CPUParticles2D
var flame_light: PointLight2D


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 | 8
	var shape := RectangleShape2D.new()
	shape.size = HALF * 2.0
	_shape = CollisionShape2D.new()
	_shape.shape = shape
	add_child(_shape)
	floor_snap_length = 6.0
	lamp = Fx.make_light(Color(0.85, 0.92, 1.0), 1.0, 1.6)
	add_child(lamp)
	flame = CPUParticles2D.new()
	flame.amount = 40
	flame.lifetime = 0.35
	flame.local_coords = false
	flame.emitting = false
	flame.direction = Vector2(0, 1)
	flame.spread = 14.0
	flame.initial_velocity_min = 140.0
	flame.initial_velocity_max = 220.0
	flame.gravity = Vector2.ZERO
	flame.scale_amount_min = 2.0
	flame.scale_amount_max = 4.5
	var ramp := Gradient.new()
	ramp.set_color(0, Color(4.0, 3.0, 1.4, 1.0))
	ramp.set_color(1, Color(1.5, 0.3, 0.1, 0.0))
	flame.color_ramp = ramp
	add_child(flame)
	flame_light = Fx.make_light(Color(1.0, 0.6, 0.25), 0.0, 0.9)
	add_child(flame_light)


func rect() -> Rect2:
	return Rect2(global_position - HALF, HALF * 2.0)


func set_in_buggy(on: bool) -> void:
	in_buggy = on
	visible = not on
	_shape.set_deferred("disabled", on)
	velocity = Vector2.ZERO
	vx = 0.0
	_set_jet(false)


func _set_jet(on: bool) -> void:
	if on != jetting:
		jetting = on
		flame.emitting = on
		jet_changed.emit(on)


func _physics_process(delta: float) -> void:
	if in_buggy or not alive or frozen:
		_set_jet(false)
		queue_redraw()
		return
	var dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()
	coyote = COYOTE if on_floor else coyote - delta
	buffer = BUFFER if Input.is_action_just_pressed("jump") else buffer - delta
	since_jump += delta
	if on_floor or not Input.is_action_pressed("jump"):
		jet_armed = false
	vx = move_toward(vx, dir * SPEED, (ACCEL if on_floor else AIR_ACCEL) * delta)
	if dir != 0.0:
		facing = signf(dir)

	if buffer > 0.0 and coyote > 0.0:
		velocity.y = -JUMP_V
		buffer = 0.0
		coyote = 0.0
		since_jump = 0.0
		squash = Vector2(0.75, 1.3)
		jumped.emit()
	elif Input.is_action_just_pressed("jump") and not on_floor:
		jet_armed = true

	var want_jet := not on_floor and Input.is_action_pressed("jump") and fuel > 0.0 \
			and (jet_armed or since_jump > JET_DELAY)
	_set_jet(want_jet)
	if jetting:
		fuel = maxf(0.0, fuel - FUEL_RATE * delta)
		velocity.y = maxf(velocity.y - (JET_ACCEL - GRAVITY) * delta, -JET_MAX_UP)
	else:
		velocity.y = minf(velocity.y + GRAVITY * delta, MAX_FALL)
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			velocity.y += GRAVITY * 1.2 * delta

	var conv: float = level.conveyor_under(self) if on_floor else 0.0
	velocity.x = vx + conv
	_fall_speed = velocity.y
	move_and_slide()
	if is_on_wall() and signf(vx) == -signf(get_wall_normal().x):
		vx = 0.0
	var now_floor := is_on_floor()
	if now_floor and not _was_floor:
		var impact := clampf(_fall_speed / MAX_FALL, 0.0, 1.0)
		squash = Vector2(1.0 + 0.4 * impact, 1.0 - 0.3 * impact)
		landed.emit(impact)
	_was_floor = now_floor
	if now_floor:
		level.stand_on(self, delta)
		if absf(vx) > 10.0:
			walk_t += delta * absf(vx) / 15.0
	squash = squash.lerp(Vector2.ONE, 1.0 - exp(-14.0 * delta))
	lamp.position = Vector2(8.0 * facing, -9.0)
	flame.position = Vector2(-11.0 * facing, 8.0)
	flame_light.position = flame.position + Vector2(0, 10)
	flame_light.energy = 1.4 if jetting else 0.0
	queue_redraw()


func _draw() -> void:
	if not alive or in_buggy:
		return
	var airborne := not is_on_floor()
	draw_set_transform(Vector2(0, HALF.y * (1.0 - squash.y)), 0.0, Vector2(squash.x * facing, squash.y))
	var ink := Color(0.03, 0.03, 0.06)
	var suit := Color(0.9, 0.91, 0.94)
	var suit_shade := Color(0.62, 0.65, 0.72)
	var accent := Color(1.0, 0.45, 0.12)
	var pack := Color(0.36, 0.39, 0.46)
	# jetpack with twin nozzles and an oxygen bottle
	draw_rect(Rect2(-16, -6, 9, 15), ink)
	draw_rect(Rect2(-15, -5, 7, 13), pack)
	draw_rect(Rect2(-15, 7, 3, 3), Color(0.2, 0.2, 0.24))
	draw_rect(Rect2(-11, 7, 3, 3), Color(0.2, 0.2, 0.24))
	draw_rect(Rect2(-14, -3, 5, 2), Color(0.3, 2.0, 2.4) * clampf(oxygen + 0.2, 0.2, 1.0))
	# legs and boots
	var stride := sin(walk_t) * 3.0 if not airborne else 0.0
	var tuck := -2.0 if airborne else 0.0
	draw_rect(Rect2(-7, 6 + tuck - maxf(stride, 0.0), 6, 9), ink)
	draw_rect(Rect2(1, 6 + tuck - maxf(-stride, 0.0), 6, 9), ink)
	draw_rect(Rect2(-6, 7 + tuck - maxf(stride, 0.0), 4, 5), suit_shade)
	draw_rect(Rect2(2, 7 + tuck - maxf(-stride, 0.0), 4, 5), suit_shade)
	draw_rect(Rect2(-6, 11 + tuck - maxf(stride, 0.0), 4, 3), Color(0.25, 0.26, 0.3))
	draw_rect(Rect2(2, 11 + tuck - maxf(-stride, 0.0), 4, 3), Color(0.25, 0.26, 0.3))
	# torso
	draw_rect(Rect2(-9, -4, 17, 12), ink)
	draw_rect(Rect2(-8, -3, 15, 10), suit)
	draw_rect(Rect2(-8, 3, 15, 2), accent)
	draw_rect(Rect2(1, -1, 4, 3), Color(0.3, 0.8, 0.4))
	# arm
	var swing := sin(walk_t) * 2.0 if not airborne else -3.0
	draw_rect(Rect2(3 + swing * 0.3, -2, 6, 8), ink)
	draw_rect(Rect2(4 + swing * 0.3, -1, 4, 6), suit_shade)
	# helmet with gold visor
	draw_circle(Vector2(1, -10), 9.5, ink)
	draw_circle(Vector2(1, -10), 8.2, suit)
	var visor := PackedVector2Array([Vector2(1, -16), Vector2(7, -15), Vector2(9, -10), Vector2(7, -5), Vector2(1, -5)])
	draw_colored_polygon(visor, Color(0.95, 0.68, 0.18))
	draw_line(Vector2(4, -14), Vector2(7, -12), Color(2.4, 2.2, 1.6), 1.5)
	draw_circle(Vector2(-3, -15), 1.6, Color(3.0, 3.0, 3.4))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
