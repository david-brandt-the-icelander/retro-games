extends Node2D
## Full-screen picture scenes: title, the nightly Zzzz, jail, and the weekend reward.

var scene := ""
var caption: Array = []
var on_done := Callable()
var t := 0.0

func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visible = false

func play(id: String, lines: Array, done: Callable) -> void:
	scene = id
	caption = []
	for l in lines:
		caption.append_array(Game.wrap(str(l), 600, 12))
	on_done = done
	t = 0.0
	visible = true

func _process(dt: float) -> void:
	if not visible:
		return
	t += dt
	queue_redraw()
	if t > 1.2 and not Game.modal and Input.is_action_just_pressed("act"):
		visible = false
		Game.block_frame = Engine.get_process_frames()
		var cb := on_done
		on_done = Callable()
		if cb.is_valid():
			cb.call()

func _draw() -> void:
	if not Art.try_png(self, "cut_" + scene, Rect2(0, 0, 640, 300)):
		match scene:
			"title": _title()
			"sleep": _sleep()
			"arrest": _arrest()
			"tv": _tv()
			"fishfry": _fishfry()
			"bar": _bar()
			"fishing": _fishing()
			"hunting": _hunting()
			"broke": _broke()
	Art.shape(self, Rect2(0, 300, 640, 100), Pal.BLACK)
	var y := 318.0
	for l in caption:
		Art.text(self, Vector2(0, y), l, Pal.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, 640)
		y += 15
	if t > 1.2 and int(t * 2) % 2 == 0:
		Art.text(self, Vector2(0, 394), "press E / Enter", Pal.DGRAY, 10, HORIZONTAL_ALIGNMENT_CENTER, 640)

func _sky(c: Color = Pal.LCYAN) -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), c)

func _title() -> void:
	_sky()
	Art.circ(self, Vector2(520, 60), 30, Pal.YELLOW)
	Art.tree_side(self, Vector2(60, 240), 220)
	Art.dfill(self, Rect2(0, 230, 640, 20), Pal.GREEN, Pal.LGREEN)
	var fr := Rect2(150, 120, 330, 120)
	Art.dfill(self, fr, Pal.RED, Pal.BROWN)
	for yy in range(128, 240, 10):
		draw_line(Vector2(150, yy), Vector2(480, yy), Pal.BLACK, 1)
	Art.shape(self, Rect2(146, 88, 338, 34), Pal.LGRAY)
	Art.shape(self, Rect2(170, 92, 290, 26), Pal.WHITE)
	Art.text(self, Vector2(150, 112), "JIM'S FIX-IT SHACK", Pal.BLACK, 18, HORIZONTAL_ALIGNMENT_CENTER, 330)
	Art.shape(self, Rect2(296, 160, 40, 80), Pal.BROWN)
	Art.dfill(self, Rect2(0, 250, 640, 50), Pal.DGRAY, Pal.BLACK)
	Art.van_side(self, Vector2(370, 290), 1.3)
	Art.jim(self, Vector2(240, 290), 2.0, 1, 0.0)
	Art.dog(self, Vector2(300, 290), 1.5, t)
	var bounce := sin(t * 3) * 3
	Art.text_shadow(self, Vector2(0, 46 + bounce), "HANDYMAN JIM", Pal.YELLOW, 40, HORIZONTAL_ALIGNMENT_CENTER, 640)
	Art.text_shadow(self, Vector2(0, 72), "Marshfield, Wisconsin's Fix-It-All Guy", Pal.WHITE, 14, HORIZONTAL_ALIGNMENT_CENTER, 640)

func _sleep() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.BLUE)
	Art.dfill(self, Rect2(0, 0, 640, 220), Pal.BLUE, Pal.BLACK)
	Art.shape(self, Rect2(420, 50, 110, 80), Pal.BLACK)
	Art.shape(self, Rect2(424, 54, 102, 72), Color8(0, 0, 85))
	Art.circ(self, Vector2(490, 80), 16, Pal.YELLOW)
	Art.circ(self, Vector2(498, 74), 14, Color8(0, 0, 85))
	Art.shape(self, Rect2(474, 54, 3, 72), Pal.BLACK)
	Art.shape(self, Rect2(0, 220, 640, 80), Pal.BROWN)
	Art.shape(self, Rect2(120, 190, 260, 50), Pal.GREEN)        # cot + blanket
	Art.shape(self, Rect2(110, 170, 16, 70), Pal.BROWN)
	Art.shape(self, Rect2(128, 184, 40, 16), Pal.WHITE)
	Art.ellipse(self, Vector2(142, 182), 4, 7, Art.BLOND)                  # blond fringe
	Art.circ(self, Vector2(152, 180), 10, Art.SKIN)                       # Jim's bald head on the pillow
	Art.ellipse(self, Vector2(152, 175), 4, 2, Color(1, 1, 1, 0.45), false)
	draw_arc(Vector2(150, 180), 3, 0.2, 2.9, 8, Pal.BLACK, 1.2, true)       # closed eyes
	draw_arc(Vector2(158, 180), 3, 0.2, 2.9, 8, Pal.BLACK, 1.2, true)
	Art.ellipse(self, Vector2(155, 186), 5, 2, Art.BLOND)                 # moustache
	Art.dog(self, Vector2(430, 250), 1.6, 0.0)
	for k in 4:
		var ph := fmod(t * 0.7 + k * 0.25, 1.0)
		var size := int(14 + ph * 26)
		var col := Color(1, 1, 1, 1.0 - ph)
		Art.text(self, Vector2(170 + ph * 160 + k * 6, 160 - ph * 130), "Z", col, size)

func _arrest() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.DGRAY)
	Art.dfill(self, Rect2(0, 0, 640, 240), Pal.DGRAY, Pal.LGRAY)
	Art.shape(self, Rect2(0, 240, 640, 60), Pal.LGRAY)
	Art.shape(self, Rect2(400, 140, 160, 30), Pal.WHITE)        # bunk
	Art.jim(self, Vector2(280, 270), 2.2, 1, 0.0)
	for k in 12:
		Art.shape(self, Rect2(20 + k * 52, 0, 8, 300), Pal.BLACK)
	Art.shape(self, Rect2(0, 30, 640, 8), Pal.BLACK)
	Art.shape(self, Rect2(0, 230, 640, 8), Pal.BLACK)
	Art.text_shadow(self, Vector2(0, 90), "WOOD COUNTY LOCKUP", Pal.WHITE, 24, HORIZONTAL_ALIGNMENT_CENTER, 640)

func _tv() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Color8(0, 0, 85))
	Art.dfill(self, Rect2(0, 0, 640, 220), Pal.BROWN, Color8(110, 55, 0))
	Art.shape(self, Rect2(0, 220, 640, 80), Pal.DGRAY)
	var glow := Pal.LBLUE if int(t * 3) % 2 == 0 else Pal.LCYAN
	Art.shape(self, Rect2(440, 110, 150, 110), Pal.BLACK)          # TV
	Art.shape(self, Rect2(450, 120, 130, 84), glow)
	Art.shape(self, Rect2(470, 160, 90, 30), Pal.GREEN)
	Art.text(self, Vector2(450, 140), "PACKERS 24 - BEARS 3", Pal.YELLOW, 10, HORIZONTAL_ALIGNMENT_CENTER, 130)
	Art.shape(self, Rect2(60, 180, 260, 70), Pal.BROWN)            # couch
	Art.shape(self, Rect2(50, 150, 280, 40), Color8(150, 75, 0))
	Art.jim(self, Vector2(160, 240), 2.0, 1, 0.0)
	Art.beer(self, Vector2(190, 200), 2.0)
	Art.dog(self, Vector2(260, 250), 2.0, t)
	for k in 5:
		Art.beer(self, Vector2(340 + k * 14, 290), 1.4)

func _fishfry() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.BROWN)
	for k in 32:
		Art.shape(self, Rect2(k * 20 + 8, 0, 3, 200), Color8(110, 55, 0))
	Art.shape(self, Rect2(170, 30, 300, 40), Pal.BLACK)
	Art.text(self, Vector2(170, 58), "FRIDAY FISH FRY", Pal.LRED if int(t * 2) % 2 == 0 else Pal.YELLOW, 22, HORIZONTAL_ALIGNMENT_CENTER, 300)
	Art.shape(self, Rect2(0, 200, 640, 100), Pal.RED)
	Art.jim(self, Vector2(320, 236), 2.0, -1, 0.0)
	Art.dfill(self, Rect2(120, 190, 400, 30), Pal.WHITE, Pal.LRED)   # checkered tablecloth
	Art.shape(self, Rect2(140, 220, 360, 60), Pal.BROWN)
	Art.circ(self, Vector2(240, 196), 30, Pal.WHITE)            # plate
	for k in 3:
		Art.shape(self, Rect2(220 + k * 12, 186, 10, 18), Pal.YELLOW)  # fried cod
	Art.shape(self, Rect2(400, 170, 14, 22), Color8(255, 170, 85)) # brandy old fashioned
	Art.shape(self, Rect2(404, 166, 6, 6), Pal.RED)

func _bar() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.BLACK)
	Art.dfill(self, Rect2(0, 0, 640, 200), Pal.BROWN, Pal.BLACK)
	Art.text(self, Vector2(60, 70), "BEER", Pal.LRED if int(t * 2) % 2 == 0 else Pal.RED, 30)
	Art.text(self, Vector2(440, 70), "RUSTY MUSKIE", Pal.LCYAN, 16)
	Art.shape(self, Rect2(420, 90, 160, 26), Pal.GREEN)
	for k in 3:
		Art.person(self, Vector2(140 + k * 160, 230), 2.0, [Pal.LRED, Pal.GREEN, Pal.YELLOW][k], Pal.BLUE,
			[Pal.WHITE, Pal.LRED, Pal.GREEN][k], Color8(255, 170, 85), Pal.BROWN, k == 1, 1 if k < 1 else -1, 0.0)
	Art.shape(self, Rect2(0, 200, 640, 100), Color8(110, 55, 0))
	Art.shape(self, Rect2(0, 196, 640, 8), Pal.BROWN)
	for k in 6:
		Art.beer(self, Vector2(80 + k * 90, 196), 2.0)
	Art.text_shadow(self, Vector2(240, 150 + sin(t * 4) * 3), "...and THEN the toilet exploded!", Pal.WHITE, 12)

func _fishing() -> void:
	_sky()
	Art.circ(self, Vector2(560, 60), 26, Pal.YELLOW)
	for k in 7:
		Art.tree_side(self, Vector2(20 + k * 100, 150), 90)
	Art.dfill(self, Rect2(0, 150, 640, 150), Pal.BLUE, Pal.LBLUE)
	var bob := sin(t * 2) * 3
	draw_colored_polygon(PackedVector2Array([Vector2(180, 210 + bob), Vector2(400, 210 + bob), Vector2(370, 240 + bob), Vector2(210, 240 + bob)]), Pal.LGRAY)
	Art.jim(self, Vector2(290, 212 + bob), 1.8, 1, 0.0)
	Art.dog(self, Vector2(220, 212 + bob), 1.2, t)
	draw_line(Vector2(305, 150 + bob), Vector2(470, 90), Pal.BLACK, 2)
	draw_line(Vector2(470, 90), Vector2(480, 220), Pal.WHITE, 1)
	var jump := absf(sin(t * 1.5)) * 40
	Art.shape(self, Rect2(490, 210 - jump, 30, 10), Pal.GREEN)    # walleye showing off
	Art.beer(self, Vector2(360, 212 + bob), 1.3)

func _hunting() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.LGRAY)
	for k in 9:
		Art.shape(self, Rect2(k * 75, 0, 16, 300), Pal.BROWN)
		Art.circ(self, Vector2(k * 75 + 8, 40), 40, Pal.GREEN)
	Art.dfill(self, Rect2(0, 240, 640, 60), Pal.WHITE, Pal.LGRAY)      # first snow
	Art.shape(self, Rect2(380, 120, 110, 12), Pal.BROWN)             # tree stand
	for k in 6:
		Art.shape(self, Rect2(380, 140 + k * 18, 30, 4), Pal.BROWN)
	Art.person(self, Vector2(430, 120), 1.8, Pal.LRED, Pal.LRED, Pal.LRED, Color8(255, 170, 85), Pal.BROWN, true, -1, 0.0)
	Art.shape(self, Rect2(150, 220, 60, 22), Pal.BROWN)              # the buck
	Art.shape(self, Rect2(200, 200, 18, 22), Pal.BROWN)
	for k in 4:
		draw_line(Vector2(204 + k * 4, 200), Vector2(196 + k * 8, 180), Pal.YELLOW, 2)
	for lx in [154, 166, 192, 202]:
		Art.shape(self, Rect2(lx, 240, 4, 18), Pal.BROWN)
	Art.text_shadow(self, Vector2(20, 40), "UP NORTH", Pal.WHITE, 24)

func _broke() -> void:
	Art.shape(self, Rect2(0, 0, 640, 300), Pal.BLACK)
	Art.circ(self, Vector2(320, 170), 120, Color(0.1, 0.1, 0.3))
	Art.jim(self, Vector2(300, 250), 2.2, 1, 0.0)
	Art.shape(self, Rect2(330, 190, 22, 28), Pal.LGRAY)              # can of beans
	Art.shape(self, Rect2(330, 198, 22, 12), Pal.RED)
	Art.dog(self, Vector2(400, 236), 1.8, 0.0)
	Art.text(self, Vector2(420, 195), "...", Pal.WHITE, 14)
