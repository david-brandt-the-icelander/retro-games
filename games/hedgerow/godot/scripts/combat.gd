class_name Combat
extends RefCounted
## Combat rules. Infantry Fire Table (IFT-style): firepower + modifiers + 2d6.
##   total >= 16 : casualty (step loss) + morale check
##   total 13-15 : morale check (fail = broken, pass = pinned)
##   total 11-12 : pinned
## Anti-tank fire: to-hit roll 2d6 <= TN, then penetration vs armor facing.

const CAS := 16
const MC := 13
const PIN := 11
const LE := [0, 0, 1, 3, 6, 10, 15, 21, 26, 30, 33, 35, 36]


static func p_le(n: int) -> float:
	## P(2d6 <= n)
	if n < 2:
		return 0.0
	if n >= 12:
		return 1.0
	return float(LE[n]) / 36.0


static func p_ge(n: int) -> float:
	## P(2d6 >= n)
	return 1.0 - p_le(n - 1)


static func is_rocket(a: Unit) -> bool:
	return int(a.d["at_rng"]) <= 4 and a.has_at()


static func can_attack(a: Unit, t: Unit, from_hex: Vector2i, map: GameMap) -> String:
	if a.status == "broken":
		return "Broken units cannot fire"
	var dist: int = Hex.distance(from_hex, t.hex)
	if t.is_vehicle():
		if not a.has_at():
			return "No anti-tank weapon"
		if dist > int(a.d["at_rng"]):
			return "Out of anti-tank range (%d)" % int(a.d["at_rng"])
	else:
		if dist > int(a.d["rng"]):
			return "Out of range (%d)" % int(a.d["rng"])
	if not map.los(from_hex, t.hex):
		return "No line of sight"
	return ""


static func morale_of(t: Unit, map: GameMap) -> int:
	var m: int = int(t.d["morale"])
	if map.tem(t.hex) >= 1:
		m += 1
	return m


static func soft_base(a: Unit, t: Unit, from_hex: Vector2i, moved: bool, map: GameMap, t_moving_open: bool) -> int:
	var dist: int = Hex.distance(from_hex, t.hex)
	var b: int = a.fp()
	if dist * 2 > int(a.d["rng"]):
		b -= 1
	var k: String = String(a.d["kind"])
	if (k == "vehicle" or k == "gun") and map.ttype(t.hex) == GameMap.BUILDING:
		b += 2  # HE shells against buildings
	if dist <= 1:
		b += 2
	b -= map.tem(t.hex)
	if moved:
		b -= 2
	if a.status == "pinned":
		b -= 2
	if t_moving_open:
		b += 2
	if map.elev(from_hex) > map.elev(t.hex):
		b += 1
	b += mini(t.hits_taken, 3)
	return b


static func soft_odds(base: int) -> Dictionary:
	var cas: float = p_ge(CAS - base)
	var mc: float = p_ge(MC - base) - cas
	var pin: float = p_ge(PIN - base) - p_ge(MC - base)
	return {"cas": cas, "mc": mc, "pin": pin}


static func at_tn(a: Unit, t: Unit, from_hex: Vector2i, moved: bool, map: GameMap) -> int:
	var dist: int = Hex.distance(from_hex, t.hex)
	var tn: int
	if is_rocket(a):
		tn = 9 - dist
	else:
		tn = 10 - int(dist / 3)
	if map.tem(t.hex) >= 1:
		tn -= 1
	if moved:
		tn -= 2
	if a.status == "pinned":
		tn -= 1
	tn += mini(t.hits_taken, 2)
	return tn


static func pen_eff(a: Unit, dist: int) -> float:
	var p: float = float(a.d["at_pen"])
	if is_rocket(a):
		return p
	return p * (1.0 - 0.018 * dist)


static func aspect(t: Unit, from_hex: Vector2i) -> String:
	var v: Vector3 = Hex.to_world(from_hex) - Hex.to_world(t.hex)
	v.y = 0
	if v.length() < 0.01:
		return "front"
	var ang: float = t.facing_vector().angle_to(v.normalized())
	if ang <= deg_to_rad(65.0):
		return "front"
	if ang >= deg_to_rad(130.0):
		return "rear"
	return "side"


static func armor_vs(t: Unit, from_hex: Vector2i) -> int:
	match aspect(t, from_hex):
		"front":
			return int(t.d["armor_f"])
		"rear":
			return int(int(t.d["armor_s"]) * 0.8)
	return int(t.d["armor_s"])


static func p_pen(pen: float, armor: float) -> float:
	## Penetration roll: pen × U(0.85, 1.15) >= armor
	if armor <= 0.0:
		return 1.0
	return clampf((1.15 - armor / pen) / 0.3, 0.0, 1.0)


static func ev(a: Unit, t: Unit, from_hex: Vector2i, moved: bool, map: GameMap, t_moving: bool) -> float:
	if t.is_vehicle():
		var dist: int = Hex.distance(from_hex, t.hex)
		var ph: float = p_le(at_tn(a, t, from_hex, moved, map))
		var pk: float = p_pen(pen_eff(a, dist), float(armor_vs(t, from_hex)))
		return t.value() * ph * (pk + (1.0 - pk) * 0.05)
	var base: int = soft_base(a, t, from_hex, moved, map, t_moving)
	var o: Dictionary = soft_odds(base)
	var pfail: float = 1.0 - p_le(morale_of(t, map))
	if t.status == "broken":
		return t.value() * (o["cas"] + o["mc"] * pfail * 0.9 + o["pin"] * 0.02)
	return t.value() * (o["cas"] * 1.0 + o["mc"] * (pfail * 0.55 + (1.0 - pfail) * 0.15) + o["pin"] * 0.12)
