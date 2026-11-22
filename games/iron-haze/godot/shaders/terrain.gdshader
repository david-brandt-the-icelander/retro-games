shader_type spatial;
// Battlefield ground: procedural mud / dry grass / rock blend with oil slicks,
// shell scorch and gravel painted in through vertex colours
// (R = scorch, G = oil, B = gravel/road).

uniform sampler2D macro_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_noise : hint_default_white, repeat_enable, filter_linear_mipmap;
uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform vec3 mud_color = vec3(0.12, 0.095, 0.07);
uniform vec3 grass_color = vec3(0.20, 0.20, 0.10);
uniform vec3 dry_color = vec3(0.34, 0.28, 0.17);
uniform vec3 rock_color = vec3(0.27, 0.25, 0.23);
uniform vec3 gravel_color = vec3(0.34, 0.32, 0.29);

varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz;
	float m = texture(macro_noise, p * 0.006).r;
	float m2 = texture(macro_noise, p * 0.021 + vec2(0.37, 0.71)).r;
	float d = texture(detail_noise, p * 0.17).r;
	float d2 = texture(detail_noise, p * 0.55 + vec2(0.13, 0.4)).r;

	vec3 col = mix(mud_color, grass_color, smoothstep(0.35, 0.65, m));
	col = mix(col, dry_color, smoothstep(0.55, 0.8, m2) * 0.7);
	float slope = 1.0 - clamp(world_nrm.y, 0.0, 1.0);
	float rockiness = smoothstep(0.10, 0.28, slope + (d - 0.5) * 0.15);
	col = mix(col, rock_color * (0.8 + 0.4 * d2), rockiness);
	col *= 0.7 + 0.6 * mix(d, d2, 0.35);

	float gravel = clamp(COLOR.b * (0.75 + 0.5 * d2), 0.0, 1.0);
	col = mix(col, gravel_color * (0.8 + 0.35 * d2), gravel * 0.85);

	float scorch = clamp(COLOR.r * (0.7 + 0.6 * d), 0.0, 1.0);
	col = mix(col, vec3(0.06, 0.05, 0.04), scorch * 0.8);

	float oil = smoothstep(0.25, 0.55, COLOR.g + (d - 0.5) * 0.45);
	col = mix(col, vec3(0.008, 0.007, 0.008), oil);

	ALBEDO = col;
	ROUGHNESS = mix(0.95 - rockiness * 0.1, 0.06, oil);
	METALLIC = oil * 0.15;
	SPECULAR = 0.25 + oil * 0.45;
	NORMAL_MAP = texture(detail_normal, p * 0.08).rgb;
	NORMAL_MAP_DEPTH = mix(0.6, 0.05, oil);
}
