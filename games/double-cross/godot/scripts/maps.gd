extends Node
## Map catalogue + deterministic layout generator.
## Every peer calls generate(map_id, seed) and gets an identical layout,
## so only the seed travels over the network.

const ROOM_SIZE := 10.0
const DOOR_WIDTH := 1.8

# Layout legend:  '#' room   'E' room with the exit door   '.' empty
const DEFS := {
	"safehouse": {
		"name": "The Safehouse",
		"blurb": "Cosy townhouse. Tight corners, short fuses.",
		"max_players": 2,
		"layout": ["##E", "###"],
		"theme": "safehouse",
	},
	"embassy": {
		"name": "The Embassy",
		"blurb": "Marble halls and diplomatic immunity (not really).",
		"max_players": 4,
		"layout": ["###", "###", "##E"],
		"theme": "embassy",
	},
	"hotel": {
		"name": "Grand Hotel Meridian",
		"blurb": "Five stars, fourteen rooms, zero trust.",
		"max_players": 6,
		"layout": ["#####", "##.##", "E####"],
		"theme": "hotel",
	},
	"arctic": {
		"name": "Polar Station Kappa",
		"blurb": "A research base at the end of the world.",
		"max_players": 8,
		"layout": [".####.", "######", "##..##", "######", ".##E#."],
		"theme": "arctic",
	},
}

const THEMES := {
	"safehouse": {
		"floor": Color(0.45, 0.28, 0.16), "floor_grain": true, "floor_rough": 0.55,
		"wall": Color(0.82, 0.74, 0.62), "trim": Color(0.30, 0.20, 0.13),
		"light": Color(1.0, 0.80, 0.55), "light_energy": 2.2, "ambient": Color(0.35, 0.28, 0.22),
		"furniture": ["desk", "bookshelf", "sofa", "dresser", "cabinet", "plant", "safe"],
		"wood": Color(0.36, 0.22, 0.12), "fabric": Color(0.55, 0.20, 0.18),
		"rooms": ["Kitchen", "Study", "Parlour", "Pantry", "Den", "Hallway", "Library", "Bedroom"],
	},
	"embassy": {
		"floor": Color(0.86, 0.85, 0.82), "floor_grain": false, "floor_rough": 0.12,
		"wall": Color(0.16, 0.30, 0.25), "trim": Color(0.78, 0.66, 0.38),
		"light": Color(1.0, 0.95, 0.86), "light_energy": 2.0, "ambient": Color(0.25, 0.30, 0.28),
		"furniture": ["desk", "cabinet", "bookshelf", "sofa", "safe", "plant", "table"],
		"wood": Color(0.25, 0.14, 0.08), "fabric": Color(0.15, 0.22, 0.45),
		"rooms": ["Atrium", "Consulate", "Archive", "Cipher Room", "Ballroom", "Ambassador's Office", "Lounge", "Records", "Press Room"],
	},
	"hotel": {
		"floor": Color(0.42, 0.07, 0.09), "floor_grain": false, "floor_rough": 0.9,
		"wall": Color(0.88, 0.82, 0.70), "trim": Color(0.75, 0.58, 0.25),
		"light": Color(1.0, 0.84, 0.60), "light_energy": 2.3, "ambient": Color(0.30, 0.22, 0.20),
		"furniture": ["dresser", "sofa", "table", "plant", "cabinet", "luggage", "desk"],
		"wood": Color(0.30, 0.17, 0.10), "fabric": Color(0.70, 0.55, 0.25),
		"rooms": ["Lobby", "Suite 101", "Suite 102", "Bar", "Laundry", "Kitchen", "Suite 201", "Suite 202", "Spa", "Concierge", "Ballroom", "Vault", "Gym", "Penthouse"],
	},
	"arctic": {
		"floor": Color(0.32, 0.35, 0.38), "floor_grain": false, "floor_rough": 0.35, "floor_metal": 0.7,
		"wall": Color(0.80, 0.86, 0.90), "trim": Color(0.95, 0.45, 0.10),
		"light": Color(0.70, 0.85, 1.0), "light_energy": 2.4, "ambient": Color(0.18, 0.24, 0.32),
		"furniture": ["locker", "crate", "cabinet", "desk", "server", "table", "safe"],
		"wood": Color(0.45, 0.48, 0.52), "fabric": Color(0.20, 0.45, 0.70),
		"rooms": ["Airlock", "Lab A", "Lab B", "Comms", "Generator", "Mess", "Bunks", "Medbay", "Core Sample Vault", "Garage", "Observatory", "Greenhouse", "Server Room", "Storage", "Cryo", "Briefing"],
	},
}

const OBJECTIVES := ["dossier", "keycard", "passport", "cash"]
const TOOLS := ["defuser", "gasmask", "cutters", "gloves"]

# trap -> {where, counter tool, damage}
const TRAPS := {
	"mine":     {"label": "Proximity Mine", "where": "furniture", "counter": "defuser", "damage": 65, "color": Color(1.0, 0.45, 0.1)},
	"gas":      {"label": "Nerve Gas",      "where": "furniture", "counter": "gasmask", "damage": 40, "color": Color(0.4, 1.0, 0.35)},
	"tripwire": {"label": "Tripwire Charge", "where": "door",     "counter": "cutters", "damage": 55, "color": Color(1.0, 0.2, 0.25)},
	"shock":    {"label": "Shock Plate",    "where": "door",      "counter": "gloves",  "damage": 30, "color": Color(0.35, 0.7, 1.0)},
}
const TRAP_ORDER := ["mine", "gas", "tripwire", "shock"]

const ITEM_LABELS := {
	"dossier": "Dossier", "keycard": "Keycard", "passport": "Passport", "cash": "Cash",
	"defuser": "Defuse Kit", "gasmask": "Gas Mask", "cutters": "Wire Cutters", "gloves": "Rubber Gloves",
}
const ITEM_COLORS := {
	"dossier": Color(0.95, 0.85, 0.35), "keycard": Color(0.35, 0.9, 1.0),
	"passport": Color(0.55, 0.45, 1.0), "cash": Color(0.4, 1.0, 0.5),
	"defuser": Color(1.0, 0.55, 0.2), "gasmask": Color(0.45, 1.0, 0.4),
	"cutters": Color(1.0, 0.3, 0.35), "gloves": Color(0.4, 0.75, 1.0),
}

const PLAYER_COLORS := [
	Color(0.10, 0.85, 0.95), Color(1.00, 0.25, 0.65), Color(1.00, 0.72, 0.15), Color(0.45, 1.00, 0.35),
	Color(0.65, 0.45, 1.00), Color(1.00, 0.40, 0.25), Color(0.95, 0.95, 0.95), Color(0.20, 0.55, 1.00),
]
const TEAM_COLORS := [Color(0.10, 0.85, 0.95), Color(1.00, 0.25, 0.65)]
const TEAM_NAMES := ["Team Cyan", "Team Magenta"]


func ids() -> Array:
	return ["safehouse", "embassy", "hotel", "arctic"]


func generate(map_id: String, seed_value: int) -> Dictionary:
	var def: Dictionary = DEFS[map_id]
	var theme: Dictionary = THEMES[def.theme]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var rooms: Array = []
	var cell_to_room := {}
	var exit_room := -1
	var rows: Array = def.layout
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch == ".":
				continue
			var idx := rooms.size()
			var c := Vector2i(x, y)
			cell_to_room[c] = idx
			rooms.append({
				"cell": c,
				"center": Vector3(x * ROOM_SIZE, 0, y * ROOM_SIZE),
				"name": "",
			})
			if ch == "E":
				exit_room = idx

	# Room names (shuffled deterministically)
	var names: Array = theme.rooms.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = names[i]; names[i] = names[j]; names[j] = t
	for i in rooms.size():
		rooms[i].name = names[i % names.size()] if i < names.size() else "Sector %d" % (i + 1)
	if exit_room >= 0:
		rooms[exit_room].name = "Exit Hall"

	# Doors: randomised spanning tree + extra loops
	var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var edges := {}  # "a_b" -> true
	var visited := {0: true}
	var stack := [0]
	while not stack.is_empty():
		var cur: int = stack.back()
		var cands := []
		for d in dirs:
			var nc: Vector2i = rooms[cur].cell + d
			if cell_to_room.has(nc) and not visited.has(cell_to_room[nc]):
				cands.append(cell_to_room[nc])
		if cands.is_empty():
			stack.pop_back()
			continue
		var nxt: int = cands[rng.randi_range(0, cands.size() - 1)]
		visited[nxt] = true
		edges[_edge_key(cur, nxt)] = true
		stack.append(nxt)
	for i in rooms.size():
		for d in [Vector2i(1, 0), Vector2i(0, 1)]:
			var nc: Vector2i = rooms[i].cell + d
			if cell_to_room.has(nc) and rng.randf() < 0.4:
				edges[_edge_key(i, cell_to_room[nc])] = true

	var doors: Array = []
	for k in edges.keys():
		var parts: PackedStringArray = k.split("_")
		var a := int(parts[0]); var b := int(parts[1])
		var pa: Vector3 = rooms[a].center; var pb: Vector3 = rooms[b].center
		doors.append({
			"pos": (pa + pb) * 0.5,
			"axis": "x" if absf(pa.x - pb.x) > 0.1 else "z",  # axis you walk along
			"rooms": [a, b],
		})
	doors.sort_custom(func(p, q): return p.pos.x * 1000 + p.pos.z < q.pos.x * 1000 + q.pos.z)

	# Exit: an outer wall of the exit room
	var exit := {}
	if exit_room >= 0:
		for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			if not cell_to_room.has(rooms[exit_room].cell + d):
				var n := Vector3(d.x, 0, d.y)
				exit = {"room": exit_room, "normal": n,
					"pos": rooms[exit_room].center + n * (ROOM_SIZE * 0.5)}
				break

	# Furniture along walls, never blocking doorways
	var half := ROOM_SIZE * 0.5
	var slots := [
		[Vector3(-2.8, 0, -half + 1.0), 0.0], [Vector3(2.8, 0, -half + 1.0), 0.0],
		[Vector3(-2.8, 0, half - 1.0), PI], [Vector3(2.8, 0, half - 1.0), PI],
		[Vector3(-half + 1.0, 0, -2.8), PI * 0.5], [Vector3(-half + 1.0, 0, 2.8), PI * 0.5],
		[Vector3(half - 1.0, 0, -2.8), -PI * 0.5], [Vector3(half - 1.0, 0, 2.8), -PI * 0.5],
	]
	var furniture: Array = []
	var types: Array = theme.furniture
	for r in rooms.size():
		var order := range(slots.size())
		for i in range(order.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = order[i]; order[i] = order[j]; order[j] = t
		var count := rng.randi_range(3, 5)
		for s in count:
			var slot: Array = slots[order[s]]
			var ftype: String = types[rng.randi_range(0, types.size() - 1)]
			if ftype == "table":
				ftype = "cabinet"  # tables go in the middle, see below
			furniture.append({
				"type": ftype, "room": r,
				"pos": rooms[r].center + slot[0], "rot": slot[1],
			})
		if types.has("table") and rng.randf() < 0.45 and r != exit_room:
			furniture.append({"type": "table", "room": r,
				"pos": rooms[r].center + Vector3(rng.randf_range(-0.8, 0.8), 0, rng.randf_range(-0.8, 0.8)),
				"rot": rng.randf_range(-0.3, 0.3)})

	# Spawn points: room centres, spread out
	var spawns: Array = []
	for r in rooms.size():
		if r != exit_room:
			spawns.append(rooms[r].center + Vector3(0, 0, 1.2))
	for i in range(spawns.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = spawns[i]; spawns[i] = spawns[j]; spawns[j] = t

	return {
		"id": map_id, "def": def, "theme": theme,
		"rooms": rooms, "cell_to_room": cell_to_room,
		"doors": doors, "furniture": furniture, "exit": exit,
		"spawns": spawns, "exit_room": exit_room,
	}


func room_at(layout: Dictionary, pos: Vector3) -> int:
	var c := Vector2i(roundi(pos.x / ROOM_SIZE), roundi(pos.z / ROOM_SIZE))
	return layout.cell_to_room.get(c, -1)


func _edge_key(a: int, b: int) -> String:
	return "%d_%d" % [mini(a, b), maxi(a, b)]
