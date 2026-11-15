class_name Town
## Marshfield street grid and every place on it (top-down, world pixels).

const W := 2600.0
const H := 1900.0
const ROADS_X := [250.0, 950.0, 1650.0, 2350.0]
const ROADS_Y := [250.0, 950.0, 1650.0]
const RW := 40.0      # road half-width (two 40px lanes)
const SW := 16.0      # sidewalk width
const STREETS_X := ["Oak Ave", "Central Ave", "Chestnut Ave", "Peach Ave"]
const STREETS_Y := ["Veterans Pkwy", "Main St", "Cheese Curd Ln"]

# Slot -> place. Slot key: "c<col>r<row><t|b><l|r>"; row 0/3 are the north/south strips.
const PLACES := {
	"c0r1tl": ["shop", "JIM'S FIX-IT SHACK"],
	"c0r1tr": ["gas", "GAS-N-GRUB"],
	"c1r1tl": ["hardware", "HUB CITY HARDWARE"],
	"c1r1tr": ["bank", "FIRST DAIRYLAND BANK"],
	"c2r1tr": ["police", "MARSHFIELD POLICE"],
	"c2r1bl": ["tavern", "THE RUSTY MUSKIE"],
	"c1r2bl": ["plumbing", "PLUMB BOB'S"],
	"c1r2br": ["electric", "SPARKY'S ELECTRIC"],
	"c0r2bl": ["lumber", "NORTHWOODS LUMBER"],
	"c2r2br": ["farm", "BADGER FARM & FEED"],
	"c1r1bl": ["park", "PARK"],
	"c0r0br": ["park", "PARK"],
	"c2r3tl": ["park", "PARK"],
}

const HOUSE_COLORS := [
	[Pal.LBLUE, Pal.RED], [Pal.YELLOW, Pal.BROWN], [Pal.LGRAY, Pal.BLUE],
	[Pal.LCYAN, Pal.DGRAY], [Pal.WHITE, Pal.GREEN], [Pal.LRED, Pal.DGRAY],
	[Pal.LGREEN, Pal.BROWN], [Pal.LMAGENTA, Pal.BLUE],
]

static var _places: Array = []

## Every slot as a dictionary: id, kind, name, rect, lot, facing (+1 lot is below / -1 above).
static func places() -> Array:
	if not _places.is_empty():
		return _places
	var house_n := 0
	for col in 3:
		var x0: float = ROADS_X[col] + RW + SW
		for row in 4:
			var sides := []
			if row == 0:
				sides = ["b"]
			elif row == 3:
				sides = ["t"]
			else:
				sides = ["t", "b"]
			for side in sides:
				for lr in ["l", "r"]:
					var key := "c%dr%d%s%s" % [col, row, side, lr]
					var bx := x0 + (50.0 if lr == "l" else 318.0)
					var bh := 140.0 if (row == 1 or row == 2) else 110.0
					var lot_h := 70.0 if (row == 1 or row == 2) else 60.0
					var rect: Rect2
					var lot: Rect2
					if side == "t":
						var y0: float = ROADS_Y[row - 1] + RW + SW
						lot = Rect2(bx, y0, 220, lot_h)
						rect = Rect2(bx, y0 + lot_h, 220, bh)
					else:
						var y1: float = ROADS_Y[row] - RW - SW
						lot = Rect2(bx, y1 - lot_h, 220, lot_h)
						rect = Rect2(bx, y1 - lot_h - bh, 220, bh)
					var p := {"id": key, "kind": "house", "name": "", "rect": rect, "lot": lot,
						"street": STREETS_Y[row - 1] if side == "t" else STREETS_Y[row], "side": side}
					if PLACES.has(key):
						p.kind = PLACES[key][0]
						p.name = PLACES[key][1]
						if p.kind != "house" and p.kind != "park":
							p.id = p.kind
					else:
						var hc: Array = HOUSE_COLORS[house_n % HOUSE_COLORS.size()]
						p["wall"] = hc[0]
						p["roof"] = hc[1]
						p["number"] = 100 + house_n * 12 + (7 if lr == "r" else 3)
						house_n += 1
					_places.append(p)
	return _places

static func place(id: String) -> Dictionary:
	for p in places():
		if p.id == id:
			return p
	return {}

static func house_ids() -> Array:
	var out := []
	for p in places():
		if p.kind == "house":
			out.append(p.id)
	return out

static func on_road(p: Vector2) -> bool:
	for rx in ROADS_X:
		if absf(p.x - rx) < RW and p.y > ROADS_Y[0] - RW and p.y < ROADS_Y[-1] + RW:
			return true
	for ry in ROADS_Y:
		if absf(p.y - ry) < RW and p.x > ROADS_X[0] - RW and p.x < ROADS_X[-1] + RW:
			return true
	return false

## Traffic light state for intersection (i, j) along an axis ("EW" or "NS"): "G","Y","R".
static func light(i: int, j: int, axis: String, t: float) -> String:
	var cyc := fmod(t + float(i * 5 + j * 3) * 1.7, 16.0)
	var ew := "G" if cyc < 6.0 else ("Y" if cyc < 8.0 else "R")
	var ns := "R" if cyc < 8.0 else ("G" if cyc < 14.0 else "Y")
	return ew if axis == "EW" else ns
