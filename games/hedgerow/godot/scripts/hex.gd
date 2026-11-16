class_name Hex
extends RefCounted
## Pointy-top axial hex math. World +X = east, -Z = north.

const SIZE := 1.0
const SQ3 := 1.7320508075688772
const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
	Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


static func to_world(h: Vector2i, y: float = 0.0) -> Vector3:
	return Vector3(SIZE * SQ3 * (h.x + h.y * 0.5), y, SIZE * 1.5 * h.y)


static func from_world(p: Vector3) -> Vector2i:
	var q: float = (SQ3 / 3.0 * p.x - 1.0 / 3.0 * p.z) / SIZE
	var r: float = (2.0 / 3.0 * p.z) / SIZE
	return axial_round(q, r)


static func axial_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rq: float = roundf(q)
	var rr: float = roundf(r)
	var rs: float = roundf(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d: Vector2i = a - b
	return int((absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2)


static func neighbors(h: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		out.append(h + d)
	return out


static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = distance(a, b)
	var out: Array[Vector2i] = []
	if n == 0:
		out.append(a)
		return out
	var aq: float = float(a.x) + 1e-6
	var ar: float = float(a.y) + 2e-6
	var bq: float = float(b.x) + 1e-6
	var br: float = float(b.y) + 2e-6
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		out.append(axial_round(lerpf(aq, bq, t), lerpf(ar, br, t)))
	return out


static func offset_to_axial(col: int, row: int) -> Vector2i:
	return Vector2i(col - int((row - (row & 1)) / 2), row)


static func axial_to_offset(h: Vector2i) -> Vector2i:
	return Vector2i(h.x + int((h.y - (h.y & 1)) / 2), h.y)


static func corner(i: int, radius: float = SIZE) -> Vector3:
	var a: float = deg_to_rad(60.0 * i - 30.0)
	return Vector3(cos(a) * radius, 0.0, sin(a) * radius)


static func dir_vector(i: int) -> Vector3:
	return to_world(DIRS[i]).normalized()


static func yaw_for(v: Vector3) -> float:
	return atan2(-v.x, -v.z)
