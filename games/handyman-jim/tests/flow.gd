extends Node
## Headless logic test of the day/week flow. Run: godot --headless --path . res://tests/flow.tscn

var m: Node
var fails := 0

func check(cond: bool, what: String) -> void:
	print(("PASS " if cond else "FAIL ") + what)
	if not cond:
		fails += 1

func wait(f: int = 3) -> void:
	for i in f:
		await get_tree().process_frame

func act() -> void:
	var e := InputEventAction.new()
	e.action = "act"
	e.pressed = true
	Input.parse_input_event(e)
	await wait(2)
	var r := InputEventAction.new()
	r.action = "act"
	Input.parse_input_event(r)
	await wait(2)

## Press E until the game is back in a playable mode with no dialog.
func settle() -> void:
	for i in 12:
		if m.mode in ["drive", "room"] and not Game.modal:
			return
		await get_tree().create_timer(1.3).timeout
		await act()

func _ready() -> void:
	m = load("res://main.tscn").instantiate()
	add_child(m)
	await wait(5)
	await settle()
	check(m.mode == "room" and Game.day == 0, "game starts Monday in the shop")
	# phone call -> job
	Game.next_call = Game.minute
	await wait(3)
	check(Game.modal, "phone rings")
	await settle()
	check(Game.jobs.size() == 1, "call creates a job")
	Game.next_call = Game.minute
	await wait(5)
	check(not Game.modal and Game.jobs.size() == 1, "no new call while a job is open")
	var j: Dictionary = Game.jobs[0]
	for item in j.tpl.mats:
		Game.add_item(item, j.tpl.mats[item])
	check(Game.missing(j).is_empty(), "materials satisfied")
	Game.cash = 100
	Game.debt = 0
	var lines := Game.finish_job(j)
	check(Game.jobs.is_empty() and Game.next_call > Game.minute, "finishing a job schedules the next call")
	check(Game.cash == 100 + j.tpl.pay and not "CHEQUE" in " ".join(lines), "jobs pay cash, never cheques: " + str(lines[2]))
	# fines go to debt, never take cash; debt is paid off from cash
	Game.fine(60, "test fine")
	check(Game.debt == 60 and Game.cash == 100 + j.tpl.pay, "a fine adds to debt and leaves cash alone")
	Game.cash = 40
	check(Game.pay_debt() == 40 and Game.cash == 0 and Game.debt == 20, "paying debt uses what cash there is")
	Game.cash = 100
	check(Game.pay_debt() == 20 and Game.cash == 80 and Game.debt == 0, "paying debt clears it")
	Game.cash = 100
	check(Game.pay_rent() == Data.SHOP_RENT - 100 and Game.cash == 0 and Game.debt == Data.SHOP_RENT - 100, "rent the cash can't cover becomes debt")
	Game.cash = 500
	Game.debt = 0
	# drive: red light / pedestrian / trash can
	m.to_drive("shop")
	await wait(3)
	var before := Game.cash
	Game.debt = 0
	var tc: Dictionary = {}
	for o in m.drive.objs:
		if o.kind == "trash":
			tc = o
			break
	m.drive.van_pos = tc.pos
	m.drive.van_vel = Vector2(100, 0)
	m.drive._check_hits()
	check(Game.cash == before and Game.debt == 40, "a trash can adds $40 to debt, cash untouched")
	# running out of gas tows you
	Game.gas = 0.0
	await wait(3)
	check(Game.modal, "out of gas message")
	await settle()
	check(Game.gas == 3.0 and m.mode == "drive", "towed to the gas station")
	var day0 := Game.day
	var cash_at_arrest := Game.cash
	m.drive.peds[0].pos = m.drive.van_pos
	m.drive.van_vel = Vector2(200, 0)
	m.drive._check_hits()
	await wait(3)
	check(m.mode == "cut", "hitting a pedestrian gets you arrested")
	check(Game.cash == cash_at_arrest and Game.debt >= 500, "bail goes to debt (debt $%d)" % Game.debt)
	await settle()
	check(Game.day == day0 + 1 and m.mode == "room", "arrest ends the day; next morning in the shop")
	# red-light tickets
	m.to_drive("shop")
	await wait(2)
	Game.tickets_today = 2
	var light_t := 0.0
	while Town.light(1, 1, "EW", light_t) != "R":
		light_t += 0.5
	m.drive.t = light_t
	m.drive.in_box = Vector2i(-1, -1)
	m.drive.van_pos = Vector2(950, 950)
	m.drive.van_vel = Vector2(200, 0)
	for c in m.drive.cars:
		if c.kind == "cop":
			c.pos = Vector2(1000, 950)
	m.drive._check_lights()
	await wait(3)
	check(m.mode == "cut", "third red light ticket = jail")
	await settle()
	# Friday night -> weekend -> Monday rent
	Game.day = 4
	Game.cash = 900
	Game.debt = 0
	m.end_day()
	await wait(3)
	for i in 5:   # the message types out, so it can take two presses to close
		if m.mode == "cut":
			break
		await act()
		await wait(3)
	check(m.mode == "cut" and m.cut.scene == "bar", "$900 Friday = bar weekend scene (%s)" % m.cut.scene)
	await settle()
	check(Game.week == 2 and Game.day == 0 and Game.cash == 900 - Data.SHOP_RENT, "week 2 Monday, rent paid")
	# clock runs and ends the day by itself
	Game.minute = Data.DAY_END - 0.5
	await get_tree().create_timer(1.0).timeout
	check(Game.modal, "7 PM quitting time triggers")
	await settle()
	check(Game.day == 1, "Tuesday after sleeping")
	# rolling into a driveway stops the van
	await settle()
	m.to_drive("shop")
	await wait(2)
	var lot: Rect2 = Town.place("shop").lot
	m.drive.current_lot = ""
	m.drive.van_pos = lot.get_center()
	m.drive.van_speed = 150.0
	m.drive.van_vel = Vector2(0, -150)
	m.drive._update_van(0.016)
	check(m.drive.van_speed == 0.0 and m.drive.van_vel == Vector2.ZERO, "driving into a driveway stops the van")
	# Enter opens the map-and-jobs planner, and nothing moves while it is open
	var e := InputEventAction.new()
	e.action = "map"
	e.pressed = true
	Input.parse_input_event(e)
	await wait(2)
	var r := InputEventAction.new()
	r.action = "map"
	Input.parse_input_event(r)
	await wait(2)
	check(m.hud.planner, "Enter opens the map and job board")
	var t0 := Game.minute
	var cars0: Vector2 = m.drive.cars[0].pos
	await get_tree().create_timer(1.0).timeout
	check(Game.minute == t0 and m.drive.cars[0].pos == cars0, "the game is frozen while the planner is open")
	m.hud.planner = false
	# sounds are generated, and speakers sound different
	check(Sfx._ring.data.size() > 100000 and Sfx.VOICE.get_length() > 40.0 and Sfx.PHRASES.size() > 20, "ring generated and the mumble recording loaded")
	check(Sfx.speaker_of("Gus: \"Ope.\"") == "Gus" and Sfx.speaker_of("*BRRRING*") == "", "speaker detection")
	check(absf(Sfx.voice_pitch("Gus") - Sfx.voice_pitch("Brenda Kowalski")) > 0.01 and Sfx.voice_pitch("JIM") < Sfx.voice_pitch("Gus") and Sfx.voice_pitch("JIM") < 0.85, "each speaker has their own pitch, Jim lowest")
	# a speaker talks in continuous phrases and stops when told to
	Sfx.talk("Gus")
	var first_talker: String = Sfx._talker
	Sfx.talk("Gus")
	check(first_talker == "Gus" and Sfx._talker == "Gus" and absf(Sfx._talk.pitch_scale - Sfx.voice_pitch("Gus")) < 0.001,
		"a speaker talks at their own pitch (%s, %.4f vs %.4f)" % [first_talker, Sfx._talk.pitch_scale, Sfx.voice_pitch("Gus")])
	Sfx.hush()
	check(Sfx._talker == "", "talking stops when the line is done")
	# every line of dialog is voiced: narration by the narrator, people in their own voices
	m.dialog.message(["You knock on the door.", "Gus: \"Ope.\"", "*SLAM*"])
	check(m.dialog._voices == [Sfx.NARRATOR, "Gus", ""], "narration and speech are voiced, sound effects are not (%s)" % str(m.dialog._voices))
	m.dialog._close()
	# the names Jan and Dale are not used, and Jim's parents are never mentioned
	var banned := RegEx.create_from_string("(?i)\\b(jan|dale|mother|father|mom|dad|parents?)\\b")
	var hits := []
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var text := FileAccess.get_file_as_string("res://scripts/" + f)
			for mt in banned.search_all(text):
				hits.append("%s: %s" % [f, mt.get_string()])
	check(hits.is_empty(), "no Jan, no Dale, no parents %s" % str(hits))
	# Escape closes a dialog window at once, and the story carries on
	var closed := [false]
	m.dialog.message(["A long message that is still typing out when Escape is pressed, so it should close at once anyway."], func(): closed[0] = true)
	await wait(2)
	var esc := InputEventAction.new()
	esc.action = "cancel"
	esc.pressed = true
	Input.parse_input_event(esc)
	await wait(2)
	var esc_up := InputEventAction.new()
	esc_up.action = "cancel"
	Input.parse_input_event(esc_up)
	await wait(2)
	check(not m.dialog.is_open() and closed[0], "Escape closes a dialog and runs what comes next")
	# the only controls are WASD, Space and Enter (plus Escape to close windows)
	var allowed := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]
	var stray := []
	for action in ["up", "down", "left", "right", "act", "map", "jobs", "cancel", "horn"]:
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey and not allowed.has(ev.physical_keycode):
				stray.append(OS.get_keycode_string(ev.physical_keycode))
	check(stray.is_empty(), "only WASD, Space, Enter and Escape are bound %s" % str(stray))
	print("FLOW DONE, failures: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
