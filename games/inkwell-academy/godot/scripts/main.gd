extends Node2D
## Inkwell Academy — an original school-day caper.
## Builds the world, HUD and cast in code and runs the timetable / AI / rules.

const WORLD_W := 6000.0
const VIEW_H := 1080.0
const MAX_LINES := 10000
const GATHER := 18.0
const ROPE_X := 5880.0
const PELLET_H := 150.0

const FLOORS := [
	{"y": 340.0, "x0": 2290.0, "x1": 5955.0, "ceil": 60.0, "label": "TOP FLOOR"},
	{"y": 620.0, "x0": 1100.0, "x1": 5955.0, "ceil": 340.0, "label": "FIRST FLOOR"},
	{"y": 900.0, "x0": 30.0, "x1": 5955.0, "ceil": 620.0, "label": "GROUND FLOOR"},
]
const STAIRS := [
	{"lo": 2, "hi": 1, "xlo": 820.0, "xhi": 1100.0},
	{"lo": 1, "hi": 0, "xlo": 3075.0, "xhi": 3355.0},
	{"lo": 2, "hi": 1, "xlo": 5440.0, "xhi": 5720.0},
]
const ROOMS := {
	"yard": {"name": "Playground", "f": 2, "x0": 15.0, "x1": 735.0, "outside": true},
	"hall": {"name": "Entrance Hall", "f": 2, "x0": 750.0, "x1": 1500.0},
	"dining": {"name": "Dining Hall", "f": 2, "x0": 1500.0, "x1": 3000.0},
	"gym": {"name": "Gymnasium", "f": 2, "x0": 3000.0, "x1": 4312.0},
	"room1": {"name": "Room 1", "f": 2, "x0": 4312.0, "x1": 5400.0, "board": true},
	"eastg": {"name": "", "f": 2, "x0": 5400.0, "x1": 5976.0},
	"westl": {"name": "Landing", "f": 1, "x0": 1100.0, "x1": 1650.0},
	"map": {"name": "Map Room", "f": 1, "x0": 1650.0, "x1": 3000.0, "board": true},
	"corr": {"name": "", "f": 1, "x0": 3000.0, "x1": 3525.0},
	"library": {"name": "Library", "f": 1, "x0": 3525.0, "x1": 4650.0, "board": true},
	"art": {"name": "Art Room", "f": 1, "x0": 4650.0, "x1": 5400.0},
	"eastl": {"name": "", "f": 1, "x0": 5400.0, "x1": 5976.0},
	"history": {"name": "History Room", "f": 0, "x0": 2265.0, "x1": 3300.0, "board": true},
	"top": {"name": "", "f": 0, "x0": 3300.0, "x1": 3712.0},
	"lab": {"name": "Science Lab", "f": 0, "x0": 3712.0, "x1": 4800.0, "board": true},
	"study": {"name": "Head's Study", "f": 0, "x0": 4800.0, "x1": 5976.0},
}
const CREST_SPOTS := [[0, 3188.0], [0, 4350.0], [0, 5175.0], [1, 2325.0], [1, 4145.0], [1, 5190.0], [2, 2025.0], [2, 3750.0]]

const SUBJECTS := {
	"register": {"name": "Registration", "room": "room1", "teacher": "ogle",
		"boards": ["Register — Day {day}"], "open": "Good morning! Answer your names, please.",
		"talk": ["Dot? Wilf? Ada? Good.", "Reg, stop yawning.", "Is Pip here? Ah, yes.", "Notices: no running in corridors.",
			"Lunch money goes in the tin.", "Mo, where is your tie?", "Say 'here', don't just wave.", "Bas, shoes on, please.", "The raffle is on Friday."]},
	"geography": {"name": "Geography", "room": "map", "teacher": "ogle",
		"boards": ["Rivers of the world", "Mountains and how to climb them", "Rainfall: why?"], "open": "Atlases open, class.",
		"talk": ["Who can find Peru?", "Rivers flow downhill. Mostly.", "That's not a lake, Mo. It's a coffee stain.", "Copy the map. Neatly!",
			"North is up. Usually.", "A delta is not a type of biscuit.", "Where does the Nile end?", "Colour in the sea BLUE, Reg.", "Mountains are tall. Remember that."]},
	"maths": {"name": "Maths", "room": "room1", "teacher": "ogle",
		"boards": ["Long division:  147 ÷ 7", "Fractions:  3/4 + 1/8 = ?", "Angles in a triangle"], "open": "Pencils sharpened? Good.",
		"talk": ["Seven eights are fifty-six.", "Show your working!", "Carry the one...", "Nobody touch the protractors.",
			"Is that a three or an eight, Ada?", "Fractions are friends.", "Divide, then check. Always check.", "A triangle has three sides. Three!", "No calculators. Brains!"]},
	"science": {"name": "Science", "room": "lab", "teacher": "vane",
		"boards": ["The boiling point of water", "Magnets: attract or repel?", "Plants need light"], "open": "Goggles ON, everybody.",
		"talk": ["Never lick the apparatus.", "Water boils at 100 degrees.", "Who left the tap on?", "Observe, then record.",
			"Hair back, goggles down.", "That bubbling is NOT supposed to happen.", "Plants do not enjoy being watered with squash.", "Wilf, put down the magnet.", "Hypothesis first, explosion later."]},
	"history": {"name": "History", "room": "history", "teacher": "brandish",
		"boards": ["Castles and moats", "The printing press", "Why kings wore crowns"], "open": "Turn to page ninety.",
		"talk": ["Dates matter, children!", "A moat is not a swimming pool.", "Who built the castles? Peasants.", "Write it down. All of it.",
			"Kings did not wear slippers.", "Eyes up, Nell. The Tudors await.", "Eighteen-sixty. Remember it.", "Yes, they really did eat that.", "History is not a spectator sport."]},
	"english": {"name": "English", "room": "library", "teacher": "brandish",
		"boards": ["Nouns, verbs & adjectives", "How to use a comma", "Write a poem about rain"], "open": "Quietly now. This is a library.",
		"talk": ["A noun is a naming word.", "Commas are not confetti.", "Read chapter four.", "Ivy, that rhyme is dreadful.",
			"Adjectives, children. Use some.", "Full stops. They exist.", "Who has borrowed my red pen?", "Shh. Library voices.", "A verb is a doing word. So do some doing."]},
}
const GATHER_TALK := ["Settle down, please.", "Take your seats.", "Bags under the desks.", "Quickly, quickly, the bell has gone.",
	"Stop dawdling, all of you.", "Sit. Sit! SIT.", "I am waiting.", "Books out, class."]
const CLASS_TALK := ["Eyes on the board!", "Quiet at the back!", "Hands up if you know.", "Pens down, listen.", "Sit up straight.",
	"Don't make me ask twice.", "Who is chewing?", "No whispering.", "That means YOU.", "Is this clear? Good."]
const DINNER_TALK := ["No running with trays.", "Eat your greens, Mo.", "Table manners, please.", "Who dropped a pea? Pip?",
	"Queue properly, children.", "Pudding is for those who finish.", "Elbows OFF the table.", "Keep your voices down."]
const PATROL_TALK := ["Walk, don't run!", "No loitering.", "Shouldn't you be somewhere?", "Tuck that shirt in.", "Hmm. Quiet today.",
	"No chewing gum in corridors.", "Keep to the left.", "I have eyes everywhere.", "Move along, move along.", "Don't slouch."]
const LESSON_KEYS := ["geography", "maths", "science", "history", "english"]
const DAY_PLAN := ["reg", "lesson", "play", "lesson", "dinner", "lesson", "lesson", "home"]
const DURS := {"reg": 45.0, "lesson": 75.0, "play": 40.0, "dinner": 50.0, "home": 16.0}
const CLOCK := [540, 555, 630, 650, 720, 780, 840, 915, 930]
const CHAT := ["Swap you a conker?", "Tag! You're it!", "Did you do the homework?", "Dinner smells funny.",
	"Bet I can jump higher.", "Who took my ruler?", "Is it Friday yet?", "I heard the Head has a pet owl."]

const PUPILS := [
	["knuckles", "Knuckles", "3d8c4a"], ["tattle", "Tattle", "4b7be0"], ["dot", "Dot", "f39c33"], ["wilf", "Wilf", "26b0b8"],
	["mo", "Mo", "d8c22a"], ["ada", "Ada", "b84fc0"], ["reg", "Reg", "7d8ff0"], ["nell", "Nell", "f06b8a"],
	["bas", "Bas", "46b04a"], ["ivy", "Ivy", "9aa3b0"],
]
const TEACHERS := [
	["ogle", "Mr Ogle", "Sir", "c9852f", 2, 4900.0],
	["vane", "Miss Vane", "Miss", "c43fa0", 0, 4300.0],
	["brandish", "Mrs Brandish", "Miss", "3561c8", 0, 2700.0],
	["thistle", "Dr Thistle", "Sir", "8a3fb0", 0, 5400.0],
]

# ---------------------------------------------------------------- state
var mode := "title"   # title | play | pause | over
var gt := 0.0
var day := 1
var score := 0
var hi := 0
var lines := 0
var bells := 0
var period := {}
var period_idx := 0
var period_t := 0.0
var todays := []
var timers := []
var next_chat := 8.0
var muted := false

var chars := []
var npcs := []
var T := {}
var player: Chara
var pellets := []
var crests := []
var board_labels := {}
var rope: Sprite2D

# nodes
var world: Node2D
var cam: Camera2D
var fx: Node2D
var sky_mat: ShaderMaterial
var clouds := []
var sfx := {}
var font_ui: FontFile
var font_bold: FontFile
var font_chalk: FontFile
var hud := {}
var banner: PanelContainer
var banner_lbl: RichTextLabel
var overlay: Control
var overlay_lbl: RichTextLabel
var hud_t := 0.0


# ================================================================= setup
func _ready() -> void:
	randomize()
	var cfg := ConfigFile.new()
	if cfg.load("user://inkwell.cfg") == OK:
		hi = int(cfg.get_value("score", "hi", 0))
	font_ui = load("res://fonts/Fredoka-Medium.woff2")
	font_bold = load("res://fonts/Fredoka-Bold.woff2")
	font_chalk = load("res://fonts/Caveat-SemiBold.woff2")
	for n in ["bell", "fire", "bonk", "crest", "lines", "punch", "founders", "expel", "win", "whoosh", "click"]:
		sfx[n] = load("res://audio/%s.wav" % n)
	_build_sky()
	_build_world()
	_build_hud()
	_show_overlay(_title_text())
	_update_hud()
	if "--selftest" in OS.get_cmdline_user_args():
		_selftest.call_deferred()


## --selftest (npm run test:godot): plays through the rules headless and quits 0, or 1 on the first failure.
func _selftest() -> void:
	var fails := []
	var check := func(ok: bool, what: String):
		print(("ok    " if ok else "FAIL  ") + what)
		if not ok:
			fails.append(what)
	var frames := func(n: int):
		for i in n:
			await get_tree().process_frame
	_start_game()
	await frames.call(3)
	check.call(mode == "play" and period["type"] == "reg", "a new game starts with registration")
	# up the west stairs
	player.wx = STAIRS[0]["xlo"]
	_enter_stairs(player, STAIRS[0], true)
	for i in 40:
		if player.state == "stairs":
			_advance_stairs(player, 20.0)
	check.call(player.floor_i == 1, "the stairs lead up a floor")
	# a pea lights a crest when no teacher is looking
	for t in T.values():
		t.floor_i = 2; t.wy = FLOORS[2]["y"]; t.wx = 3800.0; t.target = null
	for n in npcs:
		if n.kind == "pupil":
			n.floor_i = 2; n.wy = FLOORS[2]["y"]; n.wx = 100.0
	player.floor_i = 1; player.wy = FLOORS[1]["y"]; player.wx = 2150.0; player.dir = 1; player.state = "idle"
	_fire()
	await frames.call(150)
	check.call(_lit_count() == 1 and lines == 0, "an unseen pea lights a crest without lines")
	# firing in front of a teacher costs lines
	var vane: Chara = T["vane"]
	vane.floor_i = 1; vane.wy = FLOORS[1]["y"]; vane.wx = 2400.0; vane.dir = -1; vane.state = "idle"; vane.target = null
	player.fire_cd = 0.0
	_fire()
	check.call(lines > 0, "firing where a teacher can see costs lines")
	await frames.call(150)
	check.call(vane.state == "down", "a pea knocks a teacher down")
	# a pea that hits a teacher who is looking at Pip costs more lines than one that hits his back
	vane.state = "idle"; vane.wx = 2500.0; vane.dir = 1; vane.target = null
	player.wx = 2150.0; player.dir = 1; player.fire_cd = 0.0
	var l0 := lines
	pellets.append({"x": 2480.0, "f": 1, "dir": 1, "dist": 0.0, "n": _spr("res://art/pea.svg", Vector2(2480, 500), 0.5)})
	_pellets_update(0.01)
	await frames.call(150)
	check.call(lines - l0 < 800, "a pea in a teacher's back does not cost the looking-at-you lines")
	vane.state = "idle"; vane.wx = 2500.0; vane.dir = -1; vane.target = null
	l0 = lines
	pellets.append({"x": 2480.0, "f": 1, "dir": 1, "dist": 0.0, "n": _spr("res://art/pea.svg", Vector2(2480, 500), 0.5)})
	_pellets_update(0.01)
	await frames.call(150)
	check.call(lines - l0 >= 800, "a pea at a teacher who is looking at Pip costs 800+ lines")
	# the bell rope needs every crest, and the Head out of his study
	for cr in crests:
		if not cr["lit"]:
			_light_crest(cr)
	var head: Chara = T["thistle"]
	head.floor_i = 2; head.wy = FLOORS[2]["y"]; head.wx = 2000.0; head.target = null
	player.floor_i = 0; player.wy = FLOORS[0]["y"]; player.wx = ROPE_X; player.state = "idle"
	var before := lines
	_try_rope()
	check.call(bells == 1 and lines == maxi(0, before - 3000) and _lit_count() == 0, "the Founder's Bell gives a half-holiday")
	# seating: only at a desk, one kid per desk, a punched kid loses the desk, a kid in Pip's desk shoves Pip
	for t in T.values():
		t.floor_i = 0; t.wy = FLOORS[0]["y"]; t.wx = 4300.0; t.target = null
	var rm1: Dictionary = ROOMS["room1"]
	var kid: Chara = null
	for n in npcs:
		if n.id == "dot":
			kid = n
	player.floor_i = 2; player.wy = FLOORS[2]["y"]; player.state = "idle"; player.dir = 1
	player.wx = rm1["x0"] + 100.0
	_player_sit()
	check.call(player.state == "idle", "Pip cannot sit anywhere but at a desk")
	kid.floor_i = 2; kid.wy = FLOORS[2]["y"]; kid.wx = _desk_x(rm1, 3); kid.state = "sit"; kid.dir = -1; kid.target = null
	player.wx = _desk_x(rm1, 3) + 12.0
	_player_sit()
	check.call(player.state == "idle", "Pip cannot sit at a desk someone is sitting at")
	player.wx = _desk_x(rm1, 3) + 60.0; player.dir = -1; player.fire_cd = 0.0
	_punch()
	check.call(player.punch_p >= 0.0, "Pip's punch starts its animation")
	_punch_lands()
	check.call(kid.state == "down", "punching a sitting kid knocks them to the floor")
	player.wx = _desk_x(rm1, 3) + 5.0
	_player_sit()
	check.call(player.state == "sit" and absf(player.wx - _desk_x(rm1, 3)) < 1.0, "Pip takes the emptied seat")
	kid.state = "idle"; kid.wx = _desk_x(rm1, 3) + 5.0
	check.call(not _pupil_takes_seat(kid, "room1", 3), "the knocked kid cannot just sit back down")
	player.state = "idle"; player.wx = _desk_x(rm1, PLAYER_SEAT); _player_sit()
	check.call(player.state == "sit", "Pip sits at Pip's own desk")
	check.call(_pupil_takes_seat(kid, "room1", PLAYER_SEAT) and player.state == "down" and player.to_floor, "a kid taking Pip's desk shoves Pip to the floor")
	await frames.call(2)
	player.down_until = 0.0
	await frames.call(4)
	check.call(player.state == "floor", "Pip is left sitting on the floor")
	var before2 := lines
	vane.floor_i = 2; vane.wy = FLOORS[2]["y"]; vane.wx = player.wx - 200.0; vane.dir = 1; vane.state = "idle"; vane.target = null
	player.cool = 0.0
	await frames.call(4)
	check.call(lines > before2, "a teacher who sees Pip on the floor gives lines")
	player.state = "idle"
	before2 = lines
	player.fire_cd = 0.0; player.dir = 1; player.wx = kid.wx - 50.0; kid.state = "idle"
	vane.wx = player.wx - 150.0; vane.dir = 1; vane.target = null
	_punch()
	_punch_lands()
	check.call(lines > before2, "a teacher who sees Pip punch gives lines")
	var shout: AudioStreamWAV = sfx["lines"]
	check.call(shout != null and shout.get_length() > 1.0, "the lines shout is a long, loud sound")
	# a teacher only gives lines for standing in class when he is looking Pip's way
	var og: Chara = period["teacher"]
	var rmk: Dictionary = ROOMS[period["room"]]
	for n in npcs:
		if n.kind == "pupil":
			n.floor_i = 2; n.wy = FLOORS[2]["y"]; n.wx = 100.0; n.target = null
	for o in T.values():
		if o != og:
			o.floor_i = 0; o.wy = FLOORS[0]["y"]; o.wx = 2400.0; o.target = null
	og.floor_i = rmk["f"]; og.wy = FLOORS[og.floor_i]["y"]; og.wx = rmk["x0"] + 190.0; og.state = "idle"; og.target = null
	period["phase"] = "teach"; period["mode"] = "write"; period["mode_until"] = period_t + 500.0
	player.floor_i = rmk["f"]; player.wy = FLOORS[player.floor_i]["y"]; player.wx = rmk["x0"] + 500.0; player.state = "idle"; player.cool = 0.0
	var l1 := lines
	period["next_check"] = 0.0
	_lesson_update(0.01)    # writing on the board: his back is turned
	check.call(lines == l1, "a teacher with his back turned gives no lines for standing")
	period["mode"] = "talk"; period["mode_until"] = period_t + 500.0; period["next_check"] = 0.0
	_lesson_update(0.01)    # facing the class
	check.call(lines > l1, "a teacher facing Pip gives lines for standing")
	# teachers never say the same thing twice running, and use every line before any comes round again
	var seen := {}
	var prev := ""
	var rep_ok := true
	for i in 60:
		var m := fresh(og, CLASS_TALK)
		if m == prev:
			rep_ok = false
		prev = m
		if i < CLASS_TALK.size():
			if seen.has(m):
				rep_ok = false
			seen[m] = true
	check.call(rep_ok and seen.size() == CLASS_TALK.size(), "a teacher never repeats himself until every line has been said")
	og.next_speak = 0.0
	og.bubble_until = 0.0
	var said_before := og.last_said
	_teacher_chatter()
	check.call(og.last_said != "" and og.last_said != said_before, "teachers speak up on their own")
	# a whole day goes by
	for i in DAY_PLAN.size() + 2:
		period_t = period["dur"]
		await frames.call(2)
	check.call(day == 2, "the timetable rolls over into a new day")
	# 10,000 lines expels
	lines = 9950
	add_lines(300, T["ogle"], "{n}")
	check.call(mode == "over", "10,000 lines ends the game")
	print("selftest: %d failed" % fails.size())
	get_tree().quit(1 if fails.size() > 0 else 0)


func _build_sky() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -100
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform vec4 top_col : source_color = vec4(0.45, 0.72, 0.98, 1.0);
uniform vec4 bot_col : source_color = vec4(0.88, 0.95, 1.0, 1.0);
void fragment() { COLOR = mix(top_col, bot_col, smoothstep(0.0, 0.85, UV.y)); }"""
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = sh
	rect.material = sky_mat
	layer.add_child(rect)
	var sun := Sprite2D.new()
	sun.texture = load("res://art/sun.svg")
	sun.position = Vector2(330, 150)
	sun.scale = Vector2(1.3, 1.3)
	layer.add_child(sun)
	for i in 7:
		var c := Sprite2D.new()
		c.texture = load("res://art/cloud%d.svg" % (i % 3))
		var s := randf_range(0.5, 0.95)
		c.scale = Vector2(s, s)
		c.modulate.a = randf_range(0.75, 0.95)
		layer.add_child(c)
		clouds.append({"n": c, "base": randf_range(0, 2600), "y": randf_range(80, 520), "v": randf_range(8, 22)})


func _spr(path: String, pos: Vector2, scale := 0.5, centered := true) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.position = pos
	s.scale = Vector2(scale, scale)
	s.centered = centered
	return s


func _build_world() -> void:
	world = Node2D.new()
	add_child(world)
	for i in 4:
		var bg := _spr("res://art/bg%d.svg" % i, Vector2(i * 1500, 0), 1.0, false)
		bg.z_index = -10
		world.add_child(bg)
	# room name plaques
	for k in ROOMS:
		var rm: Dictionary = ROOMS[k]
		if rm["name"] == "" or rm.has("outside"):
			continue
		var f: Dictionary = FLOORS[rm["f"]]
		var p := _plaque(rm["name"])
		p.position = Vector2((rm["x0"] + rm["x1"]) / 2.0 - p.size.x / 2.0, f["ceil"] + 30.0)
		if k == "hall":
			p.position.y = 380.0
		world.add_child(p)
	# school sign on the gable, either side of the round plaque
	for part in [["Inkwell", 1300.0], ["Academy", 1545.0]]:
		var sign := Label.new()
		sign.text = part[0]
		sign.add_theme_font_override("font", font_bold)
		sign.add_theme_font_size_override("font_size", 30)
		sign.add_theme_color_override("font_color", Color("fbf7ee"))
		sign.add_theme_color_override("font_outline_color", Color("2b2233"))
		sign.add_theme_constant_override("outline_size", 8)
		sign.position = Vector2(part[1], 262)
		sign.z_index = -5
		world.add_child(sign)
	# blackboards' chalk text
	for k in ROOMS:
		var rm: Dictionary = ROOMS[k]
		if not rm.has("board"):
			continue
		var y: float = FLOORS[rm["f"]]["y"]
		var l := Label.new()
		l.add_theme_font_override("font", font_chalk)
		l.add_theme_font_size_override("font_size", 40)
		l.add_theme_color_override("font_color", Color(0.96, 0.97, 0.92, 0.92))
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.position = Vector2(rm["x0"] + 58.0, y - 222.0)
		l.size = Vector2(266, 124)
		l.z_index = -5
		world.add_child(l)
		board_labels[k] = l
		# desks (front layer)
		for i in 11:
			var d := _spr("res://art/desk.svg", Vector2(_desk_x(rm, i) - 26.0, y), 0.55)
			d.offset = Vector2(0, -60)
			d.z_index = 10
			world.add_child(d)
	for tx in [1820.0, 2620.0]:
		var t := _spr("res://art/table.svg", Vector2(tx, 900), 0.5)
		t.offset = Vector2(0, -70)
		t.z_index = 10
		world.add_child(t)
	var bd := _spr("res://art/bigdesk.svg", Vector2(5440, 340), 0.5)
	bd.offset = Vector2(0, -80)
	bd.z_index = 10
	world.add_child(bd)
	rope = _spr("res://art/rope.svg", Vector2(ROPE_X, 80), 0.45, false)
	rope.offset = Vector2(-11, 0)
	rope.z_index = -4
	world.add_child(rope)
	# crests
	for sp in CREST_SPOTS:
		var cs := _spr("res://art/crest_off.svg", Vector2(sp[1], FLOORS[sp[0]]["y"] - PELLET_H), 0.32)
		cs.z_index = -4
		world.add_child(cs)
		crests.append({"f": sp[0], "x": sp[1], "lit": false, "n": cs})
	fx = Node2D.new()
	fx.z_index = 100
	world.add_child(fx)
	# the cast
	player = _mk({"id": "pip", "cname": "Pip", "kind": "player", "floor_i": 2, "wx": 380.0, "speed": 310.0, "accent": Color("e8473c")})
	for i in PUPILS.size():
		var p: Array = PUPILS[i]
		var c := _mk({"id": p[0], "cname": p[1], "kind": "pupil", "floor_i": 2, "wx": randf_range(60, 700),
			"speed": randf_range(225, 255), "desk": i, "dir": 1 if randf() < 0.5 else -1, "accent": Color(p[2])})
		npcs.append(c)
	for d in TEACHERS:
		var c := _mk({"id": d[0], "cname": d[1], "title": d[2], "kind": "teacher", "floor_i": d[4], "wx": d[5],
			"speed": 200.0, "accent": Color(d[3])})
		T[d[0]] = c
		npcs.append(c)
	player.z_index = 2
	cam = Camera2D.new()
	cam.limit_left = 0
	cam.limit_right = int(WORLD_W)
	cam.limit_top = 0
	cam.limit_bottom = int(VIEW_H)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 6.0
	cam.position = Vector2(player.wx, VIEW_H / 2.0)
	world.add_child(cam)
	cam.make_current()


func _mk(def: Dictionary) -> Chara:
	var c := Chara.new()
	def["wy"] = FLOORS[def["floor_i"]]["y"]
	c.build(def)
	c.z_index = 1 if def["kind"] == "teacher" else 0
	world.add_child(c)
	chars.append(c)
	return c


func _plaque(text: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fbf7ee")
	sb.set_corner_radius_all(10)
	sb.border_color = Color("2b2233")
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	sb.shadow_color = Color(0, 0, 0, 0.18)
	sb.shadow_size = 4
	sb.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold)
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Color("2b2233"))
	p.add_child(l)
	p.z_index = -5
	p.size = p.get_combined_minimum_size()
	return p


# ================================================================= HUD
func _style(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bw > 0:
		sb.border_color = border
		sb.set_border_width_all(bw)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	return sb


func _label(text: String, size := 24, col := Color.WHITE, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_bold if bold else font_ui)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# top bar
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.16, 0.82), 18))
	top.position = Vector2(16, 10)
	top.size = Vector2(1888, 56)
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 18)
	top.add_child(hb)
	hud.day = _pill("Day 1", Color("f2c230"), Color("2b2233"))
	hb.add_child(hud.day)
	hud.clock = _pill("9:00", Color("fbf7ee"), Color("2b2233"))
	hb.add_child(hud.clock)
	hud.period = _label("", 26, Color("bfe8ff"), true)
	hud.period.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.period.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hb.add_child(hud.period)
	hud.score = _label("Score 0", 26, Color("9ef08a"), true)
	hb.add_child(hud.score)
	hud.hi = _label("Best 0", 22, Color(1, 1, 1, 0.55))
	hb.add_child(hud.hi)
	# bottom bar
	var bot := PanelContainer.new()
	bot.add_theme_stylebox_override("panel", _style(Color(0.09, 0.08, 0.16, 0.86), 20))
	bot.position = Vector2(16, 932)
	bot.size = Vector2(1888, 136)
	root.add_child(bot)
	var bh := HBoxContainer.new()
	bh.add_theme_constant_override("separation", 22)
	bot.add_child(bh)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 6)
	bh.add_child(left)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 14)
	left.add_child(r1)
	r1.add_child(_label("Lines", 22, Color(1, 1, 1, 0.6), true))
	var bar := ProgressBar.new()
	bar.max_value = MAX_LINES
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 22)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_theme_stylebox_override("background", _style(Color(1, 1, 1, 0.1), 11))
	var fill := _style(Color("6fd36a"), 11)
	bar.add_theme_stylebox_override("fill", fill)
	hud.bar = bar
	hud.fill = fill
	r1.add_child(bar)
	hud.lines = _label("0 / 10,000", 22, Color.WHITE, true)
	hud.lines.custom_minimum_size = Vector2(190, 0)
	hud.lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r1.add_child(hud.lines)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	left.add_child(r2)
	r2.add_child(_label("Crests ", 22, Color(1, 1, 1, 0.6), true))
	hud.crests = []
	for i in 8:
		var tr := TextureRect.new()
		tr.texture = load("res://art/crest_off.svg")
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.custom_minimum_size = Vector2(30, 32)
		r2.add_child(tr)
		hud.crests.append(tr)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(14, 0)
	r2.add_child(sp)
	var bi := TextureRect.new()
	bi.texture = load("res://art/bell_icon.svg")
	bi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bi.custom_minimum_size = Vector2(30, 30)
	r2.add_child(bi)
	hud.bell = _label("Founder's Bell: silent", 22, Color(1, 1, 1, 0.6))
	r2.add_child(hud.bell)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r2.add_child(sp2)
	hud.where = _label("", 22, Color("7fe0ff"), true)
	r2.add_child(hud.where)
	hud.msg = _label("", 21, Color(1, 1, 1, 0.85))
	hud.msg.clip_text = true
	hud.msg.custom_minimum_size = Vector2(800, 0)
	left.add_child(hud.msg)
	var mm := Control.new()
	mm.custom_minimum_size = Vector2(540, 120)
	mm.draw.connect(_draw_minimap.bind(mm))
	bh.add_child(mm)
	hud.mm = mm
	# banner
	banner = PanelContainer.new()
	var bsb := _style(Color(0.09, 0.08, 0.16, 0.9), 22, Color("f2c230"), 4)
	bsb.content_margin_left = 40
	bsb.content_margin_right = 40
	bsb.content_margin_top = 16
	bsb.content_margin_bottom = 16
	banner.add_theme_stylebox_override("panel", bsb)
	banner_lbl = _rich(34)
	banner_lbl.custom_minimum_size = Vector2(900, 0)
	banner.add_child(banner_lbl)
	banner.modulate.a = 0.0
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(banner)
	# overlay (title / pause / expelled)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.04, 0.1, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var card := PanelContainer.new()
	var csb := _style(Color("fbf7ee"), 28, Color("2b2233"), 4)
	csb.content_margin_left = 56
	csb.content_margin_right = 56
	csb.content_margin_top = 40
	csb.content_margin_bottom = 40
	csb.shadow_color = Color(0, 0, 0, 0.35)
	csb.shadow_size = 24
	csb.shadow_offset = Vector2(0, 10)
	card.add_theme_stylebox_override("panel", csb)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay_lbl = _rich(28, Color("2b2233"))
	overlay_lbl.custom_minimum_size = Vector2(1120, 0)
	card.add_child(overlay_lbl)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(card)
	overlay.add_child(center)
	overlay.gui_input.connect(_on_overlay_input)
	root.add_child(overlay)


func _pill(text: String, bg: Color, fg: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _style(bg, 14)
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	var l := _label(text, 24, fg, true)
	p.add_child(l)
	p.set_meta("l", l)
	return p


func _rich(size: int, col := Color.WHITE) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font_ui)
	r.add_theme_font_override("bold_font", font_bold)
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", col)
	return r


func _title_text() -> String:
	return ("[center][font_size=84][b][color=#c0392b]Inkwell Academy[/color][/b][/font_size]\n"
		+ "[font_size=30][color=#6a5a7a]A school-day caper[/color][/font_size][/center]\n\n"
		+ "You are [b][color=#e8473c]Pip[/color][/b]. Legend says that when all eight school crests shine, whoever pulls the "
		+ "[b][color=#b8860b]Founder's Bell[/color][/b] wins the whole school a half-holiday. The rope hangs in the Head's study.\n\n"
		+ "Light the crests with your pea-shooter. Meanwhile, follow the timetable: turn up to lessons, sit down, and don't get caught. "
		+ "[b][color=#c0392b]10,000 lines and you're expelled.[/color][/b]\n\n"
		+ "[font_size=24][color=#6a5a7a]Teachers only see what's in front of them. Peas fly over pupils' heads, but not teachers'. "
		+ "Watch out for [b]Knuckles[/b] (thumps you) and [b]Tattle[/b] (tells on you). The Head leaves his study at dinner time.[/color][/font_size]\n\n"
		+ "[center][font_size=24][b]Left / Right[/b] walk    [b]Up / Down[/b] stairs    [b]S[/b] sit at a desk / stand    [b]X[/b] punch    [b]F[/b] or [b]Space[/b] pea-shooter    [b]E[/b] bell rope    [b]P[/b] pause    [b]M[/b] sound[/font_size]\n\n"
		+ "[font_size=34][b][color=#2f6e5a]Press Enter or click to start[/color][/b][/font_size][/center]")


func _show_overlay(text: String) -> void:
	overlay_lbl.text = text
	overlay.visible = true
	overlay.modulate.a = 0.0
	create_tween().tween_property(overlay, "modulate:a", 1.0, 0.25)


func _hide_overlay() -> void:
	overlay.visible = false


func _on_overlay_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if mode == "title" or mode == "over":
			_start_game()
		elif mode == "pause":
			_toggle_pause()


func show_banner(title: String, sub := "", secs := 2.8) -> void:
	var t := "[center][b][color=#f2c230]%s[/color][/b]" % title
	if sub != "":
		t += "\n[font_size=24][color=#bfe8ff]%s[/color][/font_size]" % sub
	t += "[/center]"
	banner_lbl.text = t
	banner.size = Vector2.ZERO
	await get_tree().process_frame
	banner.position = Vector2(960 - banner.size.x / 2.0, 120)
	var tw := create_tween()
	banner.scale = Vector2(0.92, 0.92)
	banner.pivot_offset = banner.size / 2.0
	tw.set_parallel(true)
	tw.tween_property(banner, "modulate:a", 1.0, 0.2)
	tw.tween_property(banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(secs)
	tw.chain().tween_property(banner, "modulate:a", 0.0, 0.4)


func log_msg(text: String, kind := "") -> void:
	hud.msg.text = text
	var c := Color(1, 1, 1, 0.85)
	if kind == "bad":
		c = Color("ff8a80")
	elif kind == "good":
		c = Color("9ef08a")
	hud.msg.add_theme_color_override("font_color", c)


func _fmt(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _clock_text() -> String:
	var frac := 0.0
	if not period.is_empty():
		frac = clampf(period_t / period["dur"], 0.0, 1.0)
	var m := int(lerpf(CLOCK[period_idx], CLOCK[period_idx + 1], frac))
	var h := m / 60
	return "%d:%02d %s" % [h if h <= 12 else h - 12, m % 60, "am" if h < 12 else "pm"]


func _period_info() -> Dictionary:
	if period.is_empty():
		return {"title": "Inkwell Academy", "room": "", "place": ""}
	var ty: String = period["type"]
	if ty == "reg" or ty == "lesson":
		var rm: Dictionary = ROOMS[period["room"]]
		return {"title": "%s  ·  %s  ·  %s" % [period["subject"]["name"], period["teacher"].cname, rm["name"]],
			"room": period["room"], "place": "%s (%s)" % [rm["name"], FLOORS[rm["f"]]["label"].to_lower()]}
	if ty == "dinner":
		return {"title": "Dinner  ·  Dining Hall", "room": "dining", "place": "Dining Hall (ground floor)"}
	if ty == "play":
		return {"title": "Playtime", "room": "", "place": ""}
	return {"title": "Home time", "room": "", "place": ""}


func _update_hud() -> void:
	hud.day.get_meta("l").text = "Day %d" % day
	hud.clock.get_meta("l").text = _clock_text()
	var info := _period_info()
	hud.period.text = info["title"]
	hud.score.text = "Score " + _fmt(score)
	hud.hi.text = "Best " + _fmt(hi)
	hud.bar.value = lines
	hud.lines.text = "%s / 10,000" % _fmt(lines)
	var fr := float(lines) / MAX_LINES
	hud.fill.bg_color = Color("6fd36a").lerp(Color("f2c230"), clampf(fr * 2.0, 0, 1)).lerp(Color("e84a3a"), clampf(fr * 2.0 - 1.0, 0, 1))
	var n := _lit_count()
	for i in 8:
		hud.crests[i].texture = load("res://art/crest_on.svg" if crests[i]["lit"] else "res://art/crest_off.svg")
	if n == crests.size():
		hud.bell.text = "Founder's Bell: READY — find the rope!"
		hud.bell.add_theme_color_override("font_color", Color("9ef08a"))
	else:
		hud.bell.text = "Founder's Bell: silent"
		hud.bell.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	# hint
	var w := ""
	var c := player
	var near_up := false
	var near_dn := false
	if c.state != "stairs":
		for s in STAIRS:
			if s["lo"] == c.floor_i and absf(c.wx - s["xlo"]) < 50:
				near_up = true
			if s["hi"] == c.floor_i and absf(c.wx - s["xhi"]) < 50:
				near_dn = true
	if c.state == "down":
		w = "Seeing stars…"
	elif c.floor_i == 0 and absf(c.wx - ROPE_X) < 85 and c.state != "stairs":
		w = "Press E to pull the bell rope"
	elif near_up:
		w = "Press Up to climb the stairs"
	elif near_dn:
		w = "Press Down to go downstairs"
	elif not period.is_empty() and info["room"] != "":
		if not _in_room(c, info["room"]):
			w = "Go to " + info["place"]
		elif period["type"] != "dinner" and c.state != "sit":
			w = "In class — find a desk and press S"
		else:
			w = "Eating dinner" if period["type"] == "dinner" else "Sitting quietly…"
	elif not period.is_empty() and period["type"] == "play":
		w = "Playtime — free to roam"
	elif not period.is_empty():
		w = "School's out"
	hud.where.text = w
	hud.mm.queue_redraw()


func _draw_minimap(mm: Control) -> void:
	var W := mm.size.x
	var H := mm.size.y
	var sx := W / WORLD_W
	var rh := 30.0
	var row := func(f): return 6.0 + f * 38.0
	mm.draw_style_box(_style(Color(1, 1, 1, 0.06), 12), Rect2(Vector2.ZERO, mm.size))
	var info := _period_info()
	for k in ROOMS:
		var rm: Dictionary = ROOMS[k]
		var y: float = row.call(rm["f"])
		var col := Color(0.25, 0.6, 0.3, 0.55) if rm.has("outside") else Color(1, 1, 1, 0.1)
		if info["room"] == k:
			col = Color(0.35, 0.85, 0.45, 0.65)
		mm.draw_rect(Rect2(rm["x0"] * sx + 1, y, (rm["x1"] - rm["x0"]) * sx - 2, rh), col)
	for s in STAIRS:
		mm.draw_line(Vector2(s["xlo"] * sx, row.call(s["lo"]) + rh), Vector2(s["xhi"] * sx, row.call(s["hi"]) + rh), Color(1, 1, 1, 0.35), 2.0, true)
	for cr in crests:
		mm.draw_circle(Vector2(cr["x"] * sx, row.call(cr["f"]) + 12), 4.0, Color("f2c230") if cr["lit"] else Color(1, 1, 1, 0.25))
	mm.draw_rect(Rect2(ROPE_X * sx - 1, row.call(0) + 2, 3, 22), Color("e8473c"))
	for c in chars:
		var y: float = row.call(c.floor_i) + rh
		if c.state == "stairs" and c.stair != null:
			y = lerpf(row.call(c.stair["lo"]) + rh, row.call(c.stair["hi"]) + rh, c.st)
		var col := Color(1, 1, 1, 0.75)
		var hh := 9.0
		if c.kind == "teacher":
			col = Color("ff6b6b") if c.id != "thistle" else Color("d68cff")
			hh = 13.0
		if c.id == "knuckles":
			col = Color("ffa040")
		if c.id == "tattle":
			col = Color("6cd0ff")
		if c == player:
			col = Color("ffe14a")
			hh = 14.0
			mm.draw_circle(Vector2(c.wx * sx, y - 7), 8.0 + 2.0 * sin(gt * 6.0), Color(1, 0.9, 0.3, 0.25))
		mm.draw_rect(Rect2(c.wx * sx - 2.5, y - hh, 5, hh), col)


# ================================================================= game flow
func _start_game() -> void:
	_play("click")
	for c in chars:
		c.queue_free()
	for p in pellets:
		p["n"].queue_free()
	chars.clear()
	npcs.clear()
	pellets.clear()
	T.clear()
	for cr in crests:
		cr["lit"] = false
		cr["n"].texture = load("res://art/crest_off.svg")
	for k in board_labels:
		board_labels[k].text = ""
	for n in fx.get_children():
		n.queue_free()
	player = _mk({"id": "pip", "cname": "Pip", "kind": "player", "floor_i": 2, "wx": 380.0, "speed": 310.0, "accent": Color("e8473c")})
	player.z_index = 2
	for i in PUPILS.size():
		var p: Array = PUPILS[i]
		npcs.append(_mk({"id": p[0], "cname": p[1], "kind": "pupil", "floor_i": 2, "wx": randf_range(60, 700),
			"speed": randf_range(225, 255), "desk": i, "dir": 1 if randf() < 0.5 else -1, "accent": Color(p[2])}))
	for d in TEACHERS:
		var c := _mk({"id": d[0], "cname": d[1], "title": d[2], "kind": "teacher", "floor_i": d[4], "wx": d[5], "speed": 200.0, "accent": Color(d[3])})
		T[d[0]] = c
		npcs.append(c)
	mode = "play"
	gt = 0.0
	day = 1
	score = 0
	lines = 0
	bells = 0
	timers.clear()
	next_chat = 8.0
	todays = LESSON_KEYS.duplicate()
	todays.shuffle()
	_hide_overlay()
	cam.position = Vector2(player.wx, VIEW_H / 2.0)
	cam.reset_smoothing()
	_start_period(0)
	log_msg("Morning! Follow the timetable at the top of the screen.")


func _toggle_pause() -> void:
	if mode == "play":
		mode = "pause"
		_show_overlay("[center][font_size=72][b]Paused[/b][/font_size]\n\n[font_size=30]Press P or click to carry on[/font_size][/center]")
	elif mode == "pause":
		mode = "play"
		_hide_overlay()


func _game_over() -> void:
	mode = "over"
	_play("expel")
	_update_hud()
	_show_overlay(("[center][font_size=88][b][color=#c0392b]Expelled![/color][/b][/font_size]\n"
		+ "[font_size=30][color=#6a5a7a]10,000 lines. Dr Thistle has written to your parents.[/color][/font_size]\n\n"
		+ "You lasted until [b]Day %d, %s[/b].\n"
		+ "Score [b][color=#2f8f3a]%s[/color][/b]      Best [b]%s[/b]      Half-holidays won [b]%d[/b]\n\n"
		+ "[font_size=34][b][color=#2f6e5a]Press Enter or click to try again[/color][/b][/font_size][/center]") % [day, _clock_text(), _fmt(score), _fmt(hi), bells])


func _start_period(i: int) -> void:
	period_idx = i
	period_t = 0.0
	var ty: String = DAY_PLAN[i]
	var p := {"type": ty, "dur": DURS[ty], "phase": "gather", "next_check": 0.0, "mode": "talk", "mode_until": 0.0, "chalk": 0.0}
	var sub = null
	if ty == "reg":
		sub = SUBJECTS["register"]
	elif ty == "lesson":
		var k := 0
		for j in i:
			if DAY_PLAN[j] == "lesson":
				k += 1
		sub = SUBJECTS[todays[k]]
	if sub != null:
		p["subject"] = sub
		p["room"] = sub["room"]
		p["teacher"] = T[sub["teacher"]]
		p["board"] = String(sub["boards"].pick_random()).replace("{day}", str(day))
	if ty == "dinner":
		p["room"] = "dining"
		p["teacher"] = T["brandish"]
	period = p
	for c in npcs:
		if c.special == "":
			c.target = null
			c.arrived = true
			c.wait_until = 0.0
		c.seat = -9
	_play("bell")
	var info := _period_info()
	if ty == "home":
		show_banner("Home time!")
	elif ty == "play":
		show_banner("Playtime", "Free to roam — mind Knuckles")
	else:
		show_banner(info["title"], "Go to " + info["place"], 3.2)
	if ty == "play":
		log_msg("The bell rings. Playtime!")
	elif ty == "home":
		log_msg("The bell rings. Home time!")
	else:
		log_msg("The bell rings. Next: %s." % info["title"])


func _new_day() -> void:
	_add_score(1000)
	day += 1
	todays = LESSON_KEYS.duplicate()
	todays.shuffle()
	for c in chars:
		if c.kind == "teacher":
			continue
		c.state = "idle"
		c.floor_i = 2
		c.wx = randf_range(60, 700)
		c.wy = FLOORS[2]["y"]
		c.stair = null
		c.special = ""
		c.target = null
	_start_period(0)
	later(3.6, func(): show_banner("Day %d" % day, "+1,000 for surviving another day", 2.6))


func later(secs: float, fn: Callable) -> void:
	timers.append({"at": gt + secs, "fn": fn})


func _play(n: String, vol := 0.0) -> void:
	if muted or not sfx.has(n):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sfx[n]
	p.volume_db = vol
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func _add_score(n: int) -> void:
	score += n
	if score > hi:
		hi = score
		var cfg := ConfigFile.new()
		cfg.set_value("score", "hi", hi)
		cfg.save("user://inkwell.cfg")


func add_lines(base: int, speaker: Chara, msg_in) -> void:
	if mode != "play":
		return
	var mult := 1.0 + 0.15 * (day - 1)
	var n := maxi(50, int(round(base * mult / 50.0)) * 50)
	lines = mini(MAX_LINES, lines + n)
	var msg: String = fresh(speaker, msg_in) if (msg_in is Array and speaker) else (msg_in if msg_in is String else msg_in[0])
	var text := msg.replace("{n}", _fmt(n))
	if speaker:
		say(speaker, text)
	log_msg(("%s: " % speaker.cname if speaker else "") + text, "bad")
	_play("lines", 6.0)
	var tw := create_tween()
	hud.lines.pivot_offset = hud.lines.size / 2.0
	tw.tween_property(hud.lines, "scale", Vector2(1.25, 1.25), 0.08)
	tw.tween_property(hud.lines, "scale", Vector2.ONE, 0.2)
	if lines >= MAX_LINES:
		_game_over()


# ================================================================= speech bubbles
## A message from `pool` this character has not said yet. When the pool is used up it starts over,
## but never opens with the message it finished on.
func fresh(c: Chara, pool: Array) -> String:
	var opts := pool.filter(func(m): return not c.used.has(m))
	if opts.is_empty():
		for m in pool:
			c.used.erase(m)
		opts = pool.filter(func(m): return m != c.last_said)
		if opts.is_empty():
			opts = pool.duplicate()
	var pick: String = opts.pick_random()
	c.used[pick] = true
	c.last_said = pick
	return pick


## Teachers speak up every few seconds: lessons, registers, dinner, or patrolling the corridors.
func _teacher_chatter() -> void:
	for t in T.values():
		if gt < t.next_speak or not _awake(t) or t.state == "stairs":
			continue
		t.next_speak = gt + randf_range(2.6, 4.8)
		if t.bubble and gt < t.bubble_until:
			continue
		var pool: Array = PATROL_TALK
		var ty: String = period["type"]
		if period.get("teacher") == t and ty != "play" and ty != "home":
			if ty == "dinner":
				pool = DINNER_TALK
			elif period["phase"] == "gather":
				pool = GATHER_TALK
			else:
				pool = period["subject"]["talk"] + CLASS_TALK
		say(t, fresh(t, pool))


func say(c: Chara, text: String, dur := 2.8) -> void:
	if c.kind == "teacher":
		c.last_said = text
	if c.bubble:
		c.bubble.queue_free()
	var b := Node2D.new()
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.97)
	sb.set_corner_radius_all(18)
	sb.border_color = c.accent.darkened(0.15)
	sb.set_border_width_all(3)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	sb.shadow_color = Color(0, 0, 0, 0.22)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font_ui)
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Color("2b2233"))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var w := font_ui.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 22).x
	if w > 320:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(320, 0)
	panel.add_child(l)
	b.add_child(panel)
	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([Vector2(-10, -2), Vector2(10, -2), Vector2(0, 14)])
	tail.color = Color(1, 1, 1, 0.97)
	b.add_child(tail)
	var name_tag := _label(c.cname, 16, c.accent.darkened(0.25), true)
	name_tag.position = Vector2(14, -20)
	b.add_child(name_tag)
	fx.add_child(b)
	b.set_meta("panel", panel)
	b.set_meta("tail", tail)
	b.modulate.a = 0.0
	b.scale = Vector2(0.85, 0.85)
	var tw := b.create_tween().set_parallel(true)
	tw.tween_property(b, "modulate:a", 1.0, 0.12)
	tw.tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	c.bubble = b
	c.bubble_until = gt + dur
	_place_bubble(c)


func _place_bubble(c: Chara) -> void:
	var b := c.bubble
	if b == null:
		return
	if gt > c.bubble_until:
		var old := b
		c.bubble = null
		var tw := old.create_tween()
		tw.tween_property(old, "modulate:a", 0.0, 0.2)
		tw.tween_callback(old.queue_free)
		return
	var panel: PanelContainer = b.get_meta("panel")
	var sz := panel.size
	var vx := cam.get_screen_center_position().x - 960.0
	var top := c.head_top() - 18.0
	var bx := clampf(c.wx - sz.x / 2.0, vx + 12.0, vx + 1908.0 - sz.x)
	var by := maxf(104.0, top - sz.y - 14.0)
	b.position = Vector2(roundf(bx), roundf(by))
	var tail: Polygon2D = b.get_meta("tail")
	tail.position = Vector2(clampf(c.wx - bx, 22.0, sz.x - 22.0), sz.y - 1.0)


# ================================================================= movement & AI
func _set_target(c: Chara, f: int, x: float, sit := false) -> void:
	if c.target != null and c.target["f"] == f and absf(c.target["x"] - x) < 3.0 and c.target["sit"] == sit:
		return
	c.target = {"f": f, "x": x, "sit": sit}
	c.arrived = false
	c.wait_until = 0.0
	if c.state == "sit":
		c.state = "idle"


func _stair_choice(f: int, tf: int, x: float, tx: float) -> Array:
	var up := tf < f
	var best = null
	var best_cost := INF
	for s in STAIRS:
		if (up and s["lo"] != f) or (not up and s["hi"] != f):
			continue
		var entry: float = s["xlo"] if up else s["xhi"]
		var exit_f: int = s["hi"] if up else s["lo"]
		var exit_x: float = s["xhi"] if up else s["xlo"]
		var next_x := tx
		if exit_f != tf:
			var bd := INF
			for q in STAIRS:
				if (up and q["lo"] == exit_f) or (not up and q["hi"] == exit_f):
					var qx: float = q["xlo"] if up else q["xhi"]
					if absf(qx - exit_x) < bd:
						bd = absf(qx - exit_x)
						next_x = qx
		var cost := absf(x - entry) + absf(exit_x - next_x)
		if cost < best_cost:
			best_cost = cost
			best = s
	return [best, up]


func _enter_stairs(c: Chara, s: Dictionary, up: bool) -> void:
	c.state = "stairs"
	c.stair = s
	c.st = 0.0 if up else 1.0
	c.stair_dir = 1 if up else -1
	c.wx = s["xlo"] if up else s["xhi"]


func _advance_stairs(c: Chara, d: float) -> void:
	var s: Dictionary = c.stair
	var ylo: float = FLOORS[s["lo"]]["y"]
	var yhi: float = FLOORS[s["hi"]]["y"]
	var length := Vector2(s["xhi"] - s["xlo"], yhi - ylo).length()
	c.st += d / length
	c.dir = 1 if d > 0 else -1
	c.moved = absf(d)
	if c.st >= 1.0:
		c.floor_i = s["hi"]
		c.wx = s["xhi"]
		c.wy = yhi
		c.state = "walk"
		c.stair = null
	elif c.st <= 0.0:
		c.floor_i = s["lo"]
		c.wx = s["xlo"]
		c.wy = ylo
		c.state = "walk"
		c.stair = null
	else:
		c.wx = lerpf(s["xlo"], s["xhi"], c.st)
		c.wy = lerpf(ylo, yhi, c.st)


func _walk_toward(c: Chara, x: float, dt: float) -> void:
	var dx := x - c.wx
	var step := signf(dx) * minf(absf(dx), c.speed * dt)
	c.wx += step
	if dx != 0:
		c.dir = 1 if dx > 0 else -1
	c.state = "walk"
	c.moved = absf(step)


func _step_npc(c: Chara, dt: float) -> void:
	if c.state == "down":
		if gt > c.down_until:
			c.state = "idle"
			c.target = null
			c.arrived = true
			if c.kind == "teacher":
				_on_teacher_wake(c)
		return
	if c.state == "stairs":
		_advance_stairs(c, c.stair_dir * c.speed * dt)
		return
	var tg = c.target
	if tg == null:
		if c.state == "walk":
			c.state = "idle"
		return
	if c.floor_i == tg["f"]:
		if absf(tg["x"] - c.wx) <= 5.0:
			c.wx = tg["x"]
			if not c.arrived:
				c.arrived = true
				c.state = "idle"
				if tg["sit"]:
					c.dir = -1
					var key := _class_room(c)
					if key != "":
						var si := _seat_index_at(key, tg["x"])
						if _pupil_takes_seat(c, key, si):
							c.state = "sit"
						elif c.kind == "pupil":
							# its desk is taken: try Pip's own desk, otherwise stand about
							c.seat = PLAYER_SEAT if si != PLAYER_SEAT else NO_SEAT
					else:
						c.state = "sit"
			elif c.state == "walk":
				c.state = "idle"
			return
		_walk_toward(c, tg["x"], dt)
	else:
		var ch := _stair_choice(c.floor_i, tg["f"], c.wx, tg["x"])
		var s: Dictionary = ch[0]
		var up: bool = ch[1]
		var entry: float = s["xlo"] if up else s["xhi"]
		if absf(entry - c.wx) <= 5.0:
			_enter_stairs(c, s, up)
		else:
			_walk_toward(c, entry, dt)
	c.wy = FLOORS[c.floor_i]["y"] if c.state != "stairs" else c.wy


func _in_room(c: Chara, key: String) -> bool:
	var rm: Dictionary = ROOMS[key]
	return c.state != "stairs" and c.floor_i == rm["f"] and c.wx >= rm["x0"] and c.wx <= rm["x1"]


func _sees(t: Chara, p: Chara, rng: float) -> bool:
	if t.state == "down" or t.state == "stairs" or p.state == "stairs" or t.floor_i != p.floor_i:
		return false
	var dx := p.wx - t.wx
	return absf(dx) < rng and (signf(dx) == t.dir or absf(dx) < 110.0)


func _awake(c: Chara) -> bool:
	return c.state != "down"


func _seat_index_at(key: String, x: float) -> int:
	var rm: Dictionary = ROOMS[key]
	for i in 11:
		if absf(_desk_x(rm, i) - x) < 6.0:
			return i
	return NO_SEAT


func _desk_x(rm: Dictionary, i: int) -> float:
	return roundf(lerpf(rm["x0"] + 375.0, rm["x1"] - 52.0, i / 10.0))


const PLAYER_SEAT := 10     # the eleventh desk in every classroom is Pip's own
const SEAT_REACH := 46.0
const PUNCH_REACH := 92.0
const NO_SEAT := -1


## The classroom a character is standing in, or "" when it is not in one.
func _class_room(c: Chara) -> String:
	for k in ROOMS:
		if ROOMS[k].get("board", false) and _in_room(c, k):
			return k
	return ""


## Who is sitting at desk `i` of room `key`: one kid per table.
func _seat_occupant(key: String, i: int) -> Chara:
	var rm: Dictionary = ROOMS[key]
	var x := _desk_x(rm, i)
	for c in chars:
		if c.state == "sit" and c.floor_i == rm["f"] and absf(c.wx - x) < 6.0:
			return c
	return null


## The desk nearest to a character, when it is close enough to sit at; NO_SEAT otherwise.
func _seat_near(c: Chara) -> int:
	var key := _class_room(c)
	if key == "":
		return NO_SEAT
	var rm: Dictionary = ROOMS[key]
	var best := NO_SEAT
	var bd := SEAT_REACH
	for i in 11:
		var d := absf(_desk_x(rm, i) - c.wx)
		if d < bd:
			bd = d
			best = i
	return best


## Pip tries to sit. Only a desk will do, and a desk with someone at it is not free.
func _player_sit() -> void:
	var c := player
	var i := _seat_near(c)
	if i == NO_SEAT:
		say(c, "I can only sit at a desk!", 1.6)
		return
	var key := _class_room(c)
	if _seat_occupant(key, i) != null:
		say(c, "Someone's already sitting there!", 1.6)
		return
	c.wx = _desk_x(ROOMS[key], i)
	c.dir = -1
	c.state = "sit"


## A pupil has walked to its desk. The desk must be free; a pupil never shoves Pip out of
## a desk that is not Pip's own, but anybody who takes Pip's own desk shoves Pip to the floor.
func _pupil_takes_seat(c: Chara, key: String, i: int) -> bool:
	var sitter := _seat_occupant(key, i)
	if sitter != null and sitter != player:
		return false
	if sitter == player:
		if i != PLAYER_SEAT:
			return false
		_shove_to_floor(player, c)
	return true


func _shove_to_floor(victim: Chara, by: Chara) -> void:
	victim.state = "down"
	victim.down_until = gt + 0.9
	victim.to_floor = true
	victim.moved = 0.0
	say(by, ["Mine now!", "Shove over, Pip!", "That's my spot!"].pick_random(), 1.8)
	log_msg("%s shoves you out of your seat!" % by.cname, "bad")
	_play("punch")
	_shake(7.0)
	_burst(Vector2(victim.wx, victim.wy - 40.0), Color("ffe08a"), 10)


func _wander(c: Chara, area) -> void:
	if not c.arrived:
		return
	if c.wait_until == 0.0:
		c.wait_until = gt + randf_range(1.5, 5.0)
		return
	if gt < c.wait_until:
		return
	var f := 0
	var x := 0.0
	if area is String and area == "school":
		f = randi_range(0, 2)
		x = randf_range(2320, 4720) if f == 0 else randf_range(maxf(FLOORS[f]["x0"], 790.0) + 40, 5900)
	else:
		f = area["f"]
		x = randf_range(area["x0"] + 50.0, area["x1"] - 50.0)
		if area == ROOMS["study"]:
			x = randf_range(4880, 5800)
	_set_target(c, f, x)


func _pupil_duty(c: Chara) -> void:
	var ty: String = period["type"]
	if c.id == "knuckles" and _bully_update(c):
		return
	if c.id == "tattle" and _tattle_update(c):
		return
	if ty == "reg" or ty == "lesson":
		var rm: Dictionary = ROOMS[period["room"]]
		var want: int = c.desk if c.seat == -9 else c.seat
		if want == NO_SEAT:
			_wander(c, rm)
		else:
			_set_target(c, rm["f"], _desk_x(rm, want), true)
	elif ty == "play":
		_wander(c, ROOMS["yard"])
	elif ty == "dinner":
		_wander(c, ROOMS["dining"])
	else:
		_set_target(c, 2, 40.0 + c.desk * 12.0)


func _teacher_duty(t: Chara) -> void:
	var ty: String = period["type"]
	if period.get("teacher") == t and ty != "dinner":
		var rm: Dictionary = ROOMS[period["room"]]
		_set_target(t, rm["f"], rm["x0"] + 190.0)
		return
	if period.get("teacher") == t and ty == "dinner":
		_wander(t, ROOMS["dining"])
		return
	if t.id == "thistle":
		_wander(t, ROOMS["dining"] if ty == "dinner" else ROOMS["study"])
		return
	_wander(t, "school")


func _bully_update(k: Chara) -> bool:
	if k.state == "down":
		return true
	if k.special == "punching":
		return true
	var ty: String = period["type"]
	var calm: bool = (ty == "lesson" or ty == "reg") and period["phase"] == "teach"
	if k.special == "chase":
		if calm or gt > k.chase_until or player.state == "down":
			k.special = ""
			k.next_bully = gt + randf_range(15, 25)
			k.target = null
			k.speed = k.base_speed
			return false
		k.speed = 285.0
		_set_target(k, player.floor_i, player.wx)
		if k.floor_i == player.floor_i and k.state != "stairs" and player.state != "stairs" and absf(k.wx - player.wx) < 78.0:
			# wind up and throw the punch; it lands a moment later if Pip is still in reach
			k.special = "punching"
			k.target = null
			k.arrived = true
			k.state = "idle"
			k.moved = 0.0
			k.dir = 1 if player.wx > k.wx else -1
			k.speed = k.base_speed
			k.start_punch()
			say(k, ["Gotcha, Pip!", "Take that!", "Ha! Too slow!"].pick_random())
			_play("whoosh", -4.0)
			later(0.13, func(): _knuckles_lands(k))
		return true
	if not calm and gt > k.next_bully and player.state != "down" and mode == "play":
		k.special = "chase"
		k.chase_until = gt + 12.0
		say(k, "Oi, Pip! C'mere!")
		return true
	return false


func _knuckles_lands(k: Chara) -> void:
	k.special = ""
	k.next_bully = gt + randf_range(18, 30) / (1.0 + 0.1 * (day - 1))
	if mode != "play" or k.state == "down":
		return
	if k.floor_i == player.floor_i and player.state != "stairs" and player.state != "down" and absf(k.wx - player.wx) < 100.0:
		player.state = "down"
		player.down_until = gt + 1.6
		player.to_floor = false
		player.dir = -k.dir
		log_msg("Knuckles knocks you flat!", "bad")
		_play("punch")
		_shake(10.0)
		_burst(Vector2(player.wx - k.dir * 8.0, player.wy - 70.0), Color("fff0a0"), 14)


func _nearest_teacher(c: Chara) -> Chara:
	var best: Chara = null
	var bc := INF
	for t in T.values():
		if not _awake(t):
			continue
		var cost := absf(t.floor_i - c.floor_i) * 1100.0 + absf(t.wx - c.wx)
		if cost < bc:
			bc = cost
			best = t
	return best


func _tattle_update(tt: Chara) -> bool:
	if tt.special != "tell":
		return false
	if tt.state == "down":
		return true
	var t := _nearest_teacher(tt)
	if gt > tt.tell_until or t == null:
		tt.special = ""
		tt.target = null
		return false
	tt.speed = 270.0
	_set_target(tt, t.floor_i, roundf(t.wx + (-45.0 if t.wx > tt.wx else 45.0)))
	if tt.floor_i == t.floor_i and tt.state != "stairs" and t.state != "stairs" and absf(tt.wx - t.wx) < 68.0:
		say(tt, "Please %s! Pip's got a pea-shooter!" % t.title)
		later(1.4, func(): if _awake(t): add_lines(400, t, ["Is that so? {n} lines, Pip!", "A pea-shooter?! {n} lines, Pip!", "Hand it over! {n} lines, Pip!"]))
		tt.special = ""
		tt.target = null
		tt.cool = gt + 20.0
		tt.speed = tt.base_speed
	return true


func _on_teacher_wake(t: Chara) -> void:
	if player.floor_i == t.floor_i and player.state != "stairs" and absf(player.wx - t.wx) < 260.0:
		t.dir = 1 if player.wx > t.wx else -1
		add_lines(300, t, ["Was that you, Pip? {n} lines!", "I think it was you, Pip. {n} lines!", "Pip! Again?! {n} lines!"])
	else:
		say(t, ["Who threw that?!", "Ow! My ear!", "Hooligans!"].pick_random())


func _lesson_update(dt: float) -> void:
	if not period.has("teacher"):
		return
	var t: Chara = period["teacher"]
	var ty: String = period["type"]
	var rkey: String = period["room"]
	var rm: Dictionary = ROOMS[rkey]
	var el := period_t
	if ty == "lesson" or ty == "reg":
		var post: float = rm["x0"] + 190.0
		var at_post: bool = _awake(t) and t.floor_i == rm["f"] and t.state != "stairs" and absf(t.wx - post) < 10.0
		if period["phase"] == "gather":
			if at_post and el > GATHER:
				period["phase"] = "teach"
				period["next_check"] = el + 4.0
				period["mode"] = "talk"
				period["mode_until"] = el + 3.0
				period["chalk"] = 0.0
				var bl: Label = board_labels[rkey]
				bl.text = period["board"]
				bl.visible_characters = 0
				t.dir = 1
				say(t, period["subject"]["open"])
		elif period["phase"] == "teach" and at_post:
			if el > period["mode_until"]:
				if period["mode"] == "write":
					period["mode"] = "talk"
					period["mode_until"] = el + randf_range(3, 5)
				else:
					period["mode"] = "write"
					period["mode_until"] = el + randf_range(4, 7)
			t.dir = -1 if period["mode"] == "write" else 1
			if period["mode"] == "write":
				var bl: Label = board_labels[rkey]
				if period["chalk"] < bl.get_total_character_count():
					period["chalk"] += dt * 6.0
					bl.visible_characters = int(period["chalk"])
			if el > period["next_check"]:
				# keep looking every half second; a teacher only punishes what he can see, so
				# standing in class is safe while his back is turned (he is writing on the board)
				period["next_check"] = el + 0.5
				if not _in_room(player, rkey):
					period["next_check"] = el + 6.0
					add_lines(300, t, ["Where is Pip? {n} lines!", "Pip is absent! {n} lines!", "Pip, where were you? {n} lines!", "Late AGAIN, Pip? {n} lines!", "Truant! {n} lines!"])
				elif player.state == "sit":
					period["next_check"] = el + 6.0
				elif _sees(t, player, 1400.0):
					period["next_check"] = el + 6.0
					add_lines(100, t, ["Sit DOWN, Pip! {n} lines.", "Pip, sit this instant! {n} lines.", "On your bottom, Pip! {n} lines.", "Why are you standing, Pip? {n} lines.", "Take a seat, Pip! {n} lines.", "Do you live on your feet? {n} lines."])
	elif ty == "dinner":
		if period["phase"] == "gather" and el > GATHER:
			period["phase"] = "teach"
			period["next_check"] = el + 2.0
		if period["phase"] == "teach" and _awake(t) and el > period["next_check"]:
			period["next_check"] = el + 7.0
			if not _in_room(player, "dining"):
				add_lines(250, t, ["Pip has skipped dinner! {n} lines!", "Where is Pip at dinner? {n} lines!", "Missing a meal, Pip? {n} lines!"])
	if (ty == "lesson" or ty == "reg") and period["phase"] == "teach":
		for o in T.values():
			if o == t or not _sees(o, player, 490.0) or _in_room(player, rkey) or gt < o.catch_cd:
				continue
			o.catch_cd = gt + 8.0
			add_lines(250, o, ["Shouldn't you be in class, Pip? {n} lines.", "Out of class, Pip? {n} lines.", "Lost, are we? {n} lines.", "Get to your lesson, Pip! {n} lines."])


# ================================================================= player
func _player_update(dt: float) -> void:
	var c := player
	c.moved = 0.0
	var L := Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)
	var R := Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)
	var U := Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)
	var D := Input.is_key_pressed(KEY_DOWN)
	if c.state == "down":
		if gt > c.down_until:
			c.state = "floor" if c.to_floor else "idle"
			c.to_floor = false
		return
	if c.state == "floor":
		if L or R or U or D:
			c.state = "idle"
		else:
			return
	if c.state == "stairs":
		var d := 0.0
		if U or R:
			d += 1.0
		if D or L:
			d -= 1.0
		if d != 0.0:
			_advance_stairs(c, d * c.speed * 0.85 * dt)
		return
	if c.state == "sit":
		if L or R or U or D:
			c.state = "idle"
		else:
			return
	if U:
		for s in STAIRS:
			if s["lo"] == c.floor_i and absf(c.wx - s["xlo"]) < 50.0:
				_enter_stairs(c, s, true)
				return
	if D:
		for s in STAIRS:
			if s["hi"] == c.floor_i and absf(c.wx - s["xhi"]) < 50.0:
				_enter_stairs(c, s, false)
				return
	var dirn := (1 if R else 0) - (1 if L else 0)
	if dirn != 0:
		var f: Dictionary = FLOORS[c.floor_i]
		var nx := clampf(c.wx + dirn * c.speed * dt, f["x0"], f["x1"])
		c.moved = absf(nx - c.wx)
		c.wx = nx
		c.dir = dirn
		c.state = "walk"
	elif c.state == "walk":
		c.state = "idle"
	c.wy = FLOORS[c.floor_i]["y"]


func _fire() -> void:
	var c := player
	if c.state == "down" or gt < c.fire_cd:
		return
	if c.state == "stairs":
		say(c, "Can't aim on the stairs!", 1.5)
		return
	if c.state == "sit" or c.state == "floor":
		say(c, "Can't aim from down here!", 1.5)
		return
	c.fire_cd = gt + 0.55
	c.start_fire()
	# the pea leaves the tube when the puff does
	later(0.1, func(): _spawn_pellet(c, c.dir, c.floor_i))
	_play("fire")
	var caught := false
	for t in T.values():
		if _sees(t, c, 640.0):
			add_lines(500, t, ["No pea-shooters in school! {n} lines.", "I SAW that, Pip! {n} lines.", "Put that away! {n} lines.", "Peas are for plates! {n} lines.", "Confiscated! Well, nearly. {n} lines."])
			caught = true
			break
	var tt: Chara = null
	for n2 in npcs:
		if n2.id == "tattle":
			tt = n2
	if not caught and tt and tt.special != "tell" and gt > tt.cool and _sees(tt, c, 525.0):
		tt.special = "tell"
		tt.tell_until = gt + 25.0
		say(tt, "Ooh! I'm telling!")
		log_msg("Tattle saw that… and is off to tell a teacher!", "bad")


func _spawn_pellet(c: Chara, dirn: int, f: int) -> void:
	if mode != "play" or c.state == "down" or c.state == "stairs":
		return
	var y: float = FLOORS[f]["y"] - PELLET_H
	var x := c.wx + dirn * 52.0
	var n := _spr("res://art/pea.svg", Vector2(x, y), 0.55)
	n.z_index = 20
	world.add_child(n)
	pellets.append({"x": x, "f": f, "dir": dirn, "dist": 0.0, "n": n})
	_burst(Vector2(x, y), Color("d8f5c0"), 5)


## Pip throws a punch. Whoever is in front, in reach, is knocked to the floor; any teacher
## who sees it gives lines.
func _punch() -> void:
	var c := player
	if c.state != "idle" and c.state != "walk":
		return
	if gt < c.fire_cd:
		return
	c.fire_cd = gt + 0.6
	c.moved = 0.0
	c.start_punch()
	_play("whoosh", -4.0)
	later(0.13, func(): _punch_lands())


func _punch_lands() -> void:
	var c := player
	if mode != "play" or c.state == "down" or c.state == "stairs":
		return
	var victim: Chara = null
	var bd := PUNCH_REACH
	for n in npcs:
		if n.kind != "pupil" or n.floor_i != c.floor_i or n.state == "down" or n.state == "stairs":
			continue
		var dx: float = n.wx - c.wx
		if signf(dx) == c.dir and absf(dx) < bd:
			bd = absf(dx)
			victim = n
	if victim != null:
		victim.state = "down"
		victim.down_until = gt + 3.5
		victim.to_floor = false
		victim.target = null
		victim.arrived = true
		victim.wait_until = 0.0
		victim.special = ""
		victim.dir = -c.dir
		say(victim, ["Ow!", "Oi!", "Ooof!"].pick_random(), 1.4)
		_play("punch")
		_shake(6.0)
		_burst(Vector2(victim.wx - c.dir * 10.0, victim.wy - 70.0), Color("fff0a0"), 12)
		log_msg("You punch %s to the floor." % victim.cname)
	for t in T.values():
		if _sees(t, c, 640.0):
			var what: Array = ["Hitting people! {n} lines, Pip!", "We do not punch! {n} lines.", "Disgraceful, Pip! {n} lines."] if victim != null else ["No fighting, Pip! {n} lines.", "Fists down, Pip! {n} lines.", "Behave! {n} lines."]
			add_lines(500 if victim != null else 300, t, what)
			break


## Pip sitting on the floor, in plain view, is a caution.
func _floor_update() -> void:
	var c := player
	if c.state != "floor" or gt < c.cool:
		return
	for t in T.values():
		if _sees(t, c, 640.0):
			c.cool = gt + 6.0
			add_lines(200, t, ["Get up off that floor, Pip! {n} lines.", "We do not sit on floors! {n} lines.", "Floors are for feet, Pip! {n} lines.", "Up! Up! {n} lines."])
			return


func _pellets_update(dt: float) -> void:
	for i in range(pellets.size() - 1, -1, -1):
		var pl: Dictionary = pellets[i]
		var step := 1050.0 * dt
		pl["x"] += pl["dir"] * step
		pl["dist"] += step
		pl["n"].position.x = pl["x"]
		pl["n"].rotation += dt * 18.0 * pl["dir"]
		var done: bool = pl["dist"] > 1125.0 or pl["x"] < FLOORS[pl["f"]]["x0"] or pl["x"] > FLOORS[pl["f"]]["x1"]
		if not done:
			for t in T.values():
				if t.floor_i == pl["f"] and t.state != "down" and t.state != "stairs" and absf(t.wx - pl["x"]) < 28.0:
					# hit while looking straight at Pip: he saw exactly who fired
					if t.dir == -int(pl["dir"]):
						later(0.5, func(): add_lines(800, t, ["Shooting at a TEACHER, Pip?! {n} lines!", "At ME?! {n} lines, Pip!", "How DARE you! {n} lines!"]))
					t.state = "down"
					t.down_until = gt + 4.0
					t.target = null
					t.arrived = true
					t.wait_until = 0.0
					say(t, "OOF!", 1.2)
					_play("bonk")
					_play("whoosh", -6.0)
					_burst(pl["n"].position, Color("a8f07a"), 14)
					_add_score(50)
					log_msg("Bullseye! %s is down." % t.cname, "good")
					done = true
					break
		if not done:
			for cr in crests:
				if not cr["lit"] and cr["f"] == pl["f"] and absf(cr["x"] - pl["x"]) < 26.0:
					_light_crest(cr)
					done = true
					break
		if done:
			pl["n"].queue_free()
			pellets.remove_at(i)


func _lit_count() -> int:
	var n := 0
	for cr in crests:
		if cr["lit"]:
			n += 1
	return n


func _light_crest(cr: Dictionary) -> void:
	cr["lit"] = true
	var n: Sprite2D = cr["n"]
	n.texture = load("res://art/crest_on.svg")
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2(0.42, 0.42), 0.12).set_trans(Tween.TRANS_BACK)
	tw.tween_property(n, "scale", Vector2(0.32, 0.32), 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_burst(n.position, Color("ffd84a"), 36)
	_play("crest")
	_add_score(200)
	var c := _lit_count()
	if c == crests.size():
		show_banner("All eight crests shine!", "Pull the Founder's Bell rope in the Head's study", 4.0)
		log_msg("Legend says: when all crests shine, the Founder's Bell grants a half-holiday…", "good")
	else:
		log_msg("A crest lights up! (%d/%d)" % [c, crests.size()], "good")


func _try_rope() -> void:
	var c := player
	if c.floor_i != 0 or c.state == "stairs" or absf(c.wx - ROPE_X) > 85.0:
		return
	var head: Chara = T["thistle"]
	var tw := rope.create_tween()
	tw.tween_property(rope, "rotation", 0.12, 0.12)
	tw.tween_property(rope, "rotation", -0.08, 0.2)
	tw.tween_property(rope, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC)
	if _lit_count() < crests.size():
		say(c, "It won't budge. The crests must all shine first.", 2.5)
		return
	if _awake(head) and head.floor_i == 0 and head.state != "stairs" and head.wx > ROOMS["study"]["x0"]:
		head.dir = 1 if c.wx > head.wx else -1
		add_lines(2000, head, ["Hands OFF the Founder's Bell! {n} lines!", "Not the bell, Pip! {n} lines!"])
		return
	_play("founders")
	later(0.3, func(): _play("win"))
	_add_score(5000)
	lines = maxi(0, lines - 3000)
	bells += 1
	_shake(14.0)
	show_banner("The Founder's Bell rings!", "Half-holiday!  +5,000 points  ·  3,000 lines forgiven", 5.0)
	log_msg("BONG! BONG! The whole school cheers. Half-holiday!", "good")
	var kids := npcs.filter(func(n): return n.kind == "pupil")
	kids.shuffle()
	for i in 3:
		var k: Chara = kids[i]
		later(i * 0.6, func(): say(k, ["Hooray!", "Half-holiday!", "Yesss!"][i], 2.5))
	for cr in crests:
		cr["lit"] = false
		cr["n"].texture = load("res://art/crest_off.svg")
	later(2.5, func(): _start_period(DAY_PLAN.size() - 1))


# ================================================================= juice
func _burst(pos: Vector2, col: Color, amount: int) -> void:
	var p := CPUParticles2D.new()
	p.texture = load("res://art/spark.svg")
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.9
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 380.0
	p.gravity = Vector2(0, 520)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(col.r, col.g, col.b, 0))
	p.color_ramp = g
	p.color = col
	fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.6).timeout.connect(p.queue_free)


var shake := 0.0


func _shake(amount: float) -> void:
	shake = maxf(shake, amount)


# ================================================================= loop
func _unhandled_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	match ev.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if mode == "title" or mode == "over":
				_start_game()
		KEY_P, KEY_ESCAPE:
			if mode == "play" or mode == "pause":
				_toggle_pause()
		KEY_M:
			muted = not muted
			log_msg("Sound off." if muted else "Sound on.")
		KEY_S:
			if mode == "play" and player.state != "down" and player.state != "stairs":
				if player.state == "sit" or player.state == "floor":
					player.state = "idle"
				else:
					_player_sit()
		KEY_X, KEY_Z:
			if mode == "play":
				_punch()
		KEY_F, KEY_SPACE:
			if mode == "play":
				_fire()
		KEY_E:
			if mode == "play":
				_try_rope()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mode == "play":
		_toggle_pause()


func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	# sky & clouds (always alive)
	var camx := cam.get_screen_center_position().x
	for cl in clouds:
		var x: float = fposmod(cl["base"] + Time.get_ticks_msec() / 1000.0 * cl["v"] - camx * 0.25, 2600.0) - 340.0
		cl["n"].position = Vector2(x, cl["y"])
	var frac := 0.0
	if not period.is_empty():
		frac = (lerpf(CLOCK[period_idx], CLOCK[period_idx + 1], clampf(period_t / period["dur"], 0, 1)) - 540.0) / 390.0
	var top := Color("4f9be8").lerp(Color("5b7fd0"), frac).lerp(Color("4a4f9a"), clampf((frac - 0.85) * 6.0, 0, 1))
	var bot := Color("e6f4ff").lerp(Color("ffe2b8"), frac)
	sky_mat.set_shader_parameter("top_col", top)
	sky_mat.set_shader_parameter("bot_col", bot)
	if mode == "play":
		_tick(dt)
	for c in chars:
		c.animate(dt, gt)
	# camera follow + shake
	cam.position = Vector2(player.wx, VIEW_H / 2.0)
	if shake > 0.0:
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake) * 0.5)
		shake = maxf(0.0, shake - dt * 40.0)
	else:
		cam.offset = Vector2.ZERO


func _tick(dt: float) -> void:
	gt += dt
	period_t += dt
	var i := timers.size() - 1
	while i >= 0:
		if i < timers.size() and gt >= timers[i]["at"]:
			var tm = timers[i]
			timers.remove_at(i)
			tm["fn"].call()
			if mode != "play":
				return
		i -= 1
	if period_t >= period["dur"]:
		if period_idx >= DAY_PLAN.size() - 1:
			_new_day()
		else:
			_start_period(period_idx + 1)
	_player_update(dt)
	for c in npcs:
		c.moved = 0.0
		if c.state != "down" and c.state != "stairs":
			if c.kind == "pupil":
				_pupil_duty(c)
			else:
				_teacher_duty(c)
		_step_npc(c, dt)
	_pellets_update(dt)
	if mode != "play":
		return
	_lesson_update(dt)
	if mode != "play":
		return
	_floor_update()
	_teacher_chatter()
	if (period["type"] == "play" or period["type"] == "dinner") and gt > next_chat:
		next_chat = gt + randf_range(5, 9)
		var kids := npcs.filter(func(n): return n.kind == "pupil" and n.special == "" and n.state != "down")
		if kids.size() > 0:
			say(kids.pick_random(), CHAT.pick_random(), 2.4)
	for c in chars:
		_place_bubble(c)
	hud_t -= dt
	if hud_t <= 0.0:
		hud_t = 0.1
		_update_hud()
