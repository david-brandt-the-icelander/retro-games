extends Node
## Game flow: title -> days of phone calls, driving, shopping, fixing -> Zzzz -> weekend.

var mode := "title"   # title | drive | room | cut
var drive: Node2D
var room: Node2D
var cut: Node2D
var hud: Node2D
var dialog: Node2D
var ending_day := false

func _ready() -> void:
	drive = Node2D.new()
	drive.set_script(load("res://scripts/drive.gd"))
	drive.main = self
	add_child(drive)
	drive.deactivate()
	room = Node2D.new()
	room.set_script(load("res://scripts/room_view.gd"))
	room.main = self
	add_child(room)
	room.deactivate()
	var cl := CanvasLayer.new()
	cl.layer = 4
	add_child(cl)
	cut = Node2D.new()
	cut.set_script(load("res://scripts/cutscene.gd"))
	cl.add_child(cut)
	var hl := CanvasLayer.new()
	hl.layer = 5
	add_child(hl)
	hud = Node2D.new()
	hud.set_script(load("res://scripts/hud.gd"))
	hud.main = self
	hl.add_child(hud)
	var dl := CanvasLayer.new()
	dl.layer = 10
	add_child(dl)
	dialog = Node2D.new()
	dialog.set_script(load("res://scripts/dialog.gd"))
	dl.add_child(dialog)
	dialog.visible = false
	_title()

func _title() -> void:
	mode = "cut"
	cut.play("title", ["WASD drive & walk     Space act / honk     Enter map & jobs",
		"Press Space or Enter to start your week."], func():
			Game.new_game()
			dialog.message([
				"Name's Jim. Handyman Jim. I fix things in Marshfield, Wisconsin.",
				"Folks here break stuff in ways science can't explain. I get the call, I grab the parts, I fix it, I get paid. Mostly.",
				"Watch the red lights - three tickets in a day and Sgt. Brekke locks me up. Run somebody over and he locks me up right away.",
				"And the van's got a big engine. Real big. Stoppin' is more of a suggestion.",
			], Callable(), "WELCOME TO JIM'S FIX-IT SHACK", "JIM")
			_morning())

func _morning() -> void:
	Game.start_day()
	drive.reset_day()
	ending_day = false
	room.start_inside(Town.place("shop"), "Workshop")
	drive.deactivate()
	mode = "room"
	if Game.day == 0 and Game.week > 1:
		Game.cash -= Data.SHOP_RENT
		dialog.message(["Monday. Shop rent is due: $%d. The landlord, Mrs. Dombrowski, counts it twice." % Data.SHOP_RENT])

func _process(dt: float) -> void:
	if mode != "drive" and mode != "room":
		return
	if Game.modal or hud.paused() or room.fixing > 0:
		return
	Game.minute += dt * Game.MIN_PER_SEC
	Game.check_deadlines()
	if Game.minute >= Data.DAY_END:
		end_day()
	elif Game.call_due():
		_incoming_call()

func _incoming_call() -> void:
	var j := Game.make_job()
	var tpl: Dictionary = j.tpl
	Sfx.ring()
	# First the phone rings; answering (Space / Enter) stops it and the caller talks.
	dialog.message(["*BRRRING BRRRING*", "*BRRRING BRRRING*", "", "The shop phone. Somebody's broken something again."],
		func(): _answer_call(j), "THE PHONE IS RINGING - %s" % Game.clock_text())

func _answer_call(j: Dictionary) -> void:
	var tpl: Dictionary = j.tpl
	var call: Array = ["JIM: \"Handyman Jim, what'd ya break?\"", ""]
	call.append_array(tpl.call)
	call.append("")
	call.append("JIM: \"%s\"" % tpl.jim)
	var order_cb := func():
		Game.jobs.append(j)
		var order: Array = ["Where: the %s place, %s  (job #%d, flashing on the map)" % [Game.last_name(j), Game.address(j), j.num],
			"Pays: $%d   Due in: %d minutes   (late = half pay)" % [tpl.pay, int(j.deadline - Game.minute)], "Need:"]
		for item in tpl.mats:
			order.append("   %d x %s" % [tpl.mats[item], Data.ITEMS[item][0]])
		order.append("Enter opens the map and job board: who sells what, and today's sales.")
		dialog.message(order, Callable(), "WORK ORDER #%d" % j.num)
	dialog.message(call, order_cb, "%s ON THE LINE" % tpl.customer.to_upper(), tpl.customer)

func enter_place(p: Dictionary) -> void:
	drive.deactivate()
	room.activate(p)
	mode = "room"

func to_drive(place_id: String) -> void:
	room.deactivate()
	drive.activate(place_id)
	mode = "drive"

func arrest(why: String, bail: int) -> void:
	if ending_day:
		return
	ending_day = true
	mode = "cut"
	drive.deactivate()
	room.deactivate()
	Game.cash -= bail
	var lost := Game.end_day_cancel()
	var lines: Array = [why, "Bail: $%d. You spend the night in the lockup. The bologna sandwich is a crime too." % bail]
	if not lost.is_empty():
		lines.append("Your open jobs went to cousin Lyle.")
	cut.play("arrest", lines, _night)

func end_day() -> void:
	if ending_day:
		return
	ending_day = true
	var lines: Array = ["%s, %s. Jim's done for the day." % [Game.day_name(), Game.clock_text()]]
	lines.append_array(Game.end_day_cancel())
	if not Game.cheques.is_empty():
		lines.append("You've still got %d uncashed cheque(s). The bank opens at 9." % Game.cheques.size())
	dialog.message(lines, func():
		mode = "cut"
		drive.deactivate()
		room.deactivate()
		_night(), "QUITTIN' TIME")

func _night() -> void:
	mode = "cut"
	if Game.day >= 4:
		var w := Game.weekend_scene()
		var lines: Array = [w[2], "Week %d: earned $%d, fixed %d messes. Cash on hand: $%d." % [Game.week,
			Game.week_income, Game.jobs_done_week, Game.cash]]
		cut.play(w[1], lines, func():
			Game.week += 1
			Game.day = 0
			Game.week_income = 0
			Game.jobs_done_week = 0
			cut.play("sleep", ["Zzzz... Sunday night. Monday comes for us all.", "Week %d begins." % Game.week], _morning))
	else:
		Game.day += 1
		var dreams := ["Jim dreams of a world where nobody owns a deep fryer.",
			"Jim dreams he's a toilet. It's not a good dream.",
			"Duke kicks in his sleep. Chasing Pickles the raccoon, probably.",
			"Jim dreams of cheese curds that don't squeak. A nightmare, really."]
		cut.play("sleep", ["Z z z z . . .  " + dreams[Game.rng.randi_range(0, dreams.size() - 1)],
			"%s morning, 7:00 AM." % Game.day_name()], _morning)
