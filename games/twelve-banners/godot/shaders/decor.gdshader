shader_type spatial;
render_mode cull_back;
#include "res://shaders/fog.gdshaderinc"

uniform float emission = 0.0;
uniform float sway = 0.0;
uniform float bob = 0.0;
varying float fogv;
varying vec3 wpos;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	fogv = fog_at(origin);
	if (fogv < 0.25) {
		VERTEX = vec3(0.0);
	}
	VERTEX.x += sin(TIME * 1.3 + origin.x * 1.7 + origin.z) * sway * max(VERTEX.y, 0.0);
	VERTEX.y += sin(TIME * 2.0 + origin.x * 3.0) * bob;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = to_linear(COLOR.rgb);
	ALBEDO = fogv < 0.75 ? fog_explored(col) : col;
	ROUGHNESS = 0.85;
	if (fogv > 0.75) {
		EMISSION = col * emission;
	}
}
