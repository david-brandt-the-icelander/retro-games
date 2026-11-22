shader_type spatial;
render_mode cull_back;
#include "res://shaders/fog.gdshaderinc"

uniform float grid_strength : hint_range(0.0, 1.0) = 0.35;
varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = to_linear(COLOR.rgb);
	float n = vnoise(wpos.xz * 2.5) * 0.55 + vnoise(wpos.xz * 8.0) * 0.3 + vnoise(wpos.xz * 22.0) * 0.15;
	col *= 0.86 + n * 0.28;
	float d = hex_edge_dist(wpos.xz);
	float top = step(0.6, (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).y);
	col = mix(col, col * 0.6, smoothstep(0.94, 0.995, d) * grid_strength * top);
	float f = fog_at(wpos);
	ROUGHNESS = 1.0;
	SPECULAR = 0.12;
	if (f < 0.25) {
		ALBEDO = vec3(0.0);
		EMISSION = fog_cloud(wpos.xz, TIME);
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = f < 0.75 ? fog_explored(col) : col;
	}
}
