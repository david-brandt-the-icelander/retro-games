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
	j.tpl = j.tpl.duplicate()
	j.tpl.cheque = 1.0
	j.tpl.bounce = 0.0
	var lines := Game.finish_job(j)
	check(Game.jobs.is_empty() and Game.next_call > Game.minute, "finishing a job schedules the next call")
	check(Game.cheques.size() == 1 and Game.jobs.is_empty(), "job paid by cheque: " + str(lines[2]))
	Game.cash_cheques()
	check(Game.cash == 100 + j.tpl.pay and Game.cheques.is_empty(), "cheque cashed")
	Game.cheques.append({"amount": 50, "from": "Test", "bounce": 1.0})
	Game.cash_cheques()
	check(Game.cash == 100 + j.tpl.pay - 25, "bounced cheque costs $25")
	# drive: red light / pedestrian / trash can
	m.to_drive("shop")
	await wait(3)
	var before := Game.cash
	var tc: Dictionary = {}
	for o in m.drive.objs:
		if o.kind == "trash":
			tc = o
			break
	m.drive.van_pos = tc.pos
	m.drive.van_vel = Vector2(100, 0)
	m.drive._check_hits()
	check(Game.cash == before - 40, "trash can costs $40")
	# running out of gas tows you
	Game.gas = 0.0
	await wait(3)
	check(Game.modal, "out of gas message")
	await settle()
	check(Game.gas == 3.0 and m.mode == "drive", "towed to the gas station")
	var day0 := Game.day
	m.drive.peds[0].pos = m.drive.van_pos
	m.drive.van_vel = Vector2(200, 0)
	m.drive._check_hits()
	await wait(3)
	check(m.mode == "cut", "hitting a pedestrian gets you arrested")
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
	m.end_day()
	await wait(3)
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
	print("FLOW DONE, failures: ", fails)
	get_tree().quit(1 if fails > 0 else 0)
