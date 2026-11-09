extends RefCounted
## Every word the presentation shows, in one table (docs/DESIGN.md § In-game UI, Build). Names
## and labels are the GDD's (§ 4); messages and notices are written to RULES D.9's purposes and
## the GDD § 9 budgets, in UI-DESIGN's voice. GDD data the sim already holds (goods, equipment,
## systems, economies, governments, Reaches) comes from the bridge instead.
##
## Use it with `const Words = preload("res://src/presentation/text/words.gd")`.

const TITLE := "LODESTAR"
const STRAPLINE := "Trade, fight and scrape a living across eight Reaches."
const FOOTER := "An independent remake"
## GDD § 1: the owner fills in the placeholders before release.
const CREDIT := "Inspired by <Title> (<year>) by <Author>, published by <Publisher>. Independent remake, not affiliated with or endorsed by the original rights holders."
const ABOUT := "A remake that plays like a 1984 classic: its rules and numbers, with our own galaxy, goods, names, words and art."

const MENU_CONTINUE := "Continue"
const MENU_LOAD := "Load pilot"
const MENU_ABOUT := "About"
const MENU_QUIT := "Quit"
const PROMPT_NAME := "Pilot name"
const LOAD_EMPTY := "No saved pilots yet."
const LOAD_ERRORS := {
	"not_found": "No pilot saved under that name.",
	"rejected": "That record is damaged; nothing was loaded.",
	"not_title": "Loading works only on the title.",
}
const SAVE_RESULTS := {
	"saved": "Saved.",
	"not_docked": "Saving works only while berthed.",
	"no_name": "Type a name to save under.",
}

## Timed in-flight messages (RULES D.9.1, GDD § 9.1), by the bridge's id. `%s` takes the data.
const MESSAGES := {
	"scoop_fuel": "SKIMMING FUEL",
	"energy_low": "ENERGY LOW",
	"kill_milestone": "THAT'S A LONG TALLY!",
	"missile_in": "DART INBOUND",
	"missile_jammed": "NO ROOM TO LAUNCH",
	"target_lost": "LOCK LOST",
	"reach_jump": "LEAVING THE REACH",
	"bounty": "%s SC",
	"scooped": "%s",
	"cargo_lost": "%s LOST",
	"equipment_lost": "%s LOST",
}
## The messages that hold longer and tint Danger (UI-DESIGN § Components, Ticker).
const URGENT := ["energy_low", "missile_in"]

const NOTE_JUMP_TARGET := "JUMPING TO %s"
const NOTE_OUT_OF_RANGE := "OUT OF RANGE"
const NOTE_DOCKED := "NOT WHILE BERTHED"
const NOTE_DEATH := "SIGNAL LOST"
const NOTE_NO_HOP := "HOP REFUSED"
const NOTE_HOP := "HOP"
const NOTE_REACH_JUMP := "REACH DRIVE ENGAGED"

const MOUNT_TAGS := ["FWD", "AFT", "PORT", "STBD"]
const RANKS := ["Unblooded", "Blooded", "Scrapper", "Brawler", "Gunhand", "Sharpshooter", "Veteran", "Ace", "Living legend"]
const LEGAL := ["Good standing", "On notice", "Outlawed"]
const CONDITIONS := ["Berthed", "Quiet", "Contact", "Danger"]
## GDD § 4.6, by type number 1..13.
const SHIPS := ["", "Stoat", "Mastiff", "Jackal", "Cheetah", "Grey Wolf", "Hush carrier", "Grey Wolf", "Spindle station", "Dart", "Asteroid", "Cargo crate", "Hush mote", "Lifeboat"]

const TABS := ["MARKET", "EQUIP", "GALAXY", "LOCAL", "SYSTEM", "PILOT", "HOLD"]
const LAUNCH := "LAUNCH"
const TRADE_REFUSED := {"too_many": "Not that many", "no_room": "Hold full", "no_cash": "No funds"}
const EQUIP_REFUSED := {"no_cash": "No funds", "at_limit": "%s already fitted", "no_mount": "Choose a mount", "not_offered": "Not sold here"}
const MISSILES_FULL := "Darts at maximum"
const PROMPT_MOUNT := "Which mount?"
const CASH_LEFT := "Cash left %s SC"
const EQUIP_BOUGHT := "%s bought"

## GDD § 9.4 `ui.equip_effect`, by item 0..11 (60 characters at most).
const EQUIP_EFFECTS := [
	"Fills the tank to 7.0 light years.",
	"A seeking missile. Carry up to four.",
	"Raises the hold from 22 to 37 tonnes.",
	"Destroys every Dart in flight nearby, for a moment.",
	"A pulsed laser for one mount.",
	"A continuous beam laser for one mount.",
	"Skims fuel from a star; scoops crates from below.",
	"Ejects you to safety. The ship and cargo are lost.",
	"One blast that destroys every ship nearby.",
	"Doubles the rate your energy recharges.",
	"Docks you at once from inside the safe zone.",
	"One jump to the next Reach, used up as it goes.",
]

## GDD § 9.4 `ui.epitaph`, by the bridge's death cause.
const EPITAPHS := {
	"crashed": "Met the planet head on.",
	"burned": "Flew too close to the star.",
	"docking": "Missed the Spindle's slot at speed.",
	"damage": "Hull breached under fire.",
	"escape_in_the_deep": "A lifeboat in the Deep goes nowhere.",
}

const DATA_LABELS := {
	"distance": "Distance", "economy": "Economy", "government": "Government", "tech": "Tech level",
	"population": "Population", "inhabitants": "Inhabitants", "productivity": "Productivity", "radius": "Radius",
}

const PAUSE_TITLE := "PAUSED"
const PAUSE_ITEMS := ["Resume", "Auto-centre", "Damping", "Quit to title"]
const PAUSE_CONFIRM := "Quit to title? Anything since your last save is lost. [Y] yes  [N] no"

const KEY_HINTS := "[1-4] MOUNT  [Q] TARGET  [E] FIRE DART"


## A timed message's words, in capitals.
static func message(id: String, detail: String) -> String:
	if not MESSAGES.has(id):
		return ""
	var template: String = MESSAGES[id]
	if id == "bounty":
		return template % cash(int(detail))
	if template.contains("%s"):
		return (template % detail).to_upper()
	return template


## Tenths of a scrip as `1,240.5`.
static func cash(tenths: int) -> String:
	var whole := thousands(tenths / 10)
	return "%s.%d" % [whole, absi(tenths) % 10]


static func thousands(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if n < 0 else "") + digits + out


## Tenths (of a light year, of a billion) as `7.0`.
static func tenths(n: int) -> String:
	return "%d.%d" % [n / 10, n % 10]


## A name in word case: `HALDRA` → `Haldra` (RULES D.10).
static func word_case(name: String) -> String:
	var out := ""
	var start := true
	for c in name:
		if c >= "A" and c <= "Z" or c >= "a" and c <= "z":
			out += c.to_upper() if start else c.to_lower()
			start = false
		else:
			out += c
			start = true
	return out


## The two-line system description, composed only from the data (GDD § 9.4 `ui.system_blurb`).
static func system_blurb(s: Dictionary) -> String:
	var line1 := "%s under %s, tech level %d." % [s["economy_label"], String(s["government_label"]).to_lower(), s["tech_level"]]
	var line2 := "Home to %s %s." % [tenths(s["population"]), "billion " + String(s["inhabitants"]).to_lower()]
	return line1 + "\n" + line2
