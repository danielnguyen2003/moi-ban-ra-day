shader_type spatial;
// v4 mice: one MultiMesh per kind, vertex-coloured meshes with animation tags in UV.x:
// 0 body · 1 feet A · 2 feet B · 3 tail · 4 ears · 5 wings · 6 rigid accessory.
// INSTANCE_CUSTOM: x phase, y speed01, z hit flash, w scared.  Vertex alpha < 1 = emissive part.
render_mode diffuse_toon, specular_disabled;
uniform vec4 shade_color : source_color = vec4(0.5, 0.46, 0.6, 1.0);   // lighter, more neutral shadows keep fur colours readable at night
uniform vec4 rim_color : source_color = vec4(0.65, 0.8, 1.0, 1.0);
uniform float hover = 0.0;      // ghosts and bats float
varying float v_flash;

void vertex() {
	float ph = INSTANCE_CUSTOM.x * 6.2831;
	float sp = INSTANCE_CUSTOM.y;
	float t = TIME * (7.0 + 13.0 * sp) + ph;
	int tag = int(UV.x + 0.5);
	float bob = abs(sin(t)) * 0.06 * sp;
	if (tag == 1) {
		VERTEX.z += sin(t) * 0.13 * sp;
		VERTEX.y += max(0.0, sin(t)) * 0.07 * sp;
	} else if (tag == 2) {
		VERTEX.z += sin(t + 3.1416) * 0.13 * sp;
		VERTEX.y += max(0.0, sin(t + 3.1416)) * 0.07 * sp;
	} else if (tag == 3) {
		float k = max(VERTEX.z - 0.25, 0.0);
		VERTEX.x += sin(TIME * 7.0 + ph + VERTEX.z * 6.0) * 0.3 * k;
		VERTEX.y += sin(TIME * 4.0 + ph) * 0.08 * k;
	} else if (tag == 4) {
		VERTEX.x += sign(VERTEX.x) * (0.02 * sin(TIME * 3.0 + ph) + 0.03 * sp * sin(t));
	} else if (tag == 5) {
		VERTEX.y += sin(TIME * 20.0 + ph) * abs(VERTEX.x) * 0.7;
	}
	// squash & stretch with the stride, plus body bob
	float sq = 1.0 + 0.08 * sin(t * 2.0) * sp;
	VERTEX.y = VERTEX.y * sq + bob;
	VERTEX.y += hover * (0.35 + 0.15 * sin(TIME * 2.0 + ph));
	// scared shiver
	VERTEX.x += sin(TIME * 70.0 + ph) * 0.012 * INSTANCE_CUSTOM.w;
	v_flash = INSTANCE_CUSTOM.z;
}

void fragment() {
	vec3 c = mix(COLOR.rgb, vec3(1.0), v_flash * 0.85);
	ALBEDO = c * 1.15;
	ROUGHNESS = 0.85;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * (1.0 - COLOR.a) * 3.0 + rim_color.rgb * rim * 0.3 + vec3(1.0) * v_flash * 0.6;
}

void light() {
	float ndl = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	float q = floor(ndl * 3.0 + 0.5) / 3.0;
	DIFFUSE_LIGHT += ALBEDO * mix(shade_color.rgb * 0.6, vec3(1.0), q) * LIGHT_COLOR * ATTENUATION / PI * 1.6;
}
