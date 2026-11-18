shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D influence_tex : filter_linear, repeat_disable;
uniform float board_size = 48.0;

varying vec3 wpos;
varying float up;

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).y;
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float inf = texture(influence_tex, clamp(wpos.xz / board_size, vec2(0.0), vec2(1.0))).r;
	vec3 dim = mix(c * 0.42, vec3(0.03, 0.04, 0.09), 0.25);
	vec3 col = mix(dim, c, smoothstep(0.3, 0.7, inf));
	vec2 g = abs(fract(wpos.xz) - 0.5);
	float line = smoothstep(0.47, 0.5, max(g.x, g.y)) * step(0.3, up);
	ALBEDO = col * (1.0 - line * 0.12);
	ROUGHNESS = 0.9;
}
