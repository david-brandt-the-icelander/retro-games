shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform vec4 color : source_color = vec4(1.0);
uniform float energy = 3.0;
// 0 = flat, 1 = soft (fresnel falloff), 2 = radial blob (UV), 3 = ring (UV)
uniform int mode = 0;
uniform bool use_vertex_color = false;
uniform float ring_width = 0.12;

void fragment() {
	vec4 c = color;
	if (use_vertex_color) {
		c *= COLOR;
	}
	float a = c.a;
	if (mode == 1) {
		float f = abs(dot(normalize(NORMAL), normalize(VIEW)));
		a *= f * f;
	} else if (mode == 2) {
		float d = length(UV - vec2(0.5)) * 2.0;
		a *= pow(clamp(1.0 - d, 0.0, 1.0), 2.0);
	} else if (mode == 3) {
		float d = length(UV - vec2(0.5)) * 2.0;
		float inner = smoothstep(1.0 - ring_width * 2.0, 1.0 - ring_width, d);
		float outer = 1.0 - smoothstep(1.0 - ring_width * 0.4, 1.0, d);
		a *= inner * outer;
	}
	ALBEDO = c.rgb * energy * a;
}
