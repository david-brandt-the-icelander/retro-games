// Glowing translucent light wall used for cycle trails and the arena boundary.
// Designed for a unit BoxMesh that is scaled per-segment (local Y spans -0.5..0.5).
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque, shadows_disabled;

uniform vec4 wall_color : source_color = vec4(0.0, 0.85, 1.0, 1.0);
uniform float energy = 3.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float scan_speed = 1.5;

varying vec3 local_pos;
varying vec3 world_pos;

void vertex() {
	local_pos = VERTEX;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp(local_pos.y + 0.5, 0.0, 1.0);
	// Bright rim along the top edge, softer rim at the base.
	float top_edge = smoothstep(0.80, 1.0, h);
	float base_edge = smoothstep(0.14, 0.0, h) * 0.5;
	// Body gets brighter toward the top.
	float body = 0.18 + 0.55 * h * h;
	// Faint horizontal scan lines drifting along the wall.
	float along = world_pos.x + world_pos.z;
	float scan = 0.5 + 0.5 * sin(along * 0.9 - TIME * scan_speed * 6.0);
	float lines = smoothstep(0.92, 1.0, scan) * 0.35 * h;

	float intensity = body + lines + top_edge * 1.8 + base_edge;
	vec3 col = mix(wall_color.rgb, vec3(1.0), top_edge * 0.55);
	// Fade walls right next to the camera so the chase cam isn't blinded by its own trail.
	float near_fade = smoothstep(1.5, 9.0, length(CAMERA_POSITION_WORLD - world_pos));
	ALBEDO = col * intensity * energy * fade * mix(0.25, 1.0, near_fade);
	ALPHA = clamp(0.22 + h * 0.3 + top_edge, 0.0, 1.0) * fade * mix(0.15, 1.0, near_fade);
}
