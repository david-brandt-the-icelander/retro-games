shader_type spatial;

uniform vec3 base_color : source_color = vec3(0.075, 0.085, 0.105);
uniform vec3 line_color : source_color = vec3(0.12, 0.62, 1.0);
uniform float line_energy = 2.2;
uniform float cell_size = 4.0;

varying vec3 wpos;
varying vec3 wnormal;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// Top faces use XZ, side faces use ZY so the panels wrap the edges.
	vec2 p = abs(wnormal.y) > 0.5 ? wpos.xz : vec2(wpos.z, wpos.y);
	vec2 cell = p / cell_size;
	vec2 id = floor(cell);
	vec2 f = fract(cell);
	float h = hash(id);

	// Grid lines (anti-aliased)
	vec2 g = abs(fract(cell - 0.5) - 0.5) / fwidth(cell);
	float line = 1.0 - min(min(g.x, g.y), 1.0);

	// Panel inset bevel
	float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
	float bevel = smoothstep(0.02, 0.07, edge);

	// Occasional lit hatch panels
	float hatch = step(0.93, h) * smoothstep(0.17, 0.19, edge) * (1.0 - smoothstep(0.21, 0.23, edge));

	// Energy pulse rolling toward the player
	float pulse = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(wpos.z * 0.12 + TIME * 4.0), 6.0);

	vec3 col = base_color * (0.75 + 0.5 * h) * mix(0.55, 1.0, bevel);
	ALBEDO = col;
	METALLIC = 0.75;
	ROUGHNESS = mix(0.55, 0.28, h);
	EMISSION = line_color * line * line_energy * pulse
		+ vec3(1.0, 0.55, 0.15) * hatch * 0.6 * (0.6 + 0.4 * sin(TIME * 3.0 + h * 20.0));
}
