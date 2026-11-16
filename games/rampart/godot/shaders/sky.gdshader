shader_type sky;

uniform vec3 top_color : source_color = vec3(0.012, 0.016, 0.04);
uniform vec3 bottom_color : source_color = vec3(0.02, 0.012, 0.045);
uniform vec3 planet_dir = vec3(0.45, -0.72, -0.6);
uniform float planet_size = 0.24;
uniform vec3 sun_dir = vec3(-0.4, 0.5, -0.6);

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0,0,0)), hash(i + vec3(1,0,0)), f.x),
	               mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x),
	               mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	vec3 col = mix(bottom_color, top_color, clamp(d.y * 0.5 + 0.5, 0.0, 1.0));

	// Nebula
	float n = fbm(d * 3.0 + vec3(0.0, 0.0, TIME * 0.003));
	float n2 = fbm(d * 6.0 + vec3(4.1, 1.7, 2.3));
	col += vec3(0.32, 0.06, 0.42) * smoothstep(0.45, 0.85, n) * 0.55;
	col += vec3(0.02, 0.22, 0.4) * smoothstep(0.5, 0.9, n2) * 0.45;

	// Stars
	vec3 sp = d * 220.0;
	vec3 id = floor(sp);
	float h = hash(id);
	float star = step(0.9965, h) * smoothstep(0.45, 0.0, length(fract(sp) - 0.5));
	col += vec3(0.8, 0.9, 1.0) * star * (2.0 + 4.0 * hash(id + 3.1));

	// Gas giant
	vec3 pd = normalize(planet_dir);
	vec3 t1 = normalize(cross(pd, vec3(0.0, 1.0, 0.0)));
	vec3 t2 = cross(t1, pd);
	float rs = sin(planet_size);
	vec2 q = vec2(dot(d, t1), dot(d, t2)) / rs;
	float r2 = dot(q, q);
	float facing = dot(d, pd);
	if (facing > 0.0 && r2 < 1.0) {
		vec3 nrm = normalize(t1 * q.x + t2 * q.y - pd * sqrt(1.0 - r2));
		vec3 L = normalize(sun_dir);
		float diff = clamp(dot(nrm, L) * 0.9 + 0.1, 0.0, 1.0);
		float lat = dot(nrm, normalize(vec3(0.2, 1.0, 0.1)));
		float bands = fbm(vec3(lat * 9.0, lat * 2.0, 0.0) + fbm(nrm * 4.0) * 1.2);
		vec3 pc = mix(vec3(0.75, 0.42, 0.22), vec3(0.95, 0.78, 0.55), bands);
		pc = mix(pc, vec3(0.35, 0.18, 0.25), smoothstep(0.6, 0.9, bands) * 0.6);
		vec3 planet = pc * diff * 0.42;
		float rim = pow(clamp(r2, 0.0, 1.0), 4.0);
		planet += vec3(0.3, 0.6, 1.0) * rim * (0.2 + diff) * 0.35;
		float aa = smoothstep(1.0, 0.985, r2);
		col = mix(col, planet, aa);
	} else if (facing > 0.0) {
		float halo = exp(-(r2 - 1.0) * 18.0);
		col += vec3(0.25, 0.5, 1.0) * halo * 0.25;
	}
	COLOR = col;
}
