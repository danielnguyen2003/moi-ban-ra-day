shader_type spatial;
// Stylised toon: 3-step diffuse ramp, soft rim light, optional tabby stripes (object space),
// emission for eyes / lanterns. Pair with outline.gdshader as next_pass for ink lines.
render_mode diffuse_toon, specular_toon;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 shade_color : source_color = vec4(0.35, 0.3, 0.55, 1.0); // shadows lean violet at night
uniform float steps = 3.0;
uniform float rim_strength = 0.45;
uniform vec4 rim_color : source_color = vec4(0.6, 0.75, 1.0, 1.0);
uniform float stripes = 0.0;            // 0 = none, >0 = tabby stripe density
uniform vec4 stripe_color : source_color = vec4(0.25, 0.2, 0.18, 1.0);
uniform vec3 stripe_axis = vec3(1.0, 0.0, 0.0);
uniform vec4 emission_color : source_color = vec4(0.0);
uniform float emission_energy = 0.0;
uniform float roughness_v = 0.8;

varying vec3 obj_pos;

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 c = albedo.rgb;
	if (stripes > 0.0) {
		float s = sin(dot(obj_pos, stripe_axis) * stripes + sin(obj_pos.y * 9.0) * 0.6);
		c = mix(c, stripe_color.rgb, smoothstep(0.35, 0.55, s));
	}
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.2;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * rim * rim_strength * 0.35;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;
	float q = floor(ndl * steps + 0.5) / steps;      // banded
	vec3 lit = mix(shade_color.rgb * 0.6, vec3(1.0), q);
	DIFFUSE_LIGHT += ALBEDO * lit * LIGHT_COLOR / PI * 1.6;
}
