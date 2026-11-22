// Glossy dark floor with anti-aliased neon grid lines.
shader_type spatial;
render_mode cull_back;

uniform vec3 line_color : source_color = vec3(0.1, 0.55, 1.0);
uniform vec3 major_color : source_color = vec3(0.55, 0.25, 1.0);
uniform float cell_size = 4.0;
uniform float major_every = 5.0;
uniform float arena_half = 100.0;
uniform float line_energy = 0.9;

varying vec3 world_pos;

float grid_line(vec2 coord, float width) {
	vec2 d = fwidth(coord);
	vec2 g = abs(fract(coord - 0.5) - 0.5) / max(d * width, vec2(1e-4));
	return 1.0 - min(min(g.x, g.y), 1.0);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float minor = grid_line(p / cell_size, 1.0);
	float major = grid_line(p / (cell_size * major_every), 1.6);

	// Inside the arena the grid is crisp; outside it fades to darkness.
	float edge = max(abs(p.x), abs(p.y));
	float inside = 1.0 - smoothstep(arena_half, arena_half + 60.0, edge);
	// Soften grid with view distance to avoid moire.
	float dist = length(CAMERA_POSITION_WORLD - world_pos);
	float dist_fade = 1.0 - smoothstep(60.0, 260.0, dist);

	ALBEDO = vec3(0.012, 0.014, 0.024);
	METALLIC = 0.6;
	ROUGHNESS = 0.32;
	SPECULAR = 0.4;
	vec3 glow = line_color * minor * 0.55 + major_color * major * 1.4;
	EMISSION = glow * line_energy * inside * mix(0.35, 1.0, dist_fade);
}
