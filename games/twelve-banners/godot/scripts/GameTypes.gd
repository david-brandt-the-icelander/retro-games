class_name GameTypes
extends RefCounted
## Plain data containers for game state.

class Unit:
	extends RefCounted
	var id: int
	var type: String
	var owner: int
	var pos: Vector2i
	var hp: int = 100
	var moves: int = 0
	var fortified := false
	var sleeping := false
	var skip := false
	var veteran := false
	var attacked := false
	var acted := false        ## moved or attacked this turn (no heal)
	var build_kind := ""
	var build_left := 0
	var goto := Vector2i(-1, -1)

	func def() -> Dictionary:
		return Defs.UNITS[type]

	func is_civilian() -> bool:
		return Defs.UNITS[type]["class"] == "civilian"

	func max_moves() -> int:
		return Defs.UNITS[type].moves

	func sight() -> int:
		return Defs.UNITS[type].get("sight", 2)

	func is_ranged() -> bool:
		return Defs.UNITS[type].rstr > 0

	func needs_orders() -> bool:
		return moves > 0 and not fortified and not sleeping and not skip and build_kind == "" and goto.x < 0


class City:
	extends RefCounted
	var id: int
	var name: String
	var owner: int
	var pos: Vector2i
	var pop: int = 1
	var food: int = 0
	var prod: int = 0
	var production := ""
	var buildings: Array = []
	var hp: int = 200
	var capital := false
	var founder: int = -1
	var bombarded := false

	func max_hp() -> int:
		var h := 200
		for b in buildings:
			h += Defs.BUILDINGS[b].get("hp", 0)
		return h

	func growth_threshold() -> int:
		var p := pop - 1
		return 15 + 6 * p + p * p


class Player:
	extends RefCounted
	var id: int
	var name: String
	var civ: int
	var color: Color
	var peer_id: int = 0     ## 0 = AI controlled
	var human := false       ## slot originally belonged to a human
	var gold: int = 0
	var science: int = 0
	var techs: Dictionary = {"agriculture": true}
	var research := ""
	var alive := true
	var ready := false
	var ever_had_city := false
	var city_name_index := 0

	func is_ai() -> bool:
		return peer_id == 0

	func civ_name() -> String:
		return Defs.CIVS[civ].name
