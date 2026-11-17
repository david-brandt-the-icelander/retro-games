shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
#include "res://shaders/fog.gdshaderinc"

uniform vec3 deep_color : source_color = vec3(0.04, 0.22, 0.38);
uniform vec3 shallow_color : source_color = vec3(0.16, 0.58, 0.66);
varying vec3 wpos;

float wave(vec2 p, float t) {
	return sin(p.x * 1.3 + t * 1.1) * 0.5 + sin(p.y * 1.7 - t * 0.9) * 0.35 + sin((p.x + p.y) * 2.9 + t * 1.7) * 0.15;
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave(wpos.xz, TIME) * 0.025;
}

void fragment() {
	float e = 0.05;
	float t = TIME;
	vec2 p = wpos.xz;
	float h0 = wave(p * 2.0, t * 1.3) + vnoise(p * 3.0 + t * 0.3) * 0.6;
	float hx = wave((p + vec2(e, 0.0)) * 2.0, t * 1.3) + vnoise((p + vec2(e, 0.0)) * 3.0 + t * 0.3) * 0.6;
	float hz = wave((p + vec2(0.0, e)) * 2.0, t * 1.3) + vnoise((p + vec2(0.0, e)) * 3.0 + t * 0.3) * 0.6;
	vec3 n_world = normalize(vec3(-(hx - h0) / e * 0.06, 1.0, -(hz - h0) / e * 0.06));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	float sparkle = smoothstep(0.82, 1.0, vnoise(p * 9.0 + vec2(t * 0.7, -t * 0.4))) * 0.25;
	vec3 col = mix(deep_color, shallow_color, 0.35 + 0.3 * vnoise(p * 0.5)) + sparkle;
	float f = fog_at(wpos);
	ROUGHNESS = 0.06;
	METALLIC = 0.0;
	SPECULAR = 0.7;
	ALPHA = mix(0.62, 0.92, fres);
	if (f < 0.25) {
		ALBEDO = vec3(0.0);
		EMISSION = fog_cloud(p, t);
		ALPHA = 1.0;
		ROUGHNESS = 1.0;
		SPECULAR = 0.0;
	} else {
		ALBEDO = f < 0.75 ? fog_explored(col) : col;
	}
}
