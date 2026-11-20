shader_type spatial;
// World-space stylised ground. mode: 0 brick courtyard, 1 wood floor, 2 grass, 3 dirt, 4 pond water.
render_mode diffuse_toon, specular_disabled;
uniform int mode = 0;
uniform vec4 base_a : source_color = vec4(0.62, 0.32, 0.24, 1.0);
uniform vec4 base_b : source_color = vec4(0.52, 0.26, 0.2, 1.0);
uniform vec4 line_c : source_color = vec4(0.25, 0.16, 0.18, 1.0);
uniform vec4 shade_color : source_color = vec4(0.3, 0.28, 0.5, 1.0);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	vec3 c = base_a.rgb;
	float em = 0.0;
	if (mode == 0) {           // gạch bát: 0.9 x 0.9 tiles, offset rows
		vec2 t = p / 0.9;
		t.x += step(1.0, mod(floor(t.y), 2.0)) * 0.5;
		vec2 f = fract(t);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		c = mix(base_a.rgb, base_b.rgb, hash(floor(t)));
		c *= 0.9 + 0.2 * noise(p * 3.0);
		c = mix(line_c.rgb, c, smoothstep(0.02, 0.06, edge));
	} else if (mode == 1) {    // ván gỗ
		float row = floor(p.y / 0.45);
		float plank = fract(p.y / 0.45);
		c = mix(base_a.rgb, base_b.rgb, hash(vec2(row, floor((p.x + row * 1.7) / 3.0))));
		c *= 0.88 + 0.12 * sin(p.x * 6.0 + noise(p * 2.0) * 4.0);
		c = mix(line_c.rgb, c, smoothstep(0.02, 0.08, min(plank, 1.0 - plank)));
	} else if (mode == 2) {    // cỏ: big soft patches, fine speckle, the odd bare earth spot
		float big = noise(p * 0.06);
		float n = noise(p * 0.7) * 0.6 + noise(p * 3.0) * 0.4;
		c = mix(base_a.rgb, base_b.rgb, n);
		c = mix(c, c * vec3(1.18, 1.22, 1.05), smoothstep(0.55, 0.8, big));
		c = mix(c, vec3(0.2, 0.17, 0.15), smoothstep(0.78, 0.86, noise(p * 0.21 + 7.0)) * 0.6);
	} else if (mode == 3) {    // đất
		float n = noise(p * 0.9) * 0.5 + noise(p * 4.0) * 0.5;
		c = mix(base_a.rgb, base_b.rgb, n);
	} else {                   // nước ao: dark with moving moon glints
		float n = noise(p * 1.5 + vec2(TIME * 0.2, TIME * 0.13));
		c = mix(base_a.rgb, base_b.rgb, n);
		// sparse moon glints + a soft sheen; water stays dark so the shore reads
		em = smoothstep(0.9, 0.93, noise(p * 3.5 - TIME * 0.25)) * 0.35 + 0.05 * n;
	}
	ALBEDO = c;
	ROUGHNESS = mode == 4 ? 0.15 : 0.95;
	EMISSION = vec3(0.7, 0.85, 1.0) * em;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float q = floor(ndl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += ALBEDO * mix(shade_color.rgb * 0.55, vec3(1.0), q) * LIGHT_COLOR * ATTENUATION / PI * 1.6;
}
