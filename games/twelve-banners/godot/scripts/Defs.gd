class_name Defs
extends RefCounted
## Static game data: terrain, units, buildings, technologies, civilizations.

const MAX_PLAYERS := 12

enum { OCEAN, COAST, GRASS, PLAINS, DESERT, TUNDRA, SNOW, MOUNTAIN }

const TERRAIN := [
	{"name": "Ocean",    "food": 1, "prod": 0, "gold": 1, "color": Color("1d4f7c"), "height": -0.55, "water": true},
	{"name": "Coast",    "food": 1, "prod": 0, "gold": 1, "color": Color("2f8fa8"), "height": -0.20, "water": true},
	{"name": "Grassland","food": 2, "prod": 0, "gold": 0, "color": Color("6fae47"), "height": 0.12, "water": false},
	{"name": "Plains",   "food": 1, "prod": 1, "gold": 0, "color": Color("b9ad5a"), "height": 0.12, "water": false},
	{"name": "Desert",   "food": 0, "prod": 0, "gold": 0, "color": Color("e3cb8f"), "height": 0.10, "water": false},
	{"name": "Tundra",   "food": 1, "prod": 0, "gold": 0, "color": Color("8c9a86"), "height": 0.12, "water": false},
	{"name": "Snow",     "food": 0, "prod": 0, "gold": 0, "color": Color("e9eef3"), "height": 0.14, "water": false},
	{"name": "Mountain", "food": 0, "prod": 0, "gold": 0, "color": Color("77706a"), "height": 0.22, "water": false},
]

const SAND_COLOR := Color("dccb94")

## Resources: bonus yields and a display colour for the crystal marker.
const RESOURCES := {
	"wheat":  {"name": "Wheat",  "food": 1, "prod": 0, "gold": 0, "color": Color("f2d14b")},
	"cattle": {"name": "Cattle", "food": 1, "prod": 0, "gold": 0, "color": Color("c98b5a")},
	"fish":   {"name": "Fish",   "food": 2, "prod": 0, "gold": 0, "color": Color("7fd6ff")},
	"horses": {"name": "Horses", "food": 0, "prod": 1, "gold": 0, "color": Color("a0703c")},
	"iron":   {"name": "Iron",   "food": 0, "prod": 2, "gold": 0, "color": Color("9aa7b8")},
	"gems":   {"name": "Gems",   "food": 0, "prod": 0, "gold": 3, "color": Color("e05cff")},
	"gold":   {"name": "Gold Ore","food": 0, "prod": 0, "gold": 2, "color": Color("ffcf33")},
	"spices": {"name": "Spices", "food": 1, "prod": 0, "gold": 2, "color": Color("ff7a3d")},
}

const IMPROVEMENTS := {
	"farm": {"name": "Farm", "food": 1, "prod": 0, "gold": 0, "turns": 3, "tech": ""},
	"mine": {"name": "Mine", "food": 0, "prod": 2, "gold": 0, "turns": 4, "tech": "mining"},
	"trading_post": {"name": "Trading Post", "food": 0, "prod": 0, "gold": 2, "turns": 3, "tech": "currency"},
}

## Unit classes: civilian, melee, ranged, mounted, siege, armor
const UNITS := {
	"settler":   {"name": "Settler",   "cost": 55,  "str": 0,  "rstr": 0,  "range": 0, "moves": 2, "tech": "",                 "class": "civilian", "model": "settler"},
	"worker":    {"name": "Worker",    "cost": 30,  "str": 0,  "rstr": 0,  "range": 0, "moves": 2, "tech": "",                 "class": "civilian", "model": "worker"},
	"scout":     {"name": "Scout",     "cost": 20,  "str": 4,  "rstr": 0,  "range": 0, "moves": 3, "tech": "",                 "class": "melee",    "model": "scout",  "sight": 3},
	"warrior":   {"name": "Warrior",   "cost": 25,  "str": 8,  "rstr": 0,  "range": 0, "moves": 2, "tech": "",                 "class": "melee",    "model": "club"},
	"archer":    {"name": "Archer",    "cost": 35,  "str": 5,  "rstr": 9,  "range": 2, "moves": 2, "tech": "archery",          "class": "ranged",   "model": "bow"},
	"spearman":  {"name": "Spearman",  "cost": 40,  "str": 12, "rstr": 0,  "range": 0, "moves": 2, "tech": "bronze_working",   "class": "melee",    "model": "spear", "anti_mounted": true},
	"horseman":  {"name": "Horseman",  "cost": 45,  "str": 12, "rstr": 0,  "range": 0, "moves": 4, "tech": "horseback_riding", "class": "mounted",  "model": "horse"},
	"swordsman": {"name": "Swordsman", "cost": 55,  "str": 15, "rstr": 0,  "range": 0, "moves": 2, "tech": "iron_working",     "class": "melee",    "model": "sword"},
	"catapult":  {"name": "Catapult",  "cost": 60,  "str": 6,  "rstr": 15, "range": 2, "moves": 2, "tech": "mathematics",      "class": "siege",    "model": "catapult"},
	"knight":    {"name": "Knight",    "cost": 80,  "str": 20, "rstr": 0,  "range": 0, "moves": 4, "tech": "chivalry",         "class": "mounted",  "model": "knight"},
	"crossbowman":{"name": "Crossbowman","cost": 75,"str": 9,  "rstr": 16, "range": 2, "moves": 2, "tech": "machinery",        "class": "ranged",   "model": "crossbow"},
	"musketman": {"name": "Musketman", "cost": 100, "str": 24, "rstr": 0,  "range": 0, "moves": 2, "tech": "gunpowder",        "class": "melee",    "model": "musket"},
	"cannon":    {"name": "Cannon",    "cost": 110, "str": 10, "rstr": 26, "range": 2, "moves": 2, "tech": "metallurgy",       "class": "siege",    "model": "cannon"},
	"rifleman":  {"name": "Rifleman",  "cost": 150, "str": 34, "rstr": 0,  "range": 0, "moves": 2, "tech": "rifling",          "class": "melee",    "model": "rifle"},
	"artillery": {"name": "Artillery", "cost": 190, "str": 18, "rstr": 40, "range": 3, "moves": 2, "tech": "dynamite",         "class": "siege",    "model": "artillery"},
	"tank":      {"name": "Tank",      "cost": 260, "str": 60, "rstr": 0,  "range": 0, "moves": 5, "tech": "combustion",       "class": "armor",    "model": "tank"},
}

const BUILDINGS := {
	"granary":      {"name": "Granary",       "cost": 40,  "tech": "pottery",          "food": 2, "prod": 0, "gold": 0, "sci": 0,  "desc": "+2 Food"},
	"library":      {"name": "Library",       "cost": 55,  "tech": "writing",          "food": 0, "prod": 0, "gold": 0, "sci": 3,  "desc": "+3 Science"},
	"walls":        {"name": "Walls",         "cost": 50,  "tech": "masonry",          "food": 0, "prod": 0, "gold": 0, "sci": 0,  "desc": "+6 City Strength, +100 City HP", "defense": 6, "hp": 100},
	"barracks":     {"name": "Barracks",      "cost": 45,  "tech": "bronze_working",   "food": 0, "prod": 0, "gold": 0, "sci": 0,  "desc": "New units are Veterans (+20% strength)"},
	"market":       {"name": "Market",        "cost": 70,  "tech": "currency",         "food": 0, "prod": 0, "gold": 3, "sci": 0,  "desc": "+3 Gold"},
	"workshop":     {"name": "Workshop",      "cost": 80,  "tech": "construction",     "food": 0, "prod": 3, "gold": 0, "sci": 0,  "desc": "+3 Production"},
	"university":   {"name": "University",    "cost": 120, "tech": "education",        "food": 0, "prod": 0, "gold": 0, "sci": 5,  "desc": "+5 Science"},
	"bank":         {"name": "Bank",          "cost": 140, "tech": "banking",          "food": 0, "prod": 0, "gold": 5, "sci": 0,  "desc": "+5 Gold"},
	"castle":       {"name": "Castle",        "cost": 120, "tech": "chivalry",         "food": 0, "prod": 0, "gold": 0, "sci": 0,  "desc": "+8 City Strength, +100 City HP", "defense": 8, "hp": 100, "requires": "walls"},
	"factory":      {"name": "Factory",       "cost": 200, "tech": "industrialization","food": 0, "prod": 8, "gold": 0, "sci": 0,  "desc": "+8 Production"},
	"hospital":     {"name": "Hospital",      "cost": 180, "tech": "electricity",      "food": 4, "prod": 0, "gold": 0, "sci": 0,  "desc": "+4 Food"},
	"research_lab": {"name": "Research Lab",  "cost": 250, "tech": "electricity",      "food": 0, "prod": 0, "gold": 0, "sci": 10, "desc": "+10 Science"},
}

## Projects: special production items.
const PROJECTS := {
	"wealth":  {"name": "Wealth",   "desc": "Converts production into gold"},
	"research":{"name": "Research", "desc": "Converts production into science"},
	"spaceship":{"name": "Spaceship","cost": 900, "tech": "space_flight", "desc": "Launch a colony ship. Win the game!"},
}

const TECHS := {
	"agriculture":      {"name": "Agriculture",      "cost": 0,    "pre": [],                                   "col": 0, "row": 2},
	"pottery":          {"name": "Pottery",          "cost": 20,   "pre": ["agriculture"],                      "col": 1, "row": 0},
	"animal_husbandry": {"name": "Animal Husbandry", "cost": 25,   "pre": ["agriculture"],                      "col": 1, "row": 1},
	"archery":          {"name": "Archery",          "cost": 25,   "pre": ["agriculture"],                      "col": 1, "row": 3},
	"mining":           {"name": "Mining",           "cost": 20,   "pre": ["agriculture"],                      "col": 1, "row": 4},
	"writing":          {"name": "Writing",          "cost": 45,   "pre": ["pottery"],                          "col": 2, "row": 0},
	"horseback_riding": {"name": "Horseback Riding", "cost": 50,   "pre": ["animal_husbandry"],                 "col": 2, "row": 1},
	"bronze_working":   {"name": "Bronze Working",   "cost": 50,   "pre": ["mining"],                           "col": 2, "row": 3},
	"masonry":          {"name": "Masonry",          "cost": 45,   "pre": ["mining"],                           "col": 2, "row": 4},
	"mathematics":      {"name": "Mathematics",      "cost": 85,   "pre": ["writing"],                          "col": 3, "row": 0},
	"currency":         {"name": "Currency",         "cost": 85,   "pre": ["writing", "bronze_working"],        "col": 3, "row": 2},
	"iron_working":     {"name": "Iron Working",     "cost": 90,   "pre": ["bronze_working"],                   "col": 3, "row": 3},
	"philosophy":       {"name": "Philosophy",       "cost": 130,  "pre": ["mathematics"],                      "col": 4, "row": 0},
	"chivalry":         {"name": "Chivalry",         "cost": 150,  "pre": ["horseback_riding", "iron_working"], "col": 4, "row": 2},
	"construction":     {"name": "Construction",     "cost": 130,  "pre": ["masonry", "mathematics"],           "col": 4, "row": 4},
	"education":        {"name": "Education",        "cost": 210,  "pre": ["philosophy"],                       "col": 5, "row": 0},
	"machinery":        {"name": "Machinery",        "cost": 210,  "pre": ["construction"],                     "col": 5, "row": 4},
	"banking":          {"name": "Banking",          "cost": 300,  "pre": ["currency", "education"],            "col": 6, "row": 1},
	"gunpowder":        {"name": "Gunpowder",        "cost": 320,  "pre": ["machinery", "chivalry"],            "col": 6, "row": 3},
	"metallurgy":       {"name": "Metallurgy",       "cost": 440,  "pre": ["gunpowder"],                        "col": 7, "row": 3},
	"industrialization":{"name": "Industrialization","cost": 470,  "pre": ["banking", "machinery"],             "col": 7, "row": 1},
	"rifling":          {"name": "Rifling",          "cost": 620,  "pre": ["metallurgy"],                       "col": 8, "row": 4},
	"dynamite":         {"name": "Dynamite",         "cost": 680,  "pre": ["metallurgy", "industrialization"],  "col": 8, "row": 2},
	"electricity":      {"name": "Electricity",      "cost": 700,  "pre": ["industrialization"],                "col": 8, "row": 0},
	"combustion":       {"name": "Combustion",       "cost": 950,  "pre": ["dynamite", "rifling"],              "col": 9, "row": 3},
	"space_flight":     {"name": "Space Flight",     "cost": 1300, "pre": ["combustion", "electricity"],        "col": 10, "row": 1},
}

const PLAYER_COLORS := [
	Color("e8483f"), Color("3f8cff"), Color("f5c542"), Color("41c77a"),
	Color("b25cf0"), Color("ff8a3d"), Color("2fd3d0"), Color("ff5fb2"),
	Color("f2f2f2"), Color("8bd13b"), Color("8a6a4a"), Color("5a5ae6"),
]

const CIVS := [
	{"name": "Aurelia",   "leader": "Cassia",    "cities": ["Aurum", "Velora", "Castra", "Lumen", "Ostra", "Nerva", "Solace", "Tiberra"]},
	{"name": "Norvik",    "leader": "Ragna",     "cities": ["Fjordheim", "Skarn", "Isvald", "Hrafn", "Kaldvik", "Tormund", "Ulvsund", "Brekka"]},
	{"name": "Qadira",    "leader": "Zahir",     "cities": ["Qadesh", "Sahrim", "Mirabad", "Tazrin", "Oasara", "Kemet", "Durhan", "Safra"]},
	{"name": "Yamato",    "leader": "Hikari",    "cities": ["Kirishima", "Aonami", "Tsukimura", "Hoshino", "Minato", "Sakaido", "Kazeoka", "Yukishi"]},
	{"name": "Tlalocan",  "leader": "Itzel",     "cities": ["Xochitlan", "Teoca", "Cuauhtla", "Mazatl", "Ollinpan", "Tecpan", "Atlico", "Yaotl"]},
	{"name": "Hellenis",  "leader": "Theron",    "cities": ["Argolis", "Delphion", "Korinthe", "Myrene", "Pelagon", "Thalassa", "Ithakos", "Lykeia"]},
	{"name": "Zhaoyan",   "leader": "Mei Lin",   "cities": ["Jinhai", "Longmen", "Baiyun", "Shanxu", "Qingdao", "Huangling", "Yuncheng", "Fenghe"]},
	{"name": "Kanem",     "leader": "Amani",     "cities": ["Njari", "Kossoba", "Timbara", "Wagadu", "Zanzo", "Malindi", "Tenkora", "Sahelo"]},
	{"name": "Avalon",    "leader": "Rowena",    "cities": ["Camelin", "Wyndmere", "Thornbury", "Glastow", "Ashford", "Brightwater", "Kestrel", "Mistvale"]},
	{"name": "Inkari",    "leader": "Pachac",    "cities": ["Cuzana", "Vilcas", "Machay", "Tambo", "Pisaq", "Ollanta", "Quilla", "Sacsa"]},
	{"name": "Rusvald",   "leader": "Yelena",    "cities": ["Novgrad", "Belozor", "Volkovo", "Zarech", "Kamensk", "Svetla", "Dubrava", "Ozersk"]},
	{"name": "Varuna",    "leader": "Devika",    "cities": ["Indrapura", "Suvarna", "Kashira", "Lankara", "Mithila", "Vasanta", "Ujjaya", "Chandri"]},
]

const MAP_SIZES := [
	{"name": "Small",    "w": 40, "h": 26},
	{"name": "Standard", "w": 54, "h": 34},
	{"name": "Large",    "w": 66, "h": 42},
	{"name": "Huge",     "w": 80, "h": 50},
]

static func tech_unlocks(tech_id: String) -> Array:
	var out := []
	for k in UNITS:
		if UNITS[k].tech == tech_id:
			out.append(UNITS[k].name)
	for k in BUILDINGS:
		if BUILDINGS[k].tech == tech_id:
			out.append(BUILDINGS[k].name)
	for k in IMPROVEMENTS:
		if IMPROVEMENTS[k].tech == tech_id:
			out.append(IMPROVEMENTS[k].name)
	if tech_id == "space_flight":
		out.append("Spaceship")
	return out

static func item_name(item: String) -> String:
	if UNITS.has(item):
		return UNITS[item].name
	if BUILDINGS.has(item):
		return BUILDINGS[item].name
	if PROJECTS.has(item):
		return PROJECTS[item].name
	return "Nothing"

static func item_cost(item: String) -> int:
	if UNITS.has(item):
		return UNITS[item].cost
	if BUILDINGS.has(item):
		return BUILDINGS[item].cost
	if PROJECTS.has(item) and PROJECTS[item].has("cost"):
		return PROJECTS[item].cost
	return 0

## "an Archer", "a Warrior", "Walls" (plural names take no article).
static func with_article(n: String) -> String:
	if n.ends_with("s"):
		return n
	return ("an " if "AEIOU".contains(n[0]) else "a ") + n
