extends Node2D
## Game controller: states, spawning, collisions, scoring, level flow.

const W = preload("res://scripts/world.gd")
const Gfx = preload("res://scripts/gfx.gd")
const Background = preload("res://scripts/background.gd")
const Player = preload("res://scripts/player.gd")
const Rocket = preload("res://scripts/rocket.gd")
const Alien = preload("res://scripts/alien.gd")
const Laser = preload("res://scripts/laser.gd")
const Item = preload("res://scripts/item.gd")
const Explosion = preload("res://scripts/explosion.gd")
const FloatText = preload("res://scripts/float_text.gd")
const Hud = preload("res://scripts/hud.gd")

const SAVE_PATH := "user://thrustbound.save"
const START_LIVES := 4
const ALIEN_SCORES := [25, 50, 80, 100, 60, 70, 90, 110, 120, 90, 150]
const ALIEN_NAMES := ["Ember meteors", "Jelly bouncers", "Scout saucers", "Seeker orbs", "Drift mines", "Dart comets", "Zigzag wasps",
		"Phase ghosts", "Dive hawks", "Ricochet shards", "Hunter drones"]
const ALIEN_COLORS := [Color(2.4, 0.9, 0.3), Color(0.4, 2.2, 0.8), Color(0.4, 1.4, 2.6), Color(2.4, 0.4, 2.0),
		Color(2.6, 0.3, 0.3), Color(2.6, 2.4, 0.6), Color(2.6, 1.6, 0.2), Color(1.6, 2.2, 2.4), Color(0.3, 2.4, 1.6),
		Color(0.8, 1.8, 2.8), Color(2.6, 0.5, 1.0)]
const LASER_COLORS := [Color(2.4, 0.4, 1.8), Color(0.4, 2.2, 2.4), Color(2.4, 2.0, 0.4), Color(0.6, 2.4, 0.6)]
const GEM_COLORS := [Color(0.5, 2.4, 2.6), Color(2.6, 0.6, 1.6), Color(2.6, 2.2, 0.5), Color(0.8, 2.6, 0.8)]

var cam: Camera2D
var world: Node2D
var rocket
var player
var hud
var aliens: Array = []
var lasers: Array = []
var items: Array = []

var state := "title"
var paused := false
var level := 1
var score := 0
var hiscore := 0
var lives := START_LIVES
var next_life_at := 10000
var spawn_timer := 1.5
var fuel_timer := 2.0
var gem_timer := 12.0
var state_timer := 0.0
var pending_new_model := false
var laser_i := 0
var shake := 0.0
var rng := RandomNumberGenerator.new()

# --selftest: drive the game automatically (used for headless verification)
var selftest := false
var test_t := 0.0


func _ready() -> void:
	rng.randomize()
	selftest = "--selftest" in OS.get_cmdline_user_args()
	_setup_input()
	_load_hiscore()
	_setup_environment()

	cam = Camera2D.new()
	cam.position = Vector2(W.WIDTH, W.HEIGHT) * 0.5
	add_child(cam)
	cam.make_current()

	add_child(Background.new())
	world = Node2D.new()
	add_child(world)
	rocket = Rocket.new()
	world.add_child(rocket)
	rocket.reset(0, 3)
	var bad: Array = W.check_layouts()
	if ALIEN_NAMES.size() < W.LAYOUTS.size() or ALIEN_SCORES.size() != ALIEN_NAMES.size() or ALIEN_COLORS.size() != ALIEN_NAMES.size():
		bad.append("every level layout needs its own enemy kind, with a score and a colour")
	if not bad.is_empty():
		push_error("level layouts: " + "; ".join(bad))
		if selftest:
			get_tree().quit(1)
	player = Player.new()
	player.fired.connect(_on_player_fired)
	world.add_child(player)
	player.visible = false

	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	_sync_hud()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.background_canvas_max_layer = 11
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_strength = 1.0
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.set_glow_level(0, 0.0)
	env.set_glow_level(1, 0.7)
	env.set_glow_level(2, 1.0)
	env.set_glow_level(3, 0.8)
	env.set_glow_level(4, 0.5)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


# ---------------------------------------------------------------- input

func _setup_input() -> void:
	_keys("left", [KEY_A, KEY_LEFT])
	_keys("right", [KEY_D, KEY_RIGHT])
	_keys("thrust", [KEY_W, KEY_UP])
	_keys("fire", [KEY_SPACE, KEY_J, KEY_CTRL])
	_keys("start", [KEY_ENTER, KEY_KP_ENTER])
	_keys("pause", [KEY_ESCAPE, KEY_P])
	_joy_axis("left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("right", JOY_AXIS_LEFT_X, 1.0)
	_joy_btn("left", JOY_BUTTON_DPAD_LEFT)
	_joy_btn("right", JOY_BUTTON_DPAD_RIGHT)
	_joy_btn("thrust", JOY_BUTTON_A)
	_joy_btn("fire", JOY_BUTTON_X)
	_joy_btn("fire", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_btn("start", JOY_BUTTON_START)
	_joy_btn("pause", JOY_BUTTON_BACK)


func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)


func _keys(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _joy_btn(action: String, b: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = b
	InputMap.action_add_event(action, ev)


func _joy_axis(action: String, axis: JoyAxis, v: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = v
	InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- main loop

func _process(delta: float) -> void:
	delta = minf(delta, 1.0 / 30.0)
	if selftest:
		_selftest_drive(delta)
	if Input.is_action_just_pressed("pause") and state in ["playing", "dying", "launch", "land"]:
		paused = not paused
		Sfx.set_thrust(false)
	if paused:
		_sync_hud()
		return
	match state:
		"title":
			if Input.is_action_just_pressed("start") or Input.is_action_just_pressed("fire"):
				_start_game()
		"playing":
			_update_playing(delta)
		"dying":
			_update_dying(delta)
		"launch":
			_update_launch(delta)
		"land":
			_update_land(delta)
		"gameover":
			state_timer -= delta
			_update_aliens(delta)
			if state_timer <= 0.0 and (Input.is_action_just_pressed("start") or Input.is_action_just_pressed("fire")):
				_clear_world()
				W.use_level(1)
				rocket.reset(0, 3)
				state = "title"
	hud.tick(delta)
	shake = maxf(0.0, shake - delta * 1.8)
	cam.offset = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * shake * shake * 16.0
	_sync_hud()


func _sync_hud() -> void:
	hud.score = score
	hud.hiscore = maxi(hiscore, score)
	hud.lives = lives
	hud.level = level
	hud.fuel = rocket.fuel
	hud.fuel_needed = W.FUEL_NEEDED
	hud.segments = rocket.segments
	hud.state = state
	hud.paused = paused


# ---------------------------------------------------------------- game flow

func _start_game() -> void:
	score = 0
	lives = START_LIVES
	level = 1
	W.use_level(level)
	next_life_at = 10000
	paused = false
	_clear_world()
	rocket.reset(0, 1)
	_place_parts()
	_spawn_player()
	state = "playing"
	spawn_timer = 2.0
	fuel_timer = 1.5
	gem_timer = rng.randf_range(10.0, 18.0)
	hud.show_message("LEVEL 1", "Find the rocket parts and stack them on the pad")
	Sfx.play("start")


func _clear_world() -> void:
	for a in aliens:
		a.queue_free()
	for l in lasers:
		l.queue_free()
	for i in items:
		i.queue_free()
	aliens.clear()
	lasers.clear()
	items.clear()
	player.carrying = null
	player.alive = false
	player.visible = false
	Sfx.set_thrust(false)


func _clear_items() -> void:
	for i in items:
		i.queue_free()
	items.clear()


func _place_parts() -> void:
	var spots := W.part_spots()
	for idx in [1, 2]:
		var it = Item.new()
		it.setup_part(idx, rocket.model)
		var r: Rect2 = spots[idx - 1]
		it.position = Vector2(r.get_center().x + rng.randf_range(-40, 40), r.position.y - 27.0)
		it.state = "rest"
		world.add_child(it)
		items.append(it)
		_explode(it.position, Color(0.5, 1.6, 2.4), 0.6, false)


func _spawn_player() -> void:
	player.reset(Vector2(W.start_x(), W.GROUND_Y - player.HALF.y))


func _update_playing(delta: float) -> void:
	player.step(delta)
	Sfx.set_thrust(player.thrusting)
	_update_lasers(delta)
	_update_aliens(delta)
	_check_player_hits()
	if state != "playing":
		return
	_update_items(delta)
	_handle_pickups()
	_spawn_logic(delta)
	_check_launch()


func _update_dying(delta: float) -> void:
	state_timer -= delta
	_update_lasers(delta)
	_update_items(delta)
	if state_timer < 1.7:
		for a in aliens:
			if not a.dead:
				_kill_alien(a, false)
	_update_aliens(delta)
	if state_timer <= 0.0:
		if lives > 0:
			_spawn_player()
			state = "playing"
			spawn_timer = 1.5
		else:
			state = "gameover"
			state_timer = 1.2
			_save_hiscore()


func _check_launch() -> void:
	if rocket.is_ready() and player.alive and W.overlap(player.rect(), rocket.rect()):
		_start_launch()


func _start_launch() -> void:
	state = "launch"
	state_timer = 0.0
	player.alive = false
	player.visible = false
	player.carrying = null
	Sfx.set_thrust(false)
	Sfx.play("launch")
	for a in aliens:
		if not a.dead:
			_kill_alien(a, false)
	for l in lasers:
		l.queue_free()
	lasers.clear()
	rocket.set_flame(true)
	hud.show_message("LIFT-OFF!", "", 1.6)
	var bonus := 500 * level
	_add_score(bonus, rocket.position + Vector2(0, -200), "LAUNCH +%d" % bonus)


func _update_launch(delta: float) -> void:
	state_timer += delta
	_update_aliens(delta)
	_update_items(delta)
	if state_timer < 0.7:
		shake = maxf(shake, 0.45)
		return
	var tt := state_timer - 0.7
	rocket.position.y -= (30.0 + tt * tt * 320.0) * delta
	shake = maxf(shake, clampf(0.6 - tt * 0.3, 0.0, 0.6))
	if rocket.position.y < -260.0:
		_next_level()


func _next_level() -> void:
	level += 1
	W.use_level(level)
	pending_new_model = (level - 1) % 4 == 0
	rocket.fuel = 0
	rocket.position = Vector2(W.pad_x(), -260.0)
	_clear_items()
	state = "land"
	state_timer = 0.0
	var k: int = _alien_kind()
	hud.show_message("LEVEL %d" % level, "%s incoming" % ALIEN_NAMES[k], 3.0)


func _update_land(delta: float) -> void:
	var target := W.ROCKET_BASE_Y
	var dist: float = target - rocket.position.y
	var speed := maxf(70.0, dist * 1.7)
	rocket.position.y = minf(target, rocket.position.y + speed * delta)
	if rocket.position.y >= target - 0.5:
		rocket.position.y = target
		rocket.set_flame(false)
		Sfx.play("clunk")
		shake = 0.35
		if pending_new_model:
			rocket.reset(rocket.model + 1, 1)
			_place_parts()
			hud.show_message("NEW ROCKET", "The old one is scrap. Build the next model!", 3.0)
		player.reset(Vector2(W.start_x(), W.GROUND_Y - player.HALF.y))
		state = "playing"
		spawn_timer = 2.0
		fuel_timer = 1.0


# ---------------------------------------------------------------- entities

func _on_player_fired(pos: Vector2, dir: int) -> void:
	if lasers.size() >= 5:
		return
	var l = Laser.new()
	l.setup(pos, dir, LASER_COLORS[laser_i % LASER_COLORS.size()])
	laser_i += 1
	world.add_child(l)
	lasers.append(l)
	Sfx.play("laser", -4.0, 0.08)


func _update_lasers(delta: float) -> void:
	for l in lasers.duplicate():
		l.step(delta)
		if not l.dead:
			for a in aliens:
				if not a.dead and l.hits(a.rect()):
					_kill_alien(a, true)
					l.dead = true
					break
		if l.dead:
			lasers.erase(l)
			l.queue_free()


func _update_aliens(delta: float) -> void:
	var target: Vector2 = player.position if player.alive else Vector2(640, 300)
	for a in aliens:
		if a.dead:
			continue
		a.step(delta, target)
		if a.kind == 0 and a.hit_solid:
			_kill_alien(a, false)
	var keep: Array = []
	for a in aliens:
		if a.dead:
			a.queue_free()
		else:
			keep.append(a)
	aliens = keep


func _kill_alien(a, scored: bool) -> void:
	a.dead = true
	_explode(a.position, ALIEN_COLORS[a.kind], 0.9 if scored else 0.7)
	if scored:
		var pts: int = ALIEN_SCORES[a.kind]
		_add_score(pts, a.position + Vector2(0, -20))


func _check_player_hits() -> void:
	if not player.alive or player.invuln > 0.0:
		return
	var pr: Rect2 = player.hit_rect()
	for a in aliens:
		if not a.dead and W.overlap(pr, a.rect()):
			_kill_player(a)
			return


func _kill_player(a) -> void:
	_kill_alien(a, false)
	_explode(player.position, Color(2.4, 1.4, 0.5), 1.7)
	shake = 0.9
	Sfx.play("death")
	Sfx.set_thrust(false)
	player.alive = false
	player.visible = false
	player.flame.emitting = false
	if player.carrying != null:
		var it = player.carrying
		it.carrier = null
		it.state = "fall"
		it.vel_y = 0.0
		player.carrying = null
	lives -= 1
	state = "dying"
	state_timer = 2.2


func _update_items(delta: float) -> void:
	for it in items.duplicate():
		it.step(delta)
		if it.state == "landed_rocket":
			_deliver(it)


func _deliver(it) -> void:
	if it.kind == Item.PART:
		rocket.segments = maxi(rocket.segments, it.part_index + 1)
		Sfx.play("clunk")
		shake = 0.3
		_explode(it.position, Color(0.5, 1.6, 2.4), 0.5, false)
		if rocket.segments >= 3:
			hud.show_message("ROCKET ASSEMBLED", "Now collect %d fuel pods" % W.FUEL_NEEDED)
	else:
		rocket.fuel += 1
		Sfx.play("fuel")
		_explode(Vector2(rocket.position.x, rocket.top_y() + 10), Color(1.6, 0.4, 2.4), 0.5, false)
		if rocket.fuel >= W.FUEL_NEEDED:
			hud.show_message("FULLY FUELLED", "Board the rocket to launch!")
			Sfx.play("ready")
	_add_score(100, it.position + Vector2(0, -30))
	items.erase(it)
	it.queue_free()


func _handle_pickups() -> void:
	if not player.alive:
		return
	var pr: Rect2 = player.rect()
	# crystals are always collectable
	for it in items.duplicate():
		if it.kind == Item.GEM and it.state in ["fall", "rest"] and W.overlap(pr, it.rect()):
			_add_score(250 * mini(level, 4), it.position + Vector2(0, -20))
			Sfx.play("gem")
			_explode(it.position, it.gem_color, 0.5, false)
			items.erase(it)
			it.queue_free()
	if player.carrying == null:
		for it in items:
			if not (it.state in ["fall", "rest"]):
				continue
			if it.kind == Item.PART and it.part_index != rocket.segments:
				continue
			if it.kind == Item.FUEL and rocket.segments < 3:
				continue
			if it.kind == Item.GEM:
				continue
			if W.overlap(pr, it.rect()):
				player.carrying = it
				it.carrier = player
				it.state = "carried"
				Sfx.play("pickup")
				break
	else:
		var it = player.carrying
		var ty: float = it.drop_target_y(rocket)
		if absf(W.wrap_dx(it.position.x, rocket.position.x)) < 20.0 and it.position.y < ty - 4.0:
			player.carrying = null
			it.start_drop(rocket.position.x, ty)


func _spawn_logic(delta: float) -> void:
	spawn_timer -= delta
	var max_aliens := mini(3 + level, 9)
	if spawn_timer <= 0.0 and aliens.size() < max_aliens:
		_spawn_alien()
		spawn_timer = rng.randf_range(0.5, 1.3) / (1.0 + 0.05 * float(level))
	if rocket.segments >= 3 and rocket.fuel < W.FUEL_NEEDED:
		var has_fuel := false
		for it in items:
			if it.kind == Item.FUEL:
				has_fuel = true
		if not has_fuel:
			fuel_timer -= delta
			if fuel_timer <= 0.0:
				var f = Item.new()
				f.setup_fuel()
				_drop_from_sky(f)
				fuel_timer = rng.randf_range(1.0, 2.5)
	gem_timer -= delta
	if gem_timer <= 0.0:
		gem_timer = rng.randf_range(14.0, 24.0)
		var g = Item.new()
		g.setup_gem(GEM_COLORS[rng.randi() % GEM_COLORS.size()])
		_drop_from_sky(g)


func _drop_from_sky(it) -> void:
	var x := rng.randf_range(60.0, W.WIDTH - 60.0)
	for i in 10:
		if absf(x - W.pad_x()) > 80.0:
			break
		x = rng.randf_range(60.0, W.WIDTH - 60.0)
	it.position = Vector2(x, -30.0)
	it.state = "fall"
	world.add_child(it)
	items.append(it)


## Every level layout has its own enemy, so no two levels in a cycle share one.
func _alien_kind() -> int:
	return (level - 1) % ALIEN_NAMES.size()


func _spawn_alien() -> void:
	var kind := _alien_kind()
	var a = Alien.new()
	var from_left := rng.randf() < 0.5
	var pos := Vector2(1.0 if from_left else W.WIDTH - 1.0, 300.0)
	for i in 12:
		pos.y = rng.randf_range(W.CEILING_Y + 30.0, W.GROUND_Y - 40.0)
		if not W.hits_solid(Rect2(pos - Vector2(22, 22), Vector2(44, 44))):
			break
	a.setup(kind, pos, 1 if from_left else -1, level, rng)
	world.add_child(a)
	aliens.append(a)


# ---------------------------------------------------------------- fx & score

func _explode(pos: Vector2, color: Color, size: float, loud: bool = true) -> void:
	var e = Explosion.new()
	e.setup(pos, color, size)
	world.add_child(e)
	if loud:
		Sfx.play("explode", -2.0 if size > 1.0 else -6.0, 0.15)
		shake = maxf(shake, 0.25 * size)


func _add_score(n: int, pos: Vector2, label: String = "") -> void:
	score += n
	var ft = FloatText.new()
	ft.setup(label if label != "" else "+%d" % n, pos, Color(1.0, 0.95, 0.7))
	world.add_child(ft)
	if score >= next_life_at:
		next_life_at += 10000
		lives += 1
		hud.show_message("EXTRA LIFE", "", 1.8)
		Sfx.play("oneup")


func _load_hiscore() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			hiscore = f.get_32()


func _save_hiscore() -> void:
	if score > hiscore:
		hiscore = score
		var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_32(hiscore)


# ---------------------------------------------------------------- self test

func _selftest_drive(delta: float) -> void:
	test_t += delta
	var phase := int(test_t)
	if state == "title" and test_t > 0.5:
		Input.action_press("start")
	else:
		Input.action_release("start")
	if state == "playing":
		# wander, thrust in pulses and fire constantly
		var dir := "right" if (phase / 3) % 2 == 0 else "left"
		Input.action_release("left")
		Input.action_release("right")
		Input.action_press(dir)
		if fmod(test_t, 1.6) < 0.7:
			Input.action_press("thrust")
		else:
			Input.action_release("thrust")
		Input.action_press("fire")
		player.invuln = 1.0
		# fast-forward rocket progress to exercise every system
		if test_t > 4.0 and rocket.segments < 3:
			for it in items:
				if it.kind == Item.PART and it.state == "rest" and it.part_index == rocket.segments:
					it.position = Vector2(rocket.position.x, 100.0)
					it.start_drop(rocket.position.x, it.drop_target_y(rocket))
					break
		if test_t > 8.0 and rocket.segments >= 3 and rocket.fuel < W.FUEL_NEEDED:
			rocket.fuel = W.FUEL_NEEDED - 1
			for it in items:
				if it.kind == Item.FUEL and it.state != "drop":
					it.position = Vector2(rocket.position.x, 100.0)
					it.start_drop(rocket.position.x, it.drop_target_y(rocket))
		if rocket.is_ready() and test_t > 10.0:
			player.position = rocket.position + Vector2(0, -60)
	if test_t > 18.0 and test_t < 18.1 and player.alive:
		player.invuln = 0.0
		_kill_player_test()
	for st in [0.3, 2.6, 3.5, 7.5, 9.5, 11.2, 12.2, 18.3]:
		if test_t - delta < st and test_t >= st and OS.has_environment("THRUST_SHOTS"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(OS.get_environment("THRUST_SHOTS") + "/shot_%05.1f.png" % st)
	if test_t > 2.0 and test_t < 2.1 and aliens.size() < 20:
		for k in ALIEN_NAMES.size():
			var sa = Alien.new()
			sa.setup(k, Vector2(200.0 + 80.0 * k, 160.0), 1, 12, rng)
			world.add_child(sa)
			aliens.append(sa)
	if test_t > 26.0:
		print("SELFTEST OK level=", level, " score=", score, " state=", state, " aliens=", aliens.size())
		get_tree().quit()


func _kill_player_test() -> void:
	var a = Alien.new()
	a.setup(1, player.position, 1, level, rng)
	world.add_child(a)
	aliens.append(a)
	_kill_player(a)
