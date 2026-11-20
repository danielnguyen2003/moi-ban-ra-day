shader_type spatial;
// Night sky dome: indigo zenith, violet-teal horizon glow, twinkling stars, faint milky band.
render_mode unshaded, cull_front, fog_disabled, depth_draw_never, shadows_disabled;
uniform vec4 zenith : source_color = vec4(0.03, 0.025, 0.09, 1.0);
uniform vec4 horizon : source_color = vec4(0.22, 0.14, 0.32, 1.0);
uniform vec4 glow : source_color = vec4(0.2, 0.35, 0.45, 1.0);
varying vec3 dir;

float hash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }

void vertex() {
	dir = normalize(VERTEX);
}

void fragment() {
	float h = clamp(dir.y, -0.2, 1.0);
	vec3 c = mix(horizon.rgb, zenith.rgb, smoothstep(0.0, 0.55, h));
	c += glow.rgb * exp(-abs(h) * 9.0) * 0.6;
	// stars
	vec3 g = floor(dir * 260.0);
	float s = hash(g);
	float star = step(0.9965, s) * smoothstep(0.02, 0.25, h);
	float tw = 0.6 + 0.4 * sin(TIME * (2.0 + s * 5.0) + s * 40.0);
	c += vec3(0.9, 0.95, 1.0) * star * tw * 1.6;
	// milky band
	float band = exp(-pow(dot(dir, normalize(vec3(0.4, 0.6, -0.7))) * 4.0, 2.0)) * smoothstep(0.05, 0.5, h);
	c += vec3(0.25, 0.22, 0.4) * band * (0.5 + 0.5 * hash(floor(dir * 90.0)));
	ALBEDO = c;
}
