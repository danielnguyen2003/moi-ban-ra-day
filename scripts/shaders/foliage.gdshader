shader_type spatial;
// Vertex-coloured toon foliage for MultiMesh with gentle wind. The bend grows linearly with
// height above the instance origin and is scaled by `sway` per material, so tall plants lean a
// little at the top instead of stretching (v4 bug: displacement grew with height²).
render_mode diffuse_toon, specular_disabled, cull_disabled;
uniform vec4 shade_color : source_color = vec4(0.3, 0.28, 0.48, 1.0);
uniform float sway = 0.03;            // metres of lean per metre of height at full gust
uniform float emission_from_alpha = 0.0;
uniform float translucency = 0.25;    // leaves glow a little when back-lit

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;   // per-plant phase
	float h = max(VERTEX.y, 0.0);
	float gust = sin(TIME * 1.3 + wp.x * 0.15 + wp.z * 0.11) * 0.7 + sin(TIME * 2.9 + wp.z * 0.4) * 0.3;
	float flutter = sin(TIME * 7.0 + VERTEX.x * 9.0 + VERTEX.z * 7.0) * 0.15;
	float lean = sway * h * (gust + flutter);
	VERTEX.x += lean;
	VERTEX.z += lean * 0.4;
	VERTEX.y -= abs(lean) * 0.15;     // keep the length roughly constant
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.85;
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * 2.5 * emission_from_alpha;
	BACKLIGHT = COLOR.rgb * translucency;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float q = floor(ndl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += ALBEDO * mix(shade_color.rgb * 0.6, vec3(1.0), q) * LIGHT_COLOR * ATTENUATION / PI * 1.6;
}
