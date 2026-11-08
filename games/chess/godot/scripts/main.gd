class_name Main
extends Control
## The game's shell: the 3D table behind everything, a top bar, and one screen at a time in front:
##   home      title, the two ways to play, sign-in
##   setup     the computer's strength and your colour
##   lobby     invite by email, invitations, games in play, contacts
##   contact   one contact: your record and every game against them
##   history   every finished game
##   game      a game (online, computer, or a replay)

static var instance: Main

const LEVELS := [
	["Pawn Pusher", "Just learned the moves", "~400"],
	["Weekend Player", "Plays fast, leaves pieces hanging", "~800"],
	["Club Novice", "Knows a few tricks", "~1100"],
	["Café Regular", "Punishes loose pieces", "~1400"],
	["Club Captain", "Solid and patient", "~1700"],
	["County Champion", "Sees tactics you miss", "~2000"],
	["Master", "Bring your best game", "~2300"],
	["Stockfish", "Full strength", "2800+"],
]
const SAVE := "user://computer.json"
const LOCAL_HISTORY := "user://history.json"

var board: Board3D
var _viewport_box: SubViewportContainer
var _veil: ColorRect
var _bar: HBoxContainer
var _user_slot: HBoxContainer
var _screen: Control
var _screen_name := ""
var _history_stack: Array[String] = []
var _toast: PanelContainer
var _pending_challenge := ""
var _lobby_timer: Timer


func _ready() -> void:
	instance = self
	theme = UI.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	_viewport_box = SubViewportContainer.new()
	_viewport_box.stretch = true
	_viewport_box.set_anchors_preset(Control.PRESET_FULL_RECT)
	var vp := SubViewport.new()
	vp.msaa_3d = Viewport.MSAA_4X
	vp.handle_input_locally = true
	vp.physics_object_picking = false
	_viewport_box.add_child(vp)
	board = Board3D.new()
	vp.add_child(board)
	add_child(_viewport_box)

	# A veil over the table, darker behind lists, gone during a game.
	_veil = ColorRect.new()
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.color = Color(UI.BG, 0.0)
	add_child(_veil)

	var bar_wrap := MarginContainer.new()
	bar_wrap.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar_wrap.offset_bottom = 72
	bar_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		bar_wrap.add_theme_constant_override("margin_" + side, 28)
	bar_wrap.add_theme_constant_override("margin_top", 18)
	_bar = UI.hbox(18)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var logo := UI.button("Gambit", func() -> void: go("home"), "Ghost")
	logo.add_theme_font_override("font", UI.italic)
	logo.add_theme_font_size_override("font_size", 28)
	logo.add_theme_color_override("font_color", UI.INK)
	logo.add_theme_color_override("font_hover_color", UI.GOLD)
	_bar.add_child(logo)
	for item in [["Play", "home"], ["Friends", "lobby"], ["History", "history"]]:
		_bar.add_child(UI.button(item[0], func() -> void: go(item[1]), "Ghost"))
	_bar.add_child(UI.spacer())
	var sound := UI.button("Sound on", func() -> void: pass, "Ghost")
	sound.pressed.connect(func() -> void:
		Sfx.muted = not Sfx.muted
		sound.text = "Sound off" if Sfx.muted else "Sound on")
	_bar.add_child(sound)
	_user_slot = UI.hbox(10)
	_bar.add_child(_user_slot)
	bar_wrap.add_child(_bar)
	add_child(bar_wrap)

	_lobby_timer = Timer.new()
	_lobby_timer.wait_time = 10.0
	add_child(_lobby_timer)

	Api.me_changed.connect(_render_user)
	_pending_challenge = Api.challenge_in_address()
	await Api.load_me()
	if _pending_challenge != "":
		go("lobby")
	else:
		go("home")
	if not Api.is_web():
		_dev_args()


## Desktop-only switches for development and the design's reference renders (docs/screens/):
##   --goto=setup|lobby|history|computer|game|contact   --id=GAME   --contact=EMAIL   --moves=e2e4,e7e5
##   --select=e2   --promote=b7a8   --view=PLY   --seek=ENTRY   --play   --face=1   --toast=TEXT   --error-toast=TEXT
##   --click=X,Y;X,Y   --invite=EMAIL   --shot=file.png --shot-after=SECONDS
func _dev_args() -> void:
	var opts := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and "=" in a:
			opts[a.substr(2).get_slice("=", 0)] = a.get_slice("=", 1)
	match str(opts.get("goto", "")):
		"setup", "lobby", "history":
			go(opts.goto)
		"computer":
			var g := _new_computer_game(3, true)
			for m in str(opts.get("moves", "")).split(",", false):
				g.moves.append(m)
				g.events.append({seq = g.events.size() + 1, at = g.created + 1000.0 * g.moves.size(), kind = "move", side = "white" if g.moves.size() % 2 else "black", text = m})
			go("game", GameScreen.new("computer", g, board))
		"game":
			_open_game(str(opts.get("id", "")), str(opts.get("mode", "")))
		"contact":
			var r := await Api.get_json("api/lobby")
			for c in r.data.get("contacts", []):
				if c.email == opts.get("contact"):
					go("contact", c)
	if opts.has("select") or opts.has("promote") or opts.has("view") or opts.has("seek") or opts.has("play") or opts.has("face"):
		await get_tree().create_timer(2.5).timeout
		var gs := _screen as GameScreen
		if opts.has("face"):
			board.face(int(opts.face), true)
		if opts.has("view"):
			gs._jump_to_ply(int(opts.view))
		if opts.has("seek"):
			gs._stop_and_seek(int(opts.seek))
		if opts.has("play"):
			gs._toggle_play()
		if opts.has("select"):
			board._select(Chess.square(str(opts.select)))
		if opts.has("promote"):
			board._select(Chess.square(str(opts.promote).substr(0, 2)))
			board._try(Chess.square(str(opts.promote).substr(2, 2)))
	if opts.has("toast"):
		toast(str(opts.toast))
	if opts.has("error-toast"):
		toast(str(opts.get("error-toast")), true)
	if opts.has("cycle"):
		for i in int(opts.cycle):
			for screen in ["lobby", "home", "history", "lobby", "setup"]:
				go(screen)
				await get_tree().create_timer(randf() * 0.4).timeout
		print("cycled")
	if opts.has("invite"):
		await get_tree().create_timer(1.5).timeout
		var edit: LineEdit = _screen.find_children("", "LineEdit", true, false)[0]
		edit.text = str(opts.invite)
		edit.text_submitted.emit(edit.text)
	for c in str(opts.get("click", "")).split(";", false):
		await get_tree().create_timer(2.0).timeout
		var at := Vector2(float(c.get_slice(",", 0)), float(c.get_slice(",", 1)))
		for pressed in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = MOUSE_BUTTON_LEFT
			e.pressed = pressed
			e.position = at
			e.global_position = at
			Input.parse_input_event(e)
			await get_tree().process_frame
	if opts.has("shot"):
		await get_tree().create_timer(float(opts.get("shot-after", "3"))).timeout
		get_viewport().get_texture().get_image().save_png(str(opts.shot))
		get_tree().quit()


func _render_user() -> void:
	UI.clear(_user_slot)
	if Api.signed_in():
		_user_slot.add_child(Avatar.make(Api.me.get("avatar"), str(Api.me.name), 34))
		_user_slot.add_child(UI.label(str(Api.me.name), "Strong"))
		_user_slot.add_child(UI.button("Sign out", func() -> void:
			await Api.logout()
			go("home"), "Ghost"))
	else:
		_user_slot.add_child(UI.button("Sign in", func() -> void: go("lobby"), "Chip"))


# ── Navigation ──

func go(name: String, arg: Variant = null) -> void:
	if not Api.loaded and name in ["lobby", "history", "contact"]:
		await Api.me_changed
	if name == "back":
		name = "lobby" if _screen_name == "game" and Api.signed_in() and _history_stack.size() < 2 else (_history_stack[-2] if _history_stack.size() >= 2 else "home")
		if _history_stack.size() >= 1:
			_history_stack.pop_back()
	else:
		_history_stack.append(name)
		if _history_stack.size() > 12:
			_history_stack.pop_front()
	if _screen:
		_screen.queue_free()
		_screen = null
	_lobby_timer.stop()
	for c in _lobby_timer.timeout.get_connections():
		_lobby_timer.timeout.disconnect(c.callable)
	_screen_name = name
	var veil := 0.62
	board.showcase = name != "game"
	match name:
		"home":
			veil = 0.18
			_screen = _home()
		"setup":
			_screen = _setup()
		"lobby":
			_screen = _lobby() if Api.signed_in() else _signin("Sign in to play friends. Invite anyone by email; they sign in too, and your games, contacts and history are kept.")
		"contact":
			_screen = _contact(arg)
		"history":
			_screen = _history()
		"game":
			veil = 0.0
			_screen = arg
			(arg as GameScreen).leave.connect(func(to: String) -> void: go(to))
	if name != "game":
		board.show_position(Chess.start(), -1, false)
		board.movable = -1
		board.frame_offset(-0.2 if name == "home" else 0.0, 15.5 if name == "home" else 14.0)
	create_tween().tween_property(_veil, "color:a", veil, 0.4)
	add_child(_screen)
	move_child(_screen, _veil.get_index() + 1)
	Api.set_title("Gambit")


## A centred column for list screens.
func _page(width := 1080.0) -> Array:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_top", 92)
	root.add_theme_constant_override("margin_bottom", 24)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(sc)
	var col := UI.vbox(18)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	# Keep the column centred and at most `width` wide. Margins only change with the window's width,
	# never with the content, so this can't feed back on itself.
	var fit := func() -> void:
		var m := int(maxf(16.0, (get_viewport_rect().size.x - width) / 2.0))
		if root.get_theme_constant("margin_left") != m:
			root.add_theme_constant_override("margin_left", m)
			root.add_theme_constant_override("margin_right", m)
	fit.call()
	get_viewport().size_changed.connect(fit)
	root.tree_exiting.connect(func() -> void: get_viewport().size_changed.disconnect(fit))
	return [root, col]


static func toast(text: String, error := false) -> void:
	var m := instance
	if m._toast:
		m._toast.queue_free()
	var t := PanelContainer.new()
	t.add_theme_stylebox_override("panel", UI.box(UI.RAISED, 12, UI.RED if error else UI.GOLD, Vector4(18, 12, 18, 12)))
	t.add_child(UI.label(text))
	m.add_child(t)
	m._toast = t
	t.anchor_left = 0.5
	t.anchor_right = 0.5
	t.anchor_top = 1.0
	t.anchor_bottom = 1.0
	t.grow_horizontal = Control.GROW_DIRECTION_BOTH
	t.grow_vertical = Control.GROW_DIRECTION_BEGIN
	t.offset_bottom = -28
	t.modulate.a = 0.0
	var tw := m.create_tween()
	tw.tween_property(t, "modulate:a", 1.0, 0.2)
	tw.tween_interval(3.5)
	tw.tween_property(t, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void:
		if is_instance_valid(t):
			t.queue_free())


# ── Home ──

func _home() -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := UI.vbox(18)
	col.anchor_top = 0.5
	col.anchor_bottom = 0.5
	col.offset_left = 72
	col.offset_top = -190
	col.custom_minimum_size.x = 460
	root.add_child(col)
	col.add_child(UI.label("CHESS, BEAUTIFULLY", "Eyebrow"))
	var title := UI.label("Gambit", "Title", 96)
	col.add_child(title)
	col.add_child(UI.wrap("Play a friend anywhere — invite them by email and take your time. Or face Stockfish, from gentle to merciless.", "Muted"))
	(col.get_child(2) as Label).add_theme_font_size_override("font_size", 18)
	col.add_child(Control.new())
	var friend := UI.button("Play a friend", func() -> void: go("lobby"), "Primary")
	friend.custom_minimum_size = Vector2(220, 52)
	var cpu := UI.button("Play the computer", func() -> void: go("setup"))
	cpu.custom_minimum_size = Vector2(220, 52)
	col.add_child(UI.hbox(12, [friend, cpu]))
	var saved := _load_computer()
	if saved.get("result", "") == "*" and not (saved.get("moves", []) as Array).is_empty():
		col.add_child(UI.button("Continue your game against level %d" % int(saved.level), func() -> void:
			go("game", GameScreen.new("computer", _load_computer(), board)), "Ghost"))
	return root


func _signin(reason: String) -> Control:
	var p := _page(520)
	var col: VBoxContainer = p[1]
	var c := UI.vbox(14)
	c.add_child(UI.label("Sign in", "Heading"))
	c.add_child(UI.wrap(reason, "Muted"))
	var names := {google = "Continue with Google", github = "Continue with GitHub"}
	for prov in Api.providers:
		if prov == "dev":
			continue
		var b := UI.button(names.get(prov, prov), func() -> void: Api.sign_in(prov), "Primary" if prov == "google" else "")
		b.custom_minimum_size.y = 48
		c.add_child(b)
	if "dev" in Api.providers:
		var email := LineEdit.new()
		email.placeholder_text = "any@email.test (development sign-in)"
		email.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.add_child(UI.hbox(8, [email, UI.button("Dev sign-in", func() -> void:
			await Api.sign_in("dev", email.text.strip_edges())
			if Api.signed_in():
				go("lobby"))]))
	if Api.providers.is_empty():
		c.add_child(UI.wrap("Sign-in isn't available right now. You can still play the computer.", "Muted"))
	c.add_child(UI.wrap("We keep your name, email address and profile picture from Google or GitHub, so friends can find you, and your games. Nothing else.", "Muted"))
	col.add_child(UI.card(c))
	return p[0]


# ── Against the computer: set-up ──

func _setup() -> Control:
	Api.engine_preload()
	var p := _page(860)
	var col: VBoxContainer = p[1]
	var c := UI.vbox(16)
	c.add_child(UI.label("Play the computer", "Heading"))
	c.add_child(UI.label("STRENGTH", "Eyebrow"))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var chosen := {level = 3, color = "random"}
	var level_buttons: Array[Button] = []
	for i in LEVELS.size():
		var b := Button.new()
		b.theme_type_variation = "Chip"
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(190, 92)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%d  %s\n%s\n%s" % [i + 1, LEVELS[i][0], LEVELS[i][1], LEVELS[i][2]]
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_stylebox_override("normal", UI.box(UI.RAISED, 12, UI.LINE, Vector4(14, 10, 14, 10)))
		b.add_theme_stylebox_override("hover", UI.box(Color("262a32"), 12, Color("3b3f4a"), Vector4(14, 10, 14, 10)))
		b.add_theme_stylebox_override("pressed", UI.box(Color(UI.GOLD, 0.14), 12, UI.GOLD, Vector4(14, 10, 14, 10)))
		b.button_pressed = i + 1 == chosen.level
		b.pressed.connect(func() -> void:
			chosen.level = i + 1
			for o in level_buttons:
				o.button_pressed = o == b
			Sfx.play("select"))
		level_buttons.append(b)
		grid.add_child(b)
	c.add_child(grid)
	c.add_child(UI.label("YOUR COLOUR", "Eyebrow"))
	var colors := UI.hbox(8)
	var color_buttons: Array[Button] = []
	for opt in [["White", "white"], ["Random", "random"], ["Black", "black"]]:
		var b := UI.button(opt[0], func() -> void: pass, "Chip")
		b.toggle_mode = true
		b.button_pressed = opt[1] == chosen.color
		b.pressed.connect(func() -> void:
			chosen.color = opt[1]
			for o in color_buttons:
				o.button_pressed = o == b)
		color_buttons.append(b)
		colors.add_child(b)
	c.add_child(colors)
	var start := UI.button("Start the game", func() -> void:
		var white: bool = chosen.color == "white" or (chosen.color == "random" and randf() < 0.5)
		go("game", GameScreen.new("computer", _new_computer_game(chosen.level, white), board)), "Primary")
	start.custom_minimum_size = Vector2(220, 50)
	c.add_child(UI.hbox(12, [UI.button("Back", func() -> void: go("home"), "Ghost"), UI.spacer(), start]))
	c.add_child(UI.wrap("Stockfish 19 runs in your browser; the ratings are rough guides.", "Muted"))
	col.add_child(UI.card(c))
	return p[0]


func _new_computer_game(level: int, white: bool) -> Dictionary:
	var now := Time.get_unix_time_from_system() * 1000.0
	var you := {id = Api.me.get("id"), email = Api.me.get("email"), name = str(Api.me.get("name", "You")), avatar = Api.me.get("avatar")}
	var cpu := {id = null, email = null, name = "Stockfish · %s" % LEVELS[level - 1][0], avatar = null}
	var g := {
		id = "local-%d" % int(now), kind = "computer", level = level,
		white = you if white else cpu, black = cpu if white else you,
		moves = [], result = "*", reason = null, drawOffer = null, created = now, updated = now,
		events = [{seq = 1, at = now, kind = "start", side = null, text = null}],
	}
	save_computer(g)
	return g


func _load_computer() -> Dictionary:
	if not FileAccess.file_exists(SAVE):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE))
	return v if v is Dictionary else {}


static func save_computer(g: Dictionary) -> void:
	var f := FileAccess.open(SAVE, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(g))


## A finished game against the computer: into the history on the server, or on this device when signed out.
static func finish_computer(g: Dictionary) -> void:
	save_computer(g)
	if Api.signed_in():
		var start: float = g.events[0].at
		var times := []
		for e in g.events:
			if e.kind == "move":
				times.append(int(float(e.at) - start))
		var mine := GameScreen._mine(g)
		var r := await Api.post_json("api/games/computer", {
			level = g.level, color = "white" if mine == 0 else "black", moves = g.moves, times = times, resigned = g.reason == "resign"})
		if not r.ok:
			toast("Couldn't save this game to your history: " + r.error, true)
	else:
		var list := _local_history()
		list.push_front(g)
		var f := FileAccess.open(LOCAL_HISTORY, FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(list.slice(0, 50)))


static func _local_history() -> Array:
	if not FileAccess.file_exists(LOCAL_HISTORY):
		return []
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(LOCAL_HISTORY))
	return v if v is Array else []


# ── The lobby ──

func _lobby() -> Control:
	var p := _page(1120)
	var col: VBoxContainer = p[1]
	var cols := UI.hbox(18)
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var left := UI.vbox(18)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.15
	var right := UI.vbox(18)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	cols.add_child(right)
	col.add_child(cols)

	# Invite a friend.
	var inv := UI.vbox(12)
	inv.add_child(UI.label("Invite a friend", "Heading"))
	inv.add_child(UI.wrap("They'll get your invitation when they sign in with this address.", "Muted"))
	var email := LineEdit.new()
	email.placeholder_text = "friend@example.com"
	email.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chosen := {color = "random"}
	var color_row := UI.hbox(8, [UI.label("You play", "Muted")])
	var color_buttons: Array[Button] = []
	for opt in [["White", "white"], ["Random", "random"], ["Black", "black"]]:
		var b := UI.button(opt[0], func() -> void: pass, "Chip")
		b.toggle_mode = true
		b.button_pressed = opt[1] == "random"
		b.pressed.connect(func() -> void:
			chosen.color = opt[1]
			for o in color_buttons:
				o.button_pressed = o == b)
		color_buttons.append(b)
		color_row.add_child(b)
	var sent := UI.vbox(8)
	var fns := {}
	var send := func() -> void:
		var addr := email.text.strip_edges()
		if addr == "" or not "@" in addr:
			toast("That doesn't look like an email address.", true)
			return
		var r := await Api.post_json("api/challenges", {email = addr, color = chosen.color})
		if not r.ok:
			toast(r.error, true)
			return
		email.text = ""
		Sfx.play("notify")
		UI.clear(sent)
		var link := str(r.data.link)
		sent.add_child(UI.wrap(("Invitation emailed to %s. " % addr if r.data.emailed else "Invitation waiting for %s. " % addr) + "You can also send them this link:", "Muted"))
		var link_edit := LineEdit.new()
		link_edit.text = link
		link_edit.editable = false
		link_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sent.add_child(UI.hbox(8, [link_edit, UI.button("Copy", func() -> void:
			Api.copy(link)
			toast("Link copied."))]))
		fns.refresh.call()
	email.text_submitted.connect(func(_t: String) -> void: send.call())
	inv.add_child(UI.hbox(8, [email, UI.button("Send invitation", send, "Primary")]))
	inv.add_child(color_row)
	inv.add_child(sent)
	left.add_child(UI.card(inv))

	var incoming := UI.vbox(10)
	var active := UI.vbox(10)
	var outgoing := UI.vbox(10)
	var contacts := UI.vbox(10)
	var in_card := UI.card(incoming)
	var out_card := UI.card(outgoing)
	left.add_child(in_card)
	left.add_child(UI.card(active))
	left.add_child(out_card)
	right.add_child(UI.card(contacts))
	right.add_child(UI.button("All your games", func() -> void: go("history"), "Ghost"))

	fns.refresh = func() -> void:
		var r := await Api.get_json("api/lobby")
		if not r.ok or not is_instance_valid(incoming):
			return
		var d: Dictionary = r.data
		_fill_incoming(incoming, d.incoming, in_card)
		_fill_active(active, d.active)
		_fill_outgoing(outgoing, d.outgoing, out_card)
		_fill_contacts(contacts, d.contacts)
		var waiting: int = d.incoming.size()
		for g in d.active:
			if (g.moves.size() % 2) == GameScreen._mine(g):
				waiting += 1
		Api.set_title("(%d) Gambit" % waiting if waiting else "Gambit")
		if _pending_challenge != "":
			var id := _pending_challenge
			_pending_challenge = ""
			var found: Array = d.incoming.filter(func(c: Dictionary) -> bool: return c.id == id)
			if found.is_empty():
				var c := await Api.get_json("api/challenges/" + id)
				if c.ok and c.data.challenge.status == "accepted" and c.data.challenge.gameId != null:
					_open_game(str(c.data.challenge.gameId))
				elif c.ok:
					toast("That invitation was %s." % c.data.challenge.status)
				else:
					toast("That invitation was sent to a different address than %s." % Api.me.email if c.status == 403 else c.error, true)
	_lobby_timer.timeout.connect(fns.refresh)
	_lobby_timer.start()
	fns.refresh.call()
	return p[0]


func _row(kids: Array, on_click := Callable()) -> PanelContainer:
	var row := UI.card(UI.hbox(12, kids), "Row")
	if on_click.is_valid():
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				on_click.call())
	return row


func _who(name: String, detail: String) -> VBoxContainer:
	var v := UI.vbox(0, [UI.label(name, "Strong"), UI.label(detail, "Muted")])
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	(v.get_child(0) as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	(v.get_child(1) as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return v


func _fill_incoming(box: VBoxContainer, list: Array, holder: Control) -> void:
	UI.clear(box)
	holder.visible = not list.is_empty()
	box.add_child(UI.label("Invitations for you", "Heading"))
	for c in list:
		var yours: String = {"white": "black", "black": "white"}.get(str(c.color), "a random colour")
		box.add_child(_row([
			Avatar.make(c.from.get("avatar"), str(c.from.name), 40),
			_who(str(c.from.name), "%s · you play %s · %s" % [c.from.email, yours, UI.ago(float(c.created))]),
			UI.button("Accept", func() -> void: _answer(str(c.id), "accept"), "Primary"),
			UI.button("Decline", func() -> void: _answer(str(c.id), "decline"), "Ghost"),
		]))


func _fill_active(box: VBoxContainer, list: Array) -> void:
	UI.clear(box)
	box.add_child(UI.label("Your games", "Heading"))
	if list.is_empty():
		box.add_child(UI.label("No games in play. Invite someone!", "Muted"))
	for g in list:
		var mine := GameScreen._mine(g)
		var opp: Dictionary = g.black if mine == 0 else g.white
		var your_move: bool = (g.moves.size() % 2) == mine
		var tag := UI.label("Your move" if your_move else "Their move", "Strong" if your_move else "Muted")
		if your_move:
			tag.add_theme_color_override("font_color", UI.GOLD)
		box.add_child(_row([
			Avatar.make(opp.get("avatar"), str(opp.name), 40),
			_who(str(opp.name), "%s · %s%s" % [UI.moves_text(g.moves.size()), UI.ago(float(g.updated)), " · draw offered" if g.get("drawOffer") != null else ""]),
			UI.side_dot(mine == 0, 12), tag,
		], func() -> void: _open_game(str(g.id))))


func _fill_outgoing(box: VBoxContainer, list: Array, holder: Control) -> void:
	UI.clear(box)
	holder.visible = not list.is_empty()
	box.add_child(UI.label("Waiting for an answer", "Heading"))
	for c in list:
		var link := Api.base + "?challenge=" + str(c.id)
		box.add_child(_row([
			_who(str(c.toEmail), "sent %s" % UI.ago(float(c.created))),
			UI.button("Copy link", func() -> void:
				Api.copy(link)
				toast("Link copied."), "Ghost"),
			UI.button("Cancel", func() -> void: _answer(str(c.id), "cancel"), "Ghost"),
		]))


func _fill_contacts(box: VBoxContainer, list: Array) -> void:
	UI.clear(box)
	box.add_child(UI.label("Contacts", "Heading"))
	if list.is_empty():
		box.add_child(UI.wrap("Everyone you play is kept here, with your record and your games against them.", "Muted"))
	for c in list:
		box.add_child(_row([
			Avatar.make(c.get("avatar"), str(c.name), 40),
			_who(str(c.name), "%s · %dW %dL %dD" % [c.email, c.wins, c.losses, c.draws]),
		], func() -> void: go("contact", c)))


func _answer(id: String, what: String) -> void:
	var r := await Api.post_json("api/challenges/%s/%s" % [id, what])
	if not r.ok:
		toast(r.error, true)
	elif what == "accept" and r.data.has("game"):
		Sfx.play("notify")
		go("game", GameScreen.new("online", r.data.game, board))
		return
	if _screen_name == "lobby":
		go("lobby")
		_history_stack.pop_back()


func _open_game(id: String, mode := "") -> void:
	var r := await Api.get_json("api/games/" + id)
	if not r.ok:
		toast(r.error, true)
		return
	var g: Dictionary = r.data.game
	if mode == "":
		mode = "online" if g.result == "*" else "replay"
	go("game", GameScreen.new(mode, g, board))


# ── One contact ──

func _contact(c: Dictionary) -> Control:
	var p := _page(820)
	var col: VBoxContainer = p[1]
	var head := UI.hbox(18, [Avatar.make(c.get("avatar"), str(c.name), 72),
		UI.vbox(2, [UI.label(str(c.name), "Heading", 30), UI.label(str(c.email), "Muted"),
			UI.label(UI.record(int(c.wins), int(c.losses), int(c.draws)), "Strong")]),
		UI.spacer()])
	var invite := UI.button("Invite to a game", func() -> void:
		var r := await Api.post_json("api/challenges", {email = c.email, color = "random"})
		toast("Invitation sent." if r.ok else r.error, not r.ok), "Primary")
	head.add_child(invite)
	col.add_child(UI.card(head))
	var list := UI.vbox(10, [UI.label("Your games together", "Heading")])
	col.add_child(UI.card(list))
	col.add_child(UI.hbox(8, [UI.button("Back", func() -> void: go("back"), "Ghost"), UI.spacer(),
		UI.button("Remove from contacts", func() -> void:
			var r := await Api.post_json("api/contacts/remove", {email = c.email})
			if r.ok:
				toast("Removed.")
				go("lobby"), "Danger")]))
	_load_contact_games(list, str(c.id))
	return p[0]


func _load_contact_games(list: VBoxContainer, id: String) -> void:
	var r := await Api.get_json("api/contacts/%s/games" % id)
	if not is_instance_valid(list):
		return
	if not r.ok:
		list.add_child(UI.label(r.error, "Muted"))
		return
	if r.data.games.is_empty():
		list.add_child(UI.label("No games yet.", "Muted"))
	for g in r.data.games:
		list.add_child(_game_row(g))


func _game_row(g: Dictionary) -> Control:
	var mine := GameScreen._mine(g)
	var opp: Dictionary = g.black if mine == 0 else g.white
	var res := str(g.result)
	var outcome := "In play"
	var tone := UI.GOLD
	if res == "1/2-1/2":
		outcome = "Draw"
		tone = UI.MUTED
	elif res != "*":
		var won := (res == "1-0") == (mine == 0)
		outcome = "Won" if won else "Lost"
		tone = UI.GREEN if won else UI.RED
	var tag := UI.label(outcome, "Strong")
	tag.add_theme_color_override("font_color", tone)
	tag.custom_minimum_size.x = 64
	var detail := "%s · %s · %s" % [Chess.describe(res, str(g.reason), str(g.white.name), str(g.black.name)) if res != "*" else "Your move" if (g.moves.size() % 2) == mine else "Their move", UI.moves_text(g.moves.size()), UI.ago(float(g.updated))]
	return _row([tag, Avatar.make(opp.get("avatar"), str(opp.name), 34), _who("vs " + str(opp.name), detail), UI.side_dot(mine == 0, 12)],
		func() -> void:
			if str(g.id).begins_with("local-"):
				go("game", GameScreen.new("replay", g, board))
			else:
				_open_game(str(g.id)))


# ── History ──

func _history() -> Control:
	var p := _page(820)
	var col: VBoxContainer = p[1]
	var list := UI.vbox(10, [UI.label("Your games", "Heading")])
	col.add_child(UI.card(list))
	if not Api.signed_in():
		list.add_child(UI.wrap("Games against the computer on this device. Sign in to keep every game, with friends too, wherever you play.", "Muted"))
		var local := _local_history()
		if local.is_empty():
			list.add_child(UI.label("No finished games yet.", "Muted"))
		for g in local:
			list.add_child(_game_row(g))
		return p[0]
	var more := UI.button("More", func() -> void: pass, "Ghost")
	more.visible = false
	col.add_child(more)
	var state := {before = 0.0}
	var load := func() -> void:
		var r := await Api.get_json("api/games" + ("?before=%d" % int(state.before) if state.before > 0 else ""))
		if not r.ok or not is_instance_valid(list):
			return
		if r.data.games.is_empty() and state.before == 0:
			list.add_child(UI.label("No finished games yet.", "Muted"))
		for g in r.data.games:
			list.add_child(_game_row(g))
		if not r.data.games.is_empty():
			state.before = float(r.data.games[-1].updated)
		more.visible = r.data.games.size() >= 30
	more.pressed.connect(load)
	load.call()
	return p[0]
