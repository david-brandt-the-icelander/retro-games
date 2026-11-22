class_name Hex
extends RefCounted
## Pointy-top hex helpers using "odd-r" offset coordinates (Vector2i(col, row)).

const SQRT3 := 1.7320508075688772
const SIZE := 1.0

const _DIRS_EVEN := [Vector2i(1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const _DIRS_ODD := [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]

static func neighbors(c: Vector2i) -> Array:
	var dirs: Array = _DIRS_ODD if (c.y & 1) == 1 else _DIRS_EVEN
	var out := []
	for d in dirs:
		out.append(c + d)
	return out

static func to_cube(c: Vector2i) -> Vector3i:
	var q := c.x - (c.y - (c.y & 1)) / 2
	var r := c.y
	return Vector3i(q, r, -q - r)

static func distance(a: Vector2i, b: Vector2i) -> int:
	var ac := to_cube(a)
	var bc := to_cube(b)
	return (absi(ac.x - bc.x) + absi(ac.y - bc.y) + absi(ac.z - bc.z)) / 2

static func to_world(c: Vector2i) -> Vector3:
	var x := SIZE * SQRT3 * (c.x + 0.5 * float(c.y & 1))
	var z := SIZE * 1.5 * c.y
	return Vector3(x, 0.0, z)

static func from_world(p: Vector3) -> Vector2i:
	var q := (SQRT3 / 3.0 * p.x - p.z / 3.0) / SIZE
	var r := (2.0 / 3.0 * p.z) / SIZE
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var qi := int(rq)
	var ri := int(rr)
	return Vector2i(qi + (ri - (ri & 1)) / 2, ri)

## Corner i (0..5) of a hex around the origin, pointy-top.
static func corner(i: int, radius: float = SIZE) -> Vector3:
	var a := deg_to_rad(60.0 * i - 30.0)
	return Vector3(radius * cos(a), 0.0, radius * sin(a))

static func ring(center: Vector2i, radius: int) -> Array:
	## All hexes within radius (inclusive), unbounded.
	var out := []
	var cc := to_cube(center)
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			var q := cc.x + dq
			var r := cc.y + dr
			out.append(Vector2i(q + (r - (r & 1)) / 2, r))
	return out
