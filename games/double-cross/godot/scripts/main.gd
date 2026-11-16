extends Node
## Menu, lobby and match lifecycle.
## In the browser, online matches come from icelander.net's multiplayer page (?match=ID); on the
## desktop, one player hosts and the others join by IP address. Either way you can practise alone.
## CLI (after `--`): --host  --join=IP  --solo  --name=NAME  --map=ID  --mode=lms|teams
##                   --autostart=N (host: start when N agents are ready)  --spectate

var ui: Control
var menu_box: Control
var lobby_box: Control
var status_label: Label
var name_edit: LineEdit
var ip_edit: LineEdit
var port_edit: LineEdit
var players_list: VBoxContainer
var map_opt: OptionButton
var mode_opt: OptionButton
var map_info: Label
var team_row: HBoxContainer
var spect_check: CheckBox
var start_btn: Button
var game: Game
var _autostart := 0
var _cli := {}


func _ready() -> void:
	_setup_input()
	_build_ui()
	Net.lobby_changed.connect(_refresh_lobby)
	Net.status.connect(func(m): status_label.text = m)
	Net.game_started.connect(_on_game_started)
	Net.back_to_lobby.connect(_on_back_to_lobby)
	Net.disconnected.connect(_on_back_to_lobby)
	_parse_cli()
	if OS.has_feature("web"):
		var id = JavaScriptBridge.eval("new URLSearchParams(location.search).get('match') || ''")
		if id is String and RegEx.create_from_string("^[A-Za-z0-9_-]{8,40}$").search(id):
			Net.join_match(id, str(JavaScriptBridge.eval("location.origin")))


# ------------------------------------------------------------------ input map

func _setup_input() -> void:
	var keys := {
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"search": [KEY_E], "set_trap": [KEY_F], "attack": [KEY_SPACE],
		"trap_1": [KEY_1], "trap_2": [KEY_2], "trap_3": [KEY_3], "trap_4": [KEY_4],
		"trap_next": [KEY_Q], "trap_prev": [], "toggle_spectate_layout": [KEY_TAB],
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack", mb)
	var wu := InputEventMouseButton.new()
	wu.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event("trap_prev", wu)
	var wd := InputEventMouseButton.new()
	wd.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event("trap_next", wd)
	# Gamepad
	var pads := {"search": JOY_BUTTON_A, "attack": JOY_BUTTON_X, "set_trap": JOY_BUTTON_B,
		"trap_next": JOY_BUTTON_RIGHT_SHOULDER, "trap_prev": JOY_BUTTON_LEFT_SHOULDER,
		"toggle_spectate_layout": JOY_BUTTON_Y}
	for action in pads:
		var j := InputEventJoypadButton.new()
		j.button_index = pads[action]
		InputMap.action_add_event(action, j)
	var axes := {"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
		"move_up": [JOY_AXIS_LEFT_Y, -1.0], "move_down": [JOY_AXIS_LEFT_Y, 1.0]}
	for action in axes:
		var j := InputEventJoypadMotion.new()
		j.axis = axes[action][0]
		j.axis_value = axes[action][1]
		InputMap.action_add_event(action, j)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ui)
	var t := Theme.new()
	t.default_font_size = 17
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0.12, 0.16, 0.22)
	btn.set_corner_radius_all(8)
	btn.content_margin_left = 16
	btn.content_margin_right = 16
	btn.content_margin_top = 8
	btn.content_margin_bottom = 8
	var hov := btn.duplicate()
	hov.bg_color = Color(0.18, 0.28, 0.38)
	var prs := btn.duplicate()
	prs.bg_color = Color(0.1, 0.55, 0.7)
	for cls in ["Button", "OptionButton"]:
		t.set_stylebox("normal", cls, btn)
		t.set_stylebox("hover", cls, hov)
		t.set_stylebox("pressed", cls, prs)
		t.set_stylebox("focus", cls, StyleBoxEmpty.new())
	var le := StyleBoxFlat.new()
	le.bg_color = Color(0.06, 0.08, 0.11)
	le.set_corner_radius_all(6)
	le.set_border_width_all(1)
	le.border_color = Color(1, 1, 1, 0.12)
	le.content_margin_left = 10
	le.content_margin_top = 6
	le.content_margin_bottom = 6
	t.set_stylebox("normal", "LineEdit", le)
	ui.theme = t

	var bg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0.03, 0.05, 0.09))
	grad.set_color(1, Color(0.08, 0.04, 0.10))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.3, 0.2)
	gt.fill_to = Vector2(1.2, 1.2)
	bg.texture = gt
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	ui.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.custom_minimum_size = Vector2(720, 0)
	center.add_child(col)

	var title := HUD.lbl("DOUBLE CROSS", 84, Color(0.92, 0.95, 1.0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 0)
	col.add_child(title)
	var tag := HUD.lbl("SEARCH · SABOTAGE · EXTRACT", 16, Color(0.35, 0.85, 1.0))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tag)

	# --- main menu
	var mp := PanelContainer.new()
	mp.add_theme_stylebox_override("panel", HUD.panel_style(0.75, Color(1, 1, 1, 0.1)))
	col.add_child(mp)
	menu_box = mp
	var mv := VBoxContainer.new()
	mv.add_theme_constant_override("separation", 12)
	mp.add_child(mv)
	var web := OS.has_feature("web")
	name_edit = _field(mv, "Codename", "Agent %d" % (randi() % 900 + 100))
	if not web:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		mv.add_child(row)
		ip_edit = _field(row, "Host address", "127.0.0.1")
		ip_edit.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
		port_edit = _field(row, "Port", str(Net.DEFAULT_PORT))
		port_edit.custom_minimum_size.x = 110
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 10)
	mv.add_child(brow)
	if web:
		var online_b := Button.new()
		online_b.text = "Play online with friends"
		online_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		online_b.pressed.connect(func(): JavaScriptBridge.eval("location.href = '/games/multiplayer/'"))
		brow.add_child(online_b)
	else:
		var host_b := Button.new()
		host_b.text = "Host a game"
		host_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		host_b.pressed.connect(func(): Net.host(int(port_edit.text), name_edit.text))
		brow.add_child(host_b)
		var join_b := Button.new()
		join_b.text = "Join game"
		join_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		join_b.pressed.connect(func(): Net.join(ip_edit.text.strip_edges(), int(port_edit.text), name_edit.text))
		brow.add_child(join_b)
	var solo_b := Button.new()
	solo_b.text = "Practise alone"
	solo_b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	solo_b.pressed.connect(func(): Net.solo(name_edit.text))
	brow.add_child(solo_b)
	if web:
		var note := HUD.lbl("Online matches start from the multiplayer page: invite friends there, and everyone lands in this briefing room together.", 13, Color(1, 1, 1, 0.5))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mv.add_child(note)

	# --- lobby
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", HUD.panel_style(0.75, Color(1, 1, 1, 0.1)))
	col.add_child(lp)
	lobby_box = lp
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 12)
	lp.add_child(lv)
	lv.add_child(HUD.lbl("BRIEFING ROOM", 14, Color(1, 1, 1, 0.5)))
	var settings := HBoxContainer.new()
	settings.add_theme_constant_override("separation", 10)
	lv.add_child(settings)
	map_opt = OptionButton.new()
	map_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for id in Maps.ids():
		map_opt.add_item("%s  (max %d)" % [Maps.DEFS[id].name, Maps.DEFS[id].max_players])
	map_opt.item_selected.connect(func(_i): _push_settings())
	settings.add_child(map_opt)
	mode_opt = OptionButton.new()
	mode_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_opt.add_item("Last Agent Standing")
	mode_opt.add_item("Co-op Teams")
	mode_opt.item_selected.connect(func(_i): _push_settings())
	settings.add_child(mode_opt)
	map_info = HUD.lbl("", 14, Color(1, 1, 1, 0.65))
	map_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lv.add_child(map_info)
	players_list = VBoxContainer.new()
	players_list.add_theme_constant_override("separation", 6)
	lv.add_child(players_list)
	team_row = HBoxContainer.new()
	team_row.add_theme_constant_override("separation", 10)
	lv.add_child(team_row)
	for i in 2:
		var tb := Button.new()
		tb.text = "Join " + Maps.TEAM_NAMES[i]
		tb.add_theme_color_override("font_color", Maps.TEAM_COLORS[i])
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.pressed.connect(Net.set_team.bind(i))
		team_row.add_child(tb)
	var lrow := HBoxContainer.new()
	lrow.add_theme_constant_override("separation", 10)
	lv.add_child(lrow)
	spect_check = CheckBox.new()
	spect_check.text = "Spectate only"
	spect_check.toggled.connect(Net.set_spectator)
	lrow.add_child(spect_check)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lrow.add_child(spacer)
	var leave_b := Button.new()
	leave_b.text = "Leave"
	leave_b.pressed.connect(Net.leave)
	lrow.add_child(leave_b)
	start_btn = Button.new()
	start_btn.text = "Start mission"
	start_btn.pressed.connect(Net.start_game)
	lrow.add_child(start_btn)

	status_label = HUD.lbl("", 15, Color(1, 0.85, 0.5))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(status_label)
	var help := HUD.lbl("Search furniture for the four pieces of intel, rig furniture and doorways with traps, carry counter-gadgets, and reach the extraction door.\nDie and you keep watching every surviving agent in spectator mode.", 13, Color(1, 1, 1, 0.45))
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(help)
	_refresh_lobby()


func _field(parent: Control, label: String, value: String) -> LineEdit:
	var v := VBoxContainer.new()
	parent.add_child(v)
	v.add_child(HUD.lbl(label.to_upper(), 12, Color(1, 1, 1, 0.5)))
	var e := LineEdit.new()
	e.text = value
	v.add_child(e)
	return e


func _push_settings() -> void:
	Net.set_settings(Maps.ids()[map_opt.selected], "teams" if mode_opt.selected == 1 else "lms")


func _refresh_lobby() -> void:
	var online := Net.is_online() and not Net.players.is_empty() and Net.players.has(Net.my_id)
	menu_box.visible = not online
	lobby_box.visible = online
	if not online:
		return
	var is_host := Net.is_host()
	map_opt.disabled = not is_host
	mode_opt.disabled = not is_host
	start_btn.visible = is_host
	map_opt.selected = Maps.ids().find(Net.settings.map)
	mode_opt.selected = 1 if Net.settings.mode == "teams" else 0
	var def: Dictionary = Maps.DEFS[Net.settings.map]
	var teams: bool = Net.settings.mode == "teams"
	team_row.visible = teams
	var n := Net.active_players().size()
	map_info.text = "%s — %s  ·  %d/%d agents" % [def.name, def.blurb, n, def.max_players]
	for c in players_list.get_children():
		c.queue_free()
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		var p: Dictionary = Net.players[id]
		var col: Color = Maps.TEAM_COLORS[p.team] if teams else Maps.PLAYER_COLORS[p.color]
		var r := HBoxContainer.new()
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(12, 12)
		dot.color = col if not p.spectator else Color(0.4, 0.4, 0.45)
		var dc := CenterContainer.new()
		dc.add_child(dot)
		r.add_child(dc)
		var txt: String = p.name
		if id == 1:
			txt += "  (host)"
		if id == Net.my_id:
			txt += "  (you)"
		r.add_child(HUD.lbl("  " + txt, 17))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		r.add_child(sp)
		var role: String = "SPECTATOR" if p.spectator else (Maps.TEAM_NAMES[p.team].to_upper() if teams else "AGENT")
		r.add_child(HUD.lbl(role, 13, Color(1, 1, 1, 0.55) if p.spectator else col))
		players_list.add_child(r)
	if Net.players.has(Net.my_id):
		spect_check.set_pressed_no_signal(Net.players[Net.my_id].spectator)
	if is_host:
		var reason := Net.can_start()
		start_btn.disabled = reason != ""
		start_btn.tooltip_text = reason
		if _autostart > 0 and Net.active_players().size() >= _autostart and reason == "":
			_autostart = 0
			if _cli.has("map") and Net.transport == "relay":
				Net.set_settings(_cli.map, _cli.get("mode", "lms"))
			Net.start_game.call_deferred()


# ------------------------------------------------------------------ match lifecycle

func _on_game_started(config: Dictionary) -> void:
	if game:
		game.free()
	ui.get_parent().visible = false
	ui.visible = false
	game = Game.new()
	game.name = "Game"
	add_child(game)
	game.start(config)


func _on_back_to_lobby() -> void:
	if game:
		game.queue_free()
		game = null
	ui.visible = true
	ui.get_parent().visible = true
	_refresh_lobby()


# ------------------------------------------------------------------ CLI (testing)

func _parse_cli() -> void:
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		_cli[parts[0]] = parts[1] if parts.size() > 1 else "1"
	if _cli.has("quit-after"):
		get_tree().create_timer(float(_cli["quit-after"])).timeout.connect(get_tree().quit)
	if _cli.has("shot"):
		# --shot=path.png --shot-at=seconds : save a screenshot (for docs/testing)
		get_tree().create_timer(float(_cli.get("shot-at", "6"))).timeout.connect(func():
			get_viewport().get_texture().get_image().save_png(_cli.shot))
	if _cli.has("selftest"):
		get_tree().create_timer(4.0).timeout.connect(_selftest)
	if _cli.has("name"):
		name_edit.text = _cli.name
	if _cli.has("host"):
		Net.host(int(_cli.get("port", Net.DEFAULT_PORT)), name_edit.text)
		Net.set_settings(_cli.get("map", "embassy"), _cli.get("mode", "lms"))
		_refresh_lobby()
	_autostart = int(_cli.get("autostart", "0"))
	if _cli.has("match"):
		# The hub's relay, from the desktop (testing): --match=ID --relay=ws://127.0.0.1:8787
		Net.join_match(_cli.match, _cli.get("relay", "https://icelander.net"))
	elif _cli.has("solo"):
		_autostart = 0
		Net.solo(name_edit.text)
		_autostart = int(_cli.get("autostart", "0"))
		Net.set_settings(_cli.get("map", "embassy"), _cli.get("mode", "lms"))
	elif _cli.has("join"):
		Net.join(_cli.join, int(_cli.get("port", Net.DEFAULT_PORT)), name_edit.text)
	if _cli.has("spectate"):
		Net.lobby_changed.connect(func():
			if Net.players.has(Net.my_id) and not Net.players[Net.my_id].spectator:
				Net.set_spectator(true), CONNECT_ONE_SHOT)


func _selftest() -> void:
	## Host-only: fire traps at agents to exercise damage, death, loot drop and win logic.
	if game == null or not Net.is_host():
		return
	var ids: Array = game.agents.keys()
	ids.sort()
	var victim: int = ids.back()
	var owner: int = ids[0]
	var pos: Vector3 = game.agents[victim].position
	print("SELFTEST: mine on ", victim)
	game._trigger_trap(victim, {"type": "mine", "team": game.info[owner].team, "owner": owner}, pos)
	print("SELFTEST hp=", game.info[victim].hp)
	game.info[victim].tools.append("gasmask")
	game._trigger_trap(victim, {"type": "gas", "team": game.info[owner].team, "owner": owner}, pos)
	print("SELFTEST after gasmask hp=", game.info[victim].hp, " tools=", game.info[victim].tools)
	game._trigger_trap(victim, {"type": "tripwire", "team": game.info[owner].team, "owner": owner}, pos)
	print("SELFTEST alive=", game.info[victim].alive)
