extends Node
## Global game state, input map and effect spawners (autoload "Game").

enum State { TITLE, PLAYING, DYING, GAME_OVER }

const ExplosionScript = preload("res://scripts/explosion.gd")
const PopupScript = preload("res://scripts/popup.gd")
const BulletScript = preload("res://scripts/bullet.gd")
const SAVE_PATH := "user://rampart.cfg"
## Difficulty climbs steadily from level 1 to RAMP_LEVELS and then holds at its peak.
const RAMP_LEVELS := 12
const LEVEL_TITLES := [
	"THE OUTER WATCH", "BREACH THE FORTRESS", "THE IRON MILE", "SILO FIELDS",
	"THE BLINKING WALLS", "INTERCEPTOR ALLEY", "THE NARROWS", "DEEP BASTION",
	"THE CROSSFIRE", "BLACK RAMPART", "THE LAST LINE", "THE WARDEN'S HOME",
]

var state: int = State.TITLE
var score: int = 0
var hi_score: int = 0
var lives: int = 3
var fuel: float = 100.0
var level: int = 1
var world: Node3D = null
var player = null
var boss = null
var shake_amount: float = 0.0
# Developer flags (command line: -- --autoplay [--goto=N] [--shots=DIR])
var autopilot: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	_load()


func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_add_action("move_right", [KEY_D, KEY_RIGHT], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_add_action("climb", [KEY_W, KEY_UP], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_add_action("descend", [KEY_S, KEY_DOWN], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_add_action("fire", [KEY_SPACE, KEY_J, KEY_CTRL], [JOY_BUTTON_A, JOY_BUTTON_RIGHT_SHOULDER], -1, 0.0)
	_add_action("start", [KEY_ENTER, KEY_KP_ENTER], [JOY_BUTTON_START], -1, 0.0)
	_add_action("pause", [KEY_ESCAPE, KEY_P], [JOY_BUTTON_BACK], -1, 0.0)


func _add_action(action: String, keys: Array, buttons: Array, axis: int, axis_dir: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in buttons:
		var jb := InputEventJoypadButton.new()
		jb.button_index = b
		InputMap.action_add_event(action, jb)
	if axis >= 0:
		var ja := InputEventJoypadMotion.new()
		ja.axis = axis
		ja.axis_value = axis_dir
		InputMap.action_add_event(action, ja)


func new_game() -> void:
	score = 0
	lives = 3
	fuel = 100.0
	level = 1


## Interpolates from the easy value at level 1 to the hard value at RAMP_LEVELS and beyond.
func ramp(lvl: int, easy: float, hard: float) -> float:
	var k := clampf(float(lvl - 1) / float(RAMP_LEVELS - 1), 0.0, 1.0)
	return lerpf(easy, hard, k)


func level_title(lvl: int) -> String:
	if lvl <= LEVEL_TITLES.size():
		return LEVEL_TITLES[lvl - 1]
	return "THE ENDLESS SIEGE"


func add_score(p: int) -> void:
	score += p
	if score > hi_score:
		hi_score = score


func add_fuel(f: float) -> void:
	fuel = minf(100.0, fuel + f)


func save_hi() -> void:
	var cf := ConfigFile.new()
	cf.set_value("score", "hi", hi_score)
	cf.save(SAVE_PATH)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE_PATH) == OK:
		hi_score = int(cf.get_value("score", "hi", 0))


func shake(a: float) -> void:
	shake_amount = maxf(shake_amount, a)


func spawn_explosion(pos: Vector3, size: float = 1.0, color: Color = Color(1.0, 0.55, 0.2)) -> void:
	if world == null:
		return
	var e = ExplosionScript.new()
	e.size = size
	e.color = color
	e.position = pos
	world.add_child(e)
	shake(0.12 * size)


func spawn_spark(pos: Vector3, color: Color = Color(0.6, 0.95, 1.0)) -> void:
	if world == null:
		return
	var e = ExplosionScript.new()
	e.size = 0.35
	e.color = color
	e.spark_only = true
	e.position = pos
	world.add_child(e)


func spawn_shot(pos: Vector3, vel: Vector3, color: Color = Color(1.0, 0.45, 0.15), big: bool = false) -> void:
	if world == null:
		return
	var b = BulletScript.new()
	b.hostile = true
	b.velocity = vel
	b.color = color
	b.big = big
	b.life = 4.0
	b.position = pos
	world.add_child(b)


func popup(pos: Vector3, text: String, color: Color = Color(1.0, 0.85, 0.4)) -> void:
	if world == null:
		return
	var p = PopupScript.new()
	p.text = text
	p.modulate = color
	p.position = pos
	world.add_child(p)
