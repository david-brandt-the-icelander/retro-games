// A procedural star panorama: soft points, denser in a band, over a faint glow along it.
shader_type sky;

uniform vec3 band_normal = vec3(0.2, 0.9, 0.35);
uniform vec3 band_tint : source_color = vec3(0.55, 0.45, 0.32);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float stars(vec3 dir, float scale, float density) {
	vec3 p = dir * scale;
	vec3 cell = floor(p);
	vec3 local = fract(p) - 0.5;
	float h = hash(cell);
	if (h > density) {
		return 0.0;
	}
	vec3 offset = vec3(hash(cell + 1.3), hash(cell + 2.7), hash(cell + 4.1)) - 0.5;
	float d = length(local - offset * 0.7);
	float size = 0.04 + 0.06 * hash(cell + 9.1);
	return smoothstep(size, 0.0, d) * (0.4 + 1.6 * hash(cell + 5.5));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float band = exp(-pow(dot(dir, normalize(band_normal)) * 3.2, 2.0));
	float s = stars(dir, 140.0, 0.035 + 0.12 * band) + stars(dir, 320.0, 0.02 + 0.08 * band) * 0.6;
	vec3 glow = band_tint * band * 0.035;
	COLOR = glow + vec3(0.92, 0.95, 1.0) * s * 1.6;
}
