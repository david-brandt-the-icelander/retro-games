extends Node3D
class_name Game
## One match. The host (peer 1) is authoritative for items, traps, damage and win
## conditions; every peer simulates its own agent's movement.

const SEARCH_TIME := 0.7
const TRAP_TIME := 0.9
const TRAP_COOLDOWN := 7.0
const INTERACT_RANGE := 1.5
const DOOR_RANGE := 1.6
const PUNCH_DAMAGE := 15
const PUNCH_RANGE := 1.6
const PUNCH_COOLDOWN := 0.55
const MAX_HP := 100

var config: Dictionary
var layout: Dictionary
var builder: WorldBuilder
var mode := "lms"
var my_id := 1
var agents := {}        # id -> Agent
var info := {}          # id -> {name, color, team, hp, alive, items, tools}  (replicated)
var am_spectator := false
var game_over := false
var time_left := 600.0
var initial_teams := 1

# --- server-only state
var furn_content: Array = []   # String item id or ""
var furn_trap: Array = []      # {} or {type, team, owner}
var door_trap: Array = []
var _hint_t := {}
var _time_sync := 0.0
var _server_ready := false

# --- local state
var camera: Camera3D
var hud: HUD
var spectator: SpectatorView
var trap_sel := 0
var trap_ready := {}
var attack_ready := 0.0
var known_traps := {}     # "f3"/"d2" -> type (traps my team knows about)
var trap_markers := {}
var current_room := -2
var shake := 0.0
var pending_action := {}  # {kind, idx, type, end}
var agents_root: Node3D
var bot_mode := false     # --bot: wander and act randomly (for automated testing)
var _bot_t := 0.0


func _bot_tick(delta: float, a: Agent) -> void:
	_bot_t -= delta
	if _bot_t > 0.0:
		return
	_bot_t = randf_range(0.5, 1.2)
	a.bot_input = Vector2.from_angle(randf() * TAU)
	var r := randf()
	if r < 0.4:
		do_search()
	elif r < 0.6:
		trap_sel = randi() % 4
		do_trap()
	elif r < 0.8:
		do_attack()


func start(cfg: Dictionary) -> void:
	config = cfg
	mode = cfg.mode
	bot_mode = OS.get_cmdline_user_args().has("--bot")
	my_id = Net.my_id
	time_left = cfg.duration
	layout = Maps.generate(cfg.map, cfg.seed)
	builder = WorldBuilder.new()
	builder.build(layout, self)

	agents_root = Node3D.new()
	agents_root.name = "Agents"
	add_child(agents_root)

	var ids: Array = []
	for id in cfg.players:
		if not cfg.players[id].spectator:
			ids.append(id)
	ids.sort()
	var teams := {}
	for i in ids.size():
		var id: int = ids[i]
		var p: Dictionary = cfg.players[id]
		var team: int = p.team if mode == "teams" else id
		var col: Color = Maps.TEAM_COLORS[p.team] if mode == "teams" else Maps.PLAYER_COLORS[p.color]
		teams[team] = true
		var a := Agent.new()
		var spawn: Vector3 = layout.spawns[i % layout.spawns.size()]
		spawn += Vector3((i / layout.spawns.size()) * 1.2, 0, 0)
		a.setup(id, p.name, col, team, spawn)
		agents_root.add_child(a)
		agents[id] = a
		info[id] = {"name": p.name, "color": col, "team": team, "hp": MAX_HP,
			"alive": true, "items": [], "tools": []}
	initial_teams = teams.size()
	am_spectator = not agents.has(my_id)

	camera = Camera3D.new()
	camera.fov = 50
	add_child(camera)
	camera.make_current()
	if agents.has(my_id):
		camera.position = agents[my_id].position + Vector3(0, 15, 6.5)
		camera.look_at(agents[my_id].position)

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)
	spectator = SpectatorView.new()
	add_child(spectator)
	spectator.setup(self)

	for t in Maps.TRAP_ORDER:
		trap_ready[t] = 0.0

	Net.peer_left.connect(_on_peer_left)
	if Net.is_host():
		_server_setup()
	if am_spectator:
		_enter_spectator()
	else:
		hud.feed("Find the Dossier, Keycard, Passport and Cash — then reach the EXTRACTION door.", Color(0.8, 0.9, 1))
		if mode == "teams":
			hud.feed("Co-op: your team pools its intel. Any teammate can extract.", Color(0.8, 0.9, 1))


func now() -> float:
	return Time.get_ticks_msec() / 1000.0


func local_agent() -> Agent:
	return agents.get(my_id)


func is_teammate(a: int, b: int) -> bool:
	return info.has(a) and info.has(b) and info[a].team == info[b].team


# =================================================================== server setup

func _server_setup() -> void:
	var n: int = layout.furniture.size()
	furn_content.resize(n)
	furn_trap.resize(n)
	for i in n:
		furn_content[i] = ""
		furn_trap[i] = {}
	door_trap.resize(layout.doors.size())
	for i in layout.doors.size():
		door_trap[i] = {}
	var order := range(n)
	order.shuffle()
	var k := 0
	for item in Maps.OBJECTIVES:
		if k < n:
			furn_content[order[k]] = item
			k += 1
	var per_tool := maxi(2, ceili(agents.size() * 0.75))
	for t in Maps.TOOLS:
		for j in per_tool:
			if k < n:
				furn_content[order[k]] = t
				k += 1
	_server_ready = true


func _sender() -> int:
	return Net.sender


func _to_server(method: String, args: Array) -> void:
	Net.call_host(self, method, args)


func _send_to(peer: int, method: String, args: Array) -> void:
	Net.call_peer(peer, self, method, args)


func _all(method: String, args: Array = []) -> void:
	Net.call_all(self, method, args)


func _team_members(team: int) -> Array:
	var out := []
	for id in info:
		if info[id].team == team:
			out.append(id)
	return out


func _team_objectives(team: int) -> Array:
	var have := []
	for id in info:
		if info[id].team == team and info[id].alive:
			for it in info[id].items:
				if not have.has(it):
					have.append(it)
	return have


func _sync_info(id: int) -> void:
	var i: Dictionary = info[id]
	_all("ev_info", [id, i.hp, i.alive, i.items, i.tools])


# =================================================================== requests

func rq_search(f: int) -> void:
	if not Net.is_host() or game_over:
		return
	var id := _sender()
	if not _valid_actor(id) or f < 0 or f >= furn_content.size():
		return
	if _interact_point(f).distance_to(agents[id].position) > INTERACT_RANGE + 1.0:
		return
	var trap: Dictionary = furn_trap[f]
	var fpos: Vector3 = layout.furniture[f].pos
	if not trap.is_empty() and trap.team != info[id].team:
		furn_trap[f] = {}
		_clear_trap("f", f, trap.team)
		if not _trigger_trap(id, trap, fpos):
			return  # died
	var item: String = furn_content[f]
	furn_content[f] = ""
	if item == "":
		_all("ev_searched", [id, f, ""])
		return
	if Maps.OBJECTIVES.has(item):
		info[id].items.append(item)
	else:
		info[id].tools.append(item)
	_sync_info(id)
	_all("ev_searched", [id, f, item])


func rq_trap(kind: String, idx: int, type: String) -> void:
	if not Net.is_host() or game_over:
		return
	var id := _sender()
	if not _valid_actor(id) or not Maps.TRAPS.has(type):
		return
	var team: int = info[id].team
	var trap := {"type": type, "team": team, "owner": id}
	if kind == "f" and Maps.TRAPS[type].where == "furniture" and idx >= 0 and idx < furn_trap.size():
		if not furn_trap[idx].is_empty():
			_send_to(id, "ev_feed", ["Something is already rigged there.", Color(1, 0.7, 0.4)])
			return
		furn_trap[idx] = trap
	elif kind == "d" and Maps.TRAPS[type].where == "door" and idx >= 0 and idx < door_trap.size():
		if not door_trap[idx].is_empty():
			_send_to(id, "ev_feed", ["That doorway is already rigged.", Color(1, 0.7, 0.4)])
			return
		door_trap[idx] = trap
	else:
		return
	for m in _team_members(team):
		_send_to(m, "ev_trap_known", [kind, idx, type])
	_send_spectators("ev_trap_known", [kind, idx, type])


func rq_attack() -> void:
	if not Net.is_host() or game_over:
		return
	var id := _sender()
	if not _valid_actor(id):
		return
	var a: Agent = agents[id]
	_all("ev_punch", [id])
	for other in agents:
		if other == id or not info[other].alive or is_teammate(id, other):
			continue
		var b: Agent = agents[other]
		var to := b.position - a.position
		to.y = 0
		if to.length() < PUNCH_RANGE and (to.length() < 0.6 or to.normalized().dot(a.facing()) > 0.35):
			_damage(other, PUNCH_DAMAGE, "%s was knocked out by %s" % [info[other].name, info[id].name], a.position, 9.0, 0.25, 0.0)


func _valid_actor(id: int) -> bool:
	return agents.has(id) and info[id].alive


# =================================================================== server logic

func _trigger_trap(victim: int, trap: Dictionary, pos: Vector3) -> bool:
	## Returns true if the victim survived.
	var def: Dictionary = Maps.TRAPS[trap.type]
	var counter: String = def.counter
	var vname: String = info[victim].name
	if info[victim].tools.has(counter):
		info[victim].tools.erase(counter)
		_sync_info(victim)
		_all("ev_fx", ["disarm", pos])
		_all("ev_feed", ["%s neutralised a %s with %s." % [vname, def.label, Maps.ITEM_LABELS[counter]], Color(0.6, 1, 0.7)])
		return true
	_all("ev_fx", [trap.type, pos])
	var owner_name: String = info[trap.owner].name if info.has(trap.owner) else "someone"
	var stun := 1.2 if trap.type == "shock" else 0.3
	var slow := 4.0 if trap.type == "gas" else 0.0
	_damage(victim, def.damage, "%s fell for %s's %s" % [vname, owner_name, def.label], pos, 12.0, stun, slow)
	return info[victim].alive


func _damage(id: int, amount: int, cause: String, from: Vector3, strength: float, stun: float, slow: float) -> void:
	if not info[id].alive:
		return
	info[id].hp = maxi(0, info[id].hp - amount)
	_sync_info(id)
	_all("ev_hit", [id, from, strength, stun, slow])
	if info[id].hp <= 0:
		_kill(id, cause)


func _kill(id: int, cause: String) -> void:
	info[id].alive = false
	# Scatter the agent's loot back into empty furniture
	var loot: Array = info[id].items + info[id].tools
	info[id].items = []
	info[id].tools = []
	var empties := []
	for i in furn_content.size():
		if furn_content[i] == "":
			empties.append(i)
	empties.shuffle()
	for it in loot:
		if not empties.is_empty():
			furn_content[empties.pop_back()] = it
	_sync_info(id)
	_all("ev_died", [id, cause, loot.size()])
	_check_win()


func _check_win() -> void:
	if game_over:
		return
	var alive_teams := {}
	for id in info:
		if info[id].alive:
			alive_teams[info[id].team] = true
	if initial_teams >= 2 and alive_teams.size() <= 1:
		if alive_teams.is_empty():
			_end("Mutual destruction — nobody made it out.", -999)
		else:
			var t: int = alive_teams.keys()[0]
			_end("%s is the last %s standing!" % [_team_label(t), "team" if mode == "teams" else "agent"], t)
	elif alive_teams.is_empty():
		_end("Mission failed.", -999)


func _team_label(team: int) -> String:
	if mode == "teams":
		return Maps.TEAM_NAMES[team]
	return info[team].name if info.has(team) else "?"


func _end(text: String, team: int) -> void:
	if game_over:
		return
	_all("ev_game_over", [text, team])


func _on_peer_left(id: int, was_host: bool) -> void:
	if was_host:
		# The host kept the match's secrets (where the intel is, the traps): without it the match is over.
		if not game_over:
			game_over = true
			hud.game_over("MATCH OVER", "The host left the match.", Color(1, 0.8, 0.4))
			hud.allow_local_return()
		return
	if Net.is_host() and _server_ready and info.has(id) and info[id].alive:
		_kill(id, "%s lost connection" % info[id].name)


func _server_tick(delta: float) -> void:
	time_left -= delta
	_time_sync -= delta
	if _time_sync <= 0.0:
		_time_sync = 5.0
		_all("ev_time", [time_left])
	if time_left <= 0.0:
		_timeout()
		return
	for id in agents:
		if not info[id].alive:
			continue
		var p: Vector3 = agents[id].position
		# Doorway traps
		for d in door_trap.size():
			var trap: Dictionary = door_trap[d]
			if trap.is_empty() or trap.team == info[id].team:
				continue
			var dp: Vector3 = layout.doors[d].pos
			if Vector2(p.x - dp.x, p.z - dp.z).length() < 0.9:
				door_trap[d] = {}
				_clear_trap("d", d, trap.team)
				_trigger_trap(id, trap, dp)
				if not info[id].alive:
					break
		if not info[id].alive or game_over:
			continue
		# Extraction
		if not layout.exit.is_empty():
			var ep: Vector3 = layout.exit.pos - layout.exit.normal * 0.8
			if Vector2(p.x - ep.x, p.z - ep.z).length() < 1.5:
				var have := _team_objectives(info[id].team)
				if have.size() >= Maps.OBJECTIVES.size():
					var who: String = info[id].name
					var label := "%s extracted with all the intel! %s wins." % [who, _team_label(info[id].team)] if mode == "teams" \
						else "%s extracted with all the intel and wins!" % who
					_end(label, info[id].team)
					return
				elif now() > _hint_t.get(id, 0.0):
					_hint_t[id] = now() + 3.0
					var missing := []
					for o in Maps.OBJECTIVES:
						if not have.has(o):
							missing.append(Maps.ITEM_LABELS[o])
					_send_to(id, "ev_feed", ["Extraction locked — still need: " + ", ".join(missing), Color(1, 0.8, 0.3)])


func _timeout() -> void:
	var best := -1
	var best_team := -999
	var tie := false
	for team in _alive_team_set():
		var c := _team_objectives(team).size()
		if c > best:
			best = c
			best_team = team
			tie = false
		elif c == best:
			tie = true
	if tie or best_team == -999:
		_end("Time's up — stalemate.", -999)
	else:
		_end("Time's up — %s held the most intel (%d/4)." % [_team_label(best_team), best], best_team)


func _alive_team_set() -> Array:
	var s := {}
	for id in info:
		if info[id].alive:
			s[info[id].team] = true
	return s.keys()


func _clear_trap(kind: String, idx: int, team: int) -> void:
	_all("ev_trap_cleared", [kind, idx])


func _send_spectators(method: String, args: Array) -> void:
	## Spectators (and the eliminated) see every trap.
	for id in config.players:
		if not info.has(id) or not info[id].alive:
			_send_to(id, method, args)


func _interact_point(f: int) -> Vector3:
	var fd: Dictionary = layout.furniture[f]
	if fd.type == "table":
		return fd.pos
	var fwd := Vector3(sin(fd.rot), 0, cos(fd.rot))
	return fd.pos + fwd * 0.9


# =================================================================== events (all peers)

func ev_info(id: int, hp: int, alive: bool, items: Array, tools: Array) -> void:
	if not info.has(id):
		return
	info[id].hp = hp
	info[id].alive = alive
	info[id].items = items
	info[id].tools = tools
	hud.refresh()


func ev_hit(id: int, from: Vector3, strength: float, stun: float, slow: float) -> void:
	if not agents.has(id):
		return
	var a: Agent = agents[id]
	a.apply_hit(from, strength, stun, slow)
	if id == my_id:
		shake = maxf(shake, 0.5)
		hud.flash_damage()


func ev_fx(kind: String, pos: Vector3) -> void:
	match kind:
		"mine", "tripwire":
			FX.explosion(self, pos)
		"gas":
			FX.gas(self, pos)
		"shock":
			FX.shock(self, pos)
		"disarm":
			FX.sparkle(self, pos, Color(0.6, 1, 0.8))
			FX.float_text(self, pos, "DISARMED", Color(0.6, 1, 0.8))
	if kind != "disarm" and local_agent() and local_agent().position.distance_to(pos) < 12.0:
		shake = maxf(shake, 0.9 - local_agent().position.distance_to(pos) * 0.06)


func ev_searched(id: int, f: int, item: String) -> void:
	if not agents.has(id):
		return
	var pos: Vector3 = agents[id].position
	var watching := id == my_id or _is_spectating()
	if not watching:
		return
	if item == "":
		FX.float_text(self, pos, "nothing…", Color(0.75, 0.75, 0.8))
	else:
		var c: Color = Maps.ITEM_COLORS[item]
		FX.sparkle(self, pos, c)
		FX.float_text(self, pos, "+ " + Maps.ITEM_LABELS[item].to_upper(), c)
		if id == my_id:
			hud.feed("You found the %s." % Maps.ITEM_LABELS[item], c)
		else:
			hud.feed("%s found the %s." % [info[id].name, Maps.ITEM_LABELS[item]], c)


func ev_punch(id: int) -> void:
	if agents.has(id) and id != my_id:
		agents[id].play_punch()


func ev_feed(text: String, color: Color) -> void:
	hud.feed(text, color)


func ev_trap_known(kind: String, idx: int, type: String) -> void:
	var key := "%s%d" % [kind, idx]
	known_traps[key] = type
	_place_marker(key, kind, idx, type)


func ev_trap_cleared(kind: String, idx: int) -> void:
	var key := "%s%d" % [kind, idx]
	known_traps.erase(key)
	if trap_markers.has(key):
		trap_markers[key].queue_free()
		trap_markers.erase(key)


func ev_died(id: int, cause: String, dropped: int) -> void:
	if not agents.has(id):
		return
	info[id].alive = false
	agents[id].set_dead()
	FX.sparkle(self, agents[id].position, Color(1, 0.4, 0.4))
	hud.feed(cause + (" — %d item(s) re-hidden" % dropped if dropped > 0 else ""), Color(1, 0.45, 0.45))
	if id == my_id:
		hud.big_message("ELIMINATED", "Entering spectator mode…", Color(1, 0.35, 0.35))
		get_tree().create_timer(1.6).timeout.connect(_enter_spectator)
	spectator.rebuild()
	hud.refresh()


func ev_time(t: float) -> void:
	if not Net.is_host():
		time_left = t


func ev_game_over(text: String, team: int) -> void:
	game_over = true
	var mine: bool = info.has(my_id) and info[my_id].team == team
	var title := "VICTORY" if mine else ("MATCH OVER" if team == -999 or not info.has(my_id) else "DEFEAT")
	var col := Color(0.4, 1, 0.6) if mine else Color(1, 0.8, 0.4)
	hud.game_over(title, text, col)
	_reveal_all()
	spectator.rebuild()


# =================================================================== local play

func _is_spectating() -> bool:
	return am_spectator or not info.has(my_id) or not info[my_id].alive


func _enter_spectator() -> void:
	am_spectator = true
	_reveal_all()
	spectator.open()
	hud.set_spectating(true)


func _reveal_all() -> void:
	for l in builder.room_lights:
		l.light_energy = layout.theme.light_energy
	for id in agents:
		agents[id].set_world_visible(true)


func _place_marker(key: String, kind: String, idx: int, type: String) -> void:
	if trap_markers.has(key):
		trap_markers[key].queue_free()
	var pos: Vector3 = layout.furniture[idx].pos if kind == "f" else layout.doors[idx].pos
	var c: Color = Maps.TRAPS[type].color
	var marker := Node3D.new()
	marker.position = pos + Vector3(0, 0.05, 0)
	add_child(marker)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.65
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	ring.material_override = m
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "f":
		ring.position = _interact_point(idx) - pos
	marker.add_child(ring)
	var lbl := Label3D.new()
	lbl.text = Maps.TRAPS[type].label
	lbl.font_size = 28
	lbl.outline_size = 8
	lbl.modulate = c
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position = ring.position + Vector3(0, 1.4, 0)
	marker.add_child(lbl)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3.ONE * 1.15, 0.6)
	tw.tween_property(ring, "scale", Vector3.ONE, 0.6)
	trap_markers[key] = marker


func nearest_furniture(pos: Vector3) -> int:
	var best := -1
	var bd := INTERACT_RANGE
	for i in layout.furniture.size():
		var d := _interact_point(i).distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


func nearest_door(pos: Vector3) -> int:
	var best := -1
	var bd := DOOR_RANGE
	for i in layout.doors.size():
		var d: float = layout.doors[i].pos.distance_to(pos)
		if d < bd:
			bd = d
			best = i
	return best


func selected_trap() -> String:
	return Maps.TRAP_ORDER[trap_sel]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_spectate_layout") and _is_spectating():
		spectator.cycle_focus()
	if game_over or _is_spectating():
		return
	for i in 4:
		if event.is_action_pressed("trap_%d" % (i + 1)):
			trap_sel = i
			hud.refresh()
	if event.is_action_pressed("trap_next"):
		trap_sel = (trap_sel + 1) % 4
		hud.refresh()
	if event.is_action_pressed("trap_prev"):
		trap_sel = (trap_sel + 3) % 4
		hud.refresh()
	if event.is_action_pressed("search"):
		do_search()
	elif event.is_action_pressed("set_trap"):
		do_trap()
	elif event.is_action_pressed("attack"):
		do_attack()


func do_search() -> void:
	var a := local_agent()
	if a == null or not a.can_act() or game_over:
		return
	var f := nearest_furniture(a.position)
	if f >= 0:
		_begin_action({"kind": "search", "idx": f}, SEARCH_TIME)


func do_trap() -> void:
	var a := local_agent()
	if a == null or not a.can_act() or game_over:
		return
	var t := selected_trap()
	if now() < trap_ready[t]:
		hud.feed("%s recharging…" % Maps.TRAPS[t].label, Color(1, 0.7, 0.4))
		return
	var idx := nearest_furniture(a.position) if Maps.TRAPS[t].where == "furniture" else nearest_door(a.position)
	if idx < 0:
		hud.feed("%s goes on %s." % [Maps.TRAPS[t].label, "furniture" if Maps.TRAPS[t].where == "furniture" else "a doorway"], Color(1, 0.7, 0.4))
		return
	_begin_action({"kind": "trap", "idx": idx, "type": t}, TRAP_TIME)


func do_attack() -> void:
	var a := local_agent()
	if a == null or not a.can_act() or game_over:
		return
	if now() >= attack_ready:
		attack_ready = now() + PUNCH_COOLDOWN
		a.play_punch()
		FX.punch(self, a.position + a.facing() * 0.8)
		_to_server("rq_attack", [])


func _begin_action(action: Dictionary, duration: float) -> void:
	var a := local_agent()
	a.busy_until = now() + duration
	action.end = now() + duration
	action.duration = duration
	pending_action = action


func _process(delta: float) -> void:
	if not Net.is_host():
		time_left = maxf(0.0, time_left - delta)
	elif not game_over and _server_ready:
		_server_tick(delta)

	var a := local_agent()
	# Finish a pending search / trap action
	if not pending_action.is_empty() and now() >= pending_action.end:
		var act := pending_action
		pending_action = {}
		if a and a.alive and not game_over:
			if act.kind == "search":
				_to_server("rq_search", [act.idx])
			else:
				trap_ready[act.type] = now() + TRAP_COOLDOWN
				_to_server("rq_trap", ["f" if Maps.TRAPS[act.type].where == "furniture" else "d", act.idx, act.type])
	if a and a.alive and not pending_action.is_empty() and now() < a.stun_until:
		pending_action = {}  # interrupted

	if bot_mode and a and a.alive and not game_over:
		_bot_tick(delta, a)
	_update_camera(delta)
	_update_visibility()
	hud.update_frame()


func _update_camera(delta: float) -> void:
	var target := Vector3.ZERO
	var a := local_agent()
	if a and not _is_spectating():
		target = a.position
	else:
		var c := Vector3.ZERO
		for r in layout.rooms:
			c += r.center
		target = c / maxf(1.0, layout.rooms.size())
	var dist := 13.0
	var want := target + Vector3(0, dist, dist * 0.43)
	camera.position = camera.position.lerp(want, 1.0 - exp(-6.0 * delta))
	var shake_off := Vector3.ZERO
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 1.8)
		shake_off = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * shake * 0.35
	camera.look_at(camera.position - Vector3(0, dist, dist * 0.43) + shake_off)


func _update_visibility() -> void:
	if _is_spectating() or game_over:
		return
	var a := local_agent()
	var room := Maps.room_at(layout, a.position)
	if room != current_room and room >= 0:
		current_room = room
		for i in builder.room_lights.size():
			var target_e: float = layout.theme.light_energy * (1.0 if i == room else 0.06)
			builder.room_lights[i].shadow_enabled = i == room
			var tw := create_tween()
			tw.tween_property(builder.room_lights[i], "light_energy", target_e, 0.35)
		hud.set_room(layout.rooms[room].name)
	for id in agents:
		if id == my_id:
			continue
		var other: Agent = agents[id]
		var r := Maps.room_at(layout, other.position)
		var near_door := false
		if r != current_room:
			# Still visible while standing in a doorway of my room
			var d := nearest_door(other.position)
			near_door = d >= 0 and layout.doors[d].rooms.has(current_room)
		other.set_world_visible(r == current_room or near_door or not other.alive and r == current_room)
