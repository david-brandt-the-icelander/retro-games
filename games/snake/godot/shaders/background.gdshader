// Animated aurora-style backdrop: drifting colour blobs, vignette and a touch of grain.
shader_type canvas_item;

uniform vec2 resolution = vec2(1280.0, 720.0);
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
uniform vec3 pulse_tint : source_color = vec3(0.2, 1.0, 0.9);

float blob(vec2 p, vec2 c, float r) {
	float d = length(p - c);
	return exp(-d * d / (r * r));
}

void fragment() {
	vec2 uv = UV;
	float aspect = resolution.x / resolution.y;
	vec2 p = vec2(uv.x * aspect, uv.y);
	float t = TIME * 0.12;

	vec3 col = mix(vec3(0.012, 0.018, 0.045), vec3(0.035, 0.018, 0.07), uv.y);

	col += vec3(0.02, 0.22, 0.30) * blob(p, vec2(0.45 + 0.30 * sin(t * 1.3), 0.30 + 0.20 * cos(t * 0.9)), 0.55);
	col += vec3(0.28, 0.05, 0.34) * blob(p, vec2(1.35 + 0.35 * cos(t * 0.8), 0.72 + 0.18 * sin(t * 1.1)), 0.60);
	col += vec3(0.05, 0.08, 0.30) * blob(p, vec2(0.95 + 0.40 * sin(t * 0.6 + 2.0), 0.15 + 0.25 * cos(t * 0.7)), 0.50);

	col += pulse_tint * pulse * 0.06;

	float v = smoothstep(1.15, 0.25, length((uv - 0.5) * vec2(1.25, 1.0)) * 1.5);
	col *= mix(0.45, 1.0, v);

	float n = fract(sin(dot(uv * resolution + fract(TIME) * 61.0, vec2(12.9898, 78.233))) * 43758.5453);
	col += (n - 0.5) * 0.012;

	COLOR = vec4(col, 1.0);
}
