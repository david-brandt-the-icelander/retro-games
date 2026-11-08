class_name GameScreen
extends Control
## A game in progress or a finished one, beside the 3D board: the two players, the transcript
## (every move and chat message with its time, and how long each move took), chat, and the
## buttons for this kind of game. Three modes:
##   "online"    a game with a friend, live over a WebSocket, moves checked by the server
##   "computer"  against Stockfish, kept on this device until it ends
##   "replay"    a finished game, step by step or played back at its own pace

signal leave(to: String)

var mode := "online"
var board: Board3D
var game := {}                     ## the server's GameView (online and replay), or a computer game in the same shape
var chess := Chess.Game.new()
var my_side := 0                   ## 0 white, 1 black
var view_ply := -1                 ## the position being looked at; -1 for the latest
var cursor := 0                    ## replay: how many transcript entries have happened
var _live: Api.Live
var _pending := false
var _playing := false
var _speed := 4.0
var _play_timer := 0.0
var _thinking := false
var _faced := false

# Widgets
var _plates := {}
var _status: Label
var _banner: PanelContainer
var _list: VBoxContainer
var _scroll: ScrollContainer
var _chat: LineEdit
var _actions: HBoxContainer
var _replay_bar: VBoxContainer
var _slider: HSlider
var _play_btn: Button
var _viewing: PanelContainer
var _promo_box: PanelContainer
var _offline: Label


func _init(screen_mode: String, data: Dictionary, the_board: Board3D) -> void:
	mode = screen_mode
	game = data
	board = the_board
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()
	board.move_made.connect(_on_board_move)
	board.promotion_needed.connect(_on_promotion)
	board.showcase = false
	board.frame_offset(0.2, 15.0)
	if mode == "computer":
		Api.engine_preload()
	if mode == "online":
		_apply(game, false)
		if game.result == "*":
			_live = Api.Live.new(game.id)
			_live.state.connect(func(g: Dictionary) -> void: _apply(g, true))
			_live.connection.connect(func(up: bool) -> void: _offline.visible = not up)
			add_child(_live)
	elif mode == "replay":
		_apply(game, false)
		cursor = 0
		_seek(0)
	else:
		_apply(game, false)
		_computer_turn()


func _exit_tree() -> void:
	board.move_made.disconnect(_on_board_move)
	board.promotion_needed.disconnect(_on_promotion)
	board.movable = -1
	if _live:
		_live.close()
	if mode == "computer":
		Api.engine_cancel()


# ── Layout ──

func _build() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -440
	panel.offset_right = -24
	panel.offset_top = 84
	panel.offset_bottom = -24
	add_child(panel)
	var col := UI.vbox(14)
	panel.add_child(col)

	_plates.black = UI.hbox(12)
	_plates.white = UI.hbox(12)
	col.add_child(UI.card(_plates.black, "Row"))
	col.add_child(UI.card(_plates.white, "Row"))

	_status = UI.label("", "Heading")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status)
	_offline = UI.label("Reconnecting…", "Muted")
	_offline.add_theme_color_override("font_color", UI.RED)
	_offline.visible = false
	col.add_child(_offline)

	_banner = PanelContainer.new()
	_banner.theme_type_variation = "Banner"
	_banner.visible = false
	col.add_child(_banner)

	_viewing = PanelContainer.new()
	_viewing.theme_type_variation = "Banner"
	_viewing.visible = false
	col.add_child(_viewing)

	var transcript_head := UI.hbox(8, [UI.label("TRANSCRIPT", "Eyebrow"), UI.spacer()])
	col.add_child(transcript_head)
	_list = UI.vbox(2)
	_scroll = UI.scroll(_list)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(UI.card(_scroll, "Inset"))
	(_scroll.get_parent() as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL

	if mode == "online":
		_chat = LineEdit.new()
		_chat.placeholder_text = "Say something…"
		_chat.max_length = 500
		_chat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_chat.text_submitted.connect(func(_t: String) -> void: _send_chat())
		col.add_child(UI.hbox(8, [_chat, UI.button("Send", _send_chat, "Primary")]))

	if mode == "replay":
		_replay_bar = UI.vbox(8)
		_slider = HSlider.new()
		_slider.min_value = 0
		_slider.step = 1
		_slider.value_changed.connect(func(v: float) -> void:
			if int(v) != cursor:
				_stop_and_seek(int(v)))
		_play_btn = UI.button("Play", _toggle_play, "Primary")
		var speeds := UI.hbox(8)
		for s in [1.0, 4.0, 16.0]:
			var b := UI.button("%d×" % int(s), func() -> void: _set_speed(s), "Chip")
			b.toggle_mode = true
			b.button_pressed = s == _speed
			b.set_meta("speed", s)
			speeds.add_child(b)
		_replay_bar.add_child(_slider)
		_replay_bar.add_child(UI.hbox(4, [
			UI.button("Start", func() -> void: _stop_and_seek(0), "Ghost"),
			UI.button("Back", func() -> void: _stop_and_seek(cursor - 1), "Ghost"),
			_play_btn,
			UI.button("Next", func() -> void: _stop_and_seek(cursor + 1), "Ghost"),
			UI.button("End", func() -> void: _stop_and_seek(_events().size()), "Ghost")]))
		_replay_bar.add_child(UI.hbox(8, [UI.label("Pace", "Muted"), speeds, UI.spacer(), UI.label("as played, sped up", "Muted")]))
		col.add_child(_replay_bar)

	# Hidden until there is something in it; a replay never has any.
	_actions = UI.hbox(8)
	_actions.visible = false
	col.add_child(_actions)
	col.add_child(UI.hbox(8, [
		UI.button("Turn the board", func() -> void: board.face(1 - board.facing), "Ghost"),
		UI.spacer(),
		UI.button("Leave", func() -> void: leave.emit("back"), "Ghost")]))

	_promo_box = PanelContainer.new()
	_promo_box.set_anchors_preset(Control.PRESET_CENTER)
	_promo_box.visible = false
	add_child(_promo_box)


func _player_plate(box: HBoxContainer, p: Dictionary, white: bool) -> void:
	UI.clear(box)
	box.add_child(Avatar.make(p.get("avatar"), str(p.name), 44))
	var who := UI.vbox(2, [UI.label(str(p.name), "Strong")])
	if p.get("email") != null and str(p.email) != "":
		who.add_child(UI.label(str(p.email), "Muted"))
	for l in who.get_children():
		(l as Label).text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		(l as Label).clip_text = true
	who.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	who.custom_minimum_size.x = 60
	box.add_child(who)
	var mat := _material_balance()
	var adv: int = mat if white else -mat
	if adv > 0:
		var l := UI.label("+%d" % adv, "Strong")
		l.add_theme_color_override("font_color", UI.GREEN)
		box.add_child(l)
	box.add_child(UI.side_dot(white, 14))


func _material_balance() -> int:
	var values := [0, 1, 3, 3, 5, 9, 0]
	var total := 0
	var pos := _shown_position()
	for sq in 64:
		var pc := pos.board[sq]
		if pc != Chess.EMPTY:
			total += values[pc & 7] * (-1 if Chess.is_black(pc) else 1)
	return total


# ── Showing the game ──

func _events() -> Array:
	return game.get("events", [])


func _shown_ply() -> int:
	return chess.moves.size() if view_ply < 0 else view_ply


func _shown_position() -> Chess.Position:
	return chess.positions[_shown_ply()]


## Takes a new state of the game (from the server, or from this device for the computer).
func _apply(g: Dictionary, animate: bool) -> void:
	var before := chess.moves.size()
	var old_events := _events().size()
	var old_offer: Variant = game.get("drawOffer")
	var old_result: String = str(game.get("result", "*"))
	game = g
	var moves := PackedStringArray(g.moves)
	if moves.size() == before + 1 and moves.slice(0, before) == chess.moves:
		chess.play(moves[-1])
	else:
		chess = Chess.Game.from_moves(moves)
	my_side = _mine(g)
	_player_plate(_plates.white, g.white, true)
	_player_plate(_plates.black, g.black, false)
	if view_ply >= 0 and view_ply >= chess.moves.size():
		view_ply = -1
	if mode != "replay":
		var grew := chess.moves.size() == before + 1
		_show_board(animate and grew and view_ply < 0)
		if not _faced:
			_faced = true
			board.face(my_side)
		_render_transcript()
		_update_status()
		_update_actions()
		_update_viewing()
		if animate and _events().size() > old_events:
			var last: Dictionary = _events()[-1]
			if last.kind == "chat" and _side_index(last.side) != my_side:
				Sfx.play("chat")
		if animate and g.get("drawOffer") != old_offer and g.get("drawOffer") != null and _side_index(g.drawOffer) != my_side:
			Sfx.play("notify")
		if old_result == "*" and str(g.result) != "*" and animate:
			_end_sound()
	elif not _faced:
		_faced = true
		board.face(my_side)


## The side this player plays (or watches from in a replay).
static func _mine(g: Dictionary) -> int:
	if str(g.get("kind")) == "computer":
		# The computer's side has no id and the name "Stockfish · …".
		return 1 if str(g.white.name).begins_with("Stockfish") else 0
	return 1 if Api.signed_in() and g.black.get("id") != null and str(g.black.id) == str(Api.me.get("id")) else 0


func _is_me(p: Dictionary) -> bool:
	return Api.signed_in() and p.get("id") != null and str(p.id) == str(Api.me.id)


func _side_index(s: Variant) -> int:
	return 0 if str(s) == "white" else 1


func _show_board(animate: bool) -> void:
	var ply := _shown_ply()
	var last := chess.played[ply - 1] if ply > 0 else -1
	board.show_position(chess.positions[ply], last, animate)
	board.movable = my_side if _can_move() else -1
	_player_plate(_plates.white, game.white, true)
	_player_plate(_plates.black, game.black, false)


func _can_move() -> bool:
	if mode == "replay" or view_ply >= 0 or _pending or _thinking or str(game.result) != "*" or chess.result != "*":
		return false
	return (chess.moves.size() % 2) == my_side


func _update_status() -> void:
	var names := [str(game.white.name), str(game.black.name)]
	if str(game.result) != "*":
		_status.text = Chess.describe(str(game.result), str(game.reason), names[0], names[1])
		_status.add_theme_color_override("font_color", UI.GOLD)
		return
	_status.remove_theme_color_override("font_color")
	var turn := chess.moves.size() % 2
	if mode == "computer" and _thinking:
		_status.text = "Stockfish is thinking…"
	elif turn == my_side:
		_status.text = "Your move" + (" — check!" if Chess.in_check(chess.current) else "")
		_status.add_theme_color_override("font_color", UI.GOLD)
	else:
		_status.text = "Waiting for %s…" % names[turn]
	# The draw offer, if any.
	var offer: Variant = game.get("drawOffer")
	UI.clear(_banner)
	_banner.visible = mode == "online" and offer != null
	if _banner.visible:
		if _side_index(offer) == my_side:
			_banner.add_child(UI.wrap("You offered a draw. Your opponent can accept, or answer with a move."))
		else:
			_banner.add_child(UI.vbox(10, [UI.wrap("%s offers a draw." % names[1 - my_side]), UI.hbox(8, [
				UI.button("Accept", func() -> void: _act({type = "draw-accept"}), "Primary"),
				UI.button("Decline", func() -> void: _act({type = "draw-decline"}))])]))
		(_banner.get_child(0) as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _update_actions() -> void:
	var over := str(game.result) != "*"
	# Rebuild only when the buttons change, so a "Sure? Resign" isn't reset by a chat message arriving.
	var key := "%s %s %s" % [mode, over, game.get("drawOffer") == null]
	if _actions.get_meta("key", "") == key:
		return
	_actions.set_meta("key", key)
	UI.clear(_actions)
	if mode == "online":
		if not over:
			if game.get("drawOffer") == null:
				_actions.add_child(UI.button("Offer draw", func() -> void: _act({type = "draw-offer"})))
			_actions.add_child(UI.sure_button("Resign", func() -> void: _act({type = "resign"})))
		else:
			var opp: Dictionary = game.black if my_side == 0 else game.white
			if opp.get("email") != null:
				_actions.add_child(UI.button("Rematch", func() -> void: _rematch(str(opp.email)), "Primary"))
	elif mode == "computer":
		if not over:
			_actions.add_child(UI.button("Take back", _take_back))
			_actions.add_child(UI.sure_button("Resign", func() -> void: _computer_end({result = "0-1" if my_side == 0 else "1-0", reason = "resign"})))
		else:
			_actions.add_child(UI.button("New game", func() -> void: leave.emit("setup"), "Primary"))
	_actions.visible = _actions.get_child_count() > 0


# ── The transcript ──

## Rebuilds the transcript. It then scrolls to the newest entry (to the current one in a replay),
## unless `follow` is false (looking back at a move), which keeps the move looked at in view.
func _render_transcript(follow := true) -> void:
	UI.clear(_list)
	var current: Control = null        ## replay: the row of the latest entry that has happened
	var viewed: Control = null         ## the row of the move being looked at
	var events := _events()
	var ply := 0
	var last_move_at: float = events[0].at if events.size() > 0 else 0.0
	var names := {white = str(game.white.name), black = str(game.black.name)}
	var day := ""
	for i in events.size():
		var e: Dictionary = events[i]
		var row: Control
		# A quiet heading wherever the date changes: "Today", "Yesterday", "Friday 6 November".
		var d := UI.day(float(e.at))
		if d != day:
			day = d
			var head := UI.label(d.to_upper(), "Eyebrow", 11)
			head.add_theme_color_override("font_color", UI.MUTED)
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			if mode == "replay" and i >= cursor:
				head.modulate.a = 0.28
			_list.add_child(head)
		match str(e.kind):
			"start":
				row = _note("Game started", e)
			"move":
				ply += 1
				var took := float(e.at) - last_move_at
				last_move_at = float(e.at)
				row = _move_row(ply, e, took)
				if ply == view_ply:
					viewed = row
			"chat":
				row = _chat_row(e, names)
			"draw-offer":
				row = _note("%s offers a draw" % names[str(e.side)], e)
			"draw-decline":
				row = _note("%s declines the draw" % names[str(e.side)], e)
			"resign":
				row = _note("%s resigns" % names[str(e.side)], e)
			"end":
				var parts := str(e.text).split(" ")
				row = _note(Chess.describe(parts[0], parts[1] if parts.size() > 1 else "", names.white, names.black), e, true)
			_:
				continue
		if mode == "replay" and i >= cursor:
			row.modulate.a = 0.28
		if i == cursor - 1:
			current = row
		_list.add_child(row)
	await get_tree().process_frame
	if not is_instance_valid(_scroll):
		return
	if not follow:
		if viewed:
			_scroll.ensure_control_visible(viewed)
	elif mode == "replay":
		if current:
			_scroll.ensure_control_visible(current)
		else:
			_scroll.scroll_vertical = 0
	else:
		_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func _time_label(e: Dictionary) -> Label:
	var t := UI.label(UI.hhmm(float(e.at)), "Muted", 12)
	t.custom_minimum_size.x = 44
	t.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return t


func _note(text: String, e: Dictionary, strong := false) -> Control:
	var l := UI.wrap(text, "Strong" if strong else "Muted")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if strong:
		l.add_theme_color_override("font_color", UI.GOLD)
	else:
		l.add_theme_font_override("font", UI.italic)
		l.add_theme_font_size_override("font_size", 15)
	return UI.hbox(10, [_time_label(e), l])


func _move_row(ply: int, e: Dictionary, took: float) -> Control:
	var white := (ply % 2) == 1
	var num := UI.label(UI.move_number(ply), "Muted", 13)
	num.custom_minimum_size.x = 34
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var san := chess.sans[ply - 1] if ply - 1 < chess.sans.size() else str(e.text)
	var b := Button.new()
	b.text = san
	b.theme_type_variation = "Ghost"
	b.add_theme_font_override("font", UI.bold)
	b.add_theme_color_override("font_color", UI.INK)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_stylebox_override("normal", UI.box(Color(UI.GOLD, 0.18) if ply == _shown_ply() and (mode == "replay" or view_ply >= 0) else Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), Vector4(8, 3, 8, 3)))
	b.add_theme_stylebox_override("hover", UI.box(Color(1, 1, 1, 0.06), 8, Color(0, 0, 0, 0), Vector4(8, 3, 8, 3)))
	# Same padding in every state, so the row doesn't grow while the button is held down.
	b.add_theme_stylebox_override("pressed", UI.box(Color(1, 1, 1, 0.03), 8, Color(0, 0, 0, 0), Vector4(8, 3, 8, 3)))
	b.add_theme_stylebox_override("focus", UI.box(Color(0, 0, 0, 0), 8, UI.GOLD, Vector4(8, 3, 8, 3)))
	b.add_theme_color_override("font_focus_color", UI.INK)
	b.add_theme_color_override("font_pressed_color", UI.INK)
	b.pressed.connect(func() -> void: _jump_to_ply(ply))
	var took_l := UI.label(UI.duration(took), "Muted", 12)
	return UI.hbox(8, [_time_label(e), num, UI.side_dot(white, 9), b, took_l])


func _chat_row(e: Dictionary, names: Dictionary) -> Control:
	var who: Dictionary = game.white if str(e.side) == "white" else game.black
	var mine := _side_index(e.side) == my_side
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", UI.box(Color(UI.GOLD, 0.12) if mine else Color("22252c"), 12, Color(0, 0, 0, 0), Vector4(12, 8, 12, 8)))
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var text := UI.wrap(str(e.text))
	bubble.add_child(UI.vbox(2, [UI.label(names[str(e.side)], "Eyebrow"), text]))
	return UI.hbox(10, [_time_label(e), Avatar.make(who.get("avatar"), str(who.name), 26), bubble])


## Looks at an earlier position (or, in a replay, goes there).
func _jump_to_ply(ply: int) -> void:
	if mode == "replay":
		# The transcript entry right after that move.
		var n := 0
		var events := _events()
		for i in events.size():
			if events[i].kind == "move":
				n += 1
				if n == ply:
					_stop_and_seek(i + 1)
					return
		return
	view_ply = -1 if ply >= chess.moves.size() else ply
	_show_board(false)
	# Back to the game follows the newest move again; looking back keeps that move in view.
	_render_transcript(view_ply < 0)
	_update_viewing()


## The "Looking at move n of m" banner, shown while looking at an earlier position.
func _update_viewing() -> void:
	UI.clear(_viewing)
	_viewing.visible = view_ply >= 0 and mode != "replay"
	if _viewing.visible:
		_viewing.add_child(UI.hbox(8, [UI.label("Looking at move %d of %d" % [(view_ply + 1) / 2, (chess.moves.size() + 1) / 2]), UI.spacer(),
			UI.button("Back to the game", func() -> void: _jump_to_ply(chess.moves.size()), "Primary")]))


# ── Moving ──

func _on_board_move(uci: String) -> void:
	if not _can_move():
		return
	if Chess.parse_uci(chess.current, uci) < 0:
		Sfx.play("illegal")
		return
	if mode == "online":
		# Show it at once; the server's answer confirms it, or puts the board back.
		var optimistic := game.duplicate(true)
		optimistic.moves = Array(chess.moves) + [uci]
		var ev: Array = optimistic.events
		ev.append({seq = 0, at = Time.get_unix_time_from_system() * 1000.0, kind = "move", side = ["white", "black"][my_side], text = uci})
		_pending = true
		_apply(optimistic, true)
		_act({type = "move", uci = uci, ply = chess.moves.size() - 1})
	elif mode == "computer":
		_computer_play(uci)


func _on_promotion(from_sq: int, to_sq: int) -> void:
	UI.clear(_promo_box)
	var row := UI.hbox(10)
	for p in [["Queen", "q"], ["Rook", "r"], ["Bishop", "b"], ["Knight", "n"]]:
		row.add_child(UI.button(p[0], func() -> void: _close_promotion(p[1]), "Primary" if p[1] == "q" else ""))
	row.add_child(UI.button("Cancel", func() -> void: _close_promotion(""), "Ghost"))
	_promo_box.add_child(UI.vbox(12, [UI.label("Promote to", "Heading"), row]))
	_promo_box.set_meta("move", [from_sq, to_sq])
	_promo_box.visible = true
	_promo_box.reset_size()
	_promo_box.position = (size - _promo_box.size) / 2.0 - Vector2(200, 0)


## Closes the promotion picker: with "q", "r", "b" or "n" the pawn promotes; with "" it goes back.
func _close_promotion(piece: String) -> void:
	if not _promo_box.visible:
		return
	_promo_box.visible = false
	var move: Array = _promo_box.get_meta("move")
	board.finish_promotion(move[0], move[1], piece)


## While the promotion picker is open, Escape or a click anywhere outside it cancels, like Cancel.
## The click is used up, so it doesn't also pick up a piece or turn the camera.
func _input(event: InputEvent) -> void:
	if not _promo_box.visible:
		return
	# A click (not a turn of the wheel) outside the card.
	var outside: bool = event is InputEventMouseButton and event.pressed \
		and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE] \
		and not _promo_box.get_global_rect().has_point(event.position)
	if event.is_action_pressed("ui_cancel") or outside:
		_close_promotion("")
		get_viewport().set_input_as_handled()


func _act(action: Dictionary) -> void:
	_pending = true
	board.movable = -1
	var r := await Api.post_json("api/games/%s/action" % game.id, action)
	_pending = false
	if r.ok:
		_apply(r.data.game, true)
	else:
		Main.toast(r.error, true)
		var g: Variant = r.data.get("game") if r.data is Dictionary else null
		if g is Dictionary:
			_apply(g, false)
		else:
			_show_board(false)


func _send_chat() -> void:
	var text := _chat.text.strip_edges()
	if text == "":
		return
	_chat.text = ""
	var r := await Api.post_json("api/games/%s/action" % game.id, {type = "chat", text = text})
	if r.ok:
		_apply(r.data.game, true)
	else:
		Main.toast(r.error, true)
		_chat.text = text


func _rematch(email: String) -> void:
	var r := await Api.post_json("api/challenges", {email = email, color = "black" if my_side == 0 else "white"})
	if r.ok:
		Main.toast("Rematch sent — it's waiting in their lobby.")
		leave.emit("lobby")
	else:
		Main.toast(r.error, true)


func _end_sound() -> void:
	var res := str(game.result)
	if res == "1/2-1/2":
		Sfx.play("draw")
	elif (res == "1-0") == (my_side == 0):
		Sfx.play("win")
	else:
		Sfx.play("lose")


# ── Against the computer ──

func _now() -> float:
	return Time.get_unix_time_from_system() * 1000.0


func _computer_play(uci: String) -> void:
	var g := game.duplicate(true)
	g.moves.append(uci)
	g.events.append({seq = g.events.size() + 1, at = _now(), kind = "move", side = ["white", "black"][(g.moves.size() - 1) % 2], text = uci})
	g.updated = _now()
	_apply(g, true)
	var test := Chess.Game.from_moves(PackedStringArray(g.moves))
	if test.result != "*":
		_computer_end({result = test.result, reason = test.reason})
		return
	Main.save_computer(game)
	_computer_turn()


func _computer_turn() -> void:
	if str(game.result) != "*" or chess.moves.size() % 2 == my_side:
		_update_status()
		return
	_thinking = true
	board.movable = -1
	_update_status()
	var at := chess.moves.size()
	Api.engine_move(chess.moves, int(game.level), func(uci: String) -> void:
		if not is_inside_tree() or chess.moves.size() != at or str(game.result) != "*":
			return
		_thinking = false
		if uci == "" or Chess.parse_uci(chess.current, uci) < 0:
			_status.text = "The computer opponent needs the web version."
			return
		_computer_play(uci))


func _take_back() -> void:
	if str(game.result) != "*":
		return
	var n := chess.moves.size()
	n -= 2 if n % 2 == my_side else 1
	# Nothing of yours to take back (playing Black, before the computer's first move): carry on
	# without disturbing the computer's search.
	if n < 0:
		return
	Api.engine_cancel()
	_thinking = false
	var g := game.duplicate(true)
	g.moves = g.moves.slice(0, n)
	# The transcript keeps the start and the moves still on the board.
	var kept := []
	var moves_seen := 0
	for e in g.events:
		if e.kind == "move":
			moves_seen += 1
			if moves_seen > n:
				break
		kept.append(e)
	g.events = kept
	_apply(g, false)
	Main.save_computer(game)


func _computer_end(outcome: Dictionary) -> void:
	var g := game.duplicate(true)
	if outcome.reason == "resign":
		g.events.append({seq = g.events.size() + 1, at = _now(), kind = "resign", side = ["white", "black"][my_side], text = null})
	g.events.append({seq = g.events.size() + 1, at = _now(), kind = "end", side = null, text = "%s %s" % [outcome.result, outcome.reason]})
	g.result = outcome.result
	g.reason = outcome.reason
	Api.engine_cancel()
	_thinking = false
	_apply(g, true)   # plays the win, lose or draw sound
	Main.finish_computer(game)


# ── Replays ──

func _seek(n: int) -> void:
	var events := _events()
	cursor = clampi(n, 0, events.size())
	var moves := PackedStringArray()
	for i in cursor:
		if events[i].kind == "move":
			moves.append(str(events[i].text))
	var animate := moves.size() == _shown_ply() + 1
	view_ply = moves.size()
	if view_ply >= chess.moves.size():
		view_ply = -1
	var ply := moves.size()
	var last := chess.played[ply - 1] if ply > 0 else -1
	board.show_position(chess.positions[ply], last, animate)
	board.movable = -1
	_player_plate(_plates.white, game.white, true)
	_player_plate(_plates.black, game.black, false)
	_slider.max_value = events.size()
	_slider.set_value_no_signal(cursor)
	var names := [str(game.white.name), str(game.black.name)]
	_status.remove_theme_color_override("font_color")
	if cursor >= events.size():
		_status.text = Chess.describe(str(game.result), str(game.reason), names[0], names[1])
		_status.add_theme_color_override("font_color", UI.GOLD)
	elif ply == 0:
		# Nothing has been played yet (only the start, or chat before the first move).
		_status.text = "Replay · %s" % UI.hhmm(float(events[0].at)) if events.size() else "Replay"
	else:
		var e: Dictionary = events[cursor - 1]
		var gone := float(e.at) - float(events[0].at)
		# White's moves "3. Qh5", Black's "3… Nf6", as in the transcript.
		_status.text = "%s %s · %s in" % [UI.move_number(ply), chess.sans[ply - 1], UI.duration(gone)]
	_render_transcript()


func _stop_and_seek(n: int) -> void:
	_playing = false
	_play_btn.text = "Play"
	_seek(n)


func _toggle_play() -> void:
	_playing = not _playing
	if _playing and cursor >= _events().size():
		_seek(0)
	_play_btn.text = "Pause" if _playing else "Play"
	_play_timer = _wait_before(cursor)


## How long Play waits before showing entry `n`: as long as the players took, sped up by the pace,
## but at least 0.35 s and at most 3 s.
func _wait_before(n: int) -> float:
	var events := _events()
	if n <= 0 or n >= events.size():
		return 0.35
	return clampf((float(events[n].at) - float(events[n - 1].at)) / 1000.0 / _speed, 0.35, 3.0)


func _set_speed(s: float) -> void:
	_speed = s
	for b in _replay_bar.find_children("", "Button", true, false):
		if b.has_meta("speed"):
			(b as Button).button_pressed = b.get_meta("speed") == s


func _process(delta: float) -> void:
	if not _playing:
		return
	_play_timer -= delta
	if _play_timer > 0:
		return
	var events := _events()
	if cursor >= events.size():
		_playing = false
		_play_btn.text = "Play"
		return
	_seek(cursor + 1)
	_play_timer = _wait_before(cursor)
