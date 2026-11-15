extends Node
## Scripted play-through that visits every screen and saves screenshots to user://shots.
## Run: godot --path . res://tests/smoke.tscn  (needs a display; xvfb-run works)

var m: Node
var n := 0
var out := ""

func _ready() -> void:
	out = OS.get_environment("SHOTS")
	if out == "":
		out = ProjectSettings.globalize_path("user://shots")
	DirAccess.make_dir_recursive_absolute(out)
	m = load("res://main.tscn").instantiate()
	add_child(m)
	_run()

func wait(f: int = 3) -> void:
	for i in f:
		await get_tree().process_frame

func shot(name: String) -> void:
	await wait(3)
	await RenderingServer.frame_post_draw
	n += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out, n, name])

func press(action: String) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	await wait(2)
	var r := InputEventAction.new()
	r.action = action
	r.pressed = false
	Input.parse_input_event(r)
	await wait(2)

## Press E until no dialog is open (a typed-out message takes two presses).
func dismiss() -> void:
	for i in 8:
		if not Game.modal:
			return
		await press("act")

func _run() -> void:
	await wait(10)
	await shot("title")
	await get_tree().create_timer(1.3).timeout
	await press("act")
	await shot("intro")
	await dismiss()
	await shot("workshop")
	Game.next_call = Game.minute
	await wait(5)
	await shot("ringing")
	await press("act")
	await get_tree().create_timer(2.5).timeout
	await shot("call")
	await press("act")
	await press("act")
	await shot("work_order")
	await dismiss()
	await press("map")
	await shot("planner")
	await press("map")
	m.to_drive("shop")
	await shot("drive_start")
	Input.action_press("up")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("up")
	await shot("drive_moving")
	m.drive.van_pos = Vector2(950, 950)
	m.drive._spawn_event(Data.ROAD_EVENTS[0])
	m.drive._spawn_event(Data.ROAD_EVENTS[5])
	m.drive._spawn_event(Data.ROAD_EVENTS[3])
	await shot("drive_events")
	await press("map")
	await shot("planner_driving")
	await press("map")
	var job: Dictionary = Game.jobs[0]
	m.enter_place(Town.place("hardware"))
	await shot("hardware_outside")
	m.room.jim_x = 330.0
	await press("act")
	await shot("hardware_inside")
	m.room.jim_x = 490.0
	await press("act")
	await shot("store_menu")
	await press("down")
	await press("act")
	await press("cancel")
	for item in job.tpl.mats:
		Game.add_item(item, job.tpl.mats[item])
	m.enter_place(Town.place(job.house))
	await shot("house_outside")
	m.room.jim_x = 330.0
	await press("act")
	await shot("house_living")
	m.room._goto(m.room.rooms.find(job.tpl.room), 450.0)
	await shot("house_problem")
	await press("act")
	await get_tree().create_timer(0.6).timeout
	await shot("fixing")
	await get_tree().create_timer(2.5).timeout
	await shot("job_done")
	await dismiss()
	for k in ["bank", "gas", "tavern", "police", "plumbing", "electric", "lumber", "farm"]:
		m.enter_place(Town.place(k))
		m.room._goto(1, 300.0)
		await shot("inside_" + k)
	m.room.start_inside(Town.place("shop"), "Bunkroom")
	await shot("bunkroom")
	# every disaster picture
	for i in Data.JOBS.size():
		var tpl: Dictionary = Data.JOBS[i]
		var j := Game.make_job()
		j.tpl = tpl
		var rr: Array = j.rooms
		if not rr.has(tpl.room):
			rr[0] = tpl.room
		Game.jobs = [j]
		m.enter_place(Town.place(j.house))
		m.room._goto(m.room.rooms.find(tpl.room), 300.0)
		await shot("prob_%s" % tpl.prob)
	Game.jobs.clear()
	for sc in ["sleep", "arrest", "tv", "fishfry", "bar", "fishing", "hunting", "broke"]:
		m.mode = "cut"
		m.room.deactivate()
		m.cut.play(sc, ["Caption for " + sc, "second line"], Callable())
		await shot("cut_" + sc)
	print("SMOKE DONE ", n, " shots in ", out)
	get_tree().quit()
