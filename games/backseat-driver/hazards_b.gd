extends RefCounted
## Road hazards, part B (see hazards_a.gd for the parameter meanings).

const Gfx = preload("res://gfx.gd")

var g: Gfx
var c: CanvasItem


func _init(gfx: Gfx) -> void:
	g = gfx
	c = gfx.c


func draw(id: String, s: float, hc: float, et: float, bad: bool, swerve: float) -> bool:
	match id:
		"police":
			police(s, hc, et, bad)
		"bridgeout":
			bridge_out(s, hc, et, bad)
		"rocks":
			rocks(s, hc, et, swerve)
		"gas":
			gas(s, et, bad)
		"curve":
			curve(s)
		"wrongway":
			wrongway(s)
		"ice":
			ice(s, et)
		"bus":
			bus(s, hc, et)
		_:
			return false
	return true


func police(s: float, hc: float, et: float, bad: bool) -> void:
	var u: float = s
	var p: Vector2 = g.P(470, s)
	g.rc(p + Vector2(0, -60) * u, 380.0 * u, 70.0 * u, Color("f2f2f2"))
	g.rc(p + Vector2(0, -35) * u, 380.0 * u, 34.0 * u, Color("16161c"))
	g.rc(p + Vector2(-20, -120) * u, 170.0 * u, 50.0 * u, Color("16161c"))
	g.rc(p + Vector2(-20, -120) * u, 140.0 * u, 34.0 * u, Color("a8d8f0"))
	for wx in [-120.0, 120.0]:
		g.c.draw_circle(p + Vector2(wx, -22) * u, 30.0 * u, Color("0e0e12"))
	var flash: bool = (hc > 0.55 or bad) and sin(et * 14.0) > 0.0
	g.c.draw_circle(p + Vector2(-50, -154) * u, 14.0 * u, Color("ff2a2a") if flash else Color("5a1a1a"))
	g.c.draw_circle(p + Vector2(10, -154) * u, 14.0 * u, Color("2a6aff") if not flash else Color("1a2a5a"))
	var bx: Vector2 = g.P(330, s)
	g.rc(bx + Vector2(0, -120) * u, 10.0 * u, 120.0 * u, Color("555555"))
	g.rc(bx + Vector2(230, -120) * u, 10.0 * u, 120.0 * u, Color("555555"))
	g.rc(bx + Vector2(115, -170) * u, 260.0 * u, 120.0 * u, Color("2f7a3a"))
	if s > 0.2:
		g.txt("JOE'S", bx + Vector2(0, -150) * u, int(34.0 * u), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 230.0 * u)


func bridge_out(s: float, hc: float, et: float, bad: bool) -> void:
	var ya: float = g.P(0, s * 0.5).y
	var yb: float = g.P(0, s).y
	g.poly([Vector2(0, ya), Vector2(Gfx.W, ya), Vector2(Gfx.W, yb), Vector2(0, yb)], Color("2f7fc0"))
	for k in 6:
		var y: float = ya + (yb - ya) * (float(k) + 0.5) / 6.0
		for j in 8:
			var x: float = float(j) * 170.0 + fposmod(et * 40.0 + float(k) * 55.0, 170.0)
			g.line(Vector2(x, y), Vector2(x + 60.0 * s, y), Color(1, 1, 1, 0.5), 3.0 * s)
	for k in 8:
		var bxk: float = -490.0 + float(k) * 140.0
		var pt: Vector2 = g.P(bxk, s * 1.05)
		g.rc(pt + Vector2(0, -50) * s, 100.0 * s, 36.0 * s, Color("ff8a1f") if k % 2 == 0 else Color.WHITE)
	if not bad and hc > 1.0:
		var fy: float = yb - 90.0 * s - absf(sin(et * 3.0)) * 60.0 * s
		g.el(Vector2(Gfx.W * 0.5 + 120.0 * s, fy), 36.0 * s, 16.0 * s, Color("f08a3a"))
		g.poly([Vector2(Gfx.W * 0.5 + 150.0 * s, fy), Vector2(Gfx.W * 0.5 + 180.0 * s, fy - 16.0 * s), Vector2(Gfx.W * 0.5 + 180.0 * s, fy + 16.0 * s)], Color("f08a3a"))


func rocks(s: float, hc: float, et: float, swerve: float) -> void:
	for k in 6:
		var f: float = fposmod(et * 0.9 + float(k) * 0.37, 1.0)
		var x: float = -520.0 + float(k) * 210.0
		var pp := Vector2(g.P(x, s * 0.8).x, lerpf(-30.0, g.P(0, s * 0.8).y - 20.0, f))
		g.el(pp, 12.0 + 18.0 * s, 10.0 + 14.0 * s, Color("6b6e75"))
	var gp: Vector2 = g.P(lerpf(0.0, 380.0, swerve), s)
	var t: float = clampf(hc, 0.0, 1.0)
	var r: float = 130.0 * s
	var by: float = lerpf(-250.0, gp.y - r * 0.9, t * t)
	var bp := Vector2(gp.x, by)
	g.el(bp, r, r * 0.9, Color("7d7f86"))
	g.el(bp + Vector2(-r * 0.2, -r * 0.2), r * 0.65, r * 0.55, Color("9a9ca4"))
	if t > 0.7:
		for sx in [-0.32, 0.32]:
			g.c.draw_circle(bp + Vector2(sx * r, -r * 0.1), r * 0.18, Color.WHITE)
			g.c.draw_circle(bp + Vector2(sx * r + r * 0.03, -r * 0.08), r * 0.08, Color.BLACK)


func gas(s: float, et: float, bad: bool) -> void:
	var u: float = s
	var p: Vector2 = g.P(700, s)
	g.rc(p + Vector2(0, -130) * u, 420.0 * u, 260.0 * u, Color("f2eadb"))
	g.rc(p + Vector2(0, -275) * u, 460.0 * u, 40.0 * u, Color("c0392b"))
	g.rc(p + Vector2(-80, -70) * u, 130.0 * u, 140.0 * u, Color("a8d8f0"))
	g.rc(p + Vector2(-380, -70) * u, 70.0 * u, 140.0 * u, Color("c0392b"))
	g.rc(p + Vector2(-480, -70) * u, 70.0 * u, 140.0 * u, Color("c0392b"))
	g.sign_plate("rect", g.P(500, s) + Vector2(0, -360) * u, 120.0 * u, Color("1f6fd1"), Color.WHITE, "GAS")
	if bad:
		for k in 3:
			var a: float = et * 0.7 + float(k) * 2.1
			var v := Vector2(Gfx.W * 0.5 + cos(a) * 220.0, 120.0 + sin(a * 1.3) * 40.0 + float(k) * 28.0)
			g.line(v, v + Vector2(-14, -9), Color("221a1a"), 3.0)
			g.line(v, v + Vector2(14, -9), Color("221a1a"), 3.0)


func curve(s: float) -> void:
	var p: Vector2 = g.P(0, s)
	var u: float = s
	g.rc(p + Vector2(0, -330) * u, 700.0 * u, 250.0 * u, Color("ffd21f"))
	g.c.draw_rect(Rect2(p + Vector2(-350, -455) * u, Vector2(700, 250) * u), Color("111111"), false, maxf(1.0, 6.0 * u))
	for k in 3:
		var cx: float = -190.0 + float(k) * 190.0
		g.poly([p + Vector2(cx - 70.0, -420.0) * u, p + Vector2(cx - 30.0, -420.0) * u, p + Vector2(cx + 50.0, -330.0) * u, p + Vector2(cx - 30.0, -240.0) * u, p + Vector2(cx - 70.0, -240.0) * u, p + Vector2(cx + 10.0, -330.0) * u], Color("111111"))
	g.rc(p + Vector2(0, -150) * u, 20.0 * u, 140.0 * u, Color("555555"))


func wrongway(s: float) -> void:
	var u: float = s
	var p: Vector2 = g.P(-120, s)
	g.el(p + Vector2(0, -200) * u, 340.0 * u, 260.0 * u, Color(1, 1, 0.8, 0.18))
	g.rc(p + Vector2(0, -170) * u, 380.0 * u, 300.0 * u, Color("3c4a5c"))
	g.rc(p + Vector2(0, -270) * u, 300.0 * u, 80.0 * u, Color("a8d8f0"))
	g.rc(p + Vector2(0, -110) * u, 260.0 * u, 60.0 * u, Color("1a1a20"))
	for sx in [-140.0, 140.0]:
		g.c.draw_circle(p + Vector2(sx, -170) * u, 38.0 * u, Color("fffbd0"))
	g.rc(p + Vector2(0, -20) * u, 400.0 * u, 40.0 * u, Color("141418"))


func ice(s: float, et: float) -> void:
	var p: Vector2 = g.P(0, s)
	g.el(p + Vector2(0, -8) * s, 560.0 * s, 70.0 * s, Color("b6dff2"))
	g.el(p + Vector2(-60, -14) * s, 380.0 * s, 40.0 * s, Color("d8f0fb"))
	for k in 5:
		var tw: float = 0.5 + 0.5 * sin(et * 4.0 + float(k) * 1.9)
		var sp: Vector2 = p + Vector2(-300.0 + float(k) * 150.0, -20.0 - 8.0 * float(k % 2)) * s
		g.line(sp + Vector2(-10, 0) * s, sp + Vector2(10, 0) * s, Color(1, 1, 1, tw), 3.0 * s)
		g.line(sp + Vector2(0, -10) * s, sp + Vector2(0, 10) * s, Color(1, 1, 1, tw), 3.0 * s)
	var cp: Vector2 = g.P(-650, s)
	g.el(cp + Vector2(0, -60) * s, 90.0 * s, 46.0 * s, Color.WHITE)
	g.c.draw_circle(cp + Vector2(-30, -70) * s, 16.0 * s, Color("222222"))
	g.c.draw_circle(cp + Vector2(30, -50) * s, 14.0 * s, Color("222222"))
	g.el(cp + Vector2(96, -88) * s, 32.0 * s, 22.0 * s, Color.WHITE)


func bus(s: float, hc: float, et: float) -> void:
	var u: float = s
	var p: Vector2 = g.P(360, s)
	g.rc(p + Vector2(0, -130) * u, 760.0 * u, 200.0 * u, Color("f2b81f"))
	g.rc(p + Vector2(0, -150) * u, 760.0 * u, 18.0 * u, Color("1a1a1a"))
	for k in 6:
		g.rc(p + Vector2(-300.0 + float(k) * 120.0, -190.0) * u, 90.0 * u, 60.0 * u, Color("a8d8f0"))
	for wx in [-230.0, 240.0]:
		g.c.draw_circle(p + Vector2(wx, -30) * u, 40.0 * u, Color("0e0e12"))
	var on: bool = sin(et * 8.0) > 0.0
	g.c.draw_circle(p + Vector2(-340, -250) * u, 14.0 * u, Color("ff2a2a") if on else Color("5a1a1a"))
	g.c.draw_circle(p + Vector2(340, -250) * u, 14.0 * u, Color("ff2a2a") if not on else Color("5a1a1a"))
	g.sign_plate("octagon", p + Vector2(-420, -170) * u, 90.0 * u, Color("d62828"), Color.WHITE, "STOP")
	var shirts: Array = [Color("e8453c"), Color("3c8de8"), Color("2fb36b"), Color("c06ae0")]
	for k in 4:
		var x: float = -330.0 + float(k) * 120.0 + (hc - 1.0) * 500.0
		var kp: Vector2 = g.P(x, s * 1.02)
		g.person(kp, 120.0 * s, shirts[k], Color("f1c9a5"), et * 6.0 + float(k), Color("3a2a1a"))
