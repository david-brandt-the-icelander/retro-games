extends RefCounted
## Shared world constants and helpers (screen wraps horizontally).

const WIDTH := 1280.0
const HEIGHT := 720.0
const GROUND_Y := 660.0
const CEILING_Y := 64.0
const PAD_X := 860.0
const SEG_H := 54.0
const ROCKET_BASE_Y := 654.0
const FUEL_NEEDED := 6

const PLATFORMS := [
	Rect2(110, 280, 250, 22),
	Rect2(530, 420, 170, 22),
	Rect2(940, 210, 230, 22),
]
const GROUND := Rect2(-4000, 660, 9280, 400)


static func solids() -> Array:
	return PLATFORMS + [GROUND]


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
