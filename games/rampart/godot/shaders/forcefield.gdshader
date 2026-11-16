shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec3 color : source_color = vec3(1.0, 0.22, 0.4);
uniform float energy = 0.85;
uniform float flicker = 1.0;

void fragment() {
	vec2 uv = UV;
	float scan = 0.5 + 0.5 * sin(uv.y * 60.0 - TIME * 10.0);
	float wave = 0.5 + 0.5 * sin(uv.x * 40.0 + TIME * 6.0 + sin(uv.y * 9.0 + TIME * 2.0) * 3.0);
	float arcs = pow(0.5 + 0.5 * sin(uv.x * 7.0 - TIME * 13.0 + sin(uv.y * 20.0) * 1.5), 12.0);
	float edge = abs(uv.y * 2.0 - 1.0);
	float rim = smoothstep(0.82, 1.0, edge);
	float a = 0.12 + 0.3 * scan * wave + arcs * 1.1 + rim * 2.2;
	ALBEDO = color * energy * a * flicker;
}
