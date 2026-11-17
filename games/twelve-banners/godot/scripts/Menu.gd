class_name Menu
extends CanvasLayer
## Title screen + multiplayer lobby.

var root: Control
var home: Control
var lobby_box: Control
var name_edit: LineEdit
var addr_edit: LineEdit
var port_edit: LineEdit
var status_lbl: Label
var players_list: VBoxContainer
var ai_lbl: Label
var size_opt: OptionButton
var start_btn: Button
var lobby_info: Label
var total_lbl: Label

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UiTheme.build()
	add_child(root)
	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var grad := Gradient.new()
	grad.set_color(0, Color("0b1424"))
	grad.set_color(1, Color("1d3a4f"))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.35)
	gt.fill_to = Vector2(1.2, 1.2)
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.modulate = Color(1, 1, 1, 0.82)
	root.add_child(bg)
	_build_home()
	_build_lobby()
	Net.lobby_changed.connect(_on_lobby)
	Net.status.connect(func(t): status_lbl.text = t)
	Net.connection_failed.connect(func(r):
		status_lbl.text = r
		show_home())
	Net.disconnected.connect(func():
		status_lbl.text = "Disconnected from host."
		show_home())
	show_home()

func _center_panel(w: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	var s := UiTheme.sb(Color(0.06, 0.08, 0.12, 0.88), 18, Color(1, 1, 1, 0.08), 1, 28)
	pc.add_theme_stylebox_override("panel", s)
	root.add_child(pc)
	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(w, 0)
	vb.add_theme_constant_override("separation", 12)
	pc.add_child(vb)
	return vb

func _build_home() -> void:
	var vb := _center_panel(420)
	home = vb.get_parent()
	var title := UiTheme.label("TWELVE BANNERS", 48, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(title)
	var sub := UiTheme.label("Raise your banner. Outlast eleven rivals.", 15, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(sub)
	vb.add_child(HSeparator.new())
	vb.add_child(UiTheme.label("Your name", 13, UiTheme.MUTED))
	name_edit = LineEdit.new()
	name_edit.text = "Player%d" % (randi() % 900 + 100)
	name_edit.max_length = 20
	vb.add_child(name_edit)
	var sp := UiTheme.button("Single Player", func():
		Net.host_offline(_name())
		show_lobby(), 18)
	sp.custom_minimum_size.y = 46
	vb.add_child(sp)
	vb.add_child(HSeparator.new())
	vb.add_child(UiTheme.label("Multiplayer (up to 12 players)", 13, UiTheme.MUTED))
	if not Net.CAN_HOST:
		# ENet isn't available in a browser: online games are in the desktop builds for now.
		var web_note := UiTheme.label("Online games with friends are in the desktop builds for now. In the browser you play against the computer.", 13, UiTheme.MUTED)
		web_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(web_note)
	var hb := HBoxContainer.new()
	hb.visible = Net.CAN_HOST
	vb.add_child(hb)
	addr_edit = LineEdit.new()
	addr_edit.text = "127.0.0.1"
	addr_edit.placeholder_text = "Host address"
	addr_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(addr_edit)
	port_edit = LineEdit.new()
	port_edit.text = str(Net.DEFAULT_PORT)
	port_edit.custom_minimum_size.x = 90
	hb.add_child(port_edit)
	var hb2 := HBoxContainer.new()
	hb2.add_theme_constant_override("separation", 10)
	vb.add_child(hb2)
	var host := UiTheme.button("Host Game", func():
		var err := Net.host_online(_name(), int(port_edit.text))
		if err != OK:
			status_lbl.text = "Could not open port %s (error %d)." % [port_edit.text, err]
		else:
			show_lobby(), 16)
	host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(host)
	var join := UiTheme.button("Join Game", func():
		var err := Net.join(_name(), addr_edit.text.strip_edges(), int(port_edit.text))
		if err != OK:
			status_lbl.text = "Could not connect (error %d)." % err, 16)
	join.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(join)
	status_lbl = UiTheme.label("", 13, Color("ffb37a"))
	status_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(status_lbl)
	var help := UiTheme.label("Controls: left-click select · right-click move/attack · WASD/edge pan · wheel zoom · Q/E rotate · Enter end turn · T tech tree · F fortify · B found city · Space skip", 12, UiTheme.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(help)
	if not OS.has_feature("web"):
		vb.add_child(UiTheme.button("Quit", func(): get_tree().quit(), 14))

func _name() -> String:
	var n := name_edit.text.strip_edges()
	return n if n != "" else "Player"

func _build_lobby() -> void:
	var vb := _center_panel(480)
	lobby_box = vb.get_parent()
	var t := UiTheme.label("Game Lobby", 30, UiTheme.ACCENT)
	vb.add_child(t)
	lobby_info = UiTheme.label("", 13, UiTheme.MUTED)
	lobby_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lobby_info)
	vb.add_child(HSeparator.new())
	total_lbl = UiTheme.label("", 15)
	vb.add_child(total_lbl)
	players_list = VBoxContainer.new()
	vb.add_child(players_list)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	vb.add_child(hb)
	hb.add_child(UiTheme.label("AI opponents", 15))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sp)
	hb.add_child(UiTheme.button(" − ", func(): Net.set_ai_count(Net.lobby.ai_count - 1)))
	ai_lbl = UiTheme.label("0", 18, UiTheme.ACCENT)
	ai_lbl.custom_minimum_size.x = 30
	ai_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(ai_lbl)
	hb.add_child(UiTheme.button(" + ", func(): Net.set_ai_count(Net.lobby.ai_count + 1)))
	var hb2 := HBoxContainer.new()
	vb.add_child(hb2)
	hb2.add_child(UiTheme.label("Map size", 15))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb2.add_child(sp2)
	size_opt = OptionButton.new()
	for s in Defs.MAP_SIZES:
		size_opt.add_item("%s (%d×%d)" % [s.name, s.w, s.h])
	size_opt.item_selected.connect(func(i): Net.set_map_size(i))
	hb2.add_child(size_opt)
	vb.add_child(HSeparator.new())
	var hb3 := HBoxContainer.new()
	hb3.add_theme_constant_override("separation", 10)
	vb.add_child(hb3)
	var back := UiTheme.button("Leave", func():
		Net.leave()
		show_home(), 16)
	hb3.add_child(back)
	start_btn = UiTheme.button("Start Game", func(): Net.start_game(), 18)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_btn.custom_minimum_size.y = 46
	hb3.add_child(start_btn)

func show_home() -> void:
	visible = true
	home.visible = true
	lobby_box.visible = false

func show_lobby() -> void:
	visible = true
	home.visible = false
	lobby_box.visible = true
	status_lbl.text = ""
	_on_lobby()

func _on_lobby() -> void:
	if Net.online and not Net.is_host and not lobby_box.visible:
		home.visible = false
		lobby_box.visible = true
	for ch in players_list.get_children():
		ch.queue_free()
	var idx := 0
	for hmn in Net.lobby.humans:
		var c: Color = Defs.PLAYER_COLORS[idx]
		var l := UiTheme.label("●  %s%s" % [hmn.name, "  (host)" if hmn.peer == 1 else ""], 15, c.lightened(0.2))
		players_list.add_child(l)
		idx += 1
	for i in Net.lobby.ai_count:
		var c: Color = Defs.PLAYER_COLORS[idx]
		players_list.add_child(UiTheme.label("●  AI opponent", 14, c.darkened(0.1)))
		idx += 1
	ai_lbl.text = str(Net.lobby.ai_count)
	total_lbl.text = "Players: %d / %d" % [Net.total_players(), Defs.MAX_PLAYERS]
	size_opt.select(Net.lobby.map_size)
	size_opt.disabled = not Net.is_host
	start_btn.disabled = not Net.is_host or Net.total_players() < 2
	start_btn.text = "Start Game" if Net.is_host else "Waiting for host…"
	if Net.online and Net.is_host:
		var ips := []
		for a in IP.get_local_addresses():
			if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"):
				ips.append(a)
		lobby_info.text = "Hosting on port %s. Friends join at: %s\nFor internet play, forward UDP port %s on your router." % [port_edit.text, ", ".join(ips) if not ips.is_empty() else "your IP", port_edit.text]
	elif Net.online:
		lobby_info.text = "Connected. The host will start the game."
	else:
		lobby_info.text = "Single player game against the AI."
