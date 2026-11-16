extends Node
## Global game state (autoload "Game"): definitions, economy, spatial queries, victory.

signal notified(text: String)
signal game_ended(winner: int)

const PLAYER := 0
const ENEMY := 1
const CELL := 8.0
const MAP_HALF := 118.0
const BUILD_RADIUS := 30.0
const AIR_ALTITUDE := 14.0

const TEAM_COLORS := [Color(0.80, 0.53, 0.17), Color(0.62, 0.11, 0.09)]
const TEAM_UI_COLORS := [Color(1.0, 0.80, 0.35), Color(1.0, 0.32, 0.26)]
const TEAM_NAMES := ["Brass Coalition", "Iron Dominion"]

const UNITS := {
	"constructor": {"name": "Constructor", "cost": 80, "hp": 260, "speed": 6.5, "radius": 1.4,
		"armor": "vehicle", "time": 6.0, "bar_h": 3.2,
		"desc": "Steam crane truck. Builds and repairs structures."},
	"trooper": {"name": "Gasmask Troopers", "cost": 60, "hp": 140, "speed": 4.4, "radius": 1.2,
		"armor": "infantry", "time": 4.5, "bar_h": 2.8,
		"weapon": "rifle", "range": 12.0, "damage": 10.0, "rate": 0.9, "hits_air": true,
		"desc": "Cheap rifle squad. Can fire on airships."},
	"tank": {"name": "Ironclad Tank", "cost": 200, "hp": 520, "speed": 6.8, "radius": 1.8,
		"armor": "vehicle", "time": 9.0, "bar_h": 3.4,
		"weapon": "cannon", "range": 16.0, "damage": 60.0, "rate": 2.2,
		"desc": "Riveted battle tank with a rotating turret. Strong against vehicles."},
	"howitzer": {"name": "Thunderer Howitzer", "cost": 260, "hp": 260, "speed": 4.6, "radius": 1.9,
		"armor": "vehicle", "time": 11.0, "bar_h": 3.6,
		"weapon": "artillery", "range": 32.0, "min_range": 8.0, "damage": 75.0, "splash": 4.5, "rate": 4.6,
		"desc": "Long-range siege gun. Must halt to fire. Devastating against structures."},
	"zeppelin": {"name": "Stormcloud Zeppelin", "cost": 360, "hp": 700, "speed": 4.8, "radius": 3.0,
		"armor": "air", "time": 15.0, "bar_h": 3.4, "air": true,
		"weapon": "bombs", "range": 4.5, "damage": 110.0, "splash": 5.5, "rate": 3.2,
		"desc": "Armored bomber airship. Only rifles and flak can hit it."},
}

const BUILDINGS := {
	"hq": {"name": "Command Bunker", "cost": 0, "hp": 2600, "size": 9.0, "time": 1.0, "income": 3.0,
		"bar_h": 14.0, "produces": ["constructor"],
		"desc": "Headquarters. Produces Constructors and trickles fuel."},
	"derrick": {"name": "Pump Jack", "cost": 150, "hp": 520, "size": 3.8, "time": 9.0, "income": 7.0,
		"bar_h": 5.5, "desc": "Pumps crude from an oil well: +7 fuel/s. Must sit on a well."},
	"barracks": {"name": "Barracks", "cost": 160, "hp": 850, "size": 6.5, "time": 12.0,
		"bar_h": 5.0, "produces": ["trooper"], "desc": "Trains Gasmask Troopers."},
	"factory": {"name": "War Factory", "cost": 320, "hp": 1400, "size": 9.0, "time": 18.0,
		"bar_h": 9.0, "produces": ["tank", "howitzer"],
		"desc": "Assembles Ironclad Tanks and Thunderer Howitzers."},
	"dock": {"name": "Airship Mast", "cost": 380, "hp": 950, "size": 7.0, "time": 18.0,
		"bar_h": 17.0, "produces": ["zeppelin"], "desc": "Moors and launches Stormcloud Zeppelins."},
	"flak": {"name": "Flak Tower", "cost": 200, "hp": 800, "size": 3.8, "time": 10.0,
		"bar_h": 7.5, "weapon": "flak", "range": 22.0, "damage": 24.0, "rate": 0.8, "splash": 2.5,
		"hits_air": true, "desc": "Quad-barrel defence tower. Shreds airships, harasses ground units."},
}

const BUILD_MENU := ["derrick", "barracks", "factory", "dock", "flak"]

## Weapon effectiveness against armor classes.
const DAMAGE := {
	"rifle": {"infantry": 1.0, "vehicle": 0.2, "building": 0.15, "air": 0.5},
	"cannon": {"infantry": 0.6, "vehicle": 1.0, "building": 0.7, "air": 0.0},
	"artillery": {"infantry": 0.9, "vehicle": 0.8, "building": 1.5, "air": 0.0},
	"bombs": {"infantry": 1.0, "vehicle": 1.0, "building": 1.3, "air": 0.0},
	"flak": {"infantry": 0.5, "vehicle": 0.3, "building": 0.2, "air": 1.4},
}

var fuel: Array = [600.0, 600.0]
var entities: Array = []
var world: Node3D = null
var wells: Array = []
var obstacles: Array = []
var obstacle_grid := {}
var grid := {}
var game_over := false
var winner := -1
var elapsed := 0.0
var last_place_error := ""
## True on the Compatibility renderer (the web build): no volumetric fog, SSAO or decals there.
var compat := false
var _victory_t := 1.0


func reset() -> void:
	fuel = [600.0, 600.0]
	entities = []
	wells = []
	obstacles = []
	obstacle_grid = {}
	grid = {}
	game_over = false
	winner = -1
	elapsed = 0.0
	_victory_t = 1.0


func alive(e) -> bool:
	return is_instance_valid(e) and not e.dead


func register(e) -> void:
	entities.append(e)


func unregister(e) -> void:
	entities.erase(e)


func notify(text: String) -> void:
	notified.emit(text)


# ---------------------------------------------------------------- helpers

func ang_diff(a: float, b: float) -> float:
	return wrapf(b - a, -PI, PI)


func turn_toward(a: float, b: float, step: float) -> float:
	return a + clampf(ang_diff(a, b), -step, step)


## Buildings face the centre of the map, snapped to 45 degrees.
func facing_yaw(p: Vector3) -> float:
	return snappedf(atan2(p.x, p.z), PI / 4.0)


func can_hit(d: Dictionary, target) -> bool:
	if not d.has("weapon"):
		return false
	if target.is_air:
		return bool(d.get("hits_air", false))
	return true


func damage_mult(weapon: String, target) -> float:
	var table: Dictionary = DAMAGE[weapon]
	return float(table.get(target.armor_type(), 1.0))


func get_hq(team: int):
	for e in entities:
		if e.team == team and e.is_building and e.kind == "hq":
			return e
	return null


func income_of(team: int) -> float:
	var total := 0.0
	for e in entities:
		if e.team == team and e.is_building and e.complete:
			total += float(e.def.get("income", 0.0))
	return total


# ---------------------------------------------------------------- spatial

func _physics_process(_delta: float) -> void:
	grid.clear()
	for e in entities:
		var p: Vector3 = e.position
		var c := Vector2i(floori(p.x / CELL), floori(p.z / CELL))
		if not grid.has(c):
			grid[c] = []
		grid[c].append(e)


## Every live entity whose footprint touches the circle (pos, radius).
func query(pos: Vector3, radius: float) -> Array:
	var out := []
	var r := int(ceil((radius + 6.0) / CELL))
	var c := Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))
	for x in range(c.x - r, c.x + r + 1):
		for y in range(c.y - r, c.y + r + 1):
			var k := Vector2i(x, y)
			if not grid.has(k):
				continue
			for e in grid[k]:
				if not is_instance_valid(e) or e.dead:
					continue
				var ep: Vector3 = e.position
				var rr: float = radius + float(e.radius)
				if Vector2(ep.x - pos.x, ep.z - pos.z).length_squared() <= rr * rr:
					out.append(e)
	return out


func add_obstacle(pos: Vector3, r: float) -> void:
	var o := {"pos": Vector2(pos.x, pos.z), "r": r}
	obstacles.append(o)
	var c := Vector2i(floori(pos.x / 16.0), floori(pos.z / 16.0))
	if not obstacle_grid.has(c):
		obstacle_grid[c] = []
	obstacle_grid[c].append(o)


func obstacles_near(pos: Vector3) -> Array:
	var out := []
	var c := Vector2i(floori(pos.x / 16.0), floori(pos.z / 16.0))
	for x in range(c.x - 1, c.x + 2):
		for y in range(c.y - 1, c.y + 2):
			var k := Vector2i(x, y)
			if obstacle_grid.has(k):
				out.append_array(obstacle_grid[k])
	return out


# ---------------------------------------------------------------- economy / building

func free_well_near(pos: Vector3, r: float):
	var best = null
	var best_d := r
	for w in wells:
		if alive(w["owner"]):
			continue
		var wp: Vector3 = w["pos"]
		var d := Vector2(wp.x - pos.x, wp.z - pos.z).length()
		if d < best_d:
			best_d = d
			best = w
	return best


## Returns the snapped placement position, or null if the spot is invalid
## (the reason is left in last_place_error).
func placement_pos(team: int, kind: String, pos: Vector3):
	var d: Dictionary = BUILDINGS[kind]
	var size: float = d["size"]
	var p := pos
	if kind == "derrick":
		var w = free_well_near(pos, 5.0)
		if w == null:
			last_place_error = "Pump Jacks must be placed on a free oil well"
			return null
		p = w["pos"]
	if absf(p.x) > MAP_HALF - size or absf(p.z) > MAP_HALF - size:
		last_place_error = "Too close to the edge of the map"
		return null
	var near_own := false
	for e in entities:
		if not e.is_building:
			continue
		var ep: Vector3 = e.position
		var dist := Vector2(ep.x - p.x, ep.z - p.z).length()
		var min_d: float = (float(e.def["size"]) + size) * 0.5 + 0.8
		if dist < min_d:
			last_place_error = "Blocked by another structure"
			return null
		if e.team == team and dist < BUILD_RADIUS + float(e.def["size"]) * 0.5:
			near_own = true
	if not near_own:
		last_place_error = "Too far from your structures"
		return null
	if kind != "derrick":
		for w in wells:
			var wp: Vector3 = w["pos"]
			if Vector2(wp.x - p.x, wp.z - p.z).length() < size * 0.5 + 2.5:
				last_place_error = "Oil wells are reserved for Pump Jacks"
				return null
	for o in obstacles_near(p):
		var op: Vector2 = o["pos"]
		if op.distance_to(Vector2(p.x, p.z)) < float(o["r"]) + size * 0.5:
			last_place_error = "Terrain is obstructed"
			return null
	var h0: float = world.height_at(p.x, p.z)
	var half := size * 0.5
	for off in [Vector2(-half, -half), Vector2(half, -half), Vector2(-half, half), Vector2(half, half)]:
		if absf(world.height_at(p.x + off.x, p.z + off.y) - h0) > 2.2:
			last_place_error = "Ground is too steep"
			return null
	p.y = h0
	last_place_error = ""
	return p


func place_building(team: int, kind: String, pos: Vector3):
	var cost: int = BUILDINGS[kind]["cost"]
	if fuel[team] < cost:
		return null
	fuel[team] -= cost
	var b = world.spawn_building(kind, team, pos, false)
	if kind == "derrick":
		var w = free_well_near(pos, 1.5)
		if w != null:
			w["owner"] = b
			b.well = w
	return b


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if world == null or game_over:
		return
	elapsed += delta
	for e in entities:
		if e.is_building and e.complete:
			var inc: float = e.def.get("income", 0.0)
			if inc > 0.0:
				fuel[e.team] += inc * delta
	_victory_t -= delta
	if _victory_t <= 0.0:
		_victory_t = 1.0
		_check_victory()


func _check_victory() -> void:
	var counts := [0, 0]
	for e in entities:
		if e.is_building:
			counts[e.team] += 1
	if counts[PLAYER] == 0:
		_end(ENEMY)
	elif counts[ENEMY] == 0:
		_end(PLAYER)


func _end(w: int) -> void:
	if game_over:
		return
	game_over = true
	winner = w
	game_ended.emit(w)
