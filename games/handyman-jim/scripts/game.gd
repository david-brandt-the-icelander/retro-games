extends Node
## Global game state: clock, money, cheques, inventory, jobs, sales.

signal toast(text: String)

const MIN_PER_SEC := 1.0   # one game minute per real second -> a 12-hour day is 12 minutes

var font: Font
var rng := RandomNumberGenerator.new()

var week := 1
var day := 0               # 0 = Monday .. 4 = Friday
var minute := float(Data.DAY_START)
var clock_running := false

var cash := 300
var cheques: Array = []    # {amount, from, bounce}
var inventory := {}        # item id -> qty
var gas := Data.TANK_SIZE
var jobs: Array = []       # active jobs
var sales := {}            # "store:item" -> discount (0.3 = 30% off)
var tickets_today := 0
var week_income := 0
var used_templates: Array = []
var next_call := float(Data.DAY_START + 3)
var jobs_done_week := 0

func _ready() -> void:
	rng.randomize()
	# Rendered at the real window resolution (stretch mode canvas_items), so keep smooth text.
	font = ThemeDB.fallback_font
	_setup_input()

func _setup_input() -> void:
	var map := {
		# The whole game plays on WASD, Space and Enter. "jobs", "cancel" and "horn" have no keys:
		# Enter does the job board, menus end with a Leave row, and Space honks while driving.
		"up": [KEY_W], "down": [KEY_S], "left": [KEY_A], "right": [KEY_D],
		"act": [KEY_SPACE],
		"map": [KEY_ENTER, KEY_KP_ENTER],
		"jobs": [], "cancel": [], "horn": [],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)

func new_game() -> void:
	week = 1
	day = 0
	cash = 300
	cheques.clear()
	inventory.clear()
	gas = Data.TANK_SIZE
	week_income = 0
	jobs_done_week = 0
	used_templates.clear()
	start_day()

func start_day() -> void:
	minute = float(Data.DAY_START)
	jobs.clear()
	tickets_today = 0
	next_call = float(Data.DAY_START + 3)
	roll_sales()

func roll_sales() -> void:
	sales.clear()
	var stores := Data.STORES.keys()
	for i in 4:
		var s: String = stores[rng.randi_range(0, stores.size() - 1)]
		var stock: Array = Data.STORES[s].stock
		var item: String = stock[rng.randi_range(0, stock.size() - 1)]
		sales["%s:%s" % [s, item]] = [0.25, 0.4, 0.5][rng.randi_range(0, 2)]

func price(store: String, item: String) -> int:
	var base: float = Data.ITEMS[item][1] * Data.STORES[store].mult
	var key := "%s:%s" % [store, item]
	if sales.has(key):
		base *= 1.0 - sales[key]
	return maxi(1, int(round(base)))

func sell_price(item: String) -> int:
	return maxi(1, int(Data.ITEMS[item][1] * 0.5))

func clock_text(m: float = -1.0) -> String:
	if m < 0:
		m = minute
	var h := int(m) / 60
	var mm := int(m) % 60
	var ap := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%d:%02d %s" % [h12, mm, ap]

func day_name() -> String:
	return Data.DAY_NAMES[day]

func advance(mins: float) -> void:
	minute += mins

func say(t: String) -> void:
	toast.emit(t)
	var who: String = Sfx.speaker_of(t)
	if who != "":
		Sfx.remark(who, t)

func charge(amount: int, why: String) -> void:
	cash -= amount
	say("-$%d  %s" % [amount, why])

func earn(amount: int, why: String) -> void:
	cash += amount
	week_income += amount
	say("+$%d  %s" % [amount, why])

func have(item: String) -> int:
	return inventory.get(item, 0)

func add_item(item: String, n: int = 1) -> void:
	inventory[item] = have(item) + n
	if inventory[item] <= 0:
		inventory.erase(item)

# ---------------------------------------------------------------- jobs

const EXTRA_ROOMS := ["Kitchen", "Bathroom", "Bedroom", "Basement", "Garage"]

## One job at a time: the phone only rings once the current job is finished.
func call_due() -> bool:
	return jobs.is_empty() and minute >= next_call and minute < Data.DAY_END - 80

func make_job() -> Dictionary:
	var free_t := []
	for i in Data.JOBS.size():
		if not used_templates.has(i):
			free_t.append(i)
	if free_t.is_empty():
		used_templates.clear()
		for i in Data.JOBS.size():
			free_t.append(i)
	var ti: int = free_t[rng.randi_range(0, free_t.size() - 1)]
	used_templates.append(ti)
	var busy := []
	for j in jobs:
		busy.append(j.house)
	var houses := Town.house_ids().filter(func(h): return not busy.has(h))
	var house: String = houses[rng.randi_range(0, houses.size() - 1)]
	var tpl: Dictionary = Data.JOBS[ti]
	# Living room in the middle, a room either side; the disaster room is one of them.
	var others := EXTRA_ROOMS.filter(func(r): return r != tpl.room)
	others.shuffle()
	var side := [tpl.room, others[0]] if tpl.room != "Living Room" else [others[0], others[1]]
	side.shuffle()
	var rooms := [side[0], "Living Room", side[1]]
	var num := 1
	while jobs.any(func(j): return j.num == num):
		num += 1
	return {"tpl": tpl, "house": house, "rooms": rooms, "num": num,
		"deadline": minute + float(tpl.deadline) + 15.0, "late": false}

func job_for_house(house: String) -> Dictionary:
	for j in jobs:
		if j.house == house:
			return j
	return {}

func last_name(j: Dictionary) -> String:
	var parts: PackedStringArray = j.tpl.customer.split(" ")
	return parts[parts.size() - 1]

func address(j: Dictionary) -> String:
	var p := Town.place(j.house)
	return "%d %s" % [p.number, p.street]

func missing(j: Dictionary) -> Dictionary:
	var out := {}
	for item in j.tpl.mats:
		var need: int = j.tpl.mats[item]
		if have(item) < need:
			out[item] = need - have(item)
	return out

func mats_have_count(j: Dictionary) -> String:
	var got := 0
	var total := 0
	for item in j.tpl.mats:
		total += 1
		if have(item) >= j.tpl.mats[item]:
			got += 1
	return "%d/%d" % [got, total]

## Do the repair. Returns lines for a message box.
func finish_job(j: Dictionary) -> Array:
	for item in j.tpl.mats:
		add_item(item, -j.tpl.mats[item])
	advance(30)
	jobs.erase(j)
	jobs_done_week += 1
	next_call = minute + rng.randi_range(5, 15)   # a short breather, then the phone rings again
	var lines: Array = [j.tpl.fix, ""]
	var pay: int = j.tpl.pay
	if minute > j.deadline:
		pay = pay / 2
		lines.append("You were LATE. %s only pays half: $%d." % [j.tpl.customer, pay])
	if rng.randf() < j.tpl.cheque:
		cheques.append({"amount": pay, "from": j.tpl.customer, "bounce": j.tpl.bounce})
		lines.append("%s writes you a CHEQUE for $%d." % [j.tpl.customer, pay])
		lines.append("Cash it at First Dairyland Bank (open 9-5). Fingers crossed.")
	else:
		lines.append("%s pays CASH: $%d. Crumpled, but cash." % [j.tpl.customer, pay])
		cash += pay
		week_income += pay
	return lines

func cash_cheques() -> Array:
	var lines := []
	if cheques.is_empty():
		return ["Teller: 'You don't have any cheques, Jim.'"]
	for c in cheques:
		if rng.randf() < c.bounce:
			cash -= 25
			lines.append("$%d from %s... BOUNCED! Bank fee $25." % [c.amount, c.from])
		else:
			cash += c.amount
			week_income += c.amount
			lines.append("$%d from %s... cleared. Cash in hand." % [c.amount, c.from])
	cheques.clear()
	return lines

func check_deadlines() -> void:
	for j in jobs:
		if not j.late and minute > j.deadline:
			j.late = true
			say("%s calls: 'WHERE ARE YOU, JIM?!' (late - half pay)" % j.tpl.customer.split(" ")[0])

func end_day_cancel() -> Array:
	var lines := []
	for j in jobs:
		lines.append("%s gave up and called your cousin Lyle instead." % j.tpl.customer)
	jobs.clear()
	return lines

func weekend_scene() -> Array:
	for w in Data.WEEKENDS:
		if cash >= w[0]:
			return w
	return Data.WEEKENDS[-1]

# ---------------------------------------------------------------- input gating

var modal := false
var block_frame := -1

## True when gameplay may read an action this frame (no dialog, not the frame one closed).
func free_input() -> bool:
	return not modal and Engine.get_process_frames() != block_frame

func wrap(s: String, width: float, size: int = 12) -> Array:
	var out := []
	for para in s.split("\n"):
		var line := ""
		for word in para.split(" "):
			var trial := word if line == "" else line + " " + word
			if font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width and line != "":
				out.append(line)
				line = word
			else:
				line = trial
		out.append(line)
	return out
