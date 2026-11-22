extends RefCounted
## Shared material factory with a small cache.

const ADD_SHADER := preload("res://shaders/additive.gdshader")

static var _cache: Dictionary = {}


static func metal(c: Color, rough: float = 0.4, metallic: float = 0.8, fade: bool = false) -> StandardMaterial3D:
	var key := "metal_%s_%.2f_%.2f_%s" % [c.to_html(), rough, metallic, str(fade)]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = rough
	if fade:
		# Obstacles between the camera and the ship dissolve so they never hide it.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
		m.distance_fade_min_distance = 21.0
		m.distance_fade_max_distance = 29.0
	_cache[key] = m
	return m


static func glow(c: Color, energy: float = 4.0) -> StandardMaterial3D:
	var key := "glow_%s_%.2f" % [c.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.3
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	_cache[key] = m
	return m


static func glass(c: Color) -> StandardMaterial3D:
	var key := "glass_%s" % c.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = 0.9
	m.roughness = 0.05
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.8
	m.rim_enabled = true
	m.rim = 0.6
	_cache[key] = m
	return m


static func add(c: Color, energy: float = 3.0, mode: int = 0, vcol: bool = false) -> ShaderMaterial:
	var key := "add_%s_%.2f_%d_%s" % [c.to_html(), energy, mode, str(vcol)]
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = ADD_SHADER
	m.set_shader_parameter("color", c)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("mode", mode)
	m.set_shader_parameter("use_vertex_color", vcol)
	_cache[key] = m
	return m


static func gradient(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / float(cols.size() - 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g


static func curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.max_value = maxf(2.0, maxf(a, b))
	c.add_point(Vector2(0.0, a))
	c.add_point(Vector2(1.0, b))
	return c
