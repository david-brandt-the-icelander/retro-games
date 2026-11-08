class_name Avatar
extends Control
## A player's round profile picture, with their initial on a coloured disc until it loads (or if
## they have none).

# The mask works in the control's own pixels, so it clips the picture and the initial alike.
const SHADER := """
shader_type canvas_item;
uniform vec2 box_size = vec2(40.0);
varying vec2 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	float d = length(local / box_size - vec2(0.5));
	COLOR.a *= smoothstep(0.5, 0.48, d);
}
"""
static var _shader: Shader

var texture: Texture2D
var initial := "?"
var tint := Color("3b4048")


static func make(path: Variant, name: String, size := 40.0) -> Avatar:
	var a := Avatar.new()
	a.custom_minimum_size = Vector2(size, size)
	a.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	a.initial = name.substr(0, 1).to_upper() if name != "" else "?"
	# A stable colour per name.
	var h := float(name.hash() % 360) / 360.0
	a.tint = Color.from_hsv(absf(h), 0.35, 0.42)
	a.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("box_size", Vector2(size, size))
	a.material = m
	Api.avatar(path, func(tex: Texture2D) -> void:
		if is_instance_valid(a) and tex:
			a.texture = tex
			a.queue_redraw())
	return a


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if texture:
		draw_texture_rect(texture, r, false)
	else:
		draw_rect(r, tint)
		var font := UI.bold
		var fs := int(size.y * 0.42)
		var w := font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) / 2.0, size.y / 2.0 + fs * 0.36), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
