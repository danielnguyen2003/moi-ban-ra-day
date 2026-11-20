shader_type spatial;
// Vertex-coloured toon foliage for MultiMesh (grass, rice, reeds, bamboo, flowers) with wind sway.
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform vec4 shade_color : source_color = vec4(0.28, 0.26, 0.5, 1.0);
uniform float sway = 0.12;
uniform float emission_from_alpha = 0.0;   // vertex alpha < 1 marks glowing parts (flower hearts)

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float w = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.21) + 0.5 * sin(TIME * 3.1 + wp.z * 0.7);
	VERTEX.x += w * sway * h * h;
	VERTEX.z += w * sway * 0.5 * h * h;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.9;
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * 2.5 * emission_from_alpha;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float q = floor(ndl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += ALBEDO * mix(shade_color.rgb * 0.6, vec3(1.0), q) * LIGHT_COLOR * ATTENUATION / PI * 1.6;
}
