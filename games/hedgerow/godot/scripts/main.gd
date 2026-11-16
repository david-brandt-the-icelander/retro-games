extends Node3D
## Game controller: setup, turn sequence, player input, move/fire resolution.

const MAX_TURNS := 12
const REINFORCE_TURN := 5
const US_COL := "#8fbaff"
const DE_COL := "#ff9585"

var map: GameMap
var cam: CameraRig
var ui: GameUI
var ai: AIController
var units: Array[Unit] = []
var units_root: Node3D
var fx_root: Node3D
var turn := 1
var current_side := "US"
var player_side := "US"
var attacker_side := "US"
var busy := true
var game_over := false
var autotest := false
var selected: Unit = null
var reach: Dictionary = {}
var hover_hex := Vector2i(-999, -999)
var rng := RandomNumberGenerator.new()
var arty_left := 3
var arty_used_turn := 0
var arty_mode := false
const NO_HEX := Vector2i(-999, -999)


func _ready() -> void:
	randomize()
	rng.randomize()
	autotest = "--autotest" in OS.get_cmdline_user_args()
	if autotest:
		Engine.time_scale = 25.0
		# A game that never ends fails the test instead of hanging it.
		get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
			push_error("AUTOTEST: no result within 240 seconds")
			get_tree().quit(1))
	_setup_environment()
	map = GameMap.new()
	add_child(map)
	map.generate(1944)
	map.build_visuals()
	units_root = Node3D.new()
	add_child(units_root)
	fx_root = Node3D.new()
	add_child(fx_root)
	cam = CameraRig.new()
	add_child(cam)
	var b := map.bounds()
	cam.bounds = b
	cam.focus_on(Vector3(b.get_center().x, 0, b.end.y - 4.0), true)
	ui = GameUI.new()
	ui.headless_log = autotest
	add_child(ui)
	ui.end_turn_pressed.connect(_on_end_turn)
	ui.next_unit_pressed.connect(_select_next)
	ui.restart_pressed.connect(func() -> void: get_tree().reload_current_scene())
	ui.artillery_pressed.connect(_toggle_artillery)
	ai = AIController.new(self)
	_deploy()
	_update_visibility()
	_refresh_objectives()
	ui.log_msg("[b]Normandy, July 1944.[/b] Your company must seize the village crossroads area. Take and hold [color=#f0c860]two of three objectives[/color] by the end of turn %d." % MAX_TURNS)
	ui.log_msg("[color=#aaa]German units in woods, buildings and wheat are concealed until close or until they fire.[/color]")
	await get_tree().process_frame
	_start_side_turn("US")
	if "--shots" in OS.get_cmdline_user_args():
		_screenshot_tour()


func _screenshot_tour() -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if dir == "":
		dir = "user://"
	var b := map.bounds()
	var poses := [
		[Vector3(b.get_center().x, 0, b.get_center().y + 2.0), 0.0, -55.0, 30.0],
		[Vector3(b.get_center().x - 1.0, 0, b.end.y - 3.0), 0.3, -38.0, 11.0],
		[Hex.to_world(map.objectives[0]["hex"]), -0.5, -35.0, 9.0],
		[Hex.to_world(map.objectives[1]["hex"]), 0.6, -42.0, 10.0],
	]
	for i in poses.size():
		var pz: Array = poses[i]
		cam.focus_on(pz[0], true)
		cam._t_yaw = pz[1]
		cam.yaw = pz[1]
		cam._t_pitch = deg_to_rad(pz[2])
		cam.pitch = cam._t_pitch
		cam._t_dist = pz[3]
		cam.dist = pz[3]
		if i == 1:
			for u in units:
				if u.side == "US" and u.is_vehicle():
					_select(u)
					hover_hex = Vector2i(-999, -999)
					break
		if i == 2:
			_deselect()
			for u in units:
				if u.side == "DE":
					u.visible = true
		for f in 40:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/shot%d.png" % [dir, i])
		print("saved shot ", i)
	get_tree().quit()


func _setup_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.3, 0.45, 0.65)
	psm.sky_horizon_color = Color(0.74, 0.72, 0.66)
	psm.ground_horizon_color = Color(0.5, 0.48, 0.42)
	psm.ground_bottom_color = Color(0.18, 0.18, 0.15)
	psm.sun_angle_max = 25.0
	sky.sky_material = psm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 2.2
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.72, 0.74)
	env.fog_density = 0.0045
	env.fog_sky_affect = 0.25
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = 70.0
	add_child(sun)


# =================================================================== deployment

func _spawn(tid: String, h: Vector2i, yaw: float) -> Unit:
	var u := Unit.new()
	units_root.add_child(u)
	u.setup(tid, h, map.unit_pos(h), yaw)
	units.append(u)
	return u


func _deploy() -> void:
	var us_list := ["us_sherman", "us_sherman", "us_sherman", "us_m10", "us_rifle", "us_rifle", "us_rifle",
		"us_rifle", "us_rifle", "us_rifle", "us_mg", "us_mg", "us_bazooka", "us_bazooka", "us_57"]
	var cands: Array[Vector2i] = []
	for h in map.tiles:
		var row: int = map.tiles[h]["row"]
		if row >= 13 and map.ttype(h) != GameMap.WATER and map.ttype(h) != GameMap.BUILDING:
			cands.append(h)
	cands.shuffle()
	for tid in us_list:
		var veh: bool = String(UnitData.TYPES[tid]["kind"]) == "vehicle"
		for h in cands:
			if unit_at(h) != null:
				continue
			if veh and map.ttype(h) == GameMap.WOODS:
				continue
			_spawn(tid, h, 0.0)
			break
	var groups := [
		["de_gren", "de_gren", "de_mg42", "de_schreck", "de_pz4"],
		["de_gren", "de_mg42", "de_pak40"],
		["de_gren", "de_stug"],
	]
	for gi in groups.size():
		var oh: Vector2i = map.objectives[gi]["hex"]
		var first := true
		for tid in groups[gi]:
			var h := oh
			if not first:
				h = _best_defensive_hex(tid, oh)
			first = false
			if h == NO_HEX:
				continue
			var u := _spawn(tid, h, PI)
			u.anchor = gi


func _best_defensive_hex(tid: String, oh: Vector2i) -> Vector2i:
	var veh: bool = String(UnitData.TYPES[tid]["kind"]) == "vehicle"
	var best := NO_HEX
	var bs := -INF
	for h in map.tiles:
		var dd: int = Hex.distance(h, oh)
		if dd > 2 or unit_at(h) != null:
			continue
		var t: int = map.ttype(h)
		if t == GameMap.WATER:
			continue
		if veh and t == GameMap.BUILDING:
			continue
		var s: float = map.tem(h) * 2.0 + map.elev(h) * 0.5 + rng.randf() * 1.5 - dd * 0.3
		if veh and t == GameMap.WOODS:
			s -= 3.0
		# prefer facing south (toward the enemy)
		s += float(map.tiles[h]["row"] - map.tiles[oh]["row"]) * 0.4
		if s > bs:
			bs = s
			best = h
	return best


func _reinforce() -> void:
	var list := ["de_panther", "de_gren"]
	var placed := 0
	for tid in list:
		var best := NO_HEX
		var bd := 999
		for h in map.tiles:
			if int(map.tiles[h]["row"]) > 1 or unit_at(h) != null:
				continue
			var t: int = map.ttype(h)
			if t == GameMap.WATER or t == GameMap.BUILDING or t == GameMap.WOODS:
				continue
			var dd: int = absi(int(map.tiles[h]["col"]) - 12)
			if dd < bd:
				bd = dd
				best = h
		if best != NO_HEX:
			var u := _spawn(tid, best, PI)
			u.anchor = 0
			placed += 1
	if placed > 0:
		ui.show_banner("German reinforcements!")
		ui.log_msg("[color=%s][b]Radio intercept:[/b] a Panther and grenadiers are moving down from the north road.[/color]" % DE_COL)


# =================================================================== queries

func unit_at(h: Vector2i) -> Unit:
	for u in units:
		if u.alive and u.hex == h:
			return u
	return null


func _n(u: Unit) -> String:
	return "[color=%s]%s[/color]" % [US_COL if u.side == "US" else DE_COL, u.display_name()]


func reachable(u: Unit) -> Dictionary:
	var mp: float = float(u.d["mp"])
	var dist := {u.hex: 0.0}
	var prev := {}
	var open: Array[Vector2i] = [u.hex]
	var kind: String = String(u.d["kind"])
	while open.size() > 0:
		var bi := 0
		for i in open.size():
			if float(dist[open[i]]) < float(dist[open[bi]]):
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if float(dist[cur]) >= mp:
			continue
		for n in Hex.neighbors(cur):
			if not map.has(n):
				continue
			var occ := unit_at(n)
			if occ != null and occ.side != u.side:
				continue
			var c: float = map.move_cost(kind, cur, n)
			if c >= 99.0:
				continue
			var nd: float = float(dist[cur]) + c
			if nd > mp + 0.001:
				if cur == u.hex:
					nd = mp  # minimum move: one hex is always possible
				else:
					continue
			if not dist.has(n) or nd < float(dist[n]):
				dist[n] = nd
				prev[n] = cur
				if not open.has(n):
					open.append(n)
	var ends: Array[Vector2i] = []
	for h in dist:
		if h != u.hex and unit_at(h) == null:
			ends.append(h)
	return {"ends": ends, "prev": prev, "dist": dist}


func build_path(prev: Dictionary, start: Vector2i, dest: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := dest
	var guard := 0
	while cur != start and guard < 200:
		path.push_front(cur)
		if not prev.has(cur):
			break
		cur = prev[cur]
		guard += 1
	return path


func can_target(a: Unit, t: Unit, from_hex: Vector2i) -> String:
	if not t.alive:
		return "Target destroyed"
	if a.side == t.side:
		return "Friendly unit"
	if t.side != player_side and not t.visible:
		return "Not spotted"
	return Combat.can_attack(a, t, from_hex, map)


func best_target(u: Unit, from_hex: Vector2i, moved: bool) -> Dictionary:
	var best: Unit = null
	var bev := 0.0
	if u.status == "broken":
		return {"unit": null, "ev": 0.0}
	for t in units:
		if not t.alive or t.side == u.side:
			continue
		if can_target(u, t, from_hex) != "":
			continue
		var e: float = Combat.ev(u, t, from_hex, moved, map, false)
		if e > bev:
			bev = e
			best = t
	return {"unit": best, "ev": bev}


# =================================================================== visibility

func _is_spotted(u: Unit) -> bool:
	var conceal: int = map.concealing(u.hex)
	for s in units:
		if not s.alive or s.side == u.side:
			continue
		var dd: int = Hex.distance(s.hex, u.hex)
		if dd > 16:
			continue
		if conceal > 0 and not u.revealed and dd > conceal:
			continue
		if map.los(s.hex, u.hex):
			return true
	return false


func _update_visibility() -> void:
	for u in units:
		if not u.alive:
			continue
		if u.side == player_side:
			u.visible = true
		else:
			u.visible = _is_spotted(u)


# =================================================================== turn flow

func _start_side_turn(side: String) -> void:
	if game_over:
		return
	current_side = side
	for u in units:
		u.hits_taken = 0
		if u.side == side and u.alive:
			u.moved = false
			u.fired = false
			u.revealed = false
			u.opfire_ready = false
	if side == "DE" and turn == REINFORCE_TURN:
		_reinforce()
	for u in units:
		if u.side == side and u.alive and u.status == "broken":
			var m: int = Combat.morale_of(u, map)
			var r: int = rng.randi_range(1, 6) + rng.randi_range(1, 6)
			if r <= m:
				u.status = "ok"
				u.moved = true
				u.fired = true
				ui.log_msg("%s rallies (%d <= %d)." % [_n(u), r, m])
			else:
				ui.log_msg("%s remains broken (%d > %d)." % [_n(u), r, m])
	for u in units:
		if u.alive:
			u.refresh()
	_update_visibility()
	ui.set_turn(turn, MAX_TURNS, side, player_side)
	_refresh_objectives()
	arty_mode = false
	_refresh_arty()
	if side == player_side and not autotest:
		if turn == 1 and not ui.help_visible():
			ui.toggle_help()
		ui.show_banner("Turn %d — Your move" % turn)
		ui.log_msg("[b]— Turn %d: US Army —[/b]" % turn)
		busy = false
		_select_next()
	else:
		ui.show_banner("Turn %d — %s" % [turn, "German turn" if side == "DE" else "US turn"])
		ui.log_msg("[b]— Turn %d: %s —[/b]" % [turn, "Wehrmacht" if side == "DE" else "US Army"])
		busy = true
		_deselect()
		await get_tree().create_timer(0.8).timeout
		if side == player_side and arty_left > 0:
			await _ai_artillery()
		await ai.run_turn(side)
		if game_over:
			return
		_end_side_turn()


func _end_side_turn() -> void:
	for u in units:
		if u.side == current_side and u.alive:
			u.opfire_ready = not u.fired and u.status != "broken"
			if u.status == "pinned":
				u.status = "ok"
			u.refresh()
	_update_all_control()
	if _check_victory():
		return
	if current_side == "US":
		_start_side_turn("DE")
	else:
		turn += 1
		if turn > MAX_TURNS:
			_final_result()
			return
		_start_side_turn("US")


func _on_end_turn() -> void:
	if busy or game_over or current_side != player_side:
		return
	busy = true
	_deselect()
	_end_side_turn()


# =================================================================== objectives

func _update_control_at(u: Unit) -> void:
	if not u.alive or u.status == "broken":
		return
	var oi: int = map.tiles[u.hex]["obj"]
	if oi >= 0 and map.objectives[oi]["owner"] != u.side:
		map.set_objective_owner(oi, u.side)
		ui.log_msg("[color=#f0c860]%s captured by %s![/color]" % [map.objectives[oi]["name"], "US forces" if u.side == "US" else "German forces"])
		if not autotest:
			ui.show_banner("%s %s" % [map.objectives[oi]["name"], "taken!" if u.side == player_side else "lost!"])
		_refresh_objectives()


func _update_all_control() -> void:
	for u in units:
		_update_control_at(u)


func _refresh_objectives() -> void:
	ui.set_objectives(map.objectives, turn, MAX_TURNS)


func _count(side: String) -> int:
	var n := 0
	for u in units:
		if u.alive and u.side == side:
			n += 1
	return n


func _check_victory() -> bool:
	if game_over:
		return true
	if _count("DE") == 0:
		_game_over(true, "Decisive Victory", "Every German unit in the sector has been destroyed or routed.")
		return true
	if _count("US") == 0:
		_game_over(false, "Defeat", "Your company has been wiped out.")
		return true
	return false


func _final_result() -> void:
	var held := 0
	for o in map.objectives:
		if o["owner"] == "US":
			held += 1
	if held >= 2:
		_game_over(true, "Victory", "Your company holds %d of 3 objectives at nightfall." % held)
	else:
		_game_over(false, "Defeat", "The Germans still hold %d of 3 objectives. The attack has stalled." % (3 - held))


func _game_over(win: bool, title: String, text: String) -> void:
	game_over = true
	busy = true
	var us_lost := 0
	var de_lost := 0
	for u in units:
		if not u.alive:
			if u.side == "US":
				us_lost += 1
			else:
				de_lost += 1
	var full := "%s\n\n[color=#8fbaff]US units lost: %d[/color]    [color=#ff9585]German units lost: %d[/color]" % [text, us_lost, de_lost]
	ui.log_msg("[b]%s[/b] — %s" % [title, text])
	ui.show_game_over(title, full, win)
	if autotest:
		print("AUTOTEST RESULT: ", title, " turn=", turn, " us_lost=", us_lost, " de_lost=", de_lost)
		await get_tree().create_timer(0.5).timeout
		get_tree().quit()


# =================================================================== actions

func do_move(u: Unit, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	u.moved = true
	u.revealed = true
	if autotest:
		print("  move %s %s -> %s" % [u.display_name(), str(Hex.axial_to_offset(u.hex)), str(Hex.axial_to_offset(path.back()))])
	var pts: Array[Vector3] = []
	for h in path:
		pts.append(map.unit_pos(h))
	await u.move_along(pts)
	u.hex = path.back()
	u.position = map.unit_pos(u.hex)
	u.refresh()
	_update_visibility()
	_update_control_at(u)
	await _check_opfire(u)
	_check_victory()


func _check_opfire(mover: Unit) -> void:
	if not mover.alive or game_over:
		return
	var shooters: Array = []
	for e in units:
		if not e.alive or e.side == mover.side or not e.opfire_ready or e.status == "broken":
			continue
		if can_target(e, mover, e.hex) != "":
			continue
		var moving_open: bool = map.tem(mover.hex) <= 0
		var v: float = Combat.ev(e, mover, e.hex, false, map, moving_open)
		if v > 0.12:
			shooters.append([v, e])
	shooters.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var n := 0
	for s in shooters:
		if n >= 2 or not mover.alive or game_over:
			break
		n += 1
		ui.log_msg("[color=#ffd36b]Op-fire![/color]")
		await do_attack(s[1], mover, true)


func do_attack(a: Unit, t: Unit, opfire: bool) -> void:
	if not a.alive or not t.alive:
		return
	a.fired = true
	a.revealed = true
	a.opfire_ready = false
	var moved: bool = a.moved and not opfire
	var t_moving_open: bool = opfire and map.tem(t.hex) <= 0
	_update_visibility()
	if not autotest and (a.visible or t.visible) and current_side != player_side:
		cam.focus_on((a.global_position + t.global_position) * 0.5)
	await a.aim_at(t.global_position)
	var at_mode: bool = t.is_vehicle()
	await a.fire_fx(t.global_position + Vector3(0, 0.25 if at_mode else 0.15, 0), at_mode, fx_root)
	if at_mode:
		_resolve_at(a, t, moved)
	else:
		_resolve_soft(a, t, moved, t_moving_open)
	t.hits_taken += 1
	a.refresh()
	if t.alive:
		t.refresh()
	if selected != null:
		ui.show_unit(selected)
	await get_tree().create_timer(0.4).timeout
	_check_victory()


func _roll2() -> Array[int]:
	return [rng.randi_range(1, 6), rng.randi_range(1, 6)]


func _resolve_soft(a: Unit, t: Unit, moved: bool, t_moving_open: bool) -> void:
	var base: int = Combat.soft_base(a, t, a.hex, moved, map, t_moving_open)
	var r := _roll2()
	var total: int = base + r[0] + r[1]
	var txt := "%s fires on %s: %d + (%d+%d) = [b]%d[/b] — " % [_n(a), _n(t), base, r[0], r[1], total]
	var tp: Vector3 = t.global_position + Vector3(0, 0.1, 0)
	if total >= Combat.CAS:
		FX.dust(fx_root, tp, 1.6)
		ui.log_msg(txt + "[color=#ff6b5b]CASUALTIES[/color]")
		if not t.take_step():
			_kill_soft(t)
			return
		_morale_check(t)
	elif total >= Combat.MC:
		FX.dust(fx_root, tp, 1.2)
		ui.log_msg(txt + "morale check")
		_morale_check(t)
	elif total >= Combat.PIN:
		FX.dust(fx_root, tp, 0.9)
		if t.status == "ok":
			t.status = "pinned"
		ui.log_msg(txt + "[color=#ffd36b]PINNED[/color]")
	else:
		FX.dust(fx_root, tp + Vector3(randf_range(-0.4, 0.4), 0, randf_range(-0.4, 0.4)), 0.6)
		ui.log_msg(txt + "no effect")


func _morale_check(t: Unit) -> void:
	var m: int = Combat.morale_of(t, map)
	var r := _roll2()
	var roll: int = r[0] + r[1]
	if roll > m:
		if t.status == "broken":
			ui.log_msg("   Morale %d vs %d — routed unit takes losses" % [roll, m])
			if not t.take_step():
				_kill_soft(t)
				return
		else:
			t.status = "broken"
			ui.log_msg("   Morale %d vs %d — [color=#ff9a50]BROKEN![/color]" % [roll, m])
	else:
		if t.status == "ok":
			t.status = "pinned"
		ui.log_msg("   Morale %d vs %d — holds, pinned" % [roll, m])
	t.refresh()


func _kill_soft(t: Unit) -> void:
	FX.dust(fx_root, t.global_position + Vector3(0, 0.1, 0), 2.0)
	t.eliminate()
	ui.log_msg("   [color=#ff6b5b]%s eliminated![/color]" % _n(t))


func _resolve_at(a: Unit, t: Unit, moved: bool) -> void:
	var dist: int = Hex.distance(a.hex, t.hex)
	var tn: int = Combat.at_tn(a, t, a.hex, moved, map)
	var r := _roll2()
	var roll: int = r[0] + r[1]
	var txt := "%s engages %s at %d hexes: to-hit %d (need <=%d) — " % [_n(a), _n(t), dist, roll, tn]
	var tp: Vector3 = t.global_position + Vector3(0, 0.3, 0)
	if roll > tn:
		FX.dust(fx_root, tp + Vector3(randf_range(-0.7, 0.7), -0.25, randf_range(-0.7, 0.7)), 1.2)
		ui.log_msg(txt + "miss")
		return
	var asp: String = Combat.aspect(t, a.hex)
	var armor: int = Combat.armor_vs(t, a.hex)
	var pen: float = Combat.pen_eff(a, dist) * rng.randf_range(0.85, 1.15)
	txt += "hit %s (%dmm vs %dmm) — " % [asp, int(pen), armor]
	if pen >= armor:
		FX.explosion(fx_root, t.global_position)
		cam.add_shake(0.4)
		t.make_wreck(fx_root)
		ui.log_msg(txt + "[color=#ff6b5b][b]KNOCKED OUT![/b][/color]")
	elif pen >= armor * 0.75:
		FX.sparks(fx_root, tp)
		if t.status == "ok":
			t.status = "pinned"
		ui.log_msg(txt + "[color=#ffd36b]no penetration, crew shaken[/color]")
	else:
		FX.sparks(fx_root, tp)
		ui.log_msg(txt + "ricochet")


# =================================================================== player input

func _pick_hex() -> Vector2i:
	var vp := get_viewport()
	var mp := vp.get_mouse_position()
	var c3 := cam.camera
	var from := c3.project_ray_origin(mp)
	var dir := c3.project_ray_normal(mp)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0, 3)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return NO_HEX
	var col: Object = hit["collider"]
	if col != null and col.has_meta("unit"):
		var u: Unit = col.get_meta("unit")
		if u.alive and (u.visible or u.side == player_side):
			return u.hex
	var p: Vector3 = hit["position"] - hit["normal"] * 0.05
	var h := Hex.from_world(p)
	return h if map.has(h) else NO_HEX


func _unhandled_input(event: InputEvent) -> void:
	if game_over or autotest:
		return
	if event is InputEventMouseMotion:
		_update_hover()
	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_on_left_click()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			_deselect()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_F1 or k.keycode == KEY_H or (k.keycode == KEY_ESCAPE and ui.help_visible()):
			ui.toggle_help()
			return
		if ui.help_visible():
			return
		match k.keycode:
			KEY_ENTER, KEY_KP_ENTER:
				_on_end_turn()
			KEY_TAB:
				_select_next()
			KEY_ESCAPE:
				_deselect()
			KEY_F:
				_toggle_artillery()
			KEY_SPACE:
				if selected != null:
					cam.focus_on(selected.global_position)


func _update_hover() -> void:
	var h := _pick_hex()
	if h == hover_hex:
		return
	hover_hex = h
	map.set_hover(h)
	_refresh_overlays()
	if h == NO_HEX:
		ui.set_hover("")
		return
	var info := map.describe(h)
	var u := unit_at(h)
	if u != null and (u.side == player_side or u.visible):
		info += "\n%s  [color=#aaa]%s[/color]" % [_n(u), String(u.d["role"])]
		if u.is_vehicle():
			info += "  · armor %d/%dmm" % [int(u.d["armor_f"]), int(u.d["armor_s"])]
		if u.status != "ok":
			info += "  · [color=#ffd36b]%s[/color]" % u.status.to_upper()
	if arty_mode:
		var why := _arty_reason(h)
		info += "\n" + ("[color=#ffb070]%s[/color]" % why if why != "" else "[color=#ffcf6a][b]Fire mission:[/b] 105mm battery — FP 9 on this hex, FP 6 on adjacent hexes. Danger close![/color]")
	elif selected != null and selected.side == player_side and current_side == player_side and not busy:
		if u == null and reach.has("ends") and (reach["ends"] as Array).has(h):
			var cost: float = reach["dist"][h]
			info += "\n[color=#9fd4ff]Move here — %s of %d MP[/color]" % [str(snappedf(cost, 0.5)), int(selected.d["mp"])]
		elif u != null and u.side != player_side and u.visible:
			info += "\n" + _attack_preview(selected, u)
	ui.set_hover(info)


func _attack_preview(a: Unit, t: Unit) -> String:
	if not a.can_fire():
		return "[color=#ffb070]%s has already fired this turn.[/color]" % a.display_name()
	var reason := can_target(a, t, a.hex)
	if reason != "":
		return "[color=#ffb070]Cannot fire: %s[/color]" % reason
	var dist: int = Hex.distance(a.hex, t.hex)
	if t.is_vehicle():
		var tn: int = Combat.at_tn(a, t, a.hex, a.moved, map)
		var ph: float = Combat.p_le(tn)
		var armor: int = Combat.armor_vs(t, a.hex)
		var pen: float = Combat.pen_eff(a, dist)
		var pk: float = Combat.p_pen(pen, float(armor))
		return "[b]Anti-tank fire[/b] · range %d\nTo hit: 2d6 <= %d ([b]%d%%[/b])   Pen ~%dmm vs %s %dmm ([b]%d%%[/b])\n[color=#ff8a6a][b]Chance to knock out: %d%%[/b][/color]" % [
			dist, tn, int(ph * 100), int(pen), Combat.aspect(t, a.hex), armor, int(pk * 100), int(ph * pk * 100)]
	var base: int = Combat.soft_base(a, t, a.hex, a.moved, map, false)
	var o: Dictionary = Combat.soft_odds(base)
	return "[b]Fire attack[/b] · range %d · base %d + 2d6\nCasualty [b]%d%%[/b] · Morale check [b]%d%%[/b] · Pin [b]%d%%[/b]%s" % [
		dist, base, int(o["cas"] * 100), int(o["mc"] * 100), int(o["pin"] * 100),
		"\n[color=#aaa](moved this turn: -2)[/color]" if a.moved else ""]


func _on_left_click() -> void:
	if busy or current_side != player_side:
		return
	var h := _pick_hex()
	if h == NO_HEX:
		return
	if arty_mode:
		var why := _arty_reason(h)
		if why != "":
			ui.flash(why)
			return
		busy = true
		arty_mode = false
		_refresh_arty()
		_clear_overlays()
		await do_artillery(h)
		busy = false
		if not game_over:
			_select(selected if selected != null and selected.alive else null)
		return
	var u := unit_at(h)
	if selected != null:
		if u != null and u.side != player_side and u.visible:
			if not selected.can_fire():
				ui.flash("%s has already fired" % selected.display_name())
				return
			var reason := can_target(selected, u, selected.hex)
			if reason != "":
				ui.flash(reason)
				return
			busy = true
			var a := selected
			_clear_overlays()
			await do_attack(a, u, false)
			busy = false
			if not game_over:
				_select(a if a.alive else null)
			return
		if u == null and reach.has("ends") and (reach["ends"] as Array).has(h) and selected.can_move():
			busy = true
			var m := selected
			var path := build_path(reach["prev"], m.hex, h)
			_clear_overlays()
			await do_move(m, path)
			busy = false
			if not game_over:
				_select(m if m.alive else null)
			return
	if u != null and u.side == player_side:
		_select(u)
		return
	_deselect()


func _select(u: Unit) -> void:
	selected = u
	if u == null:
		_deselect()
		return
	reach = reachable(u) if u.can_move() else {}
	ui.show_unit(u)
	_refresh_overlays()


func _deselect() -> void:
	selected = null
	reach = {}
	if ui != null:
		ui.show_unit(null)
	_refresh_overlays()


func _clear_overlays() -> void:
	map.show_overlays([], [], [], NO_HEX)


func _refresh_overlays() -> void:
	if map == null:
		return
	if selected == null or not selected.alive:
		_clear_overlays()
		return
	var moves: Array = reach["ends"] if reach.has("ends") else []
	var path: Array = []
	if moves.has(hover_hex):
		path = build_path(reach["prev"], selected.hex, hover_hex)
	var targets: Array = []
	if selected.can_fire():
		for t in units:
			if t.alive and t.side != player_side and t.visible and can_target(selected, t, selected.hex) == "":
				targets.append(t.hex)
	map.show_overlays(moves, path, targets, selected.hex)


func _refresh_arty() -> void:
	var avail: bool = current_side == player_side and not game_over and arty_left > 0 and arty_used_turn != turn
	if not avail:
		arty_mode = false
	ui.set_artillery(arty_left, avail, arty_mode)


func _toggle_artillery() -> void:
	if busy or current_side != player_side or game_over:
		_refresh_arty()
		return
	if arty_left <= 0 or arty_used_turn == turn:
		ui.flash("No fire mission available this turn")
		_refresh_arty()
		return
	arty_mode = not arty_mode
	if arty_mode:
		ui.flash("Select a target hex your units can see")
	_refresh_arty()


func _arty_reason(h: Vector2i) -> String:
	for u in units:
		if u.alive and u.side == player_side and u.status != "broken" and Hex.distance(u.hex, h) <= 14 and map.los(u.hex, h):
			return ""
	return "No observer has line of sight to that hex"


func _ai_artillery() -> void:
	var best := NO_HEX
	var bs := 1.5
	for e in units:
		if not e.alive or e.side == player_side or not e.visible or e.is_vehicle():
			continue
		if _arty_reason(e.hex) != "":
			continue
		var sc := 0.0
		for o in units:
			if o.alive and Hex.distance(o.hex, e.hex) <= 1:
				sc += (1.0 if o.side != player_side else -2.0) * (1.0 if o.hex == e.hex else 0.5)
		if sc > bs:
			bs = sc
			best = e.hex
	if best != NO_HEX:
		await do_artillery(best)


func do_artillery(h: Vector2i) -> void:
	arty_left -= 1
	arty_used_turn = turn
	_refresh_arty()
	ui.log_msg("[color=#ffcf6a][b]Fire mission![/b] 105mm howitzers on target.[/color]")
	cam.focus_on(Hex.to_world(h))
	await get_tree().create_timer(0.6).timeout
	for i in 7:
		var off := Vector3(rng.randf_range(-1.4, 1.4), 0, rng.randf_range(-1.4, 1.4))
		var p := Hex.to_world(h) + off
		var ph := Hex.from_world(p)
		var y: float = map.top_y(ph) if map.has(ph) else 0.0
		FX.explosion(fx_root, Vector3(p.x, y, p.z))
		cam.add_shake(0.3)
		await get_tree().create_timer(0.16).timeout
	var victims: Array[Unit] = []
	for u in units:
		if u.alive and Hex.distance(u.hex, h) <= 1:
			victims.append(u)
	for t in victims:
		if not t.alive:
			continue
		var center: bool = t.hex == h
		var r := _roll2()
		if t.is_vehicle():
			var roll: int = r[0] + r[1]
			if center and roll == 12:
				FX.explosion(fx_root, t.global_position)
				t.make_wreck(fx_root)
				ui.log_msg("   Direct hit! %s [color=#ff6b5b][b]KNOCKED OUT![/b][/color]" % _n(t))
			elif roll >= (10 if center else 11):
				if t.status == "ok":
					t.status = "pinned"
				ui.log_msg("   %s shaken by near misses" % _n(t))
			t.refresh()
			continue
		var base: int = (9 if center else 6) - map.tem(t.hex) + mini(t.hits_taken, 3)
		var total: int = base + r[0] + r[1]
		var txt := "   Barrage on %s: %d + (%d+%d) = [b]%d[/b] — " % [_n(t), base, r[0], r[1], total]
		if total >= Combat.CAS:
			ui.log_msg(txt + "[color=#ff6b5b]CASUALTIES[/color]")
			if not t.take_step():
				_kill_soft(t)
				continue
			_morale_check(t)
		elif total >= Combat.MC:
			ui.log_msg(txt + "morale check")
			_morale_check(t)
		elif total >= Combat.PIN:
			if t.status == "ok":
				t.status = "pinned"
			ui.log_msg(txt + "[color=#ffd36b]PINNED[/color]")
			t.refresh()
		else:
			ui.log_msg(txt + "no effect")
		t.hits_taken += 1
	if victims.is_empty():
		ui.log_msg("   The barrage falls on empty ground.")
	_update_visibility()
	await get_tree().create_timer(0.5).timeout
	_check_victory()


func _select_next() -> void:
	if busy or current_side != player_side or game_over:
		return
	var mine: Array[Unit] = []
	for u in units:
		if u.alive and u.side == player_side and (u.can_move() or u.can_fire()):
			mine.append(u)
	if mine.is_empty():
		ui.flash("All units have acted — end your turn")
		return
	var idx := 0
	if selected != null and mine.has(selected):
		idx = (mine.find(selected) + 1) % mine.size()
	_select(mine[idx])
	cam.focus_on(mine[idx].global_position)
