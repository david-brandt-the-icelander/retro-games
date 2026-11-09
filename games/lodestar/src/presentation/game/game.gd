extends Node
## The game: the sim host, the 3D space scene, the HUD, the tunnels and the panels, and the keys
## that drive them (docs/DESIGN.md § Keyboard controls, the Modern layout; RULES D.4 and D.5).
##
## Held flight actions (dive, climb, roll, speed, fire) are sampled by SimHost at each tick from
## the input map. Every one-shot key arrives here and becomes a press for the next tick, sent
## where it means something in the present mode and screen: the title's menu, the docked hub,
## the flight actions and screen keys, or the pause panel. The camera keys are the camera's.
##
## `-- --script=<steps>` runs a scripted game (see script_runner.gd) for screenshots and the
## headless smoke test; `--shot=<png> --frames=<n>` saves one screenshot and quits.

const Space := preload("res://src/presentation/space/space.gd")
const Hud := preload("res://src/presentation/hud/hud.gd")
const Hub := preload("res://src/presentation/ui/hub.gd")
const Title := preload("res://src/presentation/ui/title.gd")
const PausePanel := preload("res://src/presentation/ui/pause_panel.gd")
const Tunnel := preload("res://src/presentation/ui/tunnel.gd")
const ScriptRunner := preload("res://src/presentation/game/script_runner.gd")
const Words := preload("res://src/presentation/text/words.gd")
const Look := preload("res://src/presentation/ui/look.gd")

## Flight actions queued for the next tick (RULES D.4.2), by input-map action.
const FLIGHT_PRESSES := {
	"arm_missile": "arm_missile", "fire_missile": "fire_missile", "unarm_missile": "unarm_missile",
	"ecm": "ecm", "area_blast": "area_blast", "in_system_jump": "in_system_jump", "auto_dock": "auto_dock",
}
const MOUNTS := ["mount_front", "mount_rear", "mount_left", "mount_right"]
## Seconds the escape pod key is held before the pod launches (docs/DESIGN.md).
const ESCAPE_HOLD := 1.0

@onready var sim: Node = $SimHost
var space: Node3D
var hud: Control
var hub: Control
var title: Control
var pause_panel: Control
var tunnel: Control
var runner: Node
var _escape_held := 0.0
var _escape_sent := false
var _shot_path := ""
var _shot_frames := 0


func _ready() -> void:
	space = Space.new()
	add_child(space)
	space.setup(sim)
	tunnel = _layer(0, Tunnel.new())
	hud = _layer(1, Hud.new())
	hud.space = space
	hub = _layer(2, Hub.new())
	title = _layer(2, Title.new())
	pause_panel = _layer(3, PausePanel.new())
	for control in [tunnel, hud, hub, title, pause_panel]:
		control.set("sim", sim)
	sim.sim_event.connect(_on_sim_event)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot_path = arg.trim_prefix("--shot=")
			_shot_frames = 150
		elif arg.begins_with("--frames="):
			_shot_frames = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--script="):
			runner = ScriptRunner.new()
			runner.game = self
			runner.steps = arg.trim_prefix("--script=")
			add_child(runner)


func _layer(order: int, control: Control) -> Control:
	var layer := CanvasLayer.new()
	layer.layer = order
	add_child(layer)
	layer.add_child(control)
	return control


func _process(delta: float) -> void:
	var mode: String = sim.mode()
	var screen: String = sim.screen()
	var flying := mode in ["flight", "dying", "escape"]
	space.camera.keys_enabled = flying and screen == "space" and not sim.paused()
	_hold_escape_pod(delta, mode)
	if _shot_path != "":
		_shot_frames -= 1
		if _shot_frames <= 0:
			get_viewport().get_texture().get_image().save_png(_shot_path)
			get_tree().quit()


## The escape pod needs its key held for a second (docs/DESIGN.md § Keyboard controls).
func _hold_escape_pod(delta: float, mode: String) -> void:
	if mode == "flight" and not sim.paused() and Input.is_action_pressed("escape_pod"):
		_escape_held += delta
		if _escape_held >= ESCAPE_HOLD and not _escape_sent:
			sim.press("escape_pod")
			_escape_sent = true
	else:
		_escape_held = 0.0
		_escape_sent = false


func _notification(what: int) -> void:
	# Losing the window's focus pauses the game (docs/DESIGN.md § Keyboard controls).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and runner == null and sim != null:
		if sim.mode() in ["docked", "flight"] and not sim.paused():
			sim.press("pause")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if handle_key(event):
		get_viewport().set_input_as_handled()


## Routes one key press by mode, screen and pause. Returns true when it was used.
func handle_key(event: InputEvent) -> bool:
	var mode: String = sim.mode()
	if sim.paused():
		return pause_panel.handle_key(event)
	match mode:
		"title":
			return title.handle_key(event)
		"docked":
			return _docked_key(event)
		"flight":
			return _flight_key(event)
	return false


func _docked_key(event: InputEvent) -> bool:
	if hub.handle_key(event):
		return true
	if event.is_action_pressed("pause"):
		sim.press("pause")
		return true
	if event.is_action_pressed("launch"):
		sim.press("launch")
		return true
	if event.is_action_pressed("galaxy_jump") or event.is_action_pressed("hyperspace"):
		hud.show_notice(Words.NOTE_DOCKED)
		hub.show_notice(Words.NOTE_DOCKED)
		return true
	for screen_key in Hub.SCREEN_KEYS:
		if event.is_action_pressed(screen_key):
			hub.open(Hub.SCREEN_KEYS[screen_key])
			return true
	return false


func _flight_key(event: InputEvent) -> bool:
	var screen: String = sim.screen()
	if event.is_action_pressed("pause"):
		if screen != "space":
			sim.show_screen("space")
		else:
			sim.press("pause")
		return true
	for screen_key in Hub.SCREEN_KEYS:
		if event.is_action_pressed(screen_key):
			var target: String = Hub.SCREEN_KEYS[screen_key]
			hub.open("space" if screen == target else target)
			return true
	if screen in ["galaxy", "local"] and hub.handle_key(event):
		return true
	for i in 4:
		if event.is_action_pressed(MOUNTS[i]):
			sim.press_mount(i)
			return true
	if event.is_action_pressed("galaxy_jump"):
		sim.press("galaxy_drive")
		return true
	if event.is_action_pressed("hyperspace"):
		hub.sync_cursor()
		sim.press("hyperspace")
		return true
	for action in FLIGHT_PRESSES:
		if event.is_action_pressed(action):
			sim.press(FLIGHT_PRESSES[action])
			return true
	return false


func _on_sim_event(kind: String, data: Dictionary) -> void:
	match kind:
		"hyperspace":
			match data["result"]:
				"started":
					hud.show_notice(Words.NOTE_JUMP_TARGET % String(data["system"]).to_upper(), 8.0)
				"out_of_range":
					hud.show_notice(Words.NOTE_OUT_OF_RANGE)
				"docked":
					hud.show_notice(Words.NOTE_DOCKED)
		"galaxy_drive":
			if data["result"] == "started":
				hud.show_notice(Words.NOTE_REACH_JUMP)
		"in_system_jump":
			hud.show_notice(Words.NOTE_HOP if data["ok"] else Words.NOTE_NO_HOP, 2.0)
		"mode":
			if data["mode"] == "tunnel_launch":
				hud.launches += 1
			if String(data["mode"]).begins_with("tunnel") or data["mode"] == "docked":
				hud.notice_time = 0.0
		"mount":
			hud.notice_time = 0.0
	hub.on_sim_event(kind, data)
