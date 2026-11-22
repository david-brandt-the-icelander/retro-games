extends Node3D
## Root scene: environment, menu, and the in-game controller (selection,
## orders, turn button, hotkeys).

var menu: Menu
var view: WorldView
var camera: CameraRig
var hud: Hud
var game: Game
var pid = 0

var sel_unit = -1
var sel_city = -1
var hover = Vector2i(-1, -1)
var _hud_dirty = true
var _auto_next_at = -1.0
var _press_pos = Vector2.ZERO
var _autotest_turns = 0

func _ready() -> void:
	_setup_environment()
	menu = Menu.new()
	add_child(menu)
	Net.game_started.connect(_on_game_started)
	Net.disconnected.connect(_teardown)
	_handle_cli()

func _setup_environment() -> void:
	var env = Environment.new()
	var sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("2d5f9a")
	sky_mat.sky_horizon_color = Color("a9c6dc")
	sky_mat.ground_horizon_color = Color("a9c6dc")
	sky_mat.ground_bottom_color = Color("1b2430")
	sky_mat.sun_angle_max = 20.0
	var sky = Sky.new()
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("d8dde3")
	env.ambient_light_energy = 0.55
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.1
	# The web build runs on the Compatibility renderer (WebGL 2), which has no SSAO.
	var compat = RenderingServer.get_current_rendering_method() == "gl_compatibility"
	env.ssao_enabled = not compat
	env.ssao_radius = 0.8
	env.ssao_intensity = 1.6
	env.fog_enabled = true
	env.fog_light_color = Color("9db7cc")
	env.fog_density = 0.0022
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.05
	if compat:
		# The Compatibility renderer comes out brighter and more saturated: tone it down to match.
		env.tonemap_exposure = 0.9
		env.adjustment_saturation = 1.0
	var we = WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.directional_shadow_max_distance = 60.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	add_child(sun)

# ================================================================ lifecycle

func _on_game_started() -> void:
	_teardown_world()
	game = Net.game
	pid = Net.local_pid
	add_child(game)
	view = WorldView.new()
	view.name = "World"
	add_child(view)
	view.setup(game, pid)
	camera = CameraRig.new()
	add_child(camera)
	var far = Hex.to_world(Vector2i(game.w - 1, game.h - 1))
	camera.bounds = Rect2(0, 0, far.x, far.z)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self, game, pid)
	menu.visible = false
	game.event_applied.connect(_on_event)
	if _autotest_turns > 0:
		game.event_applied.connect(func(ev):
			if ev.t == "new_turn":
				print("SYNC %d %d" % [game.turn, game.checksum()]))
	game.game_over.connect(func(w, k): hud.show_game_over(w, k))
	var first = _my_units()
	if not first.is_empty():
		camera.look_at_tile(first[0].pos, true)
		select_unit(first[0].id)
	_hud_dirty = true

func _teardown_world() -> void:
	for n in [view, camera, hud, game]:
		if is_instance_valid(n):
			n.queue_free()
	view = null
	camera = null
	hud = null
	game = null
	sel_unit = -1
	sel_city = -1

func _teardown() -> void:
	_teardown_world()
	menu.show_home()

func leave_game() -> void:
	Net.leave()
	_teardown()

# ================================================================ events

func _on_event(ev: Dictionary) -> void:
	_hud_dirty = true
	if sel_unit >= 0 and not game.units.has(sel_unit):
		sel_unit = -1
		view.set_selection(Vector2i(-1, -1))
		view.clear_reach()
		view.clear_path()
	if sel_city >= 0 and (not game.cities.has(sel_city)):
		sel_city = -1
	if ev.t == "new_turn":
		_auto_next_at = Time.get_ticks_msec() / 1000.0 + 0.4
		return
	var mine_unit: bool = ev.has("u") and game.units.has(ev.u) and game.units[ev.u].owner == pid
	if mine_unit and ev.u == sel_unit and ev.t in ["move", "attack", "fortify", "sleep", "skip", "improve"]:
		var u = game.units[ev.u]
		if not u.needs_orders():
			_auto_next_at = Time.get_ticks_msec() / 1000.0 + 0.45
	if ev.t == "found" and _ev_owner_was_me(ev):
		_auto_next_at = Time.get_ticks_msec() / 1000.0 + 0.3
		for c in game.player_cities(pid):
			if c.pos == _last_settler_pos:
				select_city(c.id)

var _last_settler_pos = Vector2i(-1, -1)

func _ev_owner_was_me(ev: Dictionary) -> bool:
	var c = game.city_at.get(_last_settler_pos)
	return c != null and c.owner == pid

func _process(_delta: float) -> void:
	if game == null:
		return
	if _autotest_turns > 0:
		_autotest_step()
	if _shot_turns > 0:
		_shot_step()
	if _auto_next_at > 0 and Time.get_ticks_msec() / 1000.0 >= _auto_next_at:
		_auto_next_at = -1.0
		var u = game.units.get(sel_unit)
		if u == null or not u.needs_orders() or u.owner != pid:
			select_next(false)
	if _hud_dirty:
		_hud_dirty = false
		hud.refresh()
		hud.update_minimap(view)
		_refresh_selection_panels()
		_update_end_button()

func _refresh_selection_panels() -> void:
	if sel_unit >= 0 and game.units.has(sel_unit):
		var u = game.units[sel_unit]
		hud.show_unit(u)
		view.set_selection(u.pos)
		if u.owner == pid:
			_show_reach(u)
	elif sel_city >= 0 and game.cities.has(sel_city):
		hud.show_city(game.cities[sel_city])
		view.set_selection(game.cities[sel_city].pos)
	else:
		hud.show_unit(null)
		hud.show_city(null)
		view.set_selection(Vector2i(-1, -1))

# ================================================================ selection

func _my_units() -> Array:
	var out = []
	for u in game.units.values():
		if u.owner == pid:
			out.append(u)
	return out

func select_unit(id: int) -> void:
	sel_unit = id
	sel_city = -1
	view.clear_path()
	var u = game.units.get(id)
	if u == null:
		return
	hud.show_unit(u)
	view.set_selection(u.pos)
	if u.owner == pid:
		_show_reach(u)
	else:
		view.clear_reach()

func select_city(id: int) -> void:
	sel_city = id
	sel_unit = -1
	view.clear_reach()
	view.clear_path()
	var c = game.cities.get(id)
	if c == null:
		return
	hud.show_city(c)
	view.set_selection(c.pos)

func deselect() -> void:
	sel_unit = -1
	sel_city = -1
	view.clear_reach()
	view.clear_path()
	view.set_selection(Vector2i(-1, -1))
	hud.show_unit(null)
	hud.show_city(null)

func _show_reach(u) -> void:
	if u.moves <= 0:
		view.clear_reach()
		return
	var reach = game.reachable(u)
	var targets = []
	if not u.is_civilian() and not u.attacked:
		var r: int = u.def().range if u.is_ranged() else 1
		for t in game.within(u.pos, r):
			if game.can_attack(u, t) and view.is_visible_tile(t):
				targets.append(t)
	view.show_reach(reach, targets)

func select_next(center = true) -> bool:
	var best = null
	var bd = 99999
	var ref: Vector2i = Vector2i(-1, -1)
	if sel_unit >= 0 and game.units.has(sel_unit):
		ref = game.units[sel_unit].pos
	for u in _my_units():
		if not u.needs_orders() or u.id == sel_unit:
			continue
		var d = Hex.distance(u.pos, ref) if ref.x >= 0 else u.id
		if d < bd:
			bd = d
			best = u
	if best == null:
		return false
	select_unit(best.id)
	camera.look_at_tile(best.pos)
	return true

func _select_at(t: Vector2i) -> void:
	if not game.in_bounds(t) or not view.is_explored(t):
		deselect()
		return
	var here = game.units_at(t)
	var mine = []
	for u in here:
		if u.owner == pid:
			mine.append(u)
	var city = game.city_at.get(t)
	if not mine.is_empty():
		mine.sort_custom(func(a, b): return a.is_civilian() and not b.is_civilian())
		mine.reverse()
		var idx = -1
		for i in mine.size():
			if mine[i].id == sel_unit:
				idx = i
		if idx >= 0 and idx == mine.size() - 1 and city != null and city.owner == pid:
			select_city(city.id)
			return
		select_unit(mine[(idx + 1) % mine.size()].id)
		return
	if city != null:
		select_city(city.id)
		return
	for u in here:
		if view.is_visible_tile(t):
			select_unit(u.id)
			return
	deselect()

func _order_at(t: Vector2i) -> void:
	var u = game.units.get(sel_unit)
	if u == null or u.owner != pid or not game.in_bounds(t):
		return
	if game.can_attack(u, t):
		Net.send({"t": "attack", "u": u.id, "target": t})
	elif t != u.pos:
		Net.send({"t": "move", "u": u.id, "to": t})
	view.clear_path()

# ================================================================ commands from HUD

func cmd_unit(kind: String, extra = {}) -> void:
	var u = game.units.get(sel_unit)
	if u == null or u.owner != pid:
		return
	if kind == "found":
		_last_settler_pos = u.pos
	var cmd = {"t": kind, "u": u.id}
	cmd.merge(extra)
	Net.send(cmd)
	if kind in ["skip", "fortify", "sleep", "disband", "improve"]:
		_auto_next_at = Time.get_ticks_msec() / 1000.0 + 0.25

func cmd_city(kind: String, cid: int, item = "") -> void:
	if kind == "prod":
		Net.send({"t": "prod", "c": cid, "item": item})
	elif kind == "buy":
		Net.send({"t": "buy", "c": cid})

# ================================================================ turn button

func _pending_action() -> Dictionary:
	var me = game.player(pid)
	if not me.alive or game.finished:
		return {}
	if me.research == "" and not game.available_techs(pid).is_empty():
		return {"kind": "research", "text": "Choose Research"}
	for c in game.player_cities(pid):
		if c.production == "":
			return {"kind": "city", "id": c.id, "text": "Choose Production"}
	for u in _my_units():
		if u.needs_orders():
			return {"kind": "unit", "id": u.id, "text": "Unit Needs Orders"}
	return {}

func _update_end_button() -> void:
	var me = game.player(pid)
	if not me.alive:
		hud.set_end_button("Spectating", "You have been eliminated.", true)
		return
	if game.finished:
		hud.set_end_button("Game Over", "", true)
		return
	var waiting = []
	for p in game.players:
		if p.alive and not p.is_ai() and not p.ready and p.id != pid:
			waiting.append(p.name)
	if me.ready:
		hud.set_end_button("Waiting…", "Waiting for: %s  (click to cancel)" % ", ".join(waiting), true)
		return
	var pend = _pending_action()
	if pend.is_empty():
		hud.set_end_button("End Turn", ("Others still playing: %s" % ", ".join(waiting)) if not waiting.is_empty() else "Press Enter", false)
	else:
		hud.set_end_button(pend.text, "Shift+Enter to end turn anyway", false)

func end_turn_pressed(force: bool) -> void:
	var me = game.player(pid)
	if not me.alive or game.finished:
		return
	if me.ready:
		Net.send({"t": "ready", "v": false})
		return
	var pend = _pending_action()
	if not force and not pend.is_empty():
		match pend.kind:
			"research":
				if not hud.tech_overlay.visible:
					hud.toggle_tech_tree()
			"city":
				select_city(pend.id)
				camera.look_at_tile(game.cities[pend.id].pos)
			"unit":
				select_unit(pend.id)
				camera.look_at_tile(game.units[pend.id].pos)
		return
	deselect()
	Net.send({"t": "ready", "v": true})

# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	if game == null or camera == null:
		return
	if event is InputEventMouseMotion:
		var t = camera.mouse_tile(event.position)
		if t != hover:
			hover = t
			view.set_hover(t)
			_update_hover_preview(event.position)
		else:
			hud.tooltip.position = event.position + Vector2(18, 18) if hud.tooltip.visible else hud.tooltip.position
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_press_pos = event.position
			elif event.position.distance_to(_press_pos) < 8:
				_select_at(camera.mouse_tile(event.position))
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_order_at(camera.mouse_tile(event.position))
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)

func _handle_key(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if Net.online and not event.shift_pressed and hud.chat_edit.visible and event.ctrl_pressed:
				hud.chat_edit.grab_focus()
			else:
				end_turn_pressed(event.shift_pressed)
		KEY_ESCAPE:
			if hud.tech_overlay.visible:
				hud.toggle_tech_tree()
			else:
				deselect()
		KEY_T:
			hud.toggle_tech_tree()
		KEY_F:
			cmd_unit("fortify")
		KEY_B:
			cmd_unit("found")
		KEY_SPACE:
			cmd_unit("skip")
		KEY_TAB, KEY_N:
			select_next()
		KEY_C:
			if Net.online:
				hud.chat_edit.grab_focus()
		KEY_H:
			for c in game.player_cities(pid):
				if c.capital:
					camera.look_at_tile(c.pos)

func _update_hover_preview(mouse: Vector2) -> void:
	view.clear_path()
	if not game.in_bounds(hover) or not view.is_explored(hover):
		hud.show_tooltip("", mouse)
		return
	var lines = []
	var u = game.units.get(sel_unit)
	if u != null and u.owner == pid and hover != u.pos:
		if game.can_attack(u, hover) and view.is_visible_tile(hover):
			var o = game.combat_odds(u, hover)
			var verdict = "[color=#8fe388]Decisive victory[/color]"
			var target_hp = 0
			var tc = game.city_at.get(hover)
			var tu = game.military_at(hover)
			target_hp = tc.hp if tc != null and tc.owner != pid else (tu.hp if tu else 100)
			if o.to_def >= target_hp:
				verdict = "[color=#8fe388]Likely kill[/color]"
			elif o.to_att >= u.hp:
				verdict = "[color=#ff6b5b]Likely death[/color]"
			elif o.to_def < o.to_att:
				verdict = "[color=#ffb37a]Costly attack[/color]"
			elif o.to_def < o.to_att * 1.5:
				verdict = "[color=#ffd166]Even fight[/color]"
			lines.append("[b]Attack[/b]  %s" % verdict)
			lines.append("Your strength %.1f vs %.1f" % [o.att, o.def])
			lines.append("Damage dealt ≈ %d   taken ≈ %d" % [int(o.to_def), int(o.to_att)])
		elif u.moves >= 0:
			var path = game.find_path(u, hover)
			if not path.is_empty():
				view.show_path(path, game.path_turns(u, path))
	var i = game.idx(hover)
	lines.append(hud._tile_desc(hover))
	var o: int = game.tile_owner[i]
	if o >= 0:
		lines.append("[color=#%s]%s territory[/color]" % [game.player(o).color.lightened(0.3).to_html(false), game.player(o).civ_name()])
	if view.is_visible_tile(hover):
		for x in game.units_at(hover):
			lines.append("%s %s  (%d HP)" % [game.player(x.owner).civ_name(), x.def().name, x.hp])
	hud.show_tooltip("\n".join(lines), mouse)

# ================================================================ CLI / automated tests

func _handle_cli() -> void:
	var args = OS.get_cmdline_user_args()
	if args.has("--autotest"):
		var turns = 60
		var i = args.find("--autotest")
		if i + 1 < args.size():
			turns = int(args[i + 1])
		var players = 6
		if args.has("--players"):
			players = int(args[args.find("--players") + 1])
		Net.host_offline("Observer")
		Net.lobby.humans.clear()
		Net.lobby.ai_count = players
		Net.lobby.map_size = 1 if players <= 6 else 2
		Net.auto_end_delay = 0.0
		_autotest_turns = turns
		Net.stop_at_turn = turns + 1
		Net.game_started.connect(func(): Net.game.event_applied.connect(func(ev): _ev_stats[ev.t] = _ev_stats.get(ev.t, 0) + 1))
		Net.start_game(12345)
	elif args.has("--host-test"):
		Net.host_online("HostBot", Net.DEFAULT_PORT)
		Net.lobby.ai_count = 2
		_autotest_turns = 30
		get_tree().create_timer(3.0).timeout.connect(func(): Net.start_game(777))
	elif args.has("--join-test"):
		Net.join("ClientBot", "127.0.0.1", Net.DEFAULT_PORT)
		_autotest_turns = 30
	elif args.has("--shot"):
		_shot_turns = int(args[args.find("--shot") + 1])
		_shot_dir = args[args.find("--shot") + 2]
		Net.host_offline("Observer")
		Net.lobby.humans.clear()
		Net.lobby.ai_count = 6
		Net.lobby.map_size = 1
		Net.auto_end_delay = 0.0
		Net.stop_at_turn = _shot_turns
		Net.start_game(4242)

var _shot_turns = 0
var _shot_dir = ""
var _shot_phase = 0
var _shot_wait = 0

func _shot_step() -> void:
	if _shot_phase == 0:
		if game.turn < _shot_turns and not game.finished:
			return
		_shot_phase = 1
		_shot_wait = 0
		var caps = game.player_cities(pid)
		var focus_c = caps[0] if not caps.is_empty() else null
		if focus_c != null:
			camera.look_at_tile(focus_c.pos, true)
			select_city(focus_c.id)
		camera.target_zoom = 0.3
		camera.zoom = 0.3
		return
	_shot_wait += 1
	if _shot_wait < 25:
		return
	_shot_wait = 0
	var img = get_viewport().get_texture().get_image()
	img.save_png("%s/shot_%d.png" % [_shot_dir, _shot_phase])
	print("saved shot ", _shot_phase)
	_shot_phase += 1
	match _shot_phase:
		2:
			deselect()
			camera.target_zoom = 0.85
			camera.zoom = 0.85
		3:
			camera.target_zoom = 0.06
			camera.zoom = 0.06
			camera.target_yaw = 0.6
			var us = []
			for u in game.units.values():
				if u.owner == pid and not u.is_civilian():
					us.append(u)
			if not us.is_empty():
				camera.look_at_tile(us[0].pos, true)
				select_unit(us[0].id)
		4:
			hud.toggle_tech_tree()
		_:
			get_tree().quit()

var _last_report_turn = 0
var _ev_stats = {}
var _bot_turn = -1

func _autotest_step() -> void:
	if game.turn != _last_report_turn:
		_last_report_turn = game.turn
		var line = "TURN %d checksum=%d" % [game.turn, game.checksum()]
		for p in game.players:
			line += " | %s c%d u%d t%d g%d%s" % [p.civ_name().left(4), game.player_cities(p.id).size(), game.player_units(p.id).size(), p.techs.size(), p.gold, "" if p.alive else " DEAD"]
		print(line)
	# Bots: humans just end their turn.
	var me = game.player(pid)
	if not me.is_ai() and me.alive and not me.ready and not game.finished and _bot_turn != game.turn:
		_bot_turn = game.turn
		AI.run_turn(game, pid, func(cmd):
			Net.send(cmd)
			return true)
		Net.send({"t": "ready", "v": true})
	if game.turn > _autotest_turns or game.finished:
		print("EVENTS ", _ev_stats)
		print("AUTOTEST DONE turn=%d finished=%s winner=%d checksum=%d" % [game.turn, str(game.finished), game.winner, game.checksum()])
		_autotest_turns = 0
		get_tree().quit()
