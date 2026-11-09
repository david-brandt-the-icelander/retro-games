// An engine plume: additive, brightest at the nozzle, fading to nothing aft.
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 core : source_color = vec3(0.45, 0.62, 1.0);
uniform float strength = 6.0;

void fragment() {
	float along = clamp(UV.y, 0.0, 1.0);
	float flicker = 0.85 + 0.15 * sin(TIME * 37.0 + UV.x * 6.2831);
	float fade = pow(1.0 - along, 2.2);
	ALBEDO = core * strength * fade * flicker;
	ALPHA = fade;
}
