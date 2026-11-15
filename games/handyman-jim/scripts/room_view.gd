extends Node2D
## Side-view location screens: the outside of a building (Sierra style) and its
## rooms, linked by obvious doors left/right. Walk with Left/Right, E to act.

const FLOOR := 248.0
const FEET_IN := 318.0
const FEET_OUT := 330.0
const DOOR_X := 150.0     # front door on the back wall of the entry room
const SPOT_X := 450.0     # counter / disaster position
const SPEED := 120.0

var main: Node
var place: Dictionary = {}
var job: Dictionary = {}
var rooms: Array = []     # [0] is always "outside"
var entry := 1
var room := 0
var jim_x := 160.0
var facing := 1
var phase := 0.0
var t := 0.0
var fixing := 0.0
var _store_actions: Array = []
var jokes_seen := {}

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED

func activate(p: Dictionary) -> void:
	place = p
	job = Game.job_for_house(p.id) if p.kind == "house" else {}
	match p.kind:
		"house":
			rooms = ["outside"] + (job.rooms if not job.is_empty() else ["Living Room"])
			entry = 2 if not job.is_empty() else 1
		"shop":
			rooms = ["outside", "Workshop", "Bunkroom"]
			entry = 1
		_:
			rooms = ["outside", p.kind]
			entry = 1
	room = 0
	jim_x = 175.0
	facing = 1
	fixing = 0.0
	visible = true

func start_inside(p: Dictionary, r: String) -> void:
	activate(p)
	room = rooms.find(r)
	jim_x = 300.0

func deactivate() -> void:
	visible = false

func room_name() -> String:
	return rooms[room]

## Hotspots for the current room: [x, half-width, prompt, callable]
func hotspots() -> Array:
	var hs := []
	var r := room_name()
	if r == "outside":
		hs.append([100.0, 60.0, "Get back in the van", func(): main.to_drive(place.id)])
		hs.append([330.0, 30.0, "Go inside", _go_in])
		return hs
	if room == entry:
		hs.append([DOOR_X, 25.0, "Go back outside", func(): _goto(0, 330.0)])
	match r:
		"hardware", "plumbing", "electric", "lumber", "farm":
			hs.append([SPOT_X + 40, 50.0, "Talk to %s at the counter" % Data.STORES[r].keeper, func(): open_store(r)])
		"gas":
			hs.append([SPOT_X + 40, 50.0, "Talk to Tiffany at the register", _gas_menu])
		"bank":
			hs.append([SPOT_X + 40, 50.0, "Talk to the teller", _bank_menu])
		"police":
			hs.append([SPOT_X + 40, 50.0, "Talk to Sgt. Brekke", _police_talk])
		"tavern":
			hs.append([SPOT_X + 40, 50.0, "Belly up to the bar", _tavern_menu])
		"Workshop":
			hs.append([SPOT_X + 20, 50.0, "Sell leftovers to walk-ins", _sell_menu])
			hs.append([300.0, 25.0, "Check the answering machine", _machine])
		"Bunkroom":
			hs.append([SPOT_X, 50.0, "Call it a day (sleep)", _sleep_menu])
			hs.append([250.0, 30.0, "Pet Duke the dog", func(): Game.say("Duke thumps his tail. He believes in you.")])
		_:
			if not job.is_empty() and r == job.tpl.room:
				hs.append([SPOT_X, 45.0, "Fix the mess (%s)" % job.tpl.customer, _try_fix])
			elif room != entry or r != "Living Room":
				hs.append([300.0, 30.0, "Look around", func(): _look(r)])
	return hs

func current_hotspot() -> Array:
	for h in hotspots():
		if absf(jim_x - h[0]) < h[1]:
			return h
	return []

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	queue_redraw()
	if main.hud.paused():
		return
	if fixing > 0:
		fixing -= dt
		if fixing <= 0:
			_fix_done()
		return
	if not Game.free_input():
		return
	var mv := 0.0
	if Input.is_action_pressed("left"):
		mv -= 1.0
	if Input.is_action_pressed("right"):
		mv += 1.0
	if mv != 0.0:
		facing = int(mv)
		phase += dt * 10.0
		jim_x += mv * SPEED * dt
	_edges()
	if Input.is_action_just_pressed("act") or Input.is_action_just_pressed("up"):
		var h := current_hotspot()
		if not h.is_empty():
			h[3].call()

func _edges() -> void:
	if room == 0:
		jim_x = clampf(jim_x, 40.0, 600.0)
		return
	if jim_x < 14.0:
		if room - 1 >= 1:
			_goto(room - 1, 600.0)
		else:
			jim_x = 14.0
	elif jim_x > 626.0:
		if room + 1 < rooms.size():
			_goto(room + 1, 40.0)
		else:
			jim_x = 626.0

func _goto(r: int, x: float) -> void:
	room = r
	jim_x = x
	Game.advance(1)

func _go_in() -> void:
	if place.kind == "bank" and (Game.minute < 9 * 60 or Game.minute >= 17 * 60):
		main.dialog.message(["The door's locked. Sign says: OPEN 9 TO 5. NO EXCEPTIONS, JIM."])
		return
	if place.kind == "house" and job.is_empty():
		var lines := ["You knock. A man in a Brett Favre jersey opens the door.",
			"Favre jersey guy: \"We didn't call no handyman. Unless you're sellin' brats?\" *SLAM*"]
		if Game.rng.randf() < 0.5:
			lines = ["You knock. A lady peeks through the blinds.",
				"Lady at the blinds: \"If this is about the lawn flamingos, I've never seen 'em before in my life.\""]
		main.dialog.message(lines)
		return
	_goto(entry, DOOR_X + 30)

# ---------------------------------------------------------------- actions

func _needed(item: String) -> int:
	var n := 0
	for j in Game.jobs:
		n += j.tpl.mats.get(item, 0)
	return n

func open_store(store: String) -> void:
	var s: Dictionary = Data.STORES[store]
	var greet := ["%s: \"Jim! What'd they break this time?\"" % s.keeper,
		"%s: \"Ope, there he is.\"" % s.keeper, "%s: \"Cash only. Your cheques scare me.\"" % s.keeper]
	Game.say(greet[Game.rng.randi_range(0, 2)])
	var _b := func() -> Array:
		_store_actions = []
		var rows := []
		for item in s.stock:
			var pr := Game.price(store, item)
			var row := "BUY  %-20s $%-4d have %d" % [Data.ITEMS[item][0], pr, Game.have(item)]
			if _needed(item) > 0:
				row += "   need %d" % _needed(item)
			if Game.sales.has("%s:%s" % [store, item]):
				row += "   SALE -%d%%" % int(Game.sales["%s:%s" % [store, item]] * 100)
			rows.append(row)
			_store_actions.append(["buy", item, pr])
		for item in Game.inventory:
			if s.stock.has(item):
				rows.append("SELL %-20s $%-4d have %d" % [Data.ITEMS[item][0], Game.sell_price(item), Game.have(item)])
				_store_actions.append(["sell", item, Game.sell_price(item)])
		rows.append("Leave")
		_store_actions.append(["leave"])
		return rows
	var _p := func(i: int) -> bool:
		var a: Array = _store_actions[i]
		if a[0] == "leave":
			return false
		if a[0] == "buy":
			if Game.cash < a[2]:
				Game.say("%s: \"Short on cash, Jim. Hit the bank.\"" % s.keeper)
			else:
				Game.cash -= a[2]
				Game.add_item(a[1])
				Game.advance(2)
				Game.say("Bought %s for $%d." % [Data.ITEMS[a[1]][0], a[2]])
		else:
			Game.cash += a[2]
			Game.add_item(a[1], -1)
			Game.say("Sold %s for $%d." % [Data.ITEMS[a[1]][0], a[2]])
		return true
	main.dialog.menu("%s   -   cash $%d" % [s.name, Game.cash], _b, _p)

func _gas_menu() -> void:
	var _b := func() -> Array:
		var gal := Data.TANK_SIZE - Game.gas
		return ["Fill 'er up: %.1f gal for $%d" % [gal, int(ceil(gal * Data.GAS_PRICE))],
			"Browse the shelves (duct tape, jerky...)", "Buy a gas station brat ($3)", "Leave"]
	var _p := func(i: int) -> bool:
		match i:
			0:
				var cost := int(ceil((Data.TANK_SIZE - Game.gas) * Data.GAS_PRICE))
				if Game.cash < cost:
					Game.say("Tiffany: \"Card declined. Wait, this is cash. Cash declined.\"")
				else:
					Game.cash -= cost
					Game.gas = Data.TANK_SIZE
					Game.advance(5)
					Game.say("Tank's full. $%d. Smells like victory and diesel." % cost)
				return true
			1:
				open_store("gas")
				return false
			2:
				Game.cash -= 3
				Game.say("The brat has been rolling since 1998. It is perfect.")
				return true
		return false
	main.dialog.menu("GAS-N-GRUB   -   cash $%d" % Game.cash, _b, _p)

func _bank_menu() -> void:
	var total := 0
	for c in Game.cheques:
		total += c.amount
	var _b := func() -> Array:
		return ["Cash my cheques (%d, $%d)" % [Game.cheques.size(), total], "Ask about a loan", "Leave"]
	var _p := func(i: int) -> bool:
		if i == 0:
			Game.advance(10)
			main.dialog.message(Game.cash_cheques(), Callable(), "TELLER WINDOW")
		elif i == 1:
			main.dialog.message(["Loan officer Gail: \"Jim, you listed 'a van' and 'Duke' as collateral.\"",
				"\"Duke is a dog.\" She stamps DENIED with real enthusiasm."])
		return false
	main.dialog.menu("FIRST DAIRYLAND BANK", _b, _p)

func _police_talk() -> void:
	var lines := [
		"Sgt. Brekke: \"Jim. Drive slower. Please. For all of us.\"",
		"Sgt. Brekke: \"Somebody stole the lawn flamingos off the Mayor's yard again.\"",
		"Sgt. Brekke: \"Your van was clocked at 60 in front of the school. In REVERSE.\"",
	]
	main.dialog.message([lines[Game.rng.randi_range(0, lines.size() - 1)],
		"Red light tickets today: %d of 3 before you're jailed." % Game.tickets_today])

func _tavern_menu() -> void:
	var _b := func() -> Array:
		return ["Basket of cheese curds ($7)", "Buy the bartender a beer for gossip ($5)", "Leave"]
	var _p := func(i: int) -> bool:
		if i == 0:
			Game.cash -= 7
			Game.advance(10)
			Game.say("SQUEAK. SQUEAK. Perfection.")
			return true
		if i == 1:
			Game.cash -= 5
			var lines := ["Bartender Lou leans in: \"Here's what I'm hearin' about sales today...\""]
			for k in Game.sales:
				var parts: PackedStringArray = k.split(":")
				lines.append("  %s: %s %d%% off" % [Data.STORES[parts[0]].name, Data.ITEMS[parts[1]][0], int(Game.sales[k] * 100)])
			main.dialog.message(lines)
		return false
	main.dialog.menu("THE RUSTY MUSKIE   -   cash $%d" % Game.cash, _b, _p)

func _sell_menu() -> void:
	var _b := func() -> Array:
		_store_actions = []
		var rows := []
		for item in Game.inventory:
			rows.append("SELL %-20s $%-4d have %d" % [Data.ITEMS[item][0], Game.sell_price(item), Game.have(item)])
			_store_actions.append(item)
		rows.append("Done")
		_store_actions.append("")
		return rows
	var _p := func(i: int) -> bool:
		var item: String = _store_actions[i]
		if item == "":
			return false
		Game.cash += Game.sell_price(item)
		Game.add_item(item, -1)
		Game.say("A guy named Rollie buys your %s." % Data.ITEMS[item][0])
		return true
	main.dialog.menu("WALK-IN CUSTOMERS (they pay half)", _b, _p)

func _machine() -> void:
	var msgs := ["BEEP. \"Jim, it's the bait shop. Your minnows are in. All four hundred of 'em.\"",
		"BEEP. \"This is Lyle. Can I borrow the van? ...Jim? I already took the ladder.\"",
		"BEEP. \"Hi, this is about your van's extended warranty—\" *you smash the button*"]
	main.dialog.message([msgs[Game.rng.randi_range(0, msgs.size() - 1)]])

func _sleep_menu() -> void:
	var _b := func() -> Array:
		return ["Yep, call it a day", "Nah, keep workin'"]
	var _p := func(i: int) -> bool:
		if i == 0:
			main.end_day()
		return false
	main.dialog.menu("Hit the hay already? It's only %s." % Game.clock_text(), _b, _p)

func _look(r: String) -> void:
	var looks := {
		"Living Room": "A deer head mounted over the TV. It's wearing sunglasses.",
		"Kitchen": "A fridge covered in Packers magnets. There's a hotdish in there older than you.",
		"Bathroom": "A framed poster of a muskie. In the bathroom. Bold choice.",
		"Bedroom": "The bed is unmade. There's a cheesehead on the pillow.",
		"Basement": "Wood-panelled walls. A dusty bar with one stool. Classic.",
		"Garage": "Forty-two coffee cans of assorted screws. You respect this man.",
		"Attic": "Boxes labelled XMAS 1987. Something moved. Probably nothing.",
		"Back Deck": "A grill the size of a canoe.",
		"Back Yard": "A lawn flamingo. Wait, that's the Mayor's lawn flamingo.",
	}
	main.dialog.message([looks.get(r, "Nothing much here.")])

func _try_fix() -> void:
	var miss := Game.missing(job)
	if not miss.is_empty():
		var lines := ["You don't have everything you need. Still missing:"]
		for item in miss:
			lines.append("  %d x %s" % [miss[item], Data.ITEMS[item][0]])
		lines.append("%s: \"You're kidding me, Jim.\"" % job.tpl.customer.split(" ")[0])
		main.dialog.message(lines)
		return
	fixing = 2.5

func _fix_done() -> void:
	var lines := Game.finish_job(job)
	var who: String = job.tpl.customer
	job = {}
	main.dialog.message(lines, Callable(), "JOB DONE: " + who.to_upper())

# ---------------------------------------------------------------- drawing: outside

const FACADE := {"shop": [Pal.RED, Pal.BROWN], "gas": [Pal.WHITE, Pal.LGRAY],
	"hardware": [Pal.RED, Pal.BROWN], "bank": [Pal.LGRAY, Pal.WHITE], "police": [Pal.RED, Pal.BROWN],
	"tavern": [Pal.BROWN, Pal.DGRAY], "plumbing": [Pal.LBLUE, Pal.BLUE], "electric": [Pal.YELLOW, Pal.BROWN],
	"lumber": [Pal.BROWN, Pal.RED], "farm": [Pal.RED, Pal.LRED]}

func _draw() -> void:
	if room == 0:
		if not Art.try_png(self, "outside_" + place.kind, Rect2(0, 0, 640, 340)):
			_draw_outside()
		Art.van_side(self, Vector2(40, FEET_OUT + 4), 1.0)
		Art.jim(self, Vector2(jim_x, FEET_OUT), 1.3, facing, phase)
	else:
		var r := room_name()
		if Art.try_png(self, "room_" + r.to_lower().replace(" ", "_"), Rect2(0, 0, 640, 340)):
			if room == entry:
				_door(DOOR_X, "EXIT")
			_draw_problem()
		else:
			_draw_room(r)
		_draw_doors()
		_draw_people(r)
		Art.jim(self, Vector2(jim_x, FEET_IN), 1.6, facing, phase)
		if fixing > 0:
			var words := ["BANG!", "WHACK!", "*grunt*", "DAGNABBIT!", "SCREEEECH", "there we go"]
			Art.text_shadow(self, Vector2(jim_x - 30, 150 + sin(t * 12) * 6), words[int(t * 3) % words.size()], Pal.YELLOW, 16)
	var h := current_hotspot()
	if not h.is_empty() and not Game.modal and fixing <= 0:
		Art.text_shadow(self, Vector2(0, 360), "[SPACE] " + h[2], Pal.YELLOW, 12, HORIZONTAL_ALIGNMENT_CENTER, 640)

func _draw_outside() -> void:
	# sky + clouds + trees, in the manner of the old Sierra exteriors
	Art.shape(self, Rect2(0, 0, 640, 250), Pal.LCYAN)
	Art.circ(self, Vector2(300, 40), 60, Pal.BLUE)
	Art.circ(self, Vector2(370, 60), 45, Pal.BLUE)
	Art.circ(self, Vector2(560, 70), 30, Pal.LBLUE)
	Art.tree_side(self, Vector2(70, 250), 240)
	Art.tree_side(self, Vector2(615, 230), 120)
	Art.dfill(self, Rect2(0, 236, 640, 20), Pal.GREEN, Pal.LGREEN)
	if place.kind == "house":
		_draw_house_front()
	else:
		_draw_business_front()
	Art.shape(self, Rect2(0, 256, 640, 14), Pal.LGRAY)
	Art.dfill(self, Rect2(0, 270, 640, 70), Pal.DGRAY, Pal.BLACK)
	Art.shape(self, Rect2(200, 334, 160, 3), Pal.YELLOW)
	Art.shape(self, Rect2(420, 334, 160, 3), Pal.YELLOW)
	# chain-link fence on the right, like a proper municipal lot
	for k in 9:
		draw_line(Vector2(560 + k * 10, 250), Vector2(600 + k * 10, 340), Pal.LGRAY, 1)
		draw_line(Vector2(600 + k * 10, 250), Vector2(560 + k * 10, 340), Pal.LGRAY, 1)
	Art.shape(self, Rect2(558, 248, 3, 92), Pal.LGRAY)

func _draw_business_front() -> void:
	var cols: Array = FACADE.get(place.kind, [Pal.RED, Pal.BROWN])
	var fr := Rect2(170, 110, 400, 146)
	Art.dfill(self, fr, cols[0], cols[1])
	if cols[0] == Pal.RED or cols[0] == Pal.BROWN:
		var y := fr.position.y + 8
		while y < fr.end.y:
			draw_line(Vector2(fr.position.x, y), Vector2(fr.end.x, y), Pal.BLACK, 1)
			y += 10
	Art.shape(self, Rect2(fr.position.x - 4, fr.position.y - 30, fr.size.x + 8, 32), Pal.LGRAY)
	Art.shape(self, Rect2(fr.position.x + 30, fr.position.y - 26, fr.size.x - 60, 24), Pal.WHITE)
	Art.text(self, Vector2(fr.position.x, fr.position.y - 8), place.name, Pal.BLACK, 16, HORIZONTAL_ALIGNMENT_CENTER, fr.size.x)
	for wx in [200, 420, 500]:
		Art.shape(self, Rect2(wx, 150, 56, 40), Pal.BLACK)
		Art.shape(self, Rect2(wx + 3, 153, 50, 34), Pal.BLUE)
		draw_line(Vector2(wx + 8, 185), Vector2(wx + 30, 158), Pal.LMAGENTA, 3)
		draw_line(Vector2(wx + 26, 185), Vector2(wx + 48, 160), Pal.LCYAN, 2)
	Art.shape(self, Rect2(312, 160, 40, 96), Pal.BLACK)
	Art.shape(self, Rect2(315, 163, 34, 90), Pal.LBLUE)
	draw_line(Vector2(320, 240), Vector2(340, 175), Pal.LMAGENTA, 3)
	Art.shape(self, Rect2(342, 205, 4, 6), Pal.YELLOW)
	if place.kind in ["police", "bank"]:
		Art.shape(self, Rect2(470, 20, 4, 90), Pal.LGRAY)
		var wave := sin(t * 3) * 2
		for k in 7:
			Art.shape(self, Rect2(474, 22 + k * 5 + wave * (k % 2), 50, 5), Pal.RED if k % 2 == 0 else Pal.WHITE)
		Art.shape(self, Rect2(474, 22, 20, 18), Pal.BLUE)
	if place.kind == "gas":
		Art.shape(self, Rect2(440, 180, 22, 60), Pal.RED)
		Art.text(self, Vector2(436, 176), "$%.2f" % Data.GAS_PRICE, Pal.BLACK, 10)
	for bx in [190, 380, 520]:
		Art.circ(self, Vector2(bx, 248), 16, Pal.GREEN)
		Art.circ(self, Vector2(bx + 14, 250), 12, Pal.LGREEN)

func _draw_house_front() -> void:
	var wall: Color = place.get("wall", Pal.WHITE)
	var roof: Color = place.get("roof", Pal.RED)
	var fr := Rect2(190, 130, 300, 126)
	Art.shape(self, fr, wall)
	var y := fr.position.y + 6
	while y < fr.end.y:
		draw_line(Vector2(fr.position.x, y), Vector2(fr.end.x, y), Color(0, 0, 0, 0.25), 1)
		y += 7
	draw_colored_polygon(PackedVector2Array([Vector2(170, 132), Vector2(340, 50), Vector2(510, 132)]), roof)
	for wx in [215, 410]:
		Art.shape(self, Rect2(wx, 160, 50, 44), Pal.WHITE)
		Art.shape(self, Rect2(wx + 4, 164, 42, 36), Pal.BLUE)
		Art.shape(self, Rect2(wx + 24, 164, 2, 36), Pal.WHITE)
	Art.shape(self, Rect2(312, 170, 40, 86), Pal.BROWN)
	Art.shape(self, Rect2(342, 210, 4, 4), Pal.YELLOW)
	var j := Game.job_for_house(place.id)
	var label := "%d %s" % [place.number, place.street]
	if not j.is_empty():
		label = "THE %s PLACE   %s" % [Game.last_name(j).to_upper(), label]
	Art.text_shadow(self, Vector2(8, 32), label, Pal.WHITE, 12)
	Art.shape(self, Rect2(520, 214, 8, 42), Pal.DGRAY)          # mailbox post
	Art.shape(self, Rect2(512, 206, 24, 12), Pal.BLUE)
	Art.shape(self, Rect2(150, 236, 18, 22), Pal.DGRAY)          # trash can
	# lawn ornaments: a pink flamingo, naturally
	draw_line(Vector2(480, 256), Vector2(480, 238), Pal.BLACK, 1)
	Art.shape(self, Rect2(474, 230, 12, 8), Pal.LMAGENTA)
	Art.shape(self, Rect2(484, 222, 3, 10), Pal.LMAGENTA)

# ---------------------------------------------------------------- drawing: inside

const WALLS := {
	"Living Room": [Pal.BROWN, Color8(150, 75, 0)], "Kitchen": [Pal.YELLOW, Pal.WHITE],
	"Bathroom": [Pal.LCYAN, Pal.WHITE], "Bedroom": [Pal.LMAGENTA, Pal.MAGENTA],
	"Basement": [Pal.DGRAY, Pal.LGRAY], "Garage": [Pal.LGRAY, Pal.DGRAY],
	"Attic": [Pal.BROWN, Pal.BLACK], "Workshop": [Pal.BROWN, Pal.RED], "Bunkroom": [Pal.DGRAY, Pal.BROWN],
	"hardware": [Pal.WHITE, Pal.LGRAY], "plumbing": [Pal.LBLUE, Pal.WHITE], "electric": [Pal.YELLOW, Pal.WHITE],
	"lumber": [Pal.BROWN, Pal.YELLOW], "farm": [Pal.RED, Pal.BROWN], "gas": [Pal.WHITE, Pal.LCYAN],
	"bank": [Pal.LGRAY, Pal.WHITE], "police": [Pal.LCYAN, Pal.LGRAY], "tavern": [Pal.BROWN, Pal.BLACK],
}

func _draw_room(r: String) -> void:
	if r in ["Back Deck", "Back Yard"]:
		Art.shape(self, Rect2(0, 0, 640, FLOOR), Pal.LCYAN)
		Art.tree_side(self, Vector2(560, FLOOR), 200)
		for k in 32:
			Art.shape(self, Rect2(k * 20, 170, 4, 80), Pal.WHITE)
		Art.shape(self, Rect2(0, 185, 640, 4), Pal.WHITE)
		Art.shape(self, Rect2(0, 215, 640, 4), Pal.WHITE)
		Art.dfill(self, Rect2(0, FLOOR, 640, 92), Pal.GREEN, Pal.LGREEN)
		_draw_problem()
		return
	var wc: Array = WALLS.get(r, [Pal.LGRAY, Pal.WHITE])
	if r in ["Basement", "Garage", "Bathroom"]:
		Art.dfill(self, Rect2(0, 0, 640, FLOOR), wc[0], wc[1])
	else:
		Art.shape(self, Rect2(0, 0, 640, FLOOR), wc[0])
		for k in 32:   # wallpaper stripes / panelling
			Art.shape(self, Rect2(k * 20 + 8, 0, 3, FLOOR), wc[1])
	Art.shape(self, Rect2(0, 0, 640, 16), Pal.DGRAY)    # ceiling trim
	var floor_c := [Pal.BROWN, Color8(150, 75, 0)]
	if r in ["Basement", "Garage"]:
		floor_c = [Pal.DGRAY, Pal.LGRAY]
	elif r in ["Kitchen", "Bathroom", "bank", "gas", "police"]:
		floor_c = [Pal.WHITE, Pal.LGRAY]
	Art.dfill(self, Rect2(0, FLOOR, 640, 92), floor_c[0], floor_c[1])
	Art.shape(self, Rect2(0, FLOOR - 6, 640, 6), Pal.BLACK)
	if room == entry:
		_door(DOOR_X, "EXIT")
	_furniture(r)
	_draw_problem()

func _door(x: float, label: String) -> void:
	Art.shape(self, Rect2(x - 26, 100, 52, FLOOR - 100), Pal.BLACK)
	Art.shape(self, Rect2(x - 22, 104, 44, FLOOR - 106), Pal.BROWN)
	Art.shape(self, Rect2(x - 16, 112, 32, 40), Color8(150, 75, 0))
	Art.shape(self, Rect2(x - 16, 162, 32, 60), Color8(150, 75, 0))
	Art.circ(self, Vector2(x + 14, 180), 3, Pal.YELLOW)
	Art.shape(self, Rect2(x - 20, 82, 40, 14), Pal.RED)
	Art.text(self, Vector2(x - 20, 93), label, Pal.WHITE, 10, HORIZONTAL_ALIGNMENT_CENTER, 40)

func _draw_doors() -> void:
	if room - 1 >= 1:
		Art.shape(self, Rect2(0, 80, 36, FLOOR - 80), Pal.BLACK)
		Art.shape(self, Rect2(0, 84, 32, FLOOR - 84), Pal.DGRAY)
		Art.text_shadow(self, Vector2(4, 72), "< " + _pretty(rooms[room - 1]), Pal.WHITE, 10)
	if room + 1 < rooms.size():
		Art.shape(self, Rect2(604, 80, 36, FLOOR - 80), Pal.BLACK)
		Art.shape(self, Rect2(608, 84, 32, FLOOR - 84), Pal.DGRAY)
		var s := _pretty(rooms[room + 1]) + " >"
		Art.text_shadow(self, Vector2(0, 72), s, Pal.WHITE, 10, HORIZONTAL_ALIGNMENT_RIGHT, 636)
	var title := _pretty(room_name())
	if place.kind == "house" and not job.is_empty():
		title = "%s - %s's %s" % [Game.address(job), Game.last_name(job), title]
	elif place.kind != "house":
		title = place.name if room_name() != "Bunkroom" else "JIM'S BUNKROOM"
	Art.text_shadow(self, Vector2(8, 32), title, Pal.WHITE, 12)

func _pretty(r: String) -> String:
	return r if r[0] == r[0].to_upper() else place.name

func _counter(color: Color) -> void:
	Art.shape(self, Rect2(SPOT_X - 20, 200, 220, 70), Pal.BLACK)
	Art.shape(self, Rect2(SPOT_X - 17, 203, 214, 64), color)
	Art.shape(self, Rect2(SPOT_X - 20, 196, 220, 8), Pal.LGRAY)

func _shelves(x0: float, x1: float, seed_n: int) -> void:
	var rr := RandomNumberGenerator.new()
	rr.seed = seed_n
	for sy in [70, 120, 170]:
		Art.shape(self, Rect2(x0, sy + 26, x1 - x0, 4), Pal.BROWN)
		var x := x0 + 4
		while x < x1 - 14:
			var w := rr.randi_range(8, 16)
			var h := rr.randi_range(12, 24)
			Art.shape(self, Rect2(x, sy + 26 - h, w, h), Pal.ALL[rr.randi_range(1, 14)])
			x += w + 3

func _furniture(r: String) -> void:
	var prob_here: bool = not job.is_empty() and r == job.tpl.room
	match r:
		"Living Room":
			Art.shape(self, Rect2(230, 60, 60, 44), Pal.WHITE)
			Art.shape(self, Rect2(234, 64, 52, 36), Pal.LCYAN)
			Art.shape(self, Rect2(300, 40, 26, 22), Pal.BROWN)           # mounted deer head
			draw_line(Vector2(304, 40), Vector2(296, 24), Pal.YELLOW, 2)
			draw_line(Vector2(322, 40), Vector2(330, 24), Pal.YELLOW, 2)
			Art.shape(self, Rect2(303, 48, 20, 4), Pal.BLACK)             # sunglasses
			if not (prob_here and job.tpl.prob == "glued"):
				Art.shape(self, Rect2(250, 200, 120, 48), Pal.GREEN)       # couch
				Art.shape(self, Rect2(244, 186, 132, 20), Pal.GREEN)
			Art.shape(self, Rect2(540, 170, 70, 60), Pal.DGRAY)            # TV
			Art.shape(self, Rect2(546, 176, 58, 44), Pal.BLUE if int(t * 2) % 2 == 0 else Pal.LBLUE)
			Art.text(self, Vector2(548, 200), "GO PACK", Pal.YELLOW, 10)
		"Kitchen":
			Art.shape(self, Rect2(200, 110, 46, 138), Pal.WHITE)           # fridge
			Art.shape(self, Rect2(240, 150, 3, 30), Pal.LGRAY)
			for k in 5:
				Art.shape(self, Rect2(206 + k * 7, 120 + (k % 2) * 10, 5, 5), Pal.GREEN if k % 2 == 0 else Pal.YELLOW)
			Art.shape(self, Rect2(250, 190, 150, 58), Pal.BROWN)            # counter
			Art.shape(self, Rect2(250, 186, 150, 6), Pal.LGRAY)
			Art.shape(self, Rect2(260, 80, 130, 50), Pal.BROWN)             # cabinets
			Art.shape(self, Rect2(540, 200, 60, 48), Pal.DGRAY)             # stove
			Art.circ(self, Vector2(556, 200), 6, Pal.BLACK)
			Art.circ(self, Vector2(584, 200), 6, Pal.BLACK)
		"Bathroom":
			Art.shape(self, Rect2(220, 200, 120, 48), Pal.WHITE)            # tub
			Art.shape(self, Rect2(520, 150, 40, 34), Pal.LGRAY)             # mirror
			Art.shape(self, Rect2(524, 200, 34, 48), Pal.WHITE)             # sink
			Art.shape(self, Rect2(250, 70, 60, 34), Pal.BLUE)               # muskie poster
			Art.shape(self, Rect2(258, 82, 44, 10), Pal.GREEN)
		"Bedroom":
			Art.shape(self, Rect2(220, 190, 150, 58), Pal.BLUE)             # bed
			Art.shape(self, Rect2(220, 170, 12, 78), Pal.BROWN)
			Art.shape(self, Rect2(236, 186, 30, 12), Pal.WHITE)
			Art.shape(self, Rect2(244, 178, 16, 8), Pal.YELLOW)             # cheesehead
			Art.shape(self, Rect2(540, 170, 70, 78), Pal.BROWN)             # dresser
			for k in 3:
				Art.shape(self, Rect2(546, 178 + k * 22, 58, 16), Color8(150, 75, 0))
		"Basement":
			Art.shape(self, Rect2(220, 120, 40, 128), Pal.LGRAY)            # water heater
			Art.shape(self, Rect2(540, 140, 70, 108), Pal.BROWN)            # canned goods shelf
			_shelves(540, 610, 7)
			if not (prob_here and job.tpl.prob == "critter"):
				Art.shape(self, Rect2(400, 130, 80, 118), Pal.DGRAY)        # furnace
		"Garage":
			for k in 4:
				Art.shape(self, Rect2(200 + k * 2, 60 + k * 36, 200, 32), Pal.WHITE)  # garage door
			Art.shape(self, Rect2(520, 190, 90, 58), Pal.BROWN)             # workbench
			for k in 10:
				Art.shape(self, Rect2(522 + k * 9, 120 + (k % 3) * 8, 4, 24), Pal.LGRAY)
		"Attic":
			draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(220, 0), Vector2(0, 180)]), Pal.BLACK)
			draw_colored_polygon(PackedVector2Array([Vector2(640, 0), Vector2(420, 0), Vector2(640, 180)]), Pal.BLACK)
			for k in 3:
				Art.shape(self, Rect2(220 + k * 40, 210, 34, 38), Pal.BROWN)
			Art.text(self, Vector2(222, 230), "XMAS", Pal.WHITE, 10)
		"Workshop":
			Art.shape(self, Rect2(200, 60, 200, 110), Pal.BROWN)            # pegboard
			for k in 12:
				Art.shape(self, Rect2(210 + k * 15, 70 + (k % 3) * 20, 5, 40), Pal.LGRAY)
			Art.shape(self, Rect2(300, 120, 14, 22), Pal.BLACK)             # answering machine
			Art.circ(self, Vector2(307, 128), 3, Pal.LRED if int(t * 2) % 2 == 0 else Pal.RED)
			_counter(Pal.BROWN)
			Art.text(self, Vector2(SPOT_X, 230), "JIM'S BENCH", Pal.YELLOW, 10)
			Art.shape(self, Rect2(500, 50, 70, 40), Pal.WHITE)              # calendar
			Art.text(self, Vector2(504, 64), Game.day_name().to_upper(), Pal.RED, 10)
			Art.text(self, Vector2(504, 80), "WEEK %d" % Game.week, Pal.BLACK, 10)
		"Bunkroom":
			Art.shape(self, Rect2(SPOT_X - 60, 210, 160, 38), Pal.GREEN)    # cot
			Art.shape(self, Rect2(SPOT_X - 60, 204, 30, 10), Pal.WHITE)
			Art.dog(self, Vector2(250, 248), 1.4, t)
			Art.shape(self, Rect2(540, 160, 60, 50), Pal.DGRAY)
			Art.shape(self, Rect2(545, 165, 50, 38), Pal.BLUE)
			Art.beer(self, Vector2(300, 246), 1.5)
			Art.beer(self, Vector2(316, 246), 1.5)
		"hardware", "plumbing", "electric", "lumber", "farm", "gas":
			_shelves(190, 400, r.hash())
			_shelves(30, 118, r.hash() + 1)
			_counter(Pal.BROWN if r != "gas" else Pal.RED)
			var on_sale := false
			for k in Game.sales:
				if k.begins_with(r + ":"):
					on_sale = true
			if on_sale:
				Art.shape(self, Rect2(420, 60, 120, 34), Pal.RED)
				Art.text(self, Vector2(420, 84), "SALE TODAY!", Pal.YELLOW, 14, HORIZONTAL_ALIGNMENT_CENTER, 120)
			if r == "gas":
				Art.shape(self, Rect2(560, 110, 60, 70), Pal.LCYAN)
				Art.text(self, Vector2(540, 104), "HOT BRATS", Pal.RED, 12)
		"bank":
			_counter(Pal.LGRAY)
			for k in 4:
				Art.shape(self, Rect2(SPOT_X - 10 + k * 52, 110, 4, 90), Pal.YELLOW)   # teller bars
			Art.shape(self, Rect2(220, 60, 140, 40), Pal.YELLOW)
			Art.text(self, Vector2(220, 85), "IN COWS WE TRUST", Pal.BLACK, 10, HORIZONTAL_ALIGNMENT_CENTER, 140)
		"police":
			_counter(Pal.BLUE)
			Art.shape(self, Rect2(230, 60, 70, 80), Pal.WHITE)
			Art.text(self, Vector2(232, 76), "WANTED", Pal.RED, 12)
			Art.text(self, Vector2(232, 96), "FLAMINGO", Pal.BLACK, 10)
			Art.text(self, Vector2(232, 110), "THIEF", Pal.BLACK, 10)
			Art.shape(self, Rect2(250, 115, 30, 20), Pal.LMAGENTA)
		"tavern":
			_counter(Pal.BROWN)
			Art.shape(self, Rect2(230, 50, 90, 30), Pal.BLACK)
			Art.text(self, Vector2(230, 72), "BEER", Pal.LRED if int(t * 2) % 2 == 0 else Pal.RED, 20, HORIZONTAL_ALIGNMENT_CENTER, 90)
			Art.shape(self, Rect2(480, 70, 100, 18), Pal.GREEN)              # mounted muskie
			draw_colored_polygon(PackedVector2Array([Vector2(580, 79), Vector2(596, 68), Vector2(596, 90)]), Pal.GREEN)
			for k in 4:
				Art.beer(self, Vector2(SPOT_X + k * 40, 196), 1.2)

const KEEPER_SHIRTS := {"hardware": Pal.LRED, "plumbing": Pal.BLUE, "electric": Pal.YELLOW,
	"lumber": Pal.GREEN, "farm": Pal.BROWN, "gas": Pal.LMAGENTA, "bank": Pal.DGRAY,
	"police": Pal.BLUE, "tavern": Pal.WHITE}

func _draw_people(r: String) -> void:
	if KEEPER_SHIRTS.has(r):
		var hat := Pal.BLUE if r == "police" else Color.TRANSPARENT
		Art.person(self, Vector2(SPOT_X + 110, 214), 1.6, KEEPER_SHIRTS[r], Pal.DGRAY, hat,
			Color8(255, 170, 85), Pal.YELLOW if r in ["gas", "bank"] else Pal.BROWN, r in ["lumber", "tavern"], -1, 0.0)
		_counter_front(r)
	if not job.is_empty() and r == job.tpl.room:
		var h: int = job.tpl.customer.hash()
		var shirt: Color = Pal.ALL[1 + absi(h) % 14]
		if job.tpl.prob == "glued":
			return   # the customer is drawn stuck in the recliner
		var fidget := sin(t * 5.0) * 2.0
		Art.person(self, Vector2(560, FEET_IN), 1.6, shirt, Pal.BLUE, Color.TRANSPARENT,
			Color8(255, 170, 85), Pal.ALL[(absi(h) / 7) % 8], absi(h) % 3 == 0, -1, 0.0)
		if int(t) % 4 < 2:
			Art.text_shadow(self, Vector2(500, 210 + fidget), "Hurry, Jim!", Pal.WHITE, 10)

## The front of the counter is redrawn over the keeper's legs.
func _counter_front(r: String) -> void:
	var col := Pal.BROWN
	match r:
		"gas": col = Pal.RED
		"bank": col = Pal.LGRAY
		"police": col = Pal.BLUE
	Art.shape(self, Rect2(SPOT_X - 20, 200, 220, 70), Pal.BLACK)
	Art.shape(self, Rect2(SPOT_X - 17, 203, 214, 64), col)
	Art.shape(self, Rect2(SPOT_X - 20, 196, 220, 8), Pal.LGRAY)

func _draw_problem() -> void:
	if job.is_empty() or room_name() != job.tpl.room:
		return
	var x := SPOT_X
	match job.tpl.prob:
		"toilet":
			Art.shape(self, Rect2(x - 18, 200, 36, 30), Pal.WHITE)
			Art.shape(self, Rect2(x - 14, 150, 28, 40), Pal.WHITE)
			Art.shape(self, Rect2(x - 10, 230, 20, 18), Pal.WHITE)
			for k in 8:
				var a := float(k) / 8.0 * PI + sin(t * 6 + k) * 0.2
				var top := 60.0 + sin(t * 8 + k) * 10
				draw_line(Vector2(x, 200), Vector2(x + cos(a) * 60, top), Pal.LBLUE, 3)
			Art.dfill(self, Rect2(x - 120, FLOOR + 30, 240, 40), Pal.LBLUE, Pal.BLUE)
		"ceiling_hole":
			draw_colored_polygon(PackedVector2Array([Vector2(x - 50, 16), Vector2(x - 20, 50), Vector2(x, 34),
				Vector2(x + 30, 60), Vector2(x + 55, 16)]), Pal.BLACK)
			Art.shape(self, Rect2(x - 4, 40 + sin(t * 2) * 2, 8, 22), Color8(255, 170, 85))   # turkey leg
			for k in 7:
				Art.shape(self, Rect2(x - 60 + k * 18, FLOOR + 20 + (k % 3) * 8, 12, 6), Pal.WHITE)
		"critter":
			Art.shape(self, Rect2(x - 40, 130, 80, 118), Pal.DGRAY)
			Art.shape(self, Rect2(x - 30, 160, 60, 40), Pal.BLACK)
			for k in 3:
				var blink := int(t * 2 + k) % 5 != 0
				if blink:
					Art.shape(self, Rect2(x - 24 + k * 18, 172, 3, 3), Pal.YELLOW)
					Art.shape(self, Rect2(x - 18 + k * 18, 172, 3, 3), Pal.YELLOW)
			Art.text_shadow(self, Vector2(x - 40, 120), "*chitter chitter*", Pal.WHITE, 10)
		"window":
			Art.shape(self, Rect2(x - 40, 70, 80, 70), Pal.WHITE)
			Art.shape(self, Rect2(x - 36, 74, 72, 62), Pal.BLACK)
			for k in 5:
				draw_colored_polygon(PackedVector2Array([Vector2(x - 36 + k * 15, 74), Vector2(x - 28 + k * 15, 74),
					Vector2(x - 32 + k * 15, 90 + (k % 2) * 14)]), Pal.LCYAN)
			Art.text_shadow(self, Vector2(x - 30, 160), "beep... beep...", Pal.WHITE, 10)
		"wires", "garage":
			if job.tpl.prob == "garage":
				draw_set_transform(Vector2(x, 140), 0.25, Vector2.ONE)
				Art.shape(self, Rect2(-90, -60, 180, 110), Pal.WHITE)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			Art.shape(self, Rect2(x - 10, 120, 20, 28), Pal.WHITE)
			for k in 6:
				var a := Vector2(x, 134)
				var b := a + Vector2.from_angle(t * 9.0 + k) * (12 + (k % 3) * 8)
				draw_line(a, b, Pal.YELLOW, 2)
			draw_line(Vector2(x - 4, 148), Vector2(x - 20, 210), Pal.RED, 2)
			draw_line(Vector2(x + 4, 148), Vector2(x + 16, 220), Pal.BLACK, 2)
		"water":
			Art.dfill(self, Rect2(0, FLOOR - 30, 640, 122), Pal.BLUE, Pal.LBLUE)
			for k in 4:
				var fx := fmod(t * 30.0 + k * 160.0, 640.0)
				Art.shape(self, Rect2(fx, FLOOR + 10 + k * 15, 8, 4), Pal.YELLOW)
				Art.shape(self, Rect2(fx - 3, FLOOR + 10 + k * 15, 3, 4), Pal.BROWN)
		"wall_hole":
			Art.shape(self, Rect2(x - 14, 80, 28, 26), Pal.BLACK)
			Art.shape(self, Rect2(x - 26, 106, 52, 60), Pal.BLACK)
			Art.shape(self, Rect2(x - 22, 166, 16, 70), Pal.BLACK)
			Art.shape(self, Rect2(x + 6, 166, 16, 70), Pal.BLACK)
		"door":
			Art.shape(self, Rect2(x - 30, 90, 60, FLOOR - 90), Pal.BLACK)
			for k in 4:
				Art.shape(self, Rect2(x - 70 + k * 36, FLOOR + 22 + (k % 2) * 10, 30, 10), Pal.BROWN)
		"deck":
			Art.dfill(self, Rect2(x - 100, FLOOR - 40, 200, 60), Pal.BROWN, Pal.BLACK)
			Art.shape(self, Rect2(x - 60, FLOOR - 30, 120, 40), Pal.LBLUE)
			for k in 4:
				Art.circ(self, Vector2(x - 40 + k * 26, FLOOR - 40 - fmod(t * 20 + k * 9, 40)), 6, Color(1, 1, 1, 0.5))
		"fence":
			for k in 6:
				draw_set_transform(Vector2(x - 80 + k * 30, FLOOR), 0.3 * (k % 3 - 1), Vector2.ONE)
				Art.shape(self, Rect2(-3, -80, 6, 80), Pal.BROWN)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for k in 10:
				Art.circ(self, Vector2(x - 90 + k * 20, 200 + sin(k) * 10), 3, Pal.LRED if (k + int(t * 3)) % 2 == 0 else Pal.LGREEN)
		"roof":
			Art.shape(self, Rect2(x - 60, 16, 120, 50), Pal.LCYAN)
			for k in 12:
				var ry := fmod(t * 160.0 + k * 31.0, FLOOR)
				draw_line(Vector2(x - 55 + k * 10, ry), Vector2(x - 57 + k * 10, ry + 8), Pal.LBLUE, 1)
			Art.shape(self, Rect2(x - 12, FLOOR + 10, 24, 14), Pal.DGRAY)    # the pot
		"glued":
			Art.shape(self, Rect2(x - 42, 158, 84, 84), Pal.BLACK)
			Art.shape(self, Rect2(x - 40, 160, 80, 80), Pal.RED)
			Art.shape(self, Rect2(x - 52, 198, 104, 44), Pal.BLACK)
			Art.shape(self, Rect2(x - 50, 200, 100, 40), Pal.LRED)
			Art.person(self, Vector2(x, 238), 1.4, Pal.LMAGENTA, Pal.MAGENTA, Color.TRANSPARENT,
				Color8(255, 170, 85), Pal.LGRAY, false, 1, 0.0)
			Art.text_shadow(self, Vector2(x - 50, 150), "I can't feel my legs, Jim", Pal.WHITE, 10)
