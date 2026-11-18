extends RefCounted
## Shared world constants and helpers (screen wraps horizontally).

const WIDTH := 1280.0
const HEIGHT := 720.0
const GROUND_Y := 660.0
const CEILING_Y := 64.0
const SEG_H := 54.0
const ROCKET_BASE_Y := 654.0
const FUEL_NEEDED := 6

## One layout per level, cycling: where the rocket stands (pad_x), where the astronaut starts,
## the floating platforms, and which two platforms hold the rocket's loose parts.
const LAYOUTS := [
	{"name": "Ledges", "pad_x": 860.0, "start_x": 300.0, "parts": [0, 2], "platforms": [
		Rect2(110, 280, 250, 22), Rect2(530, 420, 170, 22), Rect2(940, 210, 230, 22)]},
	{"name": "Staircase", "pad_x": 170.0, "start_x": 640.0, "parts": [1, 2], "platforms": [
		Rect2(430, 520, 150, 22), Rect2(700, 360, 150, 22), Rect2(980, 200, 200, 22)]},
	{"name": "Twin Shelves", "pad_x": 640.0, "start_x": 200.0, "parts": [0, 1], "platforms": [
		Rect2(70, 330, 260, 22), Rect2(950, 330, 260, 22), Rect2(330, 170, 170, 22), Rect2(780, 170, 170, 22)]},
	{"name": "Descent", "pad_x": 1120.0, "start_x": 100.0, "parts": [0, 3], "platforms": [
		Rect2(80, 200, 200, 22), Rect2(340, 330, 200, 22), Rect2(600, 460, 200, 22), Rect2(860, 560, 150, 22)]},
	{"name": "Long Ridge", "pad_x": 400.0, "start_x": 900.0, "parts": [0, 3], "platforms": [
		Rect2(700, 250, 500, 22), Rect2(60, 430, 200, 22), Rect2(760, 470, 140, 22), Rect2(1020, 470, 140, 22)]},
	{"name": "Islands", "pad_x": 960.0, "start_x": 560.0, "parts": [0, 4], "platforms": [
		Rect2(60, 220, 130, 22), Rect2(260, 380, 130, 22), Rect2(470, 230, 130, 22), Rect2(660, 420, 130, 22),
		Rect2(1100, 330, 130, 22)]},
	{"name": "Edge of the World", "pad_x": 90.0, "start_x": 640.0, "parts": [0, 2], "platforms": [
		Rect2(300, 300, 360, 22), Rect2(760, 430, 200, 22), Rect2(1000, 220, 240, 22)]},
	{"name": "Far Shore", "pad_x": 1200.0, "start_x": 320.0, "parts": [0, 3], "platforms": [
		Rect2(100, 230, 240, 22), Rect2(450, 350, 150, 22), Rect2(700, 470, 150, 22), Rect2(900, 260, 170, 22)]},
	{"name": "Canopy", "pad_x": 1130.0, "start_x": 250.0, "parts": [0, 1], "platforms": [
		Rect2(100, 170, 330, 22), Rect2(560, 170, 330, 22), Rect2(600, 520, 240, 22)]},
	{"name": "Pillars", "pad_x": 520.0, "start_x": 900.0, "parts": [0, 4], "platforms": [
		Rect2(110, 450, 110, 22), Rect2(250, 330, 110, 22), Rect2(750, 450, 110, 22), Rect2(890, 330, 110, 22),
		Rect2(1030, 210, 110, 22), Rect2(640, 190, 110, 22)]},
	{"name": "Crossroads", "pad_x": 760.0, "start_x": 150.0, "parts": [1, 3], "platforms": [
		Rect2(60, 480, 200, 22), Rect2(300, 340, 360, 22), Rect2(870, 420, 200, 22), Rect2(1000, 230, 230, 22)]},
]

static var layout_i := 0


## Switch to the layout for a level (1-based); the layouts repeat after the last one.
static func use_level(level: int) -> void:
	layout_i = posmod(level - 1, LAYOUTS.size())


static func layout() -> Dictionary:
	return LAYOUTS[layout_i]


static func platforms() -> Array:
	return layout()["platforms"]


static func pad_x() -> float:
	return layout()["pad_x"]


static func start_x() -> float:
	return layout()["start_x"]


## The platforms that carry the rocket's two loose parts, in part order.
static func part_spots() -> Array:
	var ps: Array = platforms()
	var idx: Array = layout()["parts"]
	return [ps[idx[0]], ps[idx[1]]]


## Problems with the layouts, as text; empty when every layout is playable and no two are alike.
static func check_layouts() -> Array:
	var bad := []
	var seen := {}
	for i in LAYOUTS.size():
		var l: Dictionary = LAYOUTS[i]
		var px: float = l["pad_x"]
		var key := "%s|%s" % [px, l["platforms"]]
		if seen.has(key) or seen.has("p%s" % px):
			bad.append("%s repeats a pad position or layout" % l["name"])
		seen[key] = true
		seen["p%s" % px] = true
		if absf(wrap_dx(px, l["start_x"])) < 200.0:
			bad.append("%s starts the astronaut next to the rocket" % l["name"])
		for r in l["platforms"]:
			if r.position.x < 0.0 or r.end.x > WIDTH or r.position.y < CEILING_Y + 60.0 or r.end.y > GROUND_Y - 60.0:
				bad.append("%s has a platform off the screen or too close to the ground" % l["name"])
			if r.end.x > px - 70.0 and r.position.x < px + 70.0:
				bad.append("%s has a platform within 70px of the rocket's column" % l["name"])
		for k in l["parts"]:
			if k >= l["platforms"].size():
				bad.append("%s names a part platform that does not exist" % l["name"])
	return bad
const GROUND := Rect2(-4000, 660, 9280, 400)


static func solids() -> Array:
	return platforms() + [GROUND]


static func wrap_x(x: float) -> float:
	return fposmod(x, WIDTH)


## Shortest signed horizontal distance from `from` to `to` on the wrapping screen.
static func wrap_dx(from: float, to: float) -> float:
	return fposmod(to - from + WIDTH * 0.5, WIDTH) - WIDTH * 0.5


static func overlap(a: Rect2, b: Rect2) -> bool:
	for o in [-WIDTH, 0.0, WIDTH]:
		if a.intersects(Rect2(b.position + Vector2(o, 0), b.size)):
			return true
	return false


static func hits_solid(r: Rect2) -> bool:
	for s in solids():
		if r.intersects(s):
			return true
	return false


## Extra x offsets at which to redraw something sitting near a screen edge.
static func edge_offsets(x: float, margin: float = 48.0) -> Array:
	var offs := [0.0]
	if x > WIDTH - margin:
		offs.append(-WIDTH)
	if x < margin:
		offs.append(WIDTH)
	return offs
