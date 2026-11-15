extends Node2D
## Sierra-style modal boxes: plain messages and scrollable pick-lists.

const SIZE := 12
const LH := 14

var _mode := ""           # "", "msg", "menu"
var _lines: Array = []
var _title := ""
var _on_done := Callable()
var _builder := Callable()
var _on_pick := Callable()
var _on_close := Callable()
var _footer := ""
var _sel := 0
var _opts: Array = []
var _opened := -1
var _queue: Array = []
var _gen := 0
var _voices: Array = []   # speaker per wrapped line ("" = silent narration)
var _shown := 0.0         # characters revealed so far (typewriter)
var _total := 0
var _last_blip := 0

const CPS := 55.0         # typewriter speed, characters per second

func is_open() -> bool:
	return _mode != ""

## voice: who is talking on lines that don't say so themselves ("Gus: \"...\"" names its own speaker).
func message(lines: Array, on_done: Callable = Callable(), title: String = "", voice: String = "") -> void:
	if is_open():
		_queue.append([lines, on_done, title, voice])
		return
	_lines = []
	_voices = []
	for l in lines:
		var who: String = Sfx.speaker_of(str(l))
		if who == "":
			who = voice if str(l) != "" and not str(l).begins_with("*") else ""
		var wrapped := Game.wrap(str(l), 540, SIZE)
		_lines.append_array(wrapped)
		for w in wrapped:
			_voices.append(who)
	_total = 0
	for l in _lines:
		_total += l.length()
	_shown = 0.0
	_last_blip = 0
	_title = title
	_on_done = on_done
	_open("msg")

func menu(title: String, builder: Callable, on_pick: Callable, on_close: Callable = Callable(),
		footer: String = "W / S choose   Space / Enter pick") -> void:
	_title = title
	_builder = builder
	_on_pick = on_pick
	_on_close = on_close
	_footer = footer
	_sel = 0
	_gen += 1
	_opts = builder.call()
	_open("menu")

func _open(m: String) -> void:
	_mode = m
	_opened = Engine.get_process_frames()
	Game.modal = true
	visible = true
	queue_redraw()

func _close() -> void:
	_mode = ""
	visible = false
	Game.modal = false
	Game.block_frame = Engine.get_process_frames()
	if not _queue.is_empty():
		var q: Array = _queue.pop_front()
		message(q[0], q[1], q[2], q[3])

func _process(_dt: float) -> void:
	if _mode == "" or Engine.get_process_frames() == _opened:
		return
	var go := Input.is_action_just_pressed("act") or Input.is_action_just_pressed("map")
	if _mode == "msg":
		if _shown < _total:
			_shown = minf(_total, _shown + _dt * CPS)
			_babble()
			if go:
				_shown = _total          # first press shows the whole page
			queue_redraw()
		elif go or Input.is_action_just_pressed("cancel"):
			Sfx.stop_ring()
			var cb := _on_done
			_close()
			if cb.is_valid():
				cb.call()
	elif _mode == "menu":
		if Input.is_action_just_pressed("up"):
			_sel = wrapi(_sel - 1, 0, _opts.size())
		elif Input.is_action_just_pressed("down"):
			_sel = wrapi(_sel + 1, 0, _opts.size())
		elif Input.is_action_just_pressed("cancel"):
			var cb := _on_close
			_close()
			if cb.is_valid():
				cb.call()
		elif go and not _opts.is_empty():
			var g := _gen
			var keep: bool = _on_pick.call(_sel)
			if _gen != g:
				pass  # the pick opened a fresh menu
			elif keep and _mode == "menu":
				_opts = _builder.call()
				_sel = clampi(_sel, 0, _opts.size() - 1)
			elif _mode == "menu":
				_close()
		queue_redraw()

func _draw() -> void:
	if _mode == "msg":
		var h := 36 + _lines.size() * LH + (LH if _title != "" else 0)
		var r := Rect2(40, 200 - h / 2.0, 560, h)
		Art.box(self, r, Pal.WHITE, Pal.RED)
		var y := r.position.y + 22
		if _title != "":
			Art.text(self, Vector2(r.position.x + 12, y), _title, Pal.RED, SIZE)
			y += LH + 2
		var left := int(_shown)
		for l in _lines:
			if left <= 0:
				break
			Art.text(self, Vector2(r.position.x + 12, y), l.substr(0, left), Pal.BLACK, SIZE)
			left -= l.length()
			y += LH
		if _shown >= _total:
			Art.text(self, Vector2(r.end.x - 120, r.end.y - 8), "[Space / Enter]", Pal.DGRAY, 10)

	elif _mode == "menu":
		var rows := mini(_opts.size(), 16)
		var h := 56 + rows * LH
		var r := Rect2(30, 196 - h / 2.0, 580, h)
		Art.box(self, r, Pal.WHITE, Pal.BLUE)
		Art.text(self, Vector2(r.position.x + 12, r.position.y + 20), _title, Pal.BLUE, SIZE)
		var first := clampi(_sel - rows + 1, 0, maxi(0, _opts.size() - rows))
		for i in rows:
			var idx := first + i
			var y := r.position.y + 38 + i * LH
			var s: String = _opts[idx]
			if idx == _sel:
				draw_rect(Rect2(r.position.x + 8, y - 11, r.size.x - 16, LH), Pal.BLUE)
				Art.text(self, Vector2(r.position.x + 12, y), s, Pal.WHITE, SIZE)
			else:
				var col := Pal.RED if s.contains("SALE") else Pal.BLACK
				Art.text(self, Vector2(r.position.x + 12, y), s, col, SIZE)
		Art.text(self, Vector2(r.position.x + 12, r.end.y - 8), _footer, Pal.DGRAY, 10)

## One mumbled syllable every seven letters (about eight a second), in the voice of whoever is speaking on that line.
func _babble() -> void:
	var n := int(_shown)
	if n - _last_blip < 7:
		return
	_last_blip = n
	var left := n
	for i in _lines.size():
		var len: int = _lines[i].length()
		if left <= len:
			var ch: String = _lines[i].substr(maxi(0, left - 1), 1) if left > 0 else " "
			if ch != " ":
				Sfx.blip(_voices[i])
			return
		left -= len
