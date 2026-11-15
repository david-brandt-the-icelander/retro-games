extends RefCounted
## Road hazards, part A. draw() returns true when it knows the hazard id.
## s = screen scale of the hazard's depth, hc = crossing progress
## (1.0 means "dead centre in front of the bumper"), et = seconds on this event.

const Gfx = preload("res://gfx.gd")

var g: Gfx
var c: CanvasItem


func _init(gfx: Gfx) -> void:
	g = gfx
	c = gfx.c


func draw(id: String, s: float, hc: float, et: float, _bad: bool, _swerve: float) -> bool:
	match id:
		"ducks":
			ducks(s, hc, et)
		"gator":
			gator(s, hc, et)
		"walker":
			walker(s, hc, et)
		"kids":
			kids(s, hc, et)
		"stop":
			stop_truck(s, hc, et)
		"train":
			train(s, hc, et)
		"kayak":
			bridge(s)
		"deer":
			deer(s, hc, et)
		_:
			return false
	return true


func zebra(s: float) -> void:
	for k in 9:
		var x: float = -480.0 + float(k) * 120.0
		g.poly([g.P(x - 35.0, s * 0.94), g.P(x + 35.0, s * 0.94), g.P(x + 35.0, s * 1.06), g.P(x - 35.0, s * 1.06)], Color(0.95, 0.95, 0.95))


func ducks(s: float, hc: float, et: float) -> void:
	var orange := Color("f08a1c")
	for k in 7:
		var sk: float = s * (1.0 - 0.05 * float(k % 3))
		var x: float = -420.0 + float(k) * 140.0 + (hc - 1.0) * 650.0
		var hop: float = absf(sin(et * 6.0 + float(k) * 1.7)) * 16.0 * sk
		var p: Vector2 = g.P(x, sk) + Vector2(0, -hop)
		var u: float = sk * 1.5
		g.line(p + Vector2(-8, -20) * u, p + Vector2(-8, 0) * u, orange, 4.0 * u)
		g.line(p + Vector2(10, -20) * u, p + Vector2(10, 0) * u, orange, 4.0 * u)
		g.el(p + Vector2(0, -36) * u, 38.0 * u, 26.0 * u, Color("f2eedd"))
		g.el(p + Vector2(-8, -40) * u, 22.0 * u, 13.0 * u, Color("d8d2bc"))
		g.poly([p + Vector2(-34, -44) * u, p + Vector2(-56, -62) * u, p + Vector2(-30, -30) * u], Color("f2eedd"))
		g.c.draw_circle(p + Vector2(30, -64) * u, 17.0 * u, Color("2d7a3a"))
		g.el(p + Vector2(50, -60) * u, 14.0 * u, 6.0 * u, orange)
		g.c.draw_circle(p + Vector2(34, -68) * u, 3.0 * u, Color.BLACK)


func gator(s: float, hc: float, et: float) -> void:
	var u: float = s
	var p: Vector2 = g.P((hc - 1.0) * 750.0, s)
	var gr := Color("3f7f3a")
	var dk := Color("2c5c2a")
	var wag: float = sin(et * 3.0) * 25.0
	g.poly([p + Vector2(-250, -90) * u, p + Vector2(-540, -20 + wag) * u, p + Vector2(-250, -20) * u], gr)
	for k in 4:
		var lx: float = [-170.0, -80.0, 120.0, 200.0][k]
		g.rc(p + Vector2(lx, -16.0 + sin(et * 4.0 + float(k)) * 5.0) * u, 44.0 * u, 40.0 * u, dk)
	g.el(p + Vector2(0, -52) * u, 290.0 * u, 52.0 * u, gr)
	g.el(p + Vector2(0, -30) * u, 250.0 * u, 26.0 * u, Color("9bc27a"))
	for k in 9:
		var rx: float = -230.0 + float(k) * 55.0
		g.poly([p + Vector2(rx, -96) * u, p + Vector2(rx + 22.0, -96) * u, p + Vector2(rx + 11.0, -118) * u], dk)
	g.el(p + Vector2(300, -44) * u, 135.0 * u, 34.0 * u, gr)
	g.line(p + Vector2(190, -34) * u, p + Vector2(430, -34) * u, Color("1c3a1b"), 5.0 * u)
	for k in 7:
		var tx: float = 220.0 + float(k) * 30.0
		g.poly([p + Vector2(tx, -33) * u, p + Vector2(tx + 14.0, -33) * u, p + Vector2(tx + 7.0, -14) * u], Color.WHITE)
	g.c.draw_circle(p + Vector2(270, -86) * u, 20.0 * u, Color("f3d23a"))
	g.rc(p + Vector2(272, -86) * u, 6.0 * u, 24.0 * u, Color.BLACK)


func walker(s: float, hc: float, et: float) -> void:
	zebra(s)
	var h: float = 190.0 * s
	var p: Vector2 = g.P((hc - 1.0) * 520.0, s)
	g.person(p, h, Color("7a5a3a"), Color("e8c4a0"), et * 2.0, Color("f0f0f0"))
	var fx: Vector2 = p + Vector2(h * 0.3, 0)
	var steel := Color("b9bec8")
	g.line(fx, fx + Vector2(0, -h * 0.5), steel, h * 0.025)
	g.line(fx + Vector2(-h * 0.16, 0), fx + Vector2(-h * 0.16, -h * 0.5), steel, h * 0.025)
	g.line(fx + Vector2(-h * 0.16, -h * 0.5), fx + Vector2(0, -h * 0.5), steel, h * 0.03)


func kids(s: float, hc: float, et: float) -> void:
	var shirts: Array = [Color("e8453c"), Color("3c8de8"), Color("f2c230")]
	for k in 3:
		var x: float = -330.0 + float(k) * 150.0 + (hc - 1.0) * 600.0
		var p: Vector2 = g.P(x, s * (1.0 - 0.04 * float(k)))
		g.person(p, 120.0 * s, shirts[k], Color("f1c9a5"), et * 9.0 + float(k), Color("5a3a1a"))
	var bounce: float = absf(sin(et * 5.0)) * 90.0 * s
	var bp: Vector2 = g.P(110.0 + (hc - 1.0) * 600.0, s) + Vector2(0, -22.0 * s - bounce)
	g.c.draw_circle(bp, 22.0 * s, Color("e8453c"))
	g.line(bp + Vector2(-22, 0) * s, bp + Vector2(22, 0) * s, Color.WHITE, 5.0 * s)


func stop_truck(s: float, hc: float, _et: float) -> void:
	var ya: float = g.P(0, s * 0.9).y
	var yb: float = g.P(0, s * 1.1).y
	g.poly([Vector2(0, ya), Vector2(Gfx.W, ya), Vector2(Gfx.W, yb), Vector2(0, yb)], Color("55555c"))
	g.poly([g.P(-520, s * 1.15), g.P(520, s * 1.15), g.P(520, s * 1.19), g.P(-520, s * 1.19)], Color.WHITE)
	var u: float = s
	var p: Vector2 = g.P((1.0 - hc) * 1500.0, s)
	g.rc(p + Vector2(60, -75) * u, 620.0 * u, 30.0 * u, Color("2b2b33"))
	for row in 3:
		for k in 5:
			var lx: float = -180.0 + float(k) * 120.0 + (20.0 if row % 2 == 1 else 0.0)
			g.rc(p + Vector2(lx + 60.0, -105.0 - float(row) * 50.0) * u, 118.0 * u, 48.0 * u, Color("8a5a2b"))
			g.el(p + Vector2(lx + 118.0, -105.0 - float(row) * 50.0) * u, 8.0 * u, 22.0 * u, Color("d9b27a"))
	g.rc(p + Vector2(-290, -120) * u, 150.0 * u, 160.0 * u, Color("c0392b"))
	g.rc(p + Vector2(-310, -150) * u, 70.0 * u, 60.0 * u, Color("a8d8f0"))
	for wx in [-290.0, -120.0, 100.0, 300.0]:
		g.c.draw_circle(p + Vector2(wx, -34) * u, 36.0 * u, Color("141418"))


func train(s: float, hc: float, et: float) -> void:
	g.poly([Vector2(0, g.P(0, s * 0.92).y), Vector2(Gfx.W, g.P(0, s * 0.92).y), Vector2(Gfx.W, g.P(0, s * 1.08).y), Vector2(0, g.P(0, s * 1.08).y)], Color("4a3f35"))
	g.line(Vector2(0, g.P(0, s * 0.97).y), Vector2(Gfx.W, g.P(0, s * 0.97).y), Color("b9bec8"), 4.0 * s)
	g.line(Vector2(0, g.P(0, s * 1.03).y), Vector2(Gfx.W, g.P(0, s * 1.03).y), Color("b9bec8"), 4.0 * s)
	var u: float = s
	var p: Vector2 = g.P((1.0 - hc) * 2200.0, s)
	g.rc(p + Vector2(-200, -140) * u, 480.0 * u, 230.0 * u, Color("1d1d22"))
	g.rc(p + Vector2(-200, -80) * u, 480.0 * u, 26.0 * u, Color("f2c230"))
	g.rc(p + Vector2(-380, -190) * u, 90.0 * u, 70.0 * u, Color("a8d8f0"))
	g.c.draw_circle(p + Vector2(-445, -105) * u, 22.0 * u, Color("fff2a0"))
	for k in 4:
		var wx: float = 80.0 + float(k) * 460.0
		g.rc(p + Vector2(wx + 150.0, -150) * u, 440.0 * u, 250.0 * u, [Color("6b2f2f"), Color("2f4f6b"), Color("4f4f4f"), Color("2f6b45")][k])
	for wx in [-340.0, -80.0, 140.0, 400.0, 700.0]:
		g.c.draw_circle(p + Vector2(wx, -28) * u, 28.0 * u, Color("0e0e12"))
	var on: bool = sin(et * 9.0) > 0.0
	for sx in [-610.0, 610.0]:
		var base: Vector2 = g.P(sx, s)
		g.line(base, base + Vector2(0, -300) * u, Color("d8d8d8"), 12.0 * u)
		g.c.draw_circle(base + Vector2(-26.0 if sx < 0.0 else 26.0, -300) * u, 20.0 * u, Color("ff2a2a") if on else Color("6a1a1a"))


func bridge(s: float) -> void:
	var gp: Vector2 = g.P(0, s)
	var top: float = gp.y - 235.0 * s
	var stone := Color("8a8478")
	g.c.draw_rect(Rect2(0, top - 130.0 * s, Gfx.W, 130.0 * s), stone)
	g.c.draw_rect(Rect2(0, top, g.P(-430, s).x, gp.y - top + 140.0 * s), Color("77716a"))
	g.c.draw_rect(Rect2(g.P(430, s).x, top, Gfx.W, gp.y - top + 140.0 * s), Color("77716a"))
	for k in 5:
		var y: float = top - 130.0 * s + float(k) * 26.0 * s
		g.line(Vector2(0, y), Vector2(Gfx.W, y), Color("5f5a54"), 3.0 * s)
	g.sign_plate("rect", Vector2(Gfx.W * 0.5, top + 52.0 * s), 70.0 * s, Color("ffd21f"), Color("111111"), "LOW\n8'6\"")


func deer(s: float, hc: float, et: float) -> void:
	for k in 2:
		var u: float = s * (1.0 - 0.12 * float(k))
		var p: Vector2 = g.P((hc - 1.0) * 420.0 - 160.0 + float(k) * 330.0, s * (1.0 - 0.12 * float(k)))
		var brown := Color("8a5a2b")
		for lx in [-70.0, -42.0, 48.0, 78.0]:
			g.line(p + Vector2(lx, -120) * u, p + Vector2(lx, 0) * u, Color("6a4320"), 12.0 * u)
		g.el(p + Vector2(0, -150) * u, 105.0 * u, 52.0 * u, brown)
		g.c.draw_circle(p + Vector2(-102, -165) * u, 12.0 * u, Color.WHITE)
		g.poly([p + Vector2(60, -170) * u, p + Vector2(100, -170) * u, p + Vector2(135, -270) * u, p + Vector2(105, -272) * u], brown)
		g.el(p + Vector2(136, -276) * u, 38.0 * u, 20.0 * u, brown)
		g.line(p + Vector2(125, -290) * u, p + Vector2(105, -370) * u, Color("d8c8a0"), 6.0 * u)
		g.line(p + Vector2(110, -340) * u, p + Vector2(60, -380) * u, Color("d8c8a0"), 5.0 * u)
		var glow: float = 0.55 + 0.25 * sin(et * 4.0 + float(k))
		g.c.draw_circle(p + Vector2(150, -282) * u, 20.0 * u, Color(1, 0.95, 0.4, glow * 0.5))
		g.c.draw_circle(p + Vector2(150, -282) * u, 8.0 * u, Color(1, 1, 0.6, 1))
