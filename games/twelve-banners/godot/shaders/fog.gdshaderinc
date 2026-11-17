// Shared hex-map helpers: world position -> odd-r offset hex, fog-of-war lookup.
uniform sampler2D fog_tex : filter_nearest, repeat_disable;
uniform vec2 map_size = vec2(40.0, 26.0);

ivec2 hex_of(vec2 p) {
	float q = (0.57735027 * p.x - p.y / 3.0);
	float r = (2.0 / 3.0) * p.y;
	float s = -q - r;
	float rq = round(q);
	float rr = round(r);
	float rs = round(s);
	float dq = abs(rq - q);
	float dr = abs(rr - r);
	float ds = abs(rs - s);
	if (dq > dr && dq > ds) { rq = -rr - rs; }
	else if (dr > ds) { rr = -rq - rs; }
	int qi = int(rq);
	int ri = int(rr);
	int col = qi + (ri - (ri & 1)) / 2;
	return ivec2(col, ri);
}

vec2 hex_center(ivec2 h) {
	return vec2(1.7320508 * (float(h.x) + 0.5 * float(h.y & 1)), 1.5 * float(h.y));
}

// 0 at hex centre, 1 at the edge midpoint.
float hex_edge_dist(vec2 p) {
	vec2 l = p - hex_center(hex_of(p));
	float d = max(abs(l.x), max(abs(0.5 * l.x + 0.8660254 * l.y), abs(0.5 * l.x - 0.8660254 * l.y)));
	return d / 0.8660254;
}

// 0 = unexplored, 0.5 = explored (fogged), 1 = visible
float fog_at(vec3 wp) {
	ivec2 h = hex_of(wp.xz);
	if (h.x < 0 || h.y < 0 || h.x >= int(map_size.x) || h.y >= int(map_size.y)) { return 0.0; }
	return texelFetch(fog_tex, h, 0).r;
}

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash12(i), hash12(i + vec2(1.0, 0.0)), u.x),
			   mix(hash12(i + vec2(0.0, 1.0)), hash12(i + vec2(1.0, 1.0)), u.x), u.y);
}

vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
}

// Unexplored tiles: flat, unlit drifting "cloud" (use as EMISSION with black albedo).
vec3 fog_cloud(vec2 wp, float time) {
	float n = vnoise(wp * 0.6 + vec2(time * 0.04, 0.0)) * 0.6 + vnoise(wp * 1.9 - vec2(0.0, time * 0.03)) * 0.4;
	return mix(vec3(0.010, 0.014, 0.022), vec3(0.035, 0.045, 0.06), n);
}

// Explored but not currently visible: desaturated and dimmed.
vec3 fog_explored(vec3 col) {
	float g = dot(col, vec3(0.3, 0.59, 0.11));
	return mix(col, vec3(g) * vec3(0.9, 0.95, 1.08), 0.7) * 0.45;
}
