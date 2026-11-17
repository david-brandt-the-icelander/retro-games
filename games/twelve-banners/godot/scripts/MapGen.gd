class_name MapGen
extends RefCounted
## Procedural continent generator. Runs on the host only; the resulting map is
## sent to every client so all peers share exactly the same world.

static func generate(w: int, h: int, seed_value: int, slots: Array) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var elev_noise := FastNoiseLite.new()
	elev_noise.seed = seed_value
	elev_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	elev_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	elev_noise.fractal_octaves = 5
	elev_noise.frequency = 2.6 / float(maxi(w, h))
	var moist_noise := FastNoiseLite.new()
	moist_noise.seed = seed_value + 101
	moist_noise.frequency = 4.0 / float(maxi(w, h))
	moist_noise.fractal_octaves = 3
	var detail := FastNoiseLite.new()
	detail.seed = seed_value + 202
	detail.frequency = 0.18

	var n := w * h
	var elev := PackedFloat32Array()
	elev.resize(n)
	var values := []
	for y in h:
		for x in w:
			var p := Hex.to_world(Vector2i(x, y))
			var e := elev_noise.get_noise_2d(p.x, p.z)
			# Push edges down so continents sit inside the map.
			var nx := float(x) / (w - 1) * 2.0 - 1.0
			var ny := float(y) / (h - 1) * 2.0 - 1.0
			var edge := maxf(absf(nx) * 0.9, absf(ny))
			e -= pow(maxf(0.0, edge - 0.55), 1.6) * 1.6
			e += detail.get_noise_2d(p.x, p.z) * 0.08
			elev[y * w + x] = e
			values.append(e)
	values.sort()
	var sea: float = values[int(values.size() * 0.56)]       # ~44% land
	var mountain: float = values[int(values.size() * 0.965)]
	var hill: float = values[int(values.size() * 0.86)]

	var terrain := PackedByteArray()
	terrain.resize(n)
	var hills := PackedByteArray()
	hills.resize(n)
	var forest := PackedByteArray()
	forest.resize(n)
	var resource := []
	resource.resize(n)
	resource.fill("")

	for y in h:
		var lat := absf(float(y) / (h - 1) * 2.0 - 1.0)   # 0 equator, 1 pole
		for x in w:
			var i := y * w + x
			var e := elev[i]
			var p := Hex.to_world(Vector2i(x, y))
			var m := moist_noise.get_noise_2d(p.x, p.z) * 0.5 + 0.5
			var temp := 1.0 - lat + (detail.get_noise_2d(p.x + 50, p.z) * 0.15)
			if e < sea:
				terrain[i] = Defs.OCEAN
				continue
			if e > mountain:
				terrain[i] = Defs.MOUNTAIN
				continue
			if temp < 0.12:
				terrain[i] = Defs.SNOW
			elif temp < 0.26:
				terrain[i] = Defs.TUNDRA
			elif temp > 0.62 and m < 0.38:
				terrain[i] = Defs.DESERT
			elif m > 0.5:
				terrain[i] = Defs.GRASS
			else:
				terrain[i] = Defs.PLAINS
			if e > hill:
				hills[i] = 1
			var forest_chance := 0.0
			if terrain[i] in [Defs.GRASS, Defs.PLAINS, Defs.TUNDRA]:
				forest_chance = clampf((m - 0.45) * 1.6, 0.0, 0.7)
			if rng.randf() < forest_chance:
				forest[i] = 1

	# Coast = ocean next to land.
	var game_probe := func(c: Vector2i) -> bool: return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h
	for y in h:
		for x in w:
			var i := y * w + x
			if terrain[i] != Defs.OCEAN:
				continue
			for nb in Hex.neighbors(Vector2i(x, y)):
				if game_probe.call(nb) and terrain[nb.y * w + nb.x] > Defs.COAST:
					terrain[i] = Defs.COAST
					break

	# Resources
	for i in n:
		var t := terrain[i]
		var r := rng.randf()
		if t == Defs.COAST and r < 0.10:
			resource[i] = "fish"
		elif t == Defs.MOUNTAIN:
			continue
		elif hills[i] == 1 and r < 0.18:
			resource[i] = ["iron", "gold", "gems"][rng.randi() % 3]
		elif forest[i] == 0 and t in [Defs.GRASS, Defs.PLAINS] and r < 0.11:
			resource[i] = ["wheat", "cattle", "horses"][rng.randi() % 3]
		elif t == Defs.DESERT and r < 0.08:
			resource[i] = ["gold", "spices"][rng.randi() % 2]
		elif t == Defs.GRASS and forest[i] == 1 and r < 0.08:
			resource[i] = "spices"
		elif t == Defs.TUNDRA and r < 0.06:
			resource[i] = "iron"

	# Start positions: good land, spread apart (greedy max-min distance).
	var cands := []
	for y in range(2, h - 2):
		for x in range(2, w - 2):
			var i := y * w + x
			var t := terrain[i]
			if not (t in [Defs.GRASS, Defs.PLAINS]):
				continue
			var s := 0.0
			var land := 0
			for c in Hex.ring(Vector2i(x, y), 2):
				if not game_probe.call(c):
					continue
				var j: int = c.y * w + c.x
				var tt := terrain[j]
				if tt == Defs.GRASS: s += 2.0
				elif tt == Defs.PLAINS: s += 1.8
				elif tt == Defs.COAST: s += 0.8
				elif tt == Defs.OCEAN: s += 0.3
				elif tt == Defs.DESERT or tt == Defs.SNOW: s -= 0.5
				if hills[j] == 1: s += 0.6
				if resource[j] != "": s += 1.0
				if tt > Defs.COAST and tt != Defs.MOUNTAIN:
					land += 1
			if land >= 12:
				cands.append({"pos": Vector2i(x, y), "s": s})
	cands.sort_custom(func(a, b): return a.s > b.s)
	cands = cands.slice(0, maxi(slots.size() * 30, 60))
	var starts := []
	var chosen := []
	if not cands.is_empty():
		chosen.append(cands[rng.randi() % mini(10, cands.size())].pos)
	while chosen.size() < slots.size() and not cands.is_empty():
		var best_c = null
		var best_v := -1.0
		for c in cands:
			var md := 9999
			for o in chosen:
				md = mini(md, Hex.distance(c.pos, o))
			var v: float = md * 10.0 + c.s
			if md > 0 and v > best_v:
				best_v = v
				best_c = c.pos
		if best_c == null:
			break
		chosen.append(best_c)
	# Fallback: any land
	while chosen.size() < slots.size():
		var tries := 0
		while tries < 10000:
			tries += 1
			var c := Vector2i(rng.randi() % w, rng.randi() % h)
			var t := terrain[c.y * w + c.x]
			if t > Defs.COAST and t != Defs.MOUNTAIN and not chosen.has(c):
				chosen.append(c)
				break
		if tries >= 10000:
			break
	for i in slots.size():
		starts.append({"p": i, "pos": chosen[i]})
	# Make start tiles nice: no forest on the start tile.
	for s in starts:
		forest[s.pos.y * w + s.pos.x] = 0
		hills[s.pos.y * w + s.pos.x] = 0

	return {"w": w, "h": h, "terrain": terrain, "hills": hills, "forest": forest,
		"resource": resource, "players": slots, "starts": starts}
