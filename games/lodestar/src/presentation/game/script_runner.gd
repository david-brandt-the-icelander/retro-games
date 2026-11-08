extends Node
## Runs a scripted game for screenshots and the headless smoke test: `-- --script=<steps>`, where
## steps are comma-separated and each step's arguments are colon-separated, or `@shots` and
## `@smoke` for the two built-in scripts. With a script running, SimHost's real-time clock is
## stopped and the sim advances only by the steps, so a script always plays the same game.
## Screenshots go to `--shots=<folder>` (default `user://shots`). Any failed expectation prints
## why and quits with exit code 1; the end of the script quits with 0.
##
## Steps:
## - `wait:N` render N frames; `ticks:N` run N ticks now; `until:MODE:MAX` tick until the mode
##   is MODE (at most MAX ticks)
## - `key:ACTION` a key press of an input-map action, through the real input path; `raw:KEY` a
##   raw key such as `B` or `Enter`; `hold:ACTION:N` hold an action for N ticks
## - `press:NAME`, `screen:NAME`, `cursor:X:Y`, `buy:ITEM:Q`, `sell:ITEM:Q`, `equip:ITEM:MOUNT`
##   send the sim a command directly
## - `save:NAME` save while docked; `load:NAME` load on the title and start
## - `until_ship:MAX` tick until a ship is on the scanner; `aim:N` steer at the nearest ship for
##   N ticks, firing while it is in the line of fire; `aim:N:planet` fly flat out at the planet;
##   `aim_hit:MAX` steer and fire until the laser hits
## - `expect:MODE`, `expect_screen:NAME`, `expect_cash_below:TENTHS` check the game
## - `shot:FILE` save a screenshot; `quit` stop

const SHOTS := "shot:01-title.png,raw:Enter,ticks:1,expect:docked,expect_screen:status,wait:1,shot:02-docked-status.png,raw:1,ticks:1,wait:1,raw:Down,raw:Right,raw:Right,raw:Right,raw:Right,shot:03-market.png,raw:B,ticks:1,shot:04-market-bought.png,raw:2,ticks:1,wait:1,raw:Down,raw:Enter,ticks:1,shot:05-equipment.png,raw:Down,raw:Down,raw:Down,raw:Enter,raw:Right,wait:1,shot:06-mount-picker.png,raw:Escape,raw:6,ticks:1,wait:1,raw:S,wait:2,shot:07-save-name.png,raw:Escape,wait:1,save:ACE,raw:3,ticks:1,wait:1,cursor:72:100,raw:Left,raw:Enter,ticks:1,shot:08-galaxy-chart.png,raw:4,ticks:1,wait:1,shot:09-local-chart.png,raw:5,ticks:1,wait:1,expect_screen:system,shot:10-system.png,key:launch,ticks:5,shot:11-launch-tunnel.png,until:flight:40,ticks:3,wait:4,shot:12-flight-hud.png,hold:climb:30,hold:speed_up:30,shot:13-flight-turning.png,hold:climb:15,hold:speed_up:10,ticks:1700,expect:flight,until_ship:3000,ticks:10,aim:300,aim_hit:600,shot:14-fight.png,aim:150,aim_hit:600,shot:15-fight-later.png,key:screen_galaxy,ticks:1,wait:1,expect_screen:galaxy,shot:16-galaxy-in-flight.png,key:pause,ticks:1,expect_screen:space,key:hyperspace,ticks:2,shot:17-countdown.png,until:tunnel_jump:120,ticks:6,shot:18-hyperspace-tunnel.png,until:flight:40,ticks:3,wait:4,shot:19-arrival.png,key:pause,ticks:1,shot:20-pause.png,raw:Down,raw:Down,raw:Down,raw:Enter,raw:Y,ticks:1,expect:title,raw:Enter,ticks:1,expect:docked,key:launch,ticks:1,until:flight:40,hold:speed_up:40,until:dying:2000,ticks:8,wait:4,shot:21-death.png,until:title:80,expect:title,load:ACE,ticks:1,expect:docked,raw:7,ticks:1,wait:1,shot:22-loaded-hold.png,quit"

const SMOKE := "expect:title,press:start,ticks:1,expect:docked,expect_screen:status,screen:market,ticks:1,expect_screen:market,buy:0:5,ticks:1,expect_cash_below:1000,screen:equipment,ticks:1,equip:1:-1,ticks:1,save:SMOKE,key:launch,ticks:1,expect:tunnel_launch,until:flight:40,hold:speed_up:20,hold:fire:10,key:mount_rear,ticks:1,key:arm_missile,key:ecm,ticks:5,screen:galaxy,ticks:1,expect_screen:galaxy,screen:space,ticks:1,key:pause,ticks:1,press:resume,ticks:1,key:auto_dock,ticks:1,hold:speed_up:40,until:dying:4000,until:title:80,expect:title,load:SMOKE,ticks:1,expect:docked,quit"

var game: Node
var steps := ""
var _queue: PackedStringArray = []
var _wait := 0
var _shots_folder := "user://shots"
var _released: Array = []
var _hits := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_shots_folder = arg.trim_prefix("--shots=")
	if steps == "@shots":
		steps = SHOTS
	elif steps == "@smoke":
		steps = SMOKE
	_queue = steps.split(",", false)
	game.sim.set_running(false)
	game.sim.sim_event.connect(func(kind: String, _data: Dictionary) -> void:
		if kind == "laser_hit":
			_hits += 1)
	DirAccess.make_dir_recursive_absolute(_shots_folder)
	print("script: %d steps" % _queue.size())


func _process(_delta: float) -> void:
	for event in _released:
		Input.parse_input_event(event)
	_released.clear()
	if _wait > 0:
		_wait -= 1
		return
	while not _queue.is_empty() and _wait == 0:
		var step := _queue[0]
		_queue.remove_at(0)
		if not _run(step.split(":")):
			return


## Runs one step; returns false to end this frame (after a key press, a wait or a screenshot).
func _run(step: PackedStringArray) -> bool:
	var sim: Node = game.sim
	var name := step[0]
	match name:
		"wait":
			_wait = int(step[1])
			return false
		"ticks":
			sim.advance(int(step[1]))
		"until":
			var limit := int(step[2])
			while sim.mode() != step[1] and limit > 0:
				sim.advance(1)
				limit -= 1
			if sim.mode() != step[1]:
				return _fail("mode %s not reached (now %s)" % [step[1], sim.mode()])
		"key":
			var events := InputMap.action_get_events(step[1])
			if events.is_empty():
				return _fail("no action " + step[1])
			_send_key(events[0])
			return false
		"raw":
			var key := InputEventKey.new()
			key.keycode = OS.find_keycode_from_string(step[1])
			key.physical_keycode = key.keycode
			_send_key(key)
			return false
		"hold":
			Input.action_press(step[1])
			sim.advance(int(step[2]))
			Input.action_release(step[1])
		"press":
			sim.press(step[1])
		"screen":
			game.hub.open(step[1])
		"cursor":
			game.hub.cursor = Vector2i(int(step[1]), int(step[2]))
		"buy":
			sim.buy(int(step[1]), int(step[2]))
		"sell":
			sim.sell(int(step[1]), int(step[2]))
		"equip":
			sim.equip(int(step[1]), int(step[2]))
		"save":
			var outcome: String = sim.save_pilot(step[1])
			if outcome != "saved":
				return _fail("save: " + outcome)
		"load":
			var error: String = game.title.load_and_start(step[1])
			if error != "":
				return _fail("load: " + error)
		"until_ship":
			var limit := int(step[1])
			while not _ship_near() and limit > 0 and sim.mode() == "flight":
				sim.advance(1)
				limit -= 1
			if not _ship_near():
				return _fail("no ship came")
		"aim":
			var planet := step.size() > 2 and step[2] == "planet"
			for i in int(step[1]):
				if sim.mode() != "flight":
					break
				_steer(planet)
				sim.advance(1)
			for action in ["roll_left", "roll_right", "climb", "dive", "fire", "slow_down", "speed_up"]:
				Input.action_release(action)
		"aim_hit":
			var before := _hits
			var limit := int(step[1])
			while _hits == before and limit > 0 and sim.mode() == "flight":
				_steer(false)
				sim.advance(1)
				limit -= 1
			for action in ["roll_left", "roll_right", "climb", "dive", "fire", "slow_down", "speed_up"]:
				Input.action_release(action)
			if _hits == before:
				return _fail("no laser hit")
		"expect":
			if sim.mode() != step[1]:
				return _fail("expected mode %s, got %s" % [step[1], sim.mode()])
		"expect_screen":
			if sim.screen() != step[1]:
				return _fail("expected screen %s, got %s" % [step[1], sim.screen()])
		"expect_cash_below":
			if int(sim.pilot()["cash"]) >= int(step[1]):
				return _fail("cash %d not below %s" % [sim.pilot()["cash"], step[1]])
		"shot":
			_queue.insert(0, "snap:" + step[1])
			_wait = 3
			return false
		"snap":
			var path := _shots_folder.path_join(step[1])
			if DisplayServer.get_name() != "headless":
				get_viewport().get_texture().get_image().save_png(path)
				print("shot: ", path, "  mode ", sim.mode(), "  tick ", sim.tick_count())
		"debug":
			for control in [game.title, game.hub, game.hud, game.pause_panel, game.tunnel]:
				print("%s visible=%s size=%s" % [control.get_script().resource_path.get_file(), control.is_visible_in_tree(), control.size])
			var c: Dictionary = sim.cockpit()
			print("mode=%s screen=%s paused=%s tick=%d speed=%d roll=%.3f pitch=%.3f energy=%d hits=%d" % [sim.mode(), sim.screen(), sim.paused(), sim.tick_count(), c["speed"], c["roll_angle"], c["pitch_angle"], c["energy"], _hits])
			for o in sim.objects():
				print("  slot %d kind %d at %s (%.0f m)%s" % [o["slot"], o["kind"], o["position"], (o["position"] as Vector3).length(), " exploding" if o["exploding"] else ""])
		"quit":
			print("script: done at tick %d" % sim.tick_count())
			get_tree().quit(0)
			return false
		_:
			return _fail("unknown step " + name)
	return true


func _send_key(template: InputEvent) -> void:
	var press: InputEvent = template.duplicate()
	press.pressed = true
	Input.parse_input_event(press)
	var release: InputEvent = template.duplicate()
	release.pressed = false
	_released.append(release)


func _fail(why: String) -> bool:
	push_error("script failed: " + why)
	printerr("script failed: ", why)
	_queue.clear()
	get_tree().quit(1)
	return false


func _nearest_ship() -> Dictionary:
	var best := {}
	var best_d := INF
	for o in game.sim.objects():
		var kind: int = o["kind"]
		if (kind <= 7 or kind == 12) and not o["exploding"] and not o["killed"]:
			var d: float = (o["position"] as Vector3).length()
			if d < best_d:
				best_d = d
				best = o
	return best


func _planet() -> Dictionary:
	for o in game.sim.objects():
		if o["kind"] in [128, 130]:
			return o
	return {}


func _ship_near() -> bool:
	var o := _nearest_ship()
	return not o.is_empty() and (o["position"] as Vector3).length() < 3000.0


## Holds the keys that bring the nearest ship (or the planet) towards the front mount's axis:
## roll it to the top of the view, then climb onto it; fire while a ship is in the line of fire.
## At a ship it slows to 10; at the planet it flies flat out.
func _steer(planet: bool) -> void:
	for action in ["roll_left", "roll_right", "climb", "dive", "fire", "slow_down", "speed_up"]:
		Input.action_release(action)
	var o := _planet() if planet else _nearest_ship()
	if o.is_empty():
		return
	var p: Vector3 = o["position"]
	var x := p.x
	var y := p.y
	var z := -p.z
	var near := 6.0
	if absf(x) > maxf(near, 0.3 * absf(y)) or y < 0.0 and z < 0.0:
		Input.action_press("roll_right" if x > 0.0 else "roll_left")
	if y > near or z < 0.0:
		Input.action_press("climb")
	elif y < -near:
		Input.action_press("dive")
	if planet:
		Input.action_press("speed_up")
	elif int(game.sim.cockpit()["speed"]) > 10:
		Input.action_press("slow_down")
	if o["in_sights"]:
		Input.action_press("fire")
